extends CharacterBody2D

# ===================================================
# player.gd — 玩家控制
#
# P1（player_index=1）：橘色圓形
#   移動：WASD  |  瞄準：滑鼠  |  射擊：左鍵
#
# P2（player_index=2）：藍色圓形
#   移動：IJKL  |  瞄準：移動方向  |  射擊：Space
#
# 速度合成：主動移動 + _knockback（投射物擊退）+ _push（饕客推擠）
# ===================================================

@export var player_index : int = 1

const SPEED            = 200.0
const RADIUS           = 24.0   # ↑ 1.5x（16→24）
const SHOOT_COOLDOWN   = 0.30
const KNOCKBACK_DECAY  = 8.0
const PUSH_DECAY       = 5.0
const PUSH_MAX         = 280.0

# 可活動的 arena 邊界（與 main.gd 的 ARENA 一致）
const ARENA_X_MIN = 160.0
const ARENA_X_MAX = 1120.0
const ARENA_Y_MIN = 100.0
const ARENA_Y_MAX = 620.0

const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")

var _color : Color:
	get: return Color(1.0, 0.50, 0.05) if player_index == 1 else Color(0.2, 0.55, 1.0)

var _facing    : Vector2 = Vector2.RIGHT
var _shoot_cd  : float   = 0.0
var _knockback : Vector2 = Vector2.ZERO   # 投射物擊退（大衝量）
var _push      : Vector2 = Vector2.ZERO   # 饕客推擠（連續小力）


func _ready() -> void:
	add_to_group("players")
	queue_redraw()


func _process(delta: float) -> void:
	_shoot_cd -= delta

	if player_index == 1:
		if Input.is_action_pressed("p1_shoot") and _shoot_cd <= 0.0:
			_shoot((get_global_mouse_position() - global_position).normalized())
			_shoot_cd = SHOOT_COOLDOWN
	else:
		if Input.is_action_pressed("p2_shoot") and _shoot_cd <= 0.0:
			_shoot(_facing)
			_shoot_cd = SHOOT_COOLDOWN


func _physics_process(delta: float) -> void:
	var dir = Vector2.ZERO

	if player_index == 1:
		if Input.is_action_pressed("p1_up"):    dir.y -= 1.0
		if Input.is_action_pressed("p1_down"):  dir.y += 1.0
		if Input.is_action_pressed("p1_left"):  dir.x -= 1.0
		if Input.is_action_pressed("p1_right"): dir.x += 1.0
		var to_mouse = get_global_mouse_position() - global_position
		if to_mouse.length_squared() > 1.0:
			_facing = to_mouse.normalized()
	else:
		if Input.is_action_pressed("p2_up"):    dir.y -= 1.0
		if Input.is_action_pressed("p2_down"):  dir.y += 1.0
		if Input.is_action_pressed("p2_left"):  dir.x -= 1.0
		if Input.is_action_pressed("p2_right"): dir.x += 1.0
		if dir != Vector2.ZERO:
			_facing = dir.normalized()

	if dir != Vector2.ZERO:
		dir = dir.normalized()

	# 衰減兩種外力（速率不同，knockback 衰減快、push 衰減慢）
	_knockback = _knockback.lerp(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	_push      = _push.lerp(Vector2.ZERO,      PUSH_DECAY      * delta)

	velocity = dir * SPEED + _knockback + _push
	move_and_slide()

	# 限制在 arena 範圍內
	position.x = clamp(position.x, ARENA_X_MIN + RADIUS, ARENA_X_MAX - RADIUS)
	position.y = clamp(position.y, ARENA_Y_MIN + RADIUS, ARENA_Y_MAX - RADIUS)

	queue_redraw()


func _draw() -> void:
	# ── 底部橢圓陰影
	draw_set_transform(Vector2(3.0, RADIUS * 0.88), 0.0, Vector2(0.90, 0.22))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 主體圓形
	draw_circle(Vector2.ZERO, RADIUS, _color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color.WHITE, 2.5)

	# 面朝方向指示線（隨尺寸拉長）
	draw_line(Vector2.ZERO, _facing * (RADIUS + 12.0), Color.WHITE, 3.0)

	# 玩家識別：P1 = 白點（大），P2 = 白色方塊（大）
	if player_index == 1:
		draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
	else:
		draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), Color.WHITE)


# ── 供 enemy.gd 呼叫：饕客推擠（連續軟力）────────
# 每幀呼叫，force 已包含 delta，等效於加速度積分

func apply_push(dir: Vector2, force: float) -> void:
	_push = (_push + dir * force).limit_length(PUSH_MAX)


# ── 供 projectile.gd 呼叫：投射物擊退（大衝量）──

func apply_knockback(dir: Vector2, force: float) -> void:
	_knockback += dir * force


# ── 發射食物投射物 ────────────────────────────────

func _shoot(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return

	var proj = PROJECTILE_SCENE.instantiate()
	proj.direction = dir.normalized()
	proj.shooter   = self

	var container = get_tree().current_scene.get_node_or_null("Projectiles")
	if container == null:
		return
	container.add_child(proj)
	proj.global_position = global_position + dir.normalized() * (RADIUS + 10.0)
