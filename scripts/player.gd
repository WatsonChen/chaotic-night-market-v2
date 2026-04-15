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
# 受擊 Juice：
#   - 昏厥 0.3s（無法移動、射擊）
#   - 顯示旋轉（_spin_angle，用 draw_set_transform，不影響碰撞）
#   - 壓扁彈回（_display_scale，Tween 驅動）
# ===================================================

@export var player_index : int = 1

const SPEED            = 200.0
const RADIUS           = 24.0
const SHOOT_COOLDOWN   = 0.30
const KNOCKBACK_DECAY  = 6.5    # ← 數字越小飛越遠（衰減越慢）
const PUSH_DECAY       = 5.0
const PUSH_MAX         = 280.0

const STUN_DURATION    = 0.38    # ← 調這裡改昏厥時間（秒）
const SPIN_SPEED_DEG   = 1050.0  # ← 調這裡改旋轉速度（度/秒）

const ARENA_X_MIN = 160.0
const ARENA_X_MAX = 1120.0
const ARENA_Y_MIN = 100.0
const ARENA_Y_MAX = 620.0

const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")

var _color : Color:
	get: return Color(1.0, 0.50, 0.05) if player_index == 1 else Color(0.2, 0.55, 1.0)

var _facing         : Vector2 = Vector2.RIGHT
var _shoot_cd       : float   = 0.0
var _knockback      : Vector2 = Vector2.ZERO
var _push           : Vector2 = Vector2.ZERO

# ── Juice 狀態 ────────────────────────────────────
var _stun_timer     : float   = 0.0         # 昏厥倒數
var _spin_angle     : float   = 0.0         # 顯示旋轉角度（弧度）
var _display_scale  : Vector2 = Vector2.ONE  # 壓扁彈回 scale（Tween 驅動）


func _ready() -> void:
	add_to_group("players")
	queue_redraw()


func _process(delta: float) -> void:
	_shoot_cd -= delta

	# 昏厥中禁止射擊
	if _stun_timer > 0.0:
		return

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

	# ── 昏厥：累計旋轉角度，方向鍵失效 ────────────
	if _stun_timer > 0.0:
		_stun_timer -= delta
		# 轉速隨昏厥剩餘時間衰減，結束前慢下來更有感
		var spin_ratio = clamp(_stun_timer / STUN_DURATION, 0.0, 1.0)
		_spin_angle += deg_to_rad(SPIN_SPEED_DEG * spin_ratio) * delta
		# 昏厥結束時歸位（避免殘留角度）
		if _stun_timer <= 0.0:
			_spin_angle = 0.0
	else:
		# ── 正常移動與瞄準 ──────────────────────
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

	_knockback = _knockback.lerp(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	_push      = _push.lerp(Vector2.ZERO,      PUSH_DECAY      * delta)

	velocity = dir * SPEED + _knockback + _push
	move_and_slide()

	position.x = clamp(position.x, ARENA_X_MIN + RADIUS, ARENA_X_MAX - RADIUS)
	position.y = clamp(position.y, ARENA_Y_MIN + RADIUS, ARENA_Y_MAX - RADIUS)

	queue_redraw()


func _draw() -> void:
	# ── 底部橢圓陰影（不跟隨旋轉）
	draw_set_transform(Vector2(3.0, RADIUS * 0.90), 0.0, Vector2(0.92, 0.20))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.0, 0.0, 0.0, 0.50))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── 主體（套用旋轉 + 壓扁 scale）
	draw_set_transform(Vector2.ZERO, _spin_angle, _display_scale)

	# 昏厥中閃爍：稍微調亮顏色作為受傷提示
	var body_color = _color
	if _stun_timer > 0.0:
		var flash = 0.5 + 0.5 * sin(_stun_timer * 60.0)  # 快速閃爍
		body_color = body_color.lerp(Color.WHITE, flash * 0.55)

	draw_circle(Vector2.ZERO, RADIUS, body_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color.WHITE, 2.5)
	draw_line(Vector2.ZERO, _facing * (RADIUS + 12.0), Color.WHITE, 3.0)

	if player_index == 1:
		draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
	else:
		draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), Color.WHITE)

	# 重置繪製變換
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 供 enemy.gd 呼叫：饕客軟推擠 ────────────────

func apply_push(dir: Vector2, force: float) -> void:
	_push = (_push + dir * force).limit_length(PUSH_MAX)


# ── 供 projectile.gd 呼叫：友火擊退 + 昏厥 ──────

func apply_knockback(dir: Vector2, force: float) -> void:
	_knockback += dir * force
	_start_hit_reaction()


func _start_hit_reaction() -> void:
	# 昏厥計時器重置（可連續被打）
	_stun_timer  = STUN_DURATION
	_spin_angle  = 0.0

	# 壓扁彈回動畫（Tween 驅動 _display_scale）
	# 數值說明：Vector2(橫向, 縱向)，1.0 = 原始大小
	var tw = create_tween()
	tw.tween_property(self, "_display_scale", Vector2(2.10, 0.28), 0.05)   # 衝擊壓扁（誇張）
	tw.tween_property(self, "_display_scale", Vector2(0.55, 1.70), 0.09)   # 縱向彈出
	tw.tween_property(self, "_display_scale", Vector2(1.20, 0.82), 0.09)   # 二次壓
	tw.tween_property(self, "_display_scale", Vector2(0.90, 1.12), 0.07)   # 三次回
	tw.tween_property(self, "_display_scale", Vector2(1.0,  1.0),  0.09)   # 歸位


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
	proj.global_position = global_position + dir.normalized() * (RADIUS + 14.0)
