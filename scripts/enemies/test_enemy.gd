extends CharacterBody2D

@export var max_health: int = 100

var health: int


func _ready() -> void:
	health = max_health

	# El enemigo pertenece a Layer 2.
	collision_layer = 2

	# Puede colisionar con Player (Layer 1).
	collision_mask = 1

	print("ENEMIGO CREADO | HP: ", health)


func take_damage(amount: int) -> void:
	health -= amount
	health = max(health, 0)

	print("================================")
	print("ENEMIGO RECIBE ", amount, " DE DAÑO")
	print("HP: ", health, " / ", max_health)
	print("================================")

	if health <= 0:
		die()


func die() -> void:
	print("ENEMIGO DERROTADO")
	queue_free()
