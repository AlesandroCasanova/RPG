class_name LootWindowUI
extends CanvasLayer


const SLOT_SCENE := preload("res://scenes/ui/loot_transfer_slot.tscn")

@onready var root: Control = $Root
@onready var corpse_grid: GridContainer = $Root/Window/Margin/Layout/Columns/CorpseColumn/CorpseGrid
@onready var inventory_grid: GridContainer = $Root/Window/Margin/Layout/Columns/InventoryColumn/InventoryGrid
@onready var details: Label = $Root/Window/Margin/Layout/Details
@onready var close_button: Button = $Root/Window/Margin/Layout/Header/Close

var corpse: CorpseLoot
var inventory: PlayerInventory
var corpse_buttons: Array[LootTransferSlot] = []
var inventory_buttons: Array[LootTransferSlot] = []
var previous_pause_state := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	root.visible = false
	close_button.pressed.connect(close)
	_create_slots(corpse_grid, corpse_buttons, &"corpse", 12)
	_create_slots(inventory_grid, inventory_buttons, &"inventory", 32)


func _create_slots(grid: GridContainer, output: Array[LootTransferSlot], side: StringName, count: int) -> void:
	for index: int in count:
		var slot := SLOT_SCENE.instantiate() as LootTransferSlot
		grid.add_child(slot)
		output.append(slot)
		slot.configure(self, side, index)
		slot.mouse_entered.connect(_hover_slot.bind(side, index))


func open_for(target: CorpseLoot) -> void:
	corpse = target
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("get_inventory"):
		return
	inventory = player.get_inventory()
	previous_pause_state = get_tree().paused
	root.visible = true
	var hotbar := get_tree().get_first_node_in_group("hotbar_ui") as HotbarUI
	if hotbar != null:
		hotbar.set_context_hidden(true)
	get_tree().paused = true
	corpse.mark_opened()
	_refresh()


func close() -> void:
	if not root.visible:
		return
	root.visible = false
	var hotbar := get_tree().get_first_node_in_group("hotbar_ui") as HotbarUI
	if hotbar != null:
		hotbar.set_context_hidden(false)
	get_tree().paused = previous_pause_state
	if is_instance_valid(corpse):
		corpse.refresh_loot_state()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if root.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_refresh_side(corpse_buttons, corpse.loot_stacks if is_instance_valid(corpse) else [])
	_refresh_side(inventory_buttons, inventory.stacks if inventory != null else [])
	details.text = "Arrastrá los objetos del cuerpo a tu mochila. F o ESC para cerrar."


func _refresh_side(buttons: Array[LootTransferSlot], stacks: Array) -> void:
	for index: int in buttons.size():
		var button := buttons[index]
		button.icon = null
		button.text = ""
		button.tooltip_text = "Espacio vacío"
		if index >= stacks.size():
			continue
		var item := stacks[index].get("item") as ItemData
		if item == null:
			continue
		var quantity := int(stacks[index].get("quantity", 1))
		button.icon = item.icon
		button.text = "×" + str(quantity) if quantity > 1 else ""
		button.tooltip_text = item.get_detail_text()


func _hover_slot(side: StringName, index: int) -> void:
	var stacks: Array = corpse.loot_stacks if side == &"corpse" and is_instance_valid(corpse) else inventory.stacks
	if index < 0 or index >= stacks.size():
		return
	var item := stacks[index].get("item") as ItemData
	if item != null:
		details.text = item.get_detail_text()


func get_drag_data_for(side: StringName, index: int, control: Control) -> Variant:
	var stacks: Array = corpse.loot_stacks if side == &"corpse" and is_instance_valid(corpse) else inventory.stacks
	if index < 0 or index >= stacks.size():
		return null
	var item := stacks[index].get("item") as ItemData
	if item == null:
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(52, 52)
	preview.texture = item.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control.set_drag_preview(preview)
	return {"source": side, "index": index, "item": item}


func can_drop_on(side: StringName, index: int, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if side == &"inventory" and StringName(data.get("source")) == &"corpse":
		return index >= 0 and index < 32
	return false


func drop_on(side: StringName, index: int, data: Variant) -> void:
	if not can_drop_on(side, index, data) or not is_instance_valid(corpse):
		return
	var corpse_index := int((data as Dictionary).get("index", -1))
	if corpse_index < 0 or corpse_index >= corpse.loot_stacks.size():
		return
	var stack: Dictionary = corpse.loot_stacks[corpse_index]
	var item := stack.get("item") as ItemData
	var quantity := int(stack.get("quantity", 1))
	var remaining := inventory.add_item(item, quantity)
	if remaining <= 0:
		corpse.loot_stacks.remove_at(corpse_index)
	else:
		corpse.loot_stacks[corpse_index]["quantity"] = remaining
	corpse.refresh_loot_state()
	_refresh()
