extends CharacterBody2D

const MAP_CENTER = Vector2(640.0, 360.0)
const REACH_DIST = 36.0

@export_group("Body")
@export var complaint_value: int = 3
@export var body_radius: float = 52.0
@export var speed: float = 92.0
@export var player_push_accel: float = 1700.0
@export var self_push_ratio: float = 0.24
@export var push_radius: float = 126.0
@export var sep_radius: float = 96.0
@export var sep_force: float = 120.0

@export_group("Armor Window")
@export var hit_window: float = 2.5
@export var armor_window_speed_multiplier: float = 0.96
@export var solo_hit_knockback_ratio: float = 0.15
@export var solo_hit_min_knockback: float = 28.0
@export var solo_hit_decay: float = 9.0

@export_group("Break Launch")
@export var break_speed_multiplier: float = 2.4
@export var break_min_launch_speed: float = 1350.0
@export var break_blast_radius: float = 176.0
@export var break_blast_speed: float = 980.0
@export var break_player_blast_force: float = 620.0
@export var break_chain_dist: float = 188.0
@export var break_chain_min_speed: float = 150.0
@export var fly_decel: float = 0.72
@export var fly_stop_thresh: float = 42.0
@export var chain_speed_ratio: float = 0.98
@export var chain_player_force: float = 1180.0
@export var break_angle_spread: float = 0.08

@export_group("Armor Bars")
@export var armor_bar_width: float = 46.0
@export var armor_bar_height: float = 10.0
@export var armor_bar_gap: float = 10.0
@export var armor_bar_offset_y: float = -76.0
@export var armor_bar_fill_speed: float = 8.0
@export var armor_bar_bg_color: Color = Color(0.18, 0.08, 0.04, 0.90)
@export var armor_bar_outline_color: Color = Color(1.0, 0.95, 0.8, 0.9)
@export var p1_bar_color: Color = Color(1.0, 0.62, 0.12)
@export var p2_bar_color: Color = Color(0.20, 0.82, 1.0)

@export_group("Visual")
@export var body_color: Color = Color(0.64, 0.08, 0.08)
@export var outline_color: Color = Color(1.0, 0.78, 0.22)
@export var armor_glow_color: Color = Color(1.0, 0.92, 0.70)

signal reach_center(complaint_delta: int)
signal armor_broken(break_position: Vector2)

var _sep_vel: Vector2 = Vector2.ZERO
var _external_vel: Vector2 = Vector2.ZERO
var _impact_vel: Vector2 = Vector2.ZERO

var _coop_window_active: bool = false
var _coop_timer: float = 0.0
var _coop_hitters: Dictionary = {}
var _pulse_time: float = 0.0
var _p1_bar_fill: float = 0.0
var _p2_bar_fill: float = 0.0
var _p1_bar_target: float = 0.0
var _p2_bar_target: float = 0.0

var _dying: bool = false
var _hit_vel: Vector2 = Vector2.ZERO
var _fading: bool = false
var _chain_hit_bodies: Array = []
var _spin_angle: float = 0.0
var _spin_speed: float = 0.0
var _display_scale: Vector2 = Vector2.ONE

var _solo_hit_tween: Tween
var _break_tween: Tween
var _break_scale_tween: Tween


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("big_enemies")

	var shape_node = get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape:
		shape_node.shape = shape_node.shape.duplicate()
		shape_node.shape.radius = body_radius

	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_bar_display(delta)

	if _dying:
		_hit_vel = _hit_vel.lerp(Vector2.ZERO, fly_decel * delta)
		_spin_angle += _spin_speed * delta
		_spin_speed *= 1.0 - 2.4 * delta
		velocity = _hit_vel
		move_and_slide()

		if global_position.distance_to(MAP_CENTER) <= REACH_DIST:
			reach_center.emit(complaint_value)
			queue_free()
			return

		if _hit_vel.length() > break_chain_min_speed:
			_check_chain_collision()

		if not _fading and _hit_vel.length() < fly_stop_thresh:
			_fading = true
			_start_fade()

		queue_redraw()
		return

	if _coop_window_active:
		_coop_timer -= delta
		_pulse_time += delta * 10.0
		if _coop_timer <= 0.0:
			_clear_coop_window()

	var to_center = MAP_CENTER - global_position
	if to_center.length() <= REACH_DIST:
		reach_center.emit(complaint_value)
		queue_free()
		return

	_sep_vel = Vector2.ZERO
	_external_vel = _external_vel.lerp(Vector2.ZERO, 5.0 * delta)
	_impact_vel = _impact_vel.lerp(Vector2.ZERO, solo_hit_decay * delta)

	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var diff = global_position - other.global_position
		var dist = diff.length()
		if dist < sep_radius and dist > 0.5:
			_sep_vel += diff.normalized() * sep_force * (1.0 - dist / sep_radius)

	for player in get_tree().get_nodes_in_group("players"):
		var diff = global_position - player.global_position
		var dist = diff.length()
		if dist < push_radius and dist > 0.5:
			var strength = 1.0 - dist / push_radius
			player.apply_push(-diff.normalized(), player_push_accel * strength * delta)
			_sep_vel += diff.normalized() * player_push_accel * self_push_ratio * strength * delta

	var speed_mult = armor_window_speed_multiplier if _coop_window_active else 1.0
	velocity = to_center.normalized() * speed * speed_mult + _sep_vel + _external_vel + _impact_vel
	move_and_slide()
	queue_redraw()


func _update_bar_display(delta: float) -> void:
	_p1_bar_fill = move_toward(_p1_bar_fill, _p1_bar_target, armor_bar_fill_speed * delta)
	_p2_bar_fill = move_toward(_p2_bar_fill, _p2_bar_target, armor_bar_fill_speed * delta)


func _check_chain_collision() -> void:
	for other in get_tree().get_nodes_in_group("small_enemies"):
		if _chain_hit_bodies.has(other):
			continue
		if global_position.distance_to(other.global_position) < break_chain_dist:
			_chain_hit_bodies.append(other)
			var hit_dir = (other.global_position - global_position).normalized()
			if hit_dir == Vector2.ZERO:
				hit_dir = _hit_vel.normalized()
			other.take_hit(hit_dir, max(_hit_vel.length() * chain_speed_ratio, break_blast_speed), 0)

	for player in get_tree().get_nodes_in_group("players"):
		if _chain_hit_bodies.has(player):
			continue
		if global_position.distance_to(player.global_position) < body_radius + 38.0:
			_chain_hit_bodies.append(player)
			player.apply_knockback(_hit_vel.normalized(), chain_player_force)


func _start_fade() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1.0, 0.46, 0.12, 0.0), 0.32)
	tw.tween_callback(queue_free)


func _draw() -> void:
	draw_set_transform(Vector2(4.0, body_radius * 0.82), 0.0, Vector2(0.94, 0.22))
	draw_circle(Vector2.ZERO, body_radius, Color(0.0, 0.0, 0.0, 0.52))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_set_transform(Vector2.ZERO, _spin_angle, _display_scale)
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 72, outline_color, 4.8)

	if _coop_window_active:
		var pulse = 0.55 + 0.45 * sin(_pulse_time)
		draw_arc(
			Vector2.ZERO,
			body_radius + 9.0 + pulse * 8.0,
			0.0,
			TAU,
			72,
			Color(armor_glow_color.r, armor_glow_color.g, armor_glow_color.b, 0.55 + pulse * 0.30),
			4.0
		)

	draw_circle(Vector2(-14.0, -10.0), 7.8, Color.BLACK)
	draw_circle(Vector2(14.0, -10.0), 7.8, Color.BLACK)
	draw_arc(Vector2.ZERO, 18.0, deg_to_rad(18), deg_to_rad(162), 20, Color.BLACK, 3.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_armor_bars()


func _draw_armor_bars() -> void:
	var total_width = armor_bar_width * 2.0 + armor_bar_gap
	var start_x = -total_width * 0.5
	var y = armor_bar_offset_y

	_draw_single_bar(Rect2(start_x, y, armor_bar_width, armor_bar_height), _p1_bar_fill, p1_bar_color)
	_draw_single_bar(Rect2(start_x + armor_bar_width + armor_bar_gap, y, armor_bar_width, armor_bar_height), _p2_bar_fill, p2_bar_color)


func _draw_single_bar(rect: Rect2, fill_ratio: float, fill_color: Color) -> void:
	draw_rect(rect, armor_bar_bg_color)
	var inner = rect.grow(-1.5)
	if fill_ratio > 0.0:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * clamp(fill_ratio, 0.0, 1.0), inner.size.y)), fill_color)
	draw_rect(rect, armor_bar_outline_color, false, 1.6)


func take_hit(hit_dir: Vector2 = Vector2.RIGHT, hit_speed: float = 420.0, attacker_id: int = 0) -> void:
	if _dying:
		return

	var break_dir = _get_break_dir(hit_dir)
	if attacker_id > 0:
		_handle_player_hit(attacker_id, break_dir, hit_speed)
		return

	_apply_solo_hit(break_dir, hit_speed)


func _handle_player_hit(attacker_id: int, break_dir: Vector2, hit_speed: float) -> void:
	if not _coop_window_active:
		_coop_window_active = true
		_coop_timer = hit_window
		_pulse_time = 0.0
		_coop_hitters.clear()

	_set_bar_target(attacker_id, 1.0)

	if _coop_hitters.has(attacker_id):
		_apply_solo_hit(break_dir, hit_speed)
		return

	_coop_hitters[attacker_id] = true
	if _coop_hitters.size() >= 2:
		_do_break(break_dir, hit_speed)
		return

	_apply_solo_hit(break_dir, hit_speed)


func _apply_solo_hit(break_dir: Vector2, hit_speed: float) -> void:
	_impact_vel = break_dir * max(hit_speed * solo_hit_knockback_ratio, solo_hit_min_knockback)

	if _solo_hit_tween != null:
		_solo_hit_tween.kill()
	if _break_scale_tween != null:
		_break_scale_tween.kill()

	_solo_hit_tween = create_tween()
	_solo_hit_tween.tween_property(self, "modulate", Color(2.0, 1.2, 0.35, 1.0), 0.03)
	_solo_hit_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)

	_display_scale = Vector2.ONE
	_break_scale_tween = create_tween()
	_break_scale_tween.tween_property(self, "_display_scale", Vector2(1.18, 0.88), 0.04)
	_break_scale_tween.tween_property(self, "_display_scale", Vector2(0.96, 1.08), 0.07)
	_break_scale_tween.tween_property(self, "_display_scale", Vector2.ONE, 0.06)


func _do_break(break_dir: Vector2, hit_speed: float) -> void:
	_clear_coop_window()
	_dying = true
	_fading = false
	_chain_hit_bodies.clear()
	_display_scale = Vector2.ONE

	var launch_speed = max(hit_speed * break_speed_multiplier, break_min_launch_speed)
	var spread = randf_range(-break_angle_spread, break_angle_spread)
	_hit_vel = break_dir.rotated(spread) * launch_speed
	_do_break_blast()

	var sign = 1.0 if randf() > 0.5 else -1.0
	_spin_speed = sign * randf_range(13.0, 21.0)

	if _break_tween != null:
		_break_tween.kill()
	if _break_scale_tween != null:
		_break_scale_tween.kill()

	_break_tween = create_tween()
	_break_tween.tween_property(self, "modulate", Color(4.2, 4.0, 2.6, 1.0), 0.04)
	_break_tween.tween_property(self, "modulate", Color(1.0, 0.55, 0.16, 1.0), 0.14)

	_break_scale_tween = create_tween()
	_break_scale_tween.tween_property(self, "_display_scale", Vector2(2.15, 0.28), 0.05)
	_break_scale_tween.tween_property(self, "_display_scale", Vector2(0.52, 1.88), 0.09)
	_break_scale_tween.tween_property(self, "_display_scale", Vector2(1.12, 0.90), 0.09)
	_break_scale_tween.tween_property(self, "_display_scale", Vector2.ONE, 0.10)

	armor_broken.emit(global_position)


func _do_break_blast() -> void:
	for other in get_tree().get_nodes_in_group("small_enemies"):
		var dist = global_position.distance_to(other.global_position)
		if dist > break_blast_radius:
			continue
		var hit_dir = (other.global_position - global_position).normalized()
		if hit_dir == Vector2.ZERO:
			var random_angle = randf() * TAU
			hit_dir = Vector2(cos(random_angle), sin(random_angle))
		other.take_hit(hit_dir, break_blast_speed, 0)

	for player in get_tree().get_nodes_in_group("players"):
		var dist = global_position.distance_to(player.global_position)
		if dist > break_blast_radius * 0.74:
			continue
		var ratio = 1.0 - dist / max(break_blast_radius * 0.74, 1.0)
		var knock_dir = (player.global_position - global_position).normalized()
		if knock_dir == Vector2.ZERO:
			knock_dir = Vector2.RIGHT
		player.apply_knockback(knock_dir, break_player_blast_force * (0.45 + ratio * 0.55))


func _clear_coop_window() -> void:
	_coop_window_active = false
	_coop_timer = 0.0
	_coop_hitters.clear()
	_p1_bar_target = 0.0
	_p2_bar_target = 0.0


func _set_bar_target(attacker_id: int, value: float) -> void:
	if attacker_id == 1:
		_p1_bar_target = value
	elif attacker_id == 2:
		_p2_bar_target = value


func _get_break_dir(hit_dir: Vector2) -> Vector2:
	var outward = (global_position - MAP_CENTER).normalized()
	if outward != Vector2.ZERO:
		return outward

	if hit_dir != Vector2.ZERO:
		return -hit_dir.normalized()
	return Vector2.RIGHT


func apply_push(dir: Vector2, force: float) -> void:
	_external_vel = (_external_vel + dir * force).limit_length(420.0)
