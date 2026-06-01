extends CharacterBody2D

const MAX_HEALTH: int = 2
const DAMAGE: int = 1
const DIVE_SPEED: float = 200.0
const RETURN_SPEED: float = 100.0
const IDLE_DISTANCE: float = 200.0
const PATROL_SPEED: float = 60.0
const PATROL_X_RANGE: float = 80.0
const PATROL_Y_RANGE: float = 7.0
const STUN_DURATION: float = 0.4
const HIT_KNOCKBACK_FORCE: float = 120.0

const RETURN_ARC_HEIGHT: float = 40.0
const KNOCKBACK_FORCE: float = 10.0
const DIVE_MAX_DISTANCE: float = 300.0  # distancia máxima antes de volver

const MOVE_SHEET_2 := preload("res://assets/enemies/common/acechador_aereo/move_sheet_2.png")
const STUN_SHEET_2 := preload("res://assets/enemies/common/acechador_aereo/stun_sheet_2.png")
const DEAD_SHEET_2 := preload("res://assets/enemies/common/acechador_aereo/dead_sheet_2.png")
const MOVE_SHEET_3 := preload("res://assets/enemies/common/acechador_aereo/move_sheet_3.png")
const STUN_SHEET_3 := preload("res://assets/enemies/common/acechador_aereo/stun_sheet_3.png")
const DEAD_SHEET_3 := preload("res://assets/enemies/common/acechador_aereo/dead_sheet_3.png")
const MOVE_SHEET_4 := preload("res://assets/enemies/common/acechador_aereo/move_sheet_4.png")
const STUN_SHEET_4 := preload("res://assets/enemies/common/acechador_aereo/stun_sheet_4.png")
const DEAD_SHEET_4 := preload("res://assets/enemies/common/acechador_aereo/dead_sheet_4.png")

enum State { IDLE, DIVING, RETURNING, STUNNED, DEAD }

var current_state: State = State.IDLE
var current_health: int = MAX_HEALTH
var player: Node2D = null
var dive_direction: Vector2 = Vector2.ZERO
var dive_started_pos: Vector2 = Vector2.ZERO
var has_hit_player: bool = false
var stun_timer: float = 0.0
var spawn_position = Vector2.ZERO

# Returning
var return_start_pos: Vector2 = Vector2.ZERO
var return_progress: float = 0.0

# Patrullaje
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_dir: float = 1.0
var patrol_y_phase: float = 0.0

# Despawn tras morir
var death_grounded_timer: float = -1.0
var has_landed: bool = false
var _combat_reset_state: Dictionary = {}

var _base_sprite_frames: SpriteFrames = null
var _level2_sprite_frames: SpriteFrames = null
var _level3_sprite_frames: SpriteFrames = null
var _level4_sprite_frames: SpriteFrames = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	current_health = MAX_HEALTH
	player = get_tree().get_first_node_in_group("player")
	
	spawn_position = global_position
	GameState.level_reset.connect(_on_level_reset)
	_base_sprite_frames = sprite.sprite_frames
	call_deferred("_apply_level_visuals")
	
	if not $EnemyHitbox.area_entered.is_connected(_on_enemy_hitbox_area_entered):
		$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)
	if not $EnemyHurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
		$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)
	_combat_reset_state = EnemyResetUtils.capture_collider_state($EnemyHitbox, $EnemyHurtbox)

	patrol_origin = global_position
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle()
		State.DIVING:
			_state_diving()
		State.RETURNING:
			_state_returning()
		State.STUNNED:
			_state_stunned(delta)
		State.DEAD:
			velocity.y += 800 * delta
			# Despawn al tocar el suelo
			if is_on_floor() and not has_landed:
				has_landed = true
				death_grounded_timer = 0.7
			if has_landed:
				death_grounded_timer -= delta
				if death_grounded_timer <= 0.0:
					_despawn_dead_instance()

	move_and_slide()

func _on_level_reset():
	set_physics_process(true)
	visible = true
	current_health = MAX_HEALTH
	global_position = spawn_position
	velocity = Vector2.ZERO
	has_landed = false
	death_grounded_timer = -1.0
	EnemyResetUtils.restore_collider_state($EnemyHitbox, $EnemyHurtbox, _combat_reset_state)
	call_deferred("_apply_level_visuals")
	_enter_state(State.IDLE)


func _apply_level_visuals() -> void:
	if sprite == null or _base_sprite_frames == null:
		return

	var target_frames: SpriteFrames = _base_sprite_frames
	if GameState.current_level == 2:
		target_frames = _get_level2_sprite_frames()
	elif GameState.current_level == 3:
		target_frames = _get_level3_sprite_frames()
	elif GameState.current_level == 4:
		target_frames = _get_level4_sprite_frames()

	if sprite.sprite_frames != target_frames:
		sprite.sprite_frames = target_frames

	var current_animation := sprite.animation
	if current_animation != "" and sprite.sprite_frames.has_animation(current_animation):
		sprite.play(current_animation)

func _get_level2_sprite_frames() -> SpriteFrames:
	if _level2_sprite_frames != null:
		return _level2_sprite_frames

	var frames := _base_sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return _base_sprite_frames

	_replace_animation_frames(frames, "move", MOVE_SHEET_2)
	_replace_animation_frames(frames, "dazed", STUN_SHEET_2)
	_replace_animation_frames(frames, "dead", DEAD_SHEET_2)

	_level2_sprite_frames = frames
	return _level2_sprite_frames

func _get_level3_sprite_frames() -> SpriteFrames:
	if _level3_sprite_frames != null:
		return _level3_sprite_frames

	var frames := _base_sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return _base_sprite_frames

	_replace_animation_frames(frames, "move", MOVE_SHEET_3)
	_replace_animation_frames(frames, "dazed", STUN_SHEET_3)
	_replace_animation_frames(frames, "dead", DEAD_SHEET_3)

	_level3_sprite_frames = frames
	return _level3_sprite_frames
	
func _get_level4_sprite_frames() -> SpriteFrames:
	if _level4_sprite_frames != null:
		return _level4_sprite_frames

	var frames := _base_sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return _base_sprite_frames

	_replace_animation_frames(frames, "move", MOVE_SHEET_4)
	_replace_animation_frames(frames, "dazed", STUN_SHEET_4)
	_replace_animation_frames(frames, "dead", DEAD_SHEET_4)

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


func _despawn_dead_instance() -> void:
	velocity = Vector2.ZERO
	EnemyResetUtils.despawn(self)

# Cambio de estados
func _enter_state(new_state: State) -> void:
	current_state = new_state

	match new_state:
		State.IDLE:
			velocity = Vector2.ZERO
			has_hit_player = false
			$AnimatedSprite2D.flip_h = patrol_dir > 0
			$AnimatedSprite2D.play("move")

		State.DIVING:
			if player:
				var head_pos = player.global_position + Vector2(0, -10)
				dive_direction = (head_pos - global_position).normalized()
				velocity = dive_direction * DIVE_SPEED
				has_hit_player = false
				dive_started_pos = global_position

		State.RETURNING:
			velocity = Vector2.ZERO
			return_start_pos = global_position
			return_progress = 0.0

		State.DEAD:
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


func _state_idle() -> void:
	if player:
		var dist = global_position.distance_to(player.global_position)

		$Vision.target_position = player.global_position - global_position

		if dist <= IDLE_DISTANCE and not $Vision.is_colliding():
			_enter_state(State.DIVING)
			return

	velocity.x = patrol_dir * PATROL_SPEED
	patrol_y_phase += get_physics_process_delta_time() * 2.0
	global_position.y = patrol_origin.y + sin(patrol_y_phase) * PATROL_Y_RANGE

	# Detectar muros
	move_and_slide()
	if is_on_wall():
		patrol_dir *= -1   # cambiar dirección si choca con un muro

	if global_position.x >= patrol_origin.x + PATROL_X_RANGE:
		patrol_dir = -1.0
	elif global_position.x <= patrol_origin.x - PATROL_X_RANGE:
		patrol_dir = 1.0

	$AnimatedSprite2D.flip_h = patrol_dir > 0
	$AnimatedSprite2D.play("move")


func _state_diving() -> void:
	if not player:
		return

	$AnimatedSprite2D.flip_h = dive_direction.x > 0
	$AnimatedSprite2D.play("move")
	velocity = dive_direction * DIVE_SPEED

	# Si choca con un muro, cancela el ataque
	if is_on_wall():
		_enter_state(State.RETURNING)
		return

	# Se considera “fallido” si recorre demasiada distancia sin golpear
	if not has_hit_player:
		if global_position.distance_to(dive_started_pos) >= DIVE_MAX_DISTANCE:
			_enter_state(State.RETURNING)


func _state_returning() -> void:
	var total_dir = patrol_origin - return_start_pos
	var total_dist = total_dir.length()
	if total_dist == 0:
		_enter_state(State.IDLE)
		return

	return_progress += RETURN_SPEED * get_physics_process_delta_time()
	var t = clamp(return_progress / total_dist, 0, 1)

	var new_pos = return_start_pos.lerp(patrol_origin, t)
	new_pos.y -= sin(t * PI) * RETURN_ARC_HEIGHT
	global_position = new_pos

	$AnimatedSprite2D.flip_h = total_dir.x > 0
	$AnimatedSprite2D.play("move")

	if t >= 1.0:
		global_position = patrol_origin
		patrol_y_phase = 0.0
		_enter_state(State.IDLE)


func _state_stunned(delta):
	stun_timer -= delta
	velocity = Vector2.ZERO

	if stun_timer <= 0:
		_enter_state(State.RETURNING)


func _on_enemy_hitbox_area_entered(area: Area2D): 
	if current_state != State.DIVING or has_hit_player: 
		return 
		
	if area.is_in_group("player_hurtbox"): 
		var target = area.get_parent() 
		has_hit_player = true 
		if target.has_method("take_damage"): 
			target.take_damage(DAMAGE) 
				
		# knockback 
		if target is CharacterBody2D and not target.is_shielding: 
			var dir = (target.global_position - global_position).normalized() 
			dir.y = 0 
			target.velocity = dir * 150 
		_enter_state(State.RETURNING) 


func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var player_node = get_tree().get_first_node_in_group("player")
		var multiplier = player_node.damage_multiplier if player_node else 1.0
		take_damage(int(1 * multiplier)) 

			
func take_damage(amount: int) -> void: 
	if current_state == State.DEAD: 
		return 
	current_health -= amount 
	if current_health <= 0: 
		die() 
		return 

	stun_timer = STUN_DURATION
	_enter_state(State.STUNNED) 
	$AnimatedSprite2D.play("dazed")


func die() -> void:
	_enter_state(State.DEAD)
