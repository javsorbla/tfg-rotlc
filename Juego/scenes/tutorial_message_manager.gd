extends Node

signal advance_requested

@export var default_duration: float = 3.0
@export var intro_action: String = "ui_accept"
@export var skip_action: String = "ui_cancel"

@onready var label: Label = get_node_or_null("TutorialMessageLayer/MessageLabel")
@onready var anim: AnimationPlayer = get_node_or_null("MessageAnim")
@onready var backdrop: ColorRect = get_node_or_null("TutorialMessageLayer/Backdrop")
@onready var pulse_node: ColorRect = get_node_or_null("TutorialMessageLayer/Pulse")
@onready var particles: GPUParticles2D = get_node_or_null("TutorialMessageLayer/Particles")

@export var intro_color: Color = Color(1, 1, 1, 1)        # blanco para la intro
@export var zone_color: Color = Color(1, 0.82, 0.27, 1)   # dorado para las zonas
@export var zone_message_offset: Vector2 = Vector2(0, -180)
@export var intro_fade_in_duration: float = 0.8
@export var intro_fade_out_duration: float = 0.5
@export var zone_fade_in_duration: float = 0.3
@export var zone_fade_out_duration: float = 0.3

var _default_offset: Vector2 = Vector2.ZERO

var _queue: Array[Dictionary] = []
var _is_showing := false
var _sequence_active := false
var _waiting_for_input := false
var _skip_requested := false
var _cancel_token: int = 0

var _celestial_material: ShaderMaterial = null

func _ready() -> void:
	add_to_group("tutorial_message_manager")
	set_process(true)
	if label != null:
		_default_offset = Vector2(label.offset_left, label.offset_top)
		_celestial_material = label.material
		label.material = null  # <- fix
		label.modulate.a = 0.0
		label.visible = true
	if backdrop != null:
		backdrop.visible = false
	if pulse_node != null:
		pulse_node.visible = false
		var sm := pulse_node.material as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("ring_radius", 0.0)
			sm.set_shader_parameter("pulse_color", Color(1.0, 1.0, 1.0, 0.0))
	if particles != null:
		particles.emitting = false
		particles.visible = false

func show_message(text: String, duration: float = -1.0, wait_for_input: bool = false) -> void:
	_queue.append({
		"text": text,
		"duration": duration,
		"wait_for_input": wait_for_input
	})
	if not _is_showing and not _sequence_active:
		call_deferred("_play_next")

func play_intro_sequence(texts: Array) -> void:
	_skip_requested = false
	_sequence_active = true
	_set_backdrop(true)
	for text in texts:
		if _skip_requested:
			break
		await _show_message_blocking(text, -1.0, true, true)
	_set_backdrop(false)
	_sequence_active = false
	_is_showing = false
	if not _is_showing and not _queue.is_empty():
		call_deferred("_play_next")

func _play_next() -> void:
	if _sequence_active:
		return
	if _queue.is_empty():
		_is_showing = false
		return
	var item = _queue.pop_front()
	await _show_message_blocking(item.text, item.duration, item.wait_for_input)
	if _queue.is_empty():
		_is_showing = false
		return
	call_deferred("_play_next")

func _show_message_blocking(text: String, duration: float, wait_for_input: bool, is_intro: bool = false) -> void:
	_is_showing = true
	if _skip_requested and is_intro:
		_is_showing = false
		return
	if label == null:
		_is_showing = false
		return
	# If intro was skipped, label may have been hidden.
	label.visible = true

	# Aplicar color según tipo
	var settings := label.label_settings
	if settings != null:
		settings.font_color = intro_color if is_intro else zone_color

	# Aplicar posición según tipo
	if is_intro:
		label.offset_left = _default_offset.x
		label.offset_top = _default_offset.y
		label.offset_right = -_default_offset.x
		label.offset_bottom = -_default_offset.y
		label.material = null
	else:
		label.offset_left = _default_offset.x + zone_message_offset.x
		label.offset_top = _default_offset.y + zone_message_offset.y
		label.offset_right = -_default_offset.x + zone_message_offset.x
		label.offset_bottom = -_default_offset.y + zone_message_offset.y
		label.material = _celestial_material

	label.text = text
	# Ensure text isn't blacked out by modulate RGB (tscn defaults to black).
	label.modulate = Color(1, 1, 1, 0)
	
	# Velocidad de fade según tipo
	var fade_in_speed := (1.0 / intro_fade_in_duration) if is_intro else (1.0 / zone_fade_in_duration)
	var fade_out_speed := (1.0 / intro_fade_out_duration) if is_intro else (1.0 / zone_fade_out_duration)

	var my_token := _cancel_token
	if anim != null and anim.has_animation("fade_in"):
		if particles != null and not is_intro:
			if label != null:
				particles.global_position = label.global_position
			var viewport_size := get_viewport().get_visible_rect().size
			particles.position = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0 + zone_message_offset.y)
			particles.visible = true
			particles.emitting = true
			particles.z_index = 200
		anim.speed_scale = fade_in_speed
		anim.play("fade_in")
		await get_tree().process_frame
		while anim.is_playing():
			if is_intro and _skip_requested:
				anim.stop()
				break
			if my_token != _cancel_token:
				anim.stop()
				break
			await get_tree().process_frame
		label.modulate = Color(1, 1, 1, 1)
	else:
		label.modulate = Color(1, 1, 1, 1)
		label.visible = true
		if label is CanvasItem:
			label.raise()
		if particles != null and not is_intro:
			particles.visible = true
			particles.emitting = true
		await get_tree().process_frame

	if wait_for_input:
		_waiting_for_input = true
		await _wait_for_advance()
		_waiting_for_input = false
	else:
		var wait_time := duration if duration > 0.0 else default_duration
		# If intro was skipped while waiting, don't block.
		var timer := get_tree().create_timer(wait_time)
		while timer.time_left > 0.0:
			if is_intro and _skip_requested:
				break
			if my_token != _cancel_token:
				break
			await get_tree().process_frame

	if anim != null and anim.has_animation("fade_out"):
		anim.speed_scale = fade_out_speed
		anim.play("fade_out")
		await get_tree().process_frame
		while anim.is_playing():
			if is_intro and _skip_requested:
				anim.stop()
				break
			if my_token != _cancel_token:
				anim.stop()
				break
			await get_tree().process_frame
		label.modulate = Color(1, 1, 1, 0)
		if particles != null:
			particles.emitting = false
			particles.visible = false
		anim.speed_scale = 1.0
	else:
		label.modulate.a = 0.0
		if particles != null:
			particles.emitting = false
			particles.visible = false
		await get_tree().process_frame

func _wait_for_advance() -> void:
	await advance_requested

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(skip_action):
		get_viewport().set_input_as_handled()
		_skip_intro()
		return
	if not _sequence_active:
		return
	if not _waiting_for_input:
		return
	if event.is_action_pressed(intro_action):
		get_viewport().set_input_as_handled()
		_waiting_for_input = false  # evita doble input mientras espera el pulso
		if particles != null:
			if not particles.emitting:
				particles.visible = true
				particles.emitting = true
		await _trigger_pulse()
		emit_signal("advance_requested")
		return
	return

func _skip_intro() -> void:
	_queue.clear()
	_sequence_active = false
	_is_showing = false
	_waiting_for_input = false
	_skip_requested = true
	_cancel_token += 1
	if anim != null:
		anim.stop()
	if label != null:
		label.modulate = Color(1,1,1,0)
		label.visible = false
	_set_backdrop(false)
	if pulse_node != null:
		pulse_node.visible = false
		var mat: ShaderMaterial = pulse_node.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("pulse_color", Color(1,1,1,0.0))
	if particles != null:
		particles.emitting = false
		particles.visible = false
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("set_input_enabled"):
			p.set_input_enabled(true)
	emit_signal("advance_requested")

func _set_backdrop(visible: bool) -> void:
	if backdrop != null:
		backdrop.visible = visible
		if visible:
			var col := backdrop.color
			col.r = 0.0
			col.g = 0.0
			col.b = 0.0
			col.a = 1.0
			backdrop.color = col

func _trigger_pulse() -> void:
	if pulse_node == null:
		return
	var mat: ShaderMaterial = pulse_node.material as ShaderMaterial
	if mat == null:
		return
	var my_token := _cancel_token
	if _skip_requested:
		return

	pulse_node.visible = true
	
	# Empieza pequeño pero visible, expande hasta cubrir la pantalla
	var start_radius := 0.05
	var end_radius := 0.8 
	var start_width := 0.06
	var end_width := 0.03

	var duration := 0.5
	var steps := 20
	var step_time := duration / float(steps)

	for i in range(steps + 1):
		if my_token != _cancel_token or _skip_requested:
			pulse_node.visible = false
			mat.set_shader_parameter("pulse_color", Color(1.0, 1.0, 1.0, 0.0))
			return
		var t := float(i) / float(steps)
		var ease_t := 1.0 - pow(1.0 - t, 2.0)
		
		mat.set_shader_parameter("ring_radius", lerp(start_radius, end_radius, ease_t))
		mat.set_shader_parameter("ring_width", lerp(start_width, end_width, t))
		mat.set_shader_parameter("pulse_color", Color(1.0, 1.0, 1.0, 1.0 - ease_t))
		
		await get_tree().create_timer(step_time).timeout

	pulse_node.visible = false
	mat.set_shader_parameter("pulse_color", Color(1.0, 1.0, 1.0, 0.0))

func _process(delta: float) -> void:
	if _sequence_active and Input.is_action_just_pressed(skip_action):
		_skip_intro()
