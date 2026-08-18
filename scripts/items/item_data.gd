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
	ARMOR,
	ACCESSORY
}


enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC
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
