class_name DialogueUI
extends CanvasLayer


signal dialogue_finished
signal dialogue_started


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
	left_frame.visible = false
	right_frame.visible = false
	overlay.visible = false


func _process(delta: float) -> void:

	input_lock_time = maxf(input_lock_time - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:

	if not active or input_lock_time > 0.0:

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


func is_dialogue_active() -> bool:

	return active


func _advance() -> void:

	current_line += 1


	if current_line < lines.size():

		_show_entry(current_line)
		return


	active = false
	overlay.visible = false
	get_tree().paused = false
	dialogue_finished.emit()


	if completion_callback.is_valid():

		completion_callback.call_deferred()


func _show_entry(index: int) -> void:
	var entry := dialogue_entries[index]
	var speaker := String(entry.get("speaker", ""))
	var side := String(entry.get("side", _default_side(speaker)))
	speaker_label.text = speaker
	body_label.text = String(entry.get("text", ""))
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
	return "left" if speaker in ["El Ambicioso", "Protagonista"] else "right"


func _portrait_for(speaker: String) -> Texture2D:
	match speaker:
		"Maela", "Nara": return MAELA_PORTRAIT
		"Ivar": return IVAR_PORTRAIT
		"El Ambicioso", "Protagonista": return PLAYER_PORTRAIT
		"Goblin":
			var atlas := AtlasTexture.new()
			atlas.atlas = GOBLIN_SHEET
			atlas.region = Rect2(3, 0, 191, 511)
			return atlas
	return null
