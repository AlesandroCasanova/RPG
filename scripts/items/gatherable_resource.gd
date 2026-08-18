class_name GatherableResource
extends Area2D


signal collected(resource: GatherableResource)

@export var item_data: ItemData
@export_range(1, 99, 1) var quantity := 1

@onready var icon: Sprite2D = $Icon
@onready var marker: Node2D = $Marker
@onready var prompt: Label = $Prompt

var nearby_player: CharacterBody2D


func _ready() -> void:
	add_to_group("tutorial_gatherables")
	if item_data != null:
		icon.texture = item_data.icon
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false


func _process(delta: float) -> void:
	marker.position.y = -58.0 + sin(Time.get_ticks_msec() * 0.004) * 5.0
	marker.rotation += delta * 0.8


func _unhandled_input(event: InputEvent) -> void:
	if nearby_player == null or not event.is_action_pressed("interact"):
		return
	var inventory: PlayerInventory = nearby_player.get_inventory()
	if inventory.add_item(item_data, quantity) == 0:
		collected.emit(self)
		queue_free()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		nearby_player = body as CharacterBody2D
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body == nearby_player:
		nearby_player = null
		prompt.visible = false
