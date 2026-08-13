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

	# Puede colisionar con objetos de Layer 1.
	collision_mask = 1

	# Configuración inicial de la barra.
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

	_flash_damage()
	_apply_knockback(attacker_position)

	if health <= 0:
		die()


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
