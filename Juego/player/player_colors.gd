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

const POWER_COOLDOWNS = {
	"cyan": 3.0,
	"red": 5.0,
	"yellow": 7.0
}
const POWER_DURATIONS = {
	"cyan": 6.0,
	"red": 5.0,
	"yellow": 3.0
}

var cooldown_timers = {
	"cyan": 0.0,
	"red": 0.0,
	"yellow": 0.0
}

var active_power = ""
var power_timer = 0.0
var power_active = false

func _ready():
	neutral_state = NeutralState.new()
	cyan_state = CyanState.new()	
	red_state = RedState.new()
	yellow_state = YellowState.new()

	neutral_state.init(player)
	cyan_state.init(player)
	red_state.init(player)
	yellow_state.init(player)

	change_state(neutral_state)

func process(delta):
	for power in cooldown_timers:
		if cooldown_timers[power] > 0:
			cooldown_timers[power] -= delta

	if power_active:
		power_timer -= delta
		if power_timer <= 0:
			power_active = false
			_start_cooldown(active_power)
			change_state(neutral_state)

	if current_state:
		current_state.process(delta)
	_handle_input()

func _start_cooldown(power: String):
	cooldown_timers[power] = POWER_COOLDOWNS[power]

func _handle_input():
	if Input.is_action_just_pressed("power_cyan") and unlocked["cyan"] and cooldown_timers["cyan"] <= 0:
		if current_state == cyan_state:
			change_state(neutral_state)
			_start_cooldown("cyan")
		else:
			change_state(cyan_state)

	elif Input.is_action_just_pressed("power_red") and unlocked["red"] and cooldown_timers["red"] <= 0:
		if current_state == red_state:
			change_state(neutral_state)
			_start_cooldown("red")
		else:
			change_state(red_state)

	elif Input.is_action_just_pressed("power_yellow") and unlocked["yellow"] and cooldown_timers["yellow"] <= 0:
		if current_state == yellow_state:
			change_state(neutral_state)
			_start_cooldown("yellow")
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

	if new_state == cyan_state:
		active_power = "cyan"
		power_timer = POWER_DURATIONS["cyan"]
		power_active = true
	elif new_state == red_state:
		active_power = "red"
		power_timer = POWER_DURATIONS["red"]
		power_active = true
	elif new_state == yellow_state:
		active_power = "yellow"
		power_timer = POWER_DURATIONS["yellow"]
		power_active = true
	else:
		active_power = ""
		power_active = false
	
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
