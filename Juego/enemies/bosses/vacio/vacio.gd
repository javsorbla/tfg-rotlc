extends Node2D

# --- CONSTANTES ---
const MAX_HEALTH: int = 30
const DAMAGE: int = 1
const CHASE_SPEED_P1: float = 0.0 
const CHASE_SPEED_P2: float = 110.0 
const DAMAGE_FLASH_TIME: float = 0.08
const HEIGHT_OFFSET: float = -30.0 

# --- ESTADOS ---
enum State { IDLE, CHASE, EXPAND, VANISH, APPEAR, AOE, SPIKE_RAIN, SHOOT, PHASE_TRANSITION, DEAD }

# --- VARIABLES ---
@export var escena_pincho: PackedScene 
@export var escena_bola: PackedScene

var current_health: int = MAX_HEALTH
var current_state: State = State.IDLE
var player: Node2D = null

var is_active: bool = false
var facing_left: bool = false
var current_size: float = 1.0 
var spawn_position: Vector2 = Vector2.ZERO 

var is_invulnerable: bool = false
var in_phase_2: bool = false 

var action_timer: float = 0.0
var state_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_hitbox: Area2D = $AttactHitBox
@onready var normal_hurtbox: Area2D = $NormalHurtBox
@onready var flash_pantalla: ColorRect = $CanvasLayer/FlashPantalla

var damage_flash_tween: Tween = null
var action_tween: Tween = null


# --- CICLO PRINCIPAL ---

func _ready() -> void:
	current_health = MAX_HEALTH
	player = get_tree().get_first_node_in_group("player")
	spawn_position = global_position 
	
	if GameState.has_signal("level_reset"):
		GameState.level_reset.connect(_on_level_reset)
	
	if not body_hitbox.area_entered.is_connected(_on_attack_hitbox_area_entered):
		body_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	if not normal_hurtbox.area_entered.is_connected(_on_normal_hurtbox_area_entered):
		normal_hurtbox.area_entered.connect(_on_normal_hurtbox_area_entered)
		
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if not is_active or current_state == State.DEAD:
		return

	if player and current_state in [State.CHASE, State.EXPAND, State.AOE, State.PHASE_TRANSITION, State.SPIKE_RAIN, State.SHOOT]:
		facing_left = player.global_position.x < global_position.x
		_update_facing()

	match current_state:
		State.CHASE: _state_chase(delta)
		State.EXPAND: _state_expand(delta)
		State.VANISH: _state_vanish(delta)
		State.APPEAR: _state_appear(delta)
		State.AOE: _state_aoe(delta)
		State.SPIKE_RAIN: _state_spike_rain(delta)
		State.SHOOT: _state_shoot(delta)
		State.PHASE_TRANSITION: _state_phase_transition(delta)

	_check_continuous_collision()


# --- MANEJO DE ESTADOS ---

func _enter_state(new_state: State) -> void:
	current_state = new_state

	match new_state:
		State.IDLE:
			is_active = false
		State.CHASE:
			modulate.a = 1.0
			current_size = 1.0
			_set_hitboxes_active(true)
			if in_phase_2:
				action_timer = randf_range(2.0, 4.0) 
				sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)
			else:
				action_timer = randf_range(4.0, 7.0) 
				sprite.modulate = Color(1, 1, 1, 1)
		State.EXPAND:
			state_timer = 2.5 if in_phase_2 else 3.0 
			_start_expansion()
		State.VANISH:
			state_timer = 1.0 
			_set_hitboxes_active(false) 
			if action_tween: action_tween.kill()
			action_tween = create_tween()
			action_tween.tween_property(self, "modulate:a", 0.0, 1.0) 
		State.APPEAR:
			state_timer = 1.0 if in_phase_2 else 1.5 
			if player: global_position = player.global_position + Vector2(0, HEIGHT_OFFSET)
			if action_tween: action_tween.kill()
			action_tween = create_tween()
			action_tween.tween_property(self, "modulate:a", 0.4, 0.2) 
		State.AOE:
			_start_aoe_attack()
		State.SPIKE_RAIN:
			_start_spike_rain()
		State.SHOOT:
			_start_shoot()	
		State.PHASE_TRANSITION:
			_start_phase_transition()
		State.DEAD:
			if action_tween: action_tween.kill()
			_set_hitboxes_active(false)
			modulate.a = 1.0
			var boss_room = get_tree().get_first_node_in_group("boss_room")
			if boss_room and boss_room.has_method("on_boss_defeated"):
				boss_room.on_boss_defeated()
			queue_free()

func _on_level_reset() -> void:
	if action_tween: action_tween.kill()
	if damage_flash_tween: damage_flash_tween.kill()
	global_position = spawn_position
	current_health = MAX_HEALTH
	current_size = 1.0
	in_phase_2 = false 
	modulate.a = 1.0
	sprite.modulate = Color(1, 1, 1, 1)
	flash_pantalla.color.a = 0.0 
	_set_hitboxes_active(true)
	is_active = false
	is_invulnerable = false
	_enter_state(State.IDLE)


# --- FUNCIONES DE ESTADO DE IA ---

func _state_chase(delta: float) -> void:
	if not player: return
	var target_pos = player.global_position + Vector2(0, HEIGHT_OFFSET)
	var speed = CHASE_SPEED_P2 if in_phase_2 else CHASE_SPEED_P1
	global_position += (target_pos - global_position).normalized() * speed * delta
	
	action_timer -= delta
	if action_timer <= 0:
		var r = randf()
		
		# --- RULETA ---
		if in_phase_2:
			# En la fase 2
			if r < 0.20: _enter_state(State.EXPAND)
			elif r < 0.40: _enter_state(State.VANISH)
			elif r < 0.60: _enter_state(State.SPIKE_RAIN)
			elif r < 0.80: _enter_state(State.SHOOT)
			else: _enter_state(State.AOE)
		else:
			# Fase 1 normal
			if r < 0.20: _enter_state(State.EXPAND)
			elif r < 0.40: _enter_state(State.VANISH)
			elif r < 0.60: _enter_state(State.SPIKE_RAIN)
			elif r < 0.80: _enter_state(State.SHOOT)
			else: _enter_state(State.AOE)

func _state_expand(delta: float) -> void:
	state_timer -= delta
	
	if player:
		var target_pos = player.global_position + Vector2(0, HEIGHT_OFFSET)
		var speed = CHASE_SPEED_P2 if in_phase_2 else CHASE_SPEED_P1
		
		# multiplicar por 0.8 hace que se mueva un 20% más lento al ser gigante,
		# para máxima velocidad, simplemente borrar el "* 0.8".
		global_position += (target_pos - global_position).normalized() * (speed * 0.8) * delta
	# ----------------------------------------------
	
	if state_timer <= 0:
		_enter_state(State.CHASE)

func _state_vanish(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0: _enter_state(State.APPEAR)

func _state_appear(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.5 and not body_hitbox.monitoring:
		modulate.a = 1.0
		_set_hitboxes_active(true)
	if state_timer <= 0: _enter_state(State.CHASE)



func _start_spike_rain() -> void:
	state_timer = 2.0 # tiempo quieto
	
	if action_tween: action_tween.kill()
	action_tween = create_tween()
	# Efecto visual: Hace un pequeño temblor o salto
	action_tween.tween_property(self, "global_position:y", global_position.y - 20, 0.2)
	action_tween.tween_property(self, "global_position:y", global_position.y, 0.2)
	

	if escena_pincho:
		call_deferred("_spawn_spikes")


func _spawn_spikes() -> void:
	var boss_room = get_tree().get_first_node_in_group("boss_room")
	if boss_room and boss_room.has_node("LimiteIzquierda") and boss_room.has_node("LimiteDerecha"):
		var left = boss_room.get_node("LimiteIzquierda").global_position.x
		var right = boss_room.get_node("LimiteDerecha").global_position.x
		
		var altura_techo = spawn_position.y - 300.0 
		var distancia_total = right - left
		

		var ancho_pincho = 29.0 
		

		var numero_pinchos = int(distancia_total / ancho_pincho)
		
		for i in range(numero_pinchos + 1):
			var pincho = escena_pincho.instantiate()
			get_parent().add_child(pincho)
			pincho.global_position = Vector2(left + (i * ancho_pincho), altura_techo)

func _state_spike_rain(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		_enter_state(State.CHASE)


func _start_phase_transition() -> void:
	state_timer = 2.0 
	_set_hitboxes_active(false) 
	if action_tween: action_tween.kill()
	action_tween = create_tween()
	action_tween.tween_property(sprite, "modulate", Color(5.0, 0.0, 0.0, 1.0), 1.0)
	action_tween.tween_property(sprite, "modulate", Color(1.0, 0.6, 0.6, 1.0), 1.0)

func _state_phase_transition(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		in_phase_2 = true
		_enter_state(State.CHASE)

func _start_aoe_attack() -> void:
	state_timer = 4.0 
	_set_hitboxes_active(false) 
	var boss_room = get_tree().get_first_node_in_group("boss_room")
	if boss_room and boss_room.has_node("LimiteIzquierda") and boss_room.has_node("LimiteDerecha"):
		var left_limit = boss_room.get_node("LimiteIzquierda").global_position.x
		var right_limit = boss_room.get_node("LimiteDerecha").global_position.x
		global_position.x = (left_limit + right_limit) / 2.0
		global_position.y = spawn_position.y
	if action_tween: action_tween.kill()
	action_tween = create_tween()
	action_tween.tween_property(flash_pantalla, "color:a", 0.6, 2.5) 
	action_tween.parallel().tween_property(sprite, "modulate", Color(3, 0, 3, 1), 2.5) 

func _state_aoe(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 1.5 and state_timer + delta > 1.5:
		_execute_aoe_damage()
	if state_timer <= 0:
		if action_tween: action_tween.kill() 
		action_tween = create_tween()
		action_tween.tween_property(flash_pantalla, "color:a", 0.0, 0.5)
		_enter_state(State.CHASE)

func _execute_aoe_damage() -> void:
	if action_tween: action_tween.kill() 
	action_tween = create_tween()
	flash_pantalla.color.a = 1.0 
	action_tween.tween_property(flash_pantalla, "color:a", 0.6, 0.3)
	if player:
		var health_node = player.get_node_or_null("Health")
		if health_node:
			if not health_node.is_invincible and not player.is_shielding:
				health_node.take_damage(2) 
				
			
				

func activate() -> void:
	is_active = true
	_enter_state(State.CHASE)

func _update_facing() -> void:
	var dir_sign = 1.0 if facing_left else -1.0
	scale = Vector2(current_size * dir_sign, current_size)

func _set_hitboxes_active(active: bool) -> void:
	body_hitbox.set_deferred("monitoring", active)
	body_hitbox.set_deferred("monitorable", active)
	normal_hurtbox.set_deferred("monitoring", active)
	normal_hurtbox.set_deferred("monitorable", active)

func _start_expansion() -> void:
	if action_tween: action_tween.kill()
	action_tween = create_tween()
	action_tween.tween_property(self, "current_size", 2.0, 0.5)
	action_tween.tween_interval(1.5)
	action_tween.tween_property(self, "current_size", 1.0, 0.5)

func _check_continuous_collision() -> void:
	if body_hitbox.monitoring:
		var overlapping_areas = body_hitbox.get_overlapping_areas()
		for area in overlapping_areas:
			_on_attack_hitbox_area_entered(area)

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if current_state in [State.DEAD, State.PHASE_TRANSITION]: return
	if area.is_in_group("player_hurtbox"):
		var hit_player = area.get_parent()
		var health_node = hit_player.get_node_or_null("Health")
		if health_node and health_node.has_method("take_damage"):
			if not health_node.is_invincible:
				health_node.take_damage(DAMAGE)
				if hit_player is CharacterBody2D:
					var push_dir = (hit_player.global_position - global_position).normalized()
					hit_player.velocity = push_dir * 350.0

func _on_normal_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var hit_player = area.get_parent()
		var final_damage = 1 
		if "damage_multiplier" in hit_player:
			final_damage = int(1 * hit_player.damage_multiplier)
		take_damage(final_damage)

func take_damage(amount: int) -> void:
	if current_state in [State.DEAD, State.EXPAND, State.PHASE_TRANSITION] or is_invulnerable: 
		return
	if current_state in [State.VANISH, State.APPEAR, State.AOE] and not normal_hurtbox.monitoring:
		return
	current_health -= amount
	if current_health <= (MAX_HEALTH / 2) and not in_phase_2:
		_enter_state(State.PHASE_TRANSITION)
		return
	if current_health <= 0:
		_enter_state(State.DEAD)
		return
	_play_damage_flash()
	is_invulnerable = true
	await get_tree().create_timer(0.2).timeout
	is_invulnerable = false

func _play_damage_flash() -> void:
	if damage_flash_tween: damage_flash_tween.kill()
	damage_flash_tween = create_tween()
	sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
	var target_color = Color(1.0, 0.6, 0.6, 1.0) if in_phase_2 else Color(1.0, 1.0, 1.0, 1.0)
	target_color.a = modulate.a 
	damage_flash_tween.tween_property(sprite, "modulate", target_color, DAMAGE_FLASH_TIME)

func _start_shoot() -> void:
	state_timer = 1.0 # Se queda quieto un segundo antes/después de disparar
	
	if action_tween: action_tween.kill()
	action_tween = create_tween()
	# Efecto visual: Hace un brillito negro rápido para avisar
	action_tween.tween_property(sprite, "modulate", Color(0, 0, 0, 1), 0.2)
	var normal_color = Color(1.0, 0.6, 0.6, 1.0) if in_phase_2 else Color(1, 1, 1, 1)
	action_tween.tween_property(sprite, "modulate", normal_color, 0.2)
	
	if escena_bola:
		call_deferred("_spawn_bola")
	

func _spawn_bola() -> void:
	if not player: return
	
	var bola = escena_bola.instantiate()
	get_parent().add_child(bola)
	
	bola.global_position = global_position
	
	var target_pos = player.global_position + Vector2(0, HEIGHT_OFFSET)
	bola.direction = (target_pos - global_position).normalized()

func _state_shoot(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		_enter_state(State.CHASE)