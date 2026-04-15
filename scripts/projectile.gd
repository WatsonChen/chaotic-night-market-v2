extends Area2D

# ===================================================
# projectile.gd — 食物投射物
#
# 命中流程：
#   1. 生成 HitEffect 爆炸效果
#   2. 觸發全場 Hit Stop（約 3 幀，~0.05s）
#   3. 通知目標播放受擊動畫
#   4. 自身消失
# ===================================================

const SPEED              = 400.0
const LIFETIME           = 3.0
const SHOOTER_GRACE_TIME = 0.15
const PLAYER_KNOCKBACK   = 750.0   # 友火擊退力（誇張）
const RADIUS             = 12.0    # ↑ 放大（8→12）

# 尾跡參數
const TRAIL_STEPS   = 11
const TRAIL_SPACING = 8.5

const HIT_EFFECT_SCRIPT    = preload("res://scripts/hit_effect.gd")
const GREASE_PUDDLE_SCRIPT = preload("res://scripts/grease_puddle.gd")

# 子彈飛行超過此時間未命中 → 落地變成滑地
const PUDDLE_SPAWN_TIME = 2.0

var direction : Vector2 = Vector2.RIGHT
var shooter             = null

var _lifetime        : float = 0.0
var _grace_timer     : float = SHOOTER_GRACE_TIME
var _can_hit_shooter : bool  = false
var _dead            : bool  = false   # 防止 body_entered 重複觸發

# ── 靜態 hit stop 狀態（全部 projectile 共享）──────
static var _hit_stop_active : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_lifetime += delta

	if not _can_hit_shooter:
		_grace_timer -= delta
		if _grace_timer <= 0.0:
			_can_hit_shooter = true

	# 飛行 2 秒未命中 → 落地生成滑溜水漬
	if not _dead and _lifetime >= PUDDLE_SPAWN_TIME:
		_dead = true
		_spawn_grease_puddle()
		queue_free()
		return

	if _lifetime >= LIFETIME:
		queue_free()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	position += direction * SPEED * delta

	if position.x < -80 or position.x > 1360 or position.y < -80 or position.y > 800:
		queue_free()


func _draw() -> void:
	var tail_dir = -direction.normalized()

	# ── 彗星尾跡（漸淡漸小）
	for i in range(TRAIL_STEPS):
		var t      = float(i + 1) / float(TRAIL_STEPS)
		var offset = tail_dir * float(i + 1) * TRAIL_SPACING
		var alpha  = (1.0 - t) * 0.70
		var size   = RADIUS * (1.0 - t * 0.65)
		var g_col  = lerp(0.72, 0.1, t)
		draw_circle(offset, size, Color(1.0, g_col, 0.0, alpha))

	# ── 主體（最前、最亮）
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.92, 0.1))
	# 光暈環
	draw_arc(Vector2.ZERO, RADIUS + 2.0, 0.0, TAU, 20, Color(1.0, 0.6, 0.0, 0.5), 3.0)
	draw_arc(Vector2.ZERO, RADIUS,        0.0, TAU, 20, Color(1.0, 0.4, 0.0, 1.0), 2.0)


# ── 碰撞處理 ─────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body == shooter and not _can_hit_shooter:
		return

	if body.is_in_group("enemies"):
		_dead = true
		_spawn_hit_effect()
		body.take_hit(direction.normalized())  # 傳入方向供飛出動畫
		_do_hit_stop_and_free()

	elif body.is_in_group("players"):
		_dead = true
		_spawn_hit_effect()
		body.apply_knockback(direction.normalized(), PLAYER_KNOCKBACK)
		_do_hit_stop_and_free()


# ── 生成爆炸效果 ──────────────────────────────────

func _spawn_hit_effect() -> void:
	var fx = Node2D.new()
	fx.set_script(HIT_EFFECT_SCRIPT)
	fx.global_position = global_position
	get_tree().current_scene.add_child(fx)


# ── 生成落地滑地 ──────────────────────────────────

func _spawn_grease_puddle() -> void:
	var puddle = Node2D.new()
	puddle.set_script(GREASE_PUDDLE_SCRIPT)
	puddle.global_position = global_position
	get_tree().current_scene.add_child(puddle)


# ── Hit Stop（全場暫停 ~3 幀）─────────────────────
# 使用 static 防止同幀多個命中重複觸發
# await get_tree().process_frame 不受 time_scale 影響，
# 保證即使 time_scale=0 仍能等待真實幀

func _do_hit_stop_and_free() -> void:
	# 隱藏自身，停止物理（但 coroutine 繼續跑）
	hide()
	set_physics_process(false)
	set_process(false)

	if not _hit_stop_active:
		_hit_stop_active = true
		Engine.time_scale = 0.0
		# 等待 3 個真實渲染幀（約 0.05s @ 60fps）
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		Engine.time_scale = 1.0
		_hit_stop_active = false

	queue_free()
