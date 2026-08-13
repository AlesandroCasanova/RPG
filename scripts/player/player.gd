extends CharacterBody2D

@export var speed: float = 300.0

@onready var player_animated: AnimatedSprite2D = $PlayerAnimated

var last_facing: String = "s"


func _ready() -> void:
	player_animated.play("idle_s")


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

	if direction != Vector2.ZERO:
		_update_facing(direction)

	move_and_slide()


func _update_facing(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			last_facing = "e"
		else:
			last_facing = "w"
	else:
		if direction.y > 0:
			last_facing = "s"
		else:
			last_facing = "n"

	player_animated.play("idle_" + last_facing)
