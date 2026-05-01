extends Area2D

const FALL_SPEED: float = 250.0 # Reducido (antes 300) para dar más tiempo
const DAMAGE: int = 1

var is_falling: bool = false # Controla si ya está cayendo

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# --- EL AVISO (Telegraph) ---
	modulate.a = 0.4 # Aparece medio transparente
	await get_tree().create_timer(1.0).timeout # Se queda suspendido 1 segundo
	
	modulate.a = 1.0 # Se vuelve opaco
	is_falling = true # ¡Empieza a caer!
	# -----------------------------
	
	get_tree().create_timer(6.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Solo cae si ya ha pasado el segundo de aviso
	if is_falling:
		global_position.y += FALL_SPEED * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var hit_player = area.get_parent()
		var health_node = hit_player.get_node_or_null("Health")
		
		if health_node and health_node.has_method("take_damage"):
			if not health_node.is_invincible and not hit_player.is_shielding:
				health_node.take_damage(DAMAGE)
				queue_free()

func _on_body_entered(body: Node2D) -> void:
	queue_free()