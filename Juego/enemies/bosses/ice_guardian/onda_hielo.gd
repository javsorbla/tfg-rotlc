extends Node2D

const SPEED := 220.0
const FLOOR_SNAP_RANGE := 64.0
const GROUND_OFFSET := 4.0
const FLOOR_NORMAL_MIN_Y := -0.7
const FRONT_X_OFFSET := 34.0
const WALL_CHECK_DISTANCE := 10.0
const WALL_CHECK_HEIGHT_LOW := -8.0
const WALL_CHECK_HEIGHT_MID := -22.0
const FLOOR_AHEAD_EXTRA := 2.0
const LOST_GROUND_GRACE := 0.15
const MAX_SNAP_UP := 6.0
const MAX_SNAP_DOWN := 24.0
const FORCED_FLOOR_CHECK_UP := 28.0
const FORCED_FLOOR_CHECK_DOWN := 56.0

var DAMAGE := 1
var direction := 1.0
var is_ending := false
var lost_ground_time := 0.0
var forced_ground_y: float = NAN
var use_forced_ground := false
var use_room_bounds := false
var room_left_bound: float = -INF
var room_right_bound: float = INF

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $EnemyHitbox

func init(move_direction: float, ground_y: float = NAN, left_bound: float = -INF, right_bound: float = INF) -> void:
	direction = sign(move_direction)
	if direction == 0.0:
		direction = 1.0
	if not is_nan(ground_y):
		forced_ground_y = ground_y
		use_forced_ground = true
	if is_finite(left_bound) and is_finite(right_bound):
		room_left_bound = left_bound
		room_right_bound = right_bound
		use_room_bounds = true


func _ready() -> void:
	sprite.flip_h = direction < 0.0
	hitbox.monitoring = true
	hitbox.monitorable = true
	if use_forced_ground:
		global_position.y = forced_ground_y
	else:
		_snap_to_ground()
	_configure_animation_loops()
	_run_animation_sequence()


func _physics_process(delta: float) -> void:
	if is_ending:
		return
	if _reached_room_bounds():
		_start_disappear()
		return
	if not use_room_bounds and _has_wall_ahead():
		_start_disappear()
		return
	if use_forced_ground:
		if not _has_forced_floor_ahead():
			_start_disappear()
			return
		position.x += direction * SPEED * delta
		global_position.y = forced_ground_y
		return
	if not _has_floor_ahead():
		lost_ground_time += delta
		if lost_ground_time >= LOST_GROUND_GRACE:
			_start_disappear()
		return
	position.x += direction * SPEED * delta
	if _snap_to_ground():
		lost_ground_time = 0.0
	else:
		lost_ground_time += delta
		if lost_ground_time >= LOST_GROUND_GRACE:
			_start_disappear()


func _configure_animation_loops() -> void:
	if not sprite.sprite_frames:
		return
	if sprite.sprite_frames.has_animation("appear"):
		sprite.sprite_frames.set_animation_loop("appear", false)
	if sprite.sprite_frames.has_animation("disappear"):
		sprite.sprite_frames.set_animation_loop("disappear", false)


func _run_animation_sequence() -> void:
	_run_animation_sequence_async()


func _run_animation_sequence_async() -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("appear"):
		sprite.play("appear")
		await sprite.animation_finished
		if is_ending:
			return

	sprite.play("idle")


func _start_disappear() -> void:
	if is_ending:
		return
	is_ending = true

	hitbox.monitoring = false
	hitbox.monitorable = false

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("disappear"):
		sprite.play("disappear")
		await sprite.animation_finished

	queue_free()


func _snap_to_ground() -> bool:
	var hit := _get_floor_hit(0.0)
	if hit.is_empty():
		return false
	var target_y: float = float(hit.position.y) + GROUND_OFFSET
	var delta_y: float = target_y - global_position.y
	if delta_y < -MAX_SNAP_UP or delta_y > MAX_SNAP_DOWN:
		return false
	global_position.y = target_y
	return true


func _has_floor_ahead() -> bool:
	var front_offset := direction * (FRONT_X_OFFSET + FLOOR_AHEAD_EXTRA)
	return not _get_floor_hit(front_offset).is_empty()


func _has_forced_floor_ahead() -> bool:
	var front_x := global_position.x + direction * (FRONT_X_OFFSET + FLOOR_AHEAD_EXTRA)
	var start := Vector2(front_x, forced_ground_y - FORCED_FLOOR_CHECK_UP)
	var finish := Vector2(front_x, forced_ground_y + FORCED_FLOOR_CHECK_DOWN)
	var hit := _cast_ray(start, finish)
	if hit.is_empty():
		return false
	return hit.normal.y <= FLOOR_NORMAL_MIN_Y


func _reached_room_bounds() -> bool:
	if not use_room_bounds:
		return false
	var front_x := global_position.x + direction * FRONT_X_OFFSET
	if direction < 0.0:
		return front_x <= room_left_bound
	return front_x >= room_right_bound


func _has_wall_ahead() -> bool:
	var start_low := global_position + Vector2(direction * FRONT_X_OFFSET, WALL_CHECK_HEIGHT_LOW)
	var finish_low := start_low + Vector2(direction * WALL_CHECK_DISTANCE, 0.0)
	var low_hit := _cast_ray(start_low, finish_low)
	if not low_hit.is_empty() and abs(low_hit.normal.x) > 0.7:
		return true

	var start_mid := global_position + Vector2(direction * FRONT_X_OFFSET, WALL_CHECK_HEIGHT_MID)
	var finish_mid := start_mid + Vector2(direction * WALL_CHECK_DISTANCE, 0.0)
	var mid_hit := _cast_ray(start_mid, finish_mid)
	return not mid_hit.is_empty() and abs(mid_hit.normal.x) > 0.7


func _get_floor_hit(x_offset: float) -> Dictionary:
	var start := global_position + Vector2(x_offset, -FLOOR_SNAP_RANGE)
	var finish := global_position + Vector2(x_offset, FLOOR_SNAP_RANGE)
	var hit := _cast_ray(start, finish)
	if hit.is_empty():
		return {}
	if hit.normal.y > FLOOR_NORMAL_MIN_Y:
		return {}
	return hit


func _cast_ray(start: Vector2, finish: Vector2) -> Dictionary:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(start, finish)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = [self]
	return space_state.intersect_ray(query)
