extends CharacterBody2D


# =========================================================
# VIDA
# =========================================================

@export var max_health: int = 100


# =========================================================
# IA
# =========================================================

@export var move_speed: float = 120.0

@export var detection_range: float = 350.0

@export var attack_range: float = 70.0

@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0


# =========================================================
# KNOCKBACK
# =========================================================

@export var knockback_force: float = 120.0
@export var knockback_friction: float = 1400.0


# =========================================================
# NODOS
# =========================================================

@onready var visual: Polygon2D = $Polygon2D
@onready var health_bar: ProgressBar = $HealthBar

@onready var navigation_agent: NavigationAgent2D = \
	$NavigationAgent2D


# =========================================================
# ESTADO
# =========================================================

var health: int

var player: CharacterBody2D = null

var attack_cooldown_left: float = 0.0

var knockback_velocity: Vector2 = Vector2.ZERO


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	health = max_health

	# Enemy = Layer 2.
	collision_layer = 2

	# Colisiona con Player / escenario Layer 1.
	collision_mask = 1

	# Barra de vida.
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false

	# Buscar Player.
	player = get_tree().get_first_node_in_group(
		"player"
	) as CharacterBody2D

	if player == null:
		print("ERROR: TestEnemy no encontró al Player")
	else:
		print("ENEMIGO: Player encontrado")

	print(
		"ENEMIGO CREADO | HP: ",
		health
	)


# =========================================================
# IA / FÍSICA
# =========================================================

func _physics_process(delta: float) -> void:

	# -----------------------------------------------------
	# COOLDOWN
	# -----------------------------------------------------

	if attack_cooldown_left > 0.0:
		attack_cooldown_left -= delta

		if attack_cooldown_left < 0.0:
			attack_cooldown_left = 0.0


	# -----------------------------------------------------
	# KNOCKBACK
	# -----------------------------------------------------

	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity

		knockback_velocity = knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_friction * delta
		)

		if knockback_velocity.length() < 1.0:
			knockback_velocity = Vector2.ZERO

		move_and_slide()

		return


	# -----------------------------------------------------
	# SIN PLAYER
	# -----------------------------------------------------

	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return


	# -----------------------------------------------------
	# PLAYER MUERTO
	# -----------------------------------------------------

	if player.has_method("is_alive"):
		if not player.is_alive():
			velocity = Vector2.ZERO
			return


	# -----------------------------------------------------
	# DISTANCIA
	# -----------------------------------------------------

	var distance_to_player := global_position.distance_to(
		player.global_position
	)


	# -----------------------------------------------------
	# PLAYER LEJOS
	# -----------------------------------------------------

	if distance_to_player > detection_range:
		velocity = Vector2.ZERO
		return


	# -----------------------------------------------------
	# ATACAR
	# -----------------------------------------------------

	if distance_to_player <= attack_range:
		velocity = Vector2.ZERO

		if attack_cooldown_left <= 0.0:
			_attack_player()

		return


	# -----------------------------------------------------
	# PATHFINDING
	# -----------------------------------------------------

	navigation_agent.target_position = (
		player.global_position
	)

	# Consultar el siguiente punto de la ruta.
	var next_path_position := (
		navigation_agent.get_next_path_position()
	)

	var direction_to_next_point := (
		next_path_position - global_position
	).normalized()

	velocity = (
		direction_to_next_point * move_speed
	)

	move_and_slide()


# =========================================================
# ATAQUE DEL ENEMIGO
# =========================================================

func _attack_player() -> void:

	if not is_instance_valid(player):
		return

	if player.has_method("is_alive"):
		if not player.is_alive():
			return

	attack_cooldown_left = attack_cooldown

	print("ENEMIGO ATACA AL JUGADOR")

	_attack_flash()

	if player.has_method("take_damage"):
		player.take_damage(
			attack_damage
		)


# =========================================================
# FLASH DEL ATAQUE
# =========================================================

func _attack_flash() -> void:
	visual.modulate = Color(
		1.0,
		0.55,
		0.15,
		1.0
	)

	var tween := create_tween()

	tween.tween_property(
		visual,
		"modulate",
		Color.WHITE,
		0.12
	)


# =========================================================
# RECIBIR DAÑO
# =========================================================

func take_damage(
	amount: int,
	attacker_position: Vector2
) -> void:

	health -= amount

	health = max(
		health,
		0
	)

	health_bar.value = health

	print("==============================")
	print(
		"ENEMIGO RECIBE ",
		amount,
		" DE DAÑO"
	)

	print(
		"HP: ",
		health,
		" / ",
		max_health
	)

	print("==============================")

	_show_damage_number(
		amount
	)

	_flash_damage()

	_apply_knockback(
		attacker_position
	)

	if health <= 0:
		die()


# =========================================================
# NÚMERO DE DAÑO
# =========================================================

func _show_damage_number(
	amount: int
) -> void:

	var damage_label := Label.new()

	damage_label.text = str(
		amount
	)

	damage_label.custom_minimum_size = Vector2(
		80.0,
		40.0
	)

	damage_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	damage_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	damage_label.position = Vector2(
		-40.0,
		-125.0
	)

	damage_label.add_theme_font_size_override(
		"font_size",
		28
	)

	damage_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.85,
			0.15,
			1.0
		)
	)

	damage_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	damage_label.add_theme_constant_override(
		"outline_size",
		6
	)

	add_child(
		damage_label
	)

	var tween := create_tween()

	tween.set_parallel(
		true
	)

	tween.tween_property(
		damage_label,
		"position",
		damage_label.position
		+ Vector2(
			0.0,
			-50.0
		),
		0.65
	)

	tween.tween_property(
		damage_label,
		"modulate:a",
		0.0,
		0.65
	).set_delay(
		0.15
	)

	tween.set_parallel(
		false
	)

	tween.tween_callback(
		damage_label.queue_free
	)


# =========================================================
# FLASH DE DAÑO
# =========================================================

func _flash_damage() -> void:
	visual.modulate = Color(
		1.0,
		0.15,
		0.15,
		1.0
	)

	var tween := create_tween()

	tween.tween_property(
		visual,
		"modulate",
		Color.WHITE,
		0.15
	)


# =========================================================
# KNOCKBACK
# =========================================================

func _apply_knockback(
	attacker_position: Vector2
) -> void:

	var direction := (
		global_position - attacker_position
	).normalized()

	knockback_velocity = (
		direction * knockback_force
	)


# =========================================================
# MUERTE
# =========================================================

func die() -> void:
	print("==============================")
	print("ENEMIGO DERROTADO")
	print("==============================")

	queue_free()
