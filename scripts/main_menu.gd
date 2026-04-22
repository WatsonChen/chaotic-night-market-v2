extends Node2D

# ===================================================
# main_menu.gd — 主選單
#
# 所有 UI 以程式動態建立，風格與 main.gd 一致。
# 場景切換：
#   開始遊戲 → res://scenes/main.tscn
#   離開     → get_tree().quit()
# ===================================================

# ── 文字常數（所有顯示文字集中管理）──────────────────
const TXT_TITLE_TC    = "混亂夜市"
const TXT_TITLE_EN    = "Chaotic Night Market"
const TXT_SUBTITLE    = "2 人合作守護夜市"
const TXT_START       = "開始遊戲"
const TXT_HOW_TO_PLAY = "操作說明"
const TXT_QUIT        = "離開"
const TXT_BACK        = "返回主選單"

const TXT_HOWTO_CONTENT = \
"""【玩家 1 — 熱狗攤】
  WASD 移動
  朝移動方向自動射擊

【玩家 2 — 珍奶攤】
  IJKL 移動
  朝移動方向自動射擊

【目標】
  阻止饕客抵達中央美食廣場
  客訴達到 10 次即失敗

【勝利條件】
  撐過 2 分鐘獲勝！"""

var _howto_panel: Panel
var _feedback_time: float = 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.06, 0.03, 0.10))
	_setup_ui()


func _process(delta: float) -> void:
	_feedback_time += delta
	queue_redraw()


func _draw() -> void:
	# 裝飾：左右兩側隱約發光線條（夜市燈光感）
	var t = _feedback_time
	for i in range(6):
		var alpha = 0.04 + 0.03 * sin(t * 0.8 + i * 1.1)
		var y = 80.0 + float(i) * 100.0
		draw_line(Vector2(0, y), Vector2(200, y + 12.0),
			Color(1.0, 0.72, 0.18, alpha), 28.0)
		draw_line(Vector2(1080, y + 8.0), Vector2(1280, y - 4.0),
			Color(1.0, 0.72, 0.18, alpha), 28.0)


func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	# 深色背景
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.03, 0.10)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)

	# 主標題（中文）
	var title_tc = Label.new()
	title_tc.text = TXT_TITLE_TC
	title_tc.position = Vector2(200.0, 110.0)
	title_tc.size = Vector2(880.0, 100.0)
	title_tc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_tc.add_theme_font_size_override("font_size", 72)
	title_tc.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	canvas.add_child(title_tc)

	# 副標題（英文）
	var title_en = Label.new()
	title_en.text = TXT_TITLE_EN
	title_en.position = Vector2(200.0, 210.0)
	title_en.size = Vector2(880.0, 50.0)
	title_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_en.add_theme_font_size_override("font_size", 30)
	title_en.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32, 0.85))
	canvas.add_child(title_en)

	# 說明文字
	var sub = Label.new()
	sub.text = TXT_SUBTITLE
	sub.position = Vector2(200.0, 270.0)
	sub.size = Vector2(880.0, 40.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.80, 0.70, 0.48, 0.75))
	canvas.add_child(sub)

	# 分隔線
	var sep = ColorRect.new()
	sep.position = Vector2(390.0, 328.0)
	sep.size = Vector2(500.0, 2.0)
	sep.color = Color(1.0, 0.82, 0.22, 0.30)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(sep)

	# 按鈕容器
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(490.0, 348.0)
	vbox.size = Vector2(300.0, 0.0)
	vbox.add_theme_constant_override("separation", 16)
	canvas.add_child(vbox)

	var btn_start = Button.new()
	btn_start.text = TXT_START
	btn_start.add_theme_font_size_override("font_size", 28)
	btn_start.custom_minimum_size = Vector2(300.0, 58.0)
	btn_start.pressed.connect(_on_start_pressed)
	vbox.add_child(btn_start)

	var btn_howto = Button.new()
	btn_howto.text = TXT_HOW_TO_PLAY
	btn_howto.add_theme_font_size_override("font_size", 28)
	btn_howto.custom_minimum_size = Vector2(300.0, 58.0)
	btn_howto.pressed.connect(_on_howto_pressed)
	vbox.add_child(btn_howto)

	var btn_quit = Button.new()
	btn_quit.text = TXT_QUIT
	btn_quit.add_theme_font_size_override("font_size", 28)
	btn_quit.custom_minimum_size = Vector2(300.0, 58.0)
	btn_quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(btn_quit)

	# ── 操作說明面板（預設隱藏）──────────────────────────
	_howto_panel = Panel.new()
	_howto_panel.position = Vector2(200.0, 80.0)
	_howto_panel.size = Vector2(880.0, 560.0)
	_howto_panel.hide()
	canvas.add_child(_howto_panel)

	var hvbox = VBoxContainer.new()
	hvbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hvbox.add_theme_constant_override("separation", 16)
	hvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_howto_panel.add_child(hvbox)

	var h_title = Label.new()
	h_title.text = TXT_HOW_TO_PLAY
	h_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_title.add_theme_font_size_override("font_size", 36)
	h_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	hvbox.add_child(h_title)

	var h_content = Label.new()
	h_content.text = TXT_HOWTO_CONTENT
	h_content.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	h_content.add_theme_font_size_override("font_size", 22)
	h_content.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	hvbox.add_child(h_content)

	var h_back = Button.new()
	h_back.text = TXT_BACK
	h_back.add_theme_font_size_override("font_size", 22)
	h_back.custom_minimum_size = Vector2(220.0, 48.0)
	h_back.pressed.connect(_on_back_pressed)
	hvbox.add_child(h_back)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_howto_pressed() -> void:
	_howto_panel.show()


func _on_back_pressed() -> void:
	_howto_panel.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()
