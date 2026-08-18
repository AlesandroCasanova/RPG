class_name LootTransferSlot
extends Button


var loot_ui: LootWindowUI
var side: StringName = &"corpse"
var slot_index: int = -1


func configure(owner_ui: LootWindowUI, slot_side: StringName, index: int) -> void:
	loot_ui = owner_ui
	side = slot_side
	slot_index = index


func _get_drag_data(_at_position: Vector2) -> Variant:
	if loot_ui == null:
		return null
	return loot_ui.get_drag_data_for(side, slot_index, self)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return loot_ui != null and loot_ui.can_drop_on(side, slot_index, data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if loot_ui != null:
		loot_ui.drop_on(side, slot_index, data)
