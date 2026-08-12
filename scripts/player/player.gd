extends CharacterBody2D

@export var speed: float = 300.0

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	var iso_direction := Vector2(
		direction.x - direction.y,
		(direction.x + direction.y) * 0.5
	).normalized()

	velocity = iso_direction * speed
	move_and_slide()
