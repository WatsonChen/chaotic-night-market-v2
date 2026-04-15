extends Node2D

# ===================================================
# grease_puddle.gd — 滑溜滑地效果
#
# 子彈 2 秒未命中任何目標時，在落地點生成。
# 同時間最多 MAX_PUDDLES 個，超過則最新的直接放棄。
#
# 範圍內的玩家與敵人每幀受到隨機方向的滑力推擠，
# 模擬失去抓地力的混亂感。
# ===================================================

const RADIUS       = 55.0   # 滑地半徑
const LIFETIME     = 3.0    # 持續時間（秒）
const SLIP_ACCEL   = 1100.0 # 滑力加速度（px/s²，乘 delta 後傳入 apply_push）
const DIR_CHANGE_T = 0.12   # 滑力方向更換間隔（秒）

const MAX_PUDDLES = 5

# 靜態計數器：追蹤目前存活的滑地數量
static var active_count : int = 0

var _time          : float   = 0.0
var _dir_timer     : float   = 0.0
var _slip_dir      : Vector2 = Vector2.RIGHT


func _ready() -> void:
	# 超過上限則立即自毀
	if active_count >= MAX_PUDDLES:
		queue_free()
		return
	active_count += 1
	queue_redraw()


func _notification(what: int) -> void:
	# 無論因何消亡，都遞減計數
	if what == NOTIFICATION_PREDELETE:
		active_count = max(0, active_count - 1)


func _process(delta: float) -> void:
	_time      += delta
	_dir_timer -= delta
	queue_redraw()

	# 更換滑力方向
	if _dir_timer <= 0.0:
		_slip_dir  = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		_dir_timer = randf_range(DIR_CHANGE_T * 0.7, DIR_CHANGE_T * 1.3)

	# 生命週期結束
	if _time >= LIFETIME:
		queue_free()
		return

	# ── 對範圍內物體施加滑力 ──────────────────────
	var force = SLIP_ACCEL * delta

	for player in get_tree().get_nodes_in_group("players"):
		var dist = global_position.distance_to(player.global_position)
		if dist < RADIUS:
			# 離中心越近滑力越強
			var strength = 1.0 - dist / RADIUS
			player.apply_push(_slip_dir, force * strength)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist = global_position.distance_to(enemy.global_position)
		if dist < RADIUS:
			var strength = 1.0 - dist / RADIUS
			enemy.apply_push(_slip_dir, force * strength)


func _draw() -> void:
	var life_ratio = _time / LIFETIME   # 0 → 1

	# ── 主體（半透明黃綠色油漬）──────────────────
	# 隨時間淡出
	var base_alpha = lerp(0.52, 0.12, life_ratio)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.62, 0.78, 0.1, base_alpha))

	# ── 脈衝同心環（生命前半段更明顯）
	var ring_alpha = (1.0 - life_ratio) * 0.70
	for i in 3:
		var phase = fmod(_time * 1.4 + float(i) * 0.55, 1.0)
		var r     = phase * RADIUS
		var a     = (1.0 - phase) * ring_alpha
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28,
			Color(0.9, 1.0, 0.2, a), lerp(5.0, 1.0, phase))

	# ── 外邊框（讓玩家看清楚範圍）
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 36,
		Color(0.5, 0.7, 0.05, (1.0 - life_ratio) * 0.85), 2.5)

	# ── 中央「滑」字（以點陣星形代替）
	var star_alpha = (1.0 - life_ratio) * 0.6
	for i in 4:
		var angle = float(i) * PI / 4.0 + _time * 1.2
		var pt    = Vector2(cos(angle), sin(angle)) * 10.0
		draw_circle(pt, 3.0, Color(1.0, 1.0, 0.3, star_alpha))
