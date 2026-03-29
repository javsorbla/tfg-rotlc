extends Camera2D

var shake_timer = 0.0
var shake_intensity = 0.0
var base_offset = Vector2(30, -10)
var boss_room_mode = false
var boss_room_target = Vector2.ZERO

const SHAKE_DURATION = 0.2
const SHAKE_INTENSITY = 3.0

@onready var player = get_tree().get_first_node_in_group("player")

# Zona muerta vertical
const DEADZONE_Y = 30.0  # píxeles arriba y abajo antes de que la cámara se mueva
const FOLLOW_SPEED_X = 0.15
const FOLLOW_SPEED_Y = 0.1

func shake():
	shake_timer = SHAKE_DURATION
	shake_intensity = SHAKE_INTENSITY

func _process(delta):
	if boss_room_mode:
		global_position = lerp(global_position, boss_room_target, 0.02)
		return
	
	if player:
		# Seguir horizontalmente siempre
		var target_x = player.global_position.x + base_offset.x
		global_position.x = lerp(global_position.x, target_x, FOLLOW_SPEED_X)

		# Seguir verticalmente solo si sale de la zona muerta
		var diff_y = player.global_position.y - global_position.y
		if abs(diff_y) > DEADZONE_Y:
			var target_y = player.global_position.y - sign(diff_y) * DEADZONE_Y
			global_position.y = lerp(global_position.y, target_y, FOLLOW_SPEED_Y)

	if shake_timer > 0:
		shake_timer -= delta
		var intensity = shake_intensity * (shake_timer / SHAKE_DURATION)
		offset = base_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
	else:
		offset = base_offset
