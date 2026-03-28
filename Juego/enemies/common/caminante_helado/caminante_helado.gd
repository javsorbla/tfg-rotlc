extends CharacterBody2D

# --- CONSTANTES BASE ---
const MAX_HEALTH: int = 3
const DAMAGE: int = 1
const PATROL_SPEED: float = 30.0
const CHASE_SPEED: float = 60.0
const DETECTION_DISTANCE: float = 220.0 
const PATROL_X_RANGE: float = 48.0
const STUN_DURATION: float = 0.5
const HIT_PAUSE_DURATION: float = 1.1 # 1.1 segundos de pausa tras pegar al jugador

# --- ESTADOS ---
enum State { IDLE, PATROL, CHASE, STUNNED, DEAD, ATTACK_PAUSE }

# --- VARIABLES ---
var current_state: State = State.IDLE
var current_health: int = MAX_HEALTH
var player: Node2D = null
var facing_dir: float = -1.0 
var patrol_origin_x: float = 0.0

var stun_timer: float = 0.0
var idle_timer: float = 0.0
var patrol_timer: float = 0.0
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

    # Configuramos el rayo de visión para que mire al suelo diagonalmente
    vision.target_position = Vector2(20 * facing_dir, 40) 
    _enter_state(State.IDLE)

func _physics_process(delta: float) -> void:
    if flip_cooldown > 0: flip_cooldown -= delta

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
        State.ATTACK_PAUSE:
            _state_attack_pause(delta)
        State.DEAD:
            velocity.x = move_toward(velocity.x, 0, 200 * delta)

    move_and_slide()
    _update_animations()

# --- LÓGICA DE ANIMACIÓN ---
func _update_animations() -> void:
    if current_state in [State.STUNNED, State.DEAD, State.ATTACK_PAUSE]:
        return 
        
    if current_state == State.IDLE:
        sprite.play("idle")
    elif current_state in [State.PATROL, State.CHASE]:
        if facing_dir < 0:
            sprite.play("walk_left")
        else:
            sprite.play("walk_right")

# --- MANEJO DE ESTADOS ---
func _enter_state(new_state: State) -> void:
    current_state = new_state
    sprite.modulate.a = 1.0

    match new_state:
        State.IDLE:
            velocity.x = 0
            idle_timer = randf_range(1.0, 2.5) 
        State.PATROL:
            patrol_timer = randf_range(2.0, 4.0) 
        State.CHASE:
            pass 
        State.ATTACK_PAUSE:
            sprite.play("idle") 
            velocity.x = 0 
        State.STUNNED:
            sprite.play("dazed") 
            velocity.x = 0 
        State.DEAD:
            sprite.play("dead") 
            if $EnemyHitbox:
                $EnemyHitbox.set_deferred("monitoring", false)
                $EnemyHitbox.set_deferred("monitorable", false)
                $EnemyHitbox.set_deferred("collision_layer", 0)
                $EnemyHitbox.set_deferred("collision_mask", 0)
            velocity.x = 0
            await get_tree().create_timer(1.5).timeout
            queue_free()

# --- LÓGICA DE VISIÓN ---
func _has_line_of_sight() -> bool:
    if not player: return false
    var space_state = get_world_2d().direct_space_state
    var eye_pos = global_position + Vector2(0, -10)
    var target_pos = player.global_position + Vector2(0, -10)
    var query = PhysicsRayQueryParameters2D.create(eye_pos, target_pos)
    query.collision_mask = 1 
    var result = space_state.intersect_ray(query)
    return result.is_empty() 

func _check_for_player() -> bool:
    if player:
        var dist = global_position.distance_to(player.global_position)
        if dist <= DETECTION_DISTANCE:
            var dir_to_player = sign(player.global_position.x - global_position.x)
            if dir_to_player == sign(facing_dir) or dir_to_player == 0:
                if _has_line_of_sight():
                    _enter_state(State.CHASE)
                    return true
    return false

# --- FUNCIONES DE ESTADO ---
func _state_idle(delta: float) -> void:
    if _check_for_player(): return
    idle_timer -= delta
    if idle_timer <= 0: _enter_state(State.PATROL)

func _state_patrol(delta: float) -> void:
    if _check_for_player(): return

    velocity.x = facing_dir * PATROL_SPEED

    patrol_timer -= delta
    if patrol_timer <= 0 and is_on_floor():
        _enter_state(State.IDLE)
        return

    var reached_limit_right = (global_position.x >= patrol_origin_x + PATROL_X_RANGE) and facing_dir == 1.0
    var reached_limit_left = (global_position.x <= patrol_origin_x - PATROL_X_RANGE) and facing_dir == -1.0

    if (reached_limit_right or reached_limit_left) and is_on_floor():
        _flip()
        _enter_state(State.IDLE)
        return

    var hit_ledge = not vision.is_colliding()
    var hit_wall = is_on_wall() and sign(get_wall_normal().x) == -sign(facing_dir)

    if is_on_floor():
        if hit_wall or hit_ledge:
            _flip()
            _enter_state(State.IDLE)

func _state_chase() -> void:
    if not player or not _has_line_of_sight():
        patrol_origin_x = global_position.x
        _enter_state(State.IDLE)
        return

    var dist = global_position.distance_to(player.global_position)
    if dist > DETECTION_DISTANCE * 1.5:
        patrol_origin_x = global_position.x
        _enter_state(State.IDLE)
        return

    var x_diff = player.global_position.x - global_position.x
    if abs(x_diff) > 5.0 and is_on_floor():
        var dir_to_player = sign(x_diff)
        if dir_to_player != 0 and dir_to_player != facing_dir:
            _flip()

    velocity.x = facing_dir * CHASE_SPEED

    var hit_ledge = not vision.is_colliding()
    var hit_wall = is_on_wall() and sign(get_wall_normal().x) == -sign(facing_dir)

    if is_on_floor():
        if hit_wall or hit_ledge:
            velocity.x = 0

func _state_stunned(delta: float) -> void:
    stun_timer -= delta
    sprite.modulate.a = 1.0 if int(stun_timer * 10) % 2 == 0 else 0.5
    if stun_timer <= 0: 
        _enter_state(State.IDLE)

func _state_attack_pause(delta: float) -> void:
    stun_timer -= delta
    if stun_timer <= 0:
        _enter_state(State.IDLE)

# --- FUNCIONES AUXILIARES ---
func _flip() -> void:
    if flip_cooldown > 0: return
    facing_dir *= -1.0
    vision.target_position.x = abs(vision.target_position.x) * facing_dir
    flip_cooldown = 0.3

# --- COMBATE ---
func _on_enemy_hitbox_area_entered(area: Area2D) -> void:
    if current_state == State.DEAD: return
    
    if area.is_in_group("player_hurtbox"):
        var hit_player = area.get_parent()
        
        if hit_player.has_method("take_damage"):
            hit_player.take_damage(DAMAGE)
            
        # Knockback directo (sin bloquear controles del jugador)
        if hit_player is CharacterBody2D:
            var push_x = sign(hit_player.global_position.x - global_position.x)
            if push_x == 0: push_x = facing_dir
            
            var knock_direction = Vector2(push_x * 0.45, -1.0).normalized()
            hit_player.velocity = knock_direction * 350.0 
            
        stun_timer = HIT_PAUSE_DURATION
        _enter_state(State.ATTACK_PAUSE)

func _on_enemy_hurtbox_area_entered(area: Area2D) -> void:
    if area.is_in_group("player_hitbox"): 
        take_damage(1)

func take_damage(amount: int) -> void:
    if current_state == State.DEAD or current_state == State.STUNNED: return
    
    current_health -= amount
    if current_health <= 0:
        die()
        return
        
    if player:
        var dir_to_player = sign(player.global_position.x - global_position.x)
        if dir_to_player != 0 and dir_to_player != sign(facing_dir):
            flip_cooldown = 0.0
            _flip()

    stun_timer = STUN_DURATION
    _enter_state(State.STUNNED)

func die() -> void:
    _enter_state(State.DEAD)