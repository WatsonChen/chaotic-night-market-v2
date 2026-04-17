extends Node2D

@export_group("Core Shape")
@export var outer_radius: float = 72.0
@export var inner_radius: float = 32.0
@export var glow_ring_width: float = 10.0

@export_group("Depth")
@export var depth_layers: int = 6
@export var depth_step: float = 2.5

@export_group("Danger Feedback")
@export var danger_fill_alpha: float = 0.26
@export var danger_flash_speed: float = 10.5
@export var warning_ring_width: float = 16.0
@export var break_pulse_decay: float = 1.55
@export var comeback_pulse_decay: float = 1.10
@export var break_pulse_radius_boost: float = 28.0
@export var comeback_pulse_radius_boost: float = 34.0

var complaint_count: int = 0
var current_stage: int = 1
var danger_threshold: int = 8
var spawn_pause_ratio: float = 0.0

var _time: float = 0.0
var _break_pulse: float = 0.0
var _comeback_pulse: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	_break_pulse = max(_break_pulse - break_pulse_decay * delta, 0.0)
	_comeback_pulse = max(_comeback_pulse - comeback_pulse_decay * delta, 0.0)
	queue_redraw()


func trigger_break_pulse(strength: float = 1.0) -> void:
	_break_pulse = max(_break_pulse, strength)


func trigger_comeback_pulse(strength: float = 1.0) -> void:
	_comeback_pulse = max(_comeback_pulse, strength)


func _draw() -> void:
	for i in range(depth_layers, 0, -1):
		var y_off = float(i) * depth_step
		var alpha = 0.22 - float(i) * 0.03
		draw_arc(
			Vector2(0.0, y_off),
			outer_radius,
			0.0,
			TAU,
			48,
			Color(0.45, 0.25, 0.0, alpha),
			glow_ring_width + 2.0
		)
		draw_arc(
			Vector2(0.0, y_off),
			inner_radius,
			0.0,
			TAU,
			24,
			Color(0.5, 0.0, 0.0, alpha * 0.6),
			3.0
		)

	var pulse = 0.35 + 0.25 * sin(_time * 2.5)
	var outer_color = Color(1.0, 0.80, 0.2, pulse)
	var inner_glow = Color(1.0, 0.90, 0.5, pulse * 0.5)
	if current_stage == 2:
		outer_color = Color(1.0, 0.50, 0.08, pulse * 1.25)
		inner_glow = Color(1.0, 0.78, 0.28, pulse * 0.72)
	elif current_stage >= 3:
		var stage3_pulse = 0.55 + 0.45 * sin(_time * danger_flash_speed)
		outer_color = Color(1.0, 0.18 + stage3_pulse * 0.14, 0.08, 0.78 + stage3_pulse * 0.18)
		inner_glow = Color(1.0, 0.35, 0.14, 0.35 + stage3_pulse * 0.26)

	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 64, outer_color, glow_ring_width)
	draw_arc(Vector2.ZERO, outer_radius - 12.0, 0.0, TAU, 64, inner_glow, 4.0)

	var inner_color = Color(1.0, 0.3, 0.3, 0.55)
	if complaint_count >= danger_threshold:
		var danger_pulse = 0.55 + 0.45 * sin(_time * danger_flash_speed)
		var red_zone_alpha = danger_fill_alpha + danger_pulse * 0.16 + spawn_pause_ratio * 0.12
		draw_circle(Vector2.ZERO, outer_radius - 3.0, Color(1.0, 0.08, 0.08, red_zone_alpha))
		draw_arc(
			Vector2.ZERO,
			outer_radius - 2.0,
			0.0,
			TAU,
			64,
			Color(1.0, 0.28, 0.22, 0.72 + danger_pulse * 0.28),
			warning_ring_width
		)
		inner_color = Color(1.0, 0.22, 0.22, 0.90)

	if _break_pulse > 0.0:
		var break_level = min(_break_pulse, 1.35)
		var break_alpha = break_level * (0.55 + 0.25 * sin(_time * 20.0))
		draw_arc(
			Vector2.ZERO,
			outer_radius + 10.0 + (1.0 - min(break_level, 1.0)) * break_pulse_radius_boost,
			0.0,
			TAU,
			64,
			Color(1.0, 0.95, 0.75, break_alpha),
			6.0
		)

	if _comeback_pulse > 0.0:
		var comeback_level = min(_comeback_pulse, 1.45)
		var comeback_alpha = comeback_level * (0.72 + 0.28 * sin(_time * 16.0))
		draw_circle(Vector2.ZERO, outer_radius + 12.0 * (1.0 - min(comeback_level, 1.0)), Color(1.0, 0.95, 0.65, comeback_alpha * 0.25))
		draw_arc(
			Vector2.ZERO,
			outer_radius + 16.0 + (1.0 - min(comeback_level, 1.0)) * comeback_pulse_radius_boost,
			0.0,
			TAU,
			64,
			Color(1.0, 0.98, 0.72, comeback_alpha),
			7.0
		)

	draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 32, inner_color, 2.5)
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.3, 0.75))

	var font = ThemeDB.fallback_font
	if font != null:
		draw_string(
			font,
			Vector2(-36.0, -outer_radius - 10.0),
			"美食廣場",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color(1.0, 0.95, 0.4)
		)
