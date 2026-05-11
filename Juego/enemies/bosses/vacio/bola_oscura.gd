extends Area2D

const SPEED: float = 200.0
const DAMAGE: int = 2

var direction: Vector2 = Vector2.ZERO
var can_hit_source: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

func _on_area_entered(area: Area2D) -> void:
	
	if area.is_in_group("player_hurtbox"):
		# Si ya fue reflejada, ignora nuevas colisiones con el jugador
		if can_hit_source:
			return
		
		var hit_player = area.get_parent()

		
		if hit_player.is_shielding:
			
			direction = -direction
			can_hit_source = true
			return

		
		var health_node = hit_player.get_node_or_null("Health")
		if health_node and health_node.has_method("take_damage"):
			if not health_node.is_invincible:
				health_node.take_damage(DAMAGE)
				queue_free()
		return

	
	if can_hit_source and (area.is_in_group("boss_hurtbox") or area.is_in_group("enemy_hurtbox") or area.is_in_group("boss_core")):
		var boss = area.get_parent()
		if boss and boss.has_method("take_damage"):
			boss.take_damage(1)
			queue_free()

func _on_screen_exited() -> void:
	queue_free()
