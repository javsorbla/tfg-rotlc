extends OverlaidWindow

@onready var records_list: VBoxContainer = %RecordsList
@onready var player_position_label: Label = %PlayerPositionLabel
@onready var loading_label: Label = %LoadingLabel
@onready var error_label: Label = %ErrorLabel


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	loading_label.show()
	error_label.hide()
	player_position_label.hide()

	var records = await NakamaManager.fetch_leaderboard_top(50)
	loading_label.hide()

	if records.is_empty():
		error_label.text = "No hay datos de clasificación"
		error_label.show()
		return

	_populate_records(records)
	_check_player_position()


func _populate_records(records: Array) -> void:
	for child in records_list.get_children():
		child.queue_free()

	var my_id: String = NakamaManager.session.user_id if NakamaManager.session else ""

	for i in range(records.size()):
		var record = records[i]

		if i < 3:
			print("Leaderboard record #", i, " owner_id=", record.owner_id, " username='", record.username, "' score=", record.score)

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

		var score_label := Label.new()
		score_label.text = str(int(record.score))
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.custom_minimum_size = Vector2(80, 0)

		row.add_child(rank)
		row.add_child(name_label)
		row.add_child(score_label)

		if owner_id == my_id:
			row.modulate = Color(1, 0.85, 0.3, 1)

		records_list.add_child(row)


func _check_player_position() -> void:
	if not NakamaManager.session:
		return

	var around = await NakamaManager.fetch_leaderboard_around_me(5)
	if around.is_empty():
		return

	var my_id: String = NakamaManager.session.user_id
	var found := false
	for record in around:
		if record.owner_id == my_id:
			var pos: int = int(record.rank) + 1
			var score: int = int(record.score)
			player_position_label.text = "Tu puesto: #" + str(pos) + " — Puntuación: " + str(score)
			player_position_label.show()
			found = true
			break

	if not found:
		player_position_label.text = "Tu puesto: #—"
		player_position_label.show()
