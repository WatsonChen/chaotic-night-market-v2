extends CharacterBody2D

# ===================================================
# big_enemy.gd — 大型饕客
#
# 合作破防機制：
#   第一擊 → 「踉蹌」狀態：速度降低、小幅後退、橙色脈衝外環提示
#   第二擊（HIT_WINDOW 秒內）→ 「破防」：高速擊飛 + 大範圍連鎖
#   超過時間窗口未能補刀 → 自動恢復正常行走
#
# ── 可調整參數（快速調整區）────────────────────────────
#   BIG_RADIUS          體型半徑（px）           ← 目前 40
#   SPEED               移動速度（px/s）          ← 目前 65
#   PLAYER_PUSH_ACCEL   對玩家的推力加速度         ← 目前 1100
#   HIT_WINDOW          合作擊退時間窗口（秒）     ← 目前 2.5
#   STAGGER_SPEED_MULT  踉蹌期間速度倍率          ← 目前 0.35
#   STAGGER_PUSH_RATIO  第一擊後退比例            ← 目前 0.22
#   BREAK_SPEED_MULT    破防擊飛速度倍率          ← 目前 1.4
#   BREAK_CHAIN_DIST    破防連鎖偵測距離（px）     ← 目前 92
#   CHAIN_PLAYER_FORCE  破防連鎖對玩家擊退力      ← 目前 700
# ===================================================

const MAP_CENTER    = Vector2(640.0, 360.0)
const REACH_DIST    = 36.0

# ── 體型與移動（快速調整區）──────────────────────
const BIG_RADIUS         = 40.0    # ← 調這裡改體型
const SPEED              = 65.0    # ← 調這裡改移動速度
const PLAYER_PUSH_ACCEL  = 1100.0  # ← 調這裡改對玩家的推力
const SELF_PUSH_RATIO    = 0.20
const PUSH_RADIUS        = 96.0    # 推力偵測範圍（px）
const SEP_RADIUS         = 80.0    # 同伴分離力範圍
const SEP_FORCE          = 80.0    # 同伴分離力

# ── 合作破防（快速調整區）────────────────────────
const HIT_WINDOW         = 2.5    # ← 調這裡改合作時間窗口（秒）
const STAGGER_SPEED_MULT = 0.35   # ← 調這裡改踉蹌期間速度（0=完全停下）
const STAGGER_PUSH_RATIO = 0.22   # ← 調這裡改第一擊後退比例
const BREAK_SPEED_MULT   = 1.4    # ← 調這裡改破防擊飛速度倍率

# ── 擊飛與連鎖（快速調整區）─────────────────────
const FLY_DECEL          = 1.0    # ← 調這裡改擊飛減速率（越小飛越遠）
const FLY_STOP_THRESH    = 35.0   # ← 調這裡改飛停速度閾值（px/s）
const BREAK_CHAIN_DIST   = BIG_RADIUS * 2.0 + 12.0   # 92 px
const CHAIN_SPEED_RATIO  = 0.68   # ← 調這裡改連鎖速度遞減比例
const CHAIN_PLAYER_FORCE = 700.0  # ← 調這裡改連鎖對玩家的擊退力
const HIT_ANGLE_SPREAD   = 0.45   # 被擊方向隨機偏移（弧度，±26 度）

# ── 外觀色彩 ─────────────────────────────────────
const COLOR_BODY    = Color(0.50, 0.02, 0.72)   # 深紫
const COLOR_OUTLINE = Color(0.82, 0.40, 1.00)   # 亮紫外框
const COLOR_STAGGER = Color(1.00, 0.55, 0.00)   # 踉蹌時橙色

signal reach_center

var _sep_vel      : Vector2 = Vector2.ZERO
var _external_vel : Vector2 = Vector2.ZERO

# ── 合作破防狀態 ─────────────────────────────────
var _stagger       : bool    = false
var _stagger_timer : float   = 0.0
var _stagger_vel   : Vector2 = Vector2.ZERO   # 第一擊後退速度
var _stagger_pulse : float   = 0.0            # 脈衝動畫計時

# ── 擊飛狀態 ──────────────────────────────────────
var _dying            : bool    = false
var _hit_vel          : Vector2 = Vector2.ZERO
var _fading           : bool    = false
var _chain_hit_bodies : Array   = []
var _spin_angle       : float   = 0.0
var _spin_speed       : float   = 0.0

# ── Juice：壓扁 ───────────────────────────────────
var _display_scale : Vector2 = Vector2.ONE


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()


func _physics_process(delta: float) -> void:
	# ── 擊飛中 ────────────────────────────────────
	if _dying:
		_hit_vel    = _hit_vel.lerp(Vector2.ZERO, FLY_DECEL * delta)
		_spin_angle += _spin_speed * delta
		_spin_speed  = _spin_speed * (1.0 - 3.0 * delta)
		velocity     = _hit_vel
		move_and_slide()

		# 飛行撞到中央 → 直接進場
		if global_position.distance_to(MAP_CENTER) <= REACH_DIST:
			reach_center.emit()
			queue_free()
			return

		if _hit_vel.length() > BREAK_CHAIN_DIST:
			_check_chain_collision()

		if not _fading and _hit_vel.length() < FLY_STOP_THRESH:
			_fading = true
			_start_fade()

		queue_redraw()
		return

	# ── 踉蹌中 ────────────────────────────────────
	if _stagger:
		_stagger_timer -= delta
		_stagger_pulse += delta * 7.0
		_stagger_vel    = _stagger_vel.lerp(Vector2.ZERO, 6.0 * delta)

		var to_center = MAP_CENTER - global_position
		if to_center.length() <= REACH_DIST:
			reach_center.emit()
			queue_free()
			return

		# 踉蹌期間仍朝中央緩行
		velocity = to_center.normalized() * SPEED * STAGGER_SPEED_MULT + _stagger_vel
		move_and_slide()

		if _stagger_timer <= 0.0:
			_stagger = false   # 時間窗口結束，恢復正常

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
			var strength = (1.0 - dist / PUSH_RADIUS)
			player.apply_push(-diff.normalized(), PLAYER_PUSH_ACCEL * strength * delta)
			_sep_vel += diff.normalized() * PLAYER_PUSH_ACCEL * SELF_PUSH_RATIO * strength * delta

	velocity = to_center.normalized() * SPEED + _sep_vel + _external_vel
	move_and_slide()


# ── 連鎖碰撞（破防擊飛時）───────────────────────

func _check_chain_collision() -> void:
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or _chain_hit_bodies.has(other):
			continue
		if global_position.distance_to(other.global_position) < BREAK_CHAIN_DIST:
			_chain_hit_bodies.append(other)
			other.take_hit(_hit_vel.normalized(), _hit_vel.length() * CHAIN_SPEED_RATIO)

	for player in get_tree().get_nodes_in_group("players"):
		if _chain_hit_bodies.has(player):
			continue
		if global_position.distance_to(player.global_position) < BIG_RADIUS + 24.0 + 8.0:
			_chain_hit_bodies.append(player)
			player.apply_knockback(_hit_vel.normalized(), CHAIN_PLAYER_FORCE)


# ── 淡出消失 ─────────────────────────────────────

func _start_fade() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(0.6, 0.0, 0.8, 0.0), 0.35)
	tw.tween_callback(queue_free)


func _draw() -> void:
	# 陰影
	draw_set_transform(Vector2(4.0, BIG_RADIUS * 0.85), 0.0, Vector2(0.88, 0.18))
	draw_circle(Vector2.ZERO, BIG_RADIUS, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_set_transform(Vector2.ZERO, _spin_angle, _display_scale)

	# 主體
	draw_circle(Vector2.ZERO, BIG_RADIUS, COLOR_BODY)

	if _stagger:
		# 踉蹌：橙色脈衝外框 + 脈衝外環（提示「再一擊！」）
		var pulse = 0.5 + 0.5 * sin(_stagger_pulse)
		draw_arc(Vector2.ZERO, BIG_RADIUS, 0.0, TAU, 60,
			COLOR_STAGGER.lerp(Color.WHITE, pulse * 0.35), 5.0)
		# 脈衝外環：距離隨脈衝擴張，透明度淡入淡出
		var ring_r = BIG_RADIUS + 6.0 + pulse * 9.0
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 60,
			Color(COLOR_STAGGER.r, COLOR_STAGGER.g, COLOR_STAGGER.b, pulse * 0.80), 2.5)
	else:
		draw_arc(Vector2.ZERO, BIG_RADIUS, 0.0, TAU, 60, COLOR_OUTLINE, 3.0)

	# 眼睛（尺寸對應體型）
	draw_circle(Vector2(-11.0, -8.0), 6.5, Color.BLACK)
	draw_circle(Vector2( 11.0, -8.0), 6.5, Color.BLACK)
	draw_arc(Vector2.ZERO, 15.0, deg_to_rad(20), deg_to_rad(160), 16, Color.BLACK, 2.5)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 被命中 ───────────────────────────────────────

func take_hit(hit_dir: Vector2 = Vector2.RIGHT, hit_speed: float = 420.0) -> void:
	if _dying:
		return

	var spread      = randf_range(-HIT_ANGLE_SPREAD, HIT_ANGLE_SPREAD)
	var actual_dir  = hit_dir.rotated(spread)

	if _stagger:
		# 第二擊 → 破防擊飛
		_stagger       = false
		_stagger_timer = 0.0
		_do_break(actual_dir, hit_speed)
	else:
		# 第一擊 → 踉蹌
		_do_stagger(actual_dir, hit_speed)


func _do_stagger(hit_dir: Vector2, hit_speed: float) -> void:
	_stagger       = true
	_stagger_timer = HIT_WINDOW
	_stagger_pulse = 0.0
	# 小幅後退：讓玩家感受到命中有效果
	_stagger_vel   = hit_dir * hit_speed * STAGGER_PUSH_RATIO

	# 橙色閃光（有別於普通敵人的白閃，讓玩家知道「不一樣」）
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(3.0, 1.5, 0.2, 1.0), 0.03)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)

	# 輕度壓扁
	_display_scale = Vector2.ONE
	var sq = create_tween()
	sq.tween_property(self, "_display_scale", Vector2(1.55, 0.52), 0.05)
	sq.tween_property(self, "_display_scale", Vector2(0.75, 1.38), 0.09)
	sq.tween_property(self, "_display_scale", Vector2(1.0,  1.0),  0.10)


func _do_break(hit_dir: Vector2, hit_speed: float) -> void:
	_dying            = true
	_fading           = false
	_chain_hit_bodies.clear()

	_hit_vel = hit_dir * hit_speed * BREAK_SPEED_MULT

	var sign = 1.0 if randf() > 0.5 else -1.0
	_spin_speed = sign * randf_range(7.0, 13.0)

	# 強烈白閃（破防感）
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(5.0, 5.0, 5.0, 1.0), 0.02)
	tw.tween_property(self, "modulate", Color(1.2, 0.4, 1.5, 1.0), 0.12)

	# 誇張壓扁（比普通敵人更大）
	_display_scale = Vector2.ONE
	var sq = create_tween()
	sq.tween_property(self, "_display_scale", Vector2(2.30, 0.22), 0.04)
	sq.tween_property(self, "_display_scale", Vector2(0.50, 1.85), 0.09)
	sq.tween_property(self, "_display_scale", Vector2(1.25, 0.80), 0.08)
	sq.tween_property(self, "_display_scale", Vector2(1.0,  1.0),  0.10)


func apply_push(dir: Vector2, force: float) -> void:
	_external_vel = (_external_vel + dir * force).limit_length(200.0)
