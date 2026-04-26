extends Node2D

# --- CONSTANTES ---
const MAX_HEALTH: int = 30
const DAMAGE: int = 1
const CHASE_SPEED: float = 55.0
const DAMAGE_FLASH_TIME: float = 0.08

# --- ESTADOS ---
enum State { IDLE, CHASE, EXPAND, VANISH, APPEAR, DEAD }

# --- VARIABLES ---
var current_health: int = MAX_HEALTH
var current_state: State = State.IDLE
var player: Node2D = null

var is_active: bool = false
var facing_left: bool = false
var current_size: float = 1.0 # Para controlar la escala del jefe (expansión)

# Temporizadores de la IA
var action_timer: float = 0.0
var state_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_hitbox: Area2D = $AttactHitBox
@onready var normal_hurtbox: Area2D = $NormalHurtBox

var damage_flash_tween: Tween = null
var action_tween: Tween = null


# --- CICLO PRINCIPAL ---

func _ready() -> void:
    current_health = MAX_HEALTH
    player = get_tree().get_first_node_in_group("player")
    
    if not body_hitbox.area_entered.is_connected(_on_attack_hitbox_area_entered):
        body_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
    if not normal_hurtbox.area_entered.is_connected(_on_normal_hurtbox_area_entered):
        normal_hurtbox.area_entered.connect(_on_normal_hurtbox_area_entered)
        
    _enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
    if not is_active or current_state == State.DEAD:
        return

    # Girar hacia el jugador si está persiguiendo o parado
    if player and current_state in [State.CHASE, State.EXPAND]:
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


# --- MANEJO DE ESTADOS ---

func _enter_state(new_state: State) -> void:
    current_state = new_state

    match new_state:
        State.IDLE:
            is_active = false
            
        State.CHASE:
            # Vuelve a su estado normal de daño y colisiones
            modulate.a = 1.0
            current_size = 1.0
            _set_hitboxes_active(true)
            action_timer = randf_range(4.0, 7.0) # Persigue entre 4 y 7 segundos antes de hacer un ataque
            
        State.EXPAND:
            state_timer = 3.0 # El ataque dura 3 segundos en total
            _start_expansion()
            
        State.VANISH:
            state_timer = 1.0 # Tarda 1 segundo en desaparecer
            _set_hitboxes_active(false) # Ya no hace daño ni lo recibe
            
            if action_tween: action_tween.kill()
            action_tween = create_tween()
            action_tween.tween_property(self, "modulate:a", 0.0, 1.0) # Se vuelve invisible
            
        State.APPEAR:
            state_timer = 1.5 # 1s de advertencia + 0.5s letal
            if player:
                global_position = player.global_position # Se teletransporta a Iris
                
            if action_tween: action_tween.kill()
            action_tween = create_tween()
            # Se vuelve semitransparente rápido para avisar al jugador
            action_tween.tween_property(self, "modulate:a", 0.4, 0.2) 
            
        State.DEAD:
            if action_tween: action_tween.kill()
            _set_hitboxes_active(false)
            modulate.a = 1.0
            
            var boss_room = get_tree().get_first_node_in_group("boss_room")
            if boss_room and boss_room.has_method("on_boss_defeated"):
                boss_room.on_boss_defeated()
                
            queue_free()


# --- FUNCIONES DE ESTADO ---

func _state_chase(delta: float) -> void:
    if not player: return
    
    # Flota lentamente hacia el jugador (en X y en Y)
    var direction = (player.global_position - global_position).normalized()
    global_position += direction * CHASE_SPEED * delta
    
    # Decide su próximo ataque
    action_timer -= delta
    if action_timer <= 0:
        if randf() > 0.5:
            _enter_state(State.EXPAND)
        else:
            _enter_state(State.VANISH)

func _state_expand(delta: float) -> void:
    # Se queda quieto mientras crece
    state_timer -= delta
    if state_timer <= 0:
        _enter_state(State.CHASE)

func _state_vanish(delta: float) -> void:
    # Se queda quieto desvaneciéndose
    state_timer -= delta
    if state_timer <= 0:
        _enter_state(State.APPEAR)

func _state_appear(delta: float) -> void:
    # Está apareciendo encima del jugador
    state_timer -= delta
    
    # Cuando queda medio segundo, se vuelve sólido y letal
    if state_timer <= 0.5 and not body_hitbox.monitoring:
        modulate.a = 1.0
        _set_hitboxes_active(true)
        
    if state_timer <= 0:
        _enter_state(State.CHASE)


# --- FUNCIONES AUXILIARES ---

func activate() -> void:
    is_active = true
    _enter_state(State.CHASE)

func _update_facing() -> void:
    # Mantiene la escala del tamaño (current_size) y la voltea si mira a la izquierda
    var dir_sign = -1.0 if facing_left else 1.0
    scale = Vector2(current_size * dir_sign, current_size)

func _set_hitboxes_active(active: bool) -> void:
    body_hitbox.set_deferred("monitoring", active)
    body_hitbox.set_deferred("monitorable", active)
    normal_hurtbox.set_deferred("monitoring", active)
    normal_hurtbox.set_deferred("monitorable", active)

func _start_expansion() -> void:
    if action_tween: action_tween.kill()
    action_tween = create_tween()
    
    # Crece al doble de su tamaño en 0.5 segundos
    action_tween.tween_property(self, "current_size", 2.0, 0.5)
    # Se queda grande durante 1.5 segundos
    action_tween.tween_interval(1.5)
    # Vuelve a su tamaño original en 0.5 segundos
    action_tween.tween_property(self, "current_size", 1.0, 0.5)


# --- COMBATE ---

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
    if current_state == State.DEAD: return
    
    if area.is_in_group("player_hurtbox"):
        var hit_player = area.get_parent()
        
        if hit_player.has_method("take_damage"):
            hit_player.take_damage(DAMAGE)
            
        # Empujón genérico al jugador si tiene la función (como hicimos antes)
        if hit_player.has_method("apply_knockback"):
            var push_dir = (hit_player.global_position - global_position).normalized()
            hit_player.apply_knockback(push_dir * 350.0)

func _on_normal_hurtbox_area_entered(area: Area2D) -> void:
    if current_state == State.DEAD: return
    
    if area.is_in_group("player_hitbox"):
        # Ignoramos el sistema complejo de multiplicadores por ahora para simplificar
        take_damage(1) 

func take_damage(amount: int) -> void:
    if current_state == State.DEAD: return
    
    # Si está invisible apareciendo/desapareciendo, no recibe daño
    if current_state in [State.VANISH, State.APPEAR] and not normal_hurtbox.monitoring:
        return

    current_health -= amount
    _play_damage_flash()

    if current_health <= 0:
        _enter_state(State.DEAD)

func _play_damage_flash() -> void:
    if damage_flash_tween: damage_flash_tween.kill()
    damage_flash_tween = create_tween()
    
    sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
    # Respeta el alfa actual por si estaba transparente al recibir el golpe justo al aparecer
    var target_color = Color(1.0, 1.0, 1.0, modulate.a) 
    damage_flash_tween.tween_property(sprite, "modulate", target_color, DAMAGE_FLASH_TIME)