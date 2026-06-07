extends Area2D

const LIFETIME: float = 2.8
const WARNING_TIME: float = 0.8
const DAMAGE: int = 2
const MAX_LOOPS: int = 3
const CHORRO_LAVA := preload("res://music/enemies/bosses/coloso_ceniza/chorro_lava.ogg")

var loop_count: int = 0
var sfx_player: AudioStreamPlayer
var luz: PointLight2D

@onready var sprite = $AnimatedSprite2D
@onready var sprite_glow = $AnimatedSprite2DGlow
@onready var collision = $CollisionPolygon2D

var active: bool = false

func _ready():
	area_entered.connect(_on_area_entered)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = CHORRO_LAVA
	sfx_player.bus = &"EFX"
	sfx_player.volume_db = 4.0
	add_child(sfx_player)
	sfx_player.play()

	luz = PointLight2D.new()
	add_child(luz)
	luz.blend_mode = Light2D.BLEND_MODE_ADD
	luz.color = Color(1.0, 0.4, 0.05)
	luz.energy = 2.0
	luz.position = Vector2(0, -67)
	luz.texture_scale = 1.0
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in 64:
		for y in 64:
			var dx: float = (x - 32.0) / 32.0
			var dy: float = (y - 32.0) / 32.0
			var dist: float = sqrt(dx*dx + dy*dy)
			var alpha: float = clamp(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.5)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	luz.texture = ImageTexture.create_from_image(img)
	luz.scale = Vector2(2.0, 6.0)

	sprite.play("base")
	sprite.frame = 0
	sprite_glow.play("base")
	sprite_glow.frame = 0
	
	if collision:
		collision.disabled = true
	
	active = false
	
	_start_attack_sequence()


func _start_attack_sequence():
	await get_tree().create_timer(WARNING_TIME).timeout
	
	active = true
	sprite.play("eruption")
	sprite.frame_changed.connect(_on_eruption_frame_changed)
	
	if collision:
		collision.disabled = false
	
	await get_tree().create_timer(LIFETIME - WARNING_TIME - 0.5).timeout
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sfx_player, "volume_db", -60.0, 0.5)
	tween.tween_property(luz, "energy", 0.0, 0.5)
	await tween.finished
	queue_free()


func _process(_delta: float) -> void:
	sprite_glow.animation = sprite.animation
	sprite_glow.frame = sprite.frame
	sprite_glow.speed_scale = sprite.speed_scale


func _on_eruption_frame_changed():
	if sprite.animation != "eruption":
		return
	
	if sprite.frame == 6 and loop_count < MAX_LOOPS:
		loop_count += 1
		sprite.frame = 3


func _on_area_entered(area: Area2D):
	if not active:
		return
		
	if area.is_in_group("player_hurtbox"):
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			return
		
		var health_node = player.get_node_or_null("Health")
		if health_node and health_node.has_method("take_damage"):
			health_node.take_damage(DAMAGE)
