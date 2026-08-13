extends CharacterBody2D

@export var speed: float = 300.0

# Configuración del ataque
@export var attack_distance: float = 55.0
@export var attack_duration: float = 0.12
@export var attack_cooldown: float = 0.35

@onready var player_animated: AnimatedSprite2D = $PlayerAnimated

@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

var attack_debug: Polygon2D

var last_facing: String = "s"

var attack_time_left: float = 0.0
var attack_cooldown_left: float = 0.0


func _ready() -> void:
	attack_collision.disabled = true

	# Rectángulo rojo provisional para ver el ataque.
	attack_debug = Polygon2D.new()
	attack_debug.name = "AttackDebug"

	attack_debug.polygon = PackedVector2Array([
		Vector2(-35, -22.5),
		Vector2(35, -22.5),
		Vector2(35, 22.5),
		Vector2(-35, 22.5)
	])

	attack_debug.color = Color(1.0, 0.0, 0.0, 0.45)
	attack_debug.visible = false

	attack_area.add_child(attack_debug)

	_play_idle()


func _physics_process(delta: float) -> void:
	_update_attack_timers(delta)

	var input_x := Input.get_axis("move_left", "move_right")
	var input_y := Input.get_axis("move_up", "move_down")

	var direction := Vector2(input_x, input_y)

	var iso_direction := Vector2(
		direction.x - direction.y,
		(direction.x + direction.y) * 0.5
	)

	if iso_direction != Vector2.ZERO:
		iso_direction = iso_direction.normalized()

	velocity = iso_direction * speed

	if direction != Vector2.ZERO:
		_update_facing(direction)
		_play_walk()
	else:
		_play_idle()

	# Ataque
	if Input.is_action_just_pressed("attack"):
		_try_attack()

	move_and_slide()


func _update_facing(direction: Vector2) -> void:
	var x := direction.x
	var y := direction.y

	if x > 0.0 and y < 0.0:
		last_facing = "e"

	elif x < 0.0 and y < 0.0:
		last_facing = "n"

	elif x > 0.0 and y > 0.0:
		last_facing = "s"

	elif x < 0.0 and y > 0.0:
		last_facing = "w"

	elif y < 0.0:
		last_facing = "ne"

	elif y > 0.0:
		last_facing = "sw"

	elif x < 0.0:
		last_facing = "nw"

	elif x > 0.0:
		last_facing = "se"


func _play_idle() -> void:
	var animation_name := "idle_" + last_facing

	if player_animated.animation != animation_name:
		player_animated.play(animation_name)


func _play_walk() -> void:
	var animation_name := "walk_" + last_facing

	if player_animated.sprite_frames.has_animation(animation_name):
		if player_animated.animation != animation_name:
			player_animated.play(animation_name)
	else:
		# Todavía no tenemos walk para esa dirección.
		var idle_name := "idle_" + last_facing

		if player_animated.animation != idle_name:
			player_animated.play(idle_name)


# =========================================================
# ATAQUE
# =========================================================

func _try_attack() -> void:
	if attack_cooldown_left > 0.0:
		return

	print("ATAQUE: ", last_facing)

	attack_cooldown_left = attack_cooldown
	attack_time_left = attack_duration

	_update_attack_area()

	attack_collision.set_deferred("disabled", false)
	attack_debug.visible = true


func _update_attack_timers(delta: float) -> void:
	if attack_cooldown_left > 0.0:
		attack_cooldown_left -= delta

	if attack_time_left > 0.0:
		attack_time_left -= delta

		if attack_time_left <= 0.0:
			attack_collision.set_deferred("disabled", true)
			attack_debug.visible = false


func _update_attack_area() -> void:
	var attack_direction := Vector2.ZERO

	match last_facing:
		"n":
			attack_direction = Vector2(0.0, -1.0)

		"ne":
			attack_direction = Vector2(1.0, -1.0).normalized()

		"e":
			attack_direction = Vector2(1.0, 0.0)

		"se":
			attack_direction = Vector2(1.0, 1.0).normalized()

		"s":
			attack_direction = Vector2(0.0, 1.0)

		"sw":
			attack_direction = Vector2(-1.0, 1.0).normalized()

		"w":
			attack_direction = Vector2(-1.0, 0.0)

		"nw":
			attack_direction = Vector2(-1.0, -1.0).normalized()

	# Coloca la hitbox delante del personaje.
	attack_area.position = attack_direction * attack_distance

	# Rota el rectángulo para acompañar la dirección del golpe.
	attack_area.rotation = attack_direction.angle()
