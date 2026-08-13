extends CharacterBody2D

@export var speed: float = 300.0

@onready var player_animated: AnimatedSprite2D = $PlayerAnimated

var last_facing: String = "s"


func _ready() -> void:
	player_animated.play("idle_s")


func _physics_process(_delta: float) -> void:
	# Leemos WASD por separado.
	var input_x := Input.get_axis("move_left", "move_right")
	var input_y := Input.get_axis("move_up", "move_down")

	var direction := Vector2(input_x, input_y)

	# Movimiento isométrico.
	var iso_direction := Vector2(
		direction.x - direction.y,
		(direction.x + direction.y) * 0.5
	)

	if iso_direction != Vector2.ZERO:
		iso_direction = iso_direction.normalized()

	velocity = iso_direction * speed

	# Actualizar hacia dónde mira el personaje.
	if direction != Vector2.ZERO:
		_update_facing(direction)

	move_and_slide()


func _update_facing(direction: Vector2) -> void:
	var x := direction.x
	var y := direction.y

	# W + D
	if x > 0.0 and y < 0.0:
		last_facing = "e"

	# W + A
	elif x < 0.0 and y < 0.0:
		last_facing = "n"

	# S + D
	elif x > 0.0 and y > 0.0:
		last_facing = "s"

	# S + A
	elif x < 0.0 and y > 0.0:
		last_facing = "w"

	# W
	elif y < 0.0:
		last_facing = "ne"

	# S
	elif y > 0.0:
		last_facing = "sw"

	# A
	elif x < 0.0:
		last_facing = "nw"

	# D
	elif x > 0.0:
		last_facing = "se"

	player_animated.play("idle_" + last_facing)