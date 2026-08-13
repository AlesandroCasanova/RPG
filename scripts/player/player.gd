extends CharacterBody2D


# =========================================================
# MOVIMIENTO
# =========================================================

@export var speed: float = 300.0


# =========================================================
# VIDA DEL JUGADOR
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

# Mientras desarrollamos dejamos visible la hitbox.
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

# Evita dañar múltiples veces al mismo enemigo
# durante un único ataque.
var hit_targets: Array[Node] = []

# Rectángulo rojo provisional.
var attack_debug: Polygon2D


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	# -------------------------
	# VIDA
	# -------------------------

	health = max_health

	# El enemigo buscará al jugador mediante este grupo.
	add_to_group("player")

	print(
		"PLAYER CREADO | HP: ",
		health,
		" / ",
		max_health
	)


	# -------------------------
	# COLISIONES
	# -------------------------

	# Player pertenece a Layer 1.
	collision_layer = 1

	# AttackArea no pertenece a ninguna Layer.
	attack_area.collision_layer = 0

	# AttackArea detecta enemigos de Layer 2.
	attack_area.collision_mask = 2

	attack_area.monitoring = true
	attack_area.monitorable = true

	# Hitbox apagada inicialmente.
	attack_collision.disabled = true


	# -------------------------
	# SEÑALES
	# -------------------------

	if not attack_area.body_entered.is_connected(
		_on_attack_area_body_entered
	):
		attack_area.body_entered.connect(
			_on_attack_area_body_entered
		)


	# -------------------------
	# DEBUG
	# -------------------------

	_create_attack_debug()

	_play_idle()


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta: float) -> void:
	# Si estamos muertos, no hacemos nada.
	if is_dead:
		velocity = Vector2.ZERO
		return


	# -------------------------
	# TIMERS DEL ATAQUE
	# -------------------------

	_update_attack_timers(delta)


	# -------------------------
	# INPUT
	# -------------------------

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


	# -------------------------
	# MOVIMIENTO ISOMÉTRICO
	# -------------------------

	var iso_direction := Vector2(
		direction.x - direction.y,
		(direction.x + direction.y) * 0.5
	)

	if iso_direction != Vector2.ZERO:
		iso_direction = iso_direction.normalized()

	velocity = iso_direction * speed


	# -------------------------
	# DIRECCIÓN / ANIMACIONES
	# -------------------------

	if direction != Vector2.ZERO:
		_update_facing(direction)
		_play_walk()
	else:
		_play_idle()


	# -------------------------
	# ATAQUE
	# -------------------------

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

	# Si tenemos animación walk real:
	if player_animated.sprite_frames.has_animation(
		animation_name
	):
		if player_animated.animation != animation_name:
			player_animated.play(animation_name)

	else:
		# Mientras no tengamos walk definitivo,
		# usamos el idle correspondiente.
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
	if is_dead:
		return

	# Todavía está en cooldown.
	if attack_cooldown_left > 0.0:
		return

	print(
		"ATAQUE: ",
		last_facing
	)

	attack_cooldown_left = attack_cooldown
	attack_time_left = attack_duration

	# Con cada nuevo ataque permitimos
	# volver a golpear a los enemigos.
	hit_targets.clear()

	_update_attack_area()


	# -------------------------
	# ACTIVAR HITBOX
	# -------------------------

	attack_collision.set_deferred(
		"disabled",
		false
	)


	# -------------------------
	# DEBUG
	# -------------------------

	if show_attack_debug:
		attack_debug.visible = true


# =========================================================
# TIMERS DEL ATAQUE
# =========================================================

func _update_attack_timers(delta: float) -> void:
	# -------------------------
	# COOLDOWN
	# -------------------------

	if attack_cooldown_left > 0.0:
		attack_cooldown_left -= delta

		if attack_cooldown_left < 0.0:
			attack_cooldown_left = 0.0


	# -------------------------
	# DURACIÓN DE HITBOX
	# -------------------------

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

	attack_area.rotation = (
		attack_direction.angle()
	)


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


	# -------------------------
	# ¿HITBOX ACTIVA?
	# -------------------------

	if attack_time_left <= 0.0:
		return


	# -------------------------
	# YA FUE GOLPEADO
	# -------------------------

	if body in hit_targets:
		return


	# -------------------------
	# HACER DAÑO
	# -------------------------

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

	else:
		print(
			body.name,
			" fue detectado pero NO tiene take_damage()"
		)


# =========================================================
# RECIBIR DAÑO
# =========================================================

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	health = max(
		health,
		0
	)

	print("==============================")
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
	print("==============================")

	# Si murió, ejecutamos la muerte directamente.
	if health <= 0:
		_die()
		return

	# Solo hacemos flash si sigue vivo.
	_flash_player_damage()


	# -------------------------
	# MUERTE
	# -------------------------

	if health <= 0:
		_die()


# =========================================================
# FLASH DEL JUGADOR
# =========================================================
func is_alive() -> bool:
	return not is_dead

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
# MUERTE DEL JUGADOR
# =========================================================

func _die() -> void:
	if is_dead:
		return

	is_dead = true

	print("==============================")
	print("PLAYER DERROTADO")
	print("==============================")


	# -------------------------
	# DETENER MOVIMIENTO
	# -------------------------

	velocity = Vector2.ZERO


	# -------------------------
	# APAGAR ATAQUE
	# -------------------------

	attack_time_left = 0.0

	attack_collision.set_deferred(
		"disabled",
		true
	)

	if attack_debug != null:
		attack_debug.visible = false


	# -------------------------
	# VISUAL PROVISIONAL DE MUERTE
	# -------------------------

	player_animated.modulate = Color(
		0.35,
		0.35,
		0.35,
		1.0
	)

	# Cuando tengamos animación de muerte,
	# reemplazaremos esto por death_s / death_n, etc.


# =========================================================
# HITBOX ROJA PROVISIONAL
# =========================================================

func _create_attack_debug() -> void:
	attack_debug = Polygon2D.new()

	attack_debug.name = "AttackDebug"


	# Mismo tamaño que nuestro RectangleShape2D 70 x 45.
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
