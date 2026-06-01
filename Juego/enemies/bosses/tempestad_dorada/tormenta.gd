extends Area2D

const LIFETIME: float = 1.3
const WARNING_TIME: float = 0.8
const DAMAGE: int = 1

var active: bool = false
var damage_done: bool = false

@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
var luz: PointLight2D

func _ready():
	add_to_group("storm")
	sprite.play("inicio")
	if collision:
		collision.disabled = true
	area_entered.connect(_on_area_entered)
	
	luz = PointLight2D.new()
	add_child(luz)
	luz.blend_mode = Light2D.BLEND_MODE_ADD
	
	var imagen = Image.create(64, 256, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(256):
			var dx = (x - 32.0) / 32.0
			var dy = (y - 128.0) / 128.0
			var alpha_x = clamp(1.0 - abs(dx), 0.0, 1.0)
			alpha_x = pow(alpha_x, 0.8)
		
			var alpha_rect = alpha_x * 0.6
			var dist = sqrt(dx*dx + dy*dy)
			var alpha_oval = clamp(1.0 - dist, 0.0, 1.0)
			alpha_oval = pow(alpha_oval, 0.4) * alpha_x
		
			var blend = clamp(float(y) / 256.0 * 2.0, 0.0, 1.0)
			var alpha = lerp(alpha_rect, alpha_oval, blend)
		
			imagen.set_pixel(x, y, Color(1, 1, 1, alpha))

	luz.texture = ImageTexture.create_from_image(imagen)
	var shape_height = $CollisionShape2D.shape.size.y
	luz.scale = Vector2(0.5, shape_height / 256.0)
	luz.position = Vector2(0, 0)
	luz.color = Color(0.0, 0.6, 1.0)
	luz.energy = 2.5
	
	_start_sequence()

func _start_sequence():
	await get_tree().create_timer(WARNING_TIME).timeout
	active = true
	sprite.play("tormenta")
	if collision:
		collision.disabled = false
	
	luz.energy = 2.5
	
	var tween = create_tween().set_loops()
	tween.tween_property(luz, "energy", 5.0, 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(luz, "energy", 3.0, 0.1).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(LIFETIME - WARNING_TIME).timeout
	queue_free()

func _on_area_entered(area: Area2D):
	if not active or damage_done:
		return
	if area.is_in_group("player_hurtbox"):
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			return
		var health_node = player.get_node_or_null("Health")
		if health_node and health_node.has_method("take_damage"):
			health_node.take_damage(DAMAGE)
			damage_done = true
