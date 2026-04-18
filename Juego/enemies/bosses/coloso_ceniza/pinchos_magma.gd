extends Area2D

const DAMAGE: int = 1
const LIFETIME: float = 0.9

var timer: float = 0.0

func _ready():
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	timer += delta
	if timer >= LIFETIME:
		queue_free()

func _on_area_entered(area: Area2D):
	if area.is_in_group("player_hurtbox"):
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			return
		
		var push_x = sign(player.global_position.x - global_position.x)
		player.velocity = Vector2(push_x * 150.0, -100.0)
		
		var health_node = player.get_node_or_null("Health")
		if health_node and health_node.has_method("take_damage"):
			health_node.take_damage(DAMAGE)
