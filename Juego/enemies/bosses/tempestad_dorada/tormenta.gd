extends Area2D

const LIFETIME: float = 1.3
const WARNING_TIME: float = 0.8
const DAMAGE: int = 1

var active: bool = false
var damage_done: bool = false

@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

func _ready():
	add_to_group("rayo_cielo")
	sprite.play("inicio")
	if collision:
		collision.disabled = true
	area_entered.connect(_on_area_entered)
	_start_sequence()

func _start_sequence():
	await get_tree().create_timer(WARNING_TIME).timeout
	active = true
	sprite.play("rayo")
	if collision:
		collision.disabled = false
	await get_tree().create_timer(LIFETIME - WARNING_TIME).timeout
	queue_free()

func _on_area_entered(area: Area2D):
	if not active or damage_done:
		return
	if area.is_in_group("player_hurtbox"):
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			return
		var health_node = player.get_node_or_null("Health")
		if health_node and health_node.has_method("take_damage"):
			health_node.take_damage(DAMAGE)
			damage_done = true
