extends CharacterBody2D

# ===================================================
# player.gd — 玩家控制
#
# 角色的武器數值/外觀來自 character（PlayerCharacter resource），
# 輸入來源來自 control_profile（ControlProfile resource），
# 兩者都由 main.gd 在 _spawn_players() 指派。
# player_index 只作為玩家「代號」使用（記分、攻擊者 ID、
# 突變效果指定對象），與角色數值、輸入來源無關。
#
# 若場景未指派 character / control_profile（例如獨立測試），
# _ready() 會依 player_index 退回舊版 P1/P2 預設值。
# ===================================================

@export var player_index : int = 1
@export var character        : PlayerCharacter = null
@export var control_profile  : ControlProfile  = null

# ── 通用移動參數 ──────────────────────────────────
const SPEED           = 200.0
const RADIUS          = 24.0
const KNOCKBACK_DECAY = 3.8   # ↓ 從 6.5 降低：衰減更慢，飛得更遠
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

# ── 角色專屬攻擊參數 ──────────────────────────────
# 數值定義在 resources/characters/*.tres（PlayerCharacter），
# _ready() 讀入後複製到下方這組 var，供全腳本使用。
# 現有兩個角色：hotdog.tres（熱狗攤）、bubble_tea.tres（珍奶攤）。

# ── Friendly Fire 放大參數 ────────────────────────
@export_group("Friendly Fire")
@export var ff_knockback_multiplier  : float   = 2.25   # ← 友火擊退力乘數（2.25 = 原 1.5 再 ×1.5）
@export var knockback_max            : float   = 6000.0 # ← 擊退速度上限（需 ≥ P1 knockback × multiplier）
@export var ff_hit_stop_frames       : int     = 5      # ← 友火 hit stop 幀數（60fps×5 ≈ 0.08s）
@export var ff_effect_scale          : float   = 2.25   # ← 友火爆炸特效倍率（原 1.5 再 ×1.5 = 2.25）
@export var ff_squash_x              : float   = 2.65   # ← 命中壓扁 X（越大越扁）
@export var ff_squash_y              : float   = 0.18   # ← 命中壓扁 Y（越小越扁）
@export var ff_stretch_x             : float   = 0.38   # ← 彈回拉伸 X（越小越細）
@export var ff_stretch_y             : float   = 2.15   # ← 彈回拉伸 Y（越大越長）
@export var ff_knockback_hit_thresh  : float   = 350.0  # ← 擊退速度超過此值才偵測碰撞（px/s）
@export var ff_chain_enemy_ratio     : float   = 0.55   # ← 被擊退玩家撞飛敵人的速度比
@export var ff_chain_player_ratio    : float   = 0.72   # ← 被擊退玩家撞飛隊友的速度比

# ── 中央壓力區（Pressure Zone）─────────────────────
# 數值由 main.gd 透過 zone_complaint_count 更新
@export_group("Pressure Zone")
@export var zone_radius         : float = 80.0   # ← 壓力區半徑（px，需與 food_court 的視覺圈一致）
@export var zone_slow_threshold : int   = 5      # ← 客訴達此數啟動減速
@export var zone_push_threshold : int   = 8      # ← 客訴達此數改為向外推力
@export var zone_slow_factor    : float = 0.50   # ← 減速倍率（0.5 = 降為一半速度）
@export var zone_push_force     : float = 150.0  # ← 向外推力（px/s）

var zone_complaint_count : int = 0   # 由 main.gd 每幀設定，不要手動改
var frozen: bool = false             # true 時鎖定所有移動與射擊（倒數期間）

# ── 突變系統 hook（由 main.gd 寫入）────────────────
var mutation_speed_mult : float = 1.0   # 突變③ 全場加速倍率
var p2_always_grease    : bool  = false # 突變② 珍珠大爆發
var proj_radius_mult    : float = 1.0   # 突變① 熱狗太興奮：子彈半徑倍率

var shoot_cooldown   : float = 0.30
var burst_count      : int   = 1      # =1 表示單發
var burst_delay      : float = 0.0
var proj_radius      : float = 12.0
var proj_speed       : float = 400.0
var proj_knockback   : float = 950.0
var proj_enemy_speed : float = 420.0
var proj_hit_stop    : int   = 2
var proj_color       : Color = Color(1.0, 0.92, 0.1)

var _color : Color:
	get: return character.body_color if character != null else Color.WHITE

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

	if character == null:
		character = _fallback_character()
	if control_profile == null:
		control_profile = _fallback_control_profile()

	# ── 依角色資料設定攻擊參數 ────────────────────
	shoot_cooldown   = character.shoot_cooldown
	burst_count      = character.burst_count
	burst_delay      = character.burst_delay
	proj_radius      = character.proj_radius
	proj_speed       = character.proj_speed
	proj_knockback   = character.proj_knockback_base * ff_knockback_multiplier
	proj_enemy_speed = character.proj_enemy_speed
	proj_hit_stop    = character.proj_hit_stop
	proj_color       = character.proj_color

	queue_redraw()


func _fallback_character() -> PlayerCharacter:
	# 場景未指派 character 時的退回值，維持重構前的 P1/P2 手感
	var c := PlayerCharacter.new()
	if player_index == 1:
		c.character_name = "熱狗攤"
		c.body_color = GameplayPalette.PLAYER_HEAVY
		c.marker_shape = "circle"
		c.shoot_cooldown = 0.55
		c.burst_count = 1
		c.proj_radius = 18.0
		c.proj_speed = 320.0
		c.proj_knockback_base = 2200.0
		c.proj_enemy_speed = 1000.0
		c.proj_hit_stop = 5
		c.proj_color = GameplayPalette.PLAYER_HEAVY_ACCENT
	else:
		c.character_name = "珍奶攤"
		c.body_color = GameplayPalette.PLAYER_SPEEDY
		c.marker_shape = "square"
		c.shoot_cooldown = 0.42
		c.burst_count = 3
		c.burst_delay = 0.075
		c.proj_radius = 7.0
		c.proj_speed = 560.0
		c.proj_knockback_base = 850.0
		c.proj_enemy_speed = 500.0
		c.proj_hit_stop = 2
		c.proj_color = GameplayPalette.PLAYER_SPEEDY_ACCENT
	return c


func _fallback_control_profile() -> ControlProfile:
	var cp := ControlProfile.new()
	cp.device_type = ControlProfile.DeviceType.KEYBOARD
	cp.action_prefix = "p1_" if player_index == 1 else "p2_"
	return cp


func _get_move_dir() -> Vector2:
	# 回傳當前幀的原始移動方向（未正規化），供 _process 與 _physics_process 共用
	var d := Vector2.ZERO

	if control_profile.device_type == ControlProfile.DeviceType.GAMEPAD:
		d.x = Input.get_joy_axis(control_profile.device_id, JOY_AXIS_LEFT_X)
		d.y = Input.get_joy_axis(control_profile.device_id, JOY_AXIS_LEFT_Y)
		if d.length() < control_profile.deadzone:
			d = Vector2.ZERO
		return d

	var prefix = control_profile.action_prefix
	if Input.is_action_pressed(prefix + "up"):    d.y -= 1.0
	if Input.is_action_pressed(prefix + "down"):  d.y += 1.0
	if Input.is_action_pressed(prefix + "left"):  d.x -= 1.0
	if Input.is_action_pressed(prefix + "right"): d.x += 1.0
	return d


func _process(delta: float) -> void:
	if frozen:
		return

	_shoot_cd -= delta

	if _stun_timer > 0.0:
		return

	# ── P2 burst 連射處理（移動中才繼續發射）──────────
	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_fire_projectile(_burst_dir)
			_burst_remaining -= 1
			_burst_timer = burst_delay
		return   # burst 進行中不接受新射擊指令

	# ── 自動射擊：有移動輸入才射擊，方向 = 當前移動方向 ──
	var move_input := _get_move_dir()
	if move_input == Vector2.ZERO:
		return   # 靜止時停止射擊

	var shoot_dir := move_input.normalized()

	if _shoot_cd <= 0.0:
		if burst_count <= 1:
			# 單發角色（例：熱狗攤）
			_fire_projectile(shoot_dir)
			_shoot_cd = shoot_cooldown
		else:
			# burst 連射角色（例：珍奶攤）
			_burst_dir       = shoot_dir
			_fire_projectile(_burst_dir)
			_burst_remaining = burst_count - 1
			_burst_timer     = burst_delay
			_shoot_cd        = shoot_cooldown


func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		return

	_sanitize_player_state()
	var dir = Vector2.ZERO

	if _stun_timer > 0.0:
		_stun_timer -= delta
		var spin_ratio = clamp(_stun_timer / STUN_DURATION, 0.0, 1.0)
		_spin_angle += deg_to_rad(SPIN_SPEED_DEG * spin_ratio) * delta
		if _stun_timer <= 0.0:
			_spin_angle = 0.0
	else:
		dir = _get_move_dir()
		if dir != Vector2.ZERO:
			_facing = dir.normalized()
			dir = dir.normalized()

	_knockback = _knockback.lerp(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	_push      = _push.lerp(Vector2.ZERO,      PUSH_DECAY      * delta)

	# ── 中央壓力區效果 ────────────────────────────────
	var zone_dist      = global_position.distance_to(MAP_CENTER)
	var effective_speed = SPEED * mutation_speed_mult   # ← 突變③ 全場加速
	if zone_dist < zone_radius:
		if zone_complaint_count >= zone_push_threshold:
			pass  # 推力在 velocity 算完後疊加
		elif zone_complaint_count >= zone_slow_threshold:
			effective_speed = SPEED * mutation_speed_mult * zone_slow_factor

	velocity = dir * effective_speed + _knockback + _push

	# 推力：在 zone 且達高壓階段，無論有無輸入都往外推
	if zone_dist < zone_radius and zone_complaint_count >= zone_push_threshold:
		var push_away = global_position - MAP_CENTER
		if push_away.length_squared() < 0.01:
			push_away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		velocity += push_away.normalized() * zone_push_force

	# velocity 上限：避免多重碰撞時 move_and_slide 產生 NaN
	velocity = velocity.limit_length(8000.0)
	move_and_slide()

	# move_and_slide 後再次確認位置：多重 CharacterBody2D 碰撞有時會產生 NaN
	if not _is_vec2_finite(position):
		position  = Vector2(380.0, 360.0) if player_index == 1 else Vector2(900.0, 360.0)
		_knockback = Vector2.ZERO
		_push      = Vector2.ZERO

	# ── 擊退中高速撞飛敵人 & 隊友（無限連鎖）──────────
	const KNOCKBACK_HIT_RANGE = RADIUS + 28.0   # 玩家半徑 + 對方半徑 + 緩衝
	if _knockback.length() > ff_knockback_hit_thresh:
		# 撞飛敵人
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(enemy.global_position) < KNOCKBACK_HIT_RANGE:
				enemy.take_hit(_knockback.normalized(), _knockback.length() * ff_chain_enemy_ratio, player_index)
				_play_chain_sfx()
				_record_run_stat("chain_enemy_hits")
		# 撞飛隊友（新：玩家→玩家連鎖）
		for other in get_tree().get_nodes_in_group("players"):
			if other == self:
				continue
			if global_position.distance_to(other.global_position) < KNOCKBACK_HIT_RANGE:
				other.apply_knockback(_knockback.normalized(), _knockback.length() * ff_chain_player_ratio)
				_play_chain_sfx()
				_record_run_stat("chain_player_hits")

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

	match character.marker_shape:
		"square":
			draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), Color.WHITE)
		"triangle":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -7.0),
				Vector2(6.5, 5.5),
				Vector2(-6.5, 5.5),
			]), Color.WHITE)
		_:
			draw_circle(Vector2.ZERO, 6.0, Color.WHITE)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 供 enemy.gd：饕客推擠 ────────────────────────

func apply_push(dir: Vector2, force: float) -> void:
	if not dir.is_finite() or not is_finite(force):
		return   # 非有限值直接忽略，防止 NaN 污染
	_push = (_push + dir * force).limit_length(PUSH_MAX)


# ── 供 projectile.gd：友火擊退 + 昏厥 ───────────

func apply_knockback(dir: Vector2, force: float) -> void:
	if not dir.is_finite() or not is_finite(force):
		return   # 非有限值直接忽略，防止 NaN 污染
	_knockback = (_knockback + dir * force).limit_length(knockback_max)
	_start_hit_reaction()


func _start_hit_reaction() -> void:
	_stun_timer = STUN_DURATION
	_spin_angle = 0.0
	if _hit_reaction_tween != null:
		_hit_reaction_tween.kill()

	_display_scale = Vector2.ONE
	_hit_reaction_tween = create_tween()
	_hit_reaction_tween.tween_property(self, "_display_scale", Vector2(ff_squash_x,  ff_squash_y),  0.05)
	_hit_reaction_tween.tween_property(self, "_display_scale", Vector2(ff_stretch_x, ff_stretch_y), 0.09)
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
	proj.proj_radius     = proj_radius * proj_radius_mult
	proj.proj_speed      = proj_speed
	proj.player_knockback    = proj_knockback
	proj.enemy_fly_speed     = proj_enemy_speed
	proj.hit_stop_frames     = proj_hit_stop
	proj.proj_color          = proj_color
	proj.ff_hit_stop_frames  = ff_hit_stop_frames
	proj.ff_hit_effect_scale = ff_effect_scale

	# 突變②：P2 珍珠大爆發 → 命中必定留下滑地
	if player_index == 2:
		proj.always_spawn_grease = p2_always_grease

	container.add_child(proj)
	proj.global_position = global_position + dir.normalized() * (RADIUS + proj_radius + 4.0)


func _play_chain_sfx() -> void:
	# 音量池的 cooldown 由 audio_manager.gd 自己擋，這裡不用管密集觸發
	var mgrs = get_tree().get_nodes_in_group("audio_manager")
	if mgrs.size() > 0:
		mgrs[0].play(mgrs[0].CHAIN_HIT)


## 一局結算統計用（見 main.gd 的 record_stat()）。current_scene 在遊玩期間就是 Main 節點本身。
func _record_run_stat(key: String) -> void:
	var scene = get_tree().current_scene
	if scene != null and scene.has_method("record_stat"):
		scene.record_stat(key)


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
	_knockback = _knockback.limit_length(knockback_max)
	_push = _push.limit_length(PUSH_MAX)
	_clamp_to_arena()


func _is_vec2_finite(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)
