extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 300.0
const DASH_DURATION = 0.20
const DASH_COOLDOWN = 0.5
const ACCELERATION = 1000.0
const FRICTION = 700.0

var can_jump = true
var can_double_jump = false
var was_on_floor = false
var is_dashing = false
var dash_timer = 0.0
var can_dash = true
var dash_direction = 1.0
var dash_cooldown_timer = 0.0
var air_dash_used = false
var last_direction = 1
var speed_multiplier = 1.0
var damage_multiplier = 1.0
var is_shielding = false

@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $Hurtbox
@onready var health = $Health
@onready var combat = $Combat
@onready var color_manager = $ColorManager

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var umbra = get_tree().get_first_node_in_group("enemies")
	if umbra:
		# Moverse hacia Umbra con algo de aleatoriedad
		var dir = sign(umbra.global_position.x - global_position.x)
		# 20% de probabilidad de ir en dirección contraria
		if randf() < 0.2:
			dir *= -1
		velocity.x = move_toward(velocity.x, dir * SPEED, 800 * delta)
		
		# Saltar si Umbra está más arriba
		if is_on_floor() and umbra.global_position.y < global_position.y - 50 and randf() < 0.05:
			velocity.y = JUMP_VELOCITY
	
	move_and_slide()
	health.process(delta)
