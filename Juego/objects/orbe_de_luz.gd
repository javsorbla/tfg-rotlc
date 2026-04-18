extends Area2D

@export var is_spawned := false

var spawn_position := Vector2.ZERO
var is_consumed := false
var _initial_collision_layer := 0
var _initial_collision_mask := 0

func _ready():
	if not is_in_group("light_orb"):
		add_to_group("light_orb")
	if not is_spawned:
		spawn_position = global_position
	_initial_collision_layer = collision_layer
	_initial_collision_mask = collision_mask
	if not GameState.level_reset.is_connected(_on_level_reset):
		GameState.level_reset.connect(_on_level_reset)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_consumed:
		return

	var health = body.get_node_or_null("Health")
	if health == null:
		return

	if health.current_health >= health.MAX_HEALTH:
		return

	health.heal(1)
	if is_spawned:
		queue_free()
	else:
		_consume_static_orb()


func _on_level_reset() -> void:
	if is_spawned:
		queue_free()
		return

	if is_consumed:
		_restore_static_orb()


func _consume_static_orb() -> void:
	is_consumed = true
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)


func _restore_static_orb() -> void:
	is_consumed = false
	global_position = spawn_position
	visible = true
	set_deferred("collision_layer", _initial_collision_layer)
	set_deferred("collision_mask", _initial_collision_mask)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
