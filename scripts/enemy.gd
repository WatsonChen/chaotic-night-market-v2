extends CharacterBody2D

# ===================================================
# enemy.gd — 普通饕客（敵人）
#
# 碰撞設計：
#   - 饕客之間：軟分離（proximity-based separation velocity）
#   - 饕客 vs 玩家：軟推擠（continuous push force，不硬卡死）
#   - push_power 控制推力倍數，大型饕客設為 2.0+
# ===================================================

const MAP_CENTER    = Vector2(640.0, 360.0)
const SPEED         = 100.0
const REACH_DIST    = 36.0                   # 略大於 RADIUS，視覺剛好到中心
const RADIUS        = 24.0                   # ↑ 1.5x（16→24）
const COLOR_BODY    = Color(0.88, 0.15, 0.15)
const COLOR_OUTLINE = Color(1.0,  0.55, 0.55)

# ── 軟碰撞參數（隨 RADIUS 等比調整）─────────────
## 與玩家感知半徑（RADIUS + player.RADIUS = 48，+20 預推區）
const PUSH_RADIUS       = 68.0
## 推擠玩家加速度（* delta → px/s）
const PLAYER_PUSH_ACCEL = 700.0
## 被玩家反推比例
const SELF_PUSH_RATIO   = 0.22
## 饕客間分離半徑（2 * RADIUS = 48，+8 緩衝）
const SEP_RADIUS        = 56.0
## 饕客間分離速度貢獻（px/s）
const SEP_FORCE         = 120.0

## 推力倍數；普通饕客 = 1.0，大型饕客可設為 2.0+
@export var push_power : float = 1.0

## 抵達中央時觸發，由 main.gd 監聽以計入客訴
signal reach_center

# 本幀累計的分離速度向量
var _sep_vel : Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()


func _physics_process(delta: float) -> void:
	var to_center = MAP_CENTER - global_position

	# 抵達中央判定
	if to_center.length() <= REACH_DIST:
		reach_center.emit()
		queue_free()
		return

	_sep_vel = Vector2.ZERO

	# ── 饕客間軟分離 ──────────────────────────────
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var diff : Vector2 = global_position - other.global_position
		var dist : float   = diff.length()
		if dist < SEP_RADIUS and dist > 0.5:
			var strength = 1.0 - dist / SEP_RADIUS
			_sep_vel += diff.normalized() * SEP_FORCE * strength

	# ── 與玩家的軟推擠 ────────────────────────────
	for player in get_tree().get_nodes_in_group("players"):
		var diff : Vector2 = global_position - player.global_position
		var dist : float   = diff.length()
		if dist < PUSH_RADIUS and dist > 0.5:
			var strength = (1.0 - dist / PUSH_RADIUS) * push_power
			# 推擠玩家（連續加速，乘 delta 保持幀率無關）
			player.apply_push(-diff.normalized(), PLAYER_PUSH_ACCEL * strength * delta)
			# 自身被輕微頂開（反作用）
			_sep_vel += diff.normalized() * PLAYER_PUSH_ACCEL * SELF_PUSH_RATIO * strength * delta

	# 合速：朝中央前進 + 軟分離向量
	velocity = to_center.normalized() * SPEED + _sep_vel
	move_and_slide()


func _draw() -> void:
	# 底部橢圓陰影
	draw_set_transform(Vector2(2.0, RADIUS * 0.82), 0.0, Vector2(0.88, 0.22))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 主體紅色圓形
	draw_circle(Vector2.ZERO, RADIUS, COLOR_BODY)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, COLOR_OUTLINE, 2.5)
	# 眼睛（隨尺寸放大）
	draw_circle(Vector2(-7.0, -6.0), 4.5, Color.BLACK)
	draw_circle(Vector2( 7.0, -6.0), 4.5, Color.BLACK)
	# 嘴巴（弧線）
	draw_arc(Vector2.ZERO, 10.0, deg_to_rad(20), deg_to_rad(160), 14, Color.BLACK, 2.0)


# ── 供 projectile.gd 呼叫：被食物命中 ───────────

func take_hit() -> void:
	queue_free()
