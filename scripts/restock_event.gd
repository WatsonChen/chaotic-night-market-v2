extends Node2D

# ===================================================
# restock_event.gd — 補貨攤位事件視覺（程式繪製 placeholder）
#
# 純視覺，沒有任何遊戲邏輯。狀態/計時/成功失敗判定
# 都在 main.gd 的 _update_restock_event() 家族函式，
# 這裡只負責依 main.gd 每幀寫入的 progress/occupied
# 畫出補貨區，以及播放成功/失敗的收尾動畫。
# 風格仿 grease_puddle.gd / hit_effect.gd：純 _draw()，
# 沒有子節點、沒有貼圖。
# ===================================================

@export var radius : float = 56.0

var progress : float = 0.0    # 0..1，由 main.gd 每幀更新
var occupied : bool  = false  # 目前是否有玩家站在區內

var _pulse_time : float = 0.0
var _result_tween : Tween


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var base_color := GameplayPalette.TASK_MARKER   # 讀圖性配色 v1：任務標記統一用青綠，見 docs/readability_palette.md
	var pulse_speed := 6.0 if occupied else 2.4
	var ring_alpha  := 0.72 + 0.28 * sin(_pulse_time * pulse_speed)

	# 外層柔光：比範圍環大一圈、更淡，讓補貨區在混亂畫面裡更容易被瞄到
	draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 40,
		Color(base_color.r, base_color.g, base_color.b, ring_alpha * 0.35), 10.0)

	# 外圈：補貨區範圍
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48,
		Color(base_color.r, base_color.g, base_color.b, ring_alpha), 4.0)

	# 進度環：依 progress 從正上方順時針畫弧
	if progress > 0.0:
		draw_arc(Vector2.ZERO, radius - 11.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48,
			Color(0.35, 1.0, 0.45, 0.95), 7.0)

	# 中央箱子 icon（有人站進來時變綠、亮一點），大小跟著 radius 縮放
	var box_color := Color(0.55, 1.0, 0.55) if occupied else base_color
	var box_w := radius * 0.42
	var box_h := radius * 0.36
	var box_rect := Rect2(-box_w * 0.5, -box_h * 0.5, box_w, box_h)
	draw_rect(box_rect, box_color)
	draw_rect(box_rect, Color(0.0, 0.0, 0.0, 0.35), false, 2.0)
	draw_line(Vector2(-box_w * 0.5, 0.0), Vector2(box_w * 0.5, 0.0), Color(0.0, 0.0, 0.0, 0.35), 2.0)


## main.gd 判定成功/失敗後呼叫，播完收尾動畫自己 queue_free()
func play_result(success: bool) -> void:
	set_process(false)

	var flash_color := Color(0.42, 1.0, 0.50) if success else Color(1.0, 0.32, 0.26)
	modulate = flash_color

	if _result_tween != null:
		_result_tween.kill()
	_result_tween = create_tween()
	_result_tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_result_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.45)
	_result_tween.tween_callback(queue_free)
