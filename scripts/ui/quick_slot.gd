class_name QuickSlot
extends Button


var hotbar: HotbarUI
var quick_index := -1


func configure(owner_hotbar: HotbarUI, index: int) -> void:
	hotbar = owner_hotbar
	quick_index = index


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if hotbar == null or not data is Dictionary:
		return false
	var item := (data as Dictionary).get("item") as ItemData
	return item != null and item.item_type == ItemData.ItemType.CONSUMABLE


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(Vector2.ZERO, data):
		hotbar.assign_from_drag(quick_index, data as Dictionary)
