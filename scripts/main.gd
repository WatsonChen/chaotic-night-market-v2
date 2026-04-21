extends Node2D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const BIG_ENEMY_SCENE = preload("res://scenes/big_enemy.tscn")
const GREASE_PUDDLE_SCRIPT = preload("res://scripts/grease_puddle.gd")
const HIT_EFFECT_SCRIPT = preload("res://scripts/hit_effect.gd")

const ARENA = Rect2(160.0, 100.0, 960.0, 520.0)
const MAP_CENTER = Vector2(640.0, 360.0)

@export_group("Complaint Stages")
@export var max_complaints: int = 10
@export var stage2_threshold: int = 4
@export var stage3_threshold: int = 8

@export_group("Base Waves")
@export var wave_interval_min: float = 5.0
@export var wave_interval_max: float = 8.0
@export var wave_size_min: int = 6
@export var wave_size_max: int = 10
@export var spawn_edges_count: int = 2
@export var wave_spawn_stagger: float = 0.07

@export_group("Escalation Curve")
@export var stage1_enemy_multiplier: float = 1.0
@export var stage2_enemy_multiplier: float = 1.6
@export var stage3_enemy_multiplier: float = 2.3
@export var stage1_interval_multiplier: float = 1.0
@export var stage2_interval_multiplier: float = 0.6
@export var stage3_interval_multiplier: float = 0.35

@export_group("Big Enemy Curve")
@export var stage2_big_chance: float = 0.40
@export var stage3_big_chance: float = 0.92
@export var stage3_double_chance: float = 0.55
@export var stage3_spike_big_chance: float = 0.88

@export_group("Stage 3 Spike Pressure")
@export var spike_min_stage: int = 3
@export var spike_interval_min: float = 8.0
@export var spike_interval_max: float = 11.0
@export var spike_duration: float = 4.0
@export var spike_spawn_rate: float = 0.30
@export var spike_spawn_pairs: int = 2

@export_group("Grease Pressure")
@export var stage2_grease_interval_min: float = 4.2
@export var stage2_grease_interval_max: float = 6.0
@export var stage2_grease_count_min: int = 1
@export var stage2_grease_count_max: int = 2
@export var stage2_max_grease_puddles: int = 6
@export var stage3_grease_interval_min: float = 1.4
@export var stage3_grease_interval_max: float = 2.2
@export var stage3_grease_count_min: int = 2
@export var stage3_grease_count_max: int = 4
@export var stage3_max_grease_puddles: int = 10
@export var grease_spawn_radius_min: float = 56.0
@export var grease_spawn_radius_max: float = 170.0
@export var grease_radius: float = 40.0
@export var grease_lifetime: float = 2.4
@export var grease_slip_accel: float = 980.0

@export_group("Feedback")
@export var stage2_message: String = "!! 夜市開始失控 !!"
@export var stage3_message: String = "!! 已經完全失控 !!"
@export var complaint_flash_strength: float = 0.16
@export var complaint_flash_duration: float = 0.22
@export var stage_flash_strength: float = 0.42
@export var stage_flash_duration: float = 0.46
@export var break_flash_strength: float = 0.58
@export var break_flash_duration: float = 0.30
@export var comeback_flash_strength: float = 0.54
@export var comeback_flash_duration: float = 0.56
@export var danger_shake_strength: float = 3.8
@export var impact_shake_strength: float = 8.5
@export var stage_transition_shake_strength: float = 9.5
@export var break_shake_strength: float = 14.0
@export var comeback_shake_strength: float = 12.0
@export var shake_decay: float = 12.0
@export var stage_banner_alpha: float = 0.34
@export var stage_banner_hold: float = 1.6
@export var stage2_banner_color: Color = Color(1.0, 0.48, 0.08)
@export var stage3_banner_color: Color = Color(1.0, 0.10, 0.08)

@export_group("Ambient Tint")
@export var stage2_tint_color: Color = Color(1.0, 0.48, 0.08)
@export var stage2_tint_alpha: float = 0.07
@export var stage3_tint_color: Color = Color(1.0, 0.08, 0.08)
@export var stage3_tint_alpha: float = 0.14
@export var stage3_tint_pulse: float = 0.05

@export_group("Break Time FX")
@export var break_hit_stop_scale: float = 0.04
@export var break_hit_stop_duration: float = 0.06
@export var break_slowmo_scale: float = 0.22
@export var break_slowmo_duration: float = 0.34
@export var break_slowmo_delay: float = 0.0
@export var comeback_slowmo_scale: float = 0.56
@export var comeback_slowmo_duration: float = 0.24

@export_group("Break Burst")
@export var break_burst_count: int = 3
@export var break_burst_radius: float = 62.0
@export var break_effect_scale: float = 2.45
@export var break_secondary_effect_scale: float = 1.80
@export var break_effect_particle_count: int = 20
@export var break_effect_ring_count: int = 4
@export var break_effect_fly_distance: float = 132.0
@export var break_effect_ring_max: float = 120.0
@export var break_effect_duration: float = 0.56

@export_group("Comeback Burst")
@export var comeback_burst_count: int = 5
@export var comeback_burst_radius: float = 124.0
@export var comeback_effect_scale: float = 2.15
@export var comeback_secondary_effect_scale: float = 1.40
@export var comeback_effect_particle_count: int = 24
@export var comeback_effect_ring_count: int = 4
@export var comeback_effect_fly_distance: float = 148.0
@export var comeback_effect_ring_max: float = 138.0
@export var comeback_effect_duration: float = 0.64

@export_group("Comeback")
@export var comeback_min_complaints: int = 8
@export var comeback_complaint_reduction: int = 1
@export var comeback_spawn_pause: float = 2.0
@export var comeback_cooldown: float = 10.0

@export_group("Victory Timer")
@export var game_duration: float = 120.0         # ← 遊戲總時長（秒）
@export var warning_time: float = 30.0           # ← 最後幾秒進入警告狀態
@export var warning_shake_strength: float = 2.0  # ← 警告期間每次震動強度
@export var warning_shake_interval: float = 3.5  # ← 震動間隔（秒）

@export_group("Danger Vignette")
@export var vignette_danger_color: Color = Color(1.0, 0.06, 0.06)  # ← 邊緣紅色
@export var vignette_edge_size: float = 90.0                        # ← 邊緣厚度（px）
@export var vignette_pulse_speed: float = 8.0                       # ← 閃爍頻率（Hz）
@export var vignette_pulse_alpha_max: float = 0.30                  # ← 最深透明度
@export var vignette_pulse_alpha_min: float = 0.10                  # ← 最淺透明度

@export_group("Sprint Visual")
@export var sprint_timer_color: Color = Color(1.0, 0.82, 0.18)      # ← 衝刺計時器主色（黃）
@export var sprint_timer_flash_color: Color = Color(1.0, 0.52, 0.10) # ← 閃爍偏橘色
@export var sprint_timer_blink_speed: float = 2.8                   # ← 計時器閃爍頻率（Hz）
@export var sprint_brightness_color: Color = Color(1.0, 0.97, 0.68)  # ← 畫面亮度 pulse 顏色
@export var sprint_brightness_alpha_max: float = 0.07               # ← pulse 最高透明度
@export var sprint_brightness_speed: float = 3.0                    # ← pulse 頻率（Hz）
@export var sprint_label_text: String = "最後衝刺！撐住！"           # ← 提示文字

@export_group("Mutation System")
@export var mutation_interval      : float = 60.0   # ← 觸發間隔（秒）
@export var mutation_choose_time   : float = 5.0    # ← 選擇倒數（秒）
@export var mutation_p1_kb_mult    : float = 2.0    # ← 突變①：P1 擊退倍率
@export var mutation_speed_ratio   : float = 1.3    # ← 突變③：全場加速倍率
@export var mutation_speed_secs    : float = 15.0   # ← 突變③：持續秒數
@export var mutation_big_mult      : float = 3.0    # ← 突變④：大型饕客機率倍率
@export var mutation_big_secs      : float = 20.0   # ← 突變④：持續秒數
@export var mutation_complaint_cut : int   = 2      # ← 突變⑤：客訴減免量
@export var mutation_card_w        : float = 276.0  # ← 卡片寬度
@export var mutation_card_h        : float = 192.0  # ← 卡片高度
@export var mutation_card_gap      : float = 28.0   # ← 卡片間距
@export var mutation_overlay_color : Color = Color(0.07, 0.03, 0.16, 0.90)
@export var mutation_card_normal   : Color = Color(0.18, 0.10, 0.34, 1.00)
@export var mutation_card_hover    : Color = Color(0.44, 0.26, 0.74, 1.00)
@export var mutation_card_p2sel    : Color = Color(0.14, 0.44, 0.18, 1.00)
@export var mutation_bar_color     : Color = Color(0.30, 0.84, 0.42, 1.00)

@export_group("Final Sprint Pressure")
@export var sprint_wave_interval_multiplier : float = 0.15  # ← 衝刺期間波次間隔倍率（越小越快）
@export var sprint_big_enemy_min           : int   = 1      # ← 進入衝刺時強制生成大型饕客最少數
@export var sprint_big_enemy_max           : int   = 2      # ← 進入衝刺時強制生成大型饕客最多數
@export var sprint_bonus_wave_count        : int   = 1      # ← 進入衝刺時立刻額外觸發的波次數

var complaint_count: int = 0
var wave_count: int = 0
var is_game_over: bool = false
var _in_sprint_mode: bool = false   # 最後 30 秒高壓衝刺旗標

# ── 突變系統狀態 ───────────────────────────────────
var _mut_trigger_timer : float    = 0.0
var _in_mutation       : bool     = false
var _mut_countdown     : float    = 0.0
var _mut_choices       : Array      = []   # 不用 Array[int]，slice() 回傳 plain Array
var _mut_hovered       : int      = -1
var _mut_p2_cursor     : int      = 0
var _mut_speed_timer   : float    = 0.0
var _mut_big_timer     : float    = 0.0
var _mut_big_active    : bool     = false

var _wave_timer: float = 0.0
var _next_wave_in: float = 3.0
var _spawn_queue: Array[Vector2] = []
var _queue_timer: float = 0.0

var _spike_timer: float = 0.0
var _next_spike_in: float = 0.0
var _in_spike: bool = false
var _spike_left: float = 0.0
var _spike_spawn_cd: float = 0.0

var _grease_timer: float = 0.0
var _next_grease_in: float = 999.0

var _spawn_pause_timer: float = 0.0
var _comeback_cooldown_left: float = 0.0
var _feedback_time: float = 0.0
var _impulse_shake: float = 0.0
var _slowmo_token: int = 0

var complaint_label: Label
var game_over_panel: Panel
var final_label: Label
var spike_label: Label
var stage_label: Label
var comeback_label: Label
var ambient_overlay: ColorRect
var flash_overlay: ColorRect
var stage_banner: ColorRect

var _flash_tween: Tween
var _stage_notice_tween: Tween
var _spike_notice_tween: Tween
var _comeback_notice_tween: Tween
var _complaint_bump_tween: Tween

var _time_left: float = 0.0
var _next_warning_shake: float = 0.0
var timer_label: Label
var win_panel: Panel
var win_final_label: Label

# 危險 vignette（4 邊緣 ColorRect）
var vignette_top: ColorRect
var vignette_bottom: ColorRect
var vignette_left: ColorRect
var vignette_right: ColorRect

# 衝刺效果
var sprint_overlay: ColorRect
var sprint_label: Label

# 音效管理器
var audio_mgr : Node

# ── 突變 UI 節點 ───────────────────────────────────
var _mut_overlay    : ColorRect
var _mut_title      : Label
var _mut_sub        : Label
var _mut_bar_bg     : ColorRect
var _mut_bar_fill   : ColorRect
var _mut_cd_label   : Label
var _mut_hint       : Label
var _mut_cards      : Array[ColorRect] = []
var _mut_card_tl    : Array[Label]     = []   # 標題 labels
var _mut_card_dl    : Array[Label]     = []   # 說明 labels
var _mut_card_nl    : Array[Label]     = []   # 編號 labels

@onready var world_node: Node2D = $World
@onready var food_court = $World/FoodCourt
@onready var players_node: Node2D = $World/Players
@onready var enemies_node: Node2D = $World/Enemies
@onready var projectiles_node: Node2D = $World/Projectiles
@onready var ui_layer: CanvasLayer = $UI


func _ready() -> void:
	# 突變系統需要在場景 pause 時仍繼續執行（倒數 + 輸入）
	# 只有 Main 本身設 ALWAYS；World 子樹設 PAUSABLE，pause 時敵人/玩家真的停下
	process_mode            = Node.PROCESS_MODE_ALWAYS
	world_node.process_mode = Node.PROCESS_MODE_PAUSABLE

	randomize()
	RenderingServer.set_default_clear_color(Color(0.08, 0.04, 0.12))

	# 音效管理器（在 UI 之前建立，其他系統可立即使用）
	audio_mgr = preload("res://scripts/audio_manager.gd").new()
	audio_mgr.name = "AudioManager"
	add_child(audio_mgr)

	_setup_ui()
	_setup_mutation_ui()
	_spawn_players()
	_reset_spawn_timers()
	_time_left = game_duration
	_next_warning_shake = warning_shake_interval
	_sync_tension_feedback()
	queue_redraw()


func _process(delta: float) -> void:
	_feedback_time += delta
	_update_world_feedback(delta)
	_sync_tension_feedback()
	queue_redraw()

	# 突變系統（paused 期間仍執行，因 PROCESS_MODE_ALWAYS）
	_update_mutation_system(delta)

	if is_game_over or _in_mutation:
		return

	_update_victory_timer(delta)
	_update_danger_vignette(delta)
	_update_sprint_visual(delta)
	_comeback_cooldown_left = max(_comeback_cooldown_left - delta, 0.0)

	if _spawn_pause_timer > 0.0:
		_spawn_pause_timer = max(_spawn_pause_timer - delta, 0.0)
		return

	_update_wave_timer(delta)
	_update_spike_timer(delta)
	_update_grease_timer(delta)
	_update_spawn_queue(delta)


func _reset_spawn_timers() -> void:
	_wave_timer = 0.0
	_next_wave_in = 3.0 * _get_interval_multiplier()
	_queue_timer = 0.0
	_spike_timer = 0.0
	_next_spike_in = randf_range(spike_interval_min, spike_interval_max)
	_in_spike = false
	_spike_left = 0.0
	_spike_spawn_cd = 0.0
	_grease_timer = 0.0
	_schedule_next_grease()


func _update_wave_timer(delta: float) -> void:
	_wave_timer += delta
	if _wave_timer < _next_wave_in:
		return

	_wave_timer = 0.0
	_next_wave_in = randf_range(wave_interval_min, wave_interval_max) * _get_interval_multiplier()
	wave_count += 1
	_build_wave_queue()


func _update_spike_timer(delta: float) -> void:
	if _get_stage() < spike_min_stage:
		if _in_spike:
			_end_spike()
		return

	if not _in_spike:
		_spike_timer += delta
		if _spike_timer >= _next_spike_in:
			_spike_timer = 0.0
			_next_spike_in = randf_range(spike_interval_min, spike_interval_max)
			_in_spike = true
			_spike_left = spike_duration
			_spike_spawn_cd = 0.0
			_show_spike_warning()
		return

	_spike_left -= delta
	_spike_spawn_cd -= delta
	if _spike_spawn_cd <= 0.0:
		_spike_spawn_cd = spike_spawn_rate
		var edges = [0, 1, 2, 3]
		edges.shuffle()
		var pair_count = clamp(spike_spawn_pairs, 1, 4)
		for i in range(pair_count):
			_spawn_enemy_at(_edge_position(edges[i]))
		if pair_count < edges.size() and randf() < stage3_spike_big_chance:
			_spawn_big_enemy_at(_edge_position(edges[pair_count]))

	if _spike_left <= 0.0:
		_end_spike()


func _update_grease_timer(delta: float) -> void:
	if _get_stage() < 2:
		_grease_timer = 0.0
		return

	_grease_timer += delta
	if _grease_timer < _next_grease_in:
		return

	_grease_timer = 0.0
	_spawn_grease_cluster(_get_stage())
	_schedule_next_grease()


func _update_spawn_queue(delta: float) -> void:
	if _spawn_queue.is_empty():
		return

	_queue_timer -= delta
	if _queue_timer > 0.0:
		return

	_spawn_enemy_at(_spawn_queue.pop_front())
	_queue_timer = wave_spawn_stagger


func _end_spike() -> void:
	_in_spike = false
	_spike_left = 0.0
	_spike_spawn_cd = 0.0
	spike_label.hide()


func _spawn_players() -> void:
	var p1 = PLAYER_SCENE.instantiate()
	p1.player_index = 1
	p1.position = Vector2(380, 360)
	players_node.add_child(p1)

	var p2 = PLAYER_SCENE.instantiate()
	p2.player_index = 2
	p2.position = Vector2(900, 360)
	players_node.add_child(p2)


func _build_wave_queue() -> void:
	var base_count = randi_range(wave_size_min, wave_size_max)
	var wave_count_scaled = max(1, int(round(float(base_count) * _get_enemy_multiplier())))
	var all_edges = [0, 1, 2, 3]
	all_edges.shuffle()
	var edge_count = clamp(spawn_edges_count, 1, 4)
	var chosen_edges = all_edges.slice(0, edge_count)

	for i in range(wave_count_scaled):
		var edge = chosen_edges[i % chosen_edges.size()]
		_spawn_queue.append(_edge_position(edge))

	_queue_timer = 0.0
	_roll_big_enemy_spawn(_get_stage())


func _roll_big_enemy_spawn(stage: int) -> void:
	var bm = mutation_big_mult if _mut_big_active else 1.0   # 突變④ 倍率

	if stage == 2:
		if randf() < minf(stage2_big_chance * bm, 1.0):
			_spawn_big_enemy_at(_edge_position(randi() % 4))
		return

	if stage < 3:
		return

	if randf() < minf(stage3_big_chance * bm, 1.0):
		var edges = [0, 1, 2, 3]
		edges.shuffle()
		_spawn_big_enemy_at(_edge_position(edges[0]))
		if randf() < stage3_double_chance:
			_spawn_big_enemy_at(_edge_position(edges[1]))


func _schedule_next_grease() -> void:
	match _get_stage():
		2:
			_next_grease_in = randf_range(stage2_grease_interval_min, stage2_grease_interval_max)
		3:
			_next_grease_in = randf_range(stage3_grease_interval_min, stage3_grease_interval_max)
		_:
			_next_grease_in = 999.0


func _spawn_grease_cluster(stage: int) -> void:
	var count_min = stage2_grease_count_min
	var count_max = stage2_grease_count_max
	var max_puddles = stage2_max_grease_puddles
	if stage >= 3:
		count_min = stage3_grease_count_min
		count_max = stage3_grease_count_max
		max_puddles = stage3_max_grease_puddles

	for _i in range(randi_range(count_min, count_max)):
		var puddle = Node2D.new()
		puddle.set_script(GREASE_PUDDLE_SCRIPT)
		puddle.radius = grease_radius
		puddle.lifetime = grease_lifetime
		puddle.slip_accel = grease_slip_accel
		puddle.max_active_puddles = max_puddles
		world_node.add_child(puddle)
		puddle.global_position = _random_grease_position()


func _random_grease_position() -> Vector2:
	var angle = randf() * TAU
	var dist = randf_range(grease_spawn_radius_min, grease_spawn_radius_max)
	var pos = MAP_CENTER + Vector2(cos(angle), sin(angle)) * dist
	return Vector2(
		clamp(pos.x, ARENA.position.x + grease_radius, ARENA.end.x - grease_radius),
		clamp(pos.y, ARENA.position.y + grease_radius, ARENA.end.y - grease_radius)
	)


func _edge_position(edge: int) -> Vector2:
	var ax = ARENA.position.x
	var ay = ARENA.position.y
	var ex = ARENA.end.x
	var ey = ARENA.end.y
	match edge:
		0:
			return Vector2(randf_range(ax, ex), ay - 32.0)
		1:
			return Vector2(randf_range(ax, ex), ey + 32.0)
		2:
			return Vector2(ax - 32.0, randf_range(ay, ey))
		3:
			return Vector2(ex + 32.0, randf_range(ay, ey))
	return MAP_CENTER


func _spawn_enemy_at(pos: Vector2) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.position = pos
	enemies_node.add_child(enemy)
	enemy.reach_center.connect(_on_enemy_reach_center)


func _spawn_big_enemy_at(pos: Vector2) -> void:
	var enemy = BIG_ENEMY_SCENE.instantiate()
	enemy.position = pos
	enemies_node.add_child(enemy)
	enemy.reach_center.connect(_on_enemy_reach_center)
	enemy.armor_broken.connect(_on_big_enemy_armor_broken)


func _get_stage() -> int:
	if complaint_count >= stage3_threshold:
		return 3
	if complaint_count >= stage2_threshold:
		return 2
	return 1


func _get_enemy_multiplier() -> float:
	match _get_stage():
		2:
			return stage2_enemy_multiplier
		3:
			return stage3_enemy_multiplier
		_:
			return stage1_enemy_multiplier


func _get_interval_multiplier() -> float:
	if _in_sprint_mode:
		return sprint_wave_interval_multiplier   # 衝刺期間強制最快間隔
	match _get_stage():
		2:
			return stage2_interval_multiplier
		3:
			return stage3_interval_multiplier
		_:
			return stage1_interval_multiplier


func _on_enemy_reach_center(complaint_delta: int = 1) -> void:
	if is_game_over:
		return

	audio_mgr.play(audio_mgr.COMPLAINT)   # 客訴 +1 音效
	_set_complaint_count(complaint_count + complaint_delta, true)
	_play_screen_flash(Color(1.0, 0.18, 0.1), complaint_flash_strength, complaint_flash_duration)
	_add_shake(impact_shake_strength * (0.45 if complaint_delta == 1 else 0.75))

	if complaint_count >= max_complaints:
		_trigger_game_over()


func _on_big_enemy_armor_broken(break_position: Vector2) -> void:
	if is_game_over:
		return

	audio_mgr.play(audio_mgr.BIG_BREAK)   # 大型破防音效
	var triggered_comeback = complaint_count >= comeback_min_complaints and _comeback_cooldown_left <= 0.0
	_spawn_break_burst(break_position)
	_play_screen_flash(Color(1.0, 1.0, 1.0), break_flash_strength, break_flash_duration)
	_add_shake(break_shake_strength)
	food_court.trigger_break_pulse(1.25)
	_start_break_time_fx(triggered_comeback)

	if triggered_comeback:
		_trigger_comeback(break_position)


func _trigger_comeback(break_position: Vector2) -> void:
	_comeback_cooldown_left = comeback_cooldown
	_spawn_pause_timer = max(_spawn_pause_timer, comeback_spawn_pause)
	_set_complaint_count(complaint_count - comeback_complaint_reduction, true)
	_spawn_comeback_burst(break_position)
	_play_screen_flash(Color(1.0, 1.0, 0.92), comeback_flash_strength, comeback_flash_duration)
	_add_shake(comeback_shake_strength)
	_show_comeback_notice()
	food_court.trigger_comeback_pulse(1.35)


func _set_complaint_count(new_value: int, play_bump: bool = true) -> void:
	var old_stage = _get_stage()
	complaint_count = clamp(new_value, 0, max_complaints)
	_update_complaint_label(play_bump)

	var new_stage = _get_stage()
	if new_stage != old_stage:
		_on_stage_changed(old_stage, new_stage)

	_sync_tension_feedback()


func _update_complaint_label(play_bump: bool) -> void:
	complaint_label.text = "客訴 %d / %d" % [complaint_count, max_complaints]
	if not play_bump:
		return

	if _complaint_bump_tween != null:
		_complaint_bump_tween.kill()

	complaint_label.scale = Vector2.ONE
	_complaint_bump_tween = create_tween()
	_complaint_bump_tween.tween_property(complaint_label, "scale", Vector2(1.22, 1.22), 0.08)
	_complaint_bump_tween.tween_property(complaint_label, "scale", Vector2.ONE, 0.18)


func _on_stage_changed(old_stage: int, new_stage: int) -> void:
	_schedule_next_grease()
	_grease_timer = 0.0

	if new_stage < spike_min_stage:
		_end_spike()
	elif old_stage < spike_min_stage and new_stage >= spike_min_stage:
		_spike_timer = 0.0
		_next_spike_in = randf_range(spike_interval_min, spike_interval_max)

	if new_stage <= old_stage:
		return

	if new_stage == 3:
		_spawn_grease_cluster(3)

	_show_stage_transition(new_stage)
	_play_screen_flash(_stage_flash_color(new_stage), stage_flash_strength, stage_flash_duration)
	_add_shake(stage_transition_shake_strength)


func _show_stage_transition(stage: int) -> void:
	var text = stage2_message
	if stage >= 3:
		text = stage3_message

	if _stage_notice_tween != null:
		_stage_notice_tween.kill()

	stage_label.text = text
	stage_label.add_theme_color_override("font_color", _stage_flash_color(stage))
	stage_banner.color = Color(_stage_banner_color(stage).r, _stage_banner_color(stage).g, _stage_banner_color(stage).b, 0.0)
	stage_label.modulate = Color(1, 1, 1, 0)
	stage_label.scale = Vector2.ONE * 0.60
	stage_banner.show()
	stage_label.show()

	_stage_notice_tween = create_tween()
	_stage_notice_tween.tween_property(stage_label, "modulate", Color(1, 1, 1, 1), 0.14)
	_stage_notice_tween.parallel().tween_property(stage_label, "scale", Vector2.ONE * 1.16, 0.14)
	_stage_notice_tween.parallel().tween_property(
		stage_banner,
		"color",
		Color(_stage_banner_color(stage).r, _stage_banner_color(stage).g, _stage_banner_color(stage).b, stage_banner_alpha),
		0.14
	)
	_stage_notice_tween.tween_property(stage_label, "scale", Vector2.ONE, 0.12)
	_stage_notice_tween.tween_interval(stage_banner_hold)
	_stage_notice_tween.tween_property(stage_label, "modulate", Color(1, 1, 1, 0), 0.35)
	_stage_notice_tween.parallel().tween_property(
		stage_banner,
		"color",
		Color(_stage_banner_color(stage).r, _stage_banner_color(stage).g, _stage_banner_color(stage).b, 0.0),
		0.35
	)
	_stage_notice_tween.tween_callback(stage_banner.hide)
	_stage_notice_tween.tween_callback(stage_label.hide)


func _show_spike_warning() -> void:
	if _spike_notice_tween != null:
		_spike_notice_tween.kill()

	spike_label.text = "失控潮湧！"
	spike_label.modulate = Color(1, 1, 1, 0)
	spike_label.scale = Vector2.ONE * 0.65
	spike_label.show()

	_spike_notice_tween = create_tween()
	_spike_notice_tween.tween_property(spike_label, "modulate", Color(1, 1, 1, 1), 0.12)
	_spike_notice_tween.parallel().tween_property(spike_label, "scale", Vector2.ONE * 1.18, 0.12)
	_spike_notice_tween.tween_property(spike_label, "scale", Vector2.ONE, 0.10)
	_spike_notice_tween.tween_interval(max(spike_duration - 0.5, 0.3))
	_spike_notice_tween.tween_property(spike_label, "modulate", Color(1, 1, 1, 0), 0.30)
	_spike_notice_tween.tween_callback(spike_label.hide)


func _show_comeback_notice() -> void:
	if _comeback_notice_tween != null:
		_comeback_notice_tween.kill()

	comeback_label.text = "差點失控，但被你們救回來了！"
	comeback_label.modulate = Color(1, 1, 1, 0)
	comeback_label.scale = Vector2.ONE * 0.72
	comeback_label.show()

	_comeback_notice_tween = create_tween()
	_comeback_notice_tween.tween_property(comeback_label, "modulate", Color(1, 1, 1, 1), 0.18)
	_comeback_notice_tween.parallel().tween_property(comeback_label, "scale", Vector2.ONE * 1.08, 0.18)
	_comeback_notice_tween.tween_property(comeback_label, "scale", Vector2.ONE, 0.12)
	_comeback_notice_tween.tween_interval(1.7)
	_comeback_notice_tween.tween_property(comeback_label, "modulate", Color(1, 1, 1, 0), 0.40)
	_comeback_notice_tween.tween_callback(comeback_label.hide)


func _stage_flash_color(stage: int) -> Color:
	if stage >= 3:
		return Color(1.0, 0.14, 0.12)
	return Color(1.0, 0.44, 0.10)


func _stage_banner_color(stage: int) -> Color:
	if stage >= 3:
		return stage3_banner_color
	return stage2_banner_color


func _spawn_hit_effect(pos: Vector2, is_player_hit: bool, scale: float, overrides: Dictionary = {}) -> void:
	var fx = Node2D.new()
	fx.set_script(HIT_EFFECT_SCRIPT)
	fx.is_player_hit = is_player_hit
	fx.effect_scale = scale
	if overrides.has("duration_override"):
		fx.duration_override = overrides["duration_override"]
	if overrides.has("particle_count_override"):
		fx.particle_count_override = overrides["particle_count_override"]
	if overrides.has("ring_count_override"):
		fx.ring_count_override = overrides["ring_count_override"]
	if overrides.has("fly_distance_override"):
		fx.fly_distance_override = overrides["fly_distance_override"]
	if overrides.has("ring_max_override"):
		fx.ring_max_override = overrides["ring_max_override"]
	if overrides.has("white_ring_boost"):
		fx.white_ring_boost = overrides["white_ring_boost"]
	if overrides.has("primary_color"):
		fx.primary_color = overrides["primary_color"]
	if overrides.has("secondary_color"):
		fx.secondary_color = overrides["secondary_color"]
	if overrides.has("accent_color"):
		fx.accent_color = overrides["accent_color"]
	if overrides.has("rainbow_mode"):
		fx.rainbow_mode = overrides["rainbow_mode"]
	if overrides.has("spin_speed"):
		fx.spin_speed = overrides["spin_speed"]
	if overrides.has("particle_size_ratio"):
		fx.particle_size_ratio = overrides["particle_size_ratio"]
	if overrides.has("ring_width_ratio"):
		fx.ring_width_ratio = overrides["ring_width_ratio"]
	if overrides.has("flash_window_ratio"):
		fx.flash_window_ratio = overrides["flash_window_ratio"]
	world_node.add_child(fx)
	fx.global_position = pos


func _spawn_break_burst(pos: Vector2) -> void:
	_spawn_hit_effect(
		pos,
		true,
		break_effect_scale,
		{
			"duration_override": break_effect_duration,
			"particle_count_override": break_effect_particle_count,
			"ring_count_override": break_effect_ring_count,
			"fly_distance_override": break_effect_fly_distance,
			"ring_max_override": break_effect_ring_max,
			"white_ring_boost": 1.5,
			"primary_color": Color(1.0, 0.78, 0.12),
			"secondary_color": Color(1.0, 1.0, 1.0),
			"accent_color": Color(1.0, 0.20, 0.06),
			"particle_size_ratio": 1.2,
			"ring_width_ratio": 1.3,
		}
	)

	for _i in range(break_burst_count):
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * randf_range(18.0, break_burst_radius)
		_spawn_hit_effect(
			pos + offset,
			true,
			break_secondary_effect_scale,
			{
				"duration_override": break_effect_duration * 0.82,
				"particle_count_override": max(8, break_effect_particle_count - 8),
				"ring_count_override": max(2, break_effect_ring_count - 1),
				"fly_distance_override": break_effect_fly_distance * 0.72,
				"ring_max_override": break_effect_ring_max * 0.74,
				"white_ring_boost": 1.0,
				"primary_color": Color(1.0, 0.88, 0.35),
				"secondary_color": Color(1.0, 0.97, 0.88),
				"accent_color": Color(1.0, 0.42, 0.12),
			}
		)


func _spawn_comeback_burst(pos: Vector2) -> void:
	_spawn_hit_effect(
		MAP_CENTER,
		true,
		comeback_effect_scale,
		{
			"duration_override": comeback_effect_duration,
			"particle_count_override": comeback_effect_particle_count,
			"ring_count_override": comeback_effect_ring_count,
			"fly_distance_override": comeback_effect_fly_distance,
			"ring_max_override": comeback_effect_ring_max,
			"white_ring_boost": 1.65,
			"rainbow_mode": true,
			"particle_size_ratio": 1.22,
			"ring_width_ratio": 1.34,
		}
	)

	for _i in range(comeback_burst_count):
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * randf_range(20.0, comeback_burst_radius)
		_spawn_hit_effect(
			MAP_CENTER + offset,
			true,
			comeback_secondary_effect_scale,
			{
				"duration_override": comeback_effect_duration * 0.76,
				"particle_count_override": max(10, comeback_effect_particle_count - 10),
				"ring_count_override": max(2, comeback_effect_ring_count - 1),
				"fly_distance_override": comeback_effect_fly_distance * 0.66,
				"ring_max_override": comeback_effect_ring_max * 0.64,
				"white_ring_boost": 1.15,
				"rainbow_mode": true,
			}
		)

	_spawn_hit_effect(
		pos,
		true,
		comeback_secondary_effect_scale,
		{
			"duration_override": comeback_effect_duration * 0.72,
			"particle_count_override": max(10, comeback_effect_particle_count - 8),
			"ring_count_override": max(2, comeback_effect_ring_count - 1),
			"fly_distance_override": comeback_effect_fly_distance * 0.58,
			"ring_max_override": comeback_effect_ring_max * 0.58,
			"white_ring_boost": 1.20,
			"rainbow_mode": true,
		}
	)


func _play_screen_flash(base_color: Color, strength: float, duration: float) -> void:
	if _flash_tween != null:
		_flash_tween.kill()

	flash_overlay.color = Color(base_color.r, base_color.g, base_color.b, 0.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(
		flash_overlay,
		"color",
		Color(base_color.r, base_color.g, base_color.b, strength),
		duration * 0.35
	)
	_flash_tween.tween_property(
		flash_overlay,
		"color",
		Color(base_color.r, base_color.g, base_color.b, 0.0),
		duration * 0.65
	)


func _start_break_time_fx(include_comeback_slowmo: bool) -> void:
	_slowmo_token += 1
	_run_break_time_fx(_slowmo_token, include_comeback_slowmo)


func _run_break_time_fx(token: int, include_comeback_slowmo: bool) -> void:
	await get_tree().create_timer(break_slowmo_delay, true, false, true).timeout
	if not is_inside_tree() or token != _slowmo_token or is_game_over:
		return

	Engine.time_scale = break_hit_stop_scale
	await get_tree().create_timer(break_hit_stop_duration, true, false, true).timeout
	if not is_inside_tree() or token != _slowmo_token:
		return

	Engine.time_scale = break_slowmo_scale
	await get_tree().create_timer(break_slowmo_duration, true, false, true).timeout
	if not is_inside_tree() or token != _slowmo_token:
		return

	if include_comeback_slowmo:
		Engine.time_scale = comeback_slowmo_scale
		await get_tree().create_timer(comeback_slowmo_duration, true, false, true).timeout
		if not is_inside_tree() or token != _slowmo_token:
			return

	if not is_game_over:
		Engine.time_scale = 1.0


func _trigger_game_over() -> void:
	if is_game_over:
		return

	is_game_over = true
	Engine.time_scale = 1.0
	get_tree().paused = false   # 防止突變暫停中途 game over
	_in_mutation = false
	if _mut_overlay:
		_mut_overlay.hide()
	audio_mgr.play(audio_mgr.LOSE)   # 失敗音效
	_clear_state_overlays()
	final_label.text = "共 %d 次客訴\n撐到第 %d 波" % [complaint_count, wave_count]
	game_over_panel.show()


func _update_victory_timer(delta: float) -> void:
	_time_left = max(_time_left - delta, 0.0)

	var mins = int(_time_left) / 60
	var secs = int(_time_left) % 60
	timer_label.text = "%d:%02d" % [mins, secs]

	if _time_left <= warning_time:
		# ── 首次進入衝刺：強制啟動高壓模式 ──────────────
		if not _in_sprint_mode:
			_in_sprint_mode = true
			_enter_sprint_pressure()

		# 顏色由 _update_sprint_visual() 負責，這裡只處理震動
		_next_warning_shake -= delta
		if _next_warning_shake <= 0.0:
			_next_warning_shake = warning_shake_interval
			_add_shake(warning_shake_strength)
	else:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))

	if _time_left <= 0.0:
		_trigger_win()


func _enter_sprint_pressure() -> void:
	audio_mgr.set_sprint_mode(true)   # BGM 加速到 160 BPM
	# 立刻重置波次計時器，觸發連續快速波次
	_wave_timer = _next_wave_in   # 讓下一幀立刻觸發波次
	for _i in range(sprint_bonus_wave_count):
		_build_wave_queue()

	# 強制生成 1–2 隻大型饕客
	var big_count = randi_range(sprint_big_enemy_min, sprint_big_enemy_max)
	for _i in range(big_count):
		_spawn_big_enemy_at(_edge_position(randi() % 4))


func _trigger_win() -> void:
	if is_game_over:
		return

	is_game_over = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	_in_mutation = false
	if _mut_overlay:
		_mut_overlay.hide()
	audio_mgr.play(audio_mgr.WIN)   # 勝利音效
	_clear_state_overlays()
	win_final_label.text = "本場客訴：%d 次" % complaint_count
	win_panel.show()


func _update_danger_vignette(delta: float) -> void:
	var target_alpha: float = 0.0
	if complaint_count >= stage3_threshold:
		var pulse = 0.5 + 0.5 * sin(_feedback_time * vignette_pulse_speed)
		target_alpha = lerp(vignette_pulse_alpha_min, vignette_pulse_alpha_max, pulse)

	var new_alpha = lerp(vignette_top.color.a, target_alpha, 6.0 * delta)
	_set_vignette_alpha(new_alpha)


func _set_vignette_alpha(alpha: float) -> void:
	var c = Color(vignette_danger_color.r, vignette_danger_color.g, vignette_danger_color.b, alpha)
	vignette_top.color    = c
	vignette_bottom.color = c
	vignette_left.color   = c
	vignette_right.color  = c


func _update_sprint_visual(delta: float) -> void:
	var in_sprint = _time_left > 0.0 and _time_left <= warning_time

	# ── 計時器閃爍顏色（黃↔橘，不用紅色）────────────────
	if in_sprint:
		var blink = 0.5 + 0.5 * sin(_feedback_time * sprint_timer_blink_speed)
		var col = sprint_timer_color.lerp(sprint_timer_flash_color, blink)
		timer_label.add_theme_color_override("font_color", col)

	# ── 畫面整體亮度 pulse ────────────────────────────────
	var target_alpha: float = 0.0
	if in_sprint:
		target_alpha = sprint_brightness_alpha_max * (0.5 + 0.5 * sin(_feedback_time * sprint_brightness_speed))
	var new_alpha = lerp(sprint_overlay.color.a, target_alpha, 7.0 * delta)
	sprint_overlay.color = Color(sprint_brightness_color.r, sprint_brightness_color.g, sprint_brightness_color.b, new_alpha)

	# ── 衝刺提示文字（緩入緩出）──────────────────────────
	var label_target: float = 0.0
	if in_sprint:
		label_target = 0.72 + 0.28 * sin(_feedback_time * sprint_timer_blink_speed * 0.5)
	var new_label_a = lerp(sprint_label.modulate.a, label_target, 4.5 * delta)
	sprint_label.modulate = Color(1.0, 1.0, 1.0, new_label_a)
	sprint_label.visible  = new_label_a > 0.005


func _clear_state_overlays() -> void:
	_set_vignette_alpha(0.0)
	sprint_overlay.color    = Color(sprint_brightness_color.r, sprint_brightness_color.g, sprint_brightness_color.b, 0.0)
	sprint_label.modulate   = Color(1.0, 1.0, 1.0, 0.0)
	sprint_label.visible    = false


func _draw() -> void:
	var ax = ARENA.position.x
	var ay = ARENA.position.y
	var ex = ARENA.end.x
	var ey = ARENA.end.y
	var dim = Color(0.0, 0.0, 0.0, 0.55)

	draw_rect(Rect2(0, 0, ax, 720), dim)
	draw_rect(Rect2(ex, 0, 1280 - ex, 720), dim)
	draw_rect(Rect2(ax, 0, ARENA.size.x, ay), dim)
	draw_rect(Rect2(ax, ey, ARENA.size.x, 720 - ey), dim)

	var border_color = Color(0.75, 0.55, 0.1, 0.75)
	var inner_color = Color(0.95, 0.75, 0.22, 0.18)
	if _get_stage() == 2:
		border_color = Color(0.95, 0.52, 0.16, 0.82)
		inner_color = Color(1.0, 0.55, 0.22, 0.18)
	elif _get_stage() >= 3:
		var pulse = 0.5 + 0.5 * sin(_feedback_time * 9.0)
		border_color = Color(1.0, 0.22 + pulse * 0.12, 0.14, 0.88)
		inner_color = Color(1.0, 0.18, 0.18, 0.18 + pulse * 0.10)

	draw_rect(ARENA, border_color, false, 3.0)
	draw_rect(Rect2(ARENA.position + Vector2(4, 4), ARENA.size - Vector2(8, 8)), inner_color, false, 1.0)


func _update_world_feedback(delta: float) -> void:
	if _in_mutation:
		world_node.position = Vector2.ZERO
		return
	_impulse_shake = max(_impulse_shake - shake_decay * delta, 0.0)

	var danger_shake = 0.0
	if complaint_count >= stage3_threshold and not is_game_over:
		var pulse = 0.5 + 0.5 * sin(_feedback_time * 20.0)
		danger_shake = danger_shake_strength * (0.45 + pulse * 0.55)

	var shake_strength = max(_impulse_shake, danger_shake)
	if shake_strength <= 0.01:
		world_node.position = Vector2.ZERO
		return

	var angle = randf() * TAU
	world_node.position = Vector2(cos(angle), sin(angle)) * shake_strength


func _add_shake(strength: float) -> void:
	_impulse_shake = max(_impulse_shake, strength)


func _sync_tension_feedback() -> void:
	var label_color = Color(1.0, 0.92, 0.3)
	if _get_stage() == 2:
		label_color = Color(1.0, 0.72, 0.28)
	elif _get_stage() >= 3:
		label_color = Color(1.0, 0.42, 0.35)
	complaint_label.add_theme_color_override("font_color", label_color)

	var ambient_color = Color(0.0, 0.0, 0.0, 0.0)
	if _get_stage() == 2:
		ambient_color = Color(stage2_tint_color.r, stage2_tint_color.g, stage2_tint_color.b, stage2_tint_alpha)
	elif _get_stage() >= 3:
		var pulse = 0.5 + 0.5 * sin(_feedback_time * 8.0)
		var alpha = stage3_tint_alpha + pulse * stage3_tint_pulse
		ambient_color = Color(stage3_tint_color.r, stage3_tint_color.g, stage3_tint_color.b, alpha)
	ambient_overlay.color = ambient_color

	food_court.complaint_count = complaint_count
	food_court.current_stage = _get_stage()
	food_court.danger_threshold = stage3_threshold
	food_court.spawn_pause_ratio = 0.0 if comeback_spawn_pause <= 0.0 else clamp(_spawn_pause_timer / comeback_spawn_pause, 0.0, 1.0)

	# 中央壓力區：把最新客訴數推給所有玩家
	for player in get_tree().get_nodes_in_group("players"):
		player.zone_complaint_count = complaint_count


# ═══════════════════════════════════════════════════
#  突變系統（Mutation System）
# ═══════════════════════════════════════════════════

# ── 突變定義（index 0-4）────────────────────────────
func _mut_def(idx: int) -> Dictionary:
	match idx:
		0: return {"title": "熱狗太興奮",  "desc": "P1 擊退距離 ×2\n（持續本局）",          "color": Color(1.0, 0.62, 0.08)}
		1: return {"title": "珍珠大爆發",  "desc": "P2 命中必定留下滑地\n（持續本局）",      "color": Color(0.28, 0.72, 1.0)}
		2: return {"title": "全場加速",    "desc": "所有人移動速度 +30%%\n（持續 15 秒）",   "color": Color(0.48, 1.0, 0.50)}
		3: return {"title": "大胃王狂潮",  "desc": "大型饕客生成頻率 ×3\n（持續 20 秒）",   "color": Color(1.0, 0.28, 0.28)}
		4: return {"title": "客訴減免",    "desc": "立即客訴 −%d" % mutation_complaint_cut, "color": Color(1.0, 0.92, 0.28)}
	return {}


# ── 突變系統主更新（_process 呼叫）──────────────────
func _update_mutation_system(delta: float) -> void:
	# 計時效果衰減（全場加速 / 大胃王狂潮）
	if _mut_speed_timer > 0.0:
		_mut_speed_timer = max(_mut_speed_timer - delta, 0.0)
		if _mut_speed_timer <= 0.0:
			for p in get_tree().get_nodes_in_group("players"):
				p.mutation_speed_mult = 1.0

	if _mut_big_timer > 0.0:
		_mut_big_timer = max(_mut_big_timer - delta, 0.0)
		if _mut_big_timer <= 0.0:
			_mut_big_active = false

	# 突變選擇 UI 倒數
	if _in_mutation:
		_update_mutation_ui_logic(delta)
		return

	if is_game_over:
		return

	# 觸發計時
	_mut_trigger_timer += delta
	if _mut_trigger_timer >= mutation_interval:
		_mut_trigger_timer = 0.0
		_show_mutation_choice()


# ── 突變 UI 倒數邏輯 ─────────────────────────────────
func _update_mutation_ui_logic(delta: float) -> void:
	_mut_countdown -= delta

	# 進度條
	var ratio = clamp(_mut_countdown / mutation_choose_time, 0.0, 1.0)
	_mut_bar_fill.size.x = _mut_bar_bg.size.x * ratio
	_mut_cd_label.text   = "%.1f 秒後自動隨機選擇" % maxf(_mut_countdown, 0.0)

	# 滑鼠懸停
	var mp = get_viewport().get_mouse_position()
	_mut_hovered = _get_hovered_card(mp)

	for i in range(3):
		if i == _mut_hovered:
			_mut_cards[i].color = mutation_card_hover
		elif i == _mut_p2_cursor:
			_mut_cards[i].color = mutation_card_p2sel
		else:
			_mut_cards[i].color = mutation_card_normal

	# 時間到 → 自動隨機選
	if _mut_countdown <= 0.0:
		_hide_mutation_choice(randi() % 3)


# ── 顯示突變選擇畫面 ─────────────────────────────────
func _show_mutation_choice() -> void:
	if is_game_over:
		return

	# 選三個不重複突變
	var pool = [0, 1, 2, 3, 4]
	pool.shuffle()
	_mut_choices = pool.slice(0, 3)
	_mut_hovered  = -1
	_mut_p2_cursor = 0
	_mut_countdown = mutation_choose_time
	_in_mutation   = true

	# 填卡片內容
	for i in range(3):
		var d : Dictionary = _mut_def(_mut_choices[i])
		_mut_card_tl[i].text = d["title"]
		_mut_card_dl[i].text = d["desc"]
		var c : Color = d["color"]
		_mut_card_nl[i].add_theme_color_override("font_color", Color(c.r, c.g, c.b, 0.55))
		_mut_card_tl[i].add_theme_color_override("font_color", c)
		_mut_cards[i].color = mutation_card_normal

	_mut_bar_fill.size.x = _mut_bar_bg.size.x
	_mut_cd_label.text   = "%.1f 秒後自動隨機選擇" % mutation_choose_time
	_mut_overlay.show()
	audio_mgr.play(audio_mgr.MUTATION)   # 突變出現音效
	get_tree().paused = true


# ── 選擇並結束突變畫面 ───────────────────────────────
func _hide_mutation_choice(slot: int) -> void:
	get_tree().paused = false
	_in_mutation = false
	_mut_overlay.hide()
	_apply_mutation(_mut_choices[slot])
	_mut_trigger_timer = 0.0


# ── 套用突變效果 ─────────────────────────────────────
func _apply_mutation(mut_id: int) -> void:
	match mut_id:
		0:  # 熱狗太興奮：P1 擊退 ×2（永久）
			for p in get_tree().get_nodes_in_group("players"):
				if p.player_index == 1:
					p.proj_knockback *= mutation_p1_kb_mult

		1:  # 珍珠大爆發：P2 命中必定滑地（永久）
			for p in get_tree().get_nodes_in_group("players"):
				if p.player_index == 2:
					p.p2_always_grease = true

		2:  # 全場加速 +30%，持續 15 秒
			for p in get_tree().get_nodes_in_group("players"):
				p.mutation_speed_mult = mutation_speed_ratio
			_mut_speed_timer = mutation_speed_secs

		3:  # 大胃王狂潮：大型饕客機率 ×3，持續 20 秒
			_mut_big_active = true
			_mut_big_timer  = mutation_big_secs

		4:  # 客訴減免：立即 -N
			_set_complaint_count(complaint_count - mutation_complaint_cut)


# ── 滑鼠在哪張卡片上（回傳 0-2，-1=沒有）───────────
func _get_hovered_card(mouse_pos: Vector2) -> int:
	for i in range(3):
		var card = _mut_cards[i]
		var r = Rect2(card.global_position, card.size)
		if r.has_point(mouse_pos):
			return i
	return -1


# ── 輸入：突變選擇期間的 P1 點擊 / P2 鍵盤 ──────────
func _unhandled_input(event: InputEvent) -> void:
	# ── 除錯：F1 鍵立刻觸發突變選擇（測試用）──────────
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5 and not is_game_over and not _in_mutation:
			_show_mutation_choice()
			return

	if not _in_mutation:
		return

	# P1：左鍵點擊選卡
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var h = _get_hovered_card(mb.position)
			if h >= 0:
				_hide_mutation_choice(h)
		return

	# P2：J/L 移動游標，Enter 確認
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_J:
				_mut_p2_cursor = (_mut_p2_cursor - 1 + 3) % 3
			KEY_L:
				_mut_p2_cursor = (_mut_p2_cursor + 1) % 3
			KEY_ENTER, KEY_KP_ENTER:
				_hide_mutation_choice(_mut_p2_cursor)


# ── 突變 UI 建立（在 _setup_ui 之後呼叫）────────────
func _setup_mutation_ui() -> void:
	# 全螢幕半透明遮罩
	_mut_overlay = ColorRect.new()
	_mut_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mut_overlay.color = mutation_overlay_color
	_mut_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mut_overlay.hide()
	ui_layer.add_child(_mut_overlay)

	# 標題
	_mut_title = Label.new()
	_mut_title.text = "⚡  突變選擇！"
	_mut_title.position = Vector2(0.0, 108.0)
	_mut_title.size = Vector2(1280.0, 64.0)
	_mut_title.pivot_offset = Vector2(640.0, 32.0)
	_mut_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mut_title.add_theme_font_size_override("font_size", 54)
	_mut_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.28))
	_mut_overlay.add_child(_mut_title)

	# 副標
	_mut_sub = Label.new()
	_mut_sub.text = "選一個突變效果繼續遊戲"
	_mut_sub.position = Vector2(0.0, 180.0)
	_mut_sub.size = Vector2(1280.0, 36.0)
	_mut_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mut_sub.add_theme_font_size_override("font_size", 24)
	_mut_sub.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0, 0.80))
	_mut_overlay.add_child(_mut_sub)

	# 三張卡片
	var total_w := mutation_card_w * 3.0 + mutation_card_gap * 2.0
	var start_x := (1280.0 - total_w) * 0.5
	var card_y  := 228.0

	for i in range(3):
		var card := ColorRect.new()
		card.position = Vector2(start_x + i * (mutation_card_w + mutation_card_gap), card_y)
		card.size     = Vector2(mutation_card_w, mutation_card_h)
		card.color    = mutation_card_normal
		_mut_overlay.add_child(card)
		_mut_cards.append(card)

		# 邊框效果（稍大的暗色底層）
		var border := ColorRect.new()
		border.position = Vector2(-2.0, -2.0)
		border.size     = Vector2(mutation_card_w + 4.0, mutation_card_h + 4.0)
		border.color    = Color(0.0, 0.0, 0.0, 0.5)
		border.z_index  = -1
		card.add_child(border)

		# 編號
		var nl := Label.new()
		nl.text     = str(i + 1)
		nl.position = Vector2(10.0, 6.0)
		nl.size     = Vector2(40.0, 28.0)
		nl.add_theme_font_size_override("font_size", 22)
		nl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.45))
		card.add_child(nl)
		_mut_card_nl.append(nl)

		# 突變名稱
		var tl := Label.new()
		tl.position = Vector2(0.0, 40.0)
		tl.size     = Vector2(mutation_card_w, 44.0)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.add_theme_font_size_override("font_size", 28)
		tl.add_theme_color_override("font_color", Color.WHITE)
		card.add_child(tl)
		_mut_card_tl.append(tl)

		# 分隔線
		var sep := ColorRect.new()
		sep.position = Vector2(16.0, 92.0)
		sep.size     = Vector2(mutation_card_w - 32.0, 2.0)
		sep.color    = Color(1.0, 1.0, 1.0, 0.18)
		card.add_child(sep)

		# 說明
		var dl := Label.new()
		dl.position = Vector2(10.0, 102.0)
		dl.size     = Vector2(mutation_card_w - 20.0, mutation_card_h - 110.0)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		dl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_size_override("font_size", 19)
		dl.add_theme_color_override("font_color", Color(0.90, 0.88, 1.0, 0.90))
		card.add_child(dl)
		_mut_card_dl.append(dl)

	# 倒數進度條背景
	var bar_y := 446.0
	_mut_bar_bg = ColorRect.new()
	_mut_bar_bg.position = Vector2(240.0, bar_y)
	_mut_bar_bg.size     = Vector2(800.0, 16.0)
	_mut_bar_bg.color    = Color(0.15, 0.15, 0.15, 0.85)
	_mut_overlay.add_child(_mut_bar_bg)

	_mut_bar_fill = ColorRect.new()
	_mut_bar_fill.position = Vector2(0.0, 0.0)
	_mut_bar_fill.size     = Vector2(800.0, 16.0)
	_mut_bar_fill.color    = mutation_bar_color
	_mut_bar_bg.add_child(_mut_bar_fill)

	# 倒數文字
	_mut_cd_label = Label.new()
	_mut_cd_label.position = Vector2(0.0, 470.0)
	_mut_cd_label.size     = Vector2(1280.0, 34.0)
	_mut_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mut_cd_label.add_theme_font_size_override("font_size", 22)
	_mut_cd_label.add_theme_color_override("font_color", Color(0.78, 0.95, 0.78, 0.88))
	_mut_overlay.add_child(_mut_cd_label)

	# 操作提示
	_mut_hint = Label.new()
	_mut_hint.text     = "P1 滑鼠點擊選擇   ·   P2  J/L 移動 / Enter 確認"
	_mut_hint.position = Vector2(0.0, 512.0)
	_mut_hint.size     = Vector2(1280.0, 30.0)
	_mut_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mut_hint.add_theme_font_size_override("font_size", 19)
	_mut_hint.add_theme_color_override("font_color", Color(0.72, 0.70, 0.88, 0.68))
	_mut_overlay.add_child(_mut_hint)


func _on_restart_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false   # 防止重啟時仍處於突變暫停狀態
	get_tree().reload_current_scene()


func _setup_ui() -> void:
	ambient_overlay = ColorRect.new()
	ambient_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ambient_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	ambient_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ambient_overlay)

	flash_overlay = ColorRect.new()
	flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(flash_overlay)

	complaint_label = Label.new()
	complaint_label.text = "客訴 0 / %d" % max_complaints
	complaint_label.position = Vector2(520, 12)
	complaint_label.size = Vector2(240, 44)
	complaint_label.pivot_offset = Vector2(120, 22)
	complaint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complaint_label.add_theme_font_size_override("font_size", 26)
	ui_layer.add_child(complaint_label)

	spike_label = Label.new()
	spike_label.position = Vector2(458, 54)
	spike_label.size = Vector2(364, 60)
	spike_label.pivot_offset = Vector2(182, 30)
	spike_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spike_label.add_theme_font_size_override("font_size", 38)
	spike_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.12))
	spike_label.hide()
	ui_layer.add_child(spike_label)

	stage_banner = ColorRect.new()
	stage_banner.position = Vector2(170, 78)
	stage_banner.size = Vector2(940, 88)
	stage_banner.color = Color(1.0, 0.45, 0.12, 0.0)
	stage_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_banner.hide()
	ui_layer.add_child(stage_banner)

	stage_label = Label.new()
	stage_label.position = Vector2(170, 94)
	stage_label.size = Vector2(940, 54)
	stage_label.pivot_offset = Vector2(470, 27)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size", 46)
	stage_label.hide()
	ui_layer.add_child(stage_label)

	comeback_label = Label.new()
	comeback_label.position = Vector2(160, 174)
	comeback_label.size = Vector2(960, 52)
	comeback_label.pivot_offset = Vector2(480, 26)
	comeback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comeback_label.add_theme_font_size_override("font_size", 34)
	comeback_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	comeback_label.hide()
	ui_layer.add_child(comeback_label)

	game_over_panel = Panel.new()
	game_over_panel.position = Vector2(390, 185)
	game_over_panel.size = Vector2(500, 350)
	game_over_panel.hide()
	ui_layer.add_child(game_over_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(vbox)

	var title = Label.new()
	title.text = "客訴太多啦！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(title)

	final_label = Label.new()
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_label.add_theme_font_size_override("font_size", 22)
	final_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(final_label)

	var btn = Button.new()
	btn.text = "重新開始"
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(btn)

	# ── 倒數計時器（右上角）────────────────────────────
	timer_label = Label.new()
	timer_label.text = "%d:%02d" % [int(game_duration) / 60, int(game_duration) % 60]
	timer_label.position = Vector2(990, 12)
	timer_label.size = Vector2(160, 44)
	timer_label.pivot_offset = Vector2(80, 22)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 26)
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	ui_layer.add_child(timer_label)

	# ── 勝利面板 ────────────────────────────────────────
	win_panel = Panel.new()
	win_panel.position = Vector2(390, 185)
	win_panel.size = Vector2(500, 350)
	win_panel.hide()
	ui_layer.add_child(win_panel)

	var win_vbox = VBoxContainer.new()
	win_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_vbox.add_theme_constant_override("separation", 20)
	win_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	win_panel.add_child(win_vbox)

	var win_title = Label.new()
	win_title.text = "撐過 2 分鐘！"
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title.add_theme_font_size_override("font_size", 40)
	win_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
	win_vbox.add_child(win_title)

	win_final_label = Label.new()
	win_final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_final_label.add_theme_font_size_override("font_size", 22)
	win_final_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	win_vbox.add_child(win_final_label)

	var win_btn = Button.new()
	win_btn.text = "重新開始"
	win_btn.add_theme_font_size_override("font_size", 22)
	win_btn.pressed.connect(_on_restart_pressed)
	win_vbox.add_child(win_btn)

	# ── 危險 vignette（4 邊緣色塊，初始透明）──────────────
	var edge = vignette_edge_size
	var base_vc = Color(vignette_danger_color.r, vignette_danger_color.g, vignette_danger_color.b, 0.0)

	vignette_top = ColorRect.new()
	vignette_top.position = Vector2(0.0, 0.0)
	vignette_top.size = Vector2(1280.0, edge)
	vignette_top.color = base_vc
	vignette_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(vignette_top)

	vignette_bottom = ColorRect.new()
	vignette_bottom.position = Vector2(0.0, 720.0 - edge)
	vignette_bottom.size = Vector2(1280.0, edge)
	vignette_bottom.color = base_vc
	vignette_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(vignette_bottom)

	vignette_left = ColorRect.new()
	vignette_left.position = Vector2(0.0, 0.0)
	vignette_left.size = Vector2(edge, 720.0)
	vignette_left.color = base_vc
	vignette_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(vignette_left)

	vignette_right = ColorRect.new()
	vignette_right.position = Vector2(1280.0 - edge, 0.0)
	vignette_right.size = Vector2(edge, 720.0)
	vignette_right.color = base_vc
	vignette_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(vignette_right)

	# ── 衝刺亮度 pulse overlay ─────────────────────────────
	sprint_overlay = ColorRect.new()
	sprint_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprint_overlay.color = Color(sprint_brightness_color.r, sprint_brightness_color.g, sprint_brightness_color.b, 0.0)
	sprint_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(sprint_overlay)

	# ── 衝刺提示文字 ──────────────────────────────────────
	sprint_label = Label.new()
	sprint_label.text = sprint_label_text
	sprint_label.position = Vector2(440.0, 60.0)
	sprint_label.size = Vector2(400.0, 50.0)
	sprint_label.pivot_offset = Vector2(200.0, 25.0)
	sprint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sprint_label.add_theme_font_size_override("font_size", 36)
	sprint_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	sprint_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	sprint_label.visible = false
	ui_layer.add_child(sprint_label)
