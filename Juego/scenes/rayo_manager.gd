extends Node2D

@onready var tilemap = get_parent().get_node("Nivel")

const RAYO_SOURCE_ID = 1
const RAYO_COORDS_BASE = [
	Vector2i(2,0), Vector2i(2,1), Vector2i(2,2), Vector2i(2,3), Vector2i(2,4),
	Vector2i(5,0), Vector2i(5,1), Vector2i(5,2), Vector2i(5,3), Vector2i(5,4)
]
const TILE_SIZE = 16


func _ready():
	_generar_luces()


func _generar_luces():
	var columnas = {}
	
	for celda in tilemap.get_used_cells():
		var sid = tilemap.get_cell_source_id(celda)
		var ac = tilemap.get_cell_atlas_coords(celda)
		if sid == RAYO_SOURCE_ID and ac in RAYO_COORDS_BASE:
			if not columnas.has(celda.x):
				columnas[celda.x] = []
			columnas[celda.x].append(celda.y)
		
	for col_x in columnas:
		var celdas_y = columnas[col_x]
		celdas_y.sort()
		var num_tiles = celdas_y.size()
		var altura_px = num_tiles * TILE_SIZE
		var pos_top = tilemap.map_to_local(Vector2i(col_x, celdas_y[0]))
		var pos_centro = pos_top + Vector2(TILE_SIZE * 0.01, altura_px / 2.0 - 7.5)
		_crear_luz(pos_centro, altura_px)
	

func _crear_luz(pos: Vector2, altura_px: float):
	var luz = PointLight2D.new()
	add_child(luz)
	luz.position = pos
	luz.color = Color(0.0, 0.6, 1.0)
	luz.energy = 6.0
	luz.blend_mode = Light2D.BLEND_MODE_ADD
	
	var imagen = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var dx = (x - 32.0) / 32.0
			# Suaviza en X
			var alpha_x = clamp(1.0 - abs(dx), 0.0, 1.0)
			alpha_x = pow(alpha_x, 1.5)
			var alpha_y = 1.0
			if y > 51: 
				alpha_y = clamp(1.0 - float(y - 51) / 13.0, 0.0, 1.0)
			imagen.set_pixel(x, y, Color(1, 1, 1, alpha_x * alpha_y))
	
	var tex = ImageTexture.create_from_image(imagen)
	luz.texture = tex
	luz.scale = Vector2(0.25, altura_px / 64.0)
	
	var tween = create_tween().set_loops()
	tween.tween_property(luz, "energy", 7.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(luz, "energy", 5.0, 0.6).set_trans(Tween.TRANS_SINE)
