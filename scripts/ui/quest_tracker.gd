class_name QuestTracker
extends CanvasLayer


var panel: PanelContainer

var title_label: Label

var objective_label: Label

var state_label: Label

var notification_label: Label


func _ready() -> void:

	layer = 20
	panel = $QuestPanel
	title_label = $QuestPanel/Margin/Content/TitleLabel
	objective_label = $QuestPanel/Margin/Content/ObjectiveLabel
	state_label = $QuestPanel/Margin/Content/StateLabel
	notification_label = $NotificationLabel


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
