class_name DialogueUI
extends CanvasLayer


signal dialogue_finished
signal dialogue_started
signal choice_selected(dialogue_id: StringName, choice_id: StringName)


var overlay: ColorRect

var speaker_label: Label

var body_label: Label

var hint_label: Label

var lines: Array[String] = []

var current_line: int = 0

var active: bool = false

var input_lock_time: float = 0.0

var completion_callback: Callable
var dialogue_entries: Array[Dictionary] = []
var left_portrait: TextureRect
var right_portrait: TextureRect
var left_frame: PanelContainer
var right_frame: PanelContainer
var choices_container: VBoxContainer
var active_dialogue_id: StringName = &""
var pending_choices: Array[DialogueChoiceData] = []
var selected_choice_id: StringName = &""
var choice_callback: Callable

const MAELA_PORTRAIT := preload("res://assets/characters/npcs/maela/maela_poor.png")
const IVAR_PORTRAIT := preload("res://assets/characters/npcs/ivar/ivar_poor.png")
const PLAYER_PORTRAIT := preload("res://assets/characters/player/sprites/idle/player_idle.png")
const GOBLIN_SHEET := preload("res://assets/characters/enemies/goblin/sprites/idle/goblien_sheet_cardinal.png")


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialogue_ui")
	layer = 100
	overlay = $DialogueOverlay
	speaker_label = $DialogueOverlay/Panel/Margin/Content/SpeakerLabel
	body_label = $DialogueOverlay/Panel/Margin/Content/BodyLabel
	hint_label = $DialogueOverlay/Panel/Margin/Content/HintLabel
	left_frame = $DialogueOverlay/LeftPortraitFrame
	right_frame = $DialogueOverlay/RightPortraitFrame
	left_portrait = $DialogueOverlay/LeftPortraitFrame/Portrait
	right_portrait = $DialogueOverlay/RightPortraitFrame/Portrait
	choices_container = $DialogueOverlay/Panel/Margin/Content/Choices
	left_frame.visible = false
	right_frame.visible = false
	overlay.visible = false
	choices_container.visible = false


func _process(delta: float) -> void:

	input_lock_time = maxf(input_lock_time - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:

	if not active or input_lock_time > 0.0 or choices_container.visible:

		return


	if (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	):

		_advance()
		get_viewport().set_input_as_handled()


func show_dialogue(
	speaker: String,
	new_lines: Array[String],
	on_complete: Callable = Callable()
) -> void:

	if new_lines.is_empty():

		return
	_reset_data_dialogue_state()
	lines = new_lines
	dialogue_entries.clear()
	for line: String in new_lines:
		dialogue_entries.append({"speaker": speaker, "text": line, "side": _default_side(speaker)})
	current_line = 0
	completion_callback = on_complete
	active = true
	input_lock_time = 0.22
	left_frame.visible = false
	right_frame.visible = false
	_show_entry(0)
	overlay.visible = true
	dialogue_started.emit()
	get_tree().paused = true


func show_cinematic_dialogue(new_entries: Array[Dictionary], on_complete: Callable = Callable()) -> void:
	if new_entries.is_empty():
		return
	_reset_data_dialogue_state()
	dialogue_entries = new_entries
	lines.clear()
	for entry: Dictionary in new_entries:
		lines.append(String(entry.get("text", "")))
	current_line = 0
	completion_callback = on_complete
	active = true
	input_lock_time = 0.22
	left_frame.visible = false
	right_frame.visible = false
	_show_entry(0)
	overlay.visible = true
	dialogue_started.emit()
	get_tree().paused = true


func show_npc_dialogue(
	npc_data: NPCData,
	dialogue_id: StringName,
	on_complete: Callable = Callable()
) -> void:
	if npc_data == null:
		push_warning("DialogueUI: faltan los datos del NPC.")
		return
	var data := npc_data.get_dialogue(dialogue_id)
	if data == null:
		push_warning("DialogueUI: diálogo '%s' no encontrado en %s." % [dialogue_id, npc_data.display_name])
		return
	_show_dialogue_data(data, npc_data, on_complete)


func show_dialogue_data(
	data: DialogueData,
	on_complete: Callable = Callable()
) -> void:
	_show_dialogue_data(data, null, on_complete)


func _show_dialogue_data(
	data: DialogueData,
	npc_data: NPCData,
	on_complete: Callable
) -> void:
	if data == null or data.entries.is_empty():
		return
	_reset_data_dialogue_state()
	active_dialogue_id = data.dialogue_id
	pending_choices.append_array(data.choices)
	if pending_choices.is_empty():
		completion_callback = on_complete
	else:
		choice_callback = on_complete
	dialogue_entries.clear()
	lines.clear()
	for entry: DialogueEntryData in data.entries:
		if entry == null:
			continue
		var speaker := entry.speaker
		var portrait := entry.portrait
		if npc_data != null:
			if speaker.is_empty():
				speaker = npc_data.display_name
			if portrait == null:
				portrait = npc_data.portrait
		var runtime_entry := {
			"speaker": speaker,
			"text": entry.text,
			"side": entry.side,
			"portrait": portrait
		}
		dialogue_entries.append(runtime_entry)
		lines.append(entry.text)
	if dialogue_entries.is_empty():
		return
	current_line = 0
	active = true
	input_lock_time = 0.22
	left_frame.visible = false
	right_frame.visible = false
	_show_entry(0)
	overlay.visible = true
	dialogue_started.emit()
	get_tree().paused = true


func is_dialogue_active() -> bool:

	return active


func _advance() -> void:

	current_line += 1


	if current_line < lines.size():

		_show_entry(current_line)
		return
	if not pending_choices.is_empty():
		_show_choices()
		return
	_finish_dialogue()


func _show_choices() -> void:
	choices_container.visible = true
	body_label.text = "Elegí una respuesta:"
	hint_label.visible = false
	for child: Node in choices_container.get_children():
		child.queue_free()
	for choice: DialogueChoiceData in pending_choices:
		if choice == null:
			continue
		var button := Button.new()
		button.text = choice.label
		button.custom_minimum_size.y = 36.0
		button.pressed.connect(_select_choice.bind(choice))
		choices_container.add_child(button)
	var first_button := choices_container.get_child(0) as Button if choices_container.get_child_count() > 0 else null
	if first_button != null:
		first_button.grab_focus()


func _select_choice(choice: DialogueChoiceData) -> void:
	selected_choice_id = choice.choice_id
	choice_selected.emit(active_dialogue_id, selected_choice_id)
	choices_container.visible = false
	hint_label.visible = true
	pending_choices.clear()
	for child: Node in choices_container.get_children():
		child.queue_free()
	if choice.response_entries.is_empty():
		_finish_dialogue()
		return
	dialogue_entries.clear()
	lines.clear()
	for entry: DialogueEntryData in choice.response_entries:
		if entry == null:
			continue
		dialogue_entries.append({
			"speaker": entry.speaker,
			"text": entry.text,
			"side": entry.side,
			"portrait": entry.portrait
		})
		lines.append(entry.text)
	current_line = 0
	input_lock_time = 0.18
	_show_entry(0)


func _finish_dialogue() -> void:
	active = false
	overlay.visible = false
	choices_container.visible = false
	hint_label.visible = true
	get_tree().paused = false
	dialogue_finished.emit()
	if choice_callback.is_valid():
		choice_callback.call_deferred(selected_choice_id)
	elif completion_callback.is_valid():
		completion_callback.call_deferred()


func _reset_data_dialogue_state() -> void:
	active_dialogue_id = &""
	pending_choices.clear()
	selected_choice_id = &""
	choice_callback = Callable()
	completion_callback = Callable()
	choices_container.visible = false
	hint_label.visible = true


func _show_entry(index: int) -> void:
	var entry := dialogue_entries[index]
	var speaker := String(entry.get("speaker", ""))
	var side := String(entry.get("side", _default_side(speaker)))
	speaker_label.text = _resolve_speaker_name(speaker)
	body_label.text = _resolve_player_name(String(entry.get("text", "")))
	var portrait := entry.get("portrait") as Texture2D
	if portrait == null:
		portrait = _portrait_for(speaker)
	if side == "left":
		left_portrait.texture = portrait
		left_frame.visible = portrait != null
		left_frame.modulate = Color.WHITE
		right_frame.modulate = Color(0.38, 0.38, 0.38, 0.78)
	else:
		right_portrait.texture = portrait
		right_frame.visible = portrait != null
		right_frame.modulate = Color.WHITE
		left_frame.modulate = Color(0.38, 0.38, 0.38, 0.78)


func _default_side(speaker: String) -> String:
	return "left" if speaker in ["El Ambicioso", "Protagonista", "{player_name}"] else "right"


func _get_player_name() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("get_character_name"):
		return String(player.get_character_name())
	return "El Ambicioso"


func _resolve_speaker_name(speaker: String) -> String:
	if speaker in ["El Ambicioso", "Protagonista", "{player_name}"]:
		return _get_player_name()
	return _resolve_player_name(speaker)


func _resolve_player_name(text: String) -> String:
	return text.replace("{player_name}", _get_player_name())


func _portrait_for(speaker: String) -> Texture2D:
	match speaker:
		"Maela", "Nara": return MAELA_PORTRAIT
		"Ivar": return IVAR_PORTRAIT
		"El Ambicioso", "Protagonista", "{player_name}": return PLAYER_PORTRAIT
		"Goblin":
			var atlas := AtlasTexture.new()
			atlas.atlas = GOBLIN_SHEET
			atlas.region = Rect2(3, 0, 191, 511)
			return atlas
	return null
