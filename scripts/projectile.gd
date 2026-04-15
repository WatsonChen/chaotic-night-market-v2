extends Area2D

# ===================================================
# projectile.gd — 食物投射物
#
# 視覺：彗星尾跡（反方向漸淡小圓，不需額外節點）
# 碰撞：
#   命中敵人 → 消滅（吃飽）
#   命中玩家 → apply_knockback（力道 2x）
# ===================================================

const SPEED              = 400.0
const LIFETIME           = 3.0
const SHOOTER_GRACE_TIME = 0.15
const PLAYER_KNOCKBACK   = 600.0
const RADIUS             = 8.0   # ↑ 略大（6→8）

# 尾跡參數（隨尺寸加長、間距加大）
const TRAIL_STEPS    = 9      # 尾跡圓的數量
const TRAIL_SPACING  = 7.0    # 每顆圓的間距（px）

var direction : Vector2 = Vector2.RIGHT
var shooter             = null

var _lifetime        : float = 0.0
var _grace_timer     : float = SHOOTER_GRACE_TIME
var _can_hit_shooter : bool  = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_lifetime += delta

	if not _can_hit_shooter:
		_grace_timer -= delta
		if _grace_timer <= 0.0:
			_can_hit_shooter = true

	if _lifetime >= LIFETIME:
		queue_free()


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

	if position.x < -50 or position.x > 1330 or position.y < -50 or position.y > 770:
		queue_free()


func _draw() -> void:
	# ── 彗星尾跡（向移動反方向漸淡）
	var tail_dir = -direction.normalized()
	for i in range(TRAIL_STEPS):
		var t       = float(i + 1) / float(TRAIL_STEPS)
		var offset  = tail_dir * float(i + 1) * TRAIL_SPACING
		var alpha   = (1.0 - t) * 0.72
		var size    = RADIUS * (1.0 - t * 0.62)
		var r_col   = 1.0
		var g_col   = lerp(0.75, 0.2, t)   # 越往後越偏橘紅
		draw_circle(offset, size, Color(r_col, g_col, 0.0, alpha))

	# ── 主體（最前面渲染，蓋在尾跡之上）
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.88, 0.1))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color(1.0, 0.55, 0.0), 1.5)


# ── 碰撞處理 ─────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if body == shooter and not _can_hit_shooter:
		return

	if body.is_in_group("enemies"):
		body.take_hit()
		queue_free()
	elif body.is_in_group("players"):
		body.apply_knockback(direction.normalized(), PLAYER_KNOCKBACK)
		queue_free()
