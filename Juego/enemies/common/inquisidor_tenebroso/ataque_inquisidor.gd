extends Area2D

const SPEED: float = 200.0
const DAMAGE: int = 2

var direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var health = body.get_node("Health")
		if health:
			health.take_damage(DAMAGE)
	queue_free()


func _on_screen_exited() -> void:
	queue_free()
