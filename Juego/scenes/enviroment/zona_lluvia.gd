extends Area2D


@export var rain_speed = 600.0
@export var rain_angle_degrees = -20.0
@export var rain_density = 1.0 

@onready var canvas_modulate = get_tree().get_root().find_child("CanvasModulate", true, false)

const ZONAS_EXCLUIDAS = [
	{"min": Vector2(2050, -830), "max": Vector2(3014, 199)},
	{"min": Vector2(5009, 209), "max": Vector2(6699, 1181)}
]

var color_base: Color
static var destello_activo: bool = false
static var destello_iniciado: bool = false

func _ready():
	var shape_size = $CollisionShape2D.shape.size
	var shape_offset = $CollisionShape2D.position

	$ParticulasLluvia.emitting = true
	$ParticulasLluvia.local_coords = false
	$ParticulasLluvia.process_material = $ParticulasLluvia.process_material.duplicate()
	var mat = $ParticulasLluvia.process_material

	var angle_rad = deg_to_rad(rain_angle_degrees)
	var dir_x = sin(angle_rad)
	var dir_y = cos(angle_rad)

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(shape_size.x / 2, shape_size.y / 2, 0)

	mat.direction = Vector3(dir_x, dir_y, 0)
	mat.spread = 0.0
	mat.gravity = Vector3.ZERO

	mat.initial_velocity_min = rain_speed * 0.85
	mat.initial_velocity_max = rain_speed * 1.0
	mat.scale_min = 0.8
	mat.scale_max = 1.4
	mat.color = Color(0.7, 0.85, 1.0, 0.9)

	$ParticulasLluvia.amount = int((shape_size.x * shape_size.y) / 3000.0 * rain_density)
	$ParticulasLluvia.lifetime = (shape_size.y / rain_speed) * 1.2

	$ParticulasLluvia.position = shape_offset

	var image = Image.create(2, 12, false, Image.FORMAT_RGBA8)
	for y in range(12):
		var alpha = float(y) / 12.0
		image.set_pixel(0, y, Color(1, 1, 1, alpha))
		image.set_pixel(1, y, Color(1, 1, 1, alpha))
	var texture = ImageTexture.create_from_image(image)
	$ParticulasLluvia.texture = texture

	$ParticulasLluvia.visibility_rect = Rect2(
		-shape_size.x / 2,
		-shape_size.y / 2,
		shape_size.x,
		shape_size.y
	)
	
	if not destello_iniciado:
		destello_iniciado = true
		var cm = get_tree().current_scene.get_node("CanvasModulate")
		if cm:
			_programar_destello(cm)

func _programar_destello(cm):
	var espera = randf_range(10.0, 12.0)
	await get_tree().create_timer(espera).timeout
	_hacer_destello(cm)

func _jugador_en_zona_excluida() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	var px = player.global_position.x
	var py = player.global_position.y
	for zona in ZONAS_EXCLUIDAS:
		if px >= zona.min.x and px <= zona.max.x and py >= zona.min.y and py <= zona.max.y:
			return true
	return false

func _hacer_destello(cm):
	if destello_activo:
		_programar_destello(cm)
		return
	destello_activo = true
	
	var color_base = cm.color
	if not _jugador_en_zona_excluida():
		var flashes = [0.25, 0.15, 0.3]
		for duracion in flashes:
			var tween = create_tween()
			tween.tween_property(cm, "color", Color(1.0, 1.0, 1.0), 0.02)
			tween.tween_property(cm, "color", color_base, duracion)
			await tween.finished
			await get_tree().create_timer(randf_range(0.08, 0.15)).timeout
	
	destello_activo = false
	_programar_destello(cm)
