extends Node2D

const SHAKE_DURATION = 1.0
const BREAK_DELAY = 0.3
const RESPAWN_TIME = 3.0

var is_shaking = false
var shake_timer = 0.0
var original_position: Vector2

@onready var tilemap = $TileMapLayer
@onready var detector = $Detector

func _ready():
	original_position = global_position

func _physics_process(delta):
	if not is_shaking:
		return
	shake_timer -= delta

	if shake_timer > BREAK_DELAY:
		var t = SHAKE_DURATION - shake_timer
		tilemap.position.x = sin(t * 40) * 2.0
	elif shake_timer <= 0:
		_break()

func _break():
	is_shaking = false
	tilemap.visible = false
	tilemap.set_collision_enabled(false)
	await get_tree().create_timer(RESPAWN_TIME).timeout
	_respawn()

func _respawn():
	tilemap.position.x = 0
	tilemap.visible = true
	tilemap.set_collision_enabled(true)
	global_position = original_position

func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_shaking:
		# Verificar que el jugador viene desde arriba
		if body.global_position.y < global_position.y:
			is_shaking = true
			shake_timer = SHAKE_DURATION
			tilemap.position.x = 0
