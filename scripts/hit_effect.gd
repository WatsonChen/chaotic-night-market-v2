extends Node2D

# ===================================================
# hit_effect.gd — 命中爆炸效果
#
# 依 is_player_hit 分為兩個等級：
#   玩家命中（最誇張）：大爆炸 + 白色衝擊圈 + 12 粒子 + 0.40s
#   敵人命中：中型爆炸 + 8 粒子 + 0.22s
#   邊界 fizzle（effect_scale ≤ 0.35）：極小極快，不搶注意力
# ===================================================

## 由外部在 add_child 之前設定
var is_player_hit : bool  = false
var effect_scale  : float = 1.0   # fizzle 用 0.3，敵人 1.0，玩家 1.0（靠 is_player_hit 放大）

var _t        : float = 0.0
var _duration : float = 0.22


func _ready() -> void:
	# 依等級決定持續時間
	if effect_scale <= 0.35:
		_duration = 0.10     # fizzle：極快消失
	elif is_player_hit:
		_duration = 0.40     # 玩家命中：最久
	else:
		_duration = 0.22     # 敵人命中：中等


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= _duration:
		queue_free()


func _draw() -> void:
	var p = _t / _duration   # 0 → 1

	# ── fizzle（邊界退場）：只畫 4 顆小點，快速消失 ──
	if effect_scale <= 0.35:
		for i in 4:
			var angle = float(i) / 4.0 * TAU
			var dist  = p * 14.0
			var pos   = Vector2(cos(angle), sin(angle)) * dist
			draw_circle(pos, lerp(3.5, 0.5, p), Color(0.7, 0.55, 0.1, (1.0 - p) * 0.55))
		return

	# ── 共用：粒子數量 & 飛射距離依等級縮放 ──────────
	var scale_m   = 1.8  if is_player_hit else 1.0
	var p_count   = 12   if is_player_hit else 8
	var fly_dist  = 90.0 if is_player_hit else 58.0
	var ring_max  = 80.0 if is_player_hit else 50.0

	# ── 粒子向外飛射 ──────────────────────────────────
	for i in p_count:
		var angle = float(i) / float(p_count) * TAU + p * 0.9
		var dist  = p * fly_dist * scale_m
		var pos   = Vector2(cos(angle), sin(angle)) * dist
		var sz    = lerp(10.0, 1.5, p) * scale_m
		var alpha = (1.0 - p) * 0.95
		var g_col = lerp(0.8, 0.05, p)
		draw_circle(pos, sz, Color(1.0, g_col, 0.0, alpha))

	# ── 衝擊環（2 圈）────────────────────────────────
	for i in 2:
		var phase = clamp(p * 1.6 - float(i) * 0.4, 0.0, 1.0)
		if phase <= 0.0:
			continue
		var r     = phase * ring_max * scale_m
		var alpha = (1.0 - phase) * 1.1
		var width = lerp(7.0, 1.0, phase) * scale_m
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32,
			Color(1.0, lerp(0.65, 0.05, phase), 0.0, alpha), width)

	# ── 玩家命中專屬：外層白色衝擊圈 ────────────────
	if is_player_hit:
		var wp = clamp(p * 2.2, 0.0, 1.0)
		var wr = wp * 110.0
		var wa = (1.0 - wp) * 0.90
		draw_arc(Vector2.ZERO, wr, 0.0, TAU, 40,
			Color(1.0, 1.0, 1.0, wa), lerp(9.0, 0.5, wp))

	# ── 中心白色閃光（命中瞬間）──────────────────────
	var flash_window = 0.12 if is_player_hit else 0.10
	if p < flash_window:
		var fp = p / flash_window
		var fr = lerp(26.0 * scale_m, 2.0, fp)
		draw_circle(Vector2.ZERO, fr, Color(1.0, 1.0, 1.0, (1.0 - fp) * 0.9))
