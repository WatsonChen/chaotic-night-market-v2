extends Node2D

# ===================================================
# main.gd — 主遊戲邏輯
#
# 波次系統：每 5~8 秒噴一批（mini wave），
#   集中從 1~2 條邊生成，每隻間隔 0.08s 依序出生。
#   這樣「一波壓來」的壓迫感比逐秒單生更強。
#
# ── 可調整波次參數 ──────────────────────────────────
#   WAVE_INTERVAL_MIN   最短波次間隔（秒）  ← 目前 5.0
#   WAVE_INTERVAL_MAX   最長波次間隔（秒）  ← 目前 8.0
#   WAVE_SIZE_MIN       每波最少敵人數      ← 目前 6
#   WAVE_SIZE_MAX       每波最多敵人數      ← 目前 10
#   SPAWN_EDGES_COUNT   每波幾條邊生成      ← 目前 2（1=更集中/2=兩側夾擊）
#   WAVE_SPAWN_STAGGER  每隻出生間隔（秒）  ← 目前 0.07
# ===================================================

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ENEMY_SCENE  = preload("res://scenes/enemy.tscn")

const MAX_COMPLAINTS = 10

# ── 波次參數（快速調整區）─────────────────────────
const WAVE_INTERVAL_MIN  = 5.0    # ← 調這裡改最短波次間隔（秒）
const WAVE_INTERVAL_MAX  = 8.0    # ← 調這裡改最長波次間隔（秒）
const WAVE_SIZE_MIN      = 6      # ← 調這裡改每波最少敵人數
const WAVE_SIZE_MAX      = 10     # ← 調這裡改每波最多敵人數
const SPAWN_EDGES_COUNT  = 2      # ← 調這裡改每波幾條邊（1 或 2）
const WAVE_SPAWN_STAGGER = 0.07   # ← 調這裡改每隻出生間隔（秒）

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

# 動態建立的 UI 節點
var complaint_label : Label
var game_over_panel : Panel
var final_label     : Label

@onready var players_node     = $Players
@onready var enemies_node     = $Enemies
@onready var projectiles_node = $Projectiles
@onready var ui_layer         = $UI


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.04, 0.12))
	queue_redraw()
	_setup_ui()
	_spawn_players()


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
		# 每隻隨機分配到其中一條邊
		var edge = chosen_edges[i % chosen_edges.size()]
		_spawn_queue.append(_edge_position(edge))

	_queue_timer = 0.0   # 立刻開始生成第一隻


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


# ── 客訴系統 ─────────────────────────────────────

func _on_enemy_reach_center() -> void:
	if is_game_over:
		return
	complaint_count += 1
	complaint_label.text = "客訴 %d / %d" % [complaint_count, MAX_COMPLAINTS]

	var tw = create_tween()
	tw.tween_property(complaint_label, "scale", Vector2(1.5, 1.5), 0.08)
	tw.tween_property(complaint_label, "scale", Vector2(1.0, 1.0), 0.18)

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


func _on_restart_pressed() -> void:
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
