class_name InventoryUI
extends CanvasLayer


signal inventory_opened
signal inventory_closed

const SLOT_COUNT: int = 32

@onready var inventory_root: Control = $InventoryRoot
@onready var loot_grid: GridContainer = $InventoryRoot/Frame/Margin/Layout/Columns/LootColumn/LootGrid
@onready var capacity_label: Label = $InventoryRoot/Frame/Margin/Layout/Columns/LootColumn/LootHeader/CapacityLabel
@onready var details_label: Label = $InventoryRoot/Frame/Margin/Layout/Columns/LootColumn/DetailsPanel/DetailsScroll/DetailsLabel
@onready var equip_button: Button = $InventoryRoot/Frame/Margin/Layout/Columns/LootColumn/EquipButton
@onready var preview_sprite: AnimatedSprite2D = $InventoryRoot/Frame/Margin/Layout/Columns/CharacterColumn/PreviewStage/PlayerPreview
@onready var stats_label: Label = $InventoryRoot/Frame/Margin/Layout/Columns/CharacterColumn/StatsPanel/StatsLabel
@onready var close_button: Button = $InventoryRoot/Frame/Margin/Layout/Header/CloseButton
@onready var title_label: Label = $InventoryRoot/Frame/Margin/Layout/Header/Title
@onready var character_title: Label = $InventoryRoot/Frame/Margin/Layout/Columns/CharacterColumn/CharacterTitle

var player: CharacterBody2D
var inventory: PlayerInventory
var loot_slots: Array[Button] = []
var equipment_buttons: Dictionary = {}
var empty_slot_labels: Dictionary = {}
var selected_stack_index: int = -1
var previous_pause_state: bool = false
var inventory_quick_slots: Array[QuickSlot] = []
var hotbar: HotbarUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	inventory_root.visible = false
	add_to_group("inventory_ui")
	_register_loot_slots()
	_register_equipment_slots()
	_register_quick_access_slots()
	close_button.pressed.connect(_close_inventory)
	equip_button.pressed.connect(_equip_selected_item)
	call_deferred("_connect_inventory")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if inventory_root.visible:
			_close_inventory()
		else:
			_open_inventory()
		get_viewport().set_input_as_handled()
		return
	if inventory_root.visible and event.is_action_pressed("ui_cancel"):
		_close_inventory()
		get_viewport().set_input_as_handled()


func _register_loot_slots() -> void:
	for child: Node in loot_grid.get_children():
		var button := child as Button
		if button == null:
			continue
		var index: int = loot_slots.size()
		loot_slots.append(button)
		if button is InventorySlot:
			(button as InventorySlot).configure_inventory(self, index)
		button.pressed.connect(_select_stack.bind(index))
		button.mouse_entered.connect(_hover_stack.bind(index))
		button.mouse_exited.connect(_restore_selected_details)


func _register_equipment_slots() -> void:
	var stage: Control = $InventoryRoot/Frame/Margin/Layout/Columns/EquipmentColumn/EquipmentStage
	_register_equipment_button(stage.get_node("WeaponSlot"), ItemData.EquipmentSlot.WEAPON, "ESPADA")
	_register_equipment_button(stage.get_node("HeadSlot"), ItemData.EquipmentSlot.HEAD, "CASCO")
	_register_equipment_button(stage.get_node("ChestSlot"), ItemData.EquipmentSlot.CHEST, "PECHO")
	_register_equipment_button(stage.get_node("LegsSlot"), ItemData.EquipmentSlot.LEGS, "PANTALÓN")
	_register_equipment_button(stage.get_node("BootsSlot"), ItemData.EquipmentSlot.BOOTS, "BOTAS")
	_register_equipment_button(stage.get_node("GlovesSlot"), ItemData.EquipmentSlot.GLOVES, "GUANTES")
	_register_equipment_button(stage.get_node("RingLeftSlot"), ItemData.EquipmentSlot.RING_LEFT, "ANILLO I")
	_register_equipment_button(stage.get_node("RingRightSlot"), ItemData.EquipmentSlot.RING_RIGHT, "ANILLO II")
	_register_equipment_button(stage.get_node("AmuletSlot"), ItemData.EquipmentSlot.AMULET, "AMULETO")


func _register_quick_access_slots() -> void:
	var row := $InventoryRoot/Frame/Margin/Layout/Columns/LootColumn/QuickAccessRow
	for child: Node in row.get_children():
		var slot := child as QuickSlot
		if slot != null:
			inventory_quick_slots.append(slot)


func _register_equipment_button(button: Button, slot: ItemData.EquipmentSlot, label: String) -> void:
	equipment_buttons[slot] = button
	empty_slot_labels[slot] = label
	button.pressed.connect(_unequip_slot.bind(slot))
	if button is InventorySlot:
		(button as InventorySlot).configure_equipment(self, slot)
	button.mouse_entered.connect(_hover_equipment.bind(slot))
	button.mouse_exited.connect(_restore_selected_details)


func _connect_inventory() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or not player.has_method("get_inventory"):
		push_warning("InventoryUI: no se encontró el inventario del Player.")
		return
	inventory = player.get_inventory()
	if inventory == null:
		push_warning("InventoryUI: el Player no tiene nodo Inventory.")
		return
	_update_character_name()
	var name_changed_callback := Callable(self, "_on_character_name_changed")
	if player.has_signal("character_name_changed") and not player.is_connected("character_name_changed", name_changed_callback):
		player.connect("character_name_changed", name_changed_callback)
	inventory.capacity = SLOT_COUNT
	inventory.inventory_changed.connect(_refresh)
	inventory.equipment_changed.connect(_refresh)
	inventory.quick_slots_changed.connect(_refresh)
	hotbar = get_tree().get_first_node_in_group("hotbar_ui") as HotbarUI
	if hotbar != null:
		for index: int in inventory_quick_slots.size():
			inventory_quick_slots[index].configure(hotbar, index)
	_configure_player_preview()
	_refresh()


func _on_character_name_changed(_new_name: String) -> void:
	_update_character_name()


func _update_character_name() -> void:
	var player_name := "El Ambicioso"
	if player != null and player.has_method("get_character_name"):
		player_name = String(player.get_character_name())
	title_label.text = "INVENTARIO DE " + player_name.to_upper()
	character_title.text = player_name.to_upper()


func _configure_player_preview() -> void:
	var world_sprite := player.get_node_or_null("PlayerAnimated") as AnimatedSprite2D
	if world_sprite == null:
		return
	preview_sprite.sprite_frames = world_sprite.sprite_frames
	preview_sprite.animation = &"idle_s"
	preview_sprite.play()


func _open_inventory() -> void:
	if inventory == null:
		_connect_inventory()
	previous_pause_state = get_tree().paused
	inventory_root.visible = true
	get_tree().paused = true
	inventory_opened.emit()
	_refresh()


func _close_inventory() -> void:
	if not inventory_root.visible:
		return
	inventory_root.visible = false
	get_tree().paused = previous_pause_state
	inventory_closed.emit()


func _refresh() -> void:
	if inventory == null:
		return
	capacity_label.text = str(inventory.stacks.size()) + " / " + str(SLOT_COUNT)
	for index: int in range(loot_slots.size()):
		var button: Button = loot_slots[index]
		button.icon = null
		button.text = ""
		button.tooltip_text = "Espacio vacío"
		button.modulate = Color.WHITE
		button.button_pressed = index == selected_stack_index
		if index >= inventory.stacks.size():
			continue
		var stack: Dictionary = inventory.stacks[index]
		var item := stack.get("item") as ItemData
		if item == null:
			continue
		var quantity: int = int(stack.get("quantity", 1))
		button.icon = item.icon
		button.text = "×" + str(quantity) if quantity > 1 else ""
		button.tooltip_text = item.get_detail_text()
		if inventory.is_item_equipped(item):
			button.modulate = Color(1.0, 0.82, 0.48, 1.0)
	_update_selected_details()
	_update_equipment_slots()
	_update_stats_text()
	_update_quick_access()


func _select_stack(index: int) -> void:
	selected_stack_index = index if inventory != null and index < inventory.stacks.size() else -1
	_refresh()


func _update_selected_details() -> void:
	equip_button.disabled = true
	if selected_stack_index < 0 or selected_stack_index >= inventory.stacks.size():
		details_label.text = "Seleccioná un objeto para consultar sus detalles."
		return
	var item := inventory.stacks[selected_stack_index].get("item") as ItemData
	if item == null:
		return
	details_label.text = item.get_detail_text()
	equip_button.disabled = not item.is_equipment()


func _equip_selected_item() -> void:
	if inventory != null and inventory.equip_stack(selected_stack_index):
		selected_stack_index = -1
		_refresh()


func _unequip_slot(slot: ItemData.EquipmentSlot) -> void:
	if inventory != null:
		inventory.unequip_slot(slot)


func _update_equipment_slots() -> void:
	for slot_variant: Variant in equipment_buttons:
		var slot: ItemData.EquipmentSlot = slot_variant as ItemData.EquipmentSlot
		var button: Button = equipment_buttons[slot]
		var item: ItemData = inventory.get_equipped_item(slot)
		var placeholder := button.get_node_or_null("Placeholder") as TextureRect
		button.icon = item.icon if item != null else null
		button.text = ""
		if placeholder != null:
			placeholder.visible = item == null
		button.tooltip_text = (
			item.get_detail_text() + "\nArrastrá a la mochila para quitar"
			if item != null
			else String(empty_slot_labels[slot]) + " vacío"
		)


func _hover_stack(index: int) -> void:
	if inventory == null or index < 0 or index >= inventory.stacks.size():
		return
	var item := inventory.stacks[index].get("item") as ItemData
	if item != null:
		details_label.text = item.get_detail_text()


func _hover_equipment(slot: ItemData.EquipmentSlot) -> void:
	if inventory == null:
		return
	var item := inventory.get_equipped_item(slot)
	if item != null:
		details_label.text = item.get_detail_text()


func _restore_selected_details() -> void:
	_update_selected_details()


func get_slot_drag_data(slot: InventorySlot) -> Variant:
	if inventory == null:
		return null
	var item: ItemData
	var data: Dictionary
	if slot.stack_index >= 0 and slot.stack_index < inventory.stacks.size():
		item = inventory.stacks[slot.stack_index].get("item") as ItemData
		data = {"source": "inventory", "stack_index": slot.stack_index, "item": item}
	elif slot.equipment_slot != ItemData.EquipmentSlot.NONE:
		item = inventory.get_equipped_item(slot.equipment_slot)
		data = {"source": "equipment", "equipment_slot": slot.equipment_slot, "item": item}
	if item == null:
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(48, 48)
	preview.texture = item.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.set_drag_preview(preview)
	return data


func can_drop_on_slot(slot: InventorySlot, data: Variant) -> bool:
	if inventory == null or not data is Dictionary:
		return false
	var item := (data as Dictionary).get("item") as ItemData
	if item == null:
		return false
	if slot.equipment_slot != ItemData.EquipmentSlot.NONE:
		return item.is_equipment() and item.equipment_slot == slot.equipment_slot
	return slot.stack_index >= 0


func drop_on_slot(slot: InventorySlot, data: Variant) -> void:
	if not can_drop_on_slot(slot, data):
		return
	var payload := data as Dictionary
	if slot.equipment_slot != ItemData.EquipmentSlot.NONE:
		if String(payload.get("source")) == "inventory":
			inventory.equip_stack(int(payload.get("stack_index", -1)))
		return
	if String(payload.get("source")) == "equipment":
		inventory.unequip_slot(int(payload.get("equipment_slot", 0)) as ItemData.EquipmentSlot)
	elif String(payload.get("source")) == "inventory":
		inventory.move_stack(int(payload.get("stack_index", -1)), slot.stack_index)


func _update_stats_text() -> void:
	if player == null:
		return
	stats_label.text = (
		"VIT " + str(player.get("effective_vitality"))
		+ "   FUE " + str(player.get("effective_strength"))
		+ "   DES " + str(player.get("effective_dexterity"))
		+ "\nAGU " + str(player.get("effective_endurance"))
		+ "   INT " + str(player.get("effective_intelligence"))
		+ "   VOL " + str(player.get("effective_willpower"))
		+ "\n\nVIDA " + str(player.get("max_health"))
		+ "   STAMINA " + str(roundi(float(player.get("max_stamina"))))
		+ "   MANÁ " + str(roundi(float(player.get("max_mana"))))
		+ "\nDAÑO " + str(player.get("attack_damage"))
		+ "   MAGIA " + str(snappedf(float(player.get("magic_power")), 0.1))
	)


func _update_quick_access() -> void:
	if inventory == null:
		return
	for index: int in inventory_quick_slots.size():
		var slot := inventory_quick_slots[index]
		var stack := inventory.get_quick_slot_stack(index)
		var item := stack.get("item") as ItemData
		var quantity := int(stack.get("quantity", 0))
		slot.icon = item.icon if item != null else null
		slot.text = str(index + 1) + (" ×" + str(quantity) if quantity > 0 else "")
		slot.tooltip_text = item.get_detail_text() if item != null else "Arrastrá un consumible"
