extends CharacterBody2D


# =========================================================
# MOVIMIENTO
# =========================================================

@export var speed: float = 300.0


# =========================================================
# ATAQUE
# =========================================================

@export var attack_damage: int = 25
@export var attack_distance: float = 55.0

# Temporalmente 1 segundo para probar.
@export var attack_duration: float = 1.0

@export var attack_cooldown: float = 0.35


# =========================================================
# NODOS
# =========================================================

@onready var player_animated: AnimatedSprite2D = $PlayerAnimated

@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D


# =========================================================
# ESTADO
# =========================================================

var last_facing: String = "s"

var attack_time_left: float = 0.0
var attack_cooldown_left: float = 0.0

var hit_targets: Array[Node] = []

var attack_debug: Polygon2D


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	# PLAYER = Layer 1
	collision_layer = 1

	# AttackArea no pertenece a ninguna capa.
	attack_area.collision_layer = 0

	# AttackArea busca únicamente Layer 2.
	attack_area.collision_mask = 2

	attack_area.monitoring = true
	attack_area.monitorable = true

	# Hitbox apagada al comenzar.
	attack_collision.disabled = true

	# Cuando un cuerpo entra en AttackArea.
	attack_area.body_entered.connect(_on_attack_area_body_entered)

	# Rectángulo rojo provisional.
	attack_debug = Polygon2D.new()
	attack_debug.name = "AttackDebug"

	attack_debug.polygon = PackedVector2Array([
		Vector2(-35.0, -22.5),
		Vector2(35.0, -22.5),
		Vector2(35.0, 22.5),
		Vector2(-35.0, 22.5)
	])

	attack_debug.color = Color(1.0, 0.0, 0.0, 0.45)
	attack_debug.visible = false

	attack_area.add_child(attack_debug)

	_play_idle()


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta: float) -> void:
	_update_attack_timers(delta)

	var input_x := Input.get_axis(
		"move_left",
		"move_right"
	)

	var input_y := Input.get_axis(
		"move_up",
		"move_down"
	)

	var direction := Vector2(
		input_x,
		input_y
	)

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

	if Input.is_action_just_pressed("attack"):
		_try_attack()

	move_and_slide()


# =========================================================
# DIRECCIÓN
# =========================================================

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


# =========================================================
# ANIMACIONES
# =========================================================

func _play_idle() -> void:
	var animation_name := "idle_" + last_facing

	if player_animated.sprite_frames.has_animation(animation_name):
		if player_animated.animation != animation_name:
			player_animated.play(animation_name)


func _play_walk() -> void:
	var animation_name := "walk_" + last_facing

	if player_animated.sprite_frames.has_animation(animation_name):
		if player_animated.animation != animation_name:
			player_animated.play(animation_name)

	else:
		var idle_name := "idle_" + last_facing

		if player_animated.sprite_frames.has_animation(idle_name):
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

	hit_targets.clear()

	_update_attack_area()

	attack_collision.set_deferred(
		"disabled",
		false
	)

	attack_debug.visible = true


func _update_attack_timers(delta: float) -> void:
	if attack_cooldown_left > 0.0:
		attack_cooldown_left -= delta

		if attack_cooldown_left < 0.0:
			attack_cooldown_left = 0.0

	if attack_time_left > 0.0:
		attack_time_left -= delta

		if attack_time_left <= 0.0:
			attack_time_left = 0.0

			attack_collision.set_deferred(
				"disabled",
				true
			)

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

	attack_area.position = (
		attack_direction * attack_distance
	)

	attack_area.rotation = attack_direction.angle()


# =========================================================
# DETECCIÓN DE GOLPE
# =========================================================

func _on_attack_area_body_entered(body: Node2D) -> void:
	print("AttackArea detectó: ", body.name)

	# Si no estamos atacando, ignoramos.
	if attack_time_left <= 0.0:
		return

	# Un enemigo solo puede recibir un golpe por ataque.
	if body in hit_targets:
		return

	# Comprobamos que sea un objeto dañable.
	if body.has_method("take_damage"):
		hit_targets.append(body)

		body.take_damage(attack_damage)

		print(
			"GOLPE CONFIRMADO | ",
			body.name,
			" | Daño: ",
			attack_damage
		)
	else:
		print(
			body.name,
			" fue detectado pero NO tiene take_damage()"
		)
