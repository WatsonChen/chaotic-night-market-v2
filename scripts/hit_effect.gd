extends Node2D

@export_group("Core")
@export var is_player_hit: bool = false
@export var effect_scale: float = 1.0
@export var duration_override: float = 0.0
@export var particle_count_override: int = 0
@export var ring_count_override: int = 0
@export var fly_distance_override: float = 0.0
@export var ring_max_override: float = 0.0
@export var white_ring_boost: float = 1.0

@export_group("Palette")
@export var primary_color: Color = Color(1.0, 0.78, 0.08)
@export var secondary_color: Color = Color(1.0, 1.0, 1.0)
@export var accent_color: Color = Color(1.0, 0.20, 0.06)
@export var rainbow_mode: bool = false

@export_group("Motion")
@export var spin_speed: float = 1.0
@export var particle_size_ratio: float = 1.0
@export var ring_width_ratio: float = 1.0
@export var flash_window_ratio: float = 0.12

var _t: float = 0.0
var _duration: float = 0.22
var _particle_count: int = 8
var _ring_count: int = 2
var _fly_distance: float = 58.0
var _ring_max: float = 50.0


func _ready() -> void:
	if duration_override > 0.0:
		_duration = duration_override
	elif effect_scale <= 0.35:
		_duration = 0.10
	elif is_player_hit:
		_duration = 0.40
	else:
		_duration = 0.22

	_particle_count = particle_count_override if particle_count_override > 0 else (12 if is_player_hit else 8)
	_ring_count = ring_count_override if ring_count_override > 0 else (3 if is_player_hit else 2)
	_fly_distance = fly_distance_override if fly_distance_override > 0.0 else (90.0 if is_player_hit else 58.0)
	_ring_max = ring_max_override if ring_max_override > 0.0 else (80.0 if is_player_hit else 50.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= _duration:
		queue_free()


func _draw() -> void:
	var p = clamp(_t / _duration, 0.0, 1.0)

	if effect_scale <= 0.35 and not rainbow_mode and particle_count_override <= 0:
		for i in range(4):
			var angle = float(i) / 4.0 * TAU
			var dist = p * 14.0
			var pos = Vector2(cos(angle), sin(angle)) * dist
			draw_circle(pos, lerp(3.5, 0.5, p), Color(primary_color.r, primary_color.g, primary_color.b, (1.0 - p) * 0.55))
		return

	var scale_m = max(effect_scale, 0.1)
	var fly_dist = _fly_distance * scale_m
	var ring_max = _ring_max * scale_m
	var particle_base_size = 10.0 * scale_m * particle_size_ratio

	for i in range(_particle_count):
		var angle = float(i) / float(max(_particle_count, 1)) * TAU + p * 1.2 * spin_speed
		var dist = p * fly_dist
		var pos = Vector2(cos(angle), sin(angle)) * dist
		var size = lerp(particle_base_size, 1.5 * scale_m, p)
		var alpha = (1.0 - p) * 0.95
		draw_circle(pos, size, _particle_color(i, p, alpha))

	for i in range(_ring_count):
		var phase = clamp(p * (1.7 + float(i) * 0.12) - float(i) * 0.28, 0.0, 1.0)
		if phase <= 0.0:
			continue
		var radius = phase * ring_max * (1.0 + float(i) * 0.12)
		var alpha = (1.0 - phase) * (1.15 - float(i) * 0.08)
		var width = lerp(9.0 * ring_width_ratio, 1.2, phase) * scale_m
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 42, _ring_color(i, phase, alpha), width)

	if is_player_hit or white_ring_boost > 1.0:
		var wp = clamp(p * 2.2, 0.0, 1.0)
		var wr = wp * ring_max * 1.42
		var wa = (1.0 - wp) * 0.92 * white_ring_boost
		draw_arc(Vector2.ZERO, wr, 0.0, TAU, 52, Color(secondary_color.r, secondary_color.g, secondary_color.b, wa), lerp(10.0 * ring_width_ratio, 0.6, wp) * scale_m)

	if p < flash_window_ratio:
		var fp = p / max(flash_window_ratio, 0.01)
		var flash_radius = lerp(28.0 * scale_m, 2.0, fp)
		draw_circle(Vector2.ZERO, flash_radius, Color(secondary_color.r, secondary_color.g, secondary_color.b, (1.0 - fp) * 0.95))


func _particle_color(index: int, progress: float, alpha: float) -> Color:
	if rainbow_mode:
		var colors = [
			Color(1.0, 0.58, 0.12),
			Color(1.0, 0.25, 0.85),
			Color(0.25, 0.90, 1.0),
			Color(0.95, 1.0, 0.22),
			Color(1.0, 0.95, 0.85),
		]
		var c = colors[index % colors.size()]
		var mixed = c.lerp(Color.WHITE, 0.14 + progress * 0.18)
		return Color(mixed.r, mixed.g, mixed.b, alpha)

	var blend = float(index) / float(max(_particle_count - 1, 1))
	var color = primary_color.lerp(accent_color, blend * 0.55 + progress * 0.30)
	return Color(color.r, color.g, color.b, alpha)


func _ring_color(index: int, phase: float, alpha: float) -> Color:
	if rainbow_mode:
		var ring_colors = [
			Color(1.0, 0.58, 0.12),
			Color(0.25, 0.90, 1.0),
			Color(1.0, 0.25, 0.85),
		]
		var c = ring_colors[index % ring_colors.size()].lerp(Color.WHITE, phase * 0.28)
		return Color(c.r, c.g, c.b, alpha)

	var base = accent_color if index % 2 == 0 else primary_color
	var ring = base.lerp(secondary_color, phase * 0.22)
	return Color(ring.r, ring.g, ring.b, alpha)
