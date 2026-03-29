extends CharacterBody2D

const DAMAGE: int = 1

const STUN_DURATION: float  = 1.0
const IDLE_DISTANCE: float = 250.0
const LOSE_DISTANCE: float = 275.0
const GRAVITY: float = 700.0

const TELEPORT_DISTANCE: float = 70.0      # Distancia mínima con el jugador
const TELEPORT_MIN_DIST: float = 200.0      # Distancia mínima tras teletransporte
const TELEPORT_MAX_DIST: float = 250.0      # Distancia máxima tras teletransporte
const TELEPORT_ATTEMPTS: int = 20           # Intentos para encontrar posición válida
const TELEPORT_HALF_WIDTH: float = 14.0
const TELEPORT_SAFETY_MARGIN: float = 40.0
const SHOOT_COOLDOWN: float = 2.0

enum State { IDLE, ATTACK, STUNNED }

var current_state: State = State.IDLE
var player: Node2D = null
var stun_timer: float = 0.0
var shoot_timer: float = 0.0

@onready var attack_scene = preload("res://enemies/common/inquisidor_tenebroso/AtaqueInquisidor.tscn")


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	if not $EnemyHitbox.area_entered.is_connected(_on_enemy_hitbox_area_entered):
		$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)
	if not $EnemyHurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
		$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)

	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	if shoot_timer > 0.0:
		shoot_timer -= delta

	match current_state:
		State.IDLE:
			_state_idle()
		State.ATTACK:
			_state_attack()
		State.STUNNED:
			_state_stunned(delta)

	move_and_slide()


func _enter_state(new_state: State) -> void:
	current_state = new_state

	match new_state:
		State.IDLE:
			$AnimatedSprite2D.play("idle")

		State.ATTACK:
			$AnimatedSprite2D.play("idle")


func _state_idle() -> void:
	velocity.x = 0

	if player and global_position.distance_to(player.global_position) <= IDLE_DISTANCE:
		_enter_state(State.ATTACK)


func _state_attack() -> void:
	velocity.x = 0
	
	if not player:
		_enter_state(State.IDLE)
		return
		
	var dist = global_position.distance_to(player.global_position)
	if dist > LOSE_DISTANCE:
		_enter_state(State.IDLE)
		return
		
	# Si el jugador se acerca demasiado, el enemigo se teletransporta de manera aleatoria
	if dist < TELEPORT_DISTANCE:
		if _should_teleport():
			_teleport_away()
		return

	# Disparar si el cooldown ha terminado
	if shoot_timer <= 0.0:
		_shoot()
		shoot_timer = SHOOT_COOLDOWN
		
	$AnimatedSprite2D.flip_h = player.global_position.x > global_position.x


func _shoot() -> void:
	var attack = attack_scene.instantiate()
	get_tree().current_scene.add_child(attack)
	attack.global_position = global_position
	attack.direction = global_position.direction_to(player.global_position)


func _should_teleport() -> bool:
	var space_state = get_world_2d().direct_space_state
	var ray = PhysicsRayQueryParameters2D.create(
		global_position - Vector2(0, 10),
		player.global_position - Vector2(0, 10)
	)
	ray.exclude = [self.get_rid(), player.get_rid()]
	var result = space_state.intersect_ray(ray)

	if not result:
		return true

	# Si hay muro vertical, no detecta al jugador
	var is_horizontal_wall = abs(result.normal.y) > abs(result.normal.x)
	var player_is_below = player.global_position.y > global_position.y
	return is_horizontal_wall and player_is_below


func _raycast(space_state: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> Dictionary:
	var ray = PhysicsRayQueryParameters2D.create(from, to)
	ray.exclude = [self.get_rid()]
	return space_state.intersect_ray(ray)


func _teleport_away() -> void:
	var space_state = get_world_2d().direct_space_state

	for i in TELEPORT_ATTEMPTS:
		var angle = randf() * TAU
		var distance = randf_range(TELEPORT_MIN_DIST, TELEPORT_MAX_DIST)
		var candidate = player.global_position + Vector2(cos(angle), sin(angle)) * distance

		var shape = CircleShape2D.new()
		shape.radius = 8.0
		var shape_query = PhysicsShapeQueryParameters2D.new()
		shape_query.shape = shape
		shape_query.transform = Transform2D(0, candidate)
		shape_query.exclude = [self.get_rid()]
		if space_state.intersect_shape(shape_query, 1).size() > 0:
			continue

		# Raycast para encontrar suelo
		var ground_result = _raycast(space_state, candidate, candidate + Vector2(0, 500))
		if not ground_result:
			continue
		var ground_y = ground_result.position.y
		var landing_pos = Vector2(candidate.x, ground_y - 1.0)

		# Comprobar que el suelo no se acaba justo en el borde del enemigo
		var grounded := true
		for x in [-TELEPORT_HALF_WIDTH, TELEPORT_HALF_WIDTH]:
			var origin = Vector2(landing_pos.x + x, ground_y - 5.0)
			if not _raycast(space_state, origin, origin + Vector2(0, 20)):
				grounded = false
				break
		if not grounded:
			continue
			
		# Comprobar que no hay vacío total más allá del enemigo
		for x in [-TELEPORT_SAFETY_MARGIN, TELEPORT_SAFETY_MARGIN]:
			var origin = Vector2(landing_pos.x + x, ground_y - 100.0)
			if not _raycast(space_state, origin, origin + Vector2(0, 600)):
				grounded = false
				break
		if not grounded:
			continue

		# Espacio libre para el enemigo
		if _raycast(space_state, landing_pos, landing_pos - Vector2(0, 80)):
			continue

		# Distancia mínima de teletrasnporte respecto al jugador
		if landing_pos.distance_to(player.global_position) < TELEPORT_MIN_DIST:
			continue

		global_position = landing_pos
		velocity = Vector2.ZERO
		return


func _state_stunned(delta):
	stun_timer -= delta
	velocity.x = 0

	if stun_timer <= 0:
		_enter_state(State.IDLE)


func _on_enemy_hitbox_area_entered(area: Area2D): 
	if area.is_in_group("player_hurtbox"): 
		var target = area.get_parent() 
		if target.has_method("take_damage"): 
			target.take_damage(DAMAGE) 


func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"): 
		take_damage(0) # Vida infinita temporalmente


func take_damage(amount: int) -> void: 
	# Vida infinita
	stun_timer = STUN_DURATION
	_enter_state(State.STUNNED) 
	$AnimatedSprite2D.play("stunned")
