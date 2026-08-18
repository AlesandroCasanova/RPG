class_name PlayerInventory
extends Node


signal inventory_changed
signal equipment_changed
signal item_added(item: ItemData, quantity: int)
signal quick_slots_changed


@export_range(1, 100, 1)
var capacity: int = 32


var stacks: Array[Dictionary] = []
var quick_slots: Array[Variant] = [null, null, null, null, null, null]

var equipped: Dictionary = {
	ItemData.EquipmentSlot.WEAPON: null,
	ItemData.EquipmentSlot.HEAD: null,
	ItemData.EquipmentSlot.CHEST: null,
	ItemData.EquipmentSlot.LEGS: null,
	ItemData.EquipmentSlot.BOOTS: null,
	ItemData.EquipmentSlot.GLOVES: null,
	ItemData.EquipmentSlot.RING_LEFT: null,
	ItemData.EquipmentSlot.RING_RIGHT: null,
	ItemData.EquipmentSlot.AMULET: null
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


	var old_item := equipped.get(item.equipment_slot) as ItemData
	stacks.remove_at(index)
	if old_item != null:
		_add_stack_without_signals(old_item, 1)
	equipped[item.equipment_slot] = item
	_apply_equipment_bonuses()
	equipment_changed.emit()
	inventory_changed.emit()


	return true


func move_stack(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= stacks.size():
		return false
	if to_index < 0 or to_index >= capacity or from_index == to_index:
		return false
	var moving: Dictionary = stacks[from_index]
	stacks.remove_at(from_index)
	if to_index >= stacks.size():
		stacks.append(moving)
	else:
		stacks.insert(to_index, moving)
	inventory_changed.emit()
	return true


func remove_item(item: ItemData, quantity: int = 1) -> int:
	var remaining := maxi(quantity, 0)
	for index: int in range(stacks.size() - 1, -1, -1):
		if stacks[index].get("item") != item:
			continue
		var available := int(stacks[index].get("quantity", 0))
		var removed := mini(available, remaining)
		stacks[index]["quantity"] = available - removed
		remaining -= removed
		if int(stacks[index]["quantity"]) <= 0:
			stacks.remove_at(index)
		if remaining <= 0:
			break
	if remaining != quantity:
		inventory_changed.emit()
	return remaining


func assign_quick_slot(index: int, item: ItemData) -> bool:
	if item == null:
		return false
	for stack_index: int in stacks.size():
		if stacks[stack_index].get("item") == item:
			return move_stack_to_quick_slot(stack_index, index)
	return false


func move_stack_to_quick_slot(stack_index: int, quick_index: int) -> bool:
	if stack_index < 0 or stack_index >= stacks.size():
		return false
	if quick_index < 0 or quick_index >= quick_slots.size():
		return false
	var moving: Dictionary = stacks[stack_index]
	var item := moving.get("item") as ItemData
	if item == null or item.item_type != ItemData.ItemType.CONSUMABLE:
		return false
	stacks.remove_at(stack_index)
	var previous: Variant = quick_slots[quick_index]
	if previous is Dictionary and not (previous as Dictionary).is_empty():
		var old_stack := previous as Dictionary
		_add_stack_without_signals(
			old_stack.get("item") as ItemData,
			int(old_stack.get("quantity", 0))
		)
	quick_slots[quick_index] = moving.duplicate()
	inventory_changed.emit()
	quick_slots_changed.emit()
	return true


func get_quick_slot_stack(index: int) -> Dictionary:
	if index < 0 or index >= quick_slots.size():
		return {}
	var value: Variant = quick_slots[index]
	return value as Dictionary if value is Dictionary else {}


func consume_quick_slot(index: int) -> bool:
	var stack := get_quick_slot_stack(index)
	if stack.is_empty() or int(stack.get("quantity", 0)) <= 0:
		return false
	stack["quantity"] = int(stack.get("quantity", 0)) - 1
	if int(stack["quantity"]) <= 0:
		quick_slots[index] = null
	else:
		quick_slots[index] = stack
	quick_slots_changed.emit()
	return true


func unequip_slot(slot: ItemData.EquipmentSlot) -> bool:

	if not equipped.has(slot) or equipped[slot] == null:

		return false

	if stacks.size() >= capacity:
		return false

	var item := equipped[slot] as ItemData
	equipped[slot] = null
	_add_stack_without_signals(item, 1)
	_apply_equipment_bonuses()
	equipment_changed.emit()
	inventory_changed.emit()
	return true


func _add_stack_without_signals(item: ItemData, quantity: int) -> void:
	if item == null or quantity <= 0:
		return
	if item.stackable:
		for stack: Dictionary in stacks:
			if stack.get("item") == item and int(stack.get("quantity", 0)) < item.max_stack:
				var amount := mini(quantity, item.max_stack - int(stack.get("quantity", 0)))
				stack["quantity"] = int(stack.get("quantity", 0)) + amount
				quantity -= amount
				if quantity <= 0:
					return
	while quantity > 0 and stacks.size() < capacity:
		var amount := mini(quantity, item.max_stack) if item.stackable else 1
		stacks.append({"item": item, "quantity": amount})
		quantity -= amount


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


func get_save_data() -> Dictionary:
	var saved_stacks: Array[Dictionary] = []
	for stack: Dictionary in stacks:
		var item := stack.get("item") as ItemData
		if item != null:
			saved_stacks.append({"path": item.resource_path, "quantity": int(stack.get("quantity", 1))})
	var saved_quick_slots: Array[Variant] = []
	for value: Variant in quick_slots:
		if value is Dictionary:
			var stack := value as Dictionary
			var item := stack.get("item") as ItemData
			saved_quick_slots.append(
				{"path": item.resource_path, "quantity": int(stack.get("quantity", 1))}
				if item != null else null
			)
		else:
			saved_quick_slots.append(null)
	var saved_equipment: Dictionary = {}
	for slot_variant: Variant in equipped:
		var item := equipped[slot_variant] as ItemData
		if item != null:
			saved_equipment[str(int(slot_variant))] = item.resource_path
	return {
		"stacks": saved_stacks,
		"quick_slots": saved_quick_slots,
		"equipped": saved_equipment
	}


func load_save_data(data: Dictionary) -> void:
	stacks.clear()
	quick_slots = [null, null, null, null, null, null]
	for slot_variant: Variant in equipped:
		equipped[slot_variant] = null
	for saved_stack_variant: Variant in Array(data.get("stacks", [])):
		var saved_stack := Dictionary(saved_stack_variant)
		var item := _load_item(String(saved_stack.get("path", "")))
		if item != null:
			stacks.append({"item": item, "quantity": int(saved_stack.get("quantity", 1))})
	var saved_quick := Array(data.get("quick_slots", []))
	for index: int in mini(saved_quick.size(), quick_slots.size()):
		if saved_quick[index] == null:
			continue
		var saved_stack := Dictionary(saved_quick[index])
		var item := _load_item(String(saved_stack.get("path", "")))
		if item != null:
			quick_slots[index] = {"item": item, "quantity": int(saved_stack.get("quantity", 1))}
	var saved_equipment := Dictionary(data.get("equipped", {}))
	for slot_key: String in saved_equipment:
		var item := _load_item(String(saved_equipment[slot_key]))
		if item != null:
			equipped[int(slot_key)] = item
	_apply_equipment_bonuses()
	inventory_changed.emit()
	equipment_changed.emit()
	quick_slots_changed.emit()


func _load_item(path: String) -> ItemData:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as ItemData
