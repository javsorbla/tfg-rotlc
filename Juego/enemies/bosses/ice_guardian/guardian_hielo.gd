extends Node2D

enum State { IDLE, CHARGE, PROJECTILE, JUMP, HURT, DEAD }
enum Phase { ONE, TWO }

const MAX_HEALTH = 40
const PHASE_TWO_THRESHOLD = 0.35
const BOSS_HALF_WIDTH = 40.0
const FLOAT_AMPLITUDE = 18.0
const STOP_DISTANCE = 340.0

# Fase 1
const FLOAT_SPEED = 60.0
const CHARGE_SPEED = 200.0
const CHARGE_COOLDOWN = 3.0
const PROJECTILE_COOLDOWN = 4.0

# Fase 2
const FLOAT_SPEED_P2 = 110.0
const CHARGE_SPEED_P2 = 250.0
const CHARGE_COOLDOWN_P2 = 2.0
const PROJECTILE_COOLDOWN_P2 = 2.5
const JUMP_COOLDOWN = 5.0
const JUMP_SPEED = 230.0
const JUMP_HORIZONTAL_DEADZONE = 24.0
const FLOOR_RAY_MARGIN = 64.0
const FLOOR_NEAR_BOTTOM_THRESHOLD = 24.0
const POST_JUMP_RECOVER = 1.25
const DAMAGE_FLASH_TIME = 0.08
const FURY_SUMMON_PAUSE = 2.4
const WALKER_SPAWN_OFFSET_X = 96.0
const WALKER_SPAWN_MARGIN_X = 24.0
const SUMMON_POP_TIME = 0.2
const FURY_SUMMON_STAGGER = 0.22
const FURY_CENTER_MOVE_TIME = 1.0

var current_health = MAX_HEALTH
var current_state = State.IDLE
var current_phase = Phase.ONE
var DAMAGE = 1
var player = null
var is_active = false

var charge_timer = 0.0
var projectile_timer = 0.0
var jump_timer = 0.0
var action_timer = 0.0
var post_jump_recover_timer = 0.0

var jump_velocity = Vector2.ZERO
var charge_direction = Vector2.ZERO
var original_y = 0.0
var core_hurtbox_base_x := 0.0
var damage_flash_tween: Tween = null
var has_summoned_fury_walkers = false

var room_left_limit = 0.0
var room_right_limit = 0.0
var room_top_limit = 0.0
var room_bottom_limit = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var projectile_spawn = $SpawnProyectil
@onready var core_hurtbox = $CoreHurtbox
@onready var core_hurtbox_shape = $CoreHurtbox/CollisionShape2D
@onready var attack_hitbox = $AttackHitbox
@onready var projectile_scene = preload("res://enemies/bosses/ice_guardian/ProyectilHielo.tscn")
@onready var shockwave_scene = preload("res://enemies/bosses/ice_guardian/OndaHielo.tscn")
@onready var caminante_helado_scene = preload("res://enemies/common/caminante_helado/CaminanteHelado.tscn")

func _ready():
	player = get_tree().get_first_node_in_group("player")
	charge_timer = CHARGE_COOLDOWN
	projectile_timer = PROJECTILE_COOLDOWN
	original_y = position.y
	core_hurtbox_base_x = abs(core_hurtbox_shape.position.x)
	if not core_hurtbox.is_in_group("boss_core"):
		core_hurtbox.add_to_group("boss_core")
	if not attack_hitbox.is_in_group("enemy_hitbox"):
		attack_hitbox.add_to_group("enemy_hitbox")
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false

func _physics_process(delta):
	if not is_active:
		return

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
	if not has_summoned_fury_walkers:
		has_summoned_fury_walkers = true
		current_state = State.IDLE
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false
		jump_velocity = Vector2.ZERO
		action_timer = FURY_CENTER_MOVE_TIME + FURY_SUMMON_PAUSE + FURY_SUMMON_STAGGER
		_start_fury_transition_async()

func _start_fury_transition_async():
	var target_center_x: float = _get_bossroom_center_x()
	var target_center_y: float = clamp(global_position.y, room_top_limit, room_bottom_limit)
	var target_pos: Vector2 = Vector2(target_center_x, target_center_y)
	var move_tween: Tween = create_tween()
	move_tween.tween_property(self, "global_position", target_pos, FURY_CENTER_MOVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await move_tween.finished
	_summon_fury_walkers_async()

func _get_bossroom_center_x() -> float:
	var boss_room = get_tree().get_first_node_in_group("boss_room")
	if boss_room and boss_room.has_node("Centro"):
		return float(boss_room.get_node("Centro").global_position.x)
	return (room_left_limit + room_right_limit) * 0.5

func _update_timers(delta):
	if charge_timer > 0:
		charge_timer -= delta
	if projectile_timer > 0:
		projectile_timer -= delta
	if current_phase == Phase.TWO and jump_timer > 0:
		jump_timer -= delta
	if post_jump_recover_timer > 0:
		post_jump_recover_timer -= delta

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
	if post_jump_recover_timer > 0:
		return

	action_timer -= delta

	# Moverse hacia el jugador pero parar a cierta distancia
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist > STOP_DISTANCE:
			var dir = (player.global_position - global_position).normalized()
			var speed = FLOAT_SPEED if current_phase == Phase.ONE else FLOAT_SPEED_P2
			position += dir * speed * delta

		position.y += sin(Time.get_ticks_msec() * 0.002) * FLOAT_AMPLITUDE * delta

		# Limites
		position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)
		position.y = clamp(position.y, room_top_limit, room_bottom_limit)

		_update_flip(player.global_position.x < global_position.x)

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
	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = true
	action_timer = 1.5
	charge_timer = CHARGE_COOLDOWN if current_phase == Phase.ONE else CHARGE_COOLDOWN_P2

	if player:
		charge_direction = (player.global_position - global_position).normalized()
		_update_flip(charge_direction.x < 0.0)
	else:
		charge_direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT

func _charge_state(delta):
	action_timer -= delta
	var speed = CHARGE_SPEED if current_phase == Phase.ONE else CHARGE_SPEED_P2
	position += charge_direction * speed * delta
	position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)
	position.y = clamp(position.y, room_top_limit, room_bottom_limit)

	if action_timer <= 0:
		charge_direction = Vector2.ZERO
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false
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

	var base_dir: Vector2 = (player.global_position - projectile_spawn.global_position).normalized()
	_spawn_projectile_with_direction(base_dir)

	if current_phase == Phase.TWO:
		var spread_angle := deg_to_rad(10.0)
		_spawn_projectile_with_direction(base_dir.rotated(spread_angle))

func _spawn_projectile_with_direction(dir: Vector2):
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = projectile_spawn.global_position
	projectile.init(dir)

func _start_jump():
	current_state = State.JUMP
	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = true
	jump_timer = JUMP_COOLDOWN
	action_timer = 1.5

	if player:
		var delta_x: float = player.global_position.x - global_position.x
		var normalized_x: float = clamp(delta_x / STOP_DISTANCE, -1.0, 1.0)
		var horizontal_speed: float = normalized_x * JUMP_SPEED
		if abs(delta_x) <= JUMP_HORIZONTAL_DEADZONE:
			horizontal_speed = 0.0
		if abs(horizontal_speed) > 0.1:
			_update_flip(horizontal_speed < 0.0)
		jump_velocity = Vector2(horizontal_speed, -400.0)

func _jump_state(delta):
	action_timer -= delta
	jump_velocity.y += 600.0 * delta
	position += jump_velocity * delta
	position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)

	# Detectar contacto con el suelo durante la caida
	if jump_velocity.y > 0.0:
		var space_state := get_world_2d().direct_space_state
		var check_start := Vector2(global_position.x, position.y)
		var check_finish := Vector2(global_position.x, position.y + 32.0)
		var query := PhysicsRayQueryParameters2D.create(check_start, check_finish)
		query.collide_with_areas = false
		query.exclude = [self]
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_y: float = float(hit.position.y)
			if hit_y >= room_bottom_limit - FLOOR_NEAR_BOTTOM_THRESHOLD:
				position.y = hit_y
				jump_velocity = Vector2.ZERO
				_land_shockwave(position.y)
				attack_hitbox.monitoring = false
				attack_hitbox.monitorable = false
				post_jump_recover_timer = POST_JUMP_RECOVER
				current_state = State.IDLE
				return

	# Fallback: si se agota el tiempo sin detectar suelo
	if action_timer <= 0:
		var landing_y := _resolve_landing_y()
		position.y = landing_y
		jump_velocity = Vector2.ZERO
		_land_shockwave(landing_y)
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false
		post_jump_recover_timer = POST_JUMP_RECOVER
		current_state = State.IDLE

func _resolve_landing_y() -> float:
	var space_state := get_world_2d().direct_space_state
	var start := Vector2(global_position.x, room_top_limit - FLOOR_RAY_MARGIN)
	var finish := Vector2(global_position.x, room_bottom_limit + FLOOR_RAY_MARGIN)
	var query := PhysicsRayQueryParameters2D.create(start, finish)
	query.collide_with_areas = false
	query.exclude = [self]
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_y: float = float(hit.position.y)
		if hit_y >= room_bottom_limit - FLOOR_NEAR_BOTTOM_THRESHOLD:
			return hit_y
	return room_bottom_limit

func _land_shockwave(ground_y: float):
	if not shockwave_scene:
		return

	# Onda hacia la izquierda
	var shockwave_left = shockwave_scene.instantiate()
	get_parent().add_child(shockwave_left)
	shockwave_left.global_position = Vector2(global_position.x, ground_y)
	shockwave_left.init(-1.0, ground_y, room_left_limit, room_right_limit)

	# Onda hacia la derecha
	var shockwave_right = shockwave_scene.instantiate()
	get_parent().add_child(shockwave_right)
	shockwave_right.global_position = Vector2(global_position.x, ground_y)
	shockwave_right.init(1.0, ground_y, room_left_limit, room_right_limit)

func _update_flip(flipped: bool):
	sprite.flip_h = flipped
	# Mantener la hurtbox del core alineada con la orientacion visual del boss.
	core_hurtbox_shape.position.x = -core_hurtbox_base_x if flipped else core_hurtbox_base_x

func activate():
	is_active = true
	charge_timer = CHARGE_COOLDOWN
	projectile_timer = PROJECTILE_COOLDOWN

func take_damage(amount: int):
	current_health -= amount
	_play_damage_flash()
	if current_health <= 0:
		die()

func _play_damage_flash():
	if not sprite:
		return
	if damage_flash_tween:
		damage_flash_tween.kill()
	damage_flash_tween = create_tween()
	sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
	damage_flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), DAMAGE_FLASH_TIME)

func _summon_fury_walkers_async():
	if not caminante_helado_scene:
		return
	var left_spawn_x: float = clamp(global_position.x - WALKER_SPAWN_OFFSET_X, room_left_limit + WALKER_SPAWN_MARGIN_X, room_right_limit - WALKER_SPAWN_MARGIN_X)
	var right_spawn_x: float = clamp(global_position.x + WALKER_SPAWN_OFFSET_X, room_left_limit + WALKER_SPAWN_MARGIN_X, room_right_limit - WALKER_SPAWN_MARGIN_X)
	await get_tree().process_frame
	_spawn_single_walker(left_spawn_x)
	await get_tree().process_frame
	await get_tree().create_timer(FURY_SUMMON_STAGGER).timeout
	_spawn_single_walker(right_spawn_x)

func _spawn_single_walker(spawn_x: float):
	var walker = caminante_helado_scene.instantiate()
	get_parent().add_child(walker)
	var ground_y: float = _resolve_ground_y_at_x(spawn_x)
	var feet_offset: float = _get_walker_feet_offset(walker)
	var spawn_y: float = ground_y - feet_offset - 4.0
	walker.global_position = Vector2(spawn_x, spawn_y)
	walker.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var summon_tween: Tween = create_tween()
	summon_tween.tween_property(walker, "modulate", Color(1.0, 1.0, 1.0, 1.0), SUMMON_POP_TIME)

func _get_walker_feet_offset(walker: Node) -> float:
	if not walker:
		return 0.0
	var shape_node := walker.get_node_or_null("CollisionShape2D")
	if not shape_node:
		return 0.0
	var local_offset_y: float = float(shape_node.position.y)
	var shape = shape_node.shape
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape
		return local_offset_y + (capsule.height * 0.5)
	if shape is RectangleShape2D:
		var rect: RectangleShape2D = shape
		return local_offset_y + (rect.size.y * 0.5)
	if shape is CircleShape2D:
		var circle: CircleShape2D = shape
		return local_offset_y + circle.radius
	return local_offset_y

func _resolve_ground_y_at_x(x: float) -> float:
	var space_state := get_world_2d().direct_space_state
	var start := Vector2(x, room_top_limit - FLOOR_RAY_MARGIN)
	var finish := Vector2(x, room_bottom_limit + FLOOR_RAY_MARGIN)
	var query := PhysicsRayQueryParameters2D.create(start, finish)
	query.collide_with_areas = false
	query.exclude = [self]
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_y: float = float(hit.position.y)
		if hit_y >= room_bottom_limit - FLOOR_NEAR_BOTTOM_THRESHOLD:
			return hit_y
	return room_bottom_limit

func die():
	current_state = State.DEAD
	var boss_room = get_tree().get_first_node_in_group("boss_room")
	if boss_room:
		boss_room.on_boss_defeated()
	queue_free()
