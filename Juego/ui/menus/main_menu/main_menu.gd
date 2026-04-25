extends MainMenu

@onready var background_texture = $BackgroundTextureRect
@onready var color_overlay = $ColorOverlay
var progress := 0.0

func _apply_color_progression():
	var game_state = _get_game_state()
	if game_state == null:
		return

	progress = clamp(float(game_state.current_level - 1) / 3.0, 0.0, 1.0)

	# Fondo (afecta mundo, no UI)
	background_texture.modulate = Color(1,1,1).lerp(
		Color(0.4, 0.4, 0.45),
		1.0 - progress
	)

	# SOLO overlay general UI (no botones individuales)
	color_overlay.modulate.a = 0.5 * (1.0 - progress * 0.5)

func _get_game_state() -> GameState:
	if has_node("/root/GameState"):
		return get_node("/root/GameState")
	return null
