extends CharacterBody2D


# =========================================================
# MOVIMIENTO
# =========================================================

@export var speed: float = 300.0


# =========================================================
# DASH
# =========================================================

@export var dash_speed: float = 850.0
@export var dash_duration: float = 0.14
@export var dash_cooldown: float = 0.40

# Tiempo máximo entre el primer y segundo toque.
@export var dash_double_tap_window: float = 0.25


# =========================================================
# VIDA
# =========================================================

@export var max_health: int = 100

var health: int = 100
var is_dead: bool = false


# =========================================================
# ATAQUE
# =========================================================

@export var attack_damage: int = 25
@export var attack_distance: float = 55.0
@export var attack_duration: float = 0.12
@export var attack_cooldown: float = 0.35

@export var show_attack_debug: bool = true


# =========================================================
# NODOS
# =========================================================

@onready var player_animated: AnimatedSprite2D = $PlayerAnimated

@onready var attack_area: Area2D = $AttackArea

@onready var attack_collision: CollisionShape2D = (
	$AttackArea/CollisionShape2D
)


# =========================================================
# ESTADO DE DIRECCIÓN
# =========================================================

var last_facing: String = "s"


# =========================================================
# ESTADO DE ATAQUE
# =========================================================

var attack_time_left: float = 0.0
var attack_cooldown_left: float = 0.0

var hit_targets: Array[Node] = []

var attack_debug: Polygon2D


# =========================================================
# ESTADO DE DASH
# =========================================================

var is_dashing: bool = false

var dash_direction: Vector2 = Vector2.ZERO

var dash_time_left: float = 0.0

var dash_cooldown_left: float = 0.0


# =========================================================
# DOBLE TOQUE
# =========================================================

var last_tap_action: String = ""

var double_tap_time_left: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready() -> void:

	# -----------------------------------------------------
	# VIDA
	# -----------------------------------------------------

	health = max_health

	add_to_group("player")

	print(
		"PLAYER CREADO | HP: ",
		health,
		" / ",
		max_health
	)


	# -----------------------------------------------------
	# COLISIONES
	# -----------------------------------------------------

	collision_layer = 1


	# -----------------------------------------------------
	# ATTACK AREA
	# -----------------------------------------------------

	attack_area.collision_layer = 0
	attack_area.collision_mask = 2

	attack_area.monitoring = true
	attack_area.monitorable = true

	attack_collision.disabled = true


	# -----------------------------------------------------
	# SIGNAL
	# -----------------------------------------------------

	if not attack_area.body_entered.is_connected(
		_on_attack_area_body_entered
	):
		attack_area.body_entered.connect(
			_on_attack_area_body_entered
		)


	# -----------------------------------------------------
	# DEBUG
	# -----------------------------------------------------

	_create_attack_debug()

	_play_idle()


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta: float) -> void:

	# -----------------------------------------------------
	# MUERTO
	# -----------------------------------------------------

	if is_dead:
		velocity = Vector2.ZERO
		return


	# -----------------------------------------------------
	# TIMERS
	# -----------------------------------------------------

	_update_attack_timers(delta)

	_update_dash_timers(delta)


	# -----------------------------------------------------
	# DETECTAR DOBLE TOQUE
	# -----------------------------------------------------

	_handle_dash_input()


	# -----------------------------------------------------
	# DASH ACTIVO
	# -----------------------------------------------------

	if is_dashing:

		velocity = (
			dash_direction
			* dash_speed
		)

		move_and_slide()

		return


	# -----------------------------------------------------
	# INPUT NORMAL
	# -----------------------------------------------------

	var input_x: float = Input.get_axis(
		"move_left",
		"move_right"
	)

	var input_y: float = Input.get_axis(
		"move_up",
		"move_down"
	)


	var direction := Vector2(
		input_x,
		input_y
	)


	# -----------------------------------------------------
	# MOVIMIENTO ISOMÉTRICO
	# -----------------------------------------------------

	var iso_direction := Vector2(
		direction.x - direction.y,
		(direction.x + direction.y) * 0.5
	)


	if iso_direction != Vector2.ZERO:

		iso_direction = (
			iso_direction.normalized()
		)


	velocity = (
		iso_direction
		* speed
	)


	# -----------------------------------------------------
	# DIRECCIÓN Y ANIMACIÓN
	# -----------------------------------------------------

	if direction != Vector2.ZERO:

		_update_facing(
			direction
		)

		_play_walk()

	else:

		_play_idle()


	# -----------------------------------------------------
	# ATAQUE
	# -----------------------------------------------------

	if Input.is_action_just_pressed(
		"attack"
	):

		_try_attack()


	# -----------------------------------------------------
	# MOVIMIENTO
	# -----------------------------------------------------

	move_and_slide()


# =========================================================
# DASH - INPUT
# =========================================================

func _handle_dash_input() -> void:

	# Solo procesamos una dirección por frame.

	if Input.is_action_just_pressed(
		"move_left"
	):

		_register_direction_tap(
			"move_left",
			Vector2(-1.0, 0.0)
		)


	elif Input.is_action_just_pressed(
		"move_right"
	):

		_register_direction_tap(
			"move_right",
			Vector2(1.0, 0.0)
		)


	elif Input.is_action_just_pressed(
		"move_up"
	):

		_register_direction_tap(
			"move_up",
			Vector2(0.0, -1.0)
		)


	elif Input.is_action_just_pressed(
		"move_down"
	):

		_register_direction_tap(
			"move_down",
			Vector2(0.0, 1.0)
		)


# =========================================================
# DASH - REGISTRAR TOQUE
# =========================================================

func _register_direction_tap(
	action_name: String,
	input_direction: Vector2
) -> void:

	# -----------------------------------------------------
	# SEGUNDO TOQUE
	# -----------------------------------------------------

	if (
		last_tap_action == action_name
		and
		double_tap_time_left > 0.0
	):

		last_tap_action = ""

		double_tap_time_left = 0.0


		# Si está disponible, ejecutamos dash.
		if (
			dash_cooldown_left <= 0.0
			and
			not is_dashing
		):

			_start_dash(
				input_direction,
				action_name
			)


		return


	# -----------------------------------------------------
	# PRIMER TOQUE
	# -----------------------------------------------------

	last_tap_action = action_name

	double_tap_time_left = (
		dash_double_tap_window
	)


# =========================================================
# DASH - COMENZAR
# =========================================================

func _start_dash(
	input_direction: Vector2,
	action_name: String
) -> void:

	# Convertimos también el dash
	# a la misma perspectiva isométrica.
	var iso_dash_direction := Vector2(
		input_direction.x
		- input_direction.y,

		(
			input_direction.x
			+ input_direction.y
		) * 0.5
	)


	if iso_dash_direction == Vector2.ZERO:
		return


	iso_dash_direction = (
		iso_dash_direction.normalized()
	)


	# -----------------------------------------------------
	# ESTADO
	# -----------------------------------------------------

	is_dashing = true

	dash_direction = (
		iso_dash_direction
	)

	dash_time_left = (
		dash_duration
	)

	dash_cooldown_left = (
		dash_cooldown
	)


	# -----------------------------------------------------
	# DIRECCIÓN VISUAL
	# -----------------------------------------------------

	_update_facing(
		input_direction
	)

	_play_walk()


	print(
		"DASH: ",
		action_name,
		" | Dirección: ",
		last_facing
	)


# =========================================================
# DASH - TIMERS
# =========================================================

func _update_dash_timers(
	delta: float
) -> void:

	# -----------------------------------------------------
	# COOLDOWN
	# -----------------------------------------------------

	if dash_cooldown_left > 0.0:

		dash_cooldown_left -= delta


		if dash_cooldown_left < 0.0:

			dash_cooldown_left = 0.0


	# -----------------------------------------------------
	# VENTANA DEL DOBLE TOQUE
	# -----------------------------------------------------

	if double_tap_time_left > 0.0:

		double_tap_time_left -= delta


		if double_tap_time_left <= 0.0:

			double_tap_time_left = 0.0

			last_tap_action = ""


	# -----------------------------------------------------
	# DURACIÓN DEL DASH
	# -----------------------------------------------------

	if is_dashing:

		dash_time_left -= delta


		if dash_time_left <= 0.0:

			_finish_dash()


# =========================================================
# DASH - TERMINAR
# =========================================================

func _finish_dash() -> void:

	is_dashing = false

	dash_time_left = 0.0

	dash_direction = Vector2.ZERO

	velocity = Vector2.ZERO

	_play_idle()


# =========================================================
# DIRECCIONES
# =========================================================

func _update_facing(
	direction: Vector2
) -> void:

	var x: float = direction.x
	var y: float = direction.y


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
# IDLE
# =========================================================

func _play_idle() -> void:

	var animation_name: String = (
		"idle_" + last_facing
	)


	if player_animated.sprite_frames.has_animation(
		animation_name
	):

		if player_animated.animation != animation_name:

			player_animated.play(
				animation_name
			)


# =========================================================
# WALK
# =========================================================

func _play_walk() -> void:

	var animation_name: String = (
		"walk_" + last_facing
	)


	if player_animated.sprite_frames.has_animation(
		animation_name
	):

		if player_animated.animation != animation_name:

			player_animated.play(
				animation_name
			)

	else:

		# Placeholder mientras no tengamos
		# las animaciones walk definitivas.

		var idle_name: String = (
			"idle_" + last_facing
		)


		if player_animated.sprite_frames.has_animation(
			idle_name
		):

			if player_animated.animation != idle_name:

				player_animated.play(
					idle_name
				)


# =========================================================
# ATAQUE
# =========================================================

func _try_attack() -> void:

	if is_dead:
		return


	if is_dashing:
		return


	if attack_cooldown_left > 0.0:
		return


	print(
		"ATAQUE: ",
		last_facing
	)


	attack_cooldown_left = (
		attack_cooldown
	)

	attack_time_left = (
		attack_duration
	)


	hit_targets.clear()


	_update_attack_area()


	attack_collision.set_deferred(
		"disabled",
		false
	)


	if show_attack_debug:

		attack_debug.visible = true


# =========================================================
# TIMERS DEL ATAQUE
# =========================================================

func _update_attack_timers(
	delta: float
) -> void:

	# -----------------------------------------------------
	# COOLDOWN
	# -----------------------------------------------------

	if attack_cooldown_left > 0.0:

		attack_cooldown_left -= delta


		if attack_cooldown_left < 0.0:

			attack_cooldown_left = 0.0


	# -----------------------------------------------------
	# DURACIÓN HITBOX
	# -----------------------------------------------------

	if attack_time_left > 0.0:

		attack_time_left -= delta


		if attack_time_left <= 0.0:

			attack_time_left = 0.0


			attack_collision.set_deferred(
				"disabled",
				true
			)


			if attack_debug != null:

				attack_debug.visible = false


# =========================================================
# POSICIÓN DEL ATAQUE
# =========================================================

func _update_attack_area() -> void:

	var attack_direction := (
		Vector2.ZERO
	)


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
		attack_direction
		* attack_distance
	)


	attack_area.rotation = (
		attack_direction.angle()
	)


# =========================================================
# IMPACTO
# =========================================================

func _on_attack_area_body_entered(
	body: Node2D
) -> void:

	print(
		"AttackArea detectó: ",
		body.name
	)


	if attack_time_left <= 0.0:
		return


	if body in hit_targets:
		return


	if body.has_method(
		"take_damage"
	):

		hit_targets.append(
			body
		)


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

	else:

		print(
			body.name,
			" fue detectado pero NO tiene take_damage()"
		)


# =========================================================
# RECIBIR DAÑO
# =========================================================

func take_damage(
	amount: int
) -> void:

	if is_dead:
		return


	health -= amount


	health = max(
		health,
		0
	)


	print(
		"=============================="
	)

	print(
		"PLAYER RECIBE ",
		amount,
		" DE DAÑO"
	)

	print(
		"HP PLAYER: ",
		health,
		" / ",
		max_health
	)

	print(
		"=============================="
	)


	if health <= 0:

		_die()

		return


	_flash_player_damage()


# =========================================================
# ¿SIGUE VIVO?
# =========================================================

func is_alive() -> bool:

	return not is_dead


# =========================================================
# FLASH DE DAÑO
# =========================================================

func _flash_player_damage() -> void:

	player_animated.modulate = Color(
		1.0,
		0.20,
		0.20,
		1.0
	)


	var tween := create_tween()


	tween.tween_property(
		player_animated,
		"modulate",
		Color.WHITE,
		0.15
	)


# =========================================================
# MUERTE
# =========================================================

func _die() -> void:

	if is_dead:
		return


	is_dead = true

	is_dashing = false


	print(
		"=============================="
	)

	print(
		"PLAYER DERROTADO"
	)

	print(
		"=============================="
	)


	# -----------------------------------------------------
	# DETENER MOVIMIENTO
	# -----------------------------------------------------

	velocity = Vector2.ZERO

	dash_direction = Vector2.ZERO


	# -----------------------------------------------------
	# APAGAR ATAQUE
	# -----------------------------------------------------

	attack_time_left = 0.0


	attack_collision.set_deferred(
		"disabled",
		true
	)


	if attack_debug != null:

		attack_debug.visible = false


	# -----------------------------------------------------
	# VISUAL PROVISIONAL
	# -----------------------------------------------------

	player_animated.modulate = Color(
		0.35,
		0.35,
		0.35,
		1.0
	)


# =========================================================
# HITBOX ROJA DE DEBUG
# =========================================================

func _create_attack_debug() -> void:

	attack_debug = Polygon2D.new()


	attack_debug.name = (
		"AttackDebug"
	)


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
