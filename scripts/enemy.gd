extends CharacterBody2D

# ===================================================
# enemy.gd — 普通饕客（敵人）
#
# 命中 Juice 流程：
#   take_hit(dir) 被呼叫
#   → _dying = true
#   → 閃白 + 旋轉飛出（_hit_vel）
#   → 0.2s 後淡出消失
#   → 有機會撞到其他饕客造成連鎖
# ===================================================

const MAP_CENTER    = Vector2(640.0, 360.0)
const SPEED         = 100.0
const REACH_DIST    = 36.0
const RADIUS        = 24.0
const COLOR_BODY    = Color(0.88, 0.15, 0.15)
const COLOR_OUTLINE = Color(1.0,  0.55, 0.55)

# ── 軟碰撞參數 ────────────────────────────────────
const PUSH_RADIUS       = 68.0
const PLAYER_PUSH_ACCEL = 700.0
const SELF_PUSH_RATIO   = 0.22
const SEP_RADIUS        = 56.0
const SEP_FORCE         = 120.0

@export var push_power : float = 1.0

signal reach_center

var _sep_vel : Vector2 = Vector2.ZERO

# ── 受擊 Juice 狀態 ───────────────────────────────
var _dying         : bool    = false
var _hit_vel       : Vector2 = Vector2.ZERO   # 被打飛的速度
var _spin_angle    : float   = 0.0            # 顯示旋轉角（弧度）
var _spin_speed    : float   = 0.0            # 旋轉角速度（弧度/秒）


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()


func _physics_process(delta: float) -> void:
	# ── 死亡飛出動畫 ──────────────────────────────
	if _dying:
		_hit_vel    = _hit_vel.lerp(Vector2.ZERO, 5.5 * delta)
		_spin_angle += _spin_speed * delta
		_spin_speed  = _spin_speed * (1.0 - 4.0 * delta)   # 旋轉逐漸減速
		velocity     = _hit_vel
		move_and_slide()
		queue_redraw()
		return

	var to_center = MAP_CENTER - global_position

	if to_center.length() <= REACH_DIST:
		reach_center.emit()
		queue_free()
		return

	_sep_vel = Vector2.ZERO

	# 饕客間軟分離
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var diff : Vector2 = global_position - other.global_position
		var dist : float   = diff.length()
		if dist < SEP_RADIUS and dist > 0.5:
			var strength = 1.0 - dist / SEP_RADIUS
			_sep_vel += diff.normalized() * SEP_FORCE * strength

	# 與玩家軟推擠
	for player in get_tree().get_nodes_in_group("players"):
		var diff : Vector2 = global_position - player.global_position
		var dist : float   = diff.length()
		if dist < PUSH_RADIUS and dist > 0.5:
			var strength = (1.0 - dist / PUSH_RADIUS) * push_power
			player.apply_push(-diff.normalized(), PLAYER_PUSH_ACCEL * strength * delta)
			_sep_vel += diff.normalized() * PLAYER_PUSH_ACCEL * SELF_PUSH_RATIO * strength * delta

	velocity = to_center.normalized() * SPEED + _sep_vel
	move_and_slide()


func _draw() -> void:
	# 底部橢圓陰影（不跟旋轉）
	draw_set_transform(Vector2(2.0, RADIUS * 0.82), 0.0, Vector2(0.88, 0.22))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 主體（套用旋轉）
	draw_set_transform(Vector2.ZERO, _spin_angle, Vector2.ONE)
	draw_circle(Vector2.ZERO, RADIUS, COLOR_BODY)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, COLOR_OUTLINE, 2.5)
	draw_circle(Vector2(-7.0, -6.0), 4.5, Color.BLACK)
	draw_circle(Vector2( 7.0, -6.0), 4.5, Color.BLACK)
	draw_arc(Vector2.ZERO, 10.0, deg_to_rad(20), deg_to_rad(160), 14, Color.BLACK, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 供 projectile.gd 呼叫：被食物命中 ───────────

func take_hit(hit_dir: Vector2 = Vector2.RIGHT) -> void:
	if _dying:
		return
	_dying = true

	# 飛出速度（被打飛）
	_hit_vel = hit_dir * 420.0

	# 隨機旋轉方向與速度（每次死法不一樣）
	var sign = 1.0 if randf() > 0.5 else -1.0
	_spin_speed = sign * randf_range(8.0, 16.0)  # 弧度/秒（約 2~3 圈/秒）

	# 閃白 → 淡出消失（Tween 驅動 modulate）
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.04)  # 白色閃光
	tw.tween_property(self, "modulate", Color(1.5, 0.4, 0.4, 0.8), 0.06)  # 紅色殘影
	tw.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 0.0), 0.18)  # 淡出
	tw.tween_callback(queue_free)
