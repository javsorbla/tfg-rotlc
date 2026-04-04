extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var health = body.get_node_or_null("Health")
	if health == null:
		return

	if health.current_health >= health.MAX_HEALTH:
		return

	health.current_health += 1
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_hearts(health.current_health, health.MAX_HEALTH)

	queue_free()
