extends Node2D

# ===================================================
# food_court.gd — 美食廣場視覺效果
#
# 視覺深度感：
#   - 多層向下偏移的陰影環 → 模擬環形看台「厚度」
#   - 脈衝發光環（動態 alpha）
#   - 中央危險區紅圈 + 中心亮點
# ===================================================

const OUTER_RADIUS    = 72.0
const INNER_RADIUS    = 32.0   # 需與 enemy.gd REACH_DIST 一致
const GLOW_RING_WIDTH = 10.0

# 厚度層數與偏移
const DEPTH_LAYERS  = 6
const DEPTH_STEP    = 2.5   # 每層向下偏移（px）

var _time : float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# ── 1. 厚度陰影環（由下往上疊，最底層最暗）
	for i in range(DEPTH_LAYERS, 0, -1):
		var y_off = float(i) * DEPTH_STEP
		var alpha = 0.22 - float(i) * 0.03
		# 外環陰影
		draw_arc(
			Vector2(0.0, y_off), OUTER_RADIUS, 0.0, TAU, 48,
			Color(0.45, 0.25, 0.0, alpha), GLOW_RING_WIDTH + 2.0
		)
		# 內圈陰影
		draw_arc(
			Vector2(0.0, y_off), INNER_RADIUS, 0.0, TAU, 24,
			Color(0.5, 0.0, 0.0, alpha * 0.6), 3.0
		)

	# ── 2. 外圍發光環（脈衝動畫）
	var pulse = 0.35 + 0.25 * sin(_time * 2.5)
	draw_arc(Vector2.ZERO, OUTER_RADIUS,      0.0, TAU, 64, Color(1.0, 0.80, 0.2, pulse),        GLOW_RING_WIDTH)
	draw_arc(Vector2.ZERO, OUTER_RADIUS - 12, 0.0, TAU, 64, Color(1.0, 0.90, 0.5, pulse * 0.5),  4.0)

	# ── 3. 內圈（危險區標示）
	draw_arc(Vector2.ZERO, INNER_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, 0.55), 2.5)

	# ── 4. 中心亮點
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.3, 0.75))

	# ── 5. 文字標示
	var font = ThemeDB.fallback_font
	if font != null:
		draw_string(
			font,
			Vector2(-36.0, -OUTER_RADIUS - 10),
			"美食廣場",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16,
			Color(1.0, 0.95, 0.4)
		)
