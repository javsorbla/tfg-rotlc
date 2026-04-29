extends Node2D

enum State { PATROL, PAUSE, DIVE, STUNNED, WEAK }
enum Phase { ONE, TWO }

const MAX_HEALTH = 50
const PHASE_TWO_THRESHOLD = 20

const BOSS_HALF_WIDTH = 40.0
const FLOAT_AMPLITUDE = 100.0
const FLOAT_SPEED = 160.0
const FLOAT_SPEED_P2 = 200.0
const SIDE_PAUSE_DURATION = 1.5

const DAMAGE_FLASH_TIME = 0.08

const DIVE_DETECT_RANGE = 500.0
const DIVE_SPEED = 420.0
const DIVE_GRAVITY = 300.0
const DIVE_WINDUP_TIME = 0.5
const DIVE_SLIDE_TIME = 0.4
const DIVE_SLIDE_SPEED = 200.0
const DIVE_COOLDOWN = 10.0
const RETURN_SPEED = 250.0

const WING_MAX_HEALTH: int = 7
const WING_REGEN_DELAY: float = 1.0
const WEAK_DURATION = 5.0
const WEAK_WALK_SPEED: float = 120.0

const STUN_DURATION: float = 13.0
const STUN_FALL_SPEED: float = 220.0

const RAY_COOLDOWN = 15.0
const RAY_WINDUP_TIME = 1.0
const RAY_DURATION = 1.5

const HURRICANE_COOLDOWN: float = 20.0
const HURRICANE_WARNING_TIME: float = 0.8
const HURRICANE_DAMAGE: int = 2
const HURRICANE_DURATION = 6.5

const STORM_COOLDOWN: float = 15.0
const STORM_COUNT: int = 5
const STORM_INTERVAL: float = 0.5

const HIT_COOLDOWN: float = 0.1

var current_health = MAX_HEALTH
var current_phase = Phase.ONE
var current_state = State.PATROL
var patrol_direction = 1.0
var is_active = false
var spawn_position = Vector2.ZERO
var pause_timer = 0.0
var DAMAGE = 1
var damage_flash_tween: Tween = null

var damage_this_frame_wing1 = false
var damage_this_frame_wing2 = false
var damage_this_frame_core = false

var wing_health: int = WING_MAX_HEALTH
var wing_regen_timer: float = 0.0
var is_weak = false
var weak_timer = 0.0
var last_direction := 1.0

var dive_cooldown_timer = 0.0
var dive_velocity = Vector2.ZERO
var dive_gravity_accum = 0.0
var dive_sliding = false
var dive_winding_up = false
var windup_timer = 0.0
var slide_timer = 0.0

var is_stunned: bool = false
var stun_timer: float = 0.0
var stun_falling: bool = false

var ray_cooldown_timer = 0.0
var ray_winding_up = false
var ray_windup_timer = 0.0
var ray_duration_timer = 0.0
var ray_instance = null
var ray_target = Vector2.ZERO
var ray_end = Vector2.ZERO

var hurricane_timer: float = HURRICANE_COOLDOWN
var hurricane_active = false
var hurricane_duration_timer = 0.0

var storm_timer: float = STORM_COOLDOWN
var storm_active: bool = false
var storm_interval_timer: float = 0.0
var storm_count: int = 0

var returning = false
var original_y: float = 0.0

var room_left_limit = 0.0
var room_right_limit = 0.0
var room_top_limit = 0.0
var room_bottom_limit = 0.0

var player = null
var shapes = []
var original_pos_x = []
var original_rot = []

var hit_cooldown: float = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var wing_hurtbox_1 = $WingHurtbox1
@onready var wing_patrol_1 = $WingHurtbox1/PatrolShape
@onready var wing_dive_1 = $WingHurtbox1/DiveShape
@onready var wing_hurtbox_2 = $WingHurtbox2
@onready var wing_patrol_2 = $WingHurtbox2/PatrolShape
@onready var wing_dive_2 = $WingHurtbox2/DiveShape
@onready var body_hitbox = $AttackHitbox
@onready var body_patrol = $AttackHitbox/PatrolShape
@onready var body_dive = $AttackHitbox/DiveShape
@onready var core_hurtbox = $CoreHurtbox
@onready var core_patrol = $CoreHurtbox/PatrolShape
@onready var core_dive = $CoreHurtbox/DiveShape

@onready var ray_spawn = $SpawnRayo
@onready var ray_scene = preload("res://enemies/bosses/tempestad_dorada/Rayo.tscn")
@onready var hurricane_scene = preload("res://enemies/bosses/tempestad_dorada/Huracan.tscn")
@onready var storm_scene = preload("res://enemies/bosses/tempestad_dorada/Tormenta.tscn")

func _set_dive_shapes(diving: bool):
	body_patrol.set_deferred("disabled", diving)
	body_dive.set_deferred("disabled", not diving)
	core_patrol.set_deferred("disabled", diving)
	core_dive.set_deferred("disabled", not diving)
	wing_patrol_1.set_deferred("disabled", diving)
	wing_dive_1.set_deferred("disabled", not diving)
	wing_patrol_2.set_deferred("disabled", diving)
	wing_dive_2.set_deferred("disabled", not diving)

func _ready():
	shapes = [body_patrol, body_dive, core_patrol, core_dive, 
			  wing_patrol_1, wing_dive_1, wing_patrol_2, wing_dive_2]
	for shape in shapes:
		original_pos_x.append(shape.position.x)
		original_rot.append(shape.rotation)
	spawn_position = global_position
	original_y = global_position.y
	player = get_tree().get_first_node_in_group("player")
	GameState.level_reset.connect(_on_level_reset)
	
	if not is_in_group("boss"):
		add_to_group("boss")
	if not wing_hurtbox_1.is_in_group("boss_hurtbox"):
		wing_hurtbox_1.add_to_group("boss_hurtbox")
	if not wing_hurtbox_2.is_in_group("boss_hurtbox"):
		wing_hurtbox_2.add_to_group("boss_hurtbox")
	if not body_hitbox.is_in_group("enemy_hitbox"):
		body_hitbox.add_to_group("enemy_hitbox")
		
	wing_hurtbox_1.area_entered.connect(_on_wing1_area_entered)
	wing_hurtbox_2.area_entered.connect(_on_wing2_area_entered)
	
	_set_dive_shapes(false)

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

	if dive_cooldown_timer > 0.0:
		dive_cooldown_timer -= delta
		
	if ray_cooldown_timer > 0.0:
		ray_cooldown_timer -= delta
		
	if hurricane_timer > 0.0:
		hurricane_timer -= delta
	
	if storm_timer <= 0.0 and player != null and not storm_active:
		storm_active = true
		storm_count = 0
		storm_interval_timer = 0.0
		storm_timer = STORM_COOLDOWN
	
	elif storm_timer > 0.0:
		storm_timer -= delta

	if storm_active:
		storm_interval_timer -= delta
		if storm_interval_timer <= 0.0:
			storm_interval_timer = STORM_INTERVAL
			var storm = storm_scene.instantiate()
			get_parent().add_child(storm)
			var random_x = player.global_position.x + randf_range(-200.0, 200.0)
			random_x = clamp(random_x, room_left_limit, room_right_limit)
			var random_y = randf_range(room_top_limit, room_bottom_limit - 250.0)
			storm.global_position = Vector2(random_x, random_y)
			storm_count += 1
			if storm_count >= STORM_COUNT:
				storm_active = false
				
	if wing_regen_timer > 0.0:
		wing_regen_timer -= delta
		if wing_regen_timer <= 0.0:
			wing_health = WING_MAX_HEALTH
	
	if hit_cooldown > 0.0:
		hit_cooldown -= delta
	
	
	damage_this_frame_wing1 = false
	damage_this_frame_wing2 = false
	_check_phase()
	_handle_state(delta)


func _check_phase():
	if current_phase == Phase.ONE and current_health <= PHASE_TWO_THRESHOLD:
		current_phase = Phase.TWO

func _handle_state(delta):
	match current_state:
		State.PATROL: 
			_patrol_state(delta)
		State.PAUSE:  
			_pause_state(delta)
		State.DIVE:   
			_dive_state(delta)
		State.STUNNED:
			_stunned_state(delta)
		State.WEAK:
			_weak_state(delta)

func _patrol_state(delta):
	if returning:
		position.y = move_toward(position.y, original_y, RETURN_SPEED * delta)
		if abs(position.y - original_y) < 2.0:
			position.y = original_y
			returning = false

	var speed = FLOAT_SPEED if current_phase == Phase.ONE else FLOAT_SPEED_P2
	position.x += patrol_direction * speed * delta
	position.y += sin(Time.get_ticks_msec() * 0.002) * FLOAT_AMPLITUDE * delta
	position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)
	position.y = clamp(position.y, room_top_limit, room_bottom_limit)
	_update_flip(patrol_direction > 0.0)

	if _can_dive():
		_start_dive()
		return

	var at_wall = (patrol_direction > 0.0 and position.x >= room_right_limit - BOSS_HALF_WIDTH) \
			   or (patrol_direction < 0.0 and position.x <= room_left_limit + BOSS_HALF_WIDTH)
	if at_wall:
		patrol_direction *= -1.0
		_update_flip(patrol_direction > 0.0)
		pause_timer = SIDE_PAUSE_DURATION
		current_state = State.PAUSE

func _pause_state(delta):
	pause_timer -= delta

	if ray_winding_up:
		position.y += sin(Time.get_ticks_msec() * 0.002) * FLOAT_AMPLITUDE * delta
		position.y = clamp(position.y, room_top_limit, room_bottom_limit)
		ray_windup_timer -= delta
		if ray_windup_timer <= 0.0:
			ray_winding_up = false
			_shoot_ray()
		return

	if ray_instance:
		ray_duration_timer -= delta
		_update_ray()
		if ray_duration_timer <= 0.0:
			ray_instance.queue_free()
			ray_instance = null
			sprite.play("idle")
			current_state = State.PATROL
		return
		
	if hurricane_active:
		hurricane_duration_timer -= delta
		# Solo se mueve arriba y abajo mientras dura el huracan
		position.y += sin(Time.get_ticks_msec() * 0.002) * FLOAT_AMPLITUDE * delta
		position.y = clamp(position.y, room_top_limit, room_bottom_limit)
		if hurricane_duration_timer <= 0.0:
			hurricane_active = false
			sprite.play("idle")
			current_state = State.PATROL
		return

	position.y += sin(Time.get_ticks_msec() * 0.002) * FLOAT_AMPLITUDE * delta
	position.y = clamp(position.y, room_top_limit, room_bottom_limit)

	if pause_timer <= 0.0:
		# Huracan solo en fase 2
		if hurricane_timer <= 0.0 and current_phase == Phase.TWO:
			hurricane_active = true
			hurricane_duration_timer = HURRICANE_DURATION
			hurricane_timer = HURRICANE_COOLDOWN
			_start_hurricane()
		elif ray_cooldown_timer <= 0.0:
			ray_end = player.global_position
			ray_winding_up = true
			ray_windup_timer = RAY_WINDUP_TIME
			ray_cooldown_timer = RAY_COOLDOWN
			sprite.play("charging")
		else:
			current_state = State.PATROL

func _dive_state(delta):
	if dive_winding_up:
		position.y += sin(Time.get_ticks_msec() * 0.002) * FLOAT_AMPLITUDE * delta
		position.y = clamp(position.y, room_top_limit, room_bottom_limit)
		windup_timer -= delta
		if windup_timer <= 0.0:
			dive_winding_up = false
			var dir = (player.global_position - global_position).normalized()
			dir.y = max(dir.y, 0.1)
			dive_velocity = dir.normalized() * DIVE_SPEED
			_update_flip(dive_velocity.x > 0.0)
			body_hitbox.monitoring = true
			body_hitbox.monitorable = true
			DAMAGE = 2
		return

	if dive_sliding:
		var slide_dir = -1.0 if not sprite.flip_h else 1.0
		position.x += slide_dir * DIVE_SLIDE_SPEED * delta
		position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)
		slide_timer -= delta
		if slide_timer <= 0.0:
			dive_sliding = false
			dive_velocity = Vector2.ZERO
			body_hitbox.monitoring = true
			body_hitbox.monitorable = true
			DAMAGE = 1
			returning = true
			sprite.play("idle")
			_set_dive_shapes(false)
			current_state = State.PATROL
		return

	position += dive_velocity * delta
	position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)

	if position.y > room_bottom_limit - 40.0 or position.x <= room_left_limit + BOSS_HALF_WIDTH or position.x >= room_right_limit - BOSS_HALF_WIDTH:
		position.y = clamp(position.y, room_top_limit, room_bottom_limit)
		dive_sliding = true
		slide_timer = DIVE_SLIDE_TIME
		

func _can_dive() -> bool:
	if dive_cooldown_timer > 0.0 or player == null:
		return false
	if player.global_position.y < global_position.y + 40.0:
		return false
	if global_position.distance_to(player.global_position) > DIVE_DETECT_RANGE:
		return false
		
	# Solo ataca si el jugador está en el lado al que mira
	var player_is_right = player.global_position.x < global_position.x
	var facing_right = not sprite.flip_h
	if player_is_right != facing_right:
		return false
	return true

func _start_dive():

	current_state = State.DIVE
	dive_winding_up = true
	windup_timer = DIVE_WINDUP_TIME
	dive_cooldown_timer = DIVE_COOLDOWN
	_update_flip((player.global_position - global_position).normalized().x > 0.0)
	sprite.play("attack")
	_set_dive_shapes(true)

func _shoot_ray():
	if not player:
		return
	ray_instance = ray_scene.instantiate()
	ray_instance.active = true
	get_parent().add_child(ray_instance)
	ray_instance.scale = Vector2.ONE

	var inicio = ray_instance.get_node_or_null("Inicio")
	if inicio:
		inicio.visible = false
		if inicio.sprite_frames:
			var tex = inicio.sprite_frames.get_frame_texture("default", 0)
			if tex:
				inicio.offset.x = tex.get_width() / 2.0

	ray_duration_timer = RAY_DURATION
	_update_ray()

func _update_ray():
	if not ray_instance or not player:
		return

	var start = ray_spawn.global_position
	var end = ray_end
	var diff = end - start
	var angle = diff.angle()

	ray_instance.global_position = Vector2.ZERO
	ray_instance.rotation = 0.0

	for child in ray_instance.get_children():
		if child.name.begins_with("RayTile"):
			child.free()

	var inicio = ray_instance.get_node_or_null("Inicio")
	if not inicio or not inicio.sprite_frames:
		return
	var tex = inicio.sprite_frames.get_frame_texture("default", 0)
	if not tex:
		return
	var tile_width = float(tex.get_width())

	var distance = diff.length()
	var num_tiles = int(ceil(distance / tile_width)) + 7

	for i in range(num_tiles):
		var tile = AnimatedSprite2D.new()
		tile.name = "RayTile" + str(i)
		tile.sprite_frames = inicio.sprite_frames
		tile.animation = "default"
		tile.play("default")
		tile.offset = inicio.offset
		tile.scale = Vector2(1.0, 0.8)
		tile.global_position = start + diff.normalized() * (tile_width * i + tile_width * 0.2)
		tile.rotation = angle
		ray_instance.add_child(tile)
	
	if ray_instance.has_method("update_hitbox"):
		ray_instance.update_hitbox(ray_spawn.global_position, ray_end)

func _start_hurricane():
	var p = get_tree().get_first_node_in_group("player")
	if not p:
		return
	if global_position.distance_to(p.global_position) > 900.0:
		return
	_spawn_hurricane(Vector2(p.global_position.x, room_bottom_limit - 8.0))

func _spawn_hurricane(pos: Vector2):
	var hurricane = hurricane_scene.instantiate()
	get_parent().add_child(hurricane)
	hurricane.global_position = pos
	hurricane.room_bottom_limit = room_bottom_limit
	hurricane.room_left_limit = room_left_limit
	hurricane.room_right_limit = room_right_limit

func _stunned_state(delta):
	if stun_falling:
		position.y += STUN_FALL_SPEED * delta
		if position.y >= room_bottom_limit - 40.0:
			position.y = room_bottom_limit - 40.0
			stun_falling = false
			stun_timer = STUN_DURATION
		return

	stun_timer -= delta
	if stun_timer <= 0.0 and current_state == State.STUNNED:
		is_stunned = false
		returning = true
		DAMAGE = 1
		sprite.play("idle")
		
		body_hitbox.set_deferred("monitoring", true)
		body_hitbox.set_deferred("monitorable", true)
		
		current_state = State.PATROL

func _enter_stun():
	current_state = State.STUNNED
	is_stunned = true
	stun_falling = true
	stun_timer = STUN_DURATION
	dive_sliding = false
	dive_velocity = Vector2.ZERO
	dive_winding_up = false
	DAMAGE = 0
	sprite.play("stun")
	
	body_hitbox.set_deferred("monitoring", false)
	body_hitbox.set_deferred("monitorable", false)
	
	body_patrol.set_deferred("disabled", false)
	body_dive.set_deferred("disabled", true)
	core_patrol.set_deferred("disabled", false)
	core_dive.set_deferred("disabled", true)
	wing_patrol_1.set_deferred("disabled", false)
	wing_dive_1.set_deferred("disabled", true)
	wing_patrol_2.set_deferred("disabled", false)
	wing_dive_2.set_deferred("disabled", true)

func _weak_state(delta):
	if position.y < room_bottom_limit - 40.0:
		position.y = move_toward(position.y, room_bottom_limit - 40.0, STUN_FALL_SPEED * delta)
		return

	weak_timer -= delta

	if player:
		var diff = player.global_position.x - position.x

		if abs(diff) > 20.0:
			var new_dir = sign(diff)
			if new_dir != last_direction:
				last_direction = new_dir

		position.x += last_direction * WEAK_WALK_SPEED * delta
		position.x = clamp(position.x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)

		_update_flip(last_direction > 0.0)

	if weak_timer <= 0.0:
		is_weak = false
		wing_health = WING_MAX_HEALTH
		returning = true
		current_state = State.PATROL
		sprite.play("idle")


func _enter_weak():
	current_state = State.WEAK
	is_weak = true
	weak_timer = WEAK_DURATION
	
	# Cancelar estados activos
	is_stunned = false
	stun_falling = false
	dive_sliding = false
	dive_velocity = Vector2.ZERO
	dive_winding_up = false
	
	ray_winding_up = false
	ray_windup_timer = 0.0
	if ray_instance:
		ray_instance.queue_free()
		ray_instance = null
	ray_duration_timer = 0.0

	hurricane_active = false
	hurricane_duration_timer = 0.0
	for node in get_tree().get_nodes_in_group("hurricane"):
		node.queue_free()
	
	body_hitbox.monitoring = false
	_set_dive_shapes(false)
	sprite.play("idle")


func _update_flip(flipped: bool):
	sprite.flip_h = flipped
	if ray_spawn:
		ray_spawn.position.x = -abs(ray_spawn.position.x) if flipped else abs(ray_spawn.position.x)
	var sign_x = -1.0 if flipped else 1.0
	for i in shapes.size():
		shapes[i].position.x = original_pos_x[i] * sign_x
		shapes[i].rotation = -original_rot[i] if flipped else original_rot[i]
		
func activate():
	_reset_for_encounter(true)

func _on_level_reset() -> void:
	_reset_for_encounter(false)

func _reset_for_encounter(make_active: bool) -> void:
	if damage_flash_tween:
		damage_flash_tween.kill()
		damage_flash_tween = null

	global_position = spawn_position
	current_health = MAX_HEALTH
	current_phase = Phase.ONE
	current_state = State.PATROL
	_set_dive_shapes(false)
	patrol_direction = 1.0
	pause_timer = 0.0
	dive_cooldown_timer = 0.0
	dive_velocity = Vector2.ZERO
	dive_winding_up = false
	windup_timer = 0.0
	dive_sliding = false
	slide_timer = 0.0
	returning = false
	ray_cooldown_timer = 0.0
	ray_winding_up = false
	ray_windup_timer = 0.0
	if ray_instance:
		ray_instance.queue_free()
		ray_instance = null
	ray_duration_timer = 0.0
	hurricane_active = false
	hurricane_duration_timer = 0.0
	hurricane_timer = HURRICANE_COOLDOWN
	for node in get_tree().get_nodes_in_group("hurricane"):
		node.queue_free()
	storm_timer = STORM_COOLDOWN
	storm_active = false
	storm_count = 0
	storm_interval_timer = 0.0
	for node in get_tree().get_nodes_in_group("storm"):
		node.queue_free()
	is_stunned = false
	stun_timer = 0.0
	stun_falling = false
	wing_health = WING_MAX_HEALTH
	wing_regen_timer = 0.0
	is_weak = false
	weak_timer = 0.0
	DAMAGE = 1
	body_hitbox.set_deferred("monitoring", true)
	body_hitbox.set_deferred("monitorable", true)
	room_right_limit = 0.0

	_update_flip(false)
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if sprite:
		sprite.play("idle")
	is_active = make_active
	
	
func _on_wing1_area_entered(area: Area2D):
	if not area.is_in_group("player_hitbox"):
		return
	if damage_this_frame_wing1:
		return
	damage_this_frame_wing1 = true
	_handle_wing_hit(area)

func _on_wing2_area_entered(area: Area2D):
	if not area.is_in_group("player_hitbox"):
		return
	if damage_this_frame_wing2:
		return
	damage_this_frame_wing2 = true
	_handle_wing_hit(area)

func _handle_wing_hit(area: Area2D):
	if is_weak:
		return

	var player_node = get_tree().get_first_node_in_group("player")
	var multiplier = player_node.damage_multiplier if player_node else 1.0

	var hits = 2 if multiplier > 1.0 else 1
	wing_health -= hits
	_play_damage_flash()

	if wing_health <= 0:
		wing_health = 0
		_enter_weak()
		return

	if current_state == State.DIVE and not dive_winding_up and not is_stunned:
		_enter_stun()

func _on_core_hit(area: Area2D):
	if not area.is_in_group("player_hitbox"):
		return
	if hit_cooldown > 0.0:
		return

	hit_cooldown = HIT_COOLDOWN
	call_deferred("_apply_core_damage")

func _reenable_core_hurtbox():
	core_hurtbox.monitoring = true
	damage_this_frame_core = false


func take_damage(amount: int):
	if hit_cooldown > 0.0:
		return

	hit_cooldown = HIT_COOLDOWN

	if current_state==State.WEAK:
		amount *= 2
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

func is_hurting() -> bool:
	return false

func die():
	current_state = State.PATROL
	var boss_room = get_tree().get_first_node_in_group("boss_room")
	if boss_room:
		boss_room.on_boss_defeated()
	queue_free()
