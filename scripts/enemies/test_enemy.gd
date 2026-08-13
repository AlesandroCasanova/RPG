extends CharacterBody2D


# =========================================================
# VIDA
# =========================================================

@export var max_health: int = 100


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


# =========================================================
# ESTADO
# =========================================================

var health: int


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	health = max_health

	# El enemigo pertenece a Layer 2.
	collision_layer = 2

	# Colisiona con objetos de Layer 1.
	collision_mask = 1

	# Barra de vida.
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false

	print("ENEMIGO CREADO | HP: ", health)


# =========================================================
# FÍSICA
# =========================================================

func _physics_process(delta: float) -> void:
	if velocity != Vector2.ZERO:
		move_and_slide()

		velocity = velocity.move_toward(
			Vector2.ZERO,
			knockback_friction * delta
		)


# =========================================================
# RECIBIR DAÑO
# =========================================================

func take_damage(amount: int, attacker_position: Vector2) -> void:
	health -= amount
	health = max(health, 0)

	health_bar.value = health

	print("==============================")
	print("ENEMIGO RECIBE ", amount, " DE DAÑO")
	print("HP: ", health, " / ", max_health)
	print("==============================")

	# Número flotante.
	_show_damage_number(amount)

	# Feedback.
	_flash_damage()
	_apply_knockback(attacker_position)

	if health <= 0:
		die()


# =========================================================
# NÚMERO DE DAÑO FLOTANTE
# =========================================================

func _show_damage_number(amount: int) -> void:
	var damage_label := Label.new()

	damage_label.text = str(amount)

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

	# Posición inicial encima del enemigo.
	damage_label.position = Vector2(
		-40.0,
		-125.0
	)

	# Tamaño del número.
	damage_label.add_theme_font_size_override(
		"font_size",
		28
	)

	# Color del daño.
	damage_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.85, 0.15, 1.0)
	)

	# Contorno negro para que se lea sobre cualquier fondo.
	damage_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	damage_label.add_theme_constant_override(
		"outline_size",
		6
	)

	add_child(damage_label)

	# Animación.
	var tween := create_tween()

	tween.set_parallel(true)

	# El número sube.
	tween.tween_property(
		damage_label,
		"position",
		damage_label.position + Vector2(0.0, -50.0),
		0.65
	)

	# Se desvanece.
	tween.tween_property(
		damage_label,
		"modulate:a",
		0.0,
		0.65
	).set_delay(0.15)

	tween.set_parallel(false)

	# Se elimina al terminar.
	tween.tween_callback(
		damage_label.queue_free
	)


# =========================================================
# FLASH AL RECIBIR DAÑO
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

func _apply_knockback(attacker_position: Vector2) -> void:
	var direction := (
		global_position - attacker_position
	).normalized()

	velocity = direction * knockback_force


# =========================================================
# MUERTE
# =========================================================

func die() -> void:
	print("ENEMIGO DERROTADO")

	queue_free()
