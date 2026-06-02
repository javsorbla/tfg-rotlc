extends CharacterBody2D

const MAX_HEALTH: int = 1
const DAMAGE: int = 10
const ATTACK_SPEED: float = 320.0
const SLEEP_DISTANCE: float = 250.0

enum State { SLEEP, ATTACK, EXPLODE, DEAD }

var current_state: State = State.SLEEP
var current_health: int = MAX_HEALTH
var player: Node2D = null
var attack_direction: Vector2 = Vector2.ZERO
var explode_timer: float = 0.0
var explode_from_death: bool = false
var dead_timer: float = 0.0
var spawn_position = Vector2.ZERO
var previous_state: State = State.SLEEP
var _combat_reset_state: Dictionary = {}

@onready var luz = $PointLight2D

func _ready() -> void:
	current_health = MAX_HEALTH
	player = get_tree().get_first_node_in_group("player")
	spawn_position = global_position
	GameState.level_reset.connect(_on_level_reset)
	
	if not $EnemyHitbox.area_entered.is_connected(_on_enemy_hitbox_area_entered):
		$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)
	if not $EnemyHurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
		$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)
	_combat_reset_state = EnemyResetUtils.capture_collider_state($EnemyHitbox, $EnemyHurtbox)

	_enter_state(State.SLEEP)
	
	var imagen = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var dx = (x - 32.0) / 32.0
			var dy = (y - 32.0) / 32.0
			var dist = sqrt(dx*dx + dy*dy)
			var alpha = clamp(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.5)
			imagen.set_pixel(x, y, Color(1, 1, 1, alpha))
	luz.texture = ImageTexture.create_from_image(imagen)
	luz.blend_mode = Light2D.BLEND_MODE_ADD
	
	_actualizar_luz()

func _actualizar_luz():
	match current_state:
		State.SLEEP:
			luz.color = Color(0.0, 0.6, 1.0)
			luz.texture_scale = 0.8
			luz.energy = 1.0
		State.ATTACK:
			luz.color = Color(0.0, 0.6, 1.0, 0.5)
			luz.texture_scale = 1.5
			luz.energy = 5.0
		State.EXPLODE:
			luz.color = Color(0.0, 0.6, 1.0, 0.5)
			luz.texture_scale = 2.0
			luz.energy = 6.0
		State.DEAD:
			luz.color = Color(0.0, 0.6, 1.0, 0.2)
			luz.texture_scale = 1.5
			luz.energy = 3.0

func _physics_process(delta: float) -> void:
	match current_state:
		State.SLEEP:
			_state_sleep()
		State.ATTACK:
			_state_attack(delta)
		State.EXPLODE:
			pass
		State.DEAD:
			_state_dead(delta)

	move_and_slide()

func _on_level_reset():
	set_physics_process(true)
	visible = true
	current_health = MAX_HEALTH
	global_position = spawn_position
	velocity = Vector2.ZERO
	attack_direction = Vector2.ZERO
	explode_timer = 0.0
	explode_from_death = false
	dead_timer = 0.0
	EnemyResetUtils.restore_collider_state($EnemyHitbox, $EnemyHurtbox, _combat_reset_state)
	_enter_state(State.SLEEP)


func _despawn_dead_instance() -> void:
	velocity = Vector2.ZERO
	EnemyResetUtils.despawn(self)

func _enter_state(new_state: State) -> void:
	previous_state = current_state
	current_state = new_state

	match new_state:
		State.SLEEP:
			velocity = Vector2.ZERO

		State.ATTACK:
			$AnimatedSprite2D.play("charged")
			if player:
				var head_pos = player.global_position + Vector2(0, 10)
				attack_direction = (head_pos - global_position).normalized()
				explode_timer = 0.0
				
		State.EXPLODE:
			velocity = Vector2.ZERO
			if previous_state == State.DEAD:
				$AnimatedSprite2D.play("dead_explode")
			else:
				$AnimatedSprite2D.play("explode")
			if $EnemyHitbox:
				$EnemyHitbox.monitoring = false
				$EnemyHitbox.monitorable = false
			if player and global_position.distance_to(player.global_position) < 30.0:
				if explode_from_death:
					player.get_node("Health").is_invincible = false 
				player.get_node("Health").take_damage(DAMAGE)
				
			var timer = Timer.new()
			add_child(timer)
			timer.wait_time = 0.75
			timer.one_shot = true
			timer.timeout.connect(_despawn_dead_instance)
			timer.start()
	
		State.DEAD:
			explode_from_death = false
			$AnimatedSprite2D.play("dead")
			if $EnemyHitbox:
				$EnemyHitbox.set_deferred("monitoring", false)
				$EnemyHitbox.set_deferred("monitorable", false)
				$EnemyHitbox.set_deferred("collision_layer", 0)
				$EnemyHitbox.set_deferred("collision_mask", 0)
			
			if $EnemyHurtbox:
				$EnemyHurtbox.set_deferred("monitoring", false)
				$EnemyHurtbox.set_deferred("monitorable", false)
				$EnemyHurtbox.set_deferred("collision_layer", 0)
				$EnemyHurtbox.set_deferred("collision_mask", 0)
			velocity = Vector2(0, 0)
	
	_actualizar_luz()

func _state_sleep() -> void:
	velocity = Vector2.ZERO
	if not player:
		return

	var dist = global_position.distance_to(player.global_position)
	$Vision.target_position = player.global_position - global_position

	if dist <= SLEEP_DISTANCE and not $Vision.is_colliding():
		_enter_state(State.ATTACK)
		return

	$AnimatedSprite2D.play("sleep")


func _state_attack(delta: float) -> void:
	# Si entra en contacto con un muro o el jugador, explota
	if not player:
		_enter_state(State.SLEEP)
		return

	explode_timer += delta
	if explode_timer >= 1.2 or is_on_wall():
		_enter_state(State.EXPLODE)
		return

	velocity = attack_direction * ATTACK_SPEED
	$AnimatedSprite2D.flip_h = attack_direction.x >= 0
		

func _state_dead(delta: float) -> void:
	velocity.y += 800 * delta
	if is_on_floor():
		dead_timer += delta
		if dead_timer >= 2.0:
			_enter_state(State.EXPLODE)


func _on_enemy_hitbox_area_entered(area: Area2D):
	if area.is_in_group("player_hurtbox"):
		_enter_state(State.EXPLODE)


func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var player_node = get_tree().get_first_node_in_group("player")
		var multiplier = player_node.damage_multiplier if player_node else 1.0
		take_damage(int(1 * multiplier))


func take_damage(amount: int) -> void:
	if current_state == State.DEAD or current_state == State.EXPLODE:
		return
	current_health -= amount
	if current_health <= 0:
		die()


func die() -> void:
	_enter_state(State.DEAD)
