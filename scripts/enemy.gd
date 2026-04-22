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
const FLY_DECEL        = 1.3    # ↓ 2.2 → 1.3：減速更慢，飛得更遠
const FLY_STOP_THRESH  = 38.0   # ↓ 60 → 38：速度更低才停下
const CHAIN_TOUCH_DIST = RADIUS * 2.0 + 8.0   # 56px

# ── 連鎖碰撞參數（export 可在 Inspector 即時調整）──
@export_group("Chain Collision")
@export var chain_speed_ratio  : float = 0.84   # ↑ 0.72 → 0.84：每跳保留更多速度，鏈更長
@export var chain_player_ratio : float = 0.80   # NEW：敵人飛行速度 × 比例 → 玩家擊退力（速度越快推越狠）
@export var max_fly_speed      : float = 1800.0 # ← 擊飛速度上限（防止連鎖爆炸導致 NaN 瞬移）

# ── 安全限制（防止大量碰撞時速度爆棚或位置 NaN）──
@export_group("Safety Limits")
@export var max_fly_speed : float = 2800.0   # ← 擊飛速度上限（px/s）
@export var min_chain_speed : float = 20.0  # ← 低於此速度不再觸發連鎖

# ── 混亂移動參數 ─────────────────────────────────
const CHAOS_SPEED        = 130.0  # 混亂狀態移動速度（px/s）
const CHAOS_DURATION_MIN = 0.55   # 最短混亂時間（秒）
const CHAOS_DURATION_MAX = 1.0    # 最長混亂時間（秒）
const HIT_ANGLE_SPREAD   = 0.70   # 被擊方向隨機偏移（弧度，±40 度）

@export var push_power : float = 1.0
@export var complaint_value : int = 1

signal reach_center(complaint_delta: int)

var _sep_vel      : Vector2 = Vector2.ZERO
var _external_vel : Vector2 = Vector2.ZERO

# ── 受擊狀態 ──────────────────────────────────────
var _dying         : bool    = false
var _hit_vel       : Vector2 = Vector2.ZERO
var _spin_angle    : float   = 0.0
var _spin_speed    : float   = 0.0
var _fading        : bool    = false   # 是否已進入淡出（防重複觸發）
var _chain_hit_bodies : Array = []

# ── 混亂狀態（飛停後短暫失控）─────────────────────
var _chaotic       : bool    = false
var _chaos_timer   : float   = 0.0
var _chaos_vel     : Vector2 = Vector2.ZERO

# ── Juice：命中壓扁 ──────────────────────────────
var _display_scale : Vector2 = Vector2.ONE


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("small_enemies")
	queue_redraw()


func _physics_process(delta: float) -> void:
	# ── 安全性保護：NaN/Inf 偵測，防止 move_and_slide 瞬移 ──
	# 根本原因：連鎖碰撞在極端幀率下速度可能溢出為 NaN，
	# Godot 物理引擎在 NaN velocity 下會把 position 重置回 (0,0)（即生成點）
	if not is_finite(position.x) or not is_finite(position.y) \
	   or not is_finite(_hit_vel.x) or not is_finite(_hit_vel.y):
		queue_free()
		return

	# ── 混亂移動（飛停後短暫失控）────────────────────
	if _chaotic:
		_chaos_timer -= delta
		velocity = _chaos_vel
		move_and_slide()
		_spin_angle += _spin_speed * delta
		queue_redraw()
		if _chaos_timer <= 0.0:
			_chaotic = false
			_start_fade()
		return

	# ── 擊飛中 ────────────────────────────────────
	if _dying:
		_hit_vel = _hit_vel.limit_length(max_fly_speed)   # ← 防止連鎖速度爆棚
		_hit_vel    = _hit_vel.lerp(Vector2.ZERO, FLY_DECEL * delta)
		_hit_vel    = _hit_vel.limit_length(max_fly_speed)  # ← 速度上限，防連鎖爆炸
		_spin_angle += _spin_speed * delta
		_spin_speed  = _spin_speed * (1.0 - 3.5 * delta)
		velocity     = _hit_vel
		move_and_slide()

		# 飛行中撞到中央 → 直接進場（讓玩家的攻擊可能害敵人進場）
		if global_position.distance_to(MAP_CENTER) <= REACH_DIST:
			reach_center.emit(complaint_value)
			queue_free()
			return

		# 速度夠高才做連鎖（避免停下後還在偵測）
		if _hit_vel.length() > CHAIN_TOUCH_DIST:
			_check_chain_collision()

		# 速度低於閾值 → 進入短暫混亂狀態（不立刻消失）
		if not _fading and _hit_vel.length() < FLY_STOP_THRESH:
			_fading = true
			_chaotic = true
			_chaos_timer = randf_range(CHAOS_DURATION_MIN, CHAOS_DURATION_MAX)
			# 隨機朝向，有一定機率偏向中央（增加「害敵人進場」機率）
			var rand_angle = randf_range(0.0, TAU)
			var chaos_dir  = Vector2(cos(rand_angle), sin(rand_angle))
			# 30% 機率強制偏向中央方向
			if randf() < 0.30:
				chaos_dir = (MAP_CENTER - global_position).normalized()
			_chaos_vel = chaos_dir * CHAOS_SPEED

		queue_redraw()
		return

	# ── 正常移動 ──────────────────────────────────
	var to_center = MAP_CENTER - global_position

	if to_center.length() <= REACH_DIST:
		reach_center.emit(complaint_value)
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
	var spd = _hit_vel.length()
	# 速度不足或方向 NaN → 跳過，避免傳入無效向量造成瞬移
	if spd < min_chain_speed or not _hit_vel.is_finite():
		return

	var dir = _hit_vel / spd   # 手動正規化，避免 length ≈ 0 時 normalized() 回傳 NaN

	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or _chain_hit_bodies.has(other):
			continue
		if global_position.distance_to(other.global_position) < CHAIN_TOUCH_DIST:
			_chain_hit_bodies.append(other)
			other.take_hit(dir, spd * chain_speed_ratio)

	for player in get_tree().get_nodes_in_group("players"):
		if _chain_hit_bodies.has(player):
			continue
		if global_position.distance_to(player.global_position) < RADIUS + 24.0 + 8.0:
			_chain_hit_bodies.append(player)
			# 速度比例：飛得越快推玩家越狠
			player.apply_knockback(dir, spd * chain_player_ratio)


# ── 狀態健全度檢查（防 NaN 瞬移）────────────────────

func _is_state_safe() -> bool:
	if not is_finite(position.x) or not is_finite(position.y):
		return false
	if not _hit_vel.is_finite():
		_hit_vel = Vector2.ZERO   # 嘗試自救：清零速度
		return true               # 位置還好就繼續活著
	return true


# ── 淡出消失（速度停下後才呼叫）────────────────────

func _start_fade() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1.0, 0.3, 0.3, 0.0), 0.22)
	tw.tween_callback(queue_free)


func _draw() -> void:
	draw_set_transform(Vector2(2.0, RADIUS * 0.82), 0.0, Vector2(0.88, 0.22))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_set_transform(Vector2.ZERO, _spin_angle, _display_scale)
	draw_circle(Vector2.ZERO, RADIUS, COLOR_BODY)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, COLOR_OUTLINE, 2.5)
	draw_circle(Vector2(-7.0, -6.0), 4.5, Color.BLACK)
	draw_circle(Vector2( 7.0, -6.0), 4.5, Color.BLACK)
	draw_arc(Vector2.ZERO, 10.0, deg_to_rad(20), deg_to_rad(160), 14, Color.BLACK, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 供 projectile.gd 呼叫：被食物命中 ───────────

func take_hit(hit_dir: Vector2 = Vector2.RIGHT, hit_speed: float = 420.0, _attacker_id: int = 0) -> void:
	# ── 參數安全檢查：非有限值或零向量直接跳過，防止 NaN 傳播造成瞬移 ──
	if not hit_dir.is_finite() or hit_dir.length_squared() < 0.0001:
		return
	if not is_finite(hit_speed) or hit_speed <= 0.0:
		return

	# 已在飛行中：跳過（連鎖已由 _chain_hit_bodies 保護）
	# 混亂中允許重新被擊：讓被推進來的敵人可以再被打出去
	if _dying and not _chaotic:
		return

	# 輸入防衛：方向或速度無效時直接丟棄（防止 NaN 從 chain 傳入）
	if not is_finite(hit_dir.x) or not is_finite(hit_dir.y) or not is_finite(hit_speed):
		return

	_dying  = true
	_fading = false
	_chaotic = false
	_chain_hit_bodies.clear()

	# 速度上限：防止連鎖爆炸累積過高速度
	hit_speed = clamp(hit_speed, 0.0, max_fly_speed)

	# 加入隨機角度偏移（±40 度），讓撞飛方向無法完全預測
	var spread = randf_range(-HIT_ANGLE_SPREAD, HIT_ANGLE_SPREAD)
	var safe_dir = hit_dir if hit_dir.length_squared() > 0.001 else Vector2.RIGHT
	_hit_vel = safe_dir.normalized().rotated(spread) * hit_speed

	var sign = 1.0 if randf() > 0.5 else -1.0
	_spin_speed = sign * randf_range(10.0, 18.0)   # 更快的旋轉，視覺更誇張

	# 立刻白閃（命中瞬間回饋），保持不透明直到速度停下
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(3.5, 3.5, 3.5, 1.0), 0.03)   # 白閃
	tw.tween_property(self, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.08) # 回到紅色，仍不透明

	# 壓扁動畫（與玩家同一套 hit pipeline）
	_display_scale = Vector2.ONE
	var sq = create_tween()
	sq.tween_property(self, "_display_scale", Vector2(1.90, 0.32), 0.04)
	sq.tween_property(self, "_display_scale", Vector2(0.60, 1.60), 0.08)
	sq.tween_property(self, "_display_scale", Vector2(1.15, 0.85), 0.08)
	sq.tween_property(self, "_display_scale", Vector2(1.0,  1.0),  0.10)


# ── 供滑地 / 外力使用 ─────────────────────────────

func apply_push(dir: Vector2, force: float) -> void:
	_external_vel = (_external_vel + dir * force).limit_length(300.0)
