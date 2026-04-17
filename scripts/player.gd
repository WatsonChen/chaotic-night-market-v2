extends CharacterBody2D

# ===================================================
# player.gd — 玩家控制
#
# ── 角色設定（_ready 中依 player_index 初始化）──────
#
# P1 橘色「熱狗攤」
#   移動：WASD  |  瞄準：滑鼠  |  射擊：左鍵
#   風格：單發大顆、強擊退、較慢節奏。一發出事。
#
# P2 藍色「珍奶攤」
#   移動：IJKL  |  瞄準：移動方向  |  射擊：Space
#   風格：快速 burst 連射（每次 3 發）、小顆弱推、刷畫面。
#
# ── 未來多機分離說明 ────────────────────────────────
#   目前 P1/P2 共用一個腳本便於測試。
#   真正上線時只需讓每台機器的 player_index 固定為 1，
#   輸入改為搖桿/鍵盤 rebind 即可，架構無需大改。
# ===================================================

@export var player_index : int = 1

# ── 通用移動參數 ──────────────────────────────────
const SPEED           = 200.0
const RADIUS          = 24.0
const KNOCKBACK_DECAY = 3.8   # ↓ 從 6.5 降低：衰減更慢，飛得更遠
const KNOCKBACK_MAX   = 2800.0
const PUSH_DECAY      = 5.0
const PUSH_MAX        = 280.0
const STUN_DURATION   = 0.38
const SPIN_SPEED_DEG  = 1050.0

const ARENA_X_MIN = 160.0
const ARENA_X_MAX = 1120.0
const ARENA_Y_MIN = 100.0
const ARENA_Y_MAX = 620.0

const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")
const MAP_CENTER       = Vector2(640.0, 360.0)   # 需與 main.gd 一致

# ── 角色專屬攻擊參數（在 _ready 中依 player_index 填入）
# ┌──────────────────────────────────────────────────────┐
# │  P1 熱狗攤 — 大擊退 / 大事故型                        │
# ├──────────────────────┬───────────────────────────────┤
# │ shoot_cooldown  0.55 │ ← 發射間隔（秒）              │
# │ proj_radius    18.0  │ ← 子彈視覺 & 碰撞半徑         │
# │ proj_speed    320.0  │ ← 子彈飛行速度（px/s）        │
# │ proj_knockback 2200  │ ← 友火擊退力（玩家）          │
# │ proj_enemy_spd 1000  │ ← 打敵人飛出速度（px/s）      │
# │ proj_hit_stop    5   │ ← 命中凍結幀數                │
# └──────────────────────┴───────────────────────────────┘
#
# ┌──────────────────────────────────────────────────────┐
# │  P2 珍奶攤 — 高頻干擾 / 持續失控型                    │
# ├──────────────────────┬───────────────────────────────┤
# │ shoot_cooldown  0.42 │ ← burst 後冷卻（秒）          │
# │ burst_count       3  │ ← 每次連射發數                │
# │ burst_delay   0.075  │ ← 連射每發間隔（秒）          │
# │ proj_radius     7.0  │ ← 子彈視覺 & 碰撞半徑         │
# │ proj_speed    560.0  │ ← 子彈飛行速度（px/s）        │
# │ proj_knockback  850  │ ← 友火擊退力（玩家）          │
# │ proj_enemy_spd  500  │ ← 打敵人飛出速度（px/s）      │
# │ proj_hit_stop    2   │ ← 命中凍結幀數                │
# └──────────────────────┴───────────────────────────────┘
#
# 比值參考（P1 / P2）：
#   敵人飛出速度  1000 / 500  = 2.0×   ← 符合設計目標
#   友火擊退力   2200 / 850  = 2.6×   ← P2 burst×3 可追上
#   子彈半徑     18.0 / 7.0  = 2.6×   ← P1 碰撞面積大

# ── 中央壓力區（Pressure Zone）─────────────────────
# 數值由 main.gd 透過 zone_complaint_count 更新
@export_group("Pressure Zone")
@export var zone_radius         : float = 80.0   # ← 壓力區半徑（px，需與 food_court 的視覺圈一致）
@export var zone_slow_threshold : int   = 5      # ← 客訴達此數啟動減速
@export var zone_push_threshold : int   = 8      # ← 客訴達此數改為向外推力
@export var zone_slow_factor    : float = 0.50   # ← 減速倍率（0.5 = 降為一半速度）
@export var zone_push_force     : float = 150.0  # ← 向外推力（px/s）

var zone_complaint_count : int = 0   # 由 main.gd 每幀設定，不要手動改

var shoot_cooldown   : float = 0.30
var burst_count      : int   = 1      # =1 表示單發（P1 模式）
var burst_delay      : float = 0.0
var proj_radius      : float = 12.0
var proj_speed       : float = 400.0
var proj_knockback   : float = 950.0
var proj_enemy_speed : float = 420.0
var proj_hit_stop    : int   = 2
var proj_color       : Color = Color(1.0, 0.92, 0.1)

var _color : Color:
	get: return Color(1.0, 0.50, 0.05) if player_index == 1 else Color(0.2, 0.55, 1.0)

var _facing         : Vector2 = Vector2.RIGHT
var _shoot_cd       : float   = 0.0
var _knockback      : Vector2 = Vector2.ZERO
var _push           : Vector2 = Vector2.ZERO

# ── Juice 狀態 ────────────────────────────────────
var _stun_timer    : float   = 0.0
var _spin_angle    : float   = 0.0
var _display_scale : Vector2 = Vector2.ONE
var _hit_reaction_tween : Tween

# ── P2 burst 狀態 ─────────────────────────────────
var _burst_remaining : int   = 0
var _burst_timer     : float = 0.0
var _burst_dir       : Vector2 = Vector2.RIGHT  # burst 期間固定方向


func _ready() -> void:
	add_to_group("players")

	# ── 依角色設定攻擊參數 ────────────────────────
	if player_index == 1:
		# P1 熱狗攤：大顆慢發、強擊退 — 一發造成大事故
		shoot_cooldown   = 0.55
		burst_count      = 1
		proj_radius      = 18.0
		proj_speed       = 320.0
		proj_knockback   = 2200.0
		proj_enemy_speed = 1000.0
		proj_hit_stop    = 5
		proj_color       = Color(1.0, 0.75, 0.05)   # 橙黃

	else:
		# P2 珍奶攤：小顆高頻連射 burst — 累積干擾造成失控
		shoot_cooldown   = 0.42   # burst 後冷卻
		burst_count      = 3
		burst_delay      = 0.075  # 連射每發間隔
		proj_radius      = 7.0
		proj_speed       = 560.0
		proj_knockback   = 850.0
		proj_enemy_speed = 500.0
		proj_hit_stop    = 2
		proj_color       = Color(0.35, 0.85, 1.0)   # 青藍

	queue_redraw()


func _process(delta: float) -> void:
	_shoot_cd -= delta

	if _stun_timer > 0.0:
		return

	# ── P2 burst 連射處理 ──────────────────────────
	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_fire_projectile(_burst_dir)
			_burst_remaining -= 1
			_burst_timer = burst_delay
		return   # burst 進行中不接受新射擊指令

	# ── 一般射擊觸發 ──────────────────────────────
	if player_index == 1:
		if Input.is_action_pressed("p1_shoot") and _shoot_cd <= 0.0:
			var aim = (get_global_mouse_position() - global_position).normalized()
			_fire_projectile(aim)
			_shoot_cd = shoot_cooldown

	else:
		if Input.is_action_pressed("p2_shoot") and _shoot_cd <= 0.0:
			# P2：立刻射第 1 發，剩餘 burst_count-1 發排入佇列
			_burst_dir       = _facing
			_fire_projectile(_burst_dir)
			_burst_remaining = burst_count - 1
			_burst_timer     = burst_delay
			_shoot_cd        = shoot_cooldown


func _physics_process(delta: float) -> void:
	_sanitize_player_state()
	var dir = Vector2.ZERO

	if _stun_timer > 0.0:
		_stun_timer -= delta
		var spin_ratio = clamp(_stun_timer / STUN_DURATION, 0.0, 1.0)
		_spin_angle += deg_to_rad(SPIN_SPEED_DEG * spin_ratio) * delta
		if _stun_timer <= 0.0:
			_spin_angle = 0.0
	else:
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

	# ── 中央壓力區效果 ────────────────────────────────
	var zone_dist      = global_position.distance_to(MAP_CENTER)
	var effective_speed = SPEED
	if zone_dist < zone_radius:
		if zone_complaint_count >= zone_push_threshold:
			pass  # 推力在 velocity 算完後疊加
		elif zone_complaint_count >= zone_slow_threshold:
			effective_speed = SPEED * zone_slow_factor

	velocity = dir * effective_speed + _knockback + _push

	# 推力：在 zone 且達高壓階段，無論有無輸入都往外推
	if zone_dist < zone_radius and zone_complaint_count >= zone_push_threshold:
		var push_away = global_position - MAP_CENTER
		if push_away.length_squared() < 0.01:
			push_away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		velocity += push_away.normalized() * zone_push_force

	move_and_slide()

	# ── 擊退中高速撞飛敵人（連鎖效果）──────────────────
	# 只有擊退速度夠大才偵測，避免正常移動誤觸
	const KNOCKBACK_HIT_THRESH = 350.0
	const KNOCKBACK_HIT_RANGE  = RADIUS + 28.0   # 玩家半徑 + 敵人半徑 + 緩衝
	if _knockback.length() > KNOCKBACK_HIT_THRESH:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(enemy.global_position) < KNOCKBACK_HIT_RANGE:
				var fly_spd = _knockback.length() * 0.55
				enemy.take_hit(_knockback.normalized(), fly_spd, player_index)

	_clamp_to_arena()

	queue_redraw()


func _draw() -> void:
	# 底部橢圓陰影
	draw_set_transform(Vector2(3.0, RADIUS * 0.90), 0.0, Vector2(0.92, 0.20))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.0, 0.0, 0.0, 0.50))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 主體（旋轉 + 壓扁）
	draw_set_transform(Vector2.ZERO, _spin_angle, _display_scale)

	var body_color = _color
	if _stun_timer > 0.0:
		var flash = 0.5 + 0.5 * sin(_stun_timer * 60.0)
		body_color = body_color.lerp(Color.WHITE, flash * 0.55)

	draw_circle(Vector2.ZERO, RADIUS, body_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color.WHITE, 2.5)
	draw_line(Vector2.ZERO, _facing * (RADIUS + 12.0), Color.WHITE, 3.0)

	if player_index == 1:
		draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
	else:
		draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), Color.WHITE)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 供 enemy.gd：饕客推擠 ────────────────────────

func apply_push(dir: Vector2, force: float) -> void:
	_push = (_push + dir * force).limit_length(PUSH_MAX)


# ── 供 projectile.gd：友火擊退 + 昏厥 ───────────

func apply_knockback(dir: Vector2, force: float) -> void:
	_knockback = (_knockback + dir * force).limit_length(KNOCKBACK_MAX)
	_start_hit_reaction()


func _start_hit_reaction() -> void:
	_stun_timer = STUN_DURATION
	_spin_angle = 0.0
	if _hit_reaction_tween != null:
		_hit_reaction_tween.kill()

	_display_scale = Vector2.ONE
	_hit_reaction_tween = create_tween()
	_hit_reaction_tween.tween_property(self, "_display_scale", Vector2(2.10, 0.28), 0.05)
	_hit_reaction_tween.tween_property(self, "_display_scale", Vector2(0.55, 1.70), 0.09)
	_hit_reaction_tween.tween_property(self, "_display_scale", Vector2(1.20, 0.82), 0.09)
	_hit_reaction_tween.tween_property(self, "_display_scale", Vector2(0.90, 1.12), 0.07)
	_hit_reaction_tween.tween_property(self, "_display_scale", Vector2(1.0,  1.0),  0.09)


# ── 發射單顆子彈（burst 和單發都走這裡）──────────

func _fire_projectile(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return

	var container = get_tree().current_scene.get_node_or_null("World/Projectiles")
	if container == null:
		container = get_tree().current_scene.get_node_or_null("Projectiles")
	if container == null:
		return

	var proj = PROJECTILE_SCENE.instantiate()
	# 注入角色專屬參數（在 add_child 前設定，_ready 會用到）
	proj.direction       = dir.normalized()
	proj.shooter         = self
	proj.proj_radius     = proj_radius
	proj.proj_speed      = proj_speed
	proj.player_knockback = proj_knockback
	proj.enemy_fly_speed  = proj_enemy_speed
	proj.hit_stop_frames  = proj_hit_stop
	proj.proj_color       = proj_color

	container.add_child(proj)
	proj.global_position = global_position + dir.normalized() * (RADIUS + proj_radius + 4.0)


func _clamp_to_arena() -> void:
	position.x = clamp(position.x, ARENA_X_MIN + RADIUS, ARENA_X_MAX - RADIUS)
	position.y = clamp(position.y, ARENA_Y_MIN + RADIUS, ARENA_Y_MAX - RADIUS)


func _sanitize_player_state() -> void:
	if not _is_vec2_finite(position) or not _is_vec2_finite(_knockback) or not _is_vec2_finite(_push):
		position = Vector2(380.0, 360.0) if player_index == 1 else Vector2(900.0, 360.0)
		_knockback = Vector2.ZERO
		_push = Vector2.ZERO
		_stun_timer = 0.0
		_spin_angle = 0.0
		_display_scale = Vector2.ONE
		modulate = Color(1.0, 1.0, 1.0, 1.0)

	_display_scale.x = clamp(_display_scale.x, 0.40, 2.40)
	_display_scale.y = clamp(_display_scale.y, 0.40, 2.40)
	_knockback = _knockback.limit_length(KNOCKBACK_MAX)
	_push = _push.limit_length(PUSH_MAX)
	_clamp_to_arena()


func _is_vec2_finite(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)
