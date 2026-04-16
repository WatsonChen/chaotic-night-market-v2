extends CharacterBody2D

# ===================================================
# enemy.gd — 普通饕客（敵人）
#
# 命中後流程：
#   1. 立刻白色閃光（視覺回饋）
#   2. 高速飛出（FLY_SPEED），移動過程維持碰撞判定
#   3. 飛行中掃描周圍，連鎖推開敵人與玩家
#   4. 速度低於 FLY_STOP_THRESH 後才開始淡出消失
#
# ── 可調整擊飛參數 ──────────────────────────────────
#   FLY_DECEL         減速率（越小飛越遠）    ← 目前 2.2
#   FLY_STOP_THRESH   開始淡出的速度閾值      ← 目前 60 px/s
#   CHAIN_TOUCH_DIST  連鎖碰撞判定距離        ← 目前 56 px
#   CHAIN_SPEED_RATIO 連鎖速度遞減比例        ← 目前 0.62
#   CHAIN_PLAYER_FORCE 連鎖對玩家的擊退力     ← 目前 380
# ===================================================

const MAP_CENTER    = Vector2(640.0, 360.0)
const SPEED         = 100.0
const REACH_DIST    = 36.0
const RADIUS        = 24.0
const COLOR_BODY    = Color(0.88, 0.15, 0.15)
const COLOR_OUTLINE = Color(1.0,  0.55, 0.55)

# ── 軟碰撞（正常移動時）─────────────────────────
const PUSH_RADIUS       = 68.0
const PLAYER_PUSH_ACCEL = 700.0
const SELF_PUSH_RATIO   = 0.22
const SEP_RADIUS        = 56.0
const SEP_FORCE         = 120.0

# ── 擊飛參數（快速調整區）────────────────────────
const FLY_DECEL          = 2.2    # ← 調這裡改減速率（越小飛越遠）
const FLY_STOP_THRESH    = 60.0   # ← 調這裡改速度低於多少才開始淡出（px/s）
const CHAIN_TOUCH_DIST   = RADIUS * 2.0 + 8.0   # 56px
const CHAIN_SPEED_RATIO  = 0.62   # ← 調這裡改連鎖速度遞減比例
const CHAIN_PLAYER_FORCE = 380.0  # ← 調這裡改連鎖對玩家的擊退力

@export var push_power : float = 1.0

signal reach_center

var _sep_vel      : Vector2 = Vector2.ZERO
var _external_vel : Vector2 = Vector2.ZERO

# ── 受擊狀態 ──────────────────────────────────────
var _dying         : bool    = false
var _hit_vel       : Vector2 = Vector2.ZERO
var _spin_angle    : float   = 0.0
var _spin_speed    : float   = 0.0
var _fading        : bool    = false   # 是否已進入淡出（防重複觸發）
var _chain_hit_bodies : Array = []


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()


func _physics_process(delta: float) -> void:
	# ── 擊飛中 ────────────────────────────────────
	if _dying:
		_hit_vel    = _hit_vel.lerp(Vector2.ZERO, FLY_DECEL * delta)
		_spin_angle += _spin_speed * delta
		_spin_speed  = _spin_speed * (1.0 - 3.5 * delta)
		velocity     = _hit_vel
		move_and_slide()

		# 速度夠高才做連鎖（避免停下後還在偵測）
		if _hit_vel.length() > CHAIN_TOUCH_DIST:
			_check_chain_collision()

		# 速度低於閾值 → 開始淡出（只觸發一次）
		if not _fading and _hit_vel.length() < FLY_STOP_THRESH:
			_fading = true
			_start_fade()

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

	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var diff : Vector2 = global_position - other.global_position
		var dist : float   = diff.length()
		if dist < SEP_RADIUS and dist > 0.5:
			_sep_vel += diff.normalized() * SEP_FORCE * (1.0 - dist / SEP_RADIUS)

	for player in get_tree().get_nodes_in_group("players"):
		var diff : Vector2 = global_position - player.global_position
		var dist : float   = diff.length()
		if dist < PUSH_RADIUS and dist > 0.5:
			var strength = (1.0 - dist / PUSH_RADIUS) * push_power
			player.apply_push(-diff.normalized(), PLAYER_PUSH_ACCEL * strength * delta)
			_sep_vel += diff.normalized() * PLAYER_PUSH_ACCEL * SELF_PUSH_RATIO * strength * delta

	velocity = to_center.normalized() * SPEED + _sep_vel + _external_vel
	move_and_slide()


# ── 連鎖碰撞偵測 ─────────────────────────────────

func _check_chain_collision() -> void:
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or _chain_hit_bodies.has(other):
			continue
		if global_position.distance_to(other.global_position) < CHAIN_TOUCH_DIST:
			_chain_hit_bodies.append(other)
			other.take_hit(_hit_vel.normalized(), _hit_vel.length() * CHAIN_SPEED_RATIO)

	for player in get_tree().get_nodes_in_group("players"):
		if _chain_hit_bodies.has(player):
			continue
		if global_position.distance_to(player.global_position) < RADIUS + 24.0 + 8.0:
			_chain_hit_bodies.append(player)
			player.apply_knockback(_hit_vel.normalized(), CHAIN_PLAYER_FORCE)


# ── 淡出消失（速度停下後才呼叫）────────────────────

func _start_fade() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1.0, 0.3, 0.3, 0.0), 0.22)
	tw.tween_callback(queue_free)


func _draw() -> void:
	draw_set_transform(Vector2(2.0, RADIUS * 0.82), 0.0, Vector2(0.88, 0.22))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_set_transform(Vector2.ZERO, _spin_angle, Vector2.ONE)
	draw_circle(Vector2.ZERO, RADIUS, COLOR_BODY)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, COLOR_OUTLINE, 2.5)
	draw_circle(Vector2(-7.0, -6.0), 4.5, Color.BLACK)
	draw_circle(Vector2( 7.0, -6.0), 4.5, Color.BLACK)
	draw_arc(Vector2.ZERO, 10.0, deg_to_rad(20), deg_to_rad(160), 14, Color.BLACK, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 供 projectile.gd 呼叫：被食物命中 ───────────

func take_hit(hit_dir: Vector2 = Vector2.RIGHT, hit_speed: float = 420.0) -> void:
	if _dying:
		return
	_dying = true
	_fading = false
	_chain_hit_bodies.clear()

	_hit_vel = hit_dir * hit_speed

	var sign = 1.0 if randf() > 0.5 else -1.0
	_spin_speed = sign * randf_range(10.0, 18.0)   # 更快的旋轉，視覺更誇張

	# 立刻白閃（命中瞬間回饋），保持不透明直到速度停下
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(3.5, 3.5, 3.5, 1.0), 0.03)   # 白閃
	tw.tween_property(self, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.08) # 回到紅色，仍不透明


# ── 供滑地 / 外力使用 ─────────────────────────────

func apply_push(dir: Vector2, force: float) -> void:
	_external_vel = (_external_vel + dir * force).limit_length(300.0)
