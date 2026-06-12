extends StaticBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var sfx_player: AudioStreamPlayer
var player_nearby := false
var zone_active := false


func _ready() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.sprite_frames.set_animation_loop("idle", true)
		animated_sprite.play("idle")

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "AntorchaSfx"
	sfx_player.stream = load("res://music/scenes/torre_vacio/antorcha.ogg")
	sfx_player.bus = &"EFX"
	sfx_player.volume_db = -6.0
	add_child(sfx_player)

	var zona = Area2D.new()
	zona.name = "ZonaProximidad"
	zona.collision_mask = 4
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(640, 640)
	shape.shape = rect
	zona.add_child(shape)
	zona.body_entered.connect(_on_body_entered)
	zona.body_exited.connect(_on_body_exited)
	add_child(zona)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		if not zone_active:
			zone_active = true
			sfx_player.play()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		zone_active = false
		sfx_player.stop()
