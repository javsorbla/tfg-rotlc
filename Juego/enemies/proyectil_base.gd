class_name ProyectilBase
extends Area2D

var direction: Vector2 = Vector2.ZERO
var source_enemy: Node = null
var can_hit_source: bool = false


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)


func _physics_process(delta: float) -> void:
	position += direction * get_speed() * delta


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.get("is_shielding") == true:
			direction = -direction
			rotation = direction.angle()
			can_hit_source = true
			return
		_hit_player(body)
		queue_free()
		return
	
	# Si el ataque reflejado impacta al enemigo que lo lanza, le hace daño
	if body == source_enemy:
		if can_hit_source and source_enemy.has_method("take_damage"):
			source_enemy.take_damage(get_damage())
			queue_free()
		return
	
	queue_free()


func _hit_player(body: Node) -> void:
	var health = body.get_node("Health")
	if health:
		health.take_damage(get_damage())


func get_speed() -> float:
	return 200.0


func get_damage() -> int:
	return 2


func _on_screen_exited() -> void:
	queue_free()
