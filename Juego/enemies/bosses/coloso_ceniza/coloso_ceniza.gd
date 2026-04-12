extends Node2D

enum State { IDLE, HURT, DEAD, PUNCH }
enum Phase { ONE, TWO }

const MAX_HEALTH: int = 50
const PHASE_TWO_THRESHOLD: float = 0.35
const BOSS_HALF_WIDTH: float = 60.0

const MOVE_SPEED: float = 40.0
const TURN_DELAY_TIME: float = 0.5

const DAMAGE_FLASH_TIME: float = 0.08

const LEG_MAX_HEALTH: int = 7
const HURT_DURATION: float = 4.0
const LEG_REGEN_DELAY: float = 1.0

const PUNCH_RANGE: float = 80.0
const PUNCH_COOLDOWN: float = 5.0
const PUNCH_DURATION: float = 1.0
const PUNCH_WINDUP: float = 0.35
const PUNCH_KNOCKBACK: float = 600.0

const SPIKE_COOLDOWN: float = 9.5
const SPIKE_SHOCKWAVE_FORCE: float = 500.0

var leg_health: int = LEG_MAX_HEALTH
var hurt_timer: float = 0.0
var leg_regen_timer: float = 0.0
var is_vulnerable: bool = false

var current_health: int = MAX_HEALTH
var current_state: State = State.IDLE
var current_phase: Phase = Phase.ONE
var DAMAGE: int = 1
var player: Node2D = null
var is_active: bool = false
var spawn_position: Vector2 = Vector2.ZERO

var action_timer: float = 0.0
var move_direction: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO
var damage_flash_tween: Tween = null

var room_left_limit: float = 0.0
var room_right_limit: float = 0.0
var room_top_limit: float = 0.0
var room_bottom_limit: float = 0.0

var facing_left: bool = false
var turn_timer: float = 0.0
var pending_facing_left: bool = false
var turning: bool = false
var last_position_x: float = 0.0
var last_target_left: bool = false

var punch_timer: float = 0.0
var punch_state_timer: float = 0.0
var punch_hit_done: bool = false
var punch_damage: int = 2

var spike_timer: float = SPIKE_COOLDOWN

@onready var sprite = $AnimatedSprite2D
@onready var body_hitbox = $AttackHitbox
@onready var normal_hurtbox = $NormalHurtbox
@onready var core_hurtbox = $CoreHurtbox
@onready var pincho_scene = preload("res://enemies/bosses/coloso_ceniza/PinchosMagma.tscn")

func _ready():
	player = get_tree().get_first_node_in_group("player")
	spawn_position = global_position
	move_direction = Vector2.RIGHT
	last_position_x = global_position.x
	GameState.level_reset.connect(_on_level_reset)

	if player:
		var desired_left = player.global_position.x < global_position.x
		facing_left = desired_left
		last_target_left = desired_left
		scale.x = -1.0 if !facing_left else 1.0

	if not normal_hurtbox.is_in_group("boss_legs"):
		normal_hurtbox.add_to_group("boss_legs")
	if not core_hurtbox.is_in_group("boss_core"):
		core_hurtbox.add_to_group("boss_core")
	if not body_hitbox.is_in_group("boss_hitbox"):
		body_hitbox.add_to_group("boss_hitbox")
	
	if not body_hitbox.area_entered.is_connected(_on_attack_hitbox_area_entered):
		body_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	if not normal_hurtbox.area_entered.is_connected(_on_leg_hurtbox_area_entered):
		normal_hurtbox.area_entered.connect(_on_leg_hurtbox_area_entered)
	if not core_hurtbox.area_entered.is_connected(_on_core_hurtbox_area_entered):
		core_hurtbox.area_entered.connect(_on_core_hurtbox_area_entered)

	core_hurtbox.collision_layer = 0
	core_hurtbox.monitoring = false
	core_hurtbox.monitorable = false
	
	if not is_in_group("boss"):
		add_to_group("boss")

	body_hitbox.monitoring = true
	body_hitbox.monitorable = true

	core_hurtbox.monitoring = false
	core_hurtbox.monitorable = false


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

	if turning:
		turn_timer -= delta
		if turn_timer <= 0.0:
			facing_left = pending_facing_left
			scale.x = -1.0 if !facing_left else 1.0
			turning = false

	if current_state == State.HURT:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			_recover_from_hurt()

	if leg_regen_timer > 0.0:
		leg_regen_timer -= delta
		if leg_regen_timer <= 0.0:
			leg_health = LEG_MAX_HEALTH
	
	if punch_timer > 0.0:
		punch_timer -= delta
	
	if spike_timer > 0.0 and current_state != State.HURT:
		spike_timer -= delta

	_check_phase()
	_handle_state(delta)


func _check_phase():
	if current_phase == Phase.ONE and current_health <= MAX_HEALTH * PHASE_TWO_THRESHOLD:
		current_phase = Phase.TWO
		_enter_phase_two()


func _enter_phase_two():
	pass


func _handle_state(delta):
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.HURT:
			pass
		State.PUNCH:
			_punch_state(delta)


func _idle_state(delta):

	if not player:
		return

	var dist_x = player.global_position.x - global_position.x
	var desired_left = dist_x < 0

	if desired_left != last_target_left and not turning:
		last_target_left = desired_left
		_update_flip(desired_left)

	if turning:
		move_direction.x = 0
	else:
		move_direction.x = sign(dist_x)

	move_direction.y = 0
	position.x += move_direction.x * MOVE_SPEED * delta
	position.y = spawn_position.y
	position.x = clamp(position.x,
		room_left_limit + BOSS_HALF_WIDTH,
		room_right_limit - BOSS_HALF_WIDTH)
		
	if spike_timer <= 0.0:
		_start_spike_attack()
	
	var dist = global_position.distance_to(player.global_position)
	if dist <= PUNCH_RANGE and punch_timer <= 0.0:
		_enter_punch()


func _enter_hurt():
	current_state = State.HURT
	hurt_timer = HURT_DURATION
	is_vulnerable = false
	move_direction = Vector2.ZERO
	
	sprite.stop()
	sprite.animation = "hurt"
	sprite.frame = 0
	sprite.play("hurt")

	body_hitbox.set_deferred("monitoring", false)
	body_hitbox.set_deferred("monitorable", false)
	normal_hurtbox.set_deferred("monitoring", false)
	normal_hurtbox.set_deferred("monitorable", false)
	
	await get_tree().create_timer(0.3).timeout
	if current_state == State.HURT:
		is_vulnerable = true
		core_hurtbox.set_deferred("collision_layer", 32)
		core_hurtbox.set_deferred("monitoring", true)
		core_hurtbox.set_deferred("monitorable", true)


func _recover_from_hurt():
	current_state = State.IDLE
	is_vulnerable = false
	hurt_timer = 0.0
	$AnimatedSprite2D.play("wave")

	body_hitbox.set_deferred("monitoring", true)
	body_hitbox.set_deferred("monitorable", true)
	core_hurtbox.set_deferred("collision_layer", 0)
	core_hurtbox.set_deferred("monitoring", false)
	core_hurtbox.set_deferred("monitorable", false)
	normal_hurtbox.set_deferred("monitoring", true)
	normal_hurtbox.set_deferred("monitorable", true)

	leg_health = LEG_MAX_HEALTH
	_spawn_shockwave()
	
	await get_tree().create_timer(sprite.sprite_frames.get_frame_count("wave") / sprite.sprite_frames.get_animation_speed("wave")).timeout
	if current_state == State.IDLE:
		sprite.play("idle")


func _enter_punch():
	current_state = State.PUNCH
	punch_state_timer = PUNCH_DURATION
	punch_hit_done = false
	move_direction = Vector2.ZERO
	sprite.play("punch")

	body_hitbox.set_deferred("monitoring", false)
	body_hitbox.set_deferred("monitorable", false)


func _punch_state(delta):
	punch_state_timer -= delta

	if not punch_hit_done and punch_state_timer <= PUNCH_DURATION - PUNCH_WINDUP:
		punch_hit_done = true
		_do_punch()

	if punch_state_timer <= 0.0:
		punch_timer = PUNCH_COOLDOWN
		current_state = State.IDLE
		sprite.play("idle")
		body_hitbox.set_deferred("monitoring", true)
		body_hitbox.set_deferred("monitorable", true)


func _do_punch():
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > PUNCH_RANGE:
		return

	var push_x = sign(player.global_position.x - global_position.x)
	var facing_dir = -1 if facing_left else 1
	if push_x != facing_dir:
		return

	player.velocity = Vector2(push_x * PUNCH_KNOCKBACK * 0.3, -PUNCH_KNOCKBACK)

	var health_node = player.get_node_or_null("Health")
	if health_node and health_node.has_method("take_damage"):
		health_node.take_damage(2)


func _spawn_shockwave():
	var p = get_tree().get_first_node_in_group("player")
	if not p:
		return
	
	var dist = global_position.distance_to(p.global_position)
	if dist <= 130.0:
		var push_x = sign(p.global_position.x - global_position.x)
		p.velocity = Vector2(push_x * 600.0, -300.0)


func _start_spike_attack():
	spike_timer = SPIKE_COOLDOWN
	
	var p = get_tree().get_first_node_in_group("player")
	if not p:
		return
	
	var height_above_floor = room_bottom_limit - p.global_position.y
	if height_above_floor > 80.0:
		return
		
	var dist = global_position.distance_to(p.global_position)
	if dist > 150.0:
		return
	
	sprite.play("wave")
	var push_x = sign(p.global_position.x - global_position.x)
	p.velocity.x = push_x * SPIKE_SHOCKWAVE_FORCE
	
	await get_tree().create_timer(0.8).timeout
	
	if current_state == State.DEAD:
		return
	
	p = get_tree().get_first_node_in_group("player")
	if not p:
		return
		
	var direction = sign(p.global_position.x - global_position.x)
	var spike_width = 16
	var spawn_x = global_position.x
	
	while true:
		spawn_x += direction * spike_width
		spawn_x = clamp(spawn_x, room_left_limit + BOSS_HALF_WIDTH, room_right_limit - BOSS_HALF_WIDTH)
		_spawn_spike(spawn_x)
		await get_tree().create_timer(0.04).timeout
		if current_state == State.DEAD:
			return
		if direction > 0 and spawn_x >= room_right_limit - BOSS_HALF_WIDTH:
			break
		if direction < 0 and spawn_x <= room_left_limit + BOSS_HALF_WIDTH:
			break
	
	if current_state == State.IDLE:
		sprite.play("idle")


func _spawn_spike(spawn_x: float):
	var spike = pincho_scene.instantiate()
	get_parent().add_child(spike)
	spike.global_position = Vector2(spawn_x, room_bottom_limit - 8.0)


func _update_flip(should_face_left: bool):
	if turning:
		return
	pending_facing_left = should_face_left
	turn_timer = TURN_DELAY_TIME
	turning = true


func activate():
	_reset_for_encounter(true)
	sprite.play("idle")


func _on_level_reset() -> void:
	_reset_for_encounter(false)


func _reset_for_encounter(make_active: bool) -> void:
	if damage_flash_tween:
		damage_flash_tween.kill()
		damage_flash_tween = null

	global_position = spawn_position
	current_health = MAX_HEALTH
	leg_health = LEG_MAX_HEALTH
	current_state = State.IDLE
	current_phase = Phase.ONE
	action_timer = 0.0
	hurt_timer = 0.0
	leg_regen_timer = 0.0
	is_vulnerable = false
	move_direction = Vector2.ZERO
	target_direction = Vector2.ZERO
	punch_timer = 0.0
	punch_state_timer = 0.0
	punch_hit_done = false
	spike_timer = SPIKE_COOLDOWN

	body_hitbox.set_deferred("monitoring", true)
	body_hitbox.set_deferred("monitorable", true)
	core_hurtbox.set_deferred("monitoring", false)
	core_hurtbox.set_deferred("monitorable", false)
	normal_hurtbox.set_deferred("monitoring", true)
	normal_hurtbox.set_deferred("monitorable", true)

	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if player:
		var desired_left = player.global_position.x < global_position.x
		facing_left = desired_left
		last_target_left = desired_left
		scale.x = -1.0 if !facing_left else 1.0
	else:
		_update_flip(false)

	is_active = make_active
	
	sprite.play("idle")
	is_active = make_active


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


func _on_leg_hurtbox_area_entered(area: Area2D):
	if area == null:
		return
	if not area.is_in_group("player_hitbox"):
		return
	if current_state == State.HURT:
		return
	if leg_regen_timer > 0.0:
		return

	var player_node = get_tree().get_first_node_in_group("player")
	var multiplier = player_node.damage_multiplier if player_node else 1.0
	leg_health -= int(1 * multiplier)

	_play_damage_flash()

	if leg_health <= 0:
		leg_health = 0
		_enter_hurt()


func _on_core_hurtbox_area_entered(area: Area2D):
	if area == null:
		return
	if not area.is_in_group("player_hitbox"):
		return
	if current_state != State.HURT:
		return
	if not is_vulnerable:
		return
	is_vulnerable = false
	core_hurtbox.set_deferred("monitoring", false)
	var player_node = get_tree().get_first_node_in_group("player")
	var multiplier = player_node.damage_multiplier if player_node else 1.0
	take_damage(int(1 * multiplier))
	await get_tree().create_timer(0.5).timeout
	if current_state == State.HURT:
		is_vulnerable = true
		core_hurtbox.set_deferred("monitoring", true)
	
	
func is_hurting() -> bool:
	return current_state == State.HURT


func _on_attack_hitbox_area_entered(area: Area2D):
	if current_state == State.HURT:
		return


func die():
	current_state = State.DEAD
	var boss_room = get_tree().get_first_node_in_group("boss_room")
	if boss_room:
		boss_room.on_boss_defeated()
	queue_free()
