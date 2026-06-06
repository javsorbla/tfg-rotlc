extends Node2D

@onready var tilemap_fondo = get_parent().get_node("TilesFondo")

const ANTORCHA_SOURCE_ID = 0
const ANTORCHA_COORDS = [
	Vector2i(2, 0)
]

const TILE_SIZE = 16

func _ready():
	_generar_luces()

func _generar_luces():
	_buscar_en_tilemap(tilemap_fondo, ANTORCHA_COORDS, Color(1.0, 0.4, 0.05))

func _buscar_en_tilemap(tm: TileMapLayer, coords: Array, color: Color):
	for celda in tm.get_used_cells():
		var sid = tm.get_cell_source_id(celda)
		var ac = tm.get_cell_atlas_coords(celda)
		if sid == ANTORCHA_SOURCE_ID and ac in coords:
			var pos = tm.map_to_local(celda)
			pos += Vector2(TILE_SIZE * 0.01, TILE_SIZE * 0.01)
			_crear_luz(pos, color)

func _crear_luz(pos: Vector2, color: Color):
	var luz = PointLight2D.new()
	add_child(luz)
	luz.position = pos
	luz.color = color
	luz.energy = 1.8
	luz.blend_mode = Light2D.BLEND_MODE_ADD

	var imagen = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var dx = (x - 32.0) / 32.0
			var dy = (y - 32.0) / 32.0
			var dist = sqrt(dx*dx + dy*dy)
			var alpha = clamp(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.5)
			imagen.set_pixel(x, y, Color(1, 1, 1, alpha))

	var tex = ImageTexture.create_from_image(imagen)
	luz.texture = tex
	luz.scale = Vector2(2.0, 2.0)

	var offset = randf() * 2.0
	await get_tree().create_timer(offset).timeout

	var tween = create_tween().set_loops()
	tween.tween_property(luz, "energy", 2.5, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(luz, "energy", 1.4, 1.0).set_trans(Tween.TRANS_SINE)
