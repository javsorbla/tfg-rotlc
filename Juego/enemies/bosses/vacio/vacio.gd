extends Node2D

# --- CONSTANTES ---
const MAX_HEALTH: int = 30
const DAMAGE: int = 1
const CHASE_SPEED: float = 55.0
const DAMAGE_FLASH_TIME: float = 0.08
const HEIGHT_OFFSET: float = -30.0 

# --- ESTADOS ---
enum State { IDLE, CHASE, EXPAND, VANISH, APPEAR, AOE, DEAD }

# --- VARIABLES ---
var current_health: int = MAX_HEALTH
var current_state: State = State.IDLE
var player: Node2D = null

var is_active: bool = false
var facing_left: bool = false
var current_size: float = 1.0 
var spawn_position: Vector2 = Vector2.ZERO 

var is_invulnerable: bool = false # Cerrojo para no recibir daño múltiple

# Temporizadores de la IA
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

    # Girar hacia el jugador (incluso si está cargando el AOE)
    if player and current_state in [State.CHASE, State.EXPAND, State.AOE]:
        facing_left = player.global_position.x < global_position.x
        _update_facing()

    match current_state:
        State.CHASE:
            _state_chase(delta)
        State.EXPAND:
            _state_expand(delta)
        State.VANISH:
            _state_vanish(delta)
        State.APPEAR:
            _state_appear(delta)
        State.AOE:
            _state_aoe(delta)

    # Comprobación de daño continuo por si el jugador se queda dentro
    _check_continuous_collision()


# --- MANEJO DE ESTADOS ---

func _enter_state(new_state: State) -> void:
    current_state = new_state

    match new_state:
        State.IDLE:
            is_active = false
            
        State.CHASE:
            modulate.a = 1.0
            sprite.modulate = Color(1, 1, 1, 1)
            current_size = 1.0
            _set_hitboxes_active(true)
            action_timer = randf_range(4.0, 7.0) 
            
        State.EXPAND:
            state_timer = 3.0 
            _start_expansion()
            
        State.VANISH:
            state_timer = 1.0 
            _set_hitboxes_active(false) 
            
            if action_tween: action_tween.kill()
            action_tween = create_tween()
            action_tween.tween_property(self, "modulate:a", 0.0, 1.0) 
            
        State.APPEAR:
            state_timer = 1.5 
            if player:
                global_position = player.global_position + Vector2(0, HEIGHT_OFFSET)
                
            if action_tween: action_tween.kill()
            action_tween = create_tween()
            action_tween.tween_property(self, "modulate:a", 0.4, 0.2) 
            
        State.AOE:
            _start_aoe_attack()
            
        State.DEAD:
            if action_tween: action_tween.kill()
            _set_hitboxes_active(false)
            modulate.a = 1.0
            
            var boss_room = get_tree().get_first_node_in_group("boss_room")
            if boss_room and boss_room.has_method("on_boss_defeated"):
                boss_room.on_boss_defeated()
                
            queue_free()


# --- REINICIO (MUERTE JUGADOR) ---

func _on_level_reset() -> void:
    if action_tween: action_tween.kill()
    if damage_flash_tween: damage_flash_tween.kill()
    
    global_position = spawn_position
    current_health = MAX_HEALTH
    current_size = 1.0
    
    modulate.a = 1.0
    sprite.modulate = Color(1, 1, 1, 1)
    flash_pantalla.color.a = 0.0 # Asegurar que la pantalla no se queda oscura
    
    _set_hitboxes_active(true)
    is_active = false
    is_invulnerable = false
    _enter_state(State.IDLE)


# --- FUNCIONES DE ESTADO DE IA ---

func _state_chase(delta: float) -> void:
    if not player: return
    var target_pos = player.global_position + Vector2(0, HEIGHT_OFFSET)
    var direction = (target_pos - global_position).normalized()
    global_position += direction * CHASE_SPEED * delta
    
    action_timer -= delta
    if action_timer <= 0:
        var r = randf()
        # Probabilidades de ataque
        if r < 0.33:
            _enter_state(State.EXPAND)
        elif r < 0.66:
            _enter_state(State.VANISH)
        else:
            _enter_state(State.AOE)

func _state_expand(delta: float) -> void:
    state_timer -= delta
    if state_timer <= 0:
        _enter_state(State.CHASE)

func _state_vanish(delta: float) -> void:
    state_timer -= delta
    if state_timer <= 0:
        _enter_state(State.APPEAR)

func _state_appear(delta: float) -> void:
    state_timer -= delta
    if state_timer <= 0.5 and not body_hitbox.monitoring:
        modulate.a = 1.0
        _set_hitboxes_active(true)
    if state_timer <= 0:
        _enter_state(State.CHASE)


# --- ATAQUE DE ÁREA (AOE) ---

func _start_aoe_attack() -> void:
    state_timer = 4.0 # 2.5s de carga + impacto a 1.5s + 1.5s de reposo
    _set_hitboxes_active(false) # El jefe es intocable mientras canaliza esto
    
    # Centrar al jefe en la habitación
    var boss_room = get_tree().get_first_node_in_group("boss_room")
    if boss_room and boss_room.has_node("LimiteIzquierda") and boss_room.has_node("LimiteDerecha"):
        var left_limit = boss_room.get_node("LimiteIzquierda").global_position.x
        var right_limit = boss_room.get_node("LimiteDerecha").global_position.x
        global_position.x = (left_limit + right_limit) / 2.0
        global_position.y = spawn_position.y

    if action_tween: action_tween.kill()
    action_tween = create_tween()
    
    # La pantalla se oscurece modificando el color:a
    action_tween.tween_property(flash_pantalla, "color:a", 0.6, 2.5) 
    # El jefe brilla
    action_tween.parallel().tween_property(sprite, "modulate", Color(3, 0, 3, 1), 2.5) 

func _state_aoe(delta: float) -> void:
    state_timer -= delta
    
    # Detona el daño
    if state_timer <= 1.5 and state_timer + delta > 1.5:
        _execute_aoe_damage()
    
    # Termina el ataque
    if state_timer <= 0:
        if action_tween: action_tween.kill() # Limpiamos de forma segura
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
            # Comprobamos los parpadeos (is_invincible) Y tu poder (is_shielding)
            if not health_node.is_invincible and not player.is_shielding:
                health_node.take_damage(2) 
                print("¡Iris ha recibido el Vórtice!")
            else:
                print("¡Iris bloqueó el Vórtice con su habilidad/escudo!")


# --- FUNCIONES AUXILIARES ---

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

# --- COMPROBACIÓN CONTINUA DE DAÑO ---

func _check_continuous_collision() -> void:
    if body_hitbox.monitoring:
        var overlapping_areas = body_hitbox.get_overlapping_areas()
        for area in overlapping_areas:
            _on_attack_hitbox_area_entered(area)


# --- COMBATE ---

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
    if current_state == State.DEAD: return
    
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
        var hit_player = area.get_parent() # Obtenemos a Iris
        var final_damage = 1 # Daño base
        
        # Si Iris tiene la variable del multiplicador, la aplicamos
        if "damage_multiplier" in hit_player:
            final_damage = int(1 * hit_player.damage_multiplier)
            
        take_damage(final_damage)

func take_damage(amount: int) -> void:
    # 1. Ignoramos daño si está muerto o si tiene el cerrojo temporal
    if current_state == State.DEAD or is_invulnerable: 
        return
        
    # 2. Ignoramos daño si el jefe se está expandiendo
    if current_state == State.EXPAND:
        return
        
    # 3. Ignoramos daño si está invisible o haciendo el ataque especial
    if current_state in [State.VANISH, State.APPEAR, State.AOE] and not normal_hurtbox.monitoring:
        return

    current_health -= amount
    print("¡Impacto! Vida de El Vacío: ", current_health, "/", MAX_HEALTH)
    _play_damage_flash()

    if current_health <= 0:
        _enter_state(State.DEAD)
        return
        
    is_invulnerable = true
    await get_tree().create_timer(0.2).timeout
    is_invulnerable = false

func _play_damage_flash() -> void:
    if damage_flash_tween: damage_flash_tween.kill()
    damage_flash_tween = create_tween()
    sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
    var target_color = Color(1.0, 1.0, 1.0, modulate.a) 
    damage_flash_tween.tween_property(sprite, "modulate", target_color, DAMAGE_FLASH_TIME)