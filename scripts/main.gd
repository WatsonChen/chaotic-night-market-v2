extends Node2D

# ===================================================
# main.gd — 主遊戲邏輯
#
# ┌─────────────────────────────────────────────────┐
# │ 客訴升級系統（Escalation System）                │
# │                                                 │
# │  第一階段（0–3）：普通波次 + 爆發波             │
# │  第二階段（4–7）：大型饕客開始偶爾出現          │
# │  第三階段（8–10）：大型饕客頻繁出現，           │
# │                    爆發波也夾帶大型饕客          │
# └─────────────────────────────────────────────────┘
#
# ── 波次參數（快速調整區）──────────────────────────
#   WAVE_INTERVAL_MIN   最短波次間隔（秒）  ← 目前 5.0
#   WAVE_INTERVAL_MAX   最長波次間隔（秒）  ← 目前 8.0
#   WAVE_SIZE_MIN       每波最少普通敵人數  ← 目前 6
#   WAVE_SIZE_MAX       每波最多普通敵人數  ← 目前 10
#
# ── 大型饕客生成（快速調整區）─────────────────────
#   STAGE2_BIG_CHANCE   第二階段每波出現機率  ← 目前 0.30
#   STAGE3_BIG_CHANCE   第三階段每波出現機率  ← 目前 0.70
#   STAGE3_DOUBLE_CHANCE 第三階段同時出現兩隻的機率 ← 目前 0.40
# ===================================================

const PLAYER_SCENE    = preload("res://scenes/player.tscn")
const ENEMY_SCENE     = preload("res://scenes/enemy.tscn")
const BIG_ENEMY_SCENE = preload("res://scenes/big_enemy.tscn")

const MAX_COMPLAINTS = 10

# ── 客訴升級閾值（快速調整區）───────────────────────
const STAGE2_THRESHOLD = 4    # ← 調這裡改第二階段觸發客訴數
const STAGE3_THRESHOLD = 8    # ← 調這裡改第三階段觸發客訴數

# ── 波次參數（快速調整區）─────────────────────────
const WAVE_INTERVAL_MIN  = 5.0    # ← 調這裡改最短波次間隔（秒）
const WAVE_INTERVAL_MAX  = 8.0    # ← 調這裡改最長波次間隔（秒）
const WAVE_SIZE_MIN      = 6      # ← 調這裡改每波最少敵人數
const WAVE_SIZE_MAX      = 10     # ← 調這裡改每波最多敵人數
const SPAWN_EDGES_COUNT  = 2      # ← 調這裡改每波幾條邊（1 或 2）
const WAVE_SPAWN_STAGGER = 0.07   # ← 調這裡改每隻出生間隔（秒）

# ── 大型饕客生成（快速調整區）────────────────────
const STAGE2_BIG_CHANCE    = 0.30  # ← 第二階段每波出現機率
const STAGE3_BIG_CHANCE    = 0.70  # ← 第三階段每波出現機率
const STAGE3_DOUBLE_CHANCE = 0.40  # ← 第三階段同時兩隻的機率（在 BIG_CHANCE 內）

# ── 爆發波參數（快速調整區）─────────────────────────
const SPIKE_INTERVAL_MIN = 15.0   # ← 調這裡改最短爆發觸發間隔（秒）
const SPIKE_INTERVAL_MAX = 20.0   # ← 調這裡改最長爆發觸發間隔（秒）
const SPIKE_DURATION     = 4.0    # ← 調這裡改每次爆發持續秒數
const SPIKE_SPAWN_RATE   = 0.30   # ← 調這裡改爆發期間每隻生成間隔（秒）

# Arena 範圍
const ARENA = Rect2(160.0, 100.0, 960.0, 520.0)

var complaint_count : int  = 0
var wave_count      : int  = 0
var is_game_over    : bool = false

# 波次計時
var _wave_timer   : float = 0.0
var _next_wave_in : float = 3.0   # 遊戲開始 3 秒後第一波（快點進入狀態）

# 出生佇列（stagger 用）
var _spawn_queue  : Array = []    # 待生成的 Vector2 位置
var _queue_timer  : float = 0.0

# 爆發波狀態
var _spike_timer      : float = 0.0
var _next_spike_in    : float = 0.0   # 在 _ready 中初始化
var _in_spike         : bool  = false
var _spike_left       : float = 0.0
var _spike_spawn_cd   : float = 0.0

# 動態建立的 UI 節點
var complaint_label : Label
var game_over_panel : Panel
var final_label     : Label
var spike_label     : Label
var stage_label     : Label   # 階段轉換提示

@onready var players_node     = $Players
@onready var enemies_node     = $Enemies
@onready var projectiles_node = $Projectiles
@onready var ui_layer         = $UI


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.04, 0.12))
	queue_redraw()
	_setup_ui()
	_spawn_players()
	_next_spike_in = randf_range(SPIKE_INTERVAL_MIN, SPIKE_INTERVAL_MAX)


func _process(delta: float) -> void:
	if is_game_over:
		return

	# ── 波次計時 ──────────────────────────────────
	_wave_timer += delta
	if _wave_timer >= _next_wave_in:
		_wave_timer    = 0.0
		_next_wave_in  = randf_range(WAVE_INTERVAL_MIN, WAVE_INTERVAL_MAX)
		wave_count    += 1
		_build_wave_queue()

	# ── 爆發波計時 ────────────────────────────────
	if not _in_spike:
		_spike_timer += delta
		if _spike_timer >= _next_spike_in:
			_spike_timer   = 0.0
			_next_spike_in = randf_range(SPIKE_INTERVAL_MIN, SPIKE_INTERVAL_MAX)
			_in_spike      = true
			_spike_left    = SPIKE_DURATION
			_spike_spawn_cd = 0.0
			_show_spike_warning()
	else:
		_spike_left     -= delta
		_spike_spawn_cd -= delta
		if _spike_spawn_cd <= 0.0:
			_spike_spawn_cd = SPIKE_SPAWN_RATE
			# 每次爆發同時從兩條邊各生一隻，製造包夾感
			var edges = [0, 1, 2, 3]
			edges.shuffle()
			_spawn_enemy_at(_edge_position(edges[0]))
			_spawn_enemy_at(_edge_position(edges[1]))
			# 第三階段爆發波：額外夾帶一隻大型饕客
			if _get_stage() >= 3 and randf() < 0.45:
				_spawn_big_enemy_at(_edge_position(edges[2]))
		if _spike_left <= 0.0:
			_in_spike = false

	# ── 佇列逐隻生成（stagger）────────────────────
	if _spawn_queue.size() > 0:
		_queue_timer -= delta
		if _queue_timer <= 0.0:
			_spawn_enemy_at(_spawn_queue.pop_front())
			_queue_timer = WAVE_SPAWN_STAGGER


# ── 建立兩名玩家 ──────────────────────────────────

func _spawn_players() -> void:
	var p1 = PLAYER_SCENE.instantiate()
	p1.player_index = 1
	p1.position     = Vector2(380, 360)
	players_node.add_child(p1)

	var p2 = PLAYER_SCENE.instantiate()
	p2.player_index = 2
	p2.position     = Vector2(900, 360)
	players_node.add_child(p2)


# ── 波次建立：隨機選邊，塞入佇列 ─────────────────

func _build_wave_queue() -> void:
	var count = randi_range(WAVE_SIZE_MIN, WAVE_SIZE_MAX)

	# 從四條邊（0=上 1=下 2=左 3=右）隨機選 SPAWN_EDGES_COUNT 條
	var all_edges = [0, 1, 2, 3]
	all_edges.shuffle()
	var chosen_edges = all_edges.slice(0, SPAWN_EDGES_COUNT)

	for i in count:
		var edge = chosen_edges[i % chosen_edges.size()]
		_spawn_queue.append(_edge_position(edge))

	_queue_timer = 0.0   # 立刻開始生成第一隻

	# ── 大型饕客生成（依客訴階段決定機率）────────────
	var stage = _get_stage()
	if stage == 2 and randf() < STAGE2_BIG_CHANCE:
		_spawn_big_enemy_at(_edge_position(randi() % 4))
	elif stage == 3:
		if randf() < STAGE3_BIG_CHANCE:
			_spawn_big_enemy_at(_edge_position(randi() % 4))
			# 第三階段有機率同時生成第二隻，從對側邊進入
			if randf() < STAGE3_DOUBLE_CHANCE:
				var all_e = [0, 1, 2, 3]
				all_e.shuffle()
				_spawn_big_enemy_at(_edge_position(all_e[0]))


func _edge_position(edge: int) -> Vector2:
	var ax = ARENA.position.x
	var ay = ARENA.position.y
	var ex = ARENA.end.x
	var ey = ARENA.end.y
	match edge:
		0: return Vector2(randf_range(ax, ex), ay - 32.0)   # 上
		1: return Vector2(randf_range(ax, ex), ey + 32.0)   # 下
		2: return Vector2(ax - 32.0, randf_range(ay, ey))   # 左
		3: return Vector2(ex + 32.0, randf_range(ay, ey))   # 右
	return Vector2(640.0, 360.0)


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


# ── 客訴升級階段 ──────────────────────────────────

func _get_stage() -> int:
	if complaint_count >= STAGE3_THRESHOLD:
		return 3
	elif complaint_count >= STAGE2_THRESHOLD:
		return 2
	return 1


# ── 客訴系統 ─────────────────────────────────────

func _on_enemy_reach_center() -> void:
	if is_game_over:
		return

	var old_stage = _get_stage()
	complaint_count += 1
	complaint_label.text = "客訴 %d / %d" % [complaint_count, MAX_COMPLAINTS]

	var tw = create_tween()
	tw.tween_property(complaint_label, "scale", Vector2(1.5, 1.5), 0.08)
	tw.tween_property(complaint_label, "scale", Vector2(1.0, 1.0), 0.18)

	# 階段升級偵測
	var new_stage = _get_stage()
	if new_stage > old_stage:
		_show_stage_transition(new_stage)

	if complaint_count >= MAX_COMPLAINTS:
		_trigger_game_over()


func _trigger_game_over() -> void:
	is_game_over = true
	final_label.text = "共 %d 次客訴\n撐到第 %d 波" % [complaint_count, wave_count]
	game_over_panel.show()


func _draw() -> void:
	var ax = ARENA.position.x
	var ay = ARENA.position.y
	var ex = ARENA.end.x
	var ey = ARENA.end.y
	var dim = Color(0.0, 0.0, 0.0, 0.55)
	draw_rect(Rect2(0,  0,  ax,        720),  dim)
	draw_rect(Rect2(ex, 0,  1280 - ex, 720),  dim)
	draw_rect(Rect2(ax, 0,  ARENA.size.x, ay), dim)
	draw_rect(Rect2(ax, ey, ARENA.size.x, 720 - ey), dim)
	draw_rect(ARENA, Color(0.75, 0.55, 0.1, 0.75), false, 3.0)
	draw_rect(
		Rect2(ARENA.position + Vector2(4, 4), ARENA.size - Vector2(8, 8)),
		Color(0.9, 0.7, 0.2, 0.2), false, 1.0
	)


# ── 階段升級提示動畫 ─────────────────────────────

func _show_stage_transition(stage: int) -> void:
	var msgs = {
		2: "!! 大型饕客出沒 !!",
		3: "!! 已到極限 !!",
	}
	var colors = {
		2: Color(0.85, 0.40, 1.00),   # 紫色（呼應大型饕客顏色）
		3: Color(1.00, 0.20, 0.15),   # 紅色（最高壓力）
	}
	stage_label.text = msgs.get(stage, "")
	# 動態改字色，讓 modulate 純做 alpha 淡入淡出
	stage_label.add_theme_color_override("font_color", colors.get(stage, Color.WHITE))
	stage_label.modulate = Color(1, 1, 1, 0)
	stage_label.scale    = Vector2(0.6, 0.6)
	stage_label.show()

	var tw = create_tween()
	tw.tween_property(stage_label, "modulate", Color(1, 1, 1, 1), 0.18)
	tw.parallel().tween_property(stage_label, "scale", Vector2(1.2, 1.2), 0.18)
	tw.tween_property(stage_label, "scale", Vector2(1.0, 1.0), 0.12)
	tw.tween_interval(2.0)
	tw.tween_property(stage_label, "modulate", Color(1, 1, 1, 0), 0.50)
	tw.tween_callback(stage_label.hide)


# ── 爆發波警告動畫 ───────────────────────────────

func _show_spike_warning() -> void:
	spike_label.text    = "!! 爆發 !!"
	spike_label.modulate = Color(1.0, 0.3, 0.1, 0.0)
	spike_label.scale   = Vector2(0.5, 0.5)
	spike_label.show()

	var tw = create_tween()
	tw.tween_property(spike_label, "modulate", Color(1.0, 0.3, 0.1, 1.0), 0.15)
	tw.parallel().tween_property(spike_label, "scale", Vector2(1.3, 1.3), 0.15)
	tw.tween_property(spike_label, "scale",   Vector2(1.0, 1.0), 0.10)
	tw.tween_interval(SPIKE_DURATION - 0.5)
	tw.tween_property(spike_label, "modulate", Color(1.0, 0.3, 0.1, 0.0), 0.40)
	tw.tween_callback(spike_label.hide)


func _on_restart_pressed() -> void:
	# 確保 hit stop coroutine 不會在 reload 後存取已釋放的 tree
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ── UI 動態建立 ──────────────────────────────────

func _setup_ui() -> void:
	complaint_label = Label.new()
	complaint_label.text = "客訴 0 / %d" % MAX_COMPLAINTS
	complaint_label.position    = Vector2(540, 12)
	complaint_label.size        = Vector2(200, 44)
	complaint_label.pivot_offset = Vector2(100, 22)
	complaint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complaint_label.add_theme_font_size_override("font_size", 26)
	complaint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	ui_layer.add_child(complaint_label)

	game_over_panel = Panel.new()
	game_over_panel.position = Vector2(390, 185)
	game_over_panel.size     = Vector2(500, 350)
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

	# 爆發波警告 Label（出現在畫面正中央上方）
	spike_label = Label.new()
	spike_label.text = "!! 爆發 !!"
	spike_label.position    = Vector2(480, 60)
	spike_label.size        = Vector2(320, 60)
	spike_label.pivot_offset = Vector2(160, 30)
	spike_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spike_label.add_theme_font_size_override("font_size", 36)
	spike_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
	spike_label.hide()
	ui_layer.add_child(spike_label)

	# 階段升級提示 Label（在爆發波 Label 下方）
	stage_label = Label.new()
	stage_label.text = ""
	stage_label.position     = Vector2(400, 110)
	stage_label.size         = Vector2(480, 52)
	stage_label.pivot_offset = Vector2(240, 26)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size", 30)
	stage_label.add_theme_color_override("font_color", Color(0.85, 0.40, 1.00))
	stage_label.hide()
	ui_layer.add_child(stage_label)
