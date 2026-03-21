extends CharacterBody2D

# --- CONSTANTES ---
const MAX_HEALTH: int = 3
const DAMAGE: int = 1
const PATROL_SPEED: float = 40.0
const CHASE_SPEED: float = 90.0
const JUMP_VELOCITY: float = -300.0 # ¡Fuerza del salto!
const DETECTION_DISTANCE: float = 180.0
const PATROL_X_RANGE: float = 80.0
const STUN_DURATION: float = 0.4

# --- ESTADOS ---
enum State { IDLE, PATROL, CHASE, STUNNED, DEAD }

# --- VARIABLES ---
var current_state: State = State.IDLE
var current_health: int = MAX_HEALTH
var player: Node2D = null
var facing_dir: float = 1.0 
var stun_timer: float = 0.0

var idle_timer: float = 0.0
var patrol_timer: float = 0.0
var patrol_origin_x: float = 0.0

# ¡LA SOLUCIÓN A LA VIBRACIÓN! Un temporizador que prohíbe girar muy rápido
var flip_cooldown: float = 0.0 

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision: RayCast2D = $Vision

func _ready() -> void:
    current_health = MAX_HEALTH
    player = get_tree().get_first_node_in_group("player")
    
    patrol_origin_x = global_position.x

    if not $EnemyHitbox.area_entered.is_connected(_on_enemy_hitbox_area_entered):
        $EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)
    if not $EnemyHurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
        $EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)

    vision.target_position = Vector2(20, 40) 
    _enter_state(State.IDLE)

func _physics_process(delta: float) -> void:
    # Reducimos el cooldown de giro
    if flip_cooldown > 0:
        flip_cooldown -= delta

    # Gravedad
    if not is_on_floor():
        velocity += get_gravity() * delta

    match current_state:
        State.IDLE:
            _state_idle(delta)
        State.PATROL:
            _state_patrol(delta)
        State.CHASE:
            _state_chase()
        State.STUNNED:
            _state_stunned(delta)
        State.DEAD:
            velocity.x = move_toward(velocity.x, 0, 200 * delta)

    move_and_slide()

# --- MANEJO DE ESTADOS ---

func _enter_state(new_state: State) -> void:
    current_state = new_state

    match new_state:
        State.IDLE:
            velocity.x = 0
            sprite.play("iddle")
            idle_timer = randf_range(1.0, 2.5) 
        State.PATROL:
            patrol_timer = randf_range(2.0, 4.0) 
        State.STUNNED:
            sprite.play("stun")
        State.DEAD:
            sprite.play("dead")
            if $EnemyHitbox:
                $EnemyHitbox.set_deferred("monitoring", false)
                $EnemyHitbox.set_deferred("monitorable", false)
                $EnemyHitbox.set_deferred("collision_layer", 0)
                $EnemyHitbox.set_deferred("collision_mask", 0)
            velocity.x = 0

func _check_for_player() -> bool:
    if player:
        var dist = global_position.distance_to(player.global_position)
        # Ampliamos un poco la detección en Y por si el jugador está en una plataforma alta
        if dist <= DETECTION_DISTANCE and abs(player.global_position.y - global_position.y) < 100:
            _enter_state(State.CHASE)
            return true
    return false

func _state_idle(delta: float) -> void:
    if _check_for_player():
        return

    idle_timer -= delta
    if idle_timer <= 0:
        _enter_state(State.PATROL)

func _state_patrol(delta: float) -> void:
    if _check_for_player():
        return

    velocity.x = facing_dir * PATROL_SPEED
    
    # Manejo de animaciones (suelo vs aire)
    if is_on_floor():
        if sprite.animation != "run":
            sprite.play("run")
    else:
        # CÁMBIALO A "jump" CUANDO LE PONGAS UN DIBUJO AL SPRITEFRAME
        sprite.play("run") 

    patrol_timer -= delta
    if patrol_timer <= 0 and is_on_floor():
        _enter_state(State.IDLE)
        return

    # Límites de la patrulla
    var reached_limit_right = (global_position.x >= patrol_origin_x + PATROL_X_RANGE) and facing_dir == 1.0
    var reached_limit_left = (global_position.x <= patrol_origin_x - PATROL_X_RANGE) and facing_dir == -1.0

    if (reached_limit_right or reached_limit_left) and is_on_floor():
        _flip()
        _enter_state(State.IDLE)
        return

    # Detección de obstáculos
    var hit_ledge = not vision.is_colliding()
    var hit_wall = is_on_wall() and sign(get_wall_normal().x) == -sign(facing_dir)

    if is_on_floor():
        if hit_wall or hit_ledge:
            # ¡Si toca muro o barranco, SALTA!
            velocity.y = JUMP_VELOCITY
    else:
        # Si está en el aire y choca con un muro, el muro es muy alto. Se da la vuelta.
        if hit_wall:
            _flip()

func _state_chase() -> void:
    if not player:
        _enter_state(State.IDLE)
        return

    var dist = global_position.distance_to(player.global_position)
    if dist > DETECTION_DISTANCE * 1.5:
        patrol_origin_x = global_position.x
        _enter_state(State.IDLE)
        return

    var x_diff = player.global_position.x - global_position.x
    
    # Solo puede decidir darse la vuelta si está en el suelo (evita giros raros en el aire)
    if abs(x_diff) > 5.0 and is_on_floor():
        var dir_to_player = sign(x_diff)
        if dir_to_player != 0 and dir_to_player != facing_dir:
            _flip()

    velocity.x = facing_dir * CHASE_SPEED

    if is_on_floor():
        if sprite.animation != "run":
            sprite.play("run")
    else:
        sprite.play("run") # CÁMBIALO A "jump" CUANDO TENGAS LA ANIMACIÓN

    var hit_ledge = not vision.is_colliding()
    var hit_wall = is_on_wall() and sign(get_wall_normal().x) == -sign(facing_dir)

    if is_on_floor():
        if hit_wall or hit_ledge:
            # ¡Salta para perseguirte!
            velocity.y = JUMP_VELOCITY
    else:
        if hit_wall:
            # Si el muro es inalcanzable, frena para caer recto
            velocity.x = 0

func _state_stunned(delta: float) -> void:
    stun_timer -= delta
    velocity.x = move_toward(velocity.x, 0, 200 * delta)

    if stun_timer <= 0:
        _enter_state(State.IDLE)

# --- FUNCIONES AUXILIARES ---

func _flip() -> void:
    # Si el cooldown está activo, ignoramos la orden de giro (adiós vibración)
    if flip_cooldown > 0:
        return
        
    facing_dir *= -1.0
    sprite.flip_h = (facing_dir < 0)
    vision.target_position.x = abs(vision.target_position.x) * facing_dir
    
    # Activamos el cooldown de 0.3 segundos
    flip_cooldown = 0.3

# --- COMBATE ---

func _on_enemy_hitbox_area_entered(area: Area2D) -> void:
    if current_state == State.DEAD:
        return

    if area.is_in_group("player_hurtbox"):
        var hit_player = area.get_parent()
        if hit_player.has_method("take_damage"):
            hit_player.take_damage(DAMAGE)
            
        if hit_player is CharacterBody2D:
            var dir = (hit_player.global_position - global_position).normalized()
            dir.y = 0
            hit_player.velocity = dir * 150

func _on_enemy_hurtbox_area_entered(area: Area2D) -> void:
    if area.is_in_group("player_hitbox"):
        take_damage(1)

func take_damage(amount: int) -> void:
    if current_state == State.DEAD:
        return

    current_health -= amount
    if current_health <= 0:
        die()
        return

    stun_timer = STUN_DURATION
    _enter_state(State.STUNNED)

func die() -> void:
    _enter_state(State.DEAD)