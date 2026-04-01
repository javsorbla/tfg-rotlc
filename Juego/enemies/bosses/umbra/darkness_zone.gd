extends Area2D

const DARKNESS_FRAMES := preload("res://assets/enemies/bosses/umbra/oscuridad.tres")

var tick_damage := 1
var tick_interval := 0.45
var remaining_lifetime := 2.8
var arming_delay := 0.55

var _tick_timer := 0.0
var _arm_timer := 0.0
var _armed := false
var _visual: AnimatedSprite2D
var _ring: Polygon2D


func configure(damage: int, interval: float, lifetime: float, delay := 0.55) -> void:
	tick_damage = damage
	tick_interval = interval
	remaining_lifetime = lifetime
	arming_delay = delay


func _ready() -> void:
	visible = true
	top_level = false
	z_as_relative = false
	z_index = 5000
	monitoring = true
	monitorable = true
	collision_layer = 16
	collision_mask = 4
	_tick_timer = tick_interval
	_arm_timer = arming_delay
	_armed = arming_delay <= 0.0
	_setup_visual()


func _setup_visual() -> void:
	_visual = AnimatedSprite2D.new()
	_visual.name = "Visual"
	_visual.sprite_frames = DARKNESS_FRAMES
	_visual.animation = &"default"
	_visual.modulate = Color(1.0, 1.0, 1.0, 0.62)
	_visual.z_as_relative = false
	_visual.z_index = 5100
	add_child(_visual)
	_visual.play()

	_ring = Polygon2D.new()
	_ring.name = "FallbackRing"
	_ring.polygon = _build_circle_polygon(52.0, 28)
	_ring.color = Color(0.12, 0.04, 0.2, 0.42)
	_ring.z_as_relative = false
	_ring.z_index = 5090
	add_child(_ring)


func _build_circle_polygon(radius: float, points: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in range(points):
		var t := TAU * float(i) / float(points)
		poly.append(Vector2(cos(t), sin(t)) * radius)
	return poly


func _physics_process(delta: float) -> void:
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		queue_free()
		return

	if not _armed:
		_arm_timer -= delta
		if _arm_timer <= 0.0:
			_armed = true
			if _visual != null:
				_visual.modulate = Color(1.0, 1.0, 1.0, 0.92)
			if _ring != null:
				_ring.color = Color(0.16, 0.06, 0.30, 0.62)
		return

	if _ring != null:
		var pulse := 0.10 + 0.08 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
		_ring.color.a = 0.56 + pulse

	_tick_timer -= delta
	if _tick_timer > 0.0:
		return

	_tick_timer = tick_interval
	_apply_tick_damage()


func _apply_tick_damage() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("player_hurtbox"):
			var owner = area.get_parent()
			if owner and owner.has_method("get"):
				var health_node = owner.get("health")
				if health_node and health_node.has_method("take_damage"):
					health_node.take_damage(tick_damage)
