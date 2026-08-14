class_name Enemy
extends CharacterBody2D


# =========================================================
# RECURSOS
# =========================================================

@export_category("Datos")

@export var enemy_data: EnemyData

@export var primary_attack: AttackData


# =========================================================
# COLISIONES
# =========================================================

@export_category("Colisiones")

@export_flags_2d_physics
var body_collision_layer: int = 2

@export_flags_2d_physics
var body_collision_mask: int = 1

@export_flags_2d_physics
var attack_collision_mask: int = 1


# =========================================================
# DEBUG
# =========================================================

@export_category("Debug")

@export var debug_combat: bool = false


# =========================================================
# NODOS
# =========================================================

@onready var enemy_animated: AnimatedSprite2D = (
	get_node_or_null("EnemyAnimated")
	as AnimatedSprite2D
)

@onready var health_bar: ProgressBar = (
	get_node_or_null("HealthBar")
	as ProgressBar
)

@onready var navigation_agent: NavigationAgent2D = (
	get_node_or_null("NavigationAgent2D")
	as NavigationAgent2D
)


# =========================================================
# ATTACK AREA
# =========================================================

var attack_area: Area2D = null

var attack_collision: CollisionShape2D = null

# IMPORTANTE:
# Esta shape será propia de cada instancia del enemigo.
var attack_hitbox_shape: RectangleShape2D = null


# =========================================================
# ESTADO
# =========================================================

var last_facing: String = "s"

# Fallback cardinal para mantener el comportamiento visual actual
# hasta que existan las animaciones diagonales.
var last_cardinal_facing: String = "s"

var health: int = 0

var player: CharacterBody2D = null

var attack_cooldown_left: float = 0.0

var knockback_velocity: Vector2 = Vector2.ZERO

var wants_navigation_movement: bool = false


# =========================================================
# DEBUG ESTADO
# =========================================================

var debug_combat_position: Vector2 = Vector2.ZERO

var debug_can_attack: bool = false

var debug_hitbox_reaches_player: bool = false

var debug_distance_to_player: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready() -> void:

	# -----------------------------------------------------
	# VALIDAR ESCENA BASE
	# -----------------------------------------------------

	if not _validate_required_nodes():

		set_physics_process(false)

		return


	# -----------------------------------------------------
	# RESOURCES
	# -----------------------------------------------------

	_ensure_resources()


	# -----------------------------------------------------
	# VIDA
	# -----------------------------------------------------

	health = maxi(
		enemy_data.max_health,
		1
	)


	# -----------------------------------------------------
	# GRUPO
	# -----------------------------------------------------

	add_to_group(
		"enemies"
	)


	# -----------------------------------------------------
	# COLISIONES DEL CUERPO
	# -----------------------------------------------------

	collision_layer = (
		body_collision_layer
	)

	collision_mask = (
		body_collision_mask
	)


	# -----------------------------------------------------
	# BARRA DE VIDA
	# -----------------------------------------------------

	_update_health_bar()


	# -----------------------------------------------------
	# PLAYER
	# -----------------------------------------------------

	_find_player()


	# -----------------------------------------------------
	# ATTACK AREA
	# -----------------------------------------------------

	_setup_attack_area()


	# -----------------------------------------------------
	# AVOIDANCE
	# -----------------------------------------------------

	_setup_navigation_avoidance()


	# -----------------------------------------------------
	# ANIMACIÓN
	# -----------------------------------------------------

	_play_idle()


	print(
		"ENEMIGO CREADO | ",
		enemy_data.enemy_name,
		" | HP: ",
		health
	)


# =========================================================
# VALIDAR NODOS NECESARIOS
# =========================================================

func _validate_required_nodes() -> bool:

	var valid: bool = true


	if enemy_animated == null:

		push_error(
			name
			+ ": falta EnemyAnimated (AnimatedSprite2D)."
		)

		valid = false


	if health_bar == null:

		push_error(
			name
			+ ": falta HealthBar (ProgressBar)."
		)

		valid = false


	if navigation_agent == null:

		push_error(
			name
			+ ": falta NavigationAgent2D."
		)

		valid = false


	return valid


# =========================================================
# ASEGURAR RESOURCES
# =========================================================

func _ensure_resources() -> void:

	if enemy_data == null:

		push_warning(
			name
			+ " no tiene EnemyData asignado. "
			+ "Se utilizarán valores por defecto."
		)

		enemy_data = EnemyData.new()


	if primary_attack == null:

		push_warning(
			enemy_data.enemy_name
			+ " no tiene AttackData asignado. "
			+ "Se utilizarán valores por defecto."
		)

		primary_attack = AttackData.new()


# =========================================================
# ACTUALIZAR BARRA DE VIDA
# =========================================================

func _update_health_bar() -> void:

	if health_bar == null:

		return


	var max_health: int = maxi(
		enemy_data.max_health,
		1
	)


	health_bar.min_value = 0

	health_bar.max_value = (
		max_health
	)

	health_bar.value = (
		health
	)

	health_bar.show_percentage = false


	# -----------------------------------------------------
	# VISIBILIDAD AUTOMÁTICA
	#
	# VIDA COMPLETA:
	# Oculta.
	#
	# ENEMIGO HERIDO:
	# Visible.
	#
	# ENEMIGO MUERTO:
	# Oculta.
	# -----------------------------------------------------

	health_bar.visible = (
		health > 0
		and health < max_health
	)


# =========================================================
# BUSCAR PLAYER
# =========================================================

func _find_player() -> void:

	player = get_tree().get_first_node_in_group(
		"player"
	) as CharacterBody2D


	if player == null:

		push_warning(
			enemy_data.enemy_name
			+ ": no se encontró un CharacterBody2D "
			+ "en el grupo player."
		)


# =========================================================
# CONFIGURAR AVOIDANCE
# =========================================================

func _setup_navigation_avoidance() -> void:

	navigation_agent.avoidance_enabled = true

	navigation_agent.radius = (
		enemy_data.avoidance_radius
	)

	navigation_agent.neighbor_distance = (
		enemy_data.avoidance_neighbor_distance
	)

	navigation_agent.max_neighbors = (
		enemy_data.avoidance_max_neighbors
	)

	navigation_agent.time_horizon_agents = (
		enemy_data.avoidance_time_horizon
	)

	navigation_agent.max_speed = (
		enemy_data.move_speed
	)

	navigation_agent.avoidance_layers = 1
	navigation_agent.avoidance_mask = 1


	if not navigation_agent.velocity_computed.is_connected(
		_on_navigation_agent_velocity_computed
	):

		navigation_agent.velocity_computed.connect(
			_on_navigation_agent_velocity_computed
		)


# =========================================================
# CONFIGURAR ATTACK AREA
# =========================================================

func _setup_attack_area() -> void:

	# -----------------------------------------------------
	# ATTACK AREA
	# -----------------------------------------------------

	var existing_area: Node = (
		get_node_or_null(
			"AttackArea"
		)
	)


	if existing_area is Area2D:

		attack_area = (
			existing_area as Area2D
		)

	else:

		attack_area = (
			Area2D.new()
		)

		attack_area.name = (
			"AttackArea"
		)

		add_child(
			attack_area
		)


	# No usamos las señales de overlap del Area2D.
	# La comprobación real se hace con intersect_shape().
	attack_area.collision_layer = 0
	attack_area.collision_mask = 0

	attack_area.monitoring = false
	attack_area.monitorable = false


	# -----------------------------------------------------
	# ATTACK COLLISION
	# -----------------------------------------------------

	var existing_collision: Node = (
		attack_area.get_node_or_null(
			"AttackCollision"
		)
	)


	# Compatibilidad temporal con escenas anteriores.
	if existing_collision == null:

		existing_collision = (
			attack_area.get_node_or_null(
				"CollisionShape2D"
			)
		)


	if existing_collision is CollisionShape2D:

		attack_collision = (
			existing_collision
			as CollisionShape2D
		)

	else:

		attack_collision = (
			CollisionShape2D.new()
		)

		attack_collision.name = (
			"AttackCollision"
		)

		attack_area.add_child(
			attack_collision
		)


	attack_collision.position = (
		Vector2.ZERO
	)

	attack_collision.rotation = 0.0


	# =====================================================
	# SHAPE ÚNICA PARA ESTA INSTANCIA
	# =====================================================

	if attack_collision.shape is RectangleShape2D:

		var duplicated_shape: Resource = (
			attack_collision.shape.duplicate()
		)

		attack_hitbox_shape = (
			duplicated_shape
			as RectangleShape2D
		)

	else:

		attack_hitbox_shape = (
			RectangleShape2D.new()
		)


	attack_collision.shape = (
		attack_hitbox_shape
	)


	_update_attack_hitbox()


# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(
	delta: float
) -> void:

	# =====================================================
	# COOLDOWN
	# =====================================================

	if attack_cooldown_left > 0.0:

		attack_cooldown_left -= delta

		if attack_cooldown_left < 0.0:

			attack_cooldown_left = 0.0


	# =====================================================
	# KNOCKBACK
	# =====================================================

	if knockback_velocity != Vector2.ZERO:

		_process_knockback(
			delta
		)

		return


	# =====================================================
	# PLAYER
	# =====================================================

	if not is_instance_valid(
		player
	):

		_find_player()


		if not is_instance_valid(
			player
		):

			_stop_navigation()

			return


	# =====================================================
	# PLAYER MUERTO
	# =====================================================

	if player.has_method(
		"is_alive"
	):

		if not player.is_alive():

			_stop_navigation()

			return


	# =====================================================
	# DISTANCIA DE DETECCIÓN
	# =====================================================

	debug_distance_to_player = (
		global_position.distance_to(
			player.global_position
		)
	)


	if debug_distance_to_player > enemy_data.detection_range:

		debug_can_attack = false

		debug_hitbox_reaches_player = false

		_stop_navigation()


		if debug_combat:

			queue_redraw()


		return


	# =====================================================
	# INFORMACIÓN DEL COMBATE
	# =====================================================

	var combat_info: Dictionary = (
		_get_combat_info()
	)


	var combat_position: Vector2 = (
		combat_info["position"]
	)


	var can_attack: bool = (
		combat_info["can_attack"]
	)


	debug_combat_position = (
		combat_position
	)

	debug_can_attack = (
		can_attack
	)


	# =====================================================
	# ATACANTE ACTIVO
	# =====================================================

	if can_attack:

		_face_player()

		_update_attack_hitbox()


		debug_hitbox_reaches_player = (
			_attack_hitbox_reaches_player()
		)


		if debug_combat:

			queue_redraw()


		# -------------------------------------------------
		# PLAYER DENTRO DE LA HITBOX
		# -------------------------------------------------

		if debug_hitbox_reaches_player:

			_stop_navigation()


			if attack_cooldown_left <= 0.0:

				_attack_player()


			return


		# -------------------------------------------------
		# TODAVÍA NO LLEGA
		# -------------------------------------------------

		_move_toward_position(
			combat_position
		)

		return


	# =====================================================
	# ESPERANDO TURNO
	# =====================================================

	debug_hitbox_reaches_player = false


	if debug_combat:

		queue_redraw()


	_move_toward_position(
		combat_position
	)


# =========================================================
# KNOCKBACK PROCESS
# =========================================================

func _process_knockback(
	delta: float
) -> void:

	wants_navigation_movement = false

	navigation_agent.velocity = (
		Vector2.ZERO
	)


	velocity = (
		knockback_velocity
	)


	move_and_slide()


	knockback_velocity = (
		knockback_velocity.move_toward(
			Vector2.ZERO,
			enemy_data.knockback_friction
			* delta
		)
	)


	if knockback_velocity.length() < 1.0:

		knockback_velocity = (
			Vector2.ZERO
		)


	if debug_combat:

		queue_redraw()


# =========================================================
# ACTUALIZAR HITBOX
# =========================================================

func _update_attack_hitbox() -> void:

	if attack_area == null:

		return


	if attack_hitbox_shape == null:

		return


	if primary_attack == null:

		return


	var desired_size: Vector2 = Vector2(
		maxf(
			primary_attack.hitbox_length,
			1.0
		),
		maxf(
			primary_attack.hitbox_width,
			1.0
		)
	)


	if attack_hitbox_shape.size != desired_size:

		attack_hitbox_shape.size = (
			desired_size
		)


	var attack_direction: Vector2 = (
		_get_attack_direction()
	)


	if attack_direction == Vector2.ZERO:

		attack_direction = (
			Vector2.DOWN
		)


	var center_distance: float = (
		primary_attack.hitbox_start_offset
		+ primary_attack.hitbox_length
		* 0.5
	)


	attack_area.position = (
		attack_direction
		* center_distance
	)


	attack_area.rotation = (
		attack_direction.angle()
	)


# =========================================================
# DIRECCIÓN DEL ATAQUE
# =========================================================

func _get_attack_direction() -> Vector2:

	if is_instance_valid(
		player
	):

		var direction_to_player: Vector2 = (
			player.global_position
			- global_position
		)


		if direction_to_player.length_squared() > 0.001:

			return (
				direction_to_player.normalized()
			)


	# Fallback solamente si no podemos calcular la dirección real
	# hacia el player. La hitbox continúa apuntando en 360° cuando
	# el player es válido.
	match last_facing:

		"n":

			return Vector2.UP

		"ne":

			return Vector2(
				1.0,
				-1.0
			).normalized()

		"e":

			return Vector2.RIGHT

		"se":

			return Vector2(
				1.0,
				1.0
			).normalized()

		"s":

			return Vector2.DOWN

		"sw":

			return Vector2(
				-1.0,
				1.0
			).normalized()

		"w":

			return Vector2.LEFT

		"nw":

			return Vector2(
				-1.0,
				-1.0
			).normalized()


	return Vector2.DOWN


# =========================================================
# ¿HITBOX TOCA AL PLAYER?
# =========================================================

func _attack_hitbox_reaches_player() -> bool:

	if not is_instance_valid(
		player
	):

		return false


	if attack_area == null:

		return false


	if attack_hitbox_shape == null:

		return false


	var query: PhysicsShapeQueryParameters2D = (
		PhysicsShapeQueryParameters2D.new()
	)


	query.shape = (
		attack_hitbox_shape
	)

	query.transform = (
		attack_area.global_transform
	)

	query.collision_mask = (
		attack_collision_mask
	)

	query.collide_with_bodies = true
	query.collide_with_areas = true

	query.exclude = [
		get_rid()
	]


	var hits: Array[Dictionary] = (
		get_world_2d()
		.direct_space_state
		.intersect_shape(
			query,
			32
		)
	)


	for hit: Dictionary in hits:

		var collider: Variant = (
			hit.get(
				"collider"
			)
		)


		if collider == player:

			return true


		if collider is Node:

			var current_node: Node = (
				collider as Node
			)


			while current_node != null:

				if current_node == player:

					return true


				if current_node.is_in_group(
					"player"
				):

					return true


				current_node = (
					current_node.get_parent()
				)


	return false


# =========================================================
# MOVIMIENTO
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
	)


	if direction_to_next_point.length_squared() < 0.001:

		_stop_navigation()

		return


	direction_to_next_point = (
		direction_to_next_point.normalized()
	)


	_update_facing(
		direction_to_next_point
	)


	var desired_velocity: Vector2 = (
		direction_to_next_point
		* enemy_data.move_speed
	)


	navigation_agent.velocity = (
		desired_velocity
	)


# =========================================================
# ORIENTACIÓN
# =========================================================

func _update_facing(
	direction: Vector2
) -> void:

	if direction == Vector2.ZERO:

		return


	# Dirección visual de 8 vías.
	last_facing = (
		_direction_to_8_way_facing(
			direction
		)
	)


	# Guardamos además la cardinal que habría usado el sistema
	# anterior. Mientras falten sprites diagonales, _play_idle()
	# usa exactamente este fallback.
	last_cardinal_facing = (
		_direction_to_cardinal_facing(
			direction
		)
	)


	_play_idle()


# =========================================================
# CONVERTIR VECTOR A 8 DIRECCIONES
# =========================================================

func _direction_to_8_way_facing(
	direction: Vector2
) -> String:

	if direction == Vector2.ZERO:

		return last_facing


	var angle_degrees: float = rad_to_deg(
		direction.angle()
	)


	# Godot 2D:
	# E =   0°
	# SE = 45°
	# S =  90°
	# SW = 135°
	# W = ±180°
	# NW = -135°
	# N =  -90°
	# NE = -45°

	if angle_degrees >= -22.5 and angle_degrees < 22.5:

		return "e"


	if angle_degrees >= 22.5 and angle_degrees < 67.5:

		return "se"


	if angle_degrees >= 67.5 and angle_degrees < 112.5:

		return "s"


	if angle_degrees >= 112.5 and angle_degrees < 157.5:

		return "sw"


	if angle_degrees >= 157.5 or angle_degrees < -157.5:

		return "w"


	if angle_degrees >= -157.5 and angle_degrees < -112.5:

		return "nw"


	if angle_degrees >= -112.5 and angle_degrees < -67.5:

		return "n"


	if angle_degrees >= -67.5 and angle_degrees < -22.5:

		return "ne"


	return "s"


# =========================================================
# FALLBACK CARDINAL ORIGINAL
# =========================================================

func _direction_to_cardinal_facing(
	direction: Vector2
) -> String:

	if direction == Vector2.ZERO:

		return last_cardinal_facing


	if absf(
		direction.x
	) > absf(
		direction.y
	):

		if direction.x > 0.0:

			return "e"

		else:

			return "w"

	else:

		if direction.y > 0.0:

			return "s"

		else:

			return "n"


# =========================================================
# MIRAR AL PLAYER
# =========================================================

func _face_player() -> void:

	if not is_instance_valid(
		player
	):

		return


	var direction_to_player: Vector2 = (
		player.global_position
		- global_position
	)


	if direction_to_player.length_squared() < 0.001:

		return


	_update_facing(
		direction_to_player.normalized()
	)


# =========================================================
# ANIMACIÓN
# =========================================================

func _play_idle() -> void:

	if enemy_animated == null:

		return


	if enemy_animated.sprite_frames == null:

		return


	# -----------------------------------------------------
	# 1) INTENTAR LA DIRECCIÓN REAL DE 8 VÍAS
	# -----------------------------------------------------

	var animation_name: String = (
		"idle_"
		+ last_facing
	)


	if enemy_animated.sprite_frames.has_animation(
		animation_name
	):

		if enemy_animated.animation != animation_name:

			enemy_animated.play(
				animation_name
			)


		return


	# -----------------------------------------------------
	# 2) FALLBACK CARDINAL
	#
	# Mientras no tengamos idle_ne / idle_se / idle_sw /
	# idle_nw, conserva el comportamiento visual que ya
	# teníamos antes de habilitar las 8 direcciones.
	# -----------------------------------------------------

	var fallback_animation_name: String = (
		"idle_"
		+ last_cardinal_facing
	)


	if not enemy_animated.sprite_frames.has_animation(
		fallback_animation_name
	):

		return


	if enemy_animated.animation != fallback_animation_name:

		enemy_animated.play(
			fallback_animation_name
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


	var attacker_count: int = mini(
		enemy_data.max_simultaneous_attackers,
		enemy_count
	)


	# =====================================================
	# ATACANTE
	# =====================================================

	if my_index < attacker_count:

		var attackers: Array[Node] = []


		for index: int in range(
			attacker_count
		):

			attackers.append(
				active_enemies[index]
			)


		var assignments: Dictionary = (
			_build_slot_assignments(
				attackers,
				enemy_data.attack_slot_radius,
				maxi(
					enemy_data.attack_slot_count,
					attacker_count
				),
				0.0
			)
		)


		var my_id: int = (
			get_instance_id()
		)


		if assignments.has(
			my_id
		):

			result["position"] = (
				assignments[
					my_id
				]
			)


		result["can_attack"] = true


		return result


	# =====================================================
	# EN ESPERA
	# =====================================================

	var waiting_enemies: Array[Node] = []


	for index: int in range(
		attacker_count,
		enemy_count
	):

		waiting_enemies.append(
			active_enemies[index]
		)


	if waiting_enemies.is_empty():

		return result


	var safe_waiting_slot_count: int = maxi(
		enemy_data.waiting_slot_count,
		waiting_enemies.size()
	)


	var waiting_angle_offset: float = (
		PI
		/ float(
			safe_waiting_slot_count
		)
	)


	var waiting_assignments: Dictionary = (
		_build_slot_assignments(
			waiting_enemies,
			enemy_data.waiting_slot_radius,
			safe_waiting_slot_count,
			waiting_angle_offset
		)
	)


	var my_waiting_id: int = (
		get_instance_id()
	)


	if waiting_assignments.has(
		my_waiting_id
	):

		result["position"] = (
			waiting_assignments[
				my_waiting_id
			]
		)


	return result


# =========================================================
# ASIGNACIÓN DINÁMICA DE SLOTS
# =========================================================

func _build_slot_assignments(
	enemies: Array[Node],
	radius: float,
	slot_count: int,
	angle_offset: float
) -> Dictionary:

	var assignments: Dictionary = {}


	if not is_instance_valid(
		player
	):

		return assignments


	if enemies.is_empty():

		return assignments


	slot_count = maxi(
		slot_count,
		enemies.size()
	)


	var available_slots: Array[int] = []


	for slot_index: int in range(
		slot_count
	):

		available_slots.append(
			slot_index
		)


	for enemy: Node in enemies:

		if not is_instance_valid(
			enemy
		):

			continue


		if not enemy is Node2D:

			continue


		if available_slots.is_empty():

			break


		var enemy_2d: Node2D = (
			enemy as Node2D
		)


		var approach_direction: Vector2 = (
			enemy_2d.global_position
			- player.global_position
		)


		if approach_direction.length_squared() < 0.001:

			approach_direction = (
				Vector2.RIGHT
			)

		else:

			approach_direction = (
				approach_direction.normalized()
			)


		var best_slot: int = (
			available_slots[0]
		)


		var best_score: float = (
			-INF
		)


		for slot_index: int in available_slots:

			var angle: float = (
				angle_offset
				+ TAU
				* float(
					slot_index
				)
				/ float(
					slot_count
				)
			)


			var slot_direction: Vector2 = (
				Vector2.RIGHT.rotated(
					angle
				)
			)


			var score: float = (
				approach_direction.dot(
					slot_direction
				)
			)


			if score > best_score:

				best_score = (
					score
				)

				best_slot = (
					slot_index
				)


		var chosen_angle: float = (
			angle_offset
				+ TAU
				* float(
					best_slot
				)
				/ float(
					slot_count
				)
		)


		var chosen_direction: Vector2 = (
			Vector2.RIGHT.rotated(
				chosen_angle
			)
		)


		var chosen_position: Vector2 = (
			player.global_position
			+ chosen_direction
			* radius
		)


		assignments[
			enemy.get_instance_id()
		] = chosen_position


		available_slots.erase(
			best_slot
		)


	return assignments


# =========================================================
# ENEMIGOS ACTIVOS
# =========================================================

func _get_active_enemies() -> Array[Node]:

	var all_enemies: Array[Node] = (
		get_tree().get_nodes_in_group(
			"enemies"
		)
	)


	var active_enemies: Array[Node] = []


	for enemy: Node in all_enemies:

		if not is_instance_valid(
			enemy
		):

			continue


		if not enemy is Node2D:

			continue


		if enemy.has_method(
			"is_combat_active"
		):

			if not enemy.is_combat_active():

				continue

		elif enemy.has_method(
			"is_enemy_alive"
		):

			if not enemy.is_enemy_alive():

				continue


		active_enemies.append(
			enemy
		)


	return active_enemies


# =========================================================
# ¿ESTÁ ACTIVO EN COMBATE?
# =========================================================

func is_combat_active() -> bool:

	if health <= 0:

		return false


	if enemy_data == null:

		return false


	if not is_instance_valid(
		player
	):

		return false


	return (
		global_position.distance_to(
			player.global_position
		)
		<= enemy_data.detection_range
	)


# =========================================================
# ORDENAR POR DISTANCIA
# =========================================================

func _sort_enemies_by_distance_to_player(
	a: Node,
	b: Node
) -> bool:

	if not is_instance_valid(
		player
	):

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


	if absf(
		distance_a
		- distance_b
	) < 1.0:

		return (
			a.get_instance_id()
			<
			b.get_instance_id()
		)


	return (
		distance_a
		<
		distance_b
	)


# =========================================================
# ¿VIVO?
# =========================================================

func is_enemy_alive() -> bool:

	return health > 0


# =========================================================
# AVOIDANCE CALLBACK
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


	if not is_instance_valid(
		player
	):

		return


	if player.has_method(
		"is_alive"
	):

		if not player.is_alive():

			return


	velocity = (
		safe_velocity
	)


	move_and_slide()


# =========================================================
# DETENER
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

	if not is_instance_valid(
		player
	):

		return


	if primary_attack == null:

		return


	if player.has_method(
		"is_alive"
	):

		if not player.is_alive():

			return


	_face_player()

	_update_attack_hitbox()


	# -----------------------------------------------------
	# SEGURIDAD:
	# SOLO HAY DAÑO SI LA HITBOX SIGUE TOCANDO AL PLAYER
	# -----------------------------------------------------

	if not _attack_hitbox_reaches_player():

		return


	attack_cooldown_left = (
		primary_attack.cooldown
	)


	print(
		"=============================="
	)

	print(
		enemy_data.enemy_name,
		" USA ",
		primary_attack.attack_name
	)

	print(
		"DISTANCIA ENTRE ORIGINS: ",
		global_position.distance_to(
			player.global_position
		)
	)

	print(
		"=============================="
	)


	_attack_flash()


	if player.has_method(
		"take_damage"
	):

		player.take_damage(
			primary_attack.damage,
			global_position,
			primary_attack.knockback_force
		)


# =========================================================
# FLASH ATAQUE
# =========================================================

func _attack_flash() -> void:

	if enemy_animated == null:

		return


	enemy_animated.modulate = Color(
		1.0,
		0.55,
		0.15,
		1.0
	)


	var tween: Tween = (
		create_tween()
	)


	tween.tween_property(
		enemy_animated,
		"modulate",
		Color.WHITE,
		0.12
	)


# =========================================================
# RECIBIR DAÑO
# =========================================================

func take_damage(
	amount: int,
	attacker_position: Vector2,
	received_knockback: float = -1.0
) -> void:

	if health <= 0:

		return


	health -= amount

	health = maxi(
		health,
		0
	)


	_update_health_bar()


	print(
		enemy_data.enemy_name,
		" RECIBE ",
		amount,
		" DE DAÑO | HP: ",
		health,
		" / ",
		enemy_data.max_health
	)


	_show_damage_number(
		amount
	)


	_flash_damage()


	if health <= 0:

		die()

		return


	_apply_knockback(
		attacker_position,
		received_knockback
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
		str(
			amount
		)
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
# FLASH DAÑO
# =========================================================

func _flash_damage() -> void:

	if enemy_animated == null:

		return


	enemy_animated.modulate = Color(
		1.0,
		0.15,
		0.15,
		1.0
	)


	var tween: Tween = (
		create_tween()
	)


	tween.tween_property(
		enemy_animated,
		"modulate",
		Color.WHITE,
		0.15
	)


# =========================================================
# KNOCKBACK
# =========================================================

func _apply_knockback(
	attacker_position: Vector2,
	received_knockback: float = -1.0
) -> void:

	var direction: Vector2 = (
		global_position
		- attacker_position
	)


	if direction.length_squared() < 0.001:

		direction = (
			Vector2.DOWN
		)

	else:

		direction = (
			direction.normalized()
		)


	# -----------------------------------------------------
	# FUERZA BASE
	# -----------------------------------------------------

	var final_knockback: float = (
		enemy_data.knockback_force
	)


	# Si el ataque especificó una fuerza,
	# usamos esa.
	if received_knockback >= 0.0:

		final_knockback = (
			received_knockback
		)


	# -----------------------------------------------------
	# RESISTENCIA DEL ENEMIGO
	# -----------------------------------------------------

	var resistance: float = clampf(
		enemy_data.knockback_resistance,
		0.0,
		1.0
	)


	final_knockback *= (
		1.0
		- resistance
	)


	knockback_velocity = (
		direction
		* final_knockback
	)


# =========================================================
# MUERTE
# =========================================================

func die() -> void:

	print(
		enemy_data.enemy_name,
		" DERROTADO"
	)


	wants_navigation_movement = false


	if health_bar != null:

		health_bar.visible = false


	if navigation_agent != null:

		navigation_agent.avoidance_enabled = false

		navigation_agent.velocity = (
			Vector2.ZERO
		)


	velocity = Vector2.ZERO

	knockback_velocity = (
		Vector2.ZERO
	)


	queue_free()


# =========================================================
# DEBUG VISUAL
# =========================================================

func _draw() -> void:

	if not debug_combat:

		return


	if primary_attack == null:

		return


	if not is_instance_valid(
		player
	):

		return


	var player_local: Vector2 = (
		to_local(
			player.global_position
		)
	)


	var slot_local: Vector2 = (
		to_local(
			debug_combat_position
		)
	)


	# -----------------------------------------------------
	# SLOT
	# -----------------------------------------------------

	draw_line(
		Vector2.ZERO,
		slot_local,
		Color(
			0.0,
			0.8,
			1.0,
			0.65
		),
		2.0
	)


	draw_circle(
		slot_local,
		6.0,
		Color(
			0.0,
			0.8,
			1.0,
			1.0
		),
		true
	)


	# -----------------------------------------------------
	# ESTADO
	# -----------------------------------------------------

	var state_color: Color


	if debug_can_attack:

		if debug_hitbox_reaches_player:

			state_color = Color(
				0.1,
				1.0,
				0.1,
				1.0
			)

		else:

			state_color = Color(
				1.0,
				0.1,
				0.1,
				1.0
			)

	else:

		state_color = Color(
			1.0,
			0.5,
			0.0,
			1.0
		)


	draw_line(
		Vector2.ZERO,
		player_local,
		state_color,
		3.0
	)


	draw_circle(
		player_local,
		5.0,
		state_color,
		true
	)


	_draw_attack_hitbox(
		state_color
	)


# =========================================================
# DEBUG HITBOX
# =========================================================

func _draw_attack_hitbox(
	outline_color: Color
) -> void:

	if attack_area == null:

		return


	if primary_attack == null:

		return


	var half_size: Vector2 = Vector2(
		primary_attack.hitbox_length
		* 0.5,

		primary_attack.hitbox_width
		* 0.5
	)


	var hitbox_transform: Transform2D = (
		Transform2D(
			attack_area.rotation,
			attack_area.position
		)
	)


	var top_left: Vector2 = (
		hitbox_transform
		* Vector2(
			-half_size.x,
			-half_size.y
		)
	)


	var top_right: Vector2 = (
		hitbox_transform
		* Vector2(
			half_size.x,
			-half_size.y
		)
	)


	var bottom_right: Vector2 = (
		hitbox_transform
		* Vector2(
			half_size.x,
			half_size.y
		)
	)


	var bottom_left: Vector2 = (
		hitbox_transform
		* Vector2(
			-half_size.x,
			half_size.y
		)
	)


	var fill_color: Color = (
		outline_color
	)

	fill_color.a = 0.12


	var polygon: PackedVector2Array = (
		PackedVector2Array(
			[
				top_left,
				top_right,
				bottom_right,
				bottom_left
			]
		)
	)


	draw_colored_polygon(
		polygon,
		fill_color
	)


	var outline: PackedVector2Array = (
		PackedVector2Array(
			[
				top_left,
				top_right,
				bottom_right,
				bottom_left,
				top_left
			]
		)
	)


	draw_polyline(
		outline,
		outline_color,
		2.0,
		true
	)
