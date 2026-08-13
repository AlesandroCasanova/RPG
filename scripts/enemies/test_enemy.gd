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
# COMBATE GRUPAL
# =========================================================

# Cantidad máxima de enemigos que pueden atacar
# al jugador al mismo tiempo.
@export var max_simultaneous_attackers: int = 2

# Distancia de los enemigos que tienen permiso de atacar.
@export var attack_slot_radius: float = 58.0

# Distancia de los enemigos que están esperando.
@export var waiting_slot_radius: float = 115.0

# Margen del sistema de slots.
@export var combat_slot_tolerance: float = 25.0


# =========================================================
# KNOCKBACK
# =========================================================

@export var knockback_force: float = 120.0
@export var knockback_friction: float = 1400.0


# =========================================================
# AVOIDANCE
# =========================================================

@export var avoidance_radius: float = 22.0
@export var avoidance_neighbor_distance: float = 120.0
@export var avoidance_max_neighbors: int = 8
@export var avoidance_time_horizon: float = 0.6


# =========================================================
# NODOS
# =========================================================

@onready var visual: Polygon2D = $Polygon2D

@onready var health_bar: ProgressBar = $HealthBar

@onready var navigation_agent: NavigationAgent2D = (
	$NavigationAgent2D
)


# =========================================================
# ESTADO
# =========================================================

var health: int

var player: CharacterBody2D = null

var attack_cooldown_left: float = 0.0

var knockback_velocity: Vector2 = Vector2.ZERO

var wants_navigation_movement: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	health = max_health


	# -----------------------------------------------------
	# GRUPO DE ENEMIGOS
	# -----------------------------------------------------

	add_to_group("enemies")


	# -----------------------------------------------------
	# COLISIONES
	# -----------------------------------------------------

	collision_layer = 2
	collision_mask = 1


	# -----------------------------------------------------
	# BARRA DE VIDA
	# -----------------------------------------------------

	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false


	# -----------------------------------------------------
	# BUSCAR PLAYER
	# -----------------------------------------------------

	player = get_tree().get_first_node_in_group(
		"player"
	) as CharacterBody2D


	if player == null:

		print(
			"ERROR: TestEnemy no encontró al Player"
		)

	else:

		print(
			"ENEMIGO: Player encontrado"
		)


	# -----------------------------------------------------
	# AVOIDANCE
	# -----------------------------------------------------

	navigation_agent.avoidance_enabled = true

	navigation_agent.radius = (
		avoidance_radius
	)

	navigation_agent.neighbor_distance = (
		avoidance_neighbor_distance
	)

	navigation_agent.max_neighbors = (
		avoidance_max_neighbors
	)

	navigation_agent.time_horizon_agents = (
		avoidance_time_horizon
	)

	navigation_agent.max_speed = (
		move_speed
	)

	navigation_agent.avoidance_layers = 1
	navigation_agent.avoidance_mask = 1


	# -----------------------------------------------------
	# SEÑAL DE AVOIDANCE
	# -----------------------------------------------------

	if not navigation_agent.velocity_computed.is_connected(
		_on_navigation_agent_velocity_computed
	):

		navigation_agent.velocity_computed.connect(
			_on_navigation_agent_velocity_computed
		)


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

		wants_navigation_movement = false

		navigation_agent.velocity = (
			Vector2.ZERO
		)

		velocity = knockback_velocity

		move_and_slide()


		knockback_velocity = (
			knockback_velocity.move_toward(
				Vector2.ZERO,
				knockback_friction * delta
			)
		)


		if knockback_velocity.length() < 1.0:

			knockback_velocity = Vector2.ZERO


		return


	# -----------------------------------------------------
	# PLAYER NO EXISTE
	# -----------------------------------------------------

	if not is_instance_valid(player):

		_stop_navigation()

		return


	# -----------------------------------------------------
	# PLAYER MUERTO
	# -----------------------------------------------------

	if player.has_method("is_alive"):

		if not player.is_alive():

			_stop_navigation()

			return


	# -----------------------------------------------------
	# DISTANCIA AL PLAYER
	# -----------------------------------------------------

	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)


	# -----------------------------------------------------
	# FUERA DE DETECCIÓN
	# -----------------------------------------------------

	if distance_to_player > detection_range:

		_stop_navigation()

		return


	# -----------------------------------------------------
	# INFORMACIÓN DE COMBATE
	# -----------------------------------------------------

	var combat_info: Dictionary = (
		_get_combat_info()
	)


	var combat_position: Vector2 = (
		combat_info["position"]
	)


	var can_attack: bool = (
		combat_info["can_attack"]
	)


	# -----------------------------------------------------
	# TIENE CUPO DE ATAQUE
	# -----------------------------------------------------

	if can_attack:

		# Si ya está suficientemente cerca del jugador,
		# ataca aunque avoidance no le permita colocarse
		# exactamente en el slot matemático.
		if distance_to_player <= attack_range:

			_stop_navigation()


			if attack_cooldown_left <= 0.0:

				_attack_player()


			return


	# -----------------------------------------------------
	# IR A LA POSICIÓN ASIGNADA
	# -----------------------------------------------------

	_move_toward_position(
		combat_position
	)


# =========================================================
# MOVERSE HACIA UNA POSICIÓN
# =========================================================

func _move_toward_position(
	target: Vector2
) -> void:

	wants_navigation_movement = true


	navigation_agent.target_position = (
		target
	)


	var next_path_position: Vector2 = (
		navigation_agent.get_next_path_position()
	)


	var direction_to_next_point: Vector2 = (
		next_path_position
		- global_position
	).normalized()


	var desired_velocity: Vector2 = (
		direction_to_next_point
		* move_speed
	)


	navigation_agent.velocity = (
		desired_velocity
	)


# =========================================================
# INFORMACIÓN DE COMBATE
# =========================================================

func _get_combat_info() -> Dictionary:

	var result: Dictionary = {
		"position": player.global_position,
		"can_attack": false
	}


	var active_enemies: Array[Node] = (
		_get_active_enemies()
	)


	if active_enemies.is_empty():

		return result


	# -----------------------------------------------------
	# LOS MÁS CERCANOS TIENEN PRIORIDAD DE ATAQUE
	# -----------------------------------------------------

	active_enemies.sort_custom(
		_sort_enemies_by_distance_to_player
	)


	var my_index: int = (
		active_enemies.find(
			self
		)
	)


	if my_index < 0:

		return result


	var enemy_count: int = (
		active_enemies.size()
	)


	# =====================================================
	# CANTIDAD DE ATACANTES
	# =====================================================

	var attacker_count: int = mini(
		max_simultaneous_attackers,
		enemy_count
	)


	var can_attack: bool = (
		my_index < attacker_count
	)


	# =====================================================
	# POSICIÓN DE LOS ATACANTES
	# =====================================================

	if can_attack:

		var angle_step: float = (
			TAU
			/ float(attacker_count)
		)


		var angle: float = (
			-PI / 2.0
			+ angle_step
			* float(my_index)
		)


		var direction: Vector2 = (
			Vector2.RIGHT.rotated(
				angle
			)
		)


		result["position"] = (
			player.global_position
			+ direction
			* attack_slot_radius
		)


		result["can_attack"] = true


		return result


	# =====================================================
	# ENEMIGOS EN ESPERA
	# =====================================================

	var waiting_index: int = (
		my_index
		- attacker_count
	)


	var waiting_count: int = (
		enemy_count
		- attacker_count
	)


	if waiting_count <= 0:

		return result


	var waiting_angle_step: float = (
		TAU
		/ float(waiting_count)
	)


	# Rotamos la segunda línea para evitar que
	# coincida exactamente con los atacantes.
	var waiting_start_angle: float = (
		-PI / 2.0
		+ PI / 4.0
	)


	var waiting_angle: float = (
		waiting_start_angle
		+ waiting_angle_step
		* float(waiting_index)
	)


	var waiting_direction: Vector2 = (
		Vector2.RIGHT.rotated(
			waiting_angle
		)
	)


	result["position"] = (
		player.global_position
		+ waiting_direction
		* waiting_slot_radius
	)


	result["can_attack"] = false


	return result


# =========================================================
# OBTENER ENEMIGOS ACTIVOS
# =========================================================

func _get_active_enemies() -> Array[Node]:

	var all_enemies: Array[Node] = (
		get_tree().get_nodes_in_group(
			"enemies"
		)
	)


	var active_enemies: Array[Node] = []


	for enemy: Node in all_enemies:

		if not is_instance_valid(enemy):

			continue


		if not enemy is Node2D:

			continue


		# -------------------------------------------------
		# IGNORAR MUERTOS
		# -------------------------------------------------

		if enemy.has_method(
			"is_enemy_alive"
		):

			if not enemy.is_enemy_alive():

				continue


		var enemy_2d: Node2D = (
			enemy as Node2D
		)


		# -------------------------------------------------
		# SOLO ENEMIGOS DE ESTA PELEA
		# -------------------------------------------------

		var distance: float = (
			enemy_2d.global_position.distance_to(
				player.global_position
			)
		)


		if distance <= detection_range:

			active_enemies.append(
				enemy
			)


	return active_enemies


# =========================================================
# ORDENAR ENEMIGOS POR DISTANCIA AL PLAYER
# =========================================================

func _sort_enemies_by_distance_to_player(
	a: Node,
	b: Node
) -> bool:

	if not is_instance_valid(player):

		return false


	var enemy_a: Node2D = (
		a as Node2D
	)


	var enemy_b: Node2D = (
		b as Node2D
	)


	var distance_a: float = (
		enemy_a.global_position.distance_squared_to(
			player.global_position
		)
	)


	var distance_b: float = (
		enemy_b.global_position.distance_squared_to(
			player.global_position
		)
	)


	# -----------------------------------------------------
	# EMPATE
	# -----------------------------------------------------

	# Si están prácticamente a la misma distancia,
	# usamos el instance ID para mantener el orden estable.
	if absf(
		distance_a - distance_b
	) < 1.0:

		return (
			a.get_instance_id()
			<
			b.get_instance_id()
		)


	# El más cercano va primero.
	return (
		distance_a < distance_b
	)


# =========================================================
# ¿ESTÁ VIVO?
# =========================================================

func is_enemy_alive() -> bool:

	return health > 0


# =========================================================
# AVOIDANCE
# =========================================================

func _on_navigation_agent_velocity_computed(
	safe_velocity: Vector2
) -> void:

	if health <= 0:

		return


	if not wants_navigation_movement:

		return


	if knockback_velocity != Vector2.ZERO:

		return


	if not is_instance_valid(player):

		return


	if player.has_method("is_alive"):

		if not player.is_alive():

			return


	velocity = safe_velocity

	move_and_slide()


# =========================================================
# DETENER NAVEGACIÓN
# =========================================================

func _stop_navigation() -> void:

	wants_navigation_movement = false

	velocity = Vector2.ZERO


	navigation_agent.velocity = (
		Vector2.ZERO
	)


# =========================================================
# ATAQUE
# =========================================================

func _attack_player() -> void:

	if not is_instance_valid(player):

		return


	if player.has_method("is_alive"):

		if not player.is_alive():

			return


	attack_cooldown_left = (
		attack_cooldown
	)


	print(
		"ENEMIGO ATACA AL JUGADOR"
	)


	_attack_flash()


	if player.has_method(
		"take_damage"
	):

		player.take_damage(
			attack_damage
		)


# =========================================================
# FLASH DE ATAQUE
# =========================================================

func _attack_flash() -> void:

	visual.modulate = Color(
		1.0,
		0.55,
		0.15,
		1.0
	)


	var tween: Tween = (
		create_tween()
	)


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

	if health <= 0:

		return


	health -= amount


	health = maxi(
		health,
		0
	)


	health_bar.value = (
		health
	)


	print(
		"=============================="
	)

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

	print(
		"=============================="
	)


	_show_damage_number(
		amount
	)


	_flash_damage()


	# -----------------------------------------------------
	# MUERTE
	# -----------------------------------------------------

	if health <= 0:

		die()

		return


	# -----------------------------------------------------
	# KNOCKBACK
	# -----------------------------------------------------

	_apply_knockback(
		attacker_position
	)


# =========================================================
# NÚMERO DE DAÑO
# =========================================================

func _show_damage_number(
	amount: int
) -> void:

	var damage_label: Label = (
		Label.new()
	)


	damage_label.text = (
		str(amount)
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


	var tween: Tween = (
		create_tween()
	)


	tween.set_parallel(
		true
	)


	# -----------------------------------------------------
	# SUBE
	# -----------------------------------------------------

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


	# -----------------------------------------------------
	# DESAPARECE
	# -----------------------------------------------------

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


	var tween: Tween = (
		create_tween()
	)


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

	var direction: Vector2 = (
		global_position
		- attacker_position
	).normalized()


	knockback_velocity = (
		direction
		* knockback_force
	)


# =========================================================
# MUERTE
# =========================================================

func die() -> void:

	print(
		"=============================="
	)

	print(
		"ENEMIGO DERROTADO"
	)

	print(
		"=============================="
	)


	wants_navigation_movement = false


	navigation_agent.avoidance_enabled = (
		false
	)


	navigation_agent.velocity = (
		Vector2.ZERO
	)


	velocity = Vector2.ZERO


	knockback_velocity = (
		Vector2.ZERO
	)


	queue_free()
