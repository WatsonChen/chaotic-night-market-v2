extends Node2D

# ===================================================
# grease_puddle.gd — 落地滑溜區域
#
# 子彈 1 秒未命中時落地，在場地中央附近生成。
# 視覺刻意降調（不搶主角），同時間最多 5 個。
#
# ── 可調整數值 ──────────────────────────────────────
#   RADIUS      滑地半徑（目前 38px）
#   LIFETIME    持續時間（目前 2.0s）
#   SLIP_ACCEL  滑力強度（目前 900 px/s²）
# ===================================================

const RADIUS       = 38.0    # ← 調這裡改滑地大小
const LIFETIME     = 2.0     # ← 調這裡改滑地持續時間（s）
const SLIP_ACCEL   = 900.0   # ← 調這裡改滑力強度
const DIR_CHANGE_T = 0.14    # 滑力方向更換間隔（秒）

const MAX_PUDDLES = 5

static var active_count : int = 0

var _time      : float   = 0.0
var _dir_timer : float   = 0.0
var _slip_dir  : Vector2 = Vector2.RIGHT


func _ready() -> void:
	if active_count >= MAX_PUDDLES:
		queue_free()
		return
	active_count += 1
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		active_count = max(0, active_count - 1)


func _process(delta: float) -> void:
	_time      += delta
	_dir_timer -= delta
	queue_redraw()

	if _dir_timer <= 0.0:
		_slip_dir  = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		_dir_timer = randf_range(DIR_CHANGE_T * 0.7, DIR_CHANGE_T * 1.3)

	if _time >= LIFETIME:
		queue_free()
		return

	var force = SLIP_ACCEL * delta

	for player in get_tree().get_nodes_in_group("players"):
		var dist = global_position.distance_to(player.global_position)
		if dist < RADIUS:
			player.apply_push(_slip_dir, force * (1.0 - dist / RADIUS))

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist = global_position.distance_to(enemy.global_position)
		if dist < RADIUS:
			enemy.apply_push(_slip_dir, force * (1.0 - dist / RADIUS))


func _draw() -> void:
	var life_ratio = _time / LIFETIME   # 0 → 1
	# ── 主體：半透明低飽和黃，快速淡出
	var alpha = lerp(0.30, 0.04, life_ratio)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.72, 0.72, 0.18, alpha))

	# ── 外邊框：細線，隨時間淡出
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32,
		Color(0.6, 0.65, 0.1, (1.0 - life_ratio) * 0.50), 1.5)
