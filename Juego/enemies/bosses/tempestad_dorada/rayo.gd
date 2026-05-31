extends Node2D

const DAMAGE: int = 1

var active: bool = false
var damage_timer: float = 0.0
var luces: Array = []
var _textura_luz: ImageTexture

@onready var hitbox = $RayoHitbox
@onready var shape = $RayoHitbox/CollisionShape2D

func update_hitbox(start: Vector2, end: Vector2):
	var diff = end - start
	hitbox.global_position = start + diff * 0.5
	hitbox.rotation = diff.angle() + deg_to_rad(90.0)
	if shape.shape is RectangleShape2D:
		shape.shape.size = Vector2(20.0, diff.length())
	_crear_luz_segmento(start, diff)

func _crear_luz_segmento(start: Vector2, diff: Vector2):
	var l = PointLight2D.new()
	get_parent().add_child(l)
	luces.append(l)
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.color = Color(0.0, 0.6, 1.0)
	l.texture = _textura_luz
	l.global_position = start + diff
	l.rotation = diff.angle() + deg_to_rad(90.0)
	l.scale = Vector2(0.8, diff.length() / 64.0 * 2)
	var tween = create_tween().set_loops()
	tween.tween_property(l, "energy", 4.0, 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(l, "energy", 2.5, 0.1).set_trans(Tween.TRANS_SINE)

func _ready():
	if not hitbox:
		return
	if not hitbox.is_in_group("enemy_hitbox"):
		hitbox.add_to_group("enemy_hitbox")
		
	var imagen = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var dx = (x - 32.0) / 32.0
			var alpha_x = clamp(1.0 - abs(dx), 0.0, 1.0)
			alpha_x = pow(alpha_x, 0.8)
			imagen.set_pixel(x, y, Color(1, 1, 1, alpha_x))
	_textura_luz = ImageTexture.create_from_image(imagen)

func _exit_tree():
	for l in luces:
		if is_instance_valid(l):
			l.queue_free()
	luces.clear()

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
