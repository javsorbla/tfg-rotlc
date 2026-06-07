extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 300.0
const DASH_DURATION = 0.20
const DASH_COOLDOWN = 0.5
const ACCELERATION = 1000.0
const FRICTION = 700.0
const ATTACK_DURATION = 0.20
const ATTACK_COOLDOWN = 0.45

enum ControlMode {
	SMART_BOT,
	HUMAN
}

@export var control_mode: ControlMode = ControlMode.SMART_BOT
@export var bot_strafe_distance := 90.0
@export var bot_react_interval := 0.12
@export var bot_jump_chance := 0.12
@export var bot_voluntary_jump_chance := 0.02
@export var bot_attack_range := 70.0
@export var bot_dash_range := 120.0
@export var debug_bot_logs := false

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
var is_attacking = false
var attack_timer = 0.0
var attack_cooldown_timer = 0.0

var _desired_dir := 0.0
var _strafe_sign := 1.0
var _react_timer := 0.0

var _bot_power_timer := 0.0
var _bot_power_cooldown_timer := 0.0
var _bot_wants_power := ""
var _bot_power_active := false

@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $Hurtbox
@onready var health = $Health
@onready var combat = $Combat
@onready var color_manager = $ColorManager
@onready var attack_hitbox = $AttackHitbox

func _ready() -> void:
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false


func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	_handle_dash(delta)
	_handle_attack(delta)
	_handle_bot_powers(delta)

	match control_mode:
		ControlMode.HUMAN:
			_human_control(delta)
		ControlMode.SMART_BOT:
			_smart_bot_control(delta)

	if _desired_dir != 0:
		last_direction = int(sign(_desired_dir))
		velocity.x = move_toward(velocity.x, _desired_dir * SPEED * speed_multiplier, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	
	move_and_slide()
	health.process(delta)
	color_manager.process(delta)


func set_control_mode(new_mode: int) -> void:
	control_mode = new_mode
	if debug_bot_logs:
		print("Dummy control_mode=", control_mode)


func reset_for_training(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	velocity = Vector2.ZERO
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	is_attacking = false
	attack_timer = 0.0
	attack_cooldown_timer = 0.0
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	health.current_health = health.MAX_HEALTH
	health.is_invincible = false
	health.invincibility_timer = 0.0
	hurtbox.monitorable = true
	_bot_power_timer = 0.0
	_bot_power_cooldown_timer = 0.0
	_bot_wants_power = ""
	_bot_power_active = false
	if color_manager:
		color_manager.apply_unlocked_powers({"cyan": true, "red": true, "yellow": true})
		if color_manager.power_active:
			color_manager.change_state(color_manager.neutral_state)


func _human_control(_delta: float) -> void:
	_desired_dir = Input.get_axis("move_left", "move_right")

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		_start_dash(_desired_dir)

	if Input.is_action_just_pressed("attack") and attack_cooldown_timer <= 0.0:
		_trigger_attack()


func _smart_bot_control(_delta: float) -> void:
	var umbra = get_tree().get_first_node_in_group("enemies")
	if umbra == null:
		_desired_dir = 0.0
		return

	var rel: Vector2 = umbra.global_position - global_position
	var abs_x := absf(rel.x)

	_react_timer -= _delta
	if _react_timer <= 0.0:
		_react_timer = bot_react_interval
		if randf() < 0.10:
			_strafe_sign *= -1.0

	if abs_x > bot_dash_range:
		_desired_dir = sign(rel.x)
	elif abs_x < bot_strafe_distance * 0.55:
		_desired_dir = -sign(rel.x)
	else:
		_desired_dir = _strafe_sign

	if is_on_floor():
		var wants_jump := false
		if not umbra.is_on_floor():
			wants_jump = true
		elif rel.y < -48.0 and randf() < bot_jump_chance:
			wants_jump = true
		elif randf() < bot_voluntary_jump_chance:
			wants_jump = true
		elif umbra.is_attacking and abs_x < bot_strafe_distance and randf() < 0.15:
			wants_jump = true
		if wants_jump:
			velocity.y = JUMP_VELOCITY

	if is_on_floor() and umbra.is_attacking and abs_x < bot_strafe_distance and dash_cooldown_timer <= 0.0:
		_start_dash(-sign(rel.x))
	elif abs_x > bot_dash_range and dash_cooldown_timer <= 0.0 and randf() < 0.10:
		_start_dash(sign(rel.x))

	if abs_x <= bot_attack_range and attack_cooldown_timer <= 0.0:
		_trigger_attack()

	if _bot_power_cooldown_timer <= 0.0 and not color_manager.power_active:
		if health.current_health <= 2 or (umbra.is_attacking and abs_x < bot_strafe_distance):
			_bot_wants_power = "yellow"
		elif abs_x <= bot_attack_range * 1.2 and attack_cooldown_timer <= ATTACK_COOLDOWN * 0.5:
			_bot_wants_power = "red"
		elif abs_x > bot_dash_range * 0.8:
			_bot_wants_power = "cyan"
		else:
			_bot_wants_power = ""

	if _bot_wants_power != "" and _bot_wants_power != color_manager.active_power:
		match _bot_wants_power:
			"cyan":
				if color_manager.unlocked["cyan"] and color_manager.cooldown_timers["cyan"] <= 0.0:
					color_manager.change_state(color_manager.cyan_state)
					_bot_power_active = true
			"red":
				if color_manager.unlocked["red"] and color_manager.cooldown_timers["red"] <= 0.0:
					color_manager.change_state(color_manager.red_state)
					_bot_power_active = true
			"yellow":
				if color_manager.unlocked["yellow"] and color_manager.cooldown_timers["yellow"] <= 0.0:
					color_manager.change_state(color_manager.yellow_state)
					_bot_power_active = true


func _handle_bot_powers(delta: float) -> void:
	if _bot_power_cooldown_timer > 0.0:
		_bot_power_cooldown_timer -= delta

	if _bot_power_active and not color_manager.power_active:
		_bot_power_active = false
		_bot_power_cooldown_timer = 2.0


func _start_dash(dir: float) -> void:
	if dir == 0:
		dir = float(last_direction)
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	dash_direction = sign(dir)
	velocity.y = 0.0


func _handle_dash(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if not is_dashing:
		return

	dash_timer -= delta
	if dash_timer <= 0.0:
		is_dashing = false
		velocity.x = dash_direction * SPEED * 0.2
		return

	velocity.x = dash_direction * DASH_SPEED


func _trigger_attack() -> void:
	is_attacking = true
	attack_timer = ATTACK_DURATION
	attack_cooldown_timer = ATTACK_COOLDOWN
	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = true
	attack_hitbox.position = Vector2(14 * last_direction, 0)


func _handle_attack(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if not is_attacking:
		return

	attack_timer -= delta
	if attack_timer <= 0.0:
		is_attacking = false
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		area.get_parent().take_damage(int(1 * damage_multiplier))


func _on_hurtbox_area_entered(_area: Area2D) -> void:
	# El dano real lo gestiona player_health.gd
	pass


func _on_hurtbox_body_entered(_body: Node2D) -> void:
	# El dano real lo gestiona player_health.gd
	pass
