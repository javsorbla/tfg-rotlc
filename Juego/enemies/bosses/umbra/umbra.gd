extends CharacterBody2D

# Constantes de movimiento (similares a Iris)
const SPEED = 140.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 280.0
const DASH_DURATION = 0.20
const ACCELERATION = 900.0
const FRICTION = 650.0

# Constantes de combate
const MAX_HEALTH = 15
const DAMAGE = 1
const ATTACK_DURATION = 0.3
const ATTACK_COOLDOWN = 1.0
const DASH_COOLDOWN = 1.0
const INVINCIBILITY_DURATION = 0.5

# Variables de movimiento
var can_double_jump = false
var was_on_floor = false
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = 1.0
var air_dash_used = false
var last_direction = 1

# Variables de combate
var current_health = MAX_HEALTH
var is_attacking = false
var attack_timer = 0.0
var attack_cooldown_timer = 0.0
var is_invincible = false
var invincibility_timer = 0.0

# Variables de IA
var ai_move_direction = 0
var ai_should_jump = false
var ai_should_attack = false
var ai_should_dash = false
var ai_should_use_power = false
var is_active = false

var _last_action_received_time := 0.0
var _encounter_reported := false

const ACTION_TIMEOUT_SECONDS := 0.35
const HEURISTIC_ATTACK_DISTANCE := 44.0
const HEURISTIC_DASH_DISTANCE := 180.0
const AUTO_ATTACK_DISTANCE_X := 72.0
const AUTO_ATTACK_DISTANCE_Y := 44.0

@export var force_heuristic_only := false
@export var debug_combat_logs := false

# Variables de poder
var current_power = "none"  # none, cyan, red, yellow

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox
@onready var hurtbox = $Hurtbox
@onready var ai_controller = $AIController2D

func _ready():
	add_to_group("umbra_boss")
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	hurtbox.monitorable = true
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	# Asignar poder según nivel
	_assign_power()
	_apply_persistent_difficulty()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		ai_controller.init(player)

func _assign_power():
	var level = GameState.current_level if "current_level" in GameState else 1
	match level:
		1: current_power = "cyan"
		2: current_power = "red"
		3: current_power = "yellow"

func _physics_process(delta):
	if not is_active:
		return

	if force_heuristic_only or _should_use_heuristic():
		_use_heuristic()
	
	_handle_timers(delta)
	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_jump()
	_handle_dash(delta)
	_handle_attack(delta)
	_handle_power()
	_update_animation()
	
	was_on_floor = is_on_floor()
	move_and_slide()


func _apply_persistent_difficulty() -> void:
	var difficulty_scale := GameState.get_umbra_difficulty_scale()
	current_health = int(round(float(MAX_HEALTH) * difficulty_scale))

func _handle_timers(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			hurtbox.monitorable = true

func _handle_gravity(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_movement(delta):
	if is_dashing:
		return
	if ai_move_direction != 0:
		last_direction = ai_move_direction
		velocity.x = move_toward(velocity.x, ai_move_direction * _get_speed(), ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

func _get_speed():
	# Cyan aumenta la velocidad
	if current_power == "cyan" and ai_should_use_power:
		return SPEED * 1.5
	return SPEED

func _handle_jump():
	if is_dashing:
		return
	if ai_should_jump:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
		elif can_double_jump:
			velocity.y = JUMP_VELOCITY
			can_double_jump = false
	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		can_double_jump = true

func _handle_dash(delta):
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity.x = dash_direction * SPEED * 0.2
		else:
			velocity.x = dash_direction * DASH_SPEED
		return
	
	if ai_should_dash and dash_cooldown_timer <= 0 and (is_on_floor() or not air_dash_used):
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		if not is_on_floor():
			air_dash_used = true
		dash_direction = ai_move_direction if ai_move_direction != 0 else last_direction
		velocity.y = 0

	if is_on_floor():
		air_dash_used = false

func _handle_attack(delta):
	if is_attacking:
		velocity.x = 0.0
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			attack_hitbox.monitoring = false
			attack_hitbox.monitorable = false
		return

	var auto_attack := false
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var rel: Vector2 = player.global_position - global_position
		auto_attack = absf(rel.x) <= AUTO_ATTACK_DISTANCE_X and absf(rel.y) <= AUTO_ATTACK_DISTANCE_Y
		if auto_attack and absf(rel.x) > 6.0:
			last_direction = signi(int(rel.x))

	if (ai_should_attack or auto_attack) and attack_cooldown_timer <= 0:
		is_attacking = true
		ai_move_direction = 0
		attack_timer = ATTACK_DURATION
		attack_cooldown_timer = ATTACK_COOLDOWN
		attack_hitbox.monitoring = true
		attack_hitbox.monitorable = true
		# Posicionar hitbox según dirección
		attack_hitbox.position = Vector2(14 * last_direction, 0)
		if debug_combat_logs:
			print("Umbra ATTACK start | ai=", ai_should_attack, " auto=", auto_attack, " dir=", last_direction)
		
		# Rojo aumenta el daño
		if current_power == "red" and ai_should_use_power:
			attack_hitbox.get_node("CollisionShape2D").set_meta("damage", DAMAGE * 2)

func _handle_power():
	# Amarillo activa escudo
	if current_power == "yellow" and ai_should_use_power:
		is_invincible = true
		hurtbox.monitorable = false
	elif current_power == "yellow" and not ai_should_use_power:
		if not is_invincible:
			hurtbox.monitorable = true

func _update_animation():
	if is_dashing:
		return
	if is_attacking:
		sprite.play("attack")
		return
	if not is_on_floor():
		pass
	elif velocity.x > 0:
		sprite.play("run")
	elif velocity.x < 0:
		sprite.play("run")
	else:
		sprite.play("idle")
	
	if velocity.x > 0:
		sprite.flip_h = false
	elif velocity.x < 0:
		sprite.flip_h = true

func take_damage(amount: int):
	if is_invincible:
		return
	current_health -= amount
	is_invincible = true
	invincibility_timer = INVINCIBILITY_DURATION
	hurtbox.monitorable = false
	if current_health <= 0:
		die()

func die():
	# Guardar métricas para el siguiente encuentro
	_report_encounter(false)
	is_active = false
	queue_free()

func activate():
	is_active = true
	_encounter_reported = false
	_last_action_received_time = Time.get_ticks_msec() / 1000.0

func set_ai_action(action):
	var normalized := _normalize_ai_action(action)
	if normalized.is_empty():
		_use_heuristic()
		return

	ai_move_direction = int(normalized.get("move", 1)) - 1  # 0,1,2 → -1,0,1
	ai_should_jump = int(normalized.get("jump", 0)) == 1
	ai_should_attack = int(normalized.get("attack", 0)) == 1
	ai_should_dash = int(normalized.get("dash", 0)) == 1
	ai_should_use_power = int(normalized.get("power", 0)) == 1

	_last_action_received_time = Time.get_ticks_msec() / 1000.0


func _normalize_ai_action(action) -> Dictionary:
	if action == null:
		return {}

	if typeof(action) == TYPE_DICTIONARY:
		if action.has("move"):
			return action
		if action.has("0"):
			return {
				"move": int(action.get("0", 1)),
				"jump": int(action.get("1", 0)),
				"attack": int(action.get("2", 0)),
				"dash": int(action.get("3", 0)),
				"power": int(action.get("4", 0))
			}
		return {}

	if typeof(action) == TYPE_ARRAY and action.size() >= 5:
		return {
			"move": int(action[0]),
			"jump": int(action[1]),
			"attack": int(action[2]),
			"dash": int(action[3]),
			"power": int(action[4])
		}

	if typeof(action) == TYPE_PACKED_FLOAT32_ARRAY and action.size() >= 5:
		return {
			"move": int(action[0]),
			"jump": int(action[1]),
			"attack": int(action[2]),
			"dash": int(action[3]),
			"power": int(action[4])
		}

	return {}


func _should_use_heuristic() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return now - _last_action_received_time > ACTION_TIMEOUT_SECONDS


func _use_heuristic() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var rel: Vector2 = player.global_position - global_position
	var abs_x := absf(rel.x)
	var abs_y := absf(rel.y)

	ai_move_direction = signi(int(rel.x))
	ai_should_attack = abs_x <= HEURISTIC_ATTACK_DISTANCE and abs_y < 24.0
	ai_should_jump = rel.y < -22.0 and is_on_floor()
	ai_should_dash = abs_x > HEURISTIC_DASH_DISTANCE and dash_cooldown_timer <= 0.0
	ai_should_use_power = abs_x > 120.0


func _report_encounter(umbra_won: bool) -> void:
	if _encounter_reported:
		return

	if ai_controller and ai_controller.has_method("build_encounter_snapshot"):
		var snapshot = ai_controller.build_encounter_snapshot(umbra_won)
		GameState.register_umbra_encounter(snapshot)

	_encounter_reported = true


func _exit_tree() -> void:
	if is_active and not _encounter_reported:
		# If Umbra leaves the tree while alive, treat it as a win for Umbra.
		_report_encounter(true)

func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		take_damage(1)

func _on_attack_hitbox_body_entered(body):
	if body.is_in_group("player"):
		if debug_combat_logs:
			print("Umbra HIT player")
		if body.has_method("get"):
			var health_node = body.get("health")
			if health_node and health_node.has_method("take_damage"):
				health_node.take_damage(DAMAGE)


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_hurtbox"):
		return

	var owner = area.get_parent()
	if owner and owner.is_in_group("player"):
		if debug_combat_logs:
			print("Umbra HIT player hurtbox")
		if owner.has_method("get"):
			var health_node = owner.get("health")
			if health_node and health_node.has_method("take_damage"):
				health_node.take_damage(DAMAGE)
