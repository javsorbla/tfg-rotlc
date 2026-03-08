extends Camera2D

var shake_timer = 0.0
var shake_intensity = 0.0
var base_offset = Vector2(60, -60)
const SHAKE_DURATION = 0.2
const SHAKE_INTENSITY = 3.0

func shake():
	shake_timer = SHAKE_DURATION
	shake_intensity = SHAKE_INTENSITY

func _process(delta):
	if shake_timer > 0:
		shake_timer -= delta
		var intensity = shake_intensity * (shake_timer / SHAKE_DURATION)
		offset = base_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
	else:
		offset = base_offset
