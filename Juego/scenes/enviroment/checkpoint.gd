extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var activated: bool = false
@onready var light2d: Node = $PointLight2D

func _ready() -> void:
	if sprite and sprite.sprite_frames:
		sprite.stop()
		if sprite.animation == "" and sprite.sprite_frames.get_animation_names().size() > 0:
			sprite.animation = sprite.sprite_frames.get_animation_names()[0]
		sprite.frame = 0
	# ensure the point light is hidden until activation
	if light2d:
		light2d.visible = false
		# start with zero energy so it's off
		if light2d.has_method("set") or true:
			# direct property access
			light2d.energy = 0.0
	connect("body_entered", Callable(self, "_on_body_entered"))
	if sprite:
		sprite.animation_finished.connect(Callable(self, "_on_sprite_animation_finished"))

func _on_body_entered(body: Node) -> void:
	if activated:
		return
	if not body or not body.is_in_group("player"):
		return
	activated = true
	# Activate checkpoint in GameState
	if Engine.has_singleton("GameState"):
		# GameState is an autoload; call its method
		GameState.activate_checkpoint(global_position)
	else:
		GameState.activate_checkpoint(global_position)

	# Play activate animation (non-looping) and let handler set final frame
	if sprite and sprite.sprite_frames:
		var anim := "activate"
		if sprite.sprite_frames.has_animation(anim):
			# ensure non-looping
			# ensure the light becomes visible and fades in
			if light2d:
				light2d.visible = true
				light2d.energy = 0.0
				var tw = get_tree().create_tween()
				tw.tween_property(light2d, "energy", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			sprite.sprite_frames.set_animation_loop(anim, false)
			sprite.play(anim)
		else:
			var anim_name := sprite.animation
			var count := 0
			if anim_name != "":
				count = sprite.sprite_frames.get_frame_count(anim_name)
			if count > 0:
				sprite.stop()
				sprite.frame = count - 1
			else:
				sprite.stop()


func _on_sprite_animation_finished() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var anim_name := sprite.animation
	if anim_name == "activate":
		var cnt := sprite.sprite_frames.get_frame_count(anim_name)
		if cnt > 0:
			sprite.stop()
			sprite.frame = cnt - 1
