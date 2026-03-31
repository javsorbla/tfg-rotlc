extends ProyectilBase

const REFLECT_SPEED_MULT: float = 1.2
const REFLECT_DAMAGE: int = 1
var current_speed: float = get_speed()
var is_reflected: bool = false

func get_speed() -> float:
	return 330.0

func get_damage() -> int:
	return 1

func init(dir: Vector2) -> void:
	direction = dir
	current_speed = get_speed()
	rotation = direction.angle()

func _ready() -> void:
	super._ready()
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * current_speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.get("is_shielding") == true:
			direction = -direction
			rotation = direction.angle()
			return
		if is_reflected:
			return
		var health = body.get_node("Health")
		if health:
			health.take_damage(get_damage())
		queue_free()
		return
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		if is_reflected:
			queue_free()
			return
		_reflect_towards_boss()
		return

	if is_reflected and (area.is_in_group("boss_core") or area.is_in_group("enemy_hurtbox")):
		var boss = area.get_parent()
		if boss and boss.is_in_group("boss") and boss.has_method("take_damage"):
			boss.take_damage(REFLECT_DAMAGE)
		queue_free()

func _reflect_towards_boss() -> void:
	is_reflected = true
	current_speed = get_speed() * REFLECT_SPEED_MULT
	collision_mask = 21
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		direction = (boss.global_position - global_position).normalized()
	else:
		direction = -direction
	rotation = direction.angle()
