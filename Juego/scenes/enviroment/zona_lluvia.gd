extends Area2D

@export var rain_speed = 600.0
@export var rain_angle_degrees = -20.0
@export var rain_density = 1.0 

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
