class_name InvestigationPoint
extends Area2D


signal investigated(point: InvestigationPoint)


@export var point_id: StringName = &"corruption_site"

@onready var marker: Label = $Marker

@onready var prompt: Label = $Prompt

@onready var scar_sprite: Sprite2D = $ScarSprite


var active: bool = false

var completed: bool = false

var nearby_player: Node2D = null


func _ready() -> void:

	add_to_group("investigation_points")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	marker.visible = false
	prompt.visible = false
	_start_corruption_pulse()


func _unhandled_input(event: InputEvent) -> void:

	if (
		not active
		or completed
		or nearby_player == null
		or not event.is_action_pressed("interact")
	):

		return


	completed = true
	active = false
	marker.visible = false
	prompt.visible = false
	scar_sprite.modulate = Color(0.48, 0.42, 0.48, 0.82)
	investigated.emit(self)
	get_viewport().set_input_as_handled()


func set_active(enabled: bool) -> void:

	active = enabled and not completed
	marker.visible = active
	prompt.visible = active and nearby_player != null


func _on_body_entered(body: Node2D) -> void:

	if not body.is_in_group("player"):

		return


	nearby_player = body
	prompt.visible = active and not completed


func _on_body_exited(body: Node2D) -> void:

	if body != nearby_player:

		return


	nearby_player = null
	prompt.visible = false


func _start_corruption_pulse() -> void:

	var tween: Tween = create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		scar_sprite,
		"self_modulate",
		Color(1.18, 0.72, 1.12, 1.0),
		1.2
	)
	tween.tween_property(
		scar_sprite,
		"self_modulate",
		Color.WHITE,
		1.2
	)
