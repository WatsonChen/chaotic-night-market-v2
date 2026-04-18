extends Area2D

# ===================================================
# projectile.gd — 食物投射物
#
# 所有數值由 player.gd 生成時注入，本身不再有 const 規格。
# 這樣 P1/P2 可以完全不同的子彈，日後多角色也無需改架構。
#
# ── 由外部注入的參數（生成後、add_child 前設定）────
#   proj_radius        視覺 & 碰撞半徑
#   proj_speed         飛行速度（px/s）
#   player_knockback   命中玩家的擊退力
#   enemy_fly_speed    命中敵人的飛出速度（傳給 take_hit）
#   hit_stop_frames    命中後 hit stop 幀數
#   proj_color         主體顏色（Color）
# ===================================================

# ── 可注入參數（預設值 = 原始規格，未設定時行為不變）
var proj_radius          : float = 12.0
var proj_speed           : float = 400.0
var player_knockback     : float = 950.0
var enemy_fly_speed      : float = 420.0
var hit_stop_frames      : int   = 2
var proj_color           : Color = Color(1.0, 0.92, 0.1)

# ── 友火專屬（由 player.gd 注入）────────────────────
var ff_hit_stop_frames   : int   = 5    # ← 友火 hit stop 幀數（≈0.08s @ 60fps）
var ff_hit_effect_scale  : float = 1.5  # ← 友火爆炸特效倍率（150%）

const LIFETIME           = 3.0
const SHOOTER_GRACE_TIME = 0.15
const PUDDLE_SPAWN_TIME  = 1.0

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
	# 同步碰撞形狀半徑（場景預設 12，按注入值更新）
	var shape_node = get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape:
		shape_node.shape = shape_node.shape.duplicate()
		shape_node.shape.radius = proj_radius

	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_lifetime += delta

	if not _can_hit_shooter:
		_grace_timer -= delta
		if _grace_timer <= 0.0:
			_can_hit_shooter = true

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
	position += direction * proj_speed * delta

	if position.x < -80 or position.x > 1360 or position.y < -80 or position.y > 800:
		_dead = true
		_spawn_hit_effect(false, 0.28)
		queue_free()


func _draw() -> void:
	var tail_dir = -direction.normalized()
	# 尾跡長度隨 proj_speed 縮放（快的子彈尾跡更長）
	var steps   = int(clamp(proj_speed / 40.0, 6.0, 16.0))
	var spacing = proj_radius * 0.72

	for i in range(steps):
		var t      = float(i + 1) / float(steps)
		var offset = tail_dir * float(i + 1) * spacing
		var alpha  = (1.0 - t) * 0.72
		var size   = proj_radius * (1.0 - t * 0.65)
		# 尾跡顏色：往後漸深（保持主色系）
		var faded = proj_color.lerp(Color(proj_color.r, 0.0, 0.0, 0.0), t * 0.8)
		draw_circle(offset, size, Color(faded.r, faded.g * (1.0 - t * 0.85), 0.0, alpha))

	# 主體
	draw_circle(Vector2.ZERO, proj_radius, proj_color)
	draw_arc(Vector2.ZERO, proj_radius + 2.0, 0.0, TAU, 20,
		Color(proj_color.r, proj_color.g * 0.6, proj_color.b, 0.50), 3.0)
	draw_arc(Vector2.ZERO, proj_radius, 0.0, TAU, 20,
		Color(proj_color.r, proj_color.g * 0.3, proj_color.b, 1.00), 2.0)


# ── 碰撞處理 ─────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body == shooter and not _can_hit_shooter:
		return

	if body.is_in_group("enemies"):
		_dead = true
		_spawn_hit_effect(false, 1.0)
		var attacker_id = 0
		if shooter != null:
			attacker_id = int(shooter.get("player_index"))
		body.take_hit(direction.normalized(), enemy_fly_speed, attacker_id)
		_do_hit_stop_and_free(hit_stop_frames)

	elif body.is_in_group("players"):
		_dead = true
		_spawn_hit_effect(true, ff_hit_effect_scale)          # 友火特效放大
		body.apply_knockback(direction.normalized(), player_knockback)
		_do_hit_stop_and_free(ff_hit_stop_frames)              # 友火專屬 hit stop

func _spawn_hit_effect(is_player: bool, scale: float) -> void:
	var fx = Node2D.new()
	fx.set_script(HIT_EFFECT_SCRIPT)
	var parent = get_tree().current_scene.get_node_or_null("World")
	if parent == null:
		parent = get_tree().current_scene
	fx.is_player_hit = is_player
	fx.effect_scale  = scale * clamp(proj_radius / 12.0, 0.6, 1.6)  # 大子彈爆炸更大
	parent.add_child(fx)
	fx.global_position = global_position


func _spawn_grease_puddle() -> void:
	var puddle = Node2D.new()
	puddle.set_script(GREASE_PUDDLE_SCRIPT)
	var parent = get_tree().current_scene.get_node_or_null("World")
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(puddle)
	puddle.global_position = global_position


func _do_hit_stop_and_free(frames: int) -> void:
	hide()
	set_physics_process(false)
	set_process(false)

	if not _hit_stop_active:
		_hit_stop_active = true
		Engine.time_scale = 0.0
		for _i in frames:
			# scene 可能正在 reload：node 已離開樹，get_tree() 會回傳 null
			if not is_inside_tree():
				Engine.time_scale = 1.0
				_hit_stop_active = false   # 重置 static，避免重開後 hit stop 永遠鎖死
				return
			await get_tree().process_frame
		Engine.time_scale = 1.0
		_hit_stop_active = false

	if is_inside_tree():
		queue_free()
