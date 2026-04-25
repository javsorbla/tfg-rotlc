extends Button

@onready var arrow: TextureRect = $Arrow

func _ready() -> void:
	# Conexiones de foco/hover
	mouse_entered.connect(_on_focus_enter)
	mouse_exited.connect(_on_focus_exit)
	focus_entered.connect(_on_focus_enter)
	focus_exited.connect(_on_focus_exit)

	# Estado inicial
	arrow.visible = false

	# Colores base del theme (fallback por si el theme falla)
	add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_theme_color_override("font_hover_color", Color(1, 1, 1))
	add_theme_color_override("font_focus_color", Color(1, 1, 1))


func _on_focus_enter() -> void:
	arrow.visible = true
	_set_focus_visual(true)


func _on_focus_exit() -> void:
	arrow.visible = false
	_set_focus_visual(false)


func _set_focus_visual(active: bool) -> void:
	if active:
		# blanco limpio cuando está seleccionado
		add_theme_color_override("font_color", Color(1, 1, 1))
		self_modulate = Color(1.05, 1.05, 1.05, 1.0)
	else:
		# gris suave cuando no está seleccionado
		add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		self_modulate = Color(1, 1, 1, 1)
