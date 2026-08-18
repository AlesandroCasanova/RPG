class_name ItemData
extends Resource


enum ItemType {
	CONSUMABLE,
	EQUIPMENT,
	MATERIAL,
	QUEST
}


enum EquipmentSlot {
	NONE,
	WEAPON,
	HEAD,
	CHEST,
	LEGS,
	BOOTS,
	GLOVES,
	RING_LEFT,
	RING_RIGHT,
	AMULET
}


enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC
}


enum ConsumableEffect {
	NONE,
	HEALTH,
	STAMINA,
	MANA
}


@export_category("Identidad")

@export var item_id: StringName = &"item"

@export var display_name: String = "Objeto"

@export_multiline var description: String = ""

@export var item_type: ItemType = ItemType.MATERIAL

@export var rarity: Rarity = Rarity.COMMON

@export var icon: Texture2D


@export_category("Inventario")

@export var stackable: bool = false

@export_range(1, 999, 1)
var max_stack: int = 1


@export_category("Equipamiento")

@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE


@export_category("Consumible")

@export var consumable_effect: ConsumableEffect = ConsumableEffect.NONE

@export_range(0.0, 9999.0, 1.0)
var effect_amount: float = 0.0


@export_category("Atributos")

@export var vitality_bonus: int = 0

@export var strength_bonus: int = 0

@export var dexterity_bonus: int = 0

@export var endurance_bonus: int = 0

@export var intelligence_bonus: int = 0

@export var willpower_bonus: int = 0


func is_equipment() -> bool:

	return (
		item_type == ItemType.EQUIPMENT
		and
		equipment_slot != EquipmentSlot.NONE
	)


func get_rarity_color() -> Color:

	match rarity:

		Rarity.UNCOMMON:
			return Color(0.3, 0.95, 0.4, 1.0)

		Rarity.RARE:
			return Color(0.25, 0.65, 1.0, 1.0)

		Rarity.EPIC:
			return Color(0.75, 0.35, 1.0, 1.0)


	return Color(0.9, 0.9, 0.9, 1.0)


func get_rarity_name() -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "Poco común"
		Rarity.RARE:
			return "Raro"
		Rarity.EPIC:
			return "Épico"
	return "Común"


func get_type_name() -> String:
	match item_type:
		ItemType.CONSUMABLE:
			return "Consumible"
		ItemType.EQUIPMENT:
			return "Equipamiento"
		ItemType.QUEST:
			return "Objeto de misión"
	return "Material"


func get_slot_name() -> String:
	match equipment_slot:
		EquipmentSlot.WEAPON: return "Arma"
		EquipmentSlot.HEAD: return "Cabeza"
		EquipmentSlot.CHEST: return "Pecho"
		EquipmentSlot.LEGS: return "Piernas"
		EquipmentSlot.BOOTS: return "Botas"
		EquipmentSlot.GLOVES: return "Guantes"
		EquipmentSlot.RING_LEFT: return "Anillo izquierdo"
		EquipmentSlot.RING_RIGHT: return "Anillo derecho"
		EquipmentSlot.AMULET: return "Amuleto"
	return ""


func get_detail_text() -> String:
	var lines: PackedStringArray = [display_name]
	lines.append(get_rarity_name() + " · " + get_type_name())
	if is_equipment():
		lines.append("Ranura: " + get_slot_name())
	if not description.is_empty():
		lines.append(description)
	if item_type == ItemType.CONSUMABLE and effect_amount > 0.0:
		var effect_name := "Vida"
		if consumable_effect == ConsumableEffect.STAMINA:
			effect_name = "Stamina"
		elif consumable_effect == ConsumableEffect.MANA:
			effect_name = "Maná"
		lines.append(effect_name + " +" + str(roundi(effect_amount)))
	if is_equipment():
		lines.append(get_bonus_text())
	return "\n".join(lines)


func get_bonus_text() -> String:

	var bonuses: PackedStringArray = []


	_append_bonus(bonuses, "Vitalidad", vitality_bonus)
	_append_bonus(bonuses, "Fuerza", strength_bonus)
	_append_bonus(bonuses, "Destreza", dexterity_bonus)
	_append_bonus(bonuses, "Aguante", endurance_bonus)
	_append_bonus(bonuses, "Inteligencia", intelligence_bonus)
	_append_bonus(bonuses, "Voluntad", willpower_bonus)


	if bonuses.is_empty():

		return "Sin bonificaciones"


	return "\n".join(bonuses)


func _append_bonus(
	bonuses: PackedStringArray,
	label: String,
	value: float
) -> void:

	if is_zero_approx(value):

		return


	bonuses.append(
		label
		+ " +"
		+ str(snappedf(value, 0.01))
	)
