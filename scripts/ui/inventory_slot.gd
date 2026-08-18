class_name InventorySlot
extends Button


var inventory_ui: InventoryUI
var stack_index: int = -1
var equipment_slot: int = ItemData.EquipmentSlot.NONE


func configure_inventory(owner_ui: InventoryUI, index: int) -> void:
	inventory_ui = owner_ui
	stack_index = index
	equipment_slot = ItemData.EquipmentSlot.NONE


func configure_equipment(owner_ui: InventoryUI, slot: int) -> void:
	inventory_ui = owner_ui
	stack_index = -1
	equipment_slot = slot


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory_ui == null:
		return null
	return inventory_ui.get_slot_drag_data(self)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return inventory_ui != null and inventory_ui.can_drop_on_slot(self, data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory_ui != null:
		inventory_ui.drop_on_slot(self, data)
