class_name RedState
extends ColorState

const BREAK_PARTICLES = preload("res://scenes/enviroment/ParticulasBloques.tscn")

func enter():
	player.speed_multiplier = 1.0
	player.damage_multiplier = 2.0

func exit():
	player.damage_multiplier = 1.0

func process(delta):
	if Input.is_action_just_pressed("attack"):
		_try_break_wall()

func _try_break_wall():
	var breakable_map = player.get_tree().get_first_node_in_group("breakable_walls")
	if not breakable_map:
		return

	var hitbox = player.get_node("AttackHitbox")
	const HITBOX_OFFSET_X = 14
	const HITBOX_OFFSET_Y = 22

	if Input.is_action_pressed("aim_up"):
		hitbox.position = Vector2(0, -HITBOX_OFFSET_Y)
	elif Input.is_action_pressed("aim_down"):
		hitbox.position = Vector2(0, HITBOX_OFFSET_Y)
	elif Input.is_action_pressed("aim_left"):
		hitbox.position = Vector2(-HITBOX_OFFSET_X, 0)
	elif Input.is_action_pressed("aim_right"):
		hitbox.position = Vector2(HITBOX_OFFSET_X, 0)
	else:
		hitbox.position = Vector2(HITBOX_OFFSET_X * player.last_direction, 0)

	var rect = hitbox.get_node("CollisionShape2D").shape.get_rect()
	var global_rect = Rect2(hitbox.global_position + rect.position, rect.size)

	var top_left = breakable_map.local_to_map(breakable_map.to_local(global_rect.position))
	var bottom_right = breakable_map.local_to_map(breakable_map.to_local(global_rect.end))

	for x in range(top_left.x, bottom_right.x + 1):
		for y in range(top_left.y, bottom_right.y + 1):
			var map_pos = Vector2i(x, y)
			if breakable_map.get_cell_source_id(map_pos) != -1:
				breakable_map.erase_cell(map_pos)
				_spawn_particles(breakable_map, map_pos)

func _spawn_particles(breakable_map, map_pos: Vector2i):
	var particles = BREAK_PARTICLES.instantiate()
	var tile_center = breakable_map.map_to_local(map_pos)
	particles.global_position = breakable_map.to_global(tile_center)
	player.get_parent().add_child(particles)
