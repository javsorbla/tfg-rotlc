extends Area2D

const BOB_AMPLITUDE := 4.0
const BOB_SPEED := 2.4
const SWAY_AMPLITUDE := 2.0
const SWAY_SPEED := 1.35
const SWAY_PHASE_OFFSET := 0.7

var _base_local_position := Vector2.ZERO
var _elapsed := 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("prism_core")
	_base_local_position = position
	body_entered.connect(_on_body_entered)
	if animated_sprite != null:
		animated_sprite.play("idle")


func _process(delta: float) -> void:
	_elapsed += delta
	var y_offset := sin(_elapsed * BOB_SPEED) * BOB_AMPLITUDE
	var x_offset := sin(_elapsed * SWAY_SPEED + SWAY_PHASE_OFFSET) * SWAY_AMPLITUDE
	position = _base_local_position + Vector2(x_offset, y_offset)


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return

	var health = body.get_node_or_null("Health")
	if health == null or not health.has_method("apply_prism_core_upgrade"):
		return

	health.apply_prism_core_upgrade()
	queue_free()
