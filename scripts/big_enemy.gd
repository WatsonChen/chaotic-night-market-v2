extends CharacterBody2D

const MAP_CENTER = Vector2(640.0, 360.0)
const REACH_DIST = 36.0

@export_group("Body")
@export var complaint_value: int = 2
@export var body_radius: float = 46.0
@export var speed: float = 78.0
@export var player_push_accel: float = 1350.0
@export var self_push_ratio: float = 0.22
@export var push_radius: float = 108.0
@export var sep_radius: float = 88.0
@export var sep_force: float = 110.0

@export_group("Co-op Break Window")
@export var hit_window: float = 2.5
@export var armor_window_speed_multiplier: float = 0.88
@export var armor_push_ratio: float = 0.12
@export var armor_push_decay: float = 7.5

@export_group("Break Launch")
@export var break_speed_multiplier: float = 1.65
@export var break_min_launch_speed: float = 850.0
@export var break_chain_dist: float = 138.0
@export var break_chain_min_speed: float = 240.0
@export var fly_decel: float = 1.05
@export var fly_stop_thresh: float = 48.0
@export var chain_speed_ratio: float = 0.84
@export var chain_player_force: float = 820.0
@export var break_angle_spread: float = 0.22

@export_group("Visual")
@export var body_color: Color = Color(0.60, 0.08, 0.10)
@export var outline_color: Color = Color(1.0, 0.68, 0.24)
@export var armor_color: Color = Color(1.0, 0.60, 0.12)

signal reach_center(complaint_delta: int)
signal armor_broken(break_position: Vector2)

var _sep_vel: Vector2 = Vector2.ZERO
var _external_vel: Vector2 = Vector2.ZERO
var _impact_vel: Vector2 = Vector2.ZERO

var _coop_window_active: bool = false
var _coop_timer: float = 0.0
var _coop_hitters: Dictionary = {}
var _pulse_time: float = 0.0

var _dying: bool = false
var _hit_vel: Vector2 = Vector2.ZERO
var _fading: bool = false
var _chain_hit_bodies: Array = []
var _spin_angle: float = 0.0
var _spin_speed: float = 0.0
var _display_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("big_enemies")

	var shape_node = get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape:
		shape_node.shape = shape_node.shape.duplicate()
		shape_node.shape.radius = body_radius

	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dying:
		_hit_vel = _hit_vel.lerp(Vector2.ZERO, fly_decel * delta)
		_spin_angle += _spin_speed * delta
		_spin_speed *= 1.0 - 3.0 * delta
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
		_pulse_time += delta * 7.0
		if _coop_timer <= 0.0:
			_clear_coop_window()

	var to_center = MAP_CENTER - global_position
	if to_center.length() <= REACH_DIST:
		reach_center.emit(complaint_value)
		queue_free()
		return

	_sep_vel = Vector2.ZERO
	_external_vel = _external_vel.lerp(Vector2.ZERO, 5.0 * delta)
	_impact_vel = _impact_vel.lerp(Vector2.ZERO, armor_push_decay * delta)

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


func _check_chain_collision() -> void:
	for other in get_tree().get_nodes_in_group("small_enemies"):
		if _chain_hit_bodies.has(other):
			continue
		if global_position.distance_to(other.global_position) < break_chain_dist:
			_chain_hit_bodies.append(other)
			other.take_hit(_hit_vel.normalized(), max(_hit_vel.length() * chain_speed_ratio, 520.0), 0)

	for player in get_tree().get_nodes_in_group("players"):
		if _chain_hit_bodies.has(player):
			continue
		if global_position.distance_to(player.global_position) < body_radius + 32.0:
			_chain_hit_bodies.append(player)
			player.apply_knockback(_hit_vel.normalized(), chain_player_force)


func _start_fade() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(0.9, 0.35, 0.1, 0.0), 0.34)
	tw.tween_callback(queue_free)


func _draw() -> void:
	draw_set_transform(Vector2(4.0, body_radius * 0.82), 0.0, Vector2(0.90, 0.20))
	draw_circle(Vector2.ZERO, body_radius, Color(0.0, 0.0, 0.0, 0.48))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_set_transform(Vector2.ZERO, _spin_angle, _display_scale)
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 64, outline_color, 4.0)

	if _coop_window_active:
		var pulse = 0.45 + 0.55 * sin(_pulse_time)
		draw_arc(
			Vector2.ZERO,
			body_radius + 8.0 + pulse * 6.0,
			0.0,
			TAU,
			64,
			Color(armor_color.r, armor_color.g, armor_color.b, 0.55 + pulse * 0.30),
			3.0
		)

	for i in range(2):
		var filled = i < _coop_hitters.size()
		var marker_pos = Vector2(-12.0 + float(i) * 24.0, -body_radius - 12.0)
		var marker_color = Color.WHITE if filled else Color(0.25, 0.12, 0.05, 0.85)
		draw_circle(marker_pos, 5.0, marker_color)
		draw_arc(marker_pos, 5.0, 0.0, TAU, 20, armor_color, 1.5)

	draw_circle(Vector2(-13.0, -9.0), 7.0, Color.BLACK)
	draw_circle(Vector2(13.0, -9.0), 7.0, Color.BLACK)
	draw_arc(Vector2.ZERO, 17.0, deg_to_rad(18), deg_to_rad(162), 18, Color.BLACK, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func take_hit(hit_dir: Vector2 = Vector2.RIGHT, hit_speed: float = 420.0, attacker_id: int = 0) -> void:
	if _dying:
		return

	var break_dir = _get_break_dir(hit_dir)
	if attacker_id > 0:
		_handle_player_hit(attacker_id, break_dir, hit_speed)
		return

	_apply_armor_hit(break_dir, hit_speed)


func _handle_player_hit(attacker_id: int, break_dir: Vector2, hit_speed: float) -> void:
	if not _coop_window_active:
		_coop_window_active = true
		_coop_timer = hit_window
		_pulse_time = 0.0
		_coop_hitters.clear()
		_coop_hitters[attacker_id] = true
		_apply_armor_hit(break_dir, hit_speed)
		return

	if _coop_hitters.has(attacker_id):
		_apply_armor_hit(break_dir, hit_speed)
		return

	_coop_hitters[attacker_id] = true
	_do_break(break_dir, hit_speed)


func _apply_armor_hit(break_dir: Vector2, hit_speed: float) -> void:
	_impact_vel = break_dir * max(hit_speed * armor_push_ratio, 38.0)

	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(3.0, 1.4, 0.25, 1.0), 0.03)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)

	_display_scale = Vector2.ONE
	var sq = create_tween()
	sq.tween_property(self, "_display_scale", Vector2(1.35, 0.72), 0.04)
	sq.tween_property(self, "_display_scale", Vector2(0.90, 1.16), 0.08)
	sq.tween_property(self, "_display_scale", Vector2.ONE, 0.08)


func _do_break(break_dir: Vector2, hit_speed: float) -> void:
	_clear_coop_window()
	_dying = true
	_fading = false
	_chain_hit_bodies.clear()
	_display_scale = Vector2.ONE

	var launch_speed = max(hit_speed * break_speed_multiplier, break_min_launch_speed)
	var spread = randf_range(-break_angle_spread, break_angle_spread)
	_hit_vel = break_dir.rotated(spread) * launch_speed

	var sign = 1.0 if randf() > 0.5 else -1.0
	_spin_speed = sign * randf_range(12.0, 20.0)

	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(3.8, 3.6, 2.4, 1.0), 0.04)
	tw.tween_property(self, "modulate", Color(1.0, 0.55, 0.18, 1.0), 0.12)

	var sq = create_tween()
	sq.tween_property(self, "_display_scale", Vector2(1.90, 0.34), 0.05)
	sq.tween_property(self, "_display_scale", Vector2(0.62, 1.65), 0.08)
	sq.tween_property(self, "_display_scale", Vector2(1.10, 0.90), 0.08)
	sq.tween_property(self, "_display_scale", Vector2.ONE, 0.10)

	armor_broken.emit(global_position)


func _clear_coop_window() -> void:
	_coop_window_active = false
	_coop_timer = 0.0
	_coop_hitters.clear()


func _get_break_dir(hit_dir: Vector2) -> Vector2:
	var outward = (global_position - MAP_CENTER).normalized()
	if outward != Vector2.ZERO:
		return outward

	if hit_dir != Vector2.ZERO:
		return -hit_dir.normalized()
	return Vector2.RIGHT


func apply_push(dir: Vector2, force: float) -> void:
	_external_vel = (_external_vel + dir * force).limit_length(360.0)
