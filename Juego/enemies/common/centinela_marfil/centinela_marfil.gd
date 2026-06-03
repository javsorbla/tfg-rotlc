extends CharacterBody2D

const MAX_HEALTH: int = 4
const DAMAGE: int = 1

const STUN_DURATION: float  = 0.8
const DETECT_DISTANCE: float = 200.0
const LOSE_DISTANCE: float = 250.0
const PATROL_SPEED: float = 50.0
const CHASE_SPEED_SHIELD: float = 70.0
const CHASE_SPEED_NO_SHIELD: float = 95.0
const GRAVITY: float = 700.0 
const PATROL_X_RANGE: float = 150.0
const EDGE_CHECK_DISTANCE: float = 15.0
const TURN_DELAY: float = 1.0
const KNOCKBACK_PLAYER: float = 250.0
const REVIVE_DURATION: float = 6.0

const BREAK_SHEET_4 := preload("res://assets/enemies/common/centinela_marfil/break_sheet_4.png")
const DAMAGED_SHEET_4 := preload("res://assets/enemies/common/centinela_marfil/damaged_sheet_4.png")
const DAMAGED_IDLE_SHEET_4 := preload("res://assets/enemies/common/centinela_marfil/damaged_idle_sheet_4.png")
const DAMAGED_STUN_SHEET_4 := preload("res://assets/enemies/common/centinela_marfil/damaged_stun_sheet_4.png")
const FAINTED_SHEET_4 := preload("res://assets/enemies/common/centinela_marfil/fainted_sheet_4.png")
const REVIVE_SHEET_4 := preload("res://assets/enemies/common/centinela_marfil/revive_sheet_4.png")
const SHIELD_SHEET_4 := preload("res://assets/enemies/common/centinela_marfil/shield_sheet_4.png")
const SHIELD_IDLE_SHEET_4 := preload("res://assets/enemies/common/centinela_marfil/shield_idle_sheet_4.png")
const SHIELD_STUN_SHEET_4 := preload("res://assets/enemies/common/centinela_marfil/shield_stun_sheet_4.png")

enum State { PATROL, ATTACK, STUNNED, FAINTED }

var current_state: State = State.PATROL
var current_health: int = MAX_HEALTH
var shield_active: bool = true
var player: Node2D = null

var stun_timer: float = 0.0
var turn_timer: float = 0.0
var is_facing_right: bool = true
var revive_timer: float = 0.0
var current_speed: float = CHASE_SPEED_SHIELD

var patrol_dir: float = 1.0
var patrol_origin: Vector2 = Vector2.ZERO
var hit_wall: bool = false
var breaking_shield: bool = false
var spawn_position = Vector2.ZERO

var _base_sprite_frames: SpriteFrames = null
var _level4_sprite_frames: SpriteFrames = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	spawn_position = global_position
	GameState.level_reset.connect(_on_level_reset)

	_base_sprite_frames = sprite.sprite_frames
	call_deferred("_apply_level_visuals")

	if not $EnemyHitbox.area_entered.is_connected(_on_enemy_hitbox_area_entered):
		$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)
	if not $EnemyHurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
		$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)

	_enter_state(State.PATROL)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	match current_state:
		State.PATROL:
			_state_patrol()
		State.ATTACK:
			_state_attack(delta)
		State.STUNNED:
			_state_stunned(delta)
		State.FAINTED:
			_state_fainted(delta)

	$AnimatedSprite2D.flip_h = is_facing_right
	move_and_slide()

func _on_level_reset():
	current_health = MAX_HEALTH
	global_position = spawn_position
	current_state = State.PATROL
	velocity = Vector2.ZERO
	visible = true
	$EnemyHurtbox.monitorable = true
	call_deferred("_apply_level_visuals")

func _apply_level_visuals() -> void:
	if sprite == null or _base_sprite_frames == null:
		return

	var target_frames: SpriteFrames = _base_sprite_frames
	if GameState.current_level == 4:
		target_frames = _get_level4_sprite_frames()

	if sprite.sprite_frames != target_frames:
		sprite.sprite_frames = target_frames

	var current_animation := sprite.animation
	if current_animation != "" and sprite.sprite_frames.has_animation(current_animation):
		sprite.play(current_animation)
	
func _get_level4_sprite_frames() -> SpriteFrames:
	if _level4_sprite_frames != null:
		return _level4_sprite_frames

	var frames := _base_sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return _base_sprite_frames

	_replace_animation_frames(frames, "break_shield", BREAK_SHEET_4)
	_replace_animation_frames(frames, "damaged", DAMAGED_SHEET_4)
	_replace_animation_frames(frames, "damaged_idle", DAMAGED_IDLE_SHEET_4)
	_replace_animation_frames(frames, "damaged_stun", DAMAGED_STUN_SHEET_4)
	_replace_animation_frames(frames, "fainted", FAINTED_SHEET_4)
	_replace_animation_frames(frames, "revive", REVIVE_SHEET_4)
	_replace_animation_frames(frames, "shield", SHIELD_SHEET_4)
	_replace_animation_frames(frames, "shield_idle", SHIELD_IDLE_SHEET_4)
	_replace_animation_frames(frames, "shield_stun", SHIELD_STUN_SHEET_4)

	_level4_sprite_frames = frames
	return _level4_sprite_frames

func _replace_animation_frames(frames: SpriteFrames, animation_name: StringName, source_texture: Texture2D) -> void:
	if frames == null or source_texture == null or not frames.has_animation(animation_name):
		return

	var frame_count := frames.get_frame_count(animation_name)
	for frame_index in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = source_texture
		atlas.region = Rect2(frame_index * 64, 0, 64, 64)
		var frame_duration := _base_sprite_frames.get_frame_duration(animation_name, frame_index)
		frames.set_frame(animation_name, frame_index, atlas, frame_duration)

func _enter_state(new_state: State) -> void:
	current_state = new_state

	match new_state:
		State.PATROL:
			velocity = Vector2.ZERO
			$EnemyHitbox.add_to_group("enemy_hitbox")
			if $AnimatedSprite2D.animation != "break_shield":
				$AnimatedSprite2D.play("shield" if shield_active else "damaged")

		State.ATTACK:
			turn_timer = 0.0
			$EnemyHitbox.add_to_group("enemy_hitbox")
			if hit_wall:
				$AnimatedSprite2D.play("shield_idle" if shield_active else "damaged_idle")
				hit_wall = false
			if player:
				is_facing_right = player.global_position.x > global_position.x
			current_speed = CHASE_SPEED_SHIELD if shield_active else CHASE_SPEED_NO_SHIELD
			velocity.x = current_speed * (1 if is_facing_right else -1)
			if $AnimatedSprite2D.animation != "break_shield":
				$AnimatedSprite2D.play("shield" if shield_active else "damaged")

		State.STUNNED:
			velocity = Vector2.ZERO
			$AnimatedSprite2D.play("shield_stun" if shield_active else "damaged_stun")
			
		State.FAINTED:
			velocity = Vector2.ZERO
			revive_timer = REVIVE_DURATION
			$AnimatedSprite2D.play("fainted")
			$EnemyHitbox.remove_from_group("enemy_hitbox")


func _state_patrol() -> void:
	if breaking_shield:
		velocity = Vector2.ZERO
		return
		
	var space_state = get_world_2d().direct_space_state
	var edge_check_pos = global_position + Vector2(patrol_dir * EDGE_CHECK_DISTANCE, 0)
	var query = PhysicsRayQueryParameters2D.create(
		edge_check_pos,
		edge_check_pos + Vector2(0, 40.0),
		collision_mask
	)
	query.exclude = [self]

	if is_on_wall() or not space_state.intersect_ray(query):
		patrol_dir *= -1
		patrol_origin = global_position

	velocity.x = PATROL_SPEED * patrol_dir
	is_facing_right = patrol_dir > 0

	if global_position.x >= patrol_origin.x + PATROL_X_RANGE:
		patrol_dir = -1.0
		patrol_origin = global_position
	elif global_position.x <= patrol_origin.x - PATROL_X_RANGE:
		patrol_dir = 1.0
		patrol_origin = global_position
		
	var correct_anim = "shield" if shield_active else "damaged"
	if $AnimatedSprite2D.animation != correct_anim:
		$AnimatedSprite2D.play(correct_anim)

	if player:
		$Vision.target_position = player.global_position - global_position
		var player_to_right = player.global_position.x > global_position.x
		if global_position.distance_to(player.global_position) <= DETECT_DISTANCE \
				and player_to_right == is_facing_right \
				and not $Vision.is_colliding():
			_enter_state(State.ATTACK)


func _state_attack(delta: float) -> void:
	if breaking_shield:
		velocity = Vector2.ZERO
		return
		
	if not player:
		_enter_state(State.PATROL)
		return

	var space_state = get_world_2d().direct_space_state
	var chase_dir = 1 if is_facing_right else -1
	var edge_check_pos = global_position + Vector2(chase_dir * EDGE_CHECK_DISTANCE, 0)
	var query = PhysicsRayQueryParameters2D.create(
		edge_check_pos,
		edge_check_pos + Vector2(0, 40.0),
		collision_mask
	)
	query.exclude = [self]

	$Vision.target_position = player.global_position - global_position
	var player_to_right = player.global_position.x > global_position.x
	var turning = player_to_right != is_facing_right

	if not turning and (global_position.distance_to(player.global_position) > LOSE_DISTANCE \
			or $Vision.is_colliding() or is_on_wall() or not space_state.intersect_ray(query)):
		
		hit_wall = is_on_wall()
		patrol_dir = -chase_dir
		patrol_origin = global_position
		_enter_state(State.PATROL)
		return

	if turning:
		turn_timer += delta
		if turn_timer >= TURN_DELAY:
			is_facing_right = player_to_right
			turn_timer = 0.0
	else:
		turn_timer = 0.0
		is_facing_right = player_to_right

	current_speed = lerp(current_speed, CHASE_SPEED_SHIELD if shield_active else CHASE_SPEED_NO_SHIELD, delta * 2.0)
	velocity.x = current_speed * (1 if is_facing_right else -1)

	var real_vel = get_real_velocity()
	if is_on_wall() or (abs(real_vel.x) < 5.0 and abs(velocity.x) > 5.0):
		$AnimatedSprite2D.play("shield_idle" if shield_active else "damaged_idle")
	elif $AnimatedSprite2D.animation != "break_shield":
		var correct_anim = "shield" if shield_active else "damaged"
		if $AnimatedSprite2D.animation != correct_anim:
			$AnimatedSprite2D.play(correct_anim)
	

func _state_stunned(delta: float) -> void:
	velocity = Vector2.ZERO
	stun_timer -= delta
	if stun_timer <= 0:
		if player and global_position.distance_to(player.global_position) <= LOSE_DISTANCE:
			_enter_state(State.ATTACK)
		else:
			_enter_state(State.PATROL)


func _state_fainted(delta: float) -> void:
	velocity = Vector2.ZERO
	revive_timer -= delta
	if revive_timer <= 0:
		current_health = MAX_HEALTH
		shield_active = false
		$AnimatedSprite2D.play("revive")
		$AnimatedSprite2D.animation_finished.connect(_on_revive_finished, CONNECT_ONE_SHOT)


func _on_revive_finished() -> void:
	if player and global_position.distance_to(player.global_position) <= DETECT_DISTANCE:
		_enter_state(State.ATTACK)
	else:
		_enter_state(State.PATROL)


func _is_hit_from_behind() -> bool:
	if not player:
		return false
	var facing = Vector2(1.0 if is_facing_right else -1.0, 0.0)
	return facing.dot((player.global_position - global_position).normalized()) < 0.0
	
	
func take_damage(amount: int) -> void:
	if current_state == State.FAINTED:
		return

	var color_manager = player.get_node_or_null("ColorManager")
	var has_red_power = color_manager and color_manager.active_power == "red"
	var from_behind = _is_hit_from_behind()

	# Si golpeas el escudo con el poder rojo, el escudo se rompe
	# Si golpeas el enemigo por detrás, infliges daño pero no rompes el escudo
	if shield_active:
		if not from_behind and has_red_power:
			shield_active = false
			breaking_shield = true
			$AnimatedSprite2D.play("break_shield")
			$AnimatedSprite2D.animation_finished.connect(_on_break_shield_finished, CONNECT_ONE_SHOT)
			return
		if not from_behind:
			if player and player is CharacterBody2D:
				var dir = sign(player.global_position.x - global_position.x)
				player.velocity.x = dir * KNOCKBACK_PLAYER
				player.velocity.y = -60.0
			return

	current_health -= amount
	if current_health <= 0:
		_enter_state(State.FAINTED)
		return

	stun_timer = STUN_DURATION
	_enter_state(State.STUNNED)


func _on_break_shield_finished() -> void:
	breaking_shield = false
	$AnimatedSprite2D.play("damaged")
	

func _on_enemy_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(DAMAGE)

func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var player_node = get_tree().get_first_node_in_group("player")
		var multiplier = player_node.damage_multiplier if player_node else 1.0
		take_damage(int(1 * multiplier))
