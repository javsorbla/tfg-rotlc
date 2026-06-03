extends OverlaidWindow

const TABS := [
	{"id": "global_score", "label": "Puntuación", "meta_key": "", "format": "score"},
	{"id": "global_time", "label": "Tiempo", "meta_key": "duration", "format": "time"},
	{"id": "global_kills", "label": "Enemigos", "meta_key": "enemies_killed", "format": "int"},
	{"id": "global_deaths", "label": "Muertes", "meta_key": "deaths", "format": "int"},
	{"id": "global_damage_dealt", "label": "Daño infligido", "meta_key": "damage_dealt", "format": "int"},
	{"id": "global_damage_taken", "label": "Daño recibido", "meta_key": "damage_taken", "format": "int"},
	{"id": "global_prism_cores", "label": "Núcleos", "meta_key": "prism_cores", "format": "int"},
]

var _current_tab := 0
var _records_cache := []

@onready var records_list: VBoxContainer = %RecordsList
@onready var player_position_label: Label = %PlayerPositionLabel
@onready var loading_label: Label = %LoadingLabel
@onready var error_label: Label = %ErrorLabel
@onready var tab_bar: TabBar = %TabBar


func _ready() -> void:
	for t in TABS:
		tab_bar.add_tab(t.label)
	_refresh()


func _refresh() -> void:
	loading_label.show()
	error_label.hide()
	player_position_label.hide()

	var tab_data: Dictionary = TABS[_current_tab]
	var records = await NakamaManager.fetch_leaderboard_top(tab_data.id, 50)
	loading_label.hide()

	if records.is_empty():
		error_label.text = "No hay datos de clasificación"
		error_label.show()
		_records_cache = []
		return

	_records_cache = records
	_populate_records(records)
	_check_player_position()


func _format_value(tab_data: Dictionary, record) -> String:
	var format: String = tab_data.format
	if format == "score":
		return str(int(record.score))

	var meta_str := str(record.metadata)
	var meta := {}
	if not meta_str.is_empty():
		meta = JSON.parse_string(meta_str)
		if typeof(meta) != TYPE_DICTIONARY:
			meta = {}

	var raw_value := 0
	if format == "time":
		raw_value = meta.get(tab_data.meta_key, 0) if meta else 0
		var mins := raw_value / 60
		var secs := raw_value % 60
		return "%02d:%02d" % [mins, secs]
	else:
		raw_value = meta.get(tab_data.meta_key, 0) if meta else 0
		return str(raw_value)


func _populate_records(records: Array) -> void:
	for child in records_list.get_children():
		child.queue_free()

	var my_id: String = NakamaManager.session.user_id if NakamaManager.session else ""
	var tab_data: Dictionary = TABS[_current_tab]

	for i in range(records.size()):
		var record = records[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var rank := Label.new()
		rank.text = str(i + 1) + "."
		rank.custom_minimum_size = Vector2(40, 0)
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var name_label := Label.new()
		var owner_id: String = record.owner_id if record.owner_id else ""
		var display_name := str(record.username)
		if display_name.is_empty():
			display_name = NakamaManager.nickname if owner_id == my_id else owner_id
		name_label.text = display_name
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL

		var value_label := Label.new()
		value_label.text = _format_value(tab_data, record)
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

	var tab_data: Dictionary = TABS[_current_tab]
	var around = await NakamaManager.fetch_leaderboard_around_me(tab_data.id, 5)
	if around.is_empty():
		return

	var my_id: String = NakamaManager.session.user_id
	var found := false
	for record in around:
		if record.owner_id == my_id:
			var pos: int = int(record.rank) + 1
			var value_str := _format_value(tab_data, record)
			player_position_label.text = "Tu puesto: #" + str(pos) + " — " + value_str
			player_position_label.show()
			found = true
			break

	if not found:
		player_position_label.text = "Tu puesto: #—"
		player_position_label.show()


func _on_tab_changed(index: int) -> void:
	_current_tab = index
	_refresh()
