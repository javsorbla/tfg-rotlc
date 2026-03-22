extends Node2D

enum State { IDLE, CHARGE, PROJECTILE, JUMP, HURT, DEAD }
enum Phase { ONE, TWO }

const MAX_HEALTH = 40
const PHASE_TWO_THRESHOLD = 0.5
const BOSS_HALF_WIDTH = 40.0
const FLOAT_AMPLITUDE = 8.0
const FLOAT_SPEED = 60.0
const FLOAT_SPEED_P2 = 100.0
const STOP_DISTANCE = 150.0

# Fase 1
const CHARGE_SPEED = 120.0
const CHARGE_COOLDOWN = 3.0
const PROJECTILE_COOLDOWN = 4.0

# Fase 2
const CHARGE_SPEED_P2 = 200.0
const CHARGE_COOLDOWN_P2 = 2.0
const PROJECTILE_COOLDOWN_P2 = 2.5
const JUMP_COOLDOWN = 5.0
const JUMP_SPEED = 300.0

var current_health = MAX_HEALTH
var current_state = State.IDLE
var current_phase = Phase.ONE
var player = null

var charge_timer = 0.0
var projectile_timer = 0.0
var jump_timer = 0.0
var action_timer = 0.0

var jump_velocity = Vector2.ZERO
var original_y = 0.0

var room_left_limit = 0.0
var room_right_limit = 0.0
var room_top_limit = 0.0
var room_bottom_limit = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var projectile_spawn = $SpawnProyectil
@onready var projectile_scene = preload("res://enemies/bosses/ice_guardian/ProyectilHielo.tscn")

func _ready():
	player = get_tree().get_first_node_in_group("player")
	charge_timer = CHARGE_COOLDOWN
	projectile_timer = PROJECTILE_COOLDOWN
	original_y = position.y

func _physics_process(delta):
	if room_right_limit == 0.0:
		var boss_room = get_tree().get_first_node_in_group("boss_room")
		if boss_room:
			room_left_limit = boss_room.get_node("LimiteIzquierda").global_position.x
			room_right_limit = boss_room.get_node("LimiteDerecha").global_position.x
			room_top_limit = boss_room.get_node("LimiteArriba").global_position.y
			room_bottom_limit = boss_room.get_node("LimiteAbajo").global_position.y

	if current_state == State.DEAD:
		return

	_check_phase()
	_handle_state(delta)
	_update_timers(delta)

func _check_phase():
	if current_phase == Phase.ONE and current_health <= MAX_HEALTH * PHASE_TWO_THRESHOLD:
		current_phase = Phase.TWO
		_enter_phase_two()

func _enter_phase_two():
	charge_timer = 0.0
	projectile_timer = 0.0

func _update_timers(delta):
	if charge_timer > 0:
		charge_timer -= delta
	if projectile_timer > 0:
		projectile_timer -= delta
	if current_phase == Phase.TWO and jump_timer > 0:
		jump_timer -= delta

func _handle_state(delta):
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.CHARGE:
			_charge_state(delta)
		State.PROJECTILE:
			_projectile_state(delta)
		State.JUMP:
			_jump_state(delta)

func _idle_state(delta):
	action_timer -= delta

	# Moverse hacia el jugador pero parar a cierta distancia
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist > STOP_DISTANCE:
			var dir = (player.global_position - global_position).normalized()
			var speed = FLOAT_SPEED if current_phase == Phase.ONE else FLOAT_SPEED_P2
			position += dir * speed * delta

		# Flotación ondulante
		position.y += sin(Time.get_ticks_msec() * 0.002) * FLOAT_AMPLITUDE * delta

		# Límites
		position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)
		position.y = clamp(position.y, room_top_limit, room_bottom_limit)

		sprite.flip_h = player.global_position.x < global_position.x

	if action_timer > 0:
		return

	if current_phase == Phase.TWO and jump_timer <= 0:
		_start_jump()
	elif charge_timer <= 0:
		_start_charge()
	elif projectile_timer <= 0:
		_start_projectile()

func _start_charge():
	current_state = State.CHARGE
	action_timer = 1.5
	charge_timer = CHARGE_COOLDOWN if current_phase == Phase.ONE else CHARGE_COOLDOWN_P2
	if player:
		sprite.flip_h = player.global_position.x < global_position.x

func _charge_state(delta):
	action_timer -= delta
	var speed = CHARGE_SPEED if current_phase == Phase.ONE else CHARGE_SPEED_P2
	if player:
		var dir = (player.global_position - global_position).normalized()
		position += dir * speed * delta
	position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)
	position.y = clamp(position.y, room_top_limit, room_bottom_limit)
	if action_timer <= 0:
		current_state = State.IDLE

func _start_projectile():
	current_state = State.PROJECTILE
	action_timer = 1.0
	projectile_timer = PROJECTILE_COOLDOWN if current_phase == Phase.ONE else PROJECTILE_COOLDOWN_P2

func _projectile_state(delta):
	action_timer -= delta
	if action_timer <= 0:
		_shoot_projectile()
		current_state = State.IDLE

func _shoot_projectile():
	if not player:
		return
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = projectile_spawn.global_position
	var dir = (player.global_position - projectile_spawn.global_position).normalized()
	projectile.init(dir)

func _start_jump():
	current_state = State.JUMP
	jump_timer = JUMP_COOLDOWN
	action_timer = 1.5
	if player:
		var dir = sign(player.global_position.x - global_position.x)
		jump_velocity = Vector2(dir * JUMP_SPEED, -400.0)

func _jump_state(delta):
	action_timer -= delta
	jump_velocity.y += 600.0 * delta
	position += jump_velocity * delta
	position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)
	if action_timer <= 0:
		position.y = clamp(position.y, room_top_limit, room_bottom_limit)
		jump_velocity = Vector2.ZERO
		_land_shockwave()
		current_state = State.IDLE

func _land_shockwave():
	pass

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO):
	current_health -= amount
	print(current_health)
	if current_health <= 0:
		die()

func die():
	current_state = State.DEAD
	var boss_room = get_tree().get_first_node_in_group("boss_room")
	if boss_room:
		boss_room.on_boss_defeated()
	queue_free()
