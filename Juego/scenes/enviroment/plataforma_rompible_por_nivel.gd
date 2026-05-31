extends AnimatableBody2D

const SHAKE_DURATION := 1.0
const BREAK_DELAY := 0.3
const RESPAWN_TIME := 3.0

const FALLBACK_VARIANT_LEVEL := 1
const VARIANT_NODE_NAMES := {
	1: "VariantNivel1",
	2: "VariantNivel2",
	3: "VariantNivel3",
	4: "VariantNivel4",
}

var is_shaking := false
var shake_timer := 0.0
var original_position: Vector2
var active_variant_level := -1
var active_tilemap: TileMapLayer
var active_detector: Area2D
var variant_data: Dictionary = {}


func _ready() -> void:
	original_position = global_position
	_cache_variants()
	_set_active_variant(_resolve_variant_level(int(GameState.current_level)))


func _cache_variants() -> void:
	variant_data.clear()
	for level_id in VARIANT_NODE_NAMES.keys():
		var variant_node := get_node_or_null(VARIANT_NODE_NAMES[level_id]) as Node2D
		if variant_node == null:
			continue
		var tilemap := variant_node.get_node_or_null("TileMapLayer") as TileMapLayer
		var detector := variant_node.get_node_or_null("Detector") as Area2D
		variant_data[level_id] = {
			"node": variant_node,
			"tilemap": tilemap,
			"detector": detector,
		}
		if detector != null:
			var handler := Callable(self, "_on_detector_body_entered")
			if not detector.body_entered.is_connected(handler):
				detector.body_entered.connect(handler)
			_set_detector_state(detector, false)
		if tilemap != null:
			_set_tilemap_state(tilemap, false)


func _resolve_variant_level(current_level: int) -> int:
	if variant_data.has(current_level) and _variant_is_configured(int(current_level)):
		return current_level
	if variant_data.has(FALLBACK_VARIANT_LEVEL) and _variant_is_configured(FALLBACK_VARIANT_LEVEL):
		return FALLBACK_VARIANT_LEVEL
	for level_id in variant_data.keys():
		if _variant_is_configured(int(level_id)):
			return int(level_id)
	return -1


func _variant_is_configured(level_id: int) -> bool:
	if not variant_data.has(level_id):
		return false
	var data: Dictionary = variant_data[level_id]
	return data.get("tilemap", null) != null or data.get("detector", null) != null


func _set_active_variant(level_id: int) -> void:
	for existing_level_id in variant_data.keys():
		_set_variant_state(int(existing_level_id), false)

	active_variant_level = -1
	active_tilemap = null
	active_detector = null

	if level_id == -1 or not variant_data.has(level_id):
		push_warning("No hay variante de plataforma rompible configurada para este nivel.")
		return

	var data: Dictionary = variant_data[level_id]
	active_tilemap = data.get("tilemap", null)
	active_detector = data.get("detector", null)
	active_variant_level = level_id
	_set_variant_state(level_id, true)
	if active_tilemap != null:
		active_tilemap.position.x = 0.0


func _set_variant_state(level_id: int, enabled: bool) -> void:
	if not variant_data.has(level_id):
		return
	var data: Dictionary = variant_data[level_id]
	var variant_node := data.get("node", null) as Node2D
	var tilemap := data.get("tilemap", null) as TileMapLayer
	var detector := data.get("detector", null) as Area2D

	if variant_node != null:
		variant_node.visible = enabled
	if tilemap != null:
		_set_tilemap_state(tilemap, enabled)
	if detector != null:
		_set_detector_state(detector, enabled)


func _set_tilemap_state(tilemap: TileMapLayer, enabled: bool) -> void:
	tilemap.visible = enabled
	tilemap.set_collision_enabled(enabled)
	if not enabled:
		tilemap.position.x = 0.0


func _set_detector_state(detector: Area2D, enabled: bool) -> void:
	detector.monitoring = enabled
	detector.monitorable = enabled
	var shape := detector.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = not enabled


func _physics_process(delta: float) -> void:
	if not is_shaking or active_tilemap == null:
		return
	shake_timer -= delta
	if shake_timer > BREAK_DELAY:
		var t = SHAKE_DURATION - shake_timer
		active_tilemap.position.x = sin(t * 40.0) * 2.0
	elif shake_timer <= 0.0:
		_break()


func _break() -> void:
	is_shaking = false
	if active_tilemap != null:
		active_tilemap.visible = false
		active_tilemap.set_collision_enabled(false)
	if active_detector != null:
		_set_detector_state(active_detector, false)
	await get_tree().create_timer(RESPAWN_TIME).timeout
	_respawn()


func _respawn() -> void:
	if active_tilemap != null:
		active_tilemap.position.x = 0.0
		active_tilemap.visible = true
		active_tilemap.set_collision_enabled(true)
	if active_detector != null:
		_set_detector_state(active_detector, true)
	global_position = original_position


func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_shaking:
		if body.global_position.y < global_position.y:
			is_shaking = true
			shake_timer = SHAKE_DURATION
			if active_tilemap != null:
				active_tilemap.position.x = 0.0