class_name EnemyCombatMovement
extends RefCounted


const PHASE_NAVIGATE: StringName = &"navigate"
const PHASE_SETUP: StringName = &"setup"
const PHASE_READY: StringName = &"ready"
const PHASE_REPOSITION: StringName = &"reposition"


var profile: EnemyAIProfile = null

var movement_phase: StringName = PHASE_NAVIGATE

var _random: RandomNumberGenerator = RandomNumberGenerator.new()

var _anchor_role: StringName = &""
var _anchor_action: StringName = &""
var _anchor_position: Vector2 = Vector2.ZERO
var _anchor_source_target: Vector2 = Vector2.ZERO
var _anchor_time_left: float = 0.0

var _circle_side: float = 1.0

var _setup_attack_id: int = 0
var _setup_position: Vector2 = Vector2.ZERO
var _setup_source_target: Vector2 = Vector2.ZERO
var _setup_hold_left: float = 0.0
var _setup_arrived: bool = false
var _setup_side: float = 1.0

var _reposition_position: Vector2 = Vector2.ZERO
var _reposition_time_left: float = 0.0


func configure(ai_profile: EnemyAIProfile, seed_offset: int = 0) -> void:
	profile = ai_profile

	if profile != null and profile.deterministic_seed > 0:
		_random.seed = profile.deterministic_seed + seed_offset * 65537
	else:
		_random.randomize()

	_circle_side = -1.0 if _random.randf() < 0.5 else 1.0
	_setup_side = -1.0 if _random.randf() < 0.5 else 1.0


func update(delta: float) -> void:
	_anchor_time_left = maxf(_anchor_time_left - delta, 0.0)
	_reposition_time_left = maxf(_reposition_time_left - delta, 0.0)

	if _reposition_time_left <= 0.0 and movement_phase == PHASE_REPOSITION:
		movement_phase = PHASE_NAVIGATE


# =========================================================
# ANCLAS TÁCTICAS ESTABLES
# =========================================================
# El coordinador de escuadrón puede recalcular una posición cada frame porque
# el jugador se mueve. Esta capa evita que el enemigo persiga un punto que
# cambia constantemente: conserva un ancla durante un breve compromiso y solo
# la renueva cuando realmente dejó de ser útil.

func stabilize_assignment(
	enemy_position: Vector2,
	raw_position: Vector2,
	target_position: Vector2,
	role: StringName,
	action: StringName
) -> Vector2:
	if profile == null:
		return raw_position

	if role not in [&"flank", &"support", &"waiting"]:
		_clear_anchor()
		return raw_position

	var target_moved: float = _anchor_source_target.distance_to(target_position)
	var role_changed: bool = role != _anchor_role
	var action_changed: bool = action != _anchor_action
	var anchor_expired: bool = _anchor_time_left <= 0.0
	var anchor_missing: bool = _anchor_position == Vector2.ZERO
	var anchor_too_stale: bool = (
		target_moved >= profile.tactical_anchor_retarget_distance
	)

	if (
		anchor_missing
		or role_changed
		or action_changed
		or anchor_expired
		or anchor_too_stale
	):
		_anchor_role = role
		_anchor_action = action
		_anchor_source_target = target_position
		_anchor_position = _normalize_assignment_anchor(
			enemy_position,
			raw_position,
			target_position,
			role
		)
		_anchor_time_left = profile.get_tactical_anchor_lock_time()

	return _anchor_position


func _normalize_assignment_anchor(
	enemy_position: Vector2,
	raw_position: Vector2,
	target_position: Vector2,
	role: StringName
) -> Vector2:
	var offset: Vector2 = raw_position - target_position

	if offset.length_squared() < 0.001:
		offset = enemy_position - target_position

	if offset.length_squared() < 0.001:
		offset = Vector2.DOWN

	var direction := offset.normalized()
	var desired_radius := offset.length()

	match role:
		&"flank":
			desired_radius = profile.flank_radius
		&"support", &"waiting":
			desired_radius = profile.support_radius

	return target_position + direction * desired_radius


func _clear_anchor() -> void:
	_anchor_role = &""
	_anchor_action = &""
	_anchor_position = Vector2.ZERO
	_anchor_source_target = Vector2.ZERO
	_anchor_time_left = 0.0


# =========================================================
# ÓRBITA REAL / CIRCLE
# =========================================================

func get_circle_destination(
	enemy_position: Vector2,
	target_position: Vector2
) -> Vector2:
	if profile == null:
		return enemy_position

	var radial := enemy_position - target_position
	if radial.length_squared() < 0.001:
		radial = Vector2.DOWN

	var radial_direction := radial.normalized()
	var tangent := radial_direction.rotated(_circle_side * PI * 0.5)
	var radial_error := radial.length() - profile.circle_radius
	var normalized_error := clampf(
		radial_error / maxf(profile.circle_radius, 1.0),
		-1.0,
		1.0
	)

	var orbit_direction := (
		tangent * profile.circle_tangent_strength
		- radial_direction
		* normalized_error
		* profile.circle_radial_correction
	)

	if orbit_direction.length_squared() < 0.001:
		orbit_direction = tangent

	movement_phase = PHASE_NAVIGATE
	return (
		enemy_position
		+ orbit_direction.normalized()
		* profile.circle_step_distance
	)


# =========================================================
# PREPARACIÓN DE ATAQUE
# =========================================================
# En vez de "llegué al rango -> golpeo", el enemigo escoge un punto de setup,
# se alinea, estabiliza la distancia y recién después entra en el ataque.

func get_attack_setup(
	enemy_position: Vector2,
	target_position: Vector2,
	target_facing: Vector2,
	attack: AttackData,
	role: StringName,
	delta: float
) -> Dictionary:
	if profile == null or attack == null:
		movement_phase = PHASE_NAVIGATE
		return {
			"position": enemy_position,
			"ready": true,
			"phase": movement_phase
		}

	var attack_id := int(attack.get_instance_id())
	var target_moved := _setup_source_target.distance_to(target_position)
	var needs_refresh := (
		_setup_attack_id != attack_id
		or _setup_position == Vector2.ZERO
		or target_moved >= profile.attack_setup_retarget_distance
	)

	if needs_refresh:
		_create_attack_setup(
			enemy_position,
			target_position,
			target_facing,
			attack,
			role
		)

	var distance_to_setup := enemy_position.distance_to(_setup_position)

	# El punto de setup es una preferencia táctica, no una obligación absoluta.
	# Si ya estamos dentro de una banda desde la cual el ataque puede alcanzar al
	# objetivo, aceptamos la posición actual. Esto evita "caminar contra" el
	# Player intentando alcanzar un punto geométricamente imposible por colisión.
	var current_target_distance := enemy_position.distance_to(target_position)
	var minimum_attack_distance := maxf(
		attack.hitbox_start_offset - maxf(profile.target_radius_estimate, 0.0),
		0.0
	)
	var maximum_attack_distance := (
		attack.hitbox_start_offset
		+ attack.hitbox_length
		+ maxf(profile.target_radius_estimate, 0.0)
	)
	var inside_attack_band := (
		current_target_distance >= minimum_attack_distance
		and current_target_distance <= maximum_attack_distance
	)

	var arrived := (
		distance_to_setup <= profile.get_attack_setup_position_tolerance()
		or inside_attack_band
	)

	if arrived:
		if not _setup_arrived:
			_setup_arrived = true
			_setup_hold_left = profile.get_attack_setup_hold_time()

		_setup_hold_left = maxf(_setup_hold_left - delta, 0.0)

		if _setup_hold_left <= 0.0:
			movement_phase = PHASE_READY
		else:
			movement_phase = PHASE_SETUP
	else:
		_setup_arrived = false
		_setup_hold_left = profile.get_attack_setup_hold_time()
		movement_phase = PHASE_SETUP

	return {
		"position": _setup_position,
		"ready": arrived and _setup_hold_left <= 0.0,
		"phase": movement_phase,
		"distance_to_setup": distance_to_setup
	}


func _create_attack_setup(
	enemy_position: Vector2,
	target_position: Vector2,
	target_facing: Vector2,
	attack: AttackData,
	role: StringName
) -> void:
	_setup_attack_id = int(attack.get_instance_id())
	_setup_source_target = target_position
	_setup_arrived = false
	_setup_hold_left = profile.get_attack_setup_hold_time()
	if _random.randf() < 0.36:
		_setup_side *= -1.0

	var current_radial := enemy_position - target_position
	if current_radial.length_squared() < 0.001:
		current_radial = Vector2.DOWN

	var desired_direction := current_radial.normalized()
	var intelligence := profile.get_intelligence_ratio()
	var angle_bias := profile.get_attack_setup_angle_bias_radians()

	if target_facing.length_squared() > 0.001:
		var facing := target_facing.normalized()
		var lateral := facing.rotated(_setup_side * PI * 0.5)

		match role:
			&"flank":
				desired_direction = (
					desired_direction.lerp(lateral, lerpf(0.42, 0.82, intelligence))
				).normalized()
			&"support", &"waiting":
				desired_direction = (
					desired_direction.lerp(lateral, lerpf(0.18, 0.52, intelligence))
				).normalized()
			_:
				desired_direction = desired_direction.rotated(_setup_side * angle_bias)
	else:
		desired_direction = desired_direction.rotated(_setup_side * angle_bias * 0.55)

	var minimum_distance := maxf(
		attack.hitbox_start_offset + 6.0,
		profile.target_radius_estimate + 10.0
	)
	var maximum_distance := maxf(
		attack.hitbox_start_offset + attack.hitbox_length - 4.0,
		minimum_distance
	)
	var desired_distance := lerpf(
		minimum_distance,
		maximum_distance,
		clampf(profile.attack_setup_reach_ratio, 0.05, 0.95)
	)

	_setup_position = target_position + desired_direction * desired_distance
	movement_phase = PHASE_SETUP


func force_attack_setup_refresh() -> void:
	_setup_position = Vector2.ZERO
	_setup_source_target = Vector2.ZERO
	_setup_arrived = false
	_setup_hold_left = 0.0
	movement_phase = PHASE_SETUP


func reset_attack_setup() -> void:
	_setup_attack_id = 0
	_setup_position = Vector2.ZERO
	_setup_source_target = Vector2.ZERO
	_setup_hold_left = 0.0
	_setup_arrived = false

	if movement_phase in [PHASE_SETUP, PHASE_READY]:
		movement_phase = PHASE_NAVIGATE


# =========================================================
# REPOSICIONAMIENTO POST-ATAQUE
# =========================================================

func notify_attack_finished(
	enemy_position: Vector2,
	target_position: Vector2
) -> void:
	if profile == null or profile.get_post_attack_reposition_distance() <= 0.0:
		return

	var away := enemy_position - target_position
	if away.length_squared() < 0.001:
		away = Vector2.DOWN

	away = away.normalized()
	var tangent := away.rotated(_setup_side * PI * 0.5)
	var reposition_direction := (away * 0.28 + tangent * 0.96).normalized()

	_reposition_position = (
		enemy_position
		+ reposition_direction
		* profile.get_post_attack_reposition_distance()
	)
	_reposition_time_left = profile.get_post_attack_reposition_duration()
	_setup_side *= -1.0
	movement_phase = PHASE_REPOSITION


func has_reposition() -> bool:
	return _reposition_time_left > 0.0


func get_reposition_position() -> Vector2:
	return _reposition_position


func finish_reposition() -> void:
	_reposition_time_left = 0.0
	_reposition_position = Vector2.ZERO
	movement_phase = PHASE_NAVIGATE


# =========================================================
# DASH INTENCIONAL
# =========================================================

func should_dash_for_movement(
	purpose: StringName,
	distance_to_goal: float,
	current_stamina: float,
	maximum_stamina: float,
	dash_cost: float,
	dash_distance: float
) -> bool:
	if profile == null:
		return false

	if purpose not in [&"approach", &"flank", &"attack_setup", &"reposition", &"retreat"]:
		return false

	var minimum_distance := profile.get_approach_dash_min_distance()
	if purpose in [&"reposition", &"retreat", &"flank"]:
		minimum_distance = profile.get_reposition_dash_min_distance()

	if distance_to_goal < minimum_distance:
		return false

	# Evita pasar de largo del punto táctico.
	if distance_to_goal <= dash_distance + profile.dash_stop_buffer:
		return false

	if maximum_stamina > 0.0:
		var stamina_after_dash := current_stamina - dash_cost
		var required_reserve := maximum_stamina * profile.get_dash_stamina_reserve_ratio()
		if stamina_after_dash < required_reserve:
			return false

	return true


func get_debug_label() -> String:
	match movement_phase:
		PHASE_SETUP:
			return "SETUP"
		PHASE_READY:
			return "LISTO"
		PHASE_REPOSITION:
			return "REPOS"
		_:
			return "MOV"
