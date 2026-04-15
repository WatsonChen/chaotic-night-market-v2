extends Node2D

# ===================================================
# hit_effect.gd — 命中爆炸效果
#
# 由 projectile.gd 在命中時生成，自動消亡。
# 不需要場景檔，直接 Node2D.new() + set_script() 使用。
# ===================================================

const DURATION = 0.28   # 效果總時間（秒）

var color    : Color   = Color(1.0, 0.88, 0.1)  # 預設黃色，可由外部覆寫
var _t       : float   = 0.0
var _is_enemy_hit : bool = false   # 敵人命中 → 紅色系


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func _draw() -> void:
	var p = _t / DURATION   # 進度 0 → 1

	# ── 8 顆粒子向外飛射 ─────────────────────────
	for i in 8:
		var angle = float(i) / 8.0 * TAU + p * 0.8
		var dist  = p * 62.0
		var pos   = Vector2(cos(angle), sin(angle)) * dist
		var sz    = lerp(9.0, 2.0, p)
		var alpha = (1.0 - p) * 0.95
		var r     = 1.0
		var g     = lerp(color.g, 0.1, p)
		draw_circle(pos, sz, Color(r, g, 0.0, alpha))

	# ── 2 圈擴散衝擊環 ───────────────────────────
	for i in 2:
		var phase = clamp(p * 1.6 - float(i) * 0.4, 0.0, 1.0)
		if phase <= 0.0:
			continue
		var r     = phase * 52.0
		var alpha = (1.0 - phase) * 1.1
		var width = lerp(6.0, 1.0, phase)
		var ring_col = Color(1.0, lerp(0.65, 0.1, phase), 0.0, alpha)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, ring_col, width)

	# ── 中心亮點（命中瞬間白色閃爍）────────────
	if p < 0.15:
		var flash_alpha = (1.0 - p / 0.15) * 0.85
		draw_circle(Vector2.ZERO, lerp(20.0, 2.0, p / 0.15), Color(1.0, 1.0, 1.0, flash_alpha))
