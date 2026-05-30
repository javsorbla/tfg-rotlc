extends StaticBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.sprite_frames.set_animation_loop("idle", true)
		animated_sprite.play("idle")
