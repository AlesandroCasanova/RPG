class_name HotbarUI
extends CanvasLayer


@onready var slots_root: HBoxContainer = $Anchor/Frame/Margin/Slots

var inventory: PlayerInventory
var player: CharacterBody2D
var slots: Array[QuickSlot] = []


func _ready() -> void:
	layer = 110
	add_to_group("hotbar_ui")
	for child: Node in slots_root.get_children():
		var slot := child as QuickSlot
		if slot == null:
			continue
		var index := slots.size()
		slots.append(slot)
		slot.configure(self, index)
	call_deferred("_connect_inventory")


func _connect_inventory() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or not player.has_method("get_inventory"):
		return
	inventory = player.get_inventory()
	inventory.inventory_changed.connect(_refresh)
	inventory.quick_slots_changed.connect(_refresh)
	var inventory_ui := get_tree().get_first_node_in_group("inventory_ui") as InventoryUI
	if inventory_ui != null:
		inventory_ui.inventory_opened.connect(_on_inventory_opened)
		inventory_ui.inventory_closed.connect(_on_inventory_closed)
	var dialogue_ui := get_tree().get_first_node_in_group("dialogue_ui") as DialogueUI
	if dialogue_ui != null:
		dialogue_ui.dialogue_started.connect(_on_dialogue_started)
		dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	_refresh()


func _on_inventory_opened() -> void:
	set_context_hidden(true)


func _on_inventory_closed() -> void:
	set_context_hidden(false)


func _on_dialogue_started() -> void:
	set_context_hidden(true)


func _on_dialogue_finished() -> void:
	set_context_hidden(false)


func set_context_hidden(hidden: bool) -> void:
	$Anchor.visible = not hidden


func _unhandled_input(event: InputEvent) -> void:
	for index: int in 6:
		if event.is_action_pressed("quick_slot_" + str(index + 1)):
			_use_slot(index)
			get_viewport().set_input_as_handled()
			return


func assign_from_drag(index: int, data: Dictionary) -> void:
	if inventory != null and String(data.get("source")) == "inventory" and inventory.move_stack_to_quick_slot(int(data.get("stack_index", -1)), index):
		_refresh()


func _use_slot(index: int) -> void:
	if inventory == null or player == null or index < 0 or index >= inventory.quick_slots.size():
		return
	var stack := inventory.get_quick_slot_stack(index)
	var item := stack.get("item") as ItemData
	if item == null or int(stack.get("quantity", 0)) <= 0 or not player.has_method("apply_consumable"):
		return
	if player.apply_consumable(item):
		inventory.consume_quick_slot(index)
	_refresh()


func _refresh() -> void:
	if inventory == null:
		return
	for index: int in slots.size():
		var slot := slots[index]
		var stack := inventory.get_quick_slot_stack(index)
		var item := stack.get("item") as ItemData
		slot.icon = item.icon if item != null else null
		var quantity := int(stack.get("quantity", 0))
		slot.text = str(index + 1) + ("  ×" + str(quantity) if quantity > 0 else "")
		# Nunca se deshabilita: una casilla vacía debe seguir aceptando drops.
		slot.disabled = false
		slot.modulate = Color.WHITE if item != null and quantity > 0 else Color(0.62, 0.58, 0.52, 1)
		slot.tooltip_text = item.get_detail_text() if item != null else "Arrastrá un consumible aquí"
