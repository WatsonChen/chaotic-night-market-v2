extends Area2D

# ===================================================
# projectile.gd — 食物投射物
#
# 命中優先順序（視覺重量）：
#   玩家命中（最誇張） > 敵人命中 > 落地滑地 > 邊界消散（最弱）
#
# ── 可調整數值 ──────────────────────────────────────
#   PLAYER_KNOCKBACK   玩家被打飛的力度（目前 950）
#   PLAYER_HIT_STOP    玩家命中的 hit stop 幀數（目前 3 幀 ≈ 0.05s）
#   ENEMY_HIT_STOP     敵人命中的 hit stop 幀數（目前 2 幀 ≈ 0.033s）
#   PUDDLE_SPAWN_TIME  幾秒後未命中就落地（目前 1.0s）
# ===================================================

const SPEED              = 400.0
const LIFETIME           = 3.0
const SHOOTER_GRACE_TIME = 0.15
const PLAYER_KNOCKBACK   = 950.0   # ← 調這裡改友火擊退強度
const RADIUS             = 12.0

const PLAYER_HIT_STOP    = 3      # ← 調這裡改玩家命中 hit stop 幀數
const ENEMY_HIT_STOP     = 2      # ← 調這裡改敵人命中 hit stop 幀數

# 飛行超過此秒數未命中 → 在當下位置落地成滑地（出現在場地中央附近）
const PUDDLE_SPAWN_TIME  = 1.0    # ← 調這裡改落地時機（s）

const TRAIL_STEPS   = 11
const TRAIL_SPACING = 8.5

const HIT_EFFECT_SCRIPT    = preload("res://scripts/hit_effect.gd")
const GREASE_PUDDLE_SCRIPT = preload("res://scripts/grease_puddle.gd")

var direction : Vector2 = Vector2.RIGHT
var shooter             = null

var _lifetime        : float = 0.0
var _grace_timer     : float = SHOOTER_GRACE_TIME
var _can_hit_shooter : bool  = false
var _dead            : bool  = false

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

	# 飛行 1 秒未命中 → 落地生成滑地（在場地中央附近，不在邊界）
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

	# 超出畫面邊界 → 極小 fizzle，安靜消失
	if position.x < -80 or position.x > 1360 or position.y < -80 or position.y > 800:
		_dead = true
		_spawn_hit_effect(false, 0.28)   # fizzle scale = 0.28（極小）
		queue_free()


func _draw() -> void:
	var tail_dir = -direction.normalized()

	# ── 彗星尾跡（漸淡漸小）
	for i in range(TRAIL_STEPS):
		var t      = float(i + 1) / float(TRAIL_STEPS)
		var offset = tail_dir * float(i + 1) * TRAIL_SPACING
		var alpha  = (1.0 - t) * 0.72
		var size   = RADIUS * (1.0 - t * 0.65)
		var g_col  = lerp(0.72, 0.1, t)
		draw_circle(offset, size, Color(1.0, g_col, 0.0, alpha))

	# ── 主體
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.92, 0.1))
	draw_arc(Vector2.ZERO, RADIUS + 2.0, 0.0, TAU, 20, Color(1.0, 0.6, 0.0, 0.50), 3.0)
	draw_arc(Vector2.ZERO, RADIUS,        0.0, TAU, 20, Color(1.0, 0.4, 0.0, 1.00), 2.0)


# ── 碰撞處理 ─────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body == shooter and not _can_hit_shooter:
		return

	if body.is_in_group("enemies"):
		_dead = true
		_spawn_hit_effect(false, 1.0)          # 敵人命中：標準大小
		body.take_hit(direction.normalized())
		_do_hit_stop_and_free(ENEMY_HIT_STOP)

	elif body.is_in_group("players"):
		_dead = true
		_spawn_hit_effect(true, 1.0)           # 玩家命中：最誇張版本
		body.apply_knockback(direction.normalized(), PLAYER_KNOCKBACK)
		_do_hit_stop_and_free(PLAYER_HIT_STOP)


# ── 生成爆炸效果 ──────────────────────────────────
# is_player: 玩家命中傳 true（啟用大版本）
# scale:     傳 ≤ 0.35 → fizzle 模式（邊界退場用）

func _spawn_hit_effect(is_player: bool, scale: float) -> void:
	var fx = Node2D.new()
	fx.set_script(HIT_EFFECT_SCRIPT)
	# 在 add_child 前設定屬性（_ready 會用到）
	fx.set_meta("is_player_hit", is_player)
	fx.set_meta("effect_scale",  scale)
	fx.global_position = global_position
	get_tree().current_scene.add_child(fx)
	# add_child 後再把值同步給腳本變數（set_meta 只是暫存）
	fx.is_player_hit = is_player
	fx.effect_scale  = scale


# ── 生成落地滑地 ──────────────────────────────────

func _spawn_grease_puddle() -> void:
	var puddle = Node2D.new()
	puddle.set_script(GREASE_PUDDLE_SCRIPT)
	puddle.global_position = global_position
	get_tree().current_scene.add_child(puddle)


# ── Hit Stop ──────────────────────────────────────
# frames：暫停的真實渲染幀數（玩家 3，敵人 2，不同強度）

func _do_hit_stop_and_free(frames: int) -> void:
	hide()
	set_physics_process(false)
	set_process(false)

	if not _hit_stop_active:
		_hit_stop_active = true
		Engine.time_scale = 0.0
		for _i in frames:
			await get_tree().process_frame
		Engine.time_scale = 1.0
		_hit_stop_active = false

	queue_free()
