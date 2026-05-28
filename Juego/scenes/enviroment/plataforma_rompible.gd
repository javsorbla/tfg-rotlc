extends AnimatableBody2D

const SHAKE_DURATION = 1    # tiempo temblando antes de romperse
const BREAK_DELAY = 0.3      # tiempo entre temblor y rotura
const RESPAWN_TIME = 3.0      # tiempo hasta que reaparece

var is_shaking = false
var shake_timer = 0.0
var original_position: Vector2

@onready var collision = $CollisionShape2D
@onready var sprite = $Sprite2D

func _ready():
	original_position = global_position

func _physics_process(delta):
	if not is_shaking:
		return
	shake_timer -= delta
	# Temblor
	if shake_timer > BREAK_DELAY:
		var t = SHAKE_DURATION - shake_timer  # tiempo transcurrido desde el inicio
		sprite.position.x = sin(t * 40) * 2.0
	# Romper
	elif shake_timer <= 0:
		_break()

func _break():
	is_shaking = false
	sprite.visible = false
	collision.disabled = true
	await get_tree().create_timer(RESPAWN_TIME).timeout
	_respawn()

func _respawn():
	sprite.position.x = 0
	sprite.visible = true
	collision.disabled = false
	global_position = original_position


func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_shaking:
		is_shaking = true
		shake_timer = SHAKE_DURATION
		sprite.position.x = 0
