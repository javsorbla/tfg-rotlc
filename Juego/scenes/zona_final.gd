extends Area2D


@export var color_zona: Color = Color(0.4, 0.55, 0.8, 1)
@export var energia_max: float = 1.2

var canvas_modulate: CanvasModulate
var luz: PointLight2D

func _ready():
	canvas_modulate = get_tree().get_first_node_in_group("canvas_modulate")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_crear_luz()

func _crear_luz():
	var shape_node = get_node_or_null("CollisionShape2D")
	if shape_node == null:
		return
	
	var shape = shape_node.shape
	var tamaño = Vector2(200, 200)
	if shape is RectangleShape2D:
		tamaño = shape.size

	luz = PointLight2D.new()
	add_child(luz)
	luz.position = shape_node.position
	luz.color = color_zona
	luz.energy = 0.0
	luz.blend_mode = Light2D.BLEND_MODE_ADD

	var res = 128
	var imagen = Image.create(res, res, false, Image.FORMAT_RGBA8)
	for x in range(res):
		for y in range(res):
			var dx = (x - res / 2.0) / (res / 2.0)
			var dy = (y - res / 2.0) / (res / 2.0)
			var dist = sqrt(dx*dx + dy*dy)
			var alpha = clamp(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.0)
			imagen.set_pixel(x, y, Color(1, 1, 1, alpha))

	luz.texture = ImageTexture.create_from_image(imagen)
	luz.scale = Vector2(tamaño.x / 64.0, tamaño.y / 64.0)

func _on_body_entered(body):
	if body.is_in_group("player"):
		canvas_modulate.cambiar_zona(color_zona)
		var tween = create_tween()
		tween.tween_property(luz, "energy", energia_max, 1.5).set_trans(Tween.TRANS_SINE)

func _on_body_exited(body):
	if body.is_in_group("player"):
		canvas_modulate.cambiar_zona(Color("#aaaaaa"))
		var tween = create_tween()
		tween.tween_property(luz, "energy", 0.0, 1.5).set_trans(Tween.TRANS_SINE)
