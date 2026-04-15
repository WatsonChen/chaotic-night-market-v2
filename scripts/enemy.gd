extends CharacterBody2D

# ===================================================
# enemy.gd — 普通饕客（敵人）
#
# 連鎖碰撞：被擊飛（_dying=true）時每幀偵測接觸，
#   對未命中過的鄰近敵人/玩家施加連鎖衝擊。
#   連鎖飛速遞減（420 → 280 → 180…），自然衰減。
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

# ── 連鎖碰撞參數 ──────────────────────────────────
# 碰撞偵測半徑：兩個 RADIUS 相加 + 一點緩衝
const CHAIN_TOUCH_DIST   = RADIUS * 2.0 + 8.0   # 56px
# 連鎖對玩家的擊退力（比投射物輕）
const CHAIN_PLAYER_FORCE = 320.0

@export var push_power : float = 1.0

signal reach_center

var _sep_vel      : Vector2 = Vector2.ZERO
var _external_vel : Vector2 = Vector2.ZERO   # 滑地/外力用

# ── 受擊 Juice 狀態 ───────────────────────────────
var _dying            : bool    = false
var _hit_vel          : Vector2 = Vector2.ZERO
var _spin_angle       : float   = 0.0
var _spin_speed       : float   = 0.0
# 記錄此次飛出已連鎖命中過的節點（防重複）
var _chain_hit_bodies : Array   = []


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()


func _physics_process(delta: float) -> void:
	# ── 死亡飛出動畫 + 連鎖偵測 ──────────────────
	if _dying:
		_hit_vel    = _hit_vel.lerp(Vector2.ZERO, 5.5 * delta)
		_spin_angle += _spin_speed * delta
		_spin_speed  = _spin_speed * (1.0 - 4.0 * delta)
		velocity     = _hit_vel
		move_and_slide()

		# 仍有足夠速度時才偵測連鎖（太慢就不算撞到）
		if _hit_vel.length() > 80.0:
			_check_chain_collision()

		queue_redraw()
		return

	# ── 正常移動 ──────────────────────────────────
	var to_center = MAP_CENTER - global_position

	if to_center.length() <= REACH_DIST:
		reach_center.emit()
		queue_free()
		return

	_sep_vel      = Vector2.ZERO
	_external_vel = _external_vel.lerp(Vector2.ZERO, 5.0 * delta)

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

	velocity = to_center.normalized() * SPEED + _sep_vel + _external_vel
	move_and_slide()


# ── 連鎖碰撞偵測（每幀呼叫，僅在 _dying 期間）──

func _check_chain_collision() -> void:
	# 檢查周圍敵人
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or _chain_hit_bodies.has(other):
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < CHAIN_TOUCH_DIST:
			_chain_hit_bodies.append(other)
			# 連鎖速度 = 本次飛速 * 0.65（自然遞減）
			var chain_speed = _hit_vel.length() * 0.65
			other.take_hit(_hit_vel.normalized(), chain_speed)

	# 檢查周圍玩家
	for player in get_tree().get_nodes_in_group("players"):
		if _chain_hit_bodies.has(player):
			continue
		var dist = global_position.distance_to(player.global_position)
		# 玩家半徑 24 + 自身半徑 24 + 緩衝
		if dist < RADIUS + 24.0 + 8.0:
			_chain_hit_bodies.append(player)
			player.apply_knockback(_hit_vel.normalized(), CHAIN_PLAYER_FORCE)


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
# hit_speed 允許連鎖時傳入遞減後的速度

func take_hit(hit_dir: Vector2 = Vector2.RIGHT, hit_speed: float = 420.0) -> void:
	if _dying:
		return
	_dying = true
	_chain_hit_bodies.clear()

	_hit_vel = hit_dir * hit_speed

	var sign = 1.0 if randf() > 0.5 else -1.0
	_spin_speed = sign * randf_range(8.0, 16.0)

	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.04)
	tw.tween_property(self, "modulate", Color(1.5, 0.4, 0.4, 0.8), 0.06)
	tw.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 0.0), 0.18)
	tw.tween_callback(queue_free)


# ── 供滑地 / 外力使用 ─────────────────────────────

func apply_push(dir: Vector2, force: float) -> void:
	_external_vel = (_external_vel + dir * force).limit_length(300.0)
