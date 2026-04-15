extends Node2D

# ===================================================
# main.gd — 主遊戲邏輯
# 負責：敵人生成、客訴計數、遊戲結束流程
# ===================================================

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ENEMY_SCENE  = preload("res://scenes/enemy.tscn")

const MAX_COMPLAINTS      = 10
const BASE_SPAWN_INTERVAL = 3.0
const MIN_SPAWN_INTERVAL  = 0.8

# ── Arena（可活動範圍，比視窗縮小 ~22% 線性）──────
# 寬 960 / 高 520，中心維持 (640, 360)
const ARENA = Rect2(160.0, 100.0, 960.0, 520.0)

var complaint_count : int   = 0      # 當前客訴數
var wave_count      : int   = 0      # 已生成波次（用於加速生成）
var is_game_over    : bool  = false  # 遊戲是否已結束
var spawn_timer     : float = 0.0   # 距離下次生成的累計時間

# 動態建立的 UI 節點
var complaint_label  : Label
var game_over_panel  : Panel
var final_label      : Label

@onready var players_node    = $Players
@onready var enemies_node    = $Enemies
@onready var projectiles_node = $Projectiles
@onready var ui_layer        = $UI


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.04, 0.12))
	queue_redraw()   # 畫 arena 邊界（靜態，只需一次）
	_setup_ui()
	_spawn_players()


func _process(delta: float) -> void:
	if is_game_over:
		return

	# 累計時間，決定何時生成下一隻敵人
	spawn_timer += delta
	var interval = max(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - wave_count * 0.08)
	if spawn_timer >= interval:
		spawn_timer = 0.0
		_spawn_enemy()
		wave_count += 1


# ── 建立兩名玩家 ──────────────────────────────────

func _spawn_players() -> void:
	# P1：橘色，出生在左半場
	var p1 = PLAYER_SCENE.instantiate()
	p1.player_index = 1
	p1.position = Vector2(380, 360)
	players_node.add_child(p1)

	# P2：藍色，出生在右半場
	var p2 = PLAYER_SCENE.instantiate()
	p2.player_index = 2
	p2.position = Vector2(900, 360)
	players_node.add_child(p2)


# ── 敵人生成 ─────────────────────────────────────

func _spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.position = _get_random_edge_position()
	enemies_node.add_child(enemy)
	# 連接「抵達中央」信號
	enemy.reach_center.connect(_on_enemy_reach_center)


func _get_random_edge_position() -> Vector2:
	# 從 arena 四邊稍微外側隨機取一點生成
	var ax = ARENA.position.x
	var ay = ARENA.position.y
	var ex = ARENA.end.x
	var ey = ARENA.end.y
	match randi() % 4:
		0: return Vector2(randf_range(ax, ex), ay - 32.0)  # 上
		1: return Vector2(randf_range(ax, ex), ey + 32.0)  # 下
		2: return Vector2(ax - 32.0, randf_range(ay, ey))  # 左
		3: return Vector2(ex + 32.0, randf_range(ay, ey))  # 右
	return Vector2(640.0, 360.0)


# ── 客訴系統 ─────────────────────────────────────

func _on_enemy_reach_center() -> void:
	_add_complaint()


func _add_complaint() -> void:
	if is_game_over:
		return

	complaint_count += 1
	complaint_label.text = "客訴 %d / %d" % [complaint_count, MAX_COMPLAINTS]

	# 彈跳動畫：放大後回彈
	var tw = create_tween()
	tw.tween_property(complaint_label, "scale", Vector2(1.5, 1.5), 0.08)
	tw.tween_property(complaint_label, "scale", Vector2(1.0, 1.0), 0.18)

	if complaint_count >= MAX_COMPLAINTS:
		_trigger_game_over()


# ── Game Over ────────────────────────────────────

func _trigger_game_over() -> void:
	is_game_over = true
	final_label.text = "共 %d 次客訴\n撐到第 %d 波" % [complaint_count, wave_count]
	game_over_panel.show()


func _draw() -> void:
	# ── arena 外側暗色遮罩（四個邊緣矩形）
	var ax = ARENA.position.x
	var ay = ARENA.position.y
	var ex = ARENA.end.x
	var ey = ARENA.end.y
	var dim = Color(0.0, 0.0, 0.0, 0.55)
	draw_rect(Rect2(0,   0,  ax,       720),     dim)       # 左
	draw_rect(Rect2(ex,  0,  1280-ex,  720),     dim)       # 右
	draw_rect(Rect2(ax,  0,  ARENA.size.x, ay),  dim)       # 上
	draw_rect(Rect2(ax,  ey, ARENA.size.x, 720-ey), dim)    # 下

	# ── arena 邊界光暈線（金色）
	draw_rect(ARENA, Color(0.75, 0.55, 0.1, 0.75), false, 3.0)
	# 內側微光（讓邊界更有存在感）
	draw_rect(
		Rect2(ARENA.position + Vector2(4, 4), ARENA.size - Vector2(8, 8)),
		Color(0.9, 0.7, 0.2, 0.2), false, 1.0
	)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


# ── UI 動態建立 ──────────────────────────────────

func _setup_ui() -> void:
	# ── 客訴計數標籤（畫面上方中央）
	complaint_label = Label.new()
	complaint_label.text = "客訴 0 / %d" % MAX_COMPLAINTS
	complaint_label.position = Vector2(540, 12)
	complaint_label.size = Vector2(200, 44)
	complaint_label.pivot_offset = Vector2(100, 22)   # 以中心縮放
	complaint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complaint_label.add_theme_font_size_override("font_size", 26)
	complaint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	ui_layer.add_child(complaint_label)

	# ── Game Over 面板（畫面中央）
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
	final_label.text = ""
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_label.add_theme_font_size_override("font_size", 22)
	final_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(final_label)

	var btn = Button.new()
	btn.text = "重新開始"
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(btn)
