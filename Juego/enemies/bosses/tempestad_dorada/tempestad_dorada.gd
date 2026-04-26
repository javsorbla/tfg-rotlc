extends Node2D

enum State { PATROL, PAUSE, DIVE }

const MAX_HEALTH = 50
const BOSS_HALF_WIDTH = 40.0
const FLOAT_AMPLITUDE = 100.0
const FLOAT_SPEED = 160.0
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

const RAY_COOLDOWN = 15.0
const RAY_WINDUP_TIME = 1.0
const RAY_DURATION = 1.5

const HURRICANE_COOLDOWN: float = 14.0
const HURRICANE_WARNING_TIME: float = 0.8
const HURRICANE_DAMAGE: int = 2
const HURRICANE_DURATION = 6.5

var current_health = MAX_HEALTH
var current_state = State.PATROL
var patrol_direction = 1.0
var is_active = false
var spawn_position = Vector2.ZERO
var pause_timer = 0.0
var DAMAGE = 1
var damage_flash_tween: Tween = null

var dive_cooldown_timer = 0.0
var dive_velocity = Vector2.ZERO
var dive_gravity_accum = 0.0
var dive_sliding = false
var dive_winding_up = false
var windup_timer = 0.0
var slide_timer = 0.0

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

var returning = false
var original_y: float = 0.0

var room_left_limit = 0.0
var room_right_limit = 0.0
var room_top_limit = 0.0
var room_bottom_limit = 0.0

var player = null

@onready var sprite = $AnimatedSprite2D
@onready var core_hurtbox_1 = $CoreHurtbox1
@onready var core_hurtbox_2 = $CoreHurtbox2
@onready var attack_hitbox = $AttackHitbox
@onready var normal_hurtbox = $NormalHurtbox

@onready var ray_spawn = $SpawnRayo
@onready var ray_scene = preload("res://enemies/bosses/tempestad_dorada/Rayo.tscn")
@onready var hurricane_scene = preload("res://enemies/bosses/tempestad_dorada/Huracan.tscn")


func _ready():
	spawn_position = global_position
	original_y = global_position.y
	player = get_tree().get_first_node_in_group("player")
	GameState.level_reset.connect(_on_level_reset)
	
	if not is_in_group("boss"):
		add_to_group("boss")
	if not core_hurtbox_1.is_in_group("boss_core"):
		core_hurtbox_1.add_to_group("boss_core")
	if not core_hurtbox_2.is_in_group("boss_core"):
		core_hurtbox_2.add_to_group("boss_core")
	if not attack_hitbox.is_in_group("enemy_hitbox"):
		attack_hitbox.add_to_group("enemy_hitbox")
		
	normal_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
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

	if dive_cooldown_timer > 0.0:
		dive_cooldown_timer -= delta
		
	if ray_cooldown_timer > 0.0:
		ray_cooldown_timer -= delta
		
	if hurricane_timer > 0.0:
		hurricane_timer -= delta

	_handle_state(delta)

func _handle_state(delta):
	match current_state:
		State.PATROL: 
			_patrol_state(delta)
		State.PAUSE:  
			_pause_state(delta)
		State.DIVE:   
			_dive_state(delta)

func _patrol_state(delta):
	if returning:
		position.y = move_toward(position.y, original_y, RETURN_SPEED * delta)
		if abs(position.y - original_y) < 2.0:
			position.y = original_y
			returning = false

	position.x += patrol_direction * FLOAT_SPEED * delta
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
		if hurricane_timer <= 0.0:
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
			attack_hitbox.monitoring = true
			attack_hitbox.monitorable = true
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
			attack_hitbox.monitoring = false
			attack_hitbox.monitorable = false
			DAMAGE = 1
			returning = true
			sprite.play("idle")
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

func _shoot_ray():
	if not player:
		return
	ray_instance = ray_scene.instantiate()
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

func _update_flip(flipped: bool):
	sprite.flip_h = flipped
	if ray_spawn:
		ray_spawn.position.x = -abs(ray_spawn.position.x) if flipped else abs(ray_spawn.position.x)
		
func activate():
	_reset_for_encounter(true)

func _on_level_reset() -> void:
	_reset_for_encounter(false)

func _reset_for_encounter(make_active: bool) -> void:
	global_position = spawn_position
	current_state = State.PATROL
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
	DAMAGE = 1
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)
	room_right_limit = 0.0
	
	_update_flip(false)
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if sprite:
		sprite.play("idle")
	is_active = make_active
	
func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var player_node = get_tree().get_first_node_in_group("player")
		var multiplier = player_node.damage_multiplier if player_node else 1.0
		take_damage(int(1 * multiplier))

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

func die():
	current_state = State.PATROL
	var boss_room = get_tree().get_first_node_in_group("boss_room")
	if boss_room:
		boss_room.on_boss_defeated()
	queue_free()
