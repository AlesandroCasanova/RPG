class_name LootEntry
extends Resource


@export var item: ItemData

@export_range(0.0, 1.0, 0.01)
var drop_chance: float = 1.0

@export_range(1, 999, 1)
var min_quantity: int = 1

@export_range(1, 999, 1)
var max_quantity: int = 1


func roll_quantity(random: RandomNumberGenerator) -> int:

	if item == null or random.randf() > drop_chance:

		return 0


	return random.randi_range(
		mini(min_quantity, max_quantity),
		maxi(min_quantity, max_quantity)
	)
