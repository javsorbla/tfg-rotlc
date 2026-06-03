extends OverlaidWindow

const SIDEBAR_TABS := [
	{"id": "campaign", "label": "Campaña"},
	{"id": "level_0", "label": "Tutorial"},
	{"id": "level_1", "label": "Campos"},
	{"id": "level_2", "label": "Montañas"},
	{"id": "level_3", "label": "Costa"},
	{"id": "level_4", "label": "Torre"},
]

const CAMPAIGN_METRICS := [
	{"id": "campaign_score", "label": "Puntuación", "meta_key": "", "format": "score"},
	{"id": "campaign_time", "label": "Tiempo", "meta_key": "total_time", "format": "time"},
	{"id": "campaign_kills", "label": "Enemigos", "meta_key": "total_kills", "format": "int"},
	{"id": "campaign_deaths", "label": "Muertes", "meta_key": "total_deaths", "format": "int"},
	{"id": "campaign_damage_dealt", "label": "Daño infligido", "meta_key": "total_damage_dealt", "format": "int"},
	{"id": "campaign_damage_received", "label": "Daño recibido", "meta_key": "total_damage_taken", "format": "int"},
	{"id": "campaign_prism_cores", "label": "Núcleos", "meta_key": "total_prism_cores", "format": "int"},
]

static func _make_level_metrics(level_id: int) -> Array:
	var p := "level_%d" % level_id
	return [
		{"id": p + "_score", "label": "Puntuación", "meta_key": "", "format": "score"},
		{"id": p + "_time", "label": "Tiempo", "meta_key": "duration", "format": "time"},
		{"id": p + "_kills", "label": "Enemigos", "meta_key": "enemies_killed", "format": "int"},
		{"id": p + "_deaths", "label": "Muertes", "meta_key": "deaths", "format": "int"},
		{"id": p + "_damage_dealt", "label": "Daño infligido", "meta_key": "damage_dealt", "format": "int"},
		{"id": p + "_damage_received", "label": "Daño recibido", "meta_key": "damage_taken", "format": "int"},
		{"id": p + "_prism_cores", "label": "Núcleos", "meta_key": "prism_cores", "format": "int"},
	]

var _current_sidebar_tab: int = 0
var _current_metric: int = 0
var _records_cache: Array = []
var _metrics_by_tab: Dictionary = {}

@onready var records_list: VBoxContainer = %RecordsList
@onready var player_position_label: Label = %PlayerPositionLabel
@onready var loading_label: Label = %LoadingLabel
@onready var error_label: Label = %ErrorLabel
@onready var offline_banner: Label = %OfflineBanner
@onready var sidebar_buttons: VBoxContainer = %SidebarButtons
@onready var metric_row: HBoxContainer = %MetricRow


func _ready() -> void:
	_build_metrics_dict()
	_build_sidebar()
	_build_metric_row(SIDEBAR_TABS[0].id)
	offline_banner.hide()
	MenuProgressionHelper.apply_progress_to_node(self)
	_refresh()


func _build_metrics_dict() -> void:
	_metrics_by_tab["campaign"] = CAMPAIGN_METRICS
	for i in range(5):
		_metrics_by_tab["level_%d" % i] = _make_level_metrics(i)


func _build_sidebar() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for i in range(SIDEBAR_TABS.size()):
		var tab: Dictionary = SIDEBAR_TABS[i]
		var btn: Button = Button.new()
		btn.text = tab.label
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_group = group
		btn.clip_text = false  # evita que corte el texto
		btn.custom_minimum_size = Vector2(0, 32) 
		btn.pressed.connect(_on_sidebar_tab_pressed.bind(i))
		sidebar_buttons.add_child(btn)

	if sidebar_buttons.get_child_count() > 0:
		sidebar_buttons.get_child(0).button_pressed = true


func _build_metric_row(tab_id: String) -> void:
	for child in metric_row.get_children():
		child.queue_free()

	var metrics: Array = _metrics_by_tab.get(tab_id, [])
	var group: ButtonGroup = ButtonGroup.new()
	for i in range(metrics.size()):
		var m: Dictionary = metrics[i]
		var btn: Button = Button.new()
		btn.text = m.label
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(60, 0)
		btn.pressed.connect(_on_metric_pressed.bind(i))
		metric_row.add_child(btn)

	if metric_row.get_child_count() > 0:
		metric_row.get_child(0).button_pressed = true
		_current_metric = 0
	MenuProgressionHelper.apply_progress_to_node(self)


func _refresh() -> void:
	loading_label.show()
	error_label.hide()
	player_position_label.hide()
	offline_banner.hide()

	var tab_id: String = SIDEBAR_TABS[_current_sidebar_tab].id
	var metrics: Array = _metrics_by_tab.get(tab_id, [])
	if _current_metric >= metrics.size():
		_current_metric = 0

	var metric_data: Dictionary = metrics[_current_metric] if metrics else {}
	if metric_data.is_empty():
		loading_label.hide()
		_clear_records_list()
		error_label.text = "Sin métricas disponibles"
		error_label.show()
		return

	if not NakamaManager.has_authenticated:
		loading_label.hide()
		_show_offline_records(metric_data)
		return

	var records = await NakamaManager.fetch_leaderboard_top(metric_data.id, 50)
	loading_label.hide()

	if records.is_empty():
		_clear_records_list()
		error_label.text = "No hay datos de clasificación"
		error_label.show()
		_records_cache = []
		return

	_records_cache = records
	_populate_records(records)
	_check_player_position()


func _format_value(metric_data: Dictionary, record) -> String:
	var fmt: String = metric_data.format
	var score_val: int
	var meta: Dictionary = {}

	if typeof(record) == TYPE_DICTIONARY:
		score_val = int(record.get("score", 0))
		var meta_raw = record.get("metadata", {})
		if typeof(meta_raw) == TYPE_DICTIONARY:
			meta = meta_raw
		elif typeof(meta_raw) == TYPE_STRING and not (meta_raw as String).is_empty():
			var parsed = JSON.parse_string(meta_raw as String)
			if typeof(parsed) == TYPE_DICTIONARY:
				meta = parsed
	else:
		score_val = int(record.score)
		var meta_str := str(record.metadata) if record.metadata != null else ""
		if not meta_str.is_empty():
			var parsed = JSON.parse_string(meta_str)
			if typeof(parsed) == TYPE_DICTIONARY:
				meta = parsed

	if fmt == "score":
		return str(score_val)

	var raw_value: int = 0
	if fmt == "time":
		raw_value = meta.get(metric_data.meta_key, 0) if meta else 0
		var hours := raw_value / 3600
		var mins := (raw_value % 3600) / 60
		var secs := raw_value % 60
		if hours > 0:
			return "%02d:%02d:%02d" % [hours, mins, secs]
		return "%02d:%02d" % [mins, secs]
	else:
		raw_value = meta.get(metric_data.meta_key, 0) if meta else 0
		return str(raw_value)


func _populate_records(records: Array) -> void:
	for child in records_list.get_children():
		child.queue_free()

	var my_id: String = NakamaManager.session.user_id if NakamaManager.session else ""
	var tab_id: String = SIDEBAR_TABS[_current_sidebar_tab].id
	var metrics: Array = _metrics_by_tab.get(tab_id, [])
	var metric_data: Dictionary = metrics[_current_metric] if _current_metric < metrics.size() else {}

	for i in range(records.size()):
		var record = records[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var rank: Label = Label.new()
		rank.text = str(i + 1) + "."
		rank.custom_minimum_size = Vector2(40, 0)
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var name_label: Label = Label.new()
		var owner_id: String = record.owner_id if record.owner_id else ""
		var display_name := str(record.username)
		var is_me := owner_id == my_id
		if display_name.is_empty() or display_name == owner_id:
			display_name = NakamaManager.nickname if is_me and not NakamaManager.nickname.is_empty() else "Jugador#" + owner_id.left(6)
		name_label.text = display_name
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL

		var value_label: Label = Label.new()
		value_label.text = _format_value(metric_data, record)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size = Vector2(100, 0)

		row.add_child(rank)
		row.add_child(name_label)
		row.add_child(value_label)

		if owner_id == my_id:
			row.modulate = Color(1, 0.85, 0.3, 1)

		records_list.add_child(row)


func _check_player_position() -> void:
	if not NakamaManager.session:
		return

	var tab_id: String = SIDEBAR_TABS[_current_sidebar_tab].id
	var metrics: Array = _metrics_by_tab.get(tab_id, [])
	var metric_data: Dictionary = metrics[_current_metric] if _current_metric < metrics.size() else {}
	if metric_data.is_empty():
		return

	var around: Array = await NakamaManager.fetch_leaderboard_around_me(metric_data.id, 5)
	if around.is_empty():
		return

	var my_id: String = NakamaManager.session.user_id
	var found: bool = false
	for record in around:
		if record.owner_id == my_id:
			var pos: int = int(record.rank) + 1
			var value_str := _format_value(metric_data, record)
			player_position_label.text = "Tu puesto: #" + str(pos) + " - " + value_str
			player_position_label.show()
			found = true
			break

	if not found:
		player_position_label.text = "Tu puesto: #—"
		player_position_label.show()


func _on_sidebar_tab_pressed(index: int) -> void:
	_current_sidebar_tab = index
	var tab_id: String = SIDEBAR_TABS[index].id
	_build_metric_row(tab_id)
	_refresh()


func _on_metric_pressed(index: int) -> void:
	_current_metric = index
	_refresh()


func _clear_records_list() -> void:
	for child in records_list.get_children():
		child.queue_free()


func _show_offline_records(metric_data: Dictionary) -> void:
	offline_banner.show()
	_clear_records_list()

	var local: Dictionary = NakamaManager.get_local_best_for(metric_data.id)
	if local.is_empty():
		error_label.text = "Sin conexión y sin datos locales"
		error_label.show()
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var rank: Label = Label.new()
	rank.text = "1."
	rank.custom_minimum_size = Vector2(40, 0)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var name_label: Label = Label.new()
	name_label.text = NakamaManager.nickname if not NakamaManager.nickname.is_empty() else "Tú"
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL

	var value_label: Label = Label.new()
	value_label.text = _format_value(metric_data, local)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(100, 0)

	row.add_child(rank)
	row.add_child(name_label)
	row.add_child(value_label)
	records_list.add_child(row)
