class_name PlayerInventory
extends Node


signal inventory_changed
signal equipment_changed
signal item_added(item: ItemData, quantity: int)


@export_range(1, 100, 1)
var capacity: int = 20


var stacks: Array[Dictionary] = []

var equipped: Dictionary = {
	ItemData.EquipmentSlot.WEAPON: null,
	ItemData.EquipmentSlot.ARMOR: null,
	ItemData.EquipmentSlot.ACCESSORY: null
}


func _ready() -> void:

	call_deferred("_apply_equipment_bonuses")


func add_item(item: ItemData, quantity: int = 1) -> int:

	if item == null or quantity <= 0:

		return quantity


	var remaining: int = quantity


	if item.stackable:

		for stack: Dictionary in stacks:

			if stack.get("item") != item:

				continue


			var current_quantity: int = int(stack.get("quantity", 0))
			var available_space: int = maxi(
				item.max_stack - current_quantity,
				0
			)
			var amount_to_add: int = mini(available_space, remaining)


			stack["quantity"] = current_quantity + amount_to_add
			remaining -= amount_to_add


			if remaining <= 0:

				break


	while remaining > 0 and stacks.size() < capacity:

		var stack_quantity: int = (
			mini(remaining, item.max_stack)
			if item.stackable
			else 1
		)
		stacks.append({
			"item": item,
			"quantity": stack_quantity
		})
		remaining -= stack_quantity


	var added_quantity: int = quantity - remaining


	if added_quantity > 0:

		inventory_changed.emit()
		item_added.emit(item, added_quantity)


	return remaining


func equip_stack(index: int) -> bool:

	if index < 0 or index >= stacks.size():

		return false


	var item: ItemData = stacks[index].get("item") as ItemData


	if item == null or not item.is_equipment():

		return false


	equipped[item.equipment_slot] = item
	_apply_equipment_bonuses()
	equipment_changed.emit()
	inventory_changed.emit()


	return true


func unequip_slot(slot: ItemData.EquipmentSlot) -> void:

	if not equipped.has(slot) or equipped[slot] == null:

		return


	equipped[slot] = null
	_apply_equipment_bonuses()
	equipment_changed.emit()
	inventory_changed.emit()


func is_item_equipped(item: ItemData) -> bool:

	return item != null and item in equipped.values()


func get_equipped_item(slot: ItemData.EquipmentSlot) -> ItemData:

	return equipped.get(slot) as ItemData


func get_total_bonuses() -> Dictionary:

	var totals: Dictionary = {
		"vitality": 0,
		"strength": 0,
		"dexterity": 0,
		"endurance": 0,
		"intelligence": 0,
		"willpower": 0
	}


	for item_variant: Variant in equipped.values():

		if not item_variant is ItemData:

			continue


		var item: ItemData = item_variant as ItemData
		totals["vitality"] += item.vitality_bonus
		totals["strength"] += item.strength_bonus
		totals["dexterity"] += item.dexterity_bonus
		totals["endurance"] += item.endurance_bonus
		totals["intelligence"] += item.intelligence_bonus
		totals["willpower"] += item.willpower_bonus


	return totals


func _apply_equipment_bonuses() -> void:

	var player: Node = get_parent()


	if player != null and player.has_method("apply_equipment_bonuses"):

		player.apply_equipment_bonuses(
			get_total_bonuses()
		)
