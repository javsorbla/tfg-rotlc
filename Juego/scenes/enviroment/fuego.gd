extends Area2D

@export var damage_amount: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.sprite_frames.set_animation_loop("idle", true)
		animated_sprite.play("idle")

	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var player = area.owner
		var health = player.get_node_or_null("Health")
		if health and health.has_method("take_damage"):
			health.take_damage(damage_amount)
