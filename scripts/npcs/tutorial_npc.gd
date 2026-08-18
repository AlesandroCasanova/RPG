class_name TutorialNPC
extends Area2D


signal interacted


@onready var character_sprite: Sprite2D = $CharacterSprite

@onready var quest_marker: Label = $QuestMarker

@onready var interaction_prompt: Label = $InteractionPrompt


var nearby_player: Node2D = null

var interaction_enabled: bool = true


func _ready() -> void:

	add_to_group("quest_npcs")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interaction_prompt.visible = false
	_start_idle_motion()


func _unhandled_input(event: InputEvent) -> void:

	if (
		nearby_player == null
		or not interaction_enabled
		or not event.is_action_pressed("interact")
	):

		return


	interacted.emit()
	get_viewport().set_input_as_handled()


func set_quest_marker(marker: String, color: Color) -> void:

	quest_marker.text = marker
	quest_marker.modulate = color
	quest_marker.visible = not marker.is_empty()


func set_interaction_enabled(enabled: bool) -> void:

	interaction_enabled = enabled
	interaction_prompt.visible = enabled and nearby_player != null


func _on_body_entered(body: Node2D) -> void:

	if not body.is_in_group("player"):

		return


	nearby_player = body
	interaction_prompt.visible = interaction_enabled


func _on_body_exited(body: Node2D) -> void:

	if body != nearby_player:

		return


	nearby_player = null
	interaction_prompt.visible = false


func _start_idle_motion() -> void:

	var tween: Tween = create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		character_sprite,
		"position:y",
		character_sprite.position.y - 2.5,
		1.35
	)
	tween.tween_property(
		character_sprite,
		"position:y",
		character_sprite.position.y,
		1.35
	)
