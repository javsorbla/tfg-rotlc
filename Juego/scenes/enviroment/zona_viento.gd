extends Area2D

@export var wind_force = 150.0
@export var wind_direction = Vector2.LEFT
var player = null
var player_inside = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	var shape_size = $CollisionShape2D.shape.size
	var shape_offset = $CollisionShape2D.position
	$ParticulasViento.process_material = $ParticulasViento.process_material.duplicate()
	var mat = $ParticulasViento.process_material

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(shape_size.x / 2, shape_size.y / 2, 0)
	mat.direction = Vector3(wind_direction.x, 0, 0)
	mat.spread = 2.0
	mat.scale_min = 1.0
	mat.scale_max = 1.5
	mat.initial_velocity_min = wind_force * 0.2
	mat.initial_velocity_max = wind_force * 0.5
	mat.gravity = Vector3.ZERO

	$ParticulasViento.amount = int(shape_size.y / 5)
	$ParticulasViento.position = shape_offset

	var max_velocity = wind_force * 0.5
	$ParticulasViento.lifetime = (shape_size.x / max_velocity) * 0.6

	# Textura alargada para las partículas
	var image = Image.create(16, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(image)
	$ParticulasViento.texture = texture

	$ParticulasViento.visibility_rect = Rect2(
		-shape_size.x / 2,
		-shape_size.y / 2,
		shape_size.x,
		shape_size.y
	)
	
	print("shape_size: ", shape_size)
	print("shape_offset: ", shape_offset)
	print("amount: ", $ParticulasViento.amount)
	print("lifetime: ", $ParticulasViento.lifetime)
	print("emission_box_extents: ", mat.emission_box_extents)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player = body
		player_inside = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false

func _physics_process(delta):
	if not player_inside:
		return
	
	var wind_velocity = wind_direction.x * wind_force * 0.5
	var player_moving_against = abs(player.velocity.x) > 10.0 and sign(player.velocity.x) != sign(wind_velocity)
	
	if player_moving_against:
		player.velocity.x = move_toward(player.velocity.x, wind_velocity * 0.2, wind_force * delta * 1.2)
	else:
		var move_dir = sign(player.velocity.x) if abs(player.velocity.x) > 10.0 else wind_direction.x
		var boosted_speed = player.SPEED * 1.8
		if abs(player.velocity.x) < boosted_speed:
			player.velocity.x += wind_direction.x * wind_force * delta * 0.8
			player.velocity.x = clamp(player.velocity.x, -boosted_speed, boosted_speed)
