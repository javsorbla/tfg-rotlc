extends CharacterBody2D

const MAX_HEALTH: int = 1
const DAMAGE: int = 2
const STUN_DURATION: float = 2.5
const SLEEP_DISTANCE: float = 200.0
const GRAVITY: float = 700.0
const ROLL_SPEED: float = 120.0
const JUMP_VELOCITY: float = -150.0
const EDGE_CHECK_DISTANCE: float = 20.0
const KNOCKBACK_ENEMY: float = 80.0
const KNOCKBACK_PLAYER: float = 150.0

const DORMIR_NUCLEO := preload("res://music/enemies/common/nucleo_inestable/dormir_nucleo.ogg")
const MOVIMIENTO_NUCLEO := preload("res://music/enemies/common/nucleo_inestable/movimiento_nucleo.ogg")
const STUN_NUCLEO := preload("res://music/enemies/common/nucleo_inestable/stun_nucleo.ogg")
const MUERTE_NUCLEO := preload("res://music/enemies/common/nucleo_inestable/muerte_nucleo.ogg")

const DEAD_SHEET_3 := preload("res://assets/enemies/common/nucleo_inestable/dead_sheet_3.png")
const DEAD_STUN_SHEET_3 := preload("res://assets/enemies/common/nucleo_inestable/stun_dead_sheet_3.png")
const IDLE_SHEET_3 := preload("res://assets/enemies/common/nucleo_inestable/idle_sheet_3.png")
const ROLLING_SHEET_3 := preload("res://assets/enemies/common/nucleo_inestable/attack_sheet_3.png")
const SLEEP_SHEET_3 := preload("res://assets/enemies/common/nucleo_inestable/sleep_sheet_3.png")
const STUNNED_SHEET_3 := preload("res://assets/enemies/common/nucleo_inestable/stun_sheet_3.png")
const STUNNED_GLOW_SHEET_3 := preload("res://assets/enemies/common/nucleo_inestable/stun_glow_sheet_3.png")
const DEAD_SHEET_4 := preload("res://assets/enemies/common/nucleo_inestable/dead_sheet_4.png")
const DEAD_STUN_SHEET_4 := preload("res://assets/enemies/common/nucleo_inestable/stun_dead_sheet_4.png")
const IDLE_SHEET_4 := preload("res://assets/enemies/common/nucleo_inestable/idle_sheet_4.png")
const ROLLING_SHEET_4 := preload("res://assets/enemies/common/nucleo_inestable/attack_sheet_4.png")
const SLEEP_SHEET_4 := preload("res://assets/enemies/common/nucleo_inestable/sleep_sheet_4.png")
const STUNNED_SHEET_4 := preload("res://assets/enemies/common/nucleo_inestable/stun_sheet_4.png")
const STUNNED_GLOW_SHEET_4 := preload("res://assets/enemies/common/nucleo_inestable/stun_glow_sheet_4.png")

enum State { SLEEP, JUMP, ROLLING, STUNNED, DEAD }

var current_state: State = State.SLEEP
var current_health: int = MAX_HEALTH
var stun_timer: float = 0.0
var roll_direction: float = 1.0
var spawn_position = Vector2.ZERO

var player: Node2D = null
var space_state: PhysicsDirectSpaceState2D = null

var death_timer: float = -1.0
var previous_state: State = State.SLEEP
var _combat_reset_state: Dictionary = {}

var _base_sprite_frames: SpriteFrames = null
var _level3_sprite_frames: SpriteFrames = null
var _level4_sprite_frames: SpriteFrames = null
var _movement_player: AudioStreamPlayer2D = null
var _sleep_player: AudioStreamPlayer2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var luz: PointLight2D = $PointLight2D

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
	
	space_state = get_world_2d().direct_space_state
	_setup_audio_players()
	_setup_light()
	_enter_state(State.SLEEP)


const SFX_MAX_DISTANCE: float = 400.0


func _play_sfx(stream: AudioStream, vol: float = 0.0, pitch: float = 1.0) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = &"EFX"
	player.volume_db = vol
	player.max_distance = SFX_MAX_DISTANCE
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _setup_audio_players() -> void:
	_movement_player = AudioStreamPlayer2D.new()
	_movement_player.stream = MOVIMIENTO_NUCLEO
	_movement_player.bus = &"EFX"
	_movement_player.volume_db = 20.0
	_movement_player.max_distance = SFX_MAX_DISTANCE
	add_child(_movement_player)

	_sleep_player = AudioStreamPlayer2D.new()
	_sleep_player.stream = DORMIR_NUCLEO
	_sleep_player.bus = &"EFX"
	_sleep_player.volume_db = 8.0
	_sleep_player.max_distance = SFX_MAX_DISTANCE
	add_child(_sleep_player)


func _setup_light() -> void:
	if GameState.current_level == 1:
		luz.enabled = false
		return

	var imagen: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var dx: float = (x - 32.0) / 32.0
			var dy: float = (y - 32.0) / 32.0
			var dist: float = sqrt(dx * dx + dy * dy)
			var alpha: float = clamp(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.5)
			imagen.set_pixel(x, y, Color(1, 1, 1, alpha))
	luz.texture = ImageTexture.create_from_image(imagen)
	luz.blend_mode = Light2D.BLEND_MODE_ADD

	if GameState.current_level == 2:
		luz.color = Color(1.0, 0.5, 0.0)
	elif GameState.current_level == 3:
		luz.color = Color(0.0, 0.6, 1.0)
	elif GameState.current_level == 4:
		luz.color = Color(0.4, 0.0, 0.8)
	luz.texture_scale = 1.5
	luz.energy = 3.5
	luz.enabled = false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		
	match current_state:
		State.SLEEP:
			_state_sleep()
		State.JUMP:
			_state_jump()
		State.ROLLING:
			_state_rolling()
			$AnimatedSprite2D.rotation += roll_direction * 5.0 * delta
		State.STUNNED:
			_state_stunned(delta)
		State.DEAD:
			if death_timer > 0:
				death_timer -= delta
				if death_timer <= 0.0:
					_despawn_dead_instance()
			
	move_and_slide()

func _on_level_reset():
	set_physics_process(true)
	visible = true
	current_health = MAX_HEALTH
	global_position = spawn_position
	velocity = Vector2.ZERO
	death_timer = -1.0
	EnemyResetUtils.restore_collider_state($EnemyHitbox, $EnemyHurtbox, _combat_reset_state)
	call_deferred("_apply_level_visuals")
	_setup_light()
	_enter_state(State.SLEEP)

func _apply_level_visuals() -> void:
	if sprite == null or _base_sprite_frames == null:
		return

	var target_frames: SpriteFrames = _base_sprite_frames
	if GameState.current_level == 3:
		target_frames = _get_level3_sprite_frames()
	elif GameState.current_level == 4:
		target_frames = _get_level4_sprite_frames()

	if sprite.sprite_frames != target_frames:
		sprite.sprite_frames = target_frames

	var current_animation := sprite.animation
	if current_animation != "" and sprite.sprite_frames.has_animation(current_animation):
		sprite.play(current_animation)

func _get_level3_sprite_frames() -> SpriteFrames:
	if _level3_sprite_frames != null:
		return _level3_sprite_frames

	var frames := _base_sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return _base_sprite_frames

	_replace_animation_frames(frames, "dead", DEAD_SHEET_3)
	_replace_animation_frames(frames, "dead_stun", DEAD_STUN_SHEET_3)
	_replace_animation_frames(frames, "idle", IDLE_SHEET_3)
	_replace_animation_frames(frames, "rolling", ROLLING_SHEET_3)
	_replace_animation_frames(frames, "sleep", SLEEP_SHEET_3)
	_replace_animation_frames(frames, "stunned", STUNNED_SHEET_3)
	_replace_animation_frames(frames, "stunned_glow", STUNNED_GLOW_SHEET_3)

	_level3_sprite_frames = frames
	return _level3_sprite_frames
	
func _get_level4_sprite_frames() -> SpriteFrames:
	if _level4_sprite_frames != null:
		return _level4_sprite_frames

	var frames := _base_sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return _base_sprite_frames

	_replace_animation_frames(frames, "dead", DEAD_SHEET_4)
	_replace_animation_frames(frames, "dead_stun", DEAD_STUN_SHEET_4)
	_replace_animation_frames(frames, "idle", IDLE_SHEET_4)
	_replace_animation_frames(frames, "rolling", ROLLING_SHEET_4)
	_replace_animation_frames(frames, "sleep", SLEEP_SHEET_4)
	_replace_animation_frames(frames, "stunned", STUNNED_SHEET_4)
	_replace_animation_frames(frames, "stunned_glow", STUNNED_GLOW_SHEET_4)

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

func _enter_state(new_state: State) -> void:
	previous_state = current_state
	current_state = new_state
	match new_state:
		State.SLEEP:
			velocity.x = 0
			$AnimatedSprite2D.rotation = 0.0
			$AnimatedSprite2D.play("sleep")
			$EnemyHitbox.set_deferred("monitorable", false)
			if $AnimatedSprite2D.animation_finished.is_connected(_on_stunned_animation_finished):
				$AnimatedSprite2D.animation_finished.disconnect(_on_stunned_animation_finished)
			if _movement_player and _movement_player.playing:
				_movement_player.stop()
			if _sleep_player and not _sleep_player.playing:
				_sleep_player.play()
			luz.enabled = false


		State.JUMP:
			if _sleep_player and _sleep_player.playing:
				_sleep_player.stop()
			if player:
				roll_direction = sign(player.global_position.x - global_position.x)
			velocity.x = 0
			velocity.y = JUMP_VELOCITY
			$AnimatedSprite2D.flip_h = roll_direction > 0
			$AnimatedSprite2D.play("idle")
			$EnemyHitbox.set_deferred("monitorable", false)
			luz.enabled = true
			luz.energy = 3.5

		State.ROLLING:
			$AnimatedSprite2D.flip_h = roll_direction > 0
			$AnimatedSprite2D.play("rolling")
			$EnemyHitbox.set_deferred("monitorable", true)
			if _movement_player and not _movement_player.playing:
				_movement_player.play()
			luz.enabled = true
			luz.energy = 3.5

		State.STUNNED:
			velocity.x = 0
			velocity.y = 0
			$AnimatedSprite2D.rotation = 0.0
			$EnemyHitbox.set_deferred("monitorable", false)
			if not $AnimatedSprite2D.animation_finished.is_connected(_on_stunned_animation_finished):
				$AnimatedSprite2D.animation_finished.connect(_on_stunned_animation_finished)
			if previous_state == State.STUNNED: 
				$AnimatedSprite2D.play("stunned_glow")
			else:
				$AnimatedSprite2D.play("stunned")
			if _sleep_player and _sleep_player.playing:
				_sleep_player.stop()
			if _movement_player and _movement_player.playing:
				_movement_player.stop()
			_play_sfx(STUN_NUCLEO, -2.0)
			luz.enabled = true
			luz.energy = 1.5
			
		State.DEAD:
			velocity = Vector2.ZERO
			$AnimatedSprite2D.rotation = 0.0
			if previous_state == State.STUNNED:
				$AnimatedSprite2D.play("dead_stun")
			else:
				$AnimatedSprite2D.play("dead")
			if _sleep_player and _sleep_player.playing:
				_sleep_player.stop()
			if _movement_player and _movement_player.playing:
				_movement_player.stop()
			_play_sfx(MUERTE_NUCLEO, 0.0, 0.85)
			if luz and luz.enabled:
				var tween: Tween = create_tween()
				tween.tween_property(luz, "energy", 0.0, 1.5)
			
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
				
			death_timer = 1.0

func _on_stunned_animation_finished() -> void:
	if current_state == State.STUNNED and $AnimatedSprite2D.animation == "stunned":
		$AnimatedSprite2D.play("stunned_glow")

func _state_sleep() -> void:
	velocity.x = 0
	if not player:
		return
		
	$Vision.target_position = player.global_position - global_position

	if global_position.distance_to(player.global_position) <= SLEEP_DISTANCE and not $Vision.is_colliding():
		_enter_state(State.JUMP)


func _state_jump() -> void:
	velocity.x = 0
	if is_on_floor():
		_enter_state(State.ROLLING)


func _state_rolling() -> void:
	# Cambiar dirección si choca contra un muro
	if is_on_wall():
		roll_direction *= -1
		$AnimatedSprite2D.flip_h = roll_direction > 0

	# Cambiar dirección si llega al borde del suelo
	var edge_check_pos = global_position + Vector2(roll_direction * EDGE_CHECK_DISTANCE, 0)
	var query = PhysicsRayQueryParameters2D.create(
		edge_check_pos,
		edge_check_pos + Vector2(0, 40.0),
		collision_mask
	)
	query.exclude = [self]
	if not space_state.intersect_ray(query):
		roll_direction *= -1
		$AnimatedSprite2D.flip_h = roll_direction > 0

	velocity.x = ROLL_SPEED * roll_direction


func _state_stunned(delta: float) -> void:
	stun_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 100.0 * delta)
	if stun_timer <= 0:
		_enter_state(State.SLEEP)


func _on_enemy_hitbox_area_entered(area: Area2D):
	if area.is_in_group("player_hurtbox"):
		var target = area.get_parent()
		
		# Si el jugador tiene escudo, rebota como contra una pared
		if target.get("is_shielding") == true:
			roll_direction *= -1
			$AnimatedSprite2D.flip_h = roll_direction > 0
			return
		
		if target.has_method("take_damage"):
			target.take_damage(DAMAGE)
			
		if target is CharacterBody2D:
			var dir = (target.global_position - global_position).normalized()
			dir.y = 0
			target.velocity = dir * 230


func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var player_node = get_tree().get_first_node_in_group("player")
		var multiplier = player_node.damage_multiplier if player_node else 1.0
		take_damage(int(1 * multiplier))


func take_damage(amount: int) -> void:
	if current_state == State.DEAD: 
		return 
	
	var color_manager = player.get_node("ColorManager")
	var has_red_power = color_manager and color_manager.active_power == "red"
	
	# Sin el poder rojo: no inflinges daño y aplicas retroceso
	if not has_red_power:
		stun_timer = STUN_DURATION
		_enter_state(State.STUNNED)
		if player and player is CharacterBody2D:
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = -dir * KNOCKBACK_ENEMY
			velocity.y = -60.0
			player.velocity.x = dir * KNOCKBACK_PLAYER
			player.velocity.y = -60.0
		return

	# Con el poder rojo: el enemigo recibe daño
	current_health -= amount
	if current_health <= 0:
		die()
		return


func die() -> void:
	NakamaManager.add_enemy_kill()
	_enter_state(State.DEAD)
