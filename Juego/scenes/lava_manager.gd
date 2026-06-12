extends Node2D

@onready var tilemap = get_parent().get_node("Nivel")

const LAVA_SOURCE_ID = 2
const LAVA_COORDS_NIVEL = [Vector2i(9,0)]
const TILE_SIZE = 16
const BASE_SCALE = 0.9
const LAVA_SOUND := preload("res://music/scenes/montanas_ceniza/lava.ogg")
const ZONA_RADIO := 35.0

var _textura_luz: ImageTexture = _crear_textura_luz()
var ambient_player: AudioStreamPlayer
var zonas_activas := 0


func _ready():
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbienteLava"
	ambient_player.stream = LAVA_SOUND
	ambient_player.bus = &"EFX"
	ambient_player.volume_db = 3.0
	add_child(ambient_player)
	_generar_luces()


func _crear_textura_luz() -> ImageTexture:
	var imagen = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var dx = (x - 32.0) / 32.0
			var dy = (y - 32.0) / 32.0
			var dist = sqrt(dx*dx + dy*dy)
			var alpha = clamp(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.5)
			imagen.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(imagen)


func _generar_luces():
	_buscar_en_tilemap(tilemap, LAVA_COORDS_NIVEL, Color(1.0, 0.75, 0.2))


func _buscar_en_tilemap(tm: TileMapLayer, coords: Array, color: Color):
	var filas = {}

	for celda in tm.get_used_cells():
		var sid = tm.get_cell_source_id(celda)
		var ac = tm.get_cell_atlas_coords(celda)
		if sid == LAVA_SOURCE_ID and ac in coords:
			var y = celda.y
			if not filas.has(y):
				filas[y] = []
			filas[y].append(celda.x)

	for y in filas:
		var xs = filas[y]
		xs.sort()

		var inicio = xs[0]
		var prev = xs[0]

		for i in range(1, xs.size()):
			if xs[i] == prev + 1:
				prev = xs[i]
			else:
				_crear_luz_para_segmento(tm, inicio, prev, y, color)
				inicio = xs[i]
				prev = xs[i]

		_crear_luz_para_segmento(tm, inicio, prev, y, color)


func _crear_luz_para_segmento(tm: TileMapLayer, x_start: int, x_end: int, y: int, color: Color):
	var num_tiles = x_end - x_start + 1
	var pos_start = tm.map_to_local(Vector2i(x_start, y))
	var pos_end = tm.map_to_local(Vector2i(x_end, y))
	var pos = (pos_start + pos_end) / 2.0
	pos += Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)

	var luz = PointLight2D.new()
	add_child(luz)
	luz.position = pos
	luz.color = color
	luz.energy = 1.5
	luz.blend_mode = Light2D.BLEND_MODE_ADD
	luz.texture = _textura_luz
	luz.scale = Vector2(BASE_SCALE * num_tiles/2, BASE_SCALE)

	var offset = randf() * 2.0
	await get_tree().create_timer(offset).timeout

	var tween = create_tween().set_loops()
	tween.tween_property(luz, "energy", 2.0, 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(luz, "energy", 1.2, 1.2).set_trans(Tween.TRANS_SINE)

	_crear_zona_proximidad(tm, x_start, x_end, y)

func _crear_zona_proximidad(tm: TileMapLayer, x_start: int, x_end: int, y: int) -> void:
	var num_tiles = x_end - x_start + 1
	var pos_start = tm.map_to_local(Vector2i(x_start, y))
	var pos_end = tm.map_to_local(Vector2i(x_end, y))
	var pos = (pos_start + pos_end) / 2.0
	var zona = Area2D.new()
	zona.name = "ZonaProximidadLava_%d_%d" % [x_start, y]
	zona.collision_mask = 4
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(num_tiles * TILE_SIZE + TILE_SIZE * ZONA_RADIO, TILE_SIZE * ZONA_RADIO)
	shape.shape = rect
	zona.position = pos
	zona.add_child(shape)
	zona.body_entered.connect(_on_zona_body_entered)
	zona.body_exited.connect(_on_zona_body_exited)
	add_child(zona)

func _on_zona_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		zonas_activas += 1
		if zonas_activas == 1:
			ambient_player.play()

func _on_zona_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		zonas_activas -= 1
		if zonas_activas <= 0:
			zonas_activas = 0
			ambient_player.stop()
