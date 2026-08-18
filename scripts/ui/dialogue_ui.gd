class_name DialogueUI
extends CanvasLayer


signal dialogue_finished


var overlay: ColorRect

var speaker_label: Label

var body_label: Label

var hint_label: Label

var lines: Array[String] = []

var current_line: int = 0

var active: bool = false

var input_lock_time: float = 0.0

var completion_callback: Callable


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_interface()
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
	current_line = 0
	completion_callback = on_complete
	active = true
	input_lock_time = 0.22
	speaker_label.text = speaker
	body_label.text = lines[0]
	overlay.visible = true
	get_tree().paused = true


func is_dialogue_active() -> bool:

	return active


func _advance() -> void:

	current_line += 1


	if current_line < lines.size():

		body_label.text = lines[current_line]
		return


	active = false
	overlay.visible = false
	get_tree().paused = false
	dialogue_finished.emit()


	if completion_callback.is_valid():

		completion_callback.call_deferred()


func _build_interface() -> void:

	overlay = ColorRect.new()
	overlay.name = "DialogueOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.012, 0.01, 0.28)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)


	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -470.0
	panel.offset_top = -230.0
	panel.offset_right = 470.0
	panel.offset_bottom = -36.0
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	overlay.add_child(panel)


	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)


	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)


	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 25)
	speaker_label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.72, 0.28, 1.0)
	)
	content.add_child(speaker_label)


	body_label = Label.new()
	body_label.custom_minimum_size = Vector2(0.0, 86.0)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 19)
	body_label.add_theme_color_override(
		"font_color",
		Color(0.93, 0.9, 0.82, 1.0)
	)
	content.add_child(body_label)


	hint_label = Label.new()
	hint_label.text = "F / ESPACIO  ·  continuar"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override(
		"font_color",
		Color(0.65, 0.61, 0.53, 1.0)
	)
	content.add_child(hint_label)


func _make_panel_style() -> StyleBoxFlat:

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.035, 0.97)
	style.border_color = Color(0.47, 0.32, 0.15, 1.0)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 12
	return style
