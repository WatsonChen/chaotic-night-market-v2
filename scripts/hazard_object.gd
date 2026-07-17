extends StaticBody2D

# ===================================================
# hazard_object.gd — 清除障礙事件（Hazard Event）的可破壞物件
#
# 主題中立命名：不叫 oil_barrel / trash_pile 之類的夜市詞彙，
# 純粹是「一個要被打掉 N 下才會消失的警示物件」。換主題時只要
# 換 _draw() 的圖形（現在是中性的警示三角形），訊號/邏輯不用動。
# 見 docs/theme_dependency_audit.md。
#
# 命中偵測沿用 projectile.gd 既有的 Area2D/body_entered 系統
# （跟 enemy.gd 共用 collision_layer），不是自己做距離判定；
# collision_layer/mask 在 _ready() 裡設定，不用改 hazard.tscn
# 或 projectile.tscn 的碰撞設定。
#
# 存在期間的壓力來源：週期性在自己附近生成滑地（借用既有的
# grease_puddle.gd，不重造一個新的滑地系統）。
# ===================================================

const GREASE_PUDDLE_SCRIPT = preload("res://scripts/grease_puddle.gd")

signal cleared

@export var hits_required    : int   = 3
@export var radius           : float = 26.0
@export var grease_interval  : float = 2.5   # ← 存在期間每隔幾秒在自己附近生成一次滑地，<=0 表示不生成

var _hits_taken    : int   = 0
var _cleared       : bool  = false
var _pulse_time     : float = 0.0
var _hit_flash      : float = 0.0   # 0..1，命中時跳到 1，逐漸衰減
var _grease_timer   : float = 0.0


func _ready() -> void:
	add_to_group("hazards")
	collision_layer = 2   # 沿用「敵人」那個 bit，projectile 現有的 mask 就會偵測到，不用改 .tscn
	collision_mask  = 0
	_grease_timer = grease_interval

	# CollisionShape2D 的 CircleShape2D 是 .tscn 裡的 sub_resource，多個 hazard 實例會共用
	# 同一份，直接改 radius 會互相汙染。這裡幫每個實例換一份自己的 shape，避免共用資源被改壞。
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape_node.shape = circle


func _process(delta: float) -> void:
	_pulse_time += delta
	_hit_flash = max(_hit_flash - delta * 3.0, 0.0)
	queue_redraw()

	if grease_interval > 0.0:
		_grease_timer -= delta
		if _grease_timer <= 0.0:
			_grease_timer = grease_interval
			_spawn_grease_puddle()


func take_hit() -> void:
	if _cleared:
		return
	_hits_taken += 1
	_hit_flash = 1.0
	if _hits_taken >= hits_required:
		_cleared = true
		cleared.emit()
		queue_free()


## main.gd 逾時收尾用：強制移除，不計入成功、不重複觸發 cleared
func force_clear() -> void:
	if _cleared:
		return
	_cleared = true
	queue_free()


func _spawn_grease_puddle() -> void:
	var puddle = Node2D.new()
	puddle.set_script(GREASE_PUDDLE_SCRIPT)
	var parent = get_parent()
	if parent == null:
		return
	parent.add_child(puddle)
	puddle.global_position = global_position


func _draw() -> void:
	var progress := float(_hits_taken) / float(max(hits_required, 1))
	var pulse := 0.6 + 0.4 * sin(_pulse_time * 4.0)
	var palette_hazard := GameplayPalette.HAZARD   # 讀圖性配色 v1：危害物統一用紫，見 docs/readability_palette.md
	var base_color := Color(palette_hazard.r, palette_hazard.g, palette_hazard.b, 0.85)
	var flash_color := base_color.lerp(Color.WHITE, _hit_flash)

	# 警示三角形（中性圖形，換主題不用改邏輯只要換這段）
	var pts := PackedVector2Array([
		Vector2(0.0, -radius),
		Vector2(radius * 0.87, radius * 0.5),
		Vector2(-radius * 0.87, radius * 0.5),
	])
	draw_colored_polygon(pts, Color(flash_color.r, flash_color.g, flash_color.b, 0.28 + 0.16 * pulse))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), flash_color, 3.0)

	# 感嘆號
	draw_line(Vector2(0.0, -radius * 0.35), Vector2(0.0, radius * 0.05), Color.WHITE, 4.0)
	draw_circle(Vector2(0.0, radius * 0.28), 3.0, Color.WHITE)

	# 底部進度條：已經打了幾下
	var bar_w := radius * 1.6
	var bar_h := 5.0
	var bar_y := radius + 10.0
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.0, 0.0, 0.0, 0.40))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * progress, bar_h), Color(1.0, 0.42, 0.30, 0.92))
