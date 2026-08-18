class_name QuestTracker
extends CanvasLayer


var panel: PanelContainer

var title_label: Label

var objective_label: Label

var state_label: Label

var notification_label: Label


func _ready() -> void:

	layer = 20
	_build_interface()


func set_quest(title: String, objective: String, state: String = "") -> void:

	title_label.text = title
	objective_label.text = objective
	state_label.text = state
	panel.visible = true


func mark_completed(reward_text: String) -> void:

	state_label.text = "MISIÓN CUMPLIDA"
	state_label.modulate = Color(0.42, 1.0, 0.5, 1.0)
	objective_label.text = reward_text


func show_notification(text: String, color: Color = Color.WHITE) -> void:

	notification_label.text = text
	notification_label.modulate = color
	notification_label.visible = true
	notification_label.position.y = 128.0


	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(
		notification_label,
		"position:y",
		146.0,
		0.25
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.7)
	tween.tween_property(
		notification_label,
		"modulate:a",
		0.0,
		0.45
	)
	tween.tween_callback(notification_label.hide)
	tween.tween_callback(
		func() -> void:
			notification_label.modulate.a = 1.0
	)


func _build_interface() -> void:

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -370.0
	panel.offset_top = 24.0
	panel.offset_right = -24.0
	panel.offset_bottom = 146.0


	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.028, 0.9)
	style.border_color = Color(0.36, 0.28, 0.16, 0.95)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)


	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)


	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)


	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.75, 0.32, 1.0)
	)
	content.add_child(title_label)


	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override(
		"font_color",
		Color(0.9, 0.87, 0.78, 1.0)
	)
	content.add_child(objective_label)


	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 12)
	state_label.add_theme_color_override(
		"font_color",
		Color(0.62, 0.68, 0.55, 1.0)
	)
	content.add_child(state_label)


	notification_label = Label.new()
	notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification_label.position = Vector2(-300.0, 128.0)
	notification_label.custom_minimum_size = Vector2(600.0, 48.0)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 22)
	notification_label.add_theme_color_override(
		"font_outline_color",
		Color(0.03, 0.02, 0.01, 1.0)
	)
	notification_label.add_theme_constant_override("outline_size", 7)
	notification_label.visible = false
	add_child(notification_label)
