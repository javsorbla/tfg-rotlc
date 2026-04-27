extends Node2D

const DAMAGE: int = 1

var active: bool = false
var damage_timer: float = 0.0

@onready var hitbox = $RayoHitbox
@onready var shape = $RayoHitbox/CollisionShape2D

func update_hitbox(start: Vector2, end: Vector2):
	var diff = end - start
	hitbox.global_position = start + diff * 0.5
	hitbox.rotation = diff.angle() + deg_to_rad(90.0)
	if shape.shape is RectangleShape2D:
		shape.shape.size = Vector2(20.0, diff.length())

func _ready():
	if not hitbox:
		return
	if not hitbox.is_in_group("enemy_hitbox"):
		hitbox.add_to_group("enemy_hitbox")

func _physics_process(delta):
	if not active:
		return
	if damage_timer > 0.0:
		damage_timer -= delta
		return
	for area in hitbox.get_overlapping_areas():
		if area.is_in_group("player_hurtbox"):
			var player = get_tree().get_first_node_in_group("player")
			if not player:
				return
			var health_node = player.get_node_or_null("Health")
			if health_node and health_node.has_method("take_damage"):
				health_node.take_damage(DAMAGE)
				return
