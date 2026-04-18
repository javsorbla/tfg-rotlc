extends Area2D

const LIFETIME: float = 2.8
const WARNING_TIME: float = 0.8
const DAMAGE: int = 2

@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionPolygon2D

var active: bool = false

func _ready():
	area_entered.connect(_on_area_entered)

	sprite.play("base")
	sprite.frame = 0
	
	if collision:
		collision.disabled = true
	
	active = false
	
	_start_attack_sequence()


func _start_attack_sequence():
	await get_tree().create_timer(WARNING_TIME).timeout
	
	active = true
	sprite.play("chorro")
	
	if collision:
		collision.disabled = false
	
	await get_tree().create_timer(LIFETIME - WARNING_TIME).timeout
	queue_free()


func _on_area_entered(area: Area2D):
	if not active:
		return
		
	if area.is_in_group("player_hurtbox"):
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			return
		
		var health_node = player.get_node_or_null("Health")
		if health_node and health_node.has_method("take_damage"):
			health_node.take_damage(DAMAGE)
