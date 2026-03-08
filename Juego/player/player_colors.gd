extends Node

@onready var player = get_parent()

var current_state = null
var neutral_state = null
var cyan_state = null
var red_state = null
var yellow_state = null

# Poderes  desbloqueados
var unlocked = {
	"cyan": false,
	"red": false,
	"yellow": false
}

func _ready():
	neutral_state = load("res://scripts/states/NeutralState.gd").new()
	cyan_state = load("res://scripts/states/CyanState.gd").new()	
	red_state = load("res://scripts/states/RedState.gd").new()
	yellow_state = load("res://scripts/states/YellowState.gd").new()

	neutral_state.init(player)
	cyan_state.init(player)
	red_state.init(player)
	yellow_state.init(player)

	change_state(neutral_state)

func process(delta):
	if current_state:
		current_state.process(delta)
	_handle_input()

func _handle_input():
	if Input.is_action_just_pressed("power_cyan") and unlocked["cyan"]:
		if current_state == cyan_state:
			change_state(neutral_state)  # toggle: desactiva si ya está activo
		else:
			change_state(cyan_state)

	elif Input.is_action_just_pressed("power_red") and unlocked["red"]:
		if current_state == red_state:
			change_state(neutral_state)
		else:
			change_state(red_state)

	elif Input.is_action_just_pressed("power_yellow") and unlocked["yellow"]:
		if current_state == yellow_state:
			change_state(neutral_state)
		else:
			change_state(yellow_state)

func _update_sprite_color(primary: Color, secondary: Color):
	var mat = player.get_node("AnimatedSprite2D").material
	if mat:
		mat.set_shader_parameter("color_primary", primary)
		mat.set_shader_parameter("color_secondary", secondary)

func change_state(new_state):
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.enter()
	# Actualizar color del sprite
	if new_state == cyan_state:
		_update_sprite_color(
			Color(0.0, 0.85, 1.0),   # celeste claro
			Color(0.0, 0.65, 0.85)   # celeste oscuro
		)
	elif new_state == red_state:
		_update_sprite_color(
			Color(1.0, 0.2, 0.2),    # rojo claro
			Color(0.8, 0.1, 0.1)     # rojo oscuro
		)
	elif new_state == yellow_state:
		_update_sprite_color(
			Color(1.0, 0.9, 0.0),    # amarillo claro
			Color(0.85, 0.7, 0.0)    # amarillo oscuro
		)
	else:
		_update_sprite_color(
			Color(1.0, 1.0, 1.0),    # blanco
			Color(0.925, 0.910, 0.910) # blanco secundario
		)

func unlock_power(color: String):
	unlocked[color] = true
