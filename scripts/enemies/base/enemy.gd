class_name Enemy
extends CharacterBody2D


signal defeated(enemy: Enemy)


const SpriteSheetAnimationBuilder = preload(
	"res://scripts/animation/sprite_sheet_animation.gd"
)

const GOBLIN_WALK_SHEET: Texture2D = preload(
	"res://assets/characters/enemies/goblin/sprites/actions/goblin_walk_cardinal.png"
)

const GOBLIN_ATTACK_SHEET: Texture2D = preload(
	"res://assets/characters/enemies/goblin/sprites/actions/goblin_attack_cardinal.png"
)

const COVER_ARRIVAL_TOLERANCE: float = 12.0


# =========================================================
# RECURSOS
# =========================================================

@export_category("Datos")

@export var enemy_data: EnemyData

@export var primary_attack: AttackData

@export var heavy_attack: AttackData

@export var charged_attack: AttackData

@export var interrupt_attack: AttackData

@export var ai_profile: EnemyAIProfile


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

@export var debug_ai_scores: bool = true


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

var attack_hitbox_shape: RectangleShape2D = null


# =========================================================
# ESTADO GENERAL
# =========================================================

var last_facing: String = "s"

var last_cardinal_facing: String = "s"

var health: int = 0

var player: CharacterBody2D = null

var wants_navigation_movement: bool = false

var loot_random: RandomNumberGenerator = RandomNumberGenerator.new()

var is_dying: bool = false


# =========================================================
# STAMINA
# =========================================================

var stamina: float = 0.0

var stamina_regen_delay_left: float = 0.0


# =========================================================
# ATAQUE
# =========================================================

var attack_cooldown_left: float = 0.0

var current_attack: AttackData = null

var current_attack_phase: String = ""

var current_attack_phase_time_left: float = 0.0

var locked_attack_direction: Vector2 = Vector2.DOWN


# =========================================================
# KNOCKBACK / STAGGER
# =========================================================

var knockback_velocity: Vector2 = Vector2.ZERO

var stagger_recovery_time_left: float = 0.0


# =========================================================
# DEBUG
# =========================================================

var debug_combat_position: Vector2 = Vector2.ZERO

var debug_can_attack: bool = false

var debug_hitbox_reaches_player: bool = false

var debug_distance_to_player: float = 0.0

var debug_ai_label: Label = null


# =========================================================
# INTELIGENCIA DE COMBATE
# =========================================================

var perception: EnemyPerception = null

var utility_brain: EnemyUtilityBrain = null

var squad_coordinator: EnemySquadCoordinator = null

var tactical_positioning: EnemyTacticalPositioning = null

var ai_role: StringName = &"support"

var ai_action: StringName = &"hold"

var ai_target_position: Vector2 = Vector2.ZERO

var ai_can_attack: bool = false

var ai_cover_candidate: Dictionary = {}

var ai_reserved_cover: EnemyCoverPoint = null

var ai_is_holding_cover: bool = false

var ai_cover_hold_time_left: float = 0.0

var ai_cover_reentry_cooldown_left: float = 0.0

var ai_dash_direction: Vector2 = Vector2.ZERO

var ai_dash_time_left: float = 0.0

var ai_dash_cooldown_left: float = 0.0

var ai_reactive_cancel_cooldown_left: float = 0.0

var ai_random: RandomNumberGenerator = RandomNumberGenerator.new()


# =========================================================
# READY
# =========================================================

func _ready() -> void:

	loot_random.randomize()

	if not _validate_required_nodes():

		set_physics_process(false)

		return


	_ensure_resources()

	_setup_combat_intelligence()


	health = maxi(
		enemy_data.max_health,
		1
	)


	stamina = maxf(
		enemy_data.max_stamina,
		1.0
	)


	add_to_group(
		"enemies"
	)


	collision_layer = (
		body_collision_layer
	)

	collision_mask = (
		body_collision_mask
	)


	_update_health_bar()

	_find_player()

	_setup_attack_area()

	_setup_navigation_avoidance()
	_setup_action_animations()

	_play_idle()

	_update_ai_debug_label()


	print(
		"ENEMIGO CREADO | ",
		enemy_data.enemy_name,
		" | HP: ",
		health,
		" | Stamina interna: ",
		stamina
	)


# =========================================================
# VALIDAR NODOS
# =========================================================

func _validate_required_nodes() -> bool:

	var valid: bool = true


	if enemy_animated == null:

		push_error(
			name
			+ ": falta EnemyAnimated."
		)

		valid = false


	if health_bar == null:

		push_error(
			name
			+ ": falta HealthBar."
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
# RECURSOS
# =========================================================

func _ensure_resources() -> void:

	if enemy_data == null:

		push_warning(
			name
			+ " no tiene EnemyData. Se usarán valores por defecto."
		)

		enemy_data = EnemyData.new()


	if primary_attack == null:

		push_warning(
			enemy_data.enemy_name
			+ " no tiene Primary Attack. "
			+ "Se utilizará uno por defecto."
		)

		primary_attack = AttackData.new()


# =========================================================
# CONFIGURAR INTELIGENCIA DE COMBATE
# =========================================================

func _setup_combat_intelligence() -> void:

	if ai_profile == null:

		ai_profile = EnemyAIProfile.new()


	perception = EnemyPerception.new()
	perception.configure(
		self,
		player,
		ai_profile,
		int(get_instance_id() % 1000000)
	)


	utility_brain = EnemyUtilityBrain.new()
	utility_brain.configure(ai_profile, int(get_instance_id() % 1000000))


	squad_coordinator = EnemySquadCoordinator.new()
	tactical_positioning = EnemyTacticalPositioning.new()
	tactical_positioning.configure(ai_profile, int(get_instance_id() % 1000000))
	if ai_profile.deterministic_seed > 0:
		ai_random.seed = ai_profile.deterministic_seed + int(get_instance_id() % 1000000) * 3571
	else:
		ai_random.randomize()


	if debug_combat:

		debug_ai_label = Label.new()
		debug_ai_label.name = "AIDebugLabel"
		debug_ai_label.position = Vector2(-95.0, -112.0)
		debug_ai_label.custom_minimum_size = Vector2(190.0, 72.0)
		debug_ai_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		debug_ai_label.add_theme_font_size_override("font_size", 11)
		debug_ai_label.add_theme_color_override("font_color", Color.WHITE)
		debug_ai_label.add_theme_color_override("font_outline_color", Color.BLACK)
		debug_ai_label.add_theme_constant_override("outline_size", 4)
		debug_ai_label.z_index = 100
		add_child(debug_ai_label)


# =========================================================
# BARRA DE VIDA
# =========================================================

func _update_health_bar() -> void:

	if health_bar == null:

		return


	var maximum_health: int = maxi(
		enemy_data.max_health,
		1
	)


	health_bar.min_value = 0

	health_bar.max_value = maximum_health

	health_bar.value = health

	health_bar.show_percentage = false


	health_bar.visible = (
		health > 0
		and
		health < maximum_health
	)


# =========================================================
# PLAYER
# =========================================================

func _find_player() -> void:

	player = (
		get_tree().get_first_node_in_group(
			"player"
		)
		as CharacterBody2D
	)


	if player == null:

		push_warning(
			enemy_data.enemy_name
			+ ": no se encontró Player."
		)


# =========================================================
# AVOIDANCE
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

	navigation_agent.time_horizon_obstacles = (
		enemy_data.avoidance_time_horizon_obstacles
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
# ATTACK AREA
# =========================================================

func _setup_attack_area() -> void:

	var existing_area: Node = (
		get_node_or_null(
			"AttackArea"
		)
	)


	if existing_area is Area2D:

		attack_area = (
			existing_area
			as Area2D
		)

	else:

		attack_area = Area2D.new()

		attack_area.name = "AttackArea"

		add_child(
			attack_area
		)


	attack_area.collision_layer = 0

	attack_area.collision_mask = 0

	attack_area.monitoring = false

	attack_area.monitorable = false


	var existing_collision: Node = (
		attack_area.get_node_or_null(
			"AttackCollision"
		)
	)


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

		attack_collision.name = "AttackCollision"

		attack_area.add_child(
			attack_collision
		)


	attack_collision.position = Vector2.ZERO

	attack_collision.rotation = 0.0


	if attack_collision.shape is RectangleShape2D:

		attack_hitbox_shape = (
			attack_collision.shape.duplicate()
			as RectangleShape2D
		)

	else:

		attack_hitbox_shape = (
			RectangleShape2D.new()
		)


	attack_collision.shape = (
		attack_hitbox_shape
	)


	_update_attack_hitbox(
		primary_attack
	)


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(
	delta: float
) -> void:

	_update_attack_cooldown(
		delta
	)

	_update_stamina(
		delta
	)

	_update_ai_mobility_timers(delta)


	if not is_instance_valid(player):

		_find_player()


	_update_combat_perception(delta)


	if utility_brain != null:

		utility_brain.update_timers(delta)


	# =====================================================
	# KNOCKBACK
	# =====================================================

	if knockback_velocity != Vector2.ZERO:

		_process_knockback(
			delta
		)

		return


	# =====================================================
	# STAGGER
	# =====================================================

	if stagger_recovery_time_left > 0.0:

		_process_stagger_recovery(
			delta
		)

		return


	# =====================================================
	# DASH TÁCTICO EN PROGRESO
	# =====================================================

	if ai_dash_time_left > 0.0:

		_process_ai_dash(delta)

		return


	# =====================================================
	# ATAQUE EN PROGRESO
	# =====================================================

	if current_attack != null:

		if _try_reactive_attack_cancel():

			return

		_process_current_attack(
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


	if player.has_method(
		"is_alive"
	):

		if not player.is_alive():

			_stop_navigation()

			return


	# =====================================================
	# CONCIENCIA / MEMORIA
	# =====================================================

	debug_distance_to_player = global_position.distance_to(
		perception.get_estimated_target_position(false)
	)


	# Una vez alcanzada, la cobertura es un compromiso espacial real. No se
	# abandona solo porque el obstáculo corte el LOS que justamente debía cortar.
	if ai_is_holding_cover:

		ai_action = &"cover"
		_execute_cover_hold_intention()
		_update_ai_debug_label()


		if debug_combat:

			queue_redraw()


		return


	if perception == null or not perception.is_aware:

		debug_can_attack = false
		debug_hitbox_reaches_player = false
		ai_role = &"unaware"
		ai_action = &"idle"
		_stop_navigation()
		_update_ai_debug_label()


		if debug_combat:

			queue_redraw()


		return


	_update_tactical_assignment()
	_reconsider_ai_action()
	_execute_ai_action()
	_update_ai_debug_label()


	if debug_combat:

		queue_redraw()


# =========================================================
# PERCEPCIÓN Y MEMORIA
# =========================================================

func _update_combat_perception(delta: float) -> void:

	if perception == null:

		return


	perception.set_target(player)
	perception.update(
		delta,
		_get_perception_facing_direction()
	)


func _get_perception_facing_direction() -> Vector2:

	if velocity.length_squared() > 0.001:

		return velocity.normalized()


	match last_facing:

		"n":
			return Vector2.UP

		"ne":
			return Vector2(1.0, -1.0).normalized()

		"e":
			return Vector2.RIGHT

		"se":
			return Vector2(1.0, 1.0).normalized()

		"sw":
			return Vector2(-1.0, 1.0).normalized()

		"w":
			return Vector2.LEFT

		"nw":
			return Vector2(-1.0, -1.0).normalized()


	return Vector2.DOWN


# =========================================================
# COORDINACIÓN TÁCTICA
# =========================================================

func _update_tactical_assignment() -> void:
	var estimated_target := perception.get_estimated_target_position(true)
	if not perception.has_confirmed_visual_contact:
		var can_search := ai_profile.is_capability_enabled(EnemyAIProfile.CAP_SEARCH)
		ai_role = &"search" if can_search else &"waiting"
		ai_target_position = estimated_target if can_search else global_position
		ai_can_attack = false
		debug_combat_position = ai_target_position
		debug_can_attack = false
		return

	var active_enemies: Array[Node] = EnemySquadCoordinator.get_active_enemies(
		get_tree()
	)


	if not active_enemies.has(self):

		active_enemies.append(self)


	var assignment: Dictionary = squad_coordinator.get_assignment(
		self,
		active_enemies,
		estimated_target,
		enemy_data,
		ai_profile
	)


	ai_role = StringName(assignment.get("role", &"support"))
	ai_target_position = Vector2(
		assignment.get("position", estimated_target)
	)
	ai_can_attack = bool(assignment.get("can_attack", false))

	debug_combat_position = ai_target_position
	debug_can_attack = ai_can_attack


# =========================================================
# DECISIÓN POR UTILIDAD
# =========================================================

func _reconsider_ai_action() -> void:
	var reachable_attacks: Array[AttackData] = _get_reachable_attacks()
	debug_hitbox_reaches_player = not reachable_attacks.is_empty()
	var observed := perception.get_observed_combat_state()
	var target_action := StringName(observed.get("action", &"none"))
	var target_phase := StringName(observed.get("phase", &"none"))
	var recognized_danger := (
		perception.has_confirmed_visual_contact
		and profile_can_read_telegraphs()
		and target_action in [&"charge", &"attack"]
		and target_phase == &"telegraph"
	)
	var force_reconsideration: bool = (
		(ai_action == &"attack" and not ai_can_attack)
		or
		(ai_action == &"search" and perception.has_confirmed_visual_contact)
		or
		(recognized_danger and ai_action not in [&"dodge", &"interrupt", &"retreat"])
	)
	if not utility_brain.should_reconsider(force_reconsideration):
		return
	var maximum_health := maxf(float(enemy_data.max_health), 1.0)
	var maximum_stamina := maxf(enemy_data.max_stamina, 1.0)
	var estimated_target := perception.get_estimated_target_position(true)
	var target_facing := Vector2(observed.get("facing", Vector2.ZERO))
	var direction_to_enemy := global_position - estimated_target
	var target_facing_me := (
		target_facing.length_squared() > 0.001
		and direction_to_enemy.length_squared() > 0.001
		and target_facing.normalized().dot(direction_to_enemy.normalized()) > 0.38
	)
	ai_cover_candidate.clear()
	if (
		ai_cover_reentry_cooldown_left <= 0.0
		and perception.has_confirmed_visual_contact
		and ai_profile.is_capability_enabled(EnemyAIProfile.CAP_COVER)
	):
		ai_cover_candidate = tactical_positioning.find_best_cover(self, estimated_target, ai_profile)
	var context: Dictionary = {
		"visible": perception.has_confirmed_visual_contact,
		"aware": perception.is_aware,
		"can_attack": ai_can_attack,
		"attack_reaches": not reachable_attacks.is_empty(),
		"cooldown_ready": attack_cooldown_left <= 0.0,
		"health_ratio": float(health) / maximum_health,
		"stamina_ratio": stamina / maximum_stamina,
		"distance": debug_distance_to_player,
		"role": ai_role,
		"target_action": target_action,
		"target_phase": target_phase,
		"target_facing_me": target_facing_me,
		"inside_target_threat": debug_distance_to_player <= maxf(ai_profile.preferred_distance + ai_profile.danger_padding, 90.0),
		"cover_available": not ai_cover_candidate.is_empty(),
		"dash_ready": _can_ai_dash(),
		"interrupt_reaches": _can_land_interrupt_attack()
	}
	var previous_action := ai_action
	ai_action = utility_brain.decide(context)
	if previous_action == &"cover" and ai_action != &"cover":
		_release_reserved_cover()
	if ai_action == &"cover" and not ai_cover_candidate.is_empty():
		var next_cover := ai_cover_candidate.get("point") as EnemyCoverPoint
		if ai_reserved_cover != next_cover:
			_release_reserved_cover()
		if next_cover != null:
			var travel_time := global_position.distance_to(next_cover.global_position) / maxf(enemy_data.move_speed, 1.0)
			var reservation_duration := (
				travel_time
				+ ai_profile.cover_hold_duration
				+ ai_profile.maximum_commitment
				+ 0.25
			)
			if next_cover.reserve(self, reservation_duration):
				ai_reserved_cover = next_cover
			else:
				ai_cover_candidate.clear()
				ai_action = &"hold"
				utility_brain.interrupt_commitment()


# =========================================================
# EJECUTAR INTENCIÓN
# =========================================================

func _execute_ai_action() -> void:

	match ai_action:

		&"attack":
			_execute_attack_intention()

		&"approach", &"flank":
			_move_or_hold(ai_target_position, 10.0)

		&"hold":
			_move_or_hold(ai_target_position, 16.0)
			_face_player()

		&"retreat":
			_move_or_hold(_get_retreat_position(), 12.0)

		&"search":
			_move_or_hold(perception.get_estimated_target_position(false), 12.0)

		&"circle":
			_execute_circle_intention()

		&"cover":
			_execute_cover_intention()

		&"dodge":
			_execute_dodge_intention()

		&"interrupt":
			_execute_interrupt_intention()

		_:
			_stop_navigation()


func _execute_circle_intention() -> void:
	var target_position := perception.get_estimated_target_position(true)
	var circle_position := tactical_positioning.get_circle_position(self, target_position, ai_profile)
	_move_or_hold(circle_position, 10.0)


func _execute_cover_intention() -> void:
	if ai_cover_candidate.is_empty():
		_move_or_hold(_get_retreat_position(), 14.0)
		return
	var cover_position := Vector2(ai_cover_candidate.get("position", global_position))
	if global_position.distance_to(cover_position) <= COVER_ARRIVAL_TOLERANCE:
		_begin_cover_hold()
		return
	_move_or_hold(cover_position, COVER_ARRIVAL_TOLERANCE)


func _begin_cover_hold() -> void:
	var cover_point := ai_cover_candidate.get("point") as EnemyCoverPoint
	if not is_instance_valid(cover_point):
		_release_reserved_cover()
		ai_cover_candidate.clear()
		return
	if ai_reserved_cover != cover_point:
		_release_reserved_cover()
	if not cover_point.reserve(self, maxf(ai_profile.cover_hold_duration, 0.1)):
		ai_cover_candidate.clear()
		ai_action = &"hold"
		utility_brain.interrupt_commitment()
		return
	ai_reserved_cover = cover_point
	ai_is_holding_cover = true
	ai_cover_hold_time_left = maxf(ai_profile.cover_hold_duration, 0.0)
	_stop_navigation()
	if ai_cover_hold_time_left <= 0.0:
		_finish_cover_hold()


func _execute_cover_hold_intention() -> void:
	if not is_instance_valid(ai_reserved_cover):
		_finish_cover_hold()
		_stop_navigation()
		return
	var cover_position := ai_reserved_cover.global_position
	_move_or_hold(cover_position, COVER_ARRIVAL_TOLERANCE)
	if global_position.distance_to(cover_position) <= COVER_ARRIVAL_TOLERANCE:
		_face_player()


func _finish_cover_hold() -> void:
	ai_is_holding_cover = false
	ai_cover_hold_time_left = 0.0
	ai_cover_reentry_cooldown_left = maxf(
		ai_cover_reentry_cooldown_left,
		_get_cover_reentry_delay()
	)
	_release_reserved_cover()
	ai_cover_candidate.clear()
	if ai_action == &"cover":
		ai_action = &"hold"
	if utility_brain != null:
		utility_brain.interrupt_commitment()


func _get_cover_reentry_delay() -> float:
	if ai_profile == null:
		return 0.35
	return maxf(
		maxf(0.35, ai_profile.maximum_commitment),
		ai_profile.get_effective_decision_interval() * 2.0
	)


func _execute_dodge_intention() -> void:
	var observed := perception.get_observed_combat_state()
	var target_position := perception.get_estimated_target_position(false)
	var target_facing := Vector2(observed.get("facing", Vector2.ZERO))
	var dodge_direction := tactical_positioning.get_dodge_direction(self, target_position, target_facing)
	if _can_ai_dash() and _start_ai_dash(dodge_direction):
		return
	_move_or_hold(global_position + dodge_direction * maxf(ai_profile.retreat_distance * 0.55, 75.0), 8.0)


func _execute_interrupt_intention() -> void:
	if perception == null:
		_stop_navigation()
		return
	if not perception.has_confirmed_visual_contact:
		ai_action = &"search"
		utility_brain.interrupt_commitment()
		_move_or_hold(perception.get_estimated_target_position(false), 12.0)
		return
	_face_player()
	if _can_land_interrupt_attack():
		_stop_navigation()
		_start_attack(interrupt_attack)
		return
	_move_or_hold(perception.get_estimated_target_position(true), 8.0)


func _can_land_interrupt_attack() -> bool:
	if interrupt_attack == null or perception == null or not perception.has_confirmed_visual_contact:
		return false
	if attack_cooldown_left > 0.0 or current_attack != null:
		return false
	if not _can_afford_attack(interrupt_attack):
		return false
	return _attack_reaches_estimated_target(interrupt_attack, _get_attack_direction())


func _execute_attack_intention() -> void:
	if perception == null:
		_stop_navigation()
		return
	if not perception.has_confirmed_visual_contact:
		ai_action = &"search"
		utility_brain.interrupt_commitment()
		_move_or_hold(perception.get_estimated_target_position(false), 12.0)
		return

	_face_player()


	var reachable_attacks: Array[AttackData] = (
		_get_reachable_attacks()
	)


	debug_hitbox_reaches_player = not reachable_attacks.is_empty()


	if reachable_attacks.is_empty():

		_move_or_hold(ai_target_position, 8.0)
		return


	_stop_navigation()


	if attack_cooldown_left > 0.0:

		return


	var selected_attack: AttackData = _choose_attack(
		reachable_attacks
	)


	if selected_attack != null:

		_start_attack(selected_attack)


func _move_or_hold(target_position: Vector2, tolerance: float) -> void:

	if global_position.distance_to(target_position) <= tolerance:

		_stop_navigation()
		return


	_move_toward_position(target_position)


func _get_retreat_position() -> Vector2:

	var danger_position: Vector2 = perception.get_estimated_target_position(true)


	var away_direction: Vector2 = global_position - danger_position


	if away_direction.length_squared() < 0.001:

		away_direction = Vector2.DOWN


	return (
		global_position
		+ away_direction.normalized()
		* ai_profile.retreat_distance
	)


# =========================================================
# DEBUG DE IA
# =========================================================

func _update_ai_debug_label() -> void:

	if debug_ai_label == null:

		return


	var awareness: String = "MEM"


	if perception != null and perception.has_confirmed_visual_contact:

		awareness = "VISION"

	elif perception != null and perception.heard_target:

		awareness = "OIDO"

	elif perception == null or not perception.is_aware:

		awareness = "CALMA"


	debug_ai_label.text = (
		String(ai_role).to_upper()
		+ " | "
		+ String(ai_action).to_upper()
		+ " | "
		+ awareness
		+ "\nIQ "
		+ str(roundi(ai_profile.intelligence_percent))
		+ "% | CONF "
		+ str(roundi(utility_brain.last_decision_confidence * 100.0))
		+ "% | OBS "
		+ str(roundi(perception.observation_confidence * 100.0))
		+ "%"
		+ (" | ERROR" if utility_brain.last_was_mistake else "")
	)


	if debug_ai_scores and utility_brain != null:

		var score_parts: PackedStringArray = []


		for action_variant: Variant in utility_brain.last_scores:

			score_parts.append(
				String(action_variant).substr(0, 3)
				+ ":"
				+ str(snappedf(
					float(utility_brain.last_scores[action_variant]),
					0.01
				))
			)


		if not score_parts.is_empty():

			debug_ai_label.text += "\n" + " ".join(score_parts)


# =========================================================
# MOVILIDAD Y REACCIONES TÁCTICAS
# =========================================================

func profile_can_read_telegraphs() -> bool:
	return ai_profile != null and ai_profile.is_capability_enabled(EnemyAIProfile.CAP_READ_TELEGRAPHS)


func _update_ai_mobility_timers(delta: float) -> void:
	ai_dash_cooldown_left = maxf(ai_dash_cooldown_left - delta, 0.0)
	ai_reactive_cancel_cooldown_left = maxf(ai_reactive_cancel_cooldown_left - delta, 0.0)
	ai_cover_reentry_cooldown_left = maxf(ai_cover_reentry_cooldown_left - delta, 0.0)
	if ai_is_holding_cover and not is_instance_valid(ai_reserved_cover):
		_finish_cover_hold()
	elif (
		ai_is_holding_cover
		and knockback_velocity == Vector2.ZERO
		and stagger_recovery_time_left <= 0.0
		and global_position.distance_to(ai_reserved_cover.global_position)
		<= COVER_ARRIVAL_TOLERANCE
	):
		ai_cover_hold_time_left = maxf(ai_cover_hold_time_left - delta, 0.0)
		if ai_cover_hold_time_left <= 0.0:
			_finish_cover_hold()


func _can_ai_dash() -> bool:
	if enemy_data == null or ai_profile == null:
		return false
	if not enemy_data.can_dash or not ai_profile.is_capability_enabled(EnemyAIProfile.CAP_DASH):
		return false
	if ai_dash_cooldown_left > 0.0 or ai_dash_time_left > 0.0 or current_attack != null:
		return false
	return not enemy_data.uses_stamina or stamina >= enemy_data.dash_stamina_cost


func _start_ai_dash(desired_direction: Vector2) -> bool:
	if not _can_ai_dash() or desired_direction.length_squared() < 0.001:
		return false
	var base_direction := desired_direction.normalized()
	var candidates: Array[Vector2] = [
		base_direction,
		base_direction.rotated(PI * 0.25),
		base_direction.rotated(-PI * 0.25),
		base_direction.rotated(PI * 0.5),
		base_direction.rotated(-PI * 0.5)
	]
	var dash_distance := enemy_data.dash_speed * enemy_data.dash_duration
	var selected := Vector2.ZERO
	for candidate: Vector2 in candidates:
		if _is_ai_dash_path_safe(candidate, dash_distance):
			selected = candidate
			break
	if selected == Vector2.ZERO:
		return false
	_stop_navigation()
	ai_dash_direction = selected
	ai_dash_time_left = enemy_data.dash_duration
	ai_dash_cooldown_left = enemy_data.dash_cooldown
	if enemy_data.uses_stamina:
		stamina = maxf(stamina - enemy_data.dash_stamina_cost, 0.0)
		stamina_regen_delay_left = enemy_data.stamina_regen_delay
	enemy_animated.self_modulate = Color(0.72, 0.9, 1.25, 1.0)
	return true


func _is_ai_dash_path_safe(direction: Vector2, distance: float) -> bool:
	var motion := direction.normalized() * distance
	if test_move(global_transform, motion):
		return false
	var destination := global_position + motion
	var navigation_map := navigation_agent.get_navigation_map()
	if navigation_map.is_valid() and not NavigationServer2D.map_get_regions(navigation_map).is_empty():
		var closest_navigation_point := NavigationServer2D.map_get_closest_point(
			navigation_map,
			destination
		)
		if closest_navigation_point.distance_to(destination) > 14.0:
			return false
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not node is Node2D:
			continue
		if node.has_method("is_enemy_alive") and not bool(node.call("is_enemy_alive")):
			continue
		var closest_on_dash := Geometry2D.get_closest_point_to_segment(
			(node as Node2D).global_position,
			global_position,
			destination
		)
		var required_spacing := enemy_data.avoidance_radius * 1.7
		var other_data := node.get("enemy_data") as EnemyData
		if other_data != null:
			required_spacing += other_data.avoidance_radius * 0.65
		if closest_on_dash.distance_to((node as Node2D).global_position) < required_spacing:
			return false
	return true


func _process_ai_dash(delta: float) -> void:
	ai_dash_time_left = maxf(ai_dash_time_left - delta, 0.0)
	velocity = ai_dash_direction * enemy_data.dash_speed
	_update_facing(ai_dash_direction)
	_play_action_animation("walk")
	move_and_slide()
	if ai_dash_time_left <= 0.0:
		ai_dash_direction = Vector2.ZERO
		velocity = Vector2.ZERO
		enemy_animated.self_modulate = Color.WHITE
		utility_brain.interrupt_commitment()


func _cancel_ai_dash() -> void:
	if ai_dash_time_left <= 0.0:
		return
	ai_dash_time_left = 0.0
	ai_dash_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	if enemy_animated != null:
		enemy_animated.self_modulate = Color.WHITE
	if utility_brain != null:
		utility_brain.interrupt_commitment()


func _try_reactive_attack_cancel() -> bool:
	if not enemy_data.can_cancel_attack_windup or ai_reactive_cancel_cooldown_left > 0.0:
		return false
	if current_attack == interrupt_attack or ai_action == &"interrupt":
		return false
	if current_attack_phase != "windup" or not profile_can_read_telegraphs():
		return false
	if perception == null or not perception.has_confirmed_visual_contact:
		return false
	if not ai_profile.is_capability_enabled(EnemyAIProfile.CAP_DODGE):
		return false
	var observed := perception.get_observed_combat_state()
	if StringName(observed.get("source", &"none")) != &"vision":
		return false
	if StringName(observed.get("action", &"none")) != &"charge":
		return false
	var target_facing := Vector2(observed.get("facing", Vector2.ZERO))
	var target_to_enemy := global_position - perception.get_estimated_target_position(false)
	if (
		target_facing.length_squared() < 0.001
		or target_to_enemy.length_squared() < 0.001
		or target_facing.normalized().dot(target_to_enemy.normalized()) <= 0.38
	):
		return false
	var perceived_distance := global_position.distance_to(
		perception.get_estimated_target_position(false)
	)
	if perceived_distance > maxf(ai_profile.preferred_distance + ai_profile.danger_padding, 105.0):
		return false
	if enemy_data.uses_stamina and stamina < enemy_data.reactive_cancel_stamina_cost:
		return false
	_cancel_current_attack()
	if enemy_data.uses_stamina:
		stamina = maxf(stamina - enemy_data.reactive_cancel_stamina_cost, 0.0)
	ai_reactive_cancel_cooldown_left = enemy_data.reactive_cancel_cooldown
	utility_brain.interrupt_commitment()
	ai_action = &"dodge"
	_execute_dodge_intention()
	return true


func _release_reserved_cover() -> void:
	if is_instance_valid(ai_reserved_cover):
		ai_reserved_cover.release(self)
	ai_reserved_cover = null


# =========================================================
# COOLDOWN
# =========================================================

func _update_attack_cooldown(
	delta: float
) -> void:

	if attack_cooldown_left <= 0.0:

		return


	attack_cooldown_left = maxf(
		attack_cooldown_left
		- delta,
		0.0
	)


# =========================================================
# STAMINA
# =========================================================

func _update_stamina(
	delta: float
) -> void:

	if not enemy_data.uses_stamina:

		stamina = (
			enemy_data.max_stamina
		)

		return


	if stamina_regen_delay_left > 0.0:

		stamina_regen_delay_left = maxf(
			stamina_regen_delay_left
			- delta,
			0.0
		)

		return


	# No regenera mientras está ejecutando un ataque.
	if current_attack != null:

		return


	if stamina >= enemy_data.max_stamina:

		stamina = enemy_data.max_stamina

		return


	stamina = minf(
		enemy_data.max_stamina,
		stamina
		+ enemy_data.stamina_regen_rate
		* delta
	)


# =========================================================
# ¿PUEDE PAGAR EL ATAQUE?
# =========================================================

func _can_afford_attack(
	attack: AttackData
) -> bool:

	if attack == null:

		return false


	if not enemy_data.uses_stamina:

		return true


	return (
		stamina
		>= attack.stamina_cost
	)


# =========================================================
# GASTAR STAMINA
# =========================================================

func _spend_attack_stamina(
	attack: AttackData
) -> bool:

	if attack == null:

		return false


	if not enemy_data.uses_stamina:

		return true


	if stamina < attack.stamina_cost:

		return false


	stamina = maxf(
		stamina
		- attack.stamina_cost,
		0.0
	)


	stamina_regen_delay_left = (
		enemy_data.stamina_regen_delay
	)


	return true


# =========================================================
# ATAQUES DISPONIBLES
# =========================================================

func _get_available_attacks() -> Array[AttackData]:

	var attacks: Array[AttackData] = []


	# -----------------------------------------------------
	# PRIMARY
	# -----------------------------------------------------

	if (
		primary_attack != null
		and
		_can_afford_attack(
			primary_attack
		)
	):

		attacks.append(
			primary_attack
		)


	# -----------------------------------------------------
	# HEAVY
	# -----------------------------------------------------

	if (
		enemy_data.can_use_heavy_attacks
		and
		ai_profile.is_capability_enabled(EnemyAIProfile.CAP_HEAVY_ATTACK)
		and
		heavy_attack != null
		and
		_can_afford_attack(
			heavy_attack
		)
	):

		attacks.append(
			heavy_attack
		)


	# -----------------------------------------------------
	# CHARGED
	# -----------------------------------------------------

	if (
		enemy_data.can_use_charged_attacks
		and
		ai_profile.is_capability_enabled(EnemyAIProfile.CAP_CHARGED_ATTACK)
		and
		charged_attack != null
		and
		_can_afford_attack(
			charged_attack
		)
	):

		attacks.append(
			charged_attack
		)


	return attacks


# =========================================================
# ATAQUES QUE ALCANZAN
# =========================================================

func _get_reachable_attacks() -> Array[AttackData]:

	var reachable: Array[AttackData] = []
	if perception == null or not perception.has_confirmed_visual_contact:
		return reachable


	var attacks: Array[AttackData] = (
		_get_available_attacks()
	)


	var direction: Vector2 = (
		_get_attack_direction()
	)


	for attack: AttackData in attacks:

		if _attack_reaches_estimated_target(
			attack,
			direction
		):

			reachable.append(
				attack
			)


	return reachable


# =========================================================
# ELEGIR ATAQUE
# =========================================================

func _choose_attack(
	candidates: Array[AttackData]
) -> AttackData:

	if candidates.is_empty():

		return null


	var best_attack: AttackData = candidates[0]
	var best_score: float = -INF
	var target_is_committed: bool = false
	if ai_profile.is_capability_enabled(EnemyAIProfile.CAP_ADAPT_ATTACKS):
		var observed := perception.get_observed_combat_state()
		target_is_committed = (
			StringName(observed.get("action", &"none")) in [&"charge", &"attack"]
			or StringName(observed.get("phase", &"none")) == &"recovery"
		)


	for attack: AttackData in candidates:

		var score: float = maxf(attack.ai_weight, 0.05)
		var total_commitment: float = (
			attack.charge_time
			+ attack.windup_time
			+ attack.recovery_time
		)


		score -= total_commitment * 0.18


		match attack.attack_kind:

			AttackData.AttackKind.PRIMARY:
				score += 0.28

			AttackData.AttackKind.HEAVY:
				score += ai_profile.aggression * 0.12

			AttackData.AttackKind.CHARGED:
				score -= 0.35


				if target_is_committed:

					score += 0.8


		if enemy_data.uses_stamina:

			var remaining_stamina_ratio: float = (
				(stamina - attack.stamina_cost)
				/ maxf(enemy_data.max_stamina, 1.0)
			)
			score += clampf(
				remaining_stamina_ratio,
				0.0,
				1.0
			) * 0.2


		# Variación pequeña: evita secuencias perfectamente
		# deterministas sin destruir la intención táctica.
		var attack_noise := ai_profile.get_decision_noise() * 0.35
		score += ai_random.randf_range(-attack_noise, attack_noise)


		if score > best_score:

			best_score = score
			best_attack = attack


	return best_attack


# =========================================================
# COMENZAR ATAQUE
# =========================================================

func _start_attack(
	attack: AttackData
) -> void:

	if attack == null:

		return


	if current_attack != null:

		return


	if attack_cooldown_left > 0.0:

		return


	if not _spend_attack_stamina(
		attack
	):

		return


	current_attack = attack


	locked_attack_direction = (
		_get_attack_direction()
	)


	if locked_attack_direction == Vector2.ZERO:

		locked_attack_direction = (
			Vector2.DOWN
		)


	_update_facing(
		locked_attack_direction
	)


	_stop_navigation()


	attack_cooldown_left = maxf(
		attack.cooldown,
		0.0
	)


	# -----------------------------------------------------
	# CARGA EXTRA
	# -----------------------------------------------------

	var additional_charge_time: float = 0.0


	if (
		attack.attack_kind
		==
		AttackData.AttackKind.CHARGED
	):

		additional_charge_time = maxf(
			attack.charge_time,
			0.0
		)


	current_attack_phase = "windup"
	_play_action_animation("attack")


	current_attack_phase_time_left = maxf(
		attack.windup_time
		+ additional_charge_time,
		0.0
	)


	_apply_attack_telegraph_visual(
		attack
	)


	if debug_combat:

		print(
			enemy_data.enemy_name,
			" [",
			name,
			"]",
			" PREPARA ",
			attack.attack_name,
			" | Rol: ",
			ai_role,
			" | Stamina: ",
			stamina,
			" / ",
			enemy_data.max_stamina
		)


	if current_attack_phase_time_left <= 0.0:

		_enter_attack_active_phase()


# =========================================================
# PROCESAR ATAQUE
# =========================================================

func _process_current_attack(
	delta: float
) -> void:

	if current_attack == null:

		return


	_stop_navigation()


	current_attack_phase_time_left = maxf(
		current_attack_phase_time_left
		- delta,
		0.0
	)


	if current_attack_phase_time_left > 0.0:

		return


	match current_attack_phase:

		"windup":

			_enter_attack_active_phase()


		"active":

			_enter_attack_recovery_phase()


		"recovery":

			_finish_current_attack()


# =========================================================
# FASE ACTIVA
# =========================================================

func _enter_attack_active_phase() -> void:

	if current_attack == null:

		return


	current_attack_phase = "active"


	current_attack_phase_time_left = maxf(
		current_attack.active_time,
		0.0
	)


	_update_attack_hitbox(
		current_attack,
		locked_attack_direction
	)


	_resolve_current_attack_hit()


	_attack_flash()


	if current_attack_phase_time_left <= 0.0:

		_enter_attack_recovery_phase()


# =========================================================
# RESOLVER IMPACTO
# =========================================================

func _resolve_current_attack_hit() -> void:

	if current_attack == null:

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


	# Muy importante:
	# el enemigo NO golpea automáticamente solo porque
	# comenzó el ataque dentro del rango.
	#
	# Se comprueba otra vez cuando llega el momento real
	# del impacto.
	#
	# Por lo tanto el jugador puede esquivarlo.
	if not _attack_hitbox_reaches_player(
		current_attack,
		locked_attack_direction
	):

		if debug_combat:

			print(
				enemy_data.enemy_name,
				" FALLA ",
				current_attack.attack_name
			)


		return


	if not _has_clear_attack_line_to_player():

		if debug_combat:

			print(
				enemy_data.enemy_name,
				" FALLA ",
				current_attack.attack_name,
				" | OBSTÁCULO"
			)


		return


	print(
		"=============================="
	)

	print(
		enemy_data.enemy_name,
		" USA ",
		current_attack.attack_name
	)

	print(
		"DAÑO: ",
		current_attack.damage,
		" | KNOCKBACK: ",
		current_attack.knockback_force
	)

	print(
		"=============================="
	)


	if player.has_method(
		"take_damage"
	):

		player.take_damage(
			current_attack.damage,
			global_position,
			current_attack.knockback_force
		)


# =========================================================
# RECOVERY
# =========================================================

func _enter_attack_recovery_phase() -> void:

	if current_attack == null:

		return


	current_attack_phase = "recovery"


	current_attack_phase_time_left = maxf(
		current_attack.recovery_time,
		0.0
	)


	_reset_attack_telegraph_visual()


	if current_attack_phase_time_left <= 0.0:

		_finish_current_attack()


# =========================================================
# FINALIZAR ATAQUE
# =========================================================

func _finish_current_attack() -> void:

	_reset_attack_telegraph_visual()


	current_attack = null

	current_attack_phase = ""

	current_attack_phase_time_left = 0.0
	_play_idle()


	if debug_combat:

		queue_redraw()


# =========================================================
# CANCELAR ATAQUE
# =========================================================

func _cancel_current_attack() -> void:

	if current_attack == null:

		return


	if debug_combat:

		print(
			enemy_data.enemy_name,
			" | ATAQUE CANCELADO: ",
			current_attack.attack_name
		)


	_reset_attack_telegraph_visual()


	current_attack = null

	current_attack_phase = ""

	current_attack_phase_time_left = 0.0


# =========================================================
# TELEGRAPH VISUAL PROVISORIO
# =========================================================

func _apply_attack_telegraph_visual(
	attack: AttackData
) -> void:

	if enemy_animated == null:

		return


	match attack.attack_kind:

		AttackData.AttackKind.HEAVY:

			enemy_animated.self_modulate = Color(
				1.0,
				0.75,
				0.35,
				1.0
			)


		AttackData.AttackKind.CHARGED:

			enemy_animated.self_modulate = Color(
				1.0,
				0.40,
				0.15,
				1.0
			)


		_:

			enemy_animated.self_modulate = (
				Color.WHITE
			)


# =========================================================
# RESET TELEGRAPH
# =========================================================

func _reset_attack_telegraph_visual() -> void:

	if enemy_animated == null:

		return


	enemy_animated.self_modulate = (
		Color.WHITE
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

		knockback_velocity = Vector2.ZERO


	if debug_combat:

		queue_redraw()


# =========================================================
# STAGGER
# =========================================================

func _process_stagger_recovery(
	delta: float
) -> void:

	wants_navigation_movement = false

	velocity = Vector2.ZERO

	navigation_agent.velocity = (
		Vector2.ZERO
	)


	stagger_recovery_time_left = maxf(
		stagger_recovery_time_left
		- delta,
		0.0
	)


	debug_can_attack = false

	debug_hitbox_reaches_player = false


	if debug_combat:

		queue_redraw()


# =========================================================
# DURACIÓN STAGGER
# =========================================================

func _calculate_stagger_recovery_duration(
	effective_knockback: float
) -> float:

	var threshold: float = maxf(
		enemy_data.stagger_threshold,
		0.0
	)


	if effective_knockback <= threshold:

		return 0.0


	var min_duration: float = maxf(
		enemy_data.stagger_min_duration,
		0.0
	)


	var max_duration: float = maxf(
		enemy_data.stagger_max_duration,
		min_duration
	)


	var force_for_max: float = maxf(
		enemy_data.stagger_force_for_max_duration,
		threshold + 1.0
	)


	var strength_ratio: float = clampf(
		(
			effective_knockback
			- threshold
		)
		/
		(
			force_for_max
			- threshold
		),
		0.0,
		1.0
	)


	return lerpf(
		min_duration,
		max_duration,
		strength_ratio
	)


# =========================================================
# KNOCKBACK EFECTIVO
# =========================================================

func _get_effective_knockback(
	received_knockback: float
) -> float:

	var base_knockback: float = (
		enemy_data.knockback_force
	)


	if received_knockback >= 0.0:

		base_knockback = (
			received_knockback
		)


	var resistance: float = clampf(
		enemy_data.knockback_resistance,
		0.0,
		1.0
	)


	return maxf(
		base_knockback
		* (
			1.0
			- resistance
		),
		0.0
	)


# =========================================================
# HITBOX
# =========================================================

func _update_attack_hitbox(
	attack: AttackData = null,
	direction: Vector2 = Vector2.ZERO
) -> void:

	if attack_area == null:

		return


	if attack_hitbox_shape == null:

		return


	if attack == null:

		attack = primary_attack


	if attack == null:

		return


	var desired_size: Vector2 = Vector2(
		maxf(
			attack.hitbox_length,
			1.0
		),
		maxf(
			attack.hitbox_width,
			1.0
		)
	)


	attack_hitbox_shape.size = (
		desired_size
	)


	var attack_direction: Vector2 = (
		direction
	)


	if attack_direction == Vector2.ZERO:

		attack_direction = (
			_get_attack_direction()
		)


	if attack_direction == Vector2.ZERO:

		attack_direction = (
			Vector2.DOWN
		)


	attack_direction = (
		attack_direction.normalized()
	)


	var center_distance: float = (
		attack.hitbox_start_offset
		+ attack.hitbox_length
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

	if perception != null and perception.is_aware:

		var direction_to_player: Vector2 = (
			perception.get_estimated_target_position(true)
			- global_position
		)


		if direction_to_player.length_squared() > 0.001:

			return (
				direction_to_player.normalized()
			)


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
# ¿ATAQUE ALCANZA LA ESTIMACIÓN PERCIBIDA?
# =========================================================

func _attack_reaches_estimated_target(
	attack: AttackData,
	direction: Vector2 = Vector2.ZERO
) -> bool:
	if attack == null or perception == null or not perception.is_aware:
		return false
	var attack_direction := direction
	if attack_direction.length_squared() < 0.001:
		attack_direction = _get_attack_direction()
	if attack_direction.length_squared() < 0.001:
		return false
	attack_direction = attack_direction.normalized()
	var target_offset := perception.get_estimated_target_position(true) - global_position
	var forward_distance := target_offset.dot(attack_direction)
	var lateral_distance := absf(target_offset.dot(attack_direction.orthogonal()))
	var target_radius := maxf(ai_profile.target_radius_estimate, 0.0)
	var minimum_forward := attack.hitbox_start_offset - target_radius
	var maximum_forward := attack.hitbox_start_offset + attack.hitbox_length + target_radius
	var maximum_lateral := attack.hitbox_width * 0.5 + target_radius
	return (
		forward_distance >= minimum_forward
		and forward_distance <= maximum_forward
		and lateral_distance <= maximum_lateral
	)


# =========================================================
# ¿ATAQUE ALCANZA PLAYER?
# =========================================================

func _attack_hitbox_reaches_player(
	attack: AttackData,
	direction: Vector2 = Vector2.ZERO
) -> bool:

	if attack == null:

		return false


	if not is_instance_valid(
		player
	):

		return false


	if attack_area == null:

		return false


	if attack_hitbox_shape == null:

		return false


	_update_attack_hitbox(
		attack,
		direction
	)


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


func _has_clear_attack_line_to_player() -> bool:
	if not is_instance_valid(player):
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position,
		attack_collision_mask,
		[get_rid()]
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	while collider != null:
		if collider == player or collider.is_in_group("player"):
			return true
		collider = collider.get_parent()
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


	_play_action_animation("walk")


# =========================================================
# ORIENTACIÓN
# =========================================================

func _update_facing(
	direction: Vector2
) -> void:

	if direction == Vector2.ZERO:

		return


	last_facing = (
		_direction_to_8_way_facing(
			direction
		)
	)


	last_cardinal_facing = (
		_direction_to_cardinal_facing(
			direction
		)
	)


	if current_attack != null:

		_play_action_animation("attack")

	elif wants_navigation_movement:

		_play_action_animation("walk")

	else:

		_play_idle()


# =========================================================
# 8 DIRECCIONES
# =========================================================

func _direction_to_8_way_facing(
	direction: Vector2
) -> String:

	if direction == Vector2.ZERO:

		return last_facing


	var angle_degrees: float = (
		rad_to_deg(
			direction.angle()
		)
	)


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
# CARDINAL
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

		return "w"


	if direction.y > 0.0:
		return "s"


	return "n"


# =========================================================
# MIRAR PLAYER
# =========================================================

func _face_player() -> void:

	if perception == null or not perception.is_aware:

		return


	var direction_to_player: Vector2 = (
		perception.get_estimated_target_position(true)
		- global_position
	)


	if direction_to_player.length_squared() < 0.001:

		return


	_update_facing(
		direction_to_player.normalized()
	)


# =========================================================
# IDLE
# =========================================================

func _play_idle() -> void:

	if enemy_animated == null:

		return


	if enemy_animated.sprite_frames == null:

		return


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


func _setup_action_animations() -> void:

	if enemy_animated == null or enemy_animated.sprite_frames == null:

		return


	# El nombre visible cambia por variante; la familia de animación es un dato
	# físico estable y no una comparación frágil de texto localizado.
	if enemy_data == null or enemy_data.animation_family != &"goblin":

		return


	SpriteSheetAnimationBuilder.add_cardinal_sheet(
		enemy_animated.sprite_frames,
		GOBLIN_WALK_SHEET,
		"walk",
		8.0,
		true
	)
	SpriteSheetAnimationBuilder.add_cardinal_sheet(
		enemy_animated.sprite_frames,
		GOBLIN_ATTACK_SHEET,
		"attack",
		12.0,
		false
	)


func _play_action_animation(animation_prefix: String) -> void:

	if enemy_animated == null or enemy_animated.sprite_frames == null:

		return


	var animation_name: StringName = StringName(
		animation_prefix + "_" + last_cardinal_facing
	)


	if not enemy_animated.sprite_frames.has_animation(animation_name):

		return


	if enemy_animated.animation != animation_name:

		enemy_animated.play(animation_name)


# =========================================================
# COMBAT ACTIVE
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
		perception != null
		and
		perception.is_aware
	)


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


	if stagger_recovery_time_left > 0.0:

		return


	if current_attack != null:

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


	velocity = safe_velocity

	move_and_slide()


# =========================================================
# STOP
# =========================================================

func _stop_navigation() -> void:

	wants_navigation_movement = false

	velocity = Vector2.ZERO


	if navigation_agent != null:

			navigation_agent.velocity = (
				Vector2.ZERO
			)


	if current_attack == null:

		_play_idle()


# =========================================================
# ATTACK FLASH
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


	if perception != null:

		perception.notice_position(attacker_position)


	if utility_brain != null:

		utility_brain.interrupt_commitment()


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

	var damage_label: Label = Label.new()


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

		direction = Vector2.DOWN

	else:

		direction = (
			direction.normalized()
		)


	var effective_knockback: float = (
		_get_effective_knockback(
			received_knockback
		)
	)


	if effective_knockback <= 0.0:

		return


	_cancel_ai_dash()


	# =====================================================
	# CANCELAR ATAQUE POR IMPACTO FUERTE
	# =====================================================

	if (
		current_attack != null
		and
		effective_knockback
		>
		enemy_data.attack_interrupt_knockback_threshold
	):

		_cancel_current_attack()


	knockback_velocity = (
		direction
		* effective_knockback
	)


	var recovery_duration: float = (
		_calculate_stagger_recovery_duration(
			effective_knockback
		)
	)


	if recovery_duration > 0.0:

		stagger_recovery_time_left = maxf(
			stagger_recovery_time_left,
			recovery_duration
		)


		print(
			enemy_data.enemy_name,
			" ENTRA EN STAGGER | Knockback efectivo: ",
			effective_knockback,
			" | Recuperación: ",
			recovery_duration,
			" s"
		)


# =========================================================
# VIVO
# =========================================================

func is_enemy_alive() -> bool:

	return health > 0


# =========================================================
# MUERTE
# =========================================================

func die() -> void:

	if is_dying:

		return


	is_dying = true
	_release_reserved_cover()

	print(
		enemy_data.enemy_name,
		" DERROTADO"
	)


	_cancel_current_attack()


	defeated.emit(self)


	_create_loot_corpse()


	wants_navigation_movement = false


	if health_bar != null:

		health_bar.visible = false


	if navigation_agent != null:

		navigation_agent.avoidance_enabled = false

		navigation_agent.velocity = Vector2.ZERO


	velocity = Vector2.ZERO

	knockback_velocity = Vector2.ZERO

	stagger_recovery_time_left = 0.0


	queue_free()


func _create_loot_corpse() -> void:
	var stacks: Array[Dictionary] = []
	if enemy_data != null:
		for loot_entry: LootEntry in enemy_data.loot_table:
			if loot_entry == null:
				continue
			var quantity := loot_entry.roll_quantity(loot_random)
			if quantity > 0 and loot_entry.item != null:
				stacks.append({"item": loot_entry.item, "quantity": quantity})
	var drop_parent := get_parent()
	if drop_parent == null:
		return
	var corpse_scene := preload("res://scenes/items/corpse_loot.tscn") as PackedScene
	var corpse := corpse_scene.instantiate() as CorpseLoot
	drop_parent.add_child(corpse)
	corpse.global_position = global_position
	corpse.configure(enemy_animated, stacks)


# =========================================================
# DEBUG
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


	_draw_perception_debug()


	var player_local: Vector2 = (
		to_local(
			perception.get_estimated_target_position(false)
		)
	)


	var slot_local: Vector2 = (
		to_local(
			debug_combat_position
		)
	)


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


	var attack_to_draw: AttackData = (
		primary_attack
	)


	var direction_to_draw: Vector2 = (
		_get_attack_direction()
	)


	if current_attack != null:

		attack_to_draw = current_attack

		direction_to_draw = (
			locked_attack_direction
		)


	_draw_attack_hitbox(
		state_color,
		attack_to_draw,
		direction_to_draw
	)


func _draw_perception_debug() -> void:

	if ai_profile == null or perception == null:

		return


	var perception_color: Color = Color(
		0.25,
		0.75,
		1.0,
		0.45
	)


	if perception.has_confirmed_visual_contact:

		perception_color = Color(1.0, 0.2, 0.15, 0.8)

	elif perception.heard_target:

		perception_color = Color(1.0, 0.85, 0.2, 0.7)


	var facing_angle: float = (
		_get_perception_facing_direction().angle()
	)
	var half_view_angle: float = deg_to_rad(
		ai_profile.vision_angle_degrees * 0.5
	)


	draw_arc(
		Vector2.ZERO,
		ai_profile.vision_range,
		facing_angle - half_view_angle,
		facing_angle + half_view_angle,
		48,
		perception_color,
		1.0,
		true
	)


	draw_arc(
		Vector2.ZERO,
		ai_profile.hearing_range,
		0.0,
		TAU,
		40,
		Color(1.0, 0.8, 0.2, 0.22),
		1.0,
		true
	)


	if perception.is_aware and not perception.has_confirmed_visual_contact:

		var memory_local: Vector2 = to_local(
			perception.last_known_position
		)


		draw_line(
			Vector2.ZERO,
			memory_local,
			Color(0.7, 0.35, 1.0, 0.7),
			2.0
		)
		draw_circle(
			memory_local,
			7.0,
			Color(0.7, 0.35, 1.0, 0.85),
			false,
			2.0
		)


# =========================================================
# DEBUG HITBOX
# =========================================================

func _draw_attack_hitbox(
	outline_color: Color,
	attack: AttackData,
	direction: Vector2
) -> void:

	if attack == null:

		return


	if direction == Vector2.ZERO:

		direction = Vector2.DOWN


	direction = direction.normalized()


	var half_size: Vector2 = Vector2(
		attack.hitbox_length
		* 0.5,
		attack.hitbox_width
		* 0.5
	)


	var center_distance: float = (
		attack.hitbox_start_offset
		+ attack.hitbox_length
		* 0.5
	)


	var hitbox_position: Vector2 = (
		direction
		* center_distance
	)


	var hitbox_transform: Transform2D = (
		Transform2D(
			direction.angle(),
			hitbox_position
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
