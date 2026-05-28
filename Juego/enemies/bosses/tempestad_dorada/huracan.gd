extends Area2D

const LIFETIME: float = 6.5
const WARNING_TIME: float = 1.0
const DAMAGE: int = 2
const MOVE_SPEED_START: float = 20.0
const MOVE_SPEED_MAX: float = 120.0
const PULL_RANGE: float = 80.0
const PULL_ROTATE_SPEED: float = 6.0
const PULL_RADIUS_START: float = 60.0
const PULL_RADIUS_SHRINK: float = 4.0
const PULL_RISE_SPEED: float = 30.0
const LAUNCH_SPEED: float = 400.0
const LAUNCH_DURATION: float = 0.5
const MAX_PULL_TIME: float = 2.0

@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionPolygon2D

var active: bool = false
var player = null
var move_speed: float = MOVE_SPEED_START
var active_time: float = 0.0

var pull_angle: float = 0.0
var pulling: bool = false
var pull_radius: float = 0.0
var pull_center: Vector2 = Vector2.ZERO
var pull_zigzag_time: float = 0.0
var pull_time: float = 0.0
var launched: bool = false
var launch_timer: float = 0.0
var launch_velocity: Vector2 = Vector2.ZERO
var room_bottom_limit: float = 10000.0
var room_left_limit: float = -10000.0
var room_right_limit: float = 10000.0

func _ready():
	add_to_group("hurricane")
	sprite.play("inicio")
	sprite.frame = 0
	
	if collision:
		collision.disabled = true
	
	active = false
	player = get_tree().get_first_node_in_group("player")
	_start_attack_sequence()


func _start_attack_sequence():
	await get_tree().create_timer(WARNING_TIME).timeout
	active = true
	sprite.play("huracan")

	await get_tree().create_timer(LIFETIME - WARNING_TIME).timeout
	if pulling and not launched:
		_launch_player()
	queue_free()

func _physics_process(delta):
	if not active or not player:
		return

	active_time += delta
	var active_duration = LIFETIME - WARNING_TIME
	move_speed = lerp(MOVE_SPEED_START, MOVE_SPEED_MAX, active_time / active_duration)

	var to_player_x = player.global_position.x - global_position.x
	var dist_x = abs(to_player_x)

	if pulling and not launched:
		pull_time += delta

		if pull_time >= MAX_PULL_TIME or pull_radius <= 15.0:
			_launch_player()
			return 

		pull_radius = max(pull_radius - PULL_RADIUS_SHRINK * delta, 0.0)
		pull_angle += PULL_ROTATE_SPEED * delta
		pull_center.y -= PULL_RISE_SPEED * delta

		var offset = Vector2(cos(pull_angle), sin(pull_angle)) * pull_radius
		var new_pos = pull_center + offset
		new_pos.y = min(new_pos.y, room_bottom_limit - 20.0)
		player.global_position = new_pos
		
	elif not pulling and not launched and launch_timer <= 0.0:
		var dist_y = abs(player.global_position.y - global_position.y)
		if dist_x < PULL_RANGE and dist_y < PULL_RANGE * 2.0:
			pulling = true
			pull_radius = clamp((player.global_position - global_position).length(), 20.0, 80.0)
			pull_angle = (player.global_position - global_position).angle()
			pull_center = player.global_position - Vector2(cos(pull_angle), sin(pull_angle)) * pull_radius
			pull_time = 0.0
		else:
			position.x += sign(to_player_x) * move_speed * delta
	
	if launch_timer > 0.0:
		launch_timer -= delta
		launch_velocity.y += 50.0 * delta
		player.global_position += launch_velocity * delta
		player.global_position.x = clamp(player.global_position.x, room_left_limit, room_right_limit)
		if player.global_position.y >= room_bottom_limit - 20.0:
			player.global_position.y = room_bottom_limit - 20.0
			launch_timer = 0.0

func _launch_player():
	if launched:
		return
	launched = true
	pulling = false
	var health_node = player.get_node_or_null("Health")
	if health_node and health_node.has_method("take_damage"):
		health_node.take_damage(DAMAGE)
	var side = 1.0 if randf() > 0.5 else -1.0
	launch_velocity = Vector2(side * 400.0, -400.0)
	launch_timer = LAUNCH_DURATION
