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
@export var attack_duration: float = 0.12
@export var attack_cooldown: float = 0.35

# Dejamos visible la hitbox roja mientras desarrollamos.
@export var show_attack_debug: bool = true


# =========================================================
# NODOS
# =========================================================

@onready var player_animated: AnimatedSprite2D = $PlayerAnimated

@onready var attack_area: Area2D = $AttackArea

@onready var attack_collision: CollisionShape2D = \
	$AttackArea/CollisionShape2D


# =========================================================
# ESTADO
# =========================================================

var last_facing: String = "s"

var attack_time_left: float = 0.0
var attack_cooldown_left: float = 0.0

# Impide dañar varias veces al mismo enemigo
# durante un único ataque.
var hit_targets: Array[Node] = []

var attack_debug: Polygon2D


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	# Player pertenece a Layer 1.
	collision_layer = 1

	# AttackArea no necesita pertenecer a ninguna Layer.
	attack_area.collision_layer = 0

	# AttackArea solamente detecta enemigos de Layer 2.
	attack_area.collision_mask = 2

	attack_area.monitoring = true
	attack_area.monitorable = true

	# La hitbox comienza apagada.
	attack_collision.disabled = true

	# Detectar enemigos que entren en la hitbox.
	attack_area.body_entered.connect(
		_on_attack_area_body_entered
	)

	_create_attack_debug()

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

	# Conversión a movimiento isométrico.
	var iso_direction := Vector2(
		direction.x - direction.y,
		(direction.x + direction.y) * 0.5
	)

	if iso_direction != Vector2.ZERO:
		iso_direction = iso_direction.normalized()

	velocity = iso_direction * speed

	# Dirección y animaciones.
	if direction != Vector2.ZERO:
		_update_facing(direction)
		_play_walk()
	else:
		_play_idle()

	# Ataque.
	if Input.is_action_just_pressed("attack"):
		_try_attack()

	move_and_slide()


# =========================================================
# DIRECCIONES
# =========================================================

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


# =========================================================
# ANIMACIONES
# =========================================================

func _play_idle() -> void:
	var animation_name := "idle_" + last_facing

	if player_animated.sprite_frames.has_animation(
		animation_name
	):
		if player_animated.animation != animation_name:
			player_animated.play(animation_name)


func _play_walk() -> void:
	var animation_name := "walk_" + last_facing

	if player_animated.sprite_frames.has_animation(
		animation_name
	):
		if player_animated.animation != animation_name:
			player_animated.play(animation_name)

	else:
		# Placeholder hasta tener walk definitivo.
		var idle_name := "idle_" + last_facing

		if player_animated.sprite_frames.has_animation(
			idle_name
		):
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

	# Cada nuevo ataque puede volver a dañar.
	hit_targets.clear()

	_update_attack_area()

	# Activar hitbox.
	attack_collision.set_deferred(
		"disabled",
		false
	)

	if show_attack_debug:
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


# =========================================================
# POSICIÓN DEL ATAQUE
# =========================================================

func _update_attack_area() -> void:
	var attack_direction := Vector2.ZERO

	match last_facing:

		"n":
			attack_direction = Vector2(
				0.0,
				-1.0
			)

		"ne":
			attack_direction = Vector2(
				1.0,
				-1.0
			).normalized()

		"e":
			attack_direction = Vector2(
				1.0,
				0.0
			)

		"se":
			attack_direction = Vector2(
				1.0,
				1.0
			).normalized()

		"s":
			attack_direction = Vector2(
				0.0,
				1.0
			)

		"sw":
			attack_direction = Vector2(
				-1.0,
				1.0
			).normalized()

		"w":
			attack_direction = Vector2(
				-1.0,
				0.0
			)

		"nw":
			attack_direction = Vector2(
				-1.0,
				-1.0
			).normalized()

	attack_area.position = (
		attack_direction * attack_distance
	)

	attack_area.rotation = attack_direction.angle()


# =========================================================
# DETECTAR IMPACTO
# =========================================================

func _on_attack_area_body_entered(
	body: Node2D
) -> void:
	print(
		"AttackArea detectó: ",
		body.name
	)

	# Si la hitbox no está activa, no hacemos daño.
	if attack_time_left <= 0.0:
		return

	# Evita múltiples impactos durante el mismo golpe.
	if body in hit_targets:
		return

	if body.has_method("take_damage"):
		hit_targets.append(body)

		body.take_damage(
			attack_damage,
			global_position
		)

		print(
			"GOLPE CONFIRMADO | ",
			body.name,
			" | Daño: ",
			attack_damage
		)


# =========================================================
# HITBOX ROJA PROVISIONAL
# =========================================================

func _create_attack_debug() -> void:
	attack_debug = Polygon2D.new()

	attack_debug.name = "AttackDebug"

	attack_debug.polygon = PackedVector2Array([
		Vector2(-35.0, -22.5),
		Vector2(35.0, -22.5),
		Vector2(35.0, 22.5),
		Vector2(-35.0, 22.5)
	])

	attack_debug.color = Color(
		1.0,
		0.0,
		0.0,
		0.45
	)

	attack_debug.visible = false

	attack_area.add_child(
		attack_debug
	)
