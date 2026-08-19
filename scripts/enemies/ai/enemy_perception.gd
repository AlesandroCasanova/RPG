class_name EnemyPerception
extends RefCounted


var owner_enemy: CharacterBody2D
var target: CharacterBody2D
var profile: EnemyAIProfile

var has_line_of_sight := false
var has_confirmed_visual_contact := false
var heard_target := false
var proximity_detected := false
var is_aware := false
var is_suspicious := false

var last_known_position := Vector2.ZERO
var last_seen_position := Vector2.ZERO
var estimated_velocity := Vector2.ZERO
var memory_time_left := 0.0
var suspicion_time_left := 0.0

var search_anchor_position := Vector2.ZERO
var search_target_position := Vector2.ZERO

var observation: Dictionary = {}
var observation_source: StringName = &"none"
var observation_confidence := 0.0
var observation_age := INF
var uncertainty_radius := 0.0

var _sample_cooldown := 0.0
var _pending_observations: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()
var _clock := 0.0
var _visual_epoch := 0
var _was_raw_line_of_sight := false
var _search_retarget_time_left := 0.0
var _search_probe_index := 0
var _search_probe_limit := 1
var _last_seen_velocity := Vector2.ZERO


func configure(
	enemy: CharacterBody2D,
	new_target: CharacterBody2D,
	ai_profile: EnemyAIProfile,
	seed_offset: int = 0
) -> void:
	owner_enemy = enemy
	target = new_target
	profile = ai_profile

	if profile.deterministic_seed > 0:
		_random.seed = profile.deterministic_seed + seed_offset
	else:
		_random.randomize()


func set_target(new_target: CharacterBody2D) -> void:
	if target != new_target:
		_reset_perception_state()

	target = new_target


func _reset_perception_state() -> void:
	_pending_observations.clear()
	observation.clear()
	is_aware = false
	is_suspicious = false
	memory_time_left = 0.0
	suspicion_time_left = 0.0
	has_line_of_sight = false
	has_confirmed_visual_contact = false
	heard_target = false
	proximity_detected = false
	last_known_position = Vector2.ZERO
	last_seen_position = Vector2.ZERO
	estimated_velocity = Vector2.ZERO
	_last_seen_velocity = Vector2.ZERO
	search_anchor_position = Vector2.ZERO
	search_target_position = Vector2.ZERO
	observation_source = &"none"
	observation_confidence = 0.0
	observation_age = INF
	uncertainty_radius = 0.0
	_visual_epoch = 0
	_was_raw_line_of_sight = false
	_search_retarget_time_left = 0.0
	_search_probe_index = 0
	_search_probe_limit = 1


func notice_position(world_position: Vector2) -> void:
	if profile == null:
		return

	is_aware = true
	is_suspicious = true
	last_known_position = world_position
	last_seen_position = world_position
	estimated_velocity = Vector2.ZERO
	_last_seen_velocity = Vector2.ZERO
	memory_time_left = profile.get_perceptual_memory_duration()
	suspicion_time_left = profile.get_suspicion_duration()
	observation_source = &"impact"
	observation_confidence = 0.90
	observation_age = 0.0
	uncertainty_radius = 8.0
	search_anchor_position = world_position
	search_target_position = world_position
	_reset_search_pattern()

	# Un golpe revela su origen, pero no invalida una visión ya confirmada.
	if not has_line_of_sight:
		has_confirmed_visual_contact = false

	observation = {
		"sequence": Engine.get_physics_frames(),
		"source": &"impact",
		"position": world_position,
		"velocity": Vector2.ZERO,
		"estimated_position": world_position,
		"estimated_velocity": Vector2.ZERO,
		"facing": Vector2.ZERO,
		"locomotion": &"unknown",
		"action": &"none",
		"phase": &"none",
		"attack_family": &"none",
		"charge_stage": &"none",
		"confidence": observation_confidence,
		"uncertainty_radius": uncertainty_radius,
		"alive": true
	}


func update(delta: float, facing_direction: Vector2) -> void:
	_clock += delta
	var had_raw_visual_contact := _was_raw_line_of_sight

	has_line_of_sight = false
	heard_target = false
	proximity_detected = false
	_sample_cooldown = maxf(_sample_cooldown - delta, 0.0)
	_search_retarget_time_left = maxf(_search_retarget_time_left - delta, 0.0)
	observation_age += delta

	if not is_instance_valid(owner_enemy):
		is_aware = false
		is_suspicious = false
		return

	if is_instance_valid(target):
		_update_raw_senses(facing_direction)

	# Detecta el instante en que un objetivo visible desaparece tras cobertura.
	# La IA no conoce la nueva posición oculta: conserva únicamente la última
	# observación que realmente llegó a percibir.
	if had_raw_visual_contact and not has_line_of_sight and is_aware:
		_enter_suspicion()

	_update_visual_contact_epoch()

	if is_instance_valid(target):
		if (
			has_line_of_sight
			or heard_target
			or proximity_detected
		) and _sample_cooldown <= 0.0:
			_queue_observation()

	_deliver_ready_observations()

	var has_current_cue := (
		has_line_of_sight
		or heard_target
		or proximity_detected
	)

	if not has_current_cue:
		_forget_over_time(delta)
	elif is_aware:
		memory_time_left = profile.get_perceptual_memory_duration()
		if proximity_detected and not has_line_of_sight:
			is_suspicious = true
			suspicion_time_left = maxf(
				suspicion_time_left,
				profile.get_suspicion_duration() * 0.55
			)

	if is_aware and not has_line_of_sight:
		uncertainty_radius += (
			delta
			* profile.get_memory_position_error()
			* 0.35
		)
		_update_search_plan(delta)
	elif has_line_of_sight:
		is_suspicious = false
		suspicion_time_left = 0.0
		search_anchor_position = last_known_position
		search_target_position = last_known_position
		_reset_search_pattern()


func get_estimated_target_position(use_prediction: bool = true) -> Vector2:
	var result := last_known_position

	if (
		use_prediction
		and observation_source == &"vision"
		and has_confirmed_visual_contact
	):
		result += (
			estimated_velocity
			* profile.get_prediction_horizon()
			* observation_confidence
		)

	return result


func get_search_target_position() -> Vector2:
	if search_target_position != Vector2.ZERO:
		return search_target_position
	return last_known_position


func get_awareness_label() -> String:
	if has_confirmed_visual_contact:
		return "VISION"
	if heard_target:
		return "OIDO"
	if proximity_detected:
		return "PROX"
	if is_suspicious:
		return "SOSPECHA"
	if is_aware:
		return "MEM"
	return "CALMA"


func get_observed_combat_state() -> Dictionary:
	var result := observation.duplicate(true)
	result["confidence"] = observation_confidence
	result["uncertainty_radius"] = uncertainty_radius
	result["age"] = observation_age
	result["suspicious"] = is_suspicious
	result["proximity"] = proximity_detected

	# Una señal no se conserva como telegraph para siempre. Si el objetivo sigue
	# visible llegarán muestras nuevas; si se ocultó, queda solo memoria espacial.
	if observation_age > 1.15:
		result["action"] = &"none"
		result["phase"] = &"none"
		result["attack_family"] = &"none"
		result["charge_stage"] = &"none"

	return result


func _update_raw_senses(facing_direction: Vector2) -> void:
	var distance_to_target := owner_enemy.global_position.distance_to(
		target.global_position
	)

	if distance_to_target <= profile.vision_range:
		has_line_of_sight = (
			_is_inside_view_cone(facing_direction)
			and _has_clear_path_to_target()
		)

	if distance_to_target <= profile.hearing_range:
		var movement_noise := target.velocity.length()
		if target.has_method("get_movement_noise_level"):
			movement_noise = float(target.get_movement_noise_level())
		heard_target = movement_noise >= profile.hearing_velocity_threshold

	# Proximidad no equivale a visión. Da una pista aproximada y ruidosa cuando
	# alguien está extremadamente cerca, incluso si un obstáculo corta el LOS.
	if (
		not has_line_of_sight
		and distance_to_target <= profile.get_proximity_sense_range()
	):
		proximity_detected = true


func _queue_observation() -> void:
	var source: StringName = &"proximity"
	if has_line_of_sight:
		source = &"vision"
	elif heard_target:
		source = &"hearing"

	var raw_snapshot: Dictionary = {}
	if source == &"vision" and target.has_method("get_combat_observable_snapshot"):
		raw_snapshot = target.get_combat_observable_snapshot()
	else:
		raw_snapshot = {
			"sequence": Engine.get_physics_frames(),
			"position": target.global_position,
			"velocity": target.velocity,
			"facing": Vector2.ZERO,
			"locomotion": &"unknown",
			"action": &"none",
			"phase": &"none",
			"attack_family": &"none",
			"charge_stage": &"none",
			"alive": true
		}

	_pending_observations.append({
		"deliver_at": _clock + profile.get_reaction_time(),
		"captured_at": _clock,
		"source": source,
		"visual_epoch": _visual_epoch if source == &"vision" else -1,
		"snapshot": raw_snapshot
	})

	if _pending_observations.size() > 8:
		_pending_observations.pop_front()

	_sample_cooldown = maxf(
		profile.get_reaction_time() * 0.55,
		0.08
	)


func _deliver_ready_observations() -> void:
	var now := _clock

	while not _pending_observations.is_empty():
		var pending := _pending_observations[0]
		if float(pending.get("deliver_at", INF)) > now:
			break

		_pending_observations.pop_front()
		_deliver_observation(
			Dictionary(pending.get("snapshot", {})),
			StringName(pending.get("source", &"memory")),
			maxf(
				_clock - float(pending.get("captured_at", _clock)),
				0.0
			),
			int(pending.get("visual_epoch", -1))
		)


func _deliver_observation(
	raw: Dictionary,
	source: StringName,
	cue_age: float,
	visual_epoch: int
) -> void:
	var skill := profile.get_intelligence_ratio()
	var source_multiplier := 1.0
	var confidence_base := 0.95

	match source:
		&"hearing":
			source_multiplier = 2.2
			confidence_base = 0.62
		&"proximity":
			source_multiplier = 3.2
			confidence_base = profile.get_proximity_confidence()
		&"impact":
			source_multiplier = 1.2
			confidence_base = 0.90

	var position_error := profile.get_memory_position_error() * source_multiplier
	if source == &"proximity":
		position_error = maxf(
			position_error,
			profile.get_proximity_position_error()
		)

	var error_direction := Vector2.RIGHT.rotated(
		_random.randf_range(0.0, TAU)
	)
	var error_distance := _random.randf_range(0.0, position_error)

	var raw_velocity := Vector2(raw.get("velocity", Vector2.ZERO))
	var velocity_read_factor := lerpf(0.35, 0.96, skill)
	if source != &"vision":
		velocity_read_factor *= 0.35

	estimated_velocity = raw_velocity * velocity_read_factor
	var reaction_compensation := (
		estimated_velocity
		* minf(cue_age, 0.8)
		* skill
	)

	last_known_position = (
		Vector2(raw.get("position", last_known_position))
		+ reaction_compensation
		+ error_direction * error_distance
	)

	observation_source = source
	observation_confidence = clampf(
		confidence_base * lerpf(0.62, 1.0, skill),
		0.0,
		1.0
	)
	uncertainty_radius = position_error
	observation_age = cue_age
	memory_time_left = profile.get_perceptual_memory_duration()
	is_aware = true

	if source == &"vision":
		last_seen_position = last_known_position
		_last_seen_velocity = estimated_velocity
		search_anchor_position = last_seen_position
		search_target_position = last_seen_position
		if has_line_of_sight and visual_epoch == _visual_epoch:
			has_confirmed_visual_contact = true
			is_suspicious = false
			suspicion_time_left = 0.0
	elif source in [&"hearing", &"proximity"]:
		is_suspicious = true
		suspicion_time_left = maxf(
			suspicion_time_left,
			profile.get_suspicion_duration() * 0.55
		)

		# Una pista nueva debe poder desplazar una memoria vieja.
		# En especial PROXIMITY: si el jugador está prácticamente encima,
		# no tiene sentido seguir investigando un punto de hace varios segundos.
		var retarget_threshold := maxf(
			profile.search_arrival_distance * 0.65,
			18.0
		)
		var should_retarget_search := (
			search_anchor_position == Vector2.ZERO
			or last_known_position.distance_to(search_anchor_position) >= retarget_threshold
		)

		if source == &"proximity":
			should_retarget_search = (
				search_anchor_position == Vector2.ZERO
				or last_known_position.distance_to(search_anchor_position) >= retarget_threshold
				or owner_enemy.global_position.distance_to(search_anchor_position) > profile.search_arrival_distance
			)

		if should_retarget_search:
			search_anchor_position = last_known_position
			search_target_position = last_known_position
			_reset_search_pattern()

	# Lista blanca deliberada: el cerebro nunca recibe el diccionario crudo del
	# Player, aunque en el futuro ese contrato agregue datos privados.
	observation = {
		"sequence": int(raw.get("sequence", Engine.get_physics_frames())),
		"source": source,
		"position": last_known_position,
		"velocity": estimated_velocity,
		"estimated_position": last_known_position,
		"estimated_velocity": estimated_velocity,
		"facing": Vector2(raw.get("facing", Vector2.ZERO)) if source == &"vision" else Vector2.ZERO,
		"locomotion": StringName(raw.get("locomotion", &"unknown")) if source == &"vision" else &"unknown",
		"action": StringName(raw.get("action", &"none")),
		"phase": StringName(raw.get("phase", &"none")),
		"attack_family": StringName(raw.get("attack_family", &"none")),
		"charge_stage": StringName(raw.get("charge_stage", &"none")),
		"confidence": observation_confidence,
		"uncertainty_radius": uncertainty_radius,
		"cue_age": cue_age,
		"alive": bool(raw.get("alive", true))
	}

	if source != &"vision":
		observation["action"] = &"none"
		observation["phase"] = &"none"
		observation["attack_family"] = &"none"
		observation["charge_stage"] = &"none"
	elif not profile.is_capability_enabled(EnemyAIProfile.CAP_READ_TELEGRAPHS):
		var can_read_recovery := (
			profile.is_capability_enabled(EnemyAIProfile.CAP_ADAPT_ATTACKS)
			and StringName(observation.get("phase", &"none")) == &"recovery"
		)
		observation["action"] = &"attack" if can_read_recovery else &"none"
		observation["phase"] = &"recovery" if can_read_recovery else &"none"
		observation["attack_family"] = &"none"
		observation["charge_stage"] = &"none"
	elif cue_age > 0.72 and StringName(observation.get("action", &"none")) != &"charge":
		observation["action"] = &"none"
		observation["phase"] = &"none"
		observation["attack_family"] = &"none"


func _enter_suspicion() -> void:
	if profile == null or not is_aware:
		return

	is_suspicious = true
	suspicion_time_left = maxf(
		suspicion_time_left,
		profile.get_suspicion_duration()
	)
	memory_time_left = maxf(
		memory_time_left,
		profile.get_perceptual_memory_duration()
	)

	# Usa únicamente la trayectoria que alcanzó a observar antes de perder LOS.
	var prediction_time := profile.get_search_prediction_time()
	search_anchor_position = (
		last_seen_position
		+ _last_seen_velocity
		* prediction_time
		* observation_confidence
	)

	if search_anchor_position == Vector2.ZERO:
		search_anchor_position = last_known_position

	search_target_position = search_anchor_position
	_reset_search_pattern()


func _forget_over_time(delta: float) -> void:
	if memory_time_left > 0.0:
		memory_time_left = maxf(memory_time_left - delta, 0.0)
		observation_confidence *= exp(
			-delta
			/ maxf(profile.get_perceptual_memory_duration(), 0.1)
		)

	if suspicion_time_left > 0.0:
		suspicion_time_left = maxf(
			suspicion_time_left - delta,
			0.0
		)

	is_suspicious = suspicion_time_left > 0.0
	is_aware = memory_time_left > 0.0 or is_suspicious

	if not is_aware:
		observation_source = &"none"
		observation_confidence = 0.0
		estimated_velocity = Vector2.ZERO
		search_anchor_position = Vector2.ZERO
		search_target_position = Vector2.ZERO


func _update_search_plan(_delta: float) -> void:
	if not is_aware or has_line_of_sight:
		return

	if search_anchor_position == Vector2.ZERO:
		search_anchor_position = last_known_position

	if search_target_position == Vector2.ZERO:
		search_target_position = search_anchor_position

	var distance_to_anchor := owner_enemy.global_position.distance_to(
		search_anchor_position
	)

	# Primero verifica el último punto razonable. Recién al llegar empieza a
	# revisar laterales, simulando que busca bordes/salidas del obstáculo.
	if distance_to_anchor > profile.search_arrival_distance:
		search_target_position = search_anchor_position
		return

	if _search_retarget_time_left > 0.0:
		return

	if _search_probe_index >= _search_probe_limit:
		_search_probe_index = 0
		_search_probe_limit = profile.get_search_probe_count()

	var forward := _last_seen_velocity
	if forward.length_squared() < 0.001:
		forward = search_anchor_position - owner_enemy.global_position
	if forward.length_squared() < 0.001:
		forward = Vector2.RIGHT
	forward = forward.normalized()

	var side := forward.orthogonal()
	var sign_value := 1.0 if _search_probe_index % 2 == 0 else -1.0

	# Una IA inteligente prioriza la continuidad de la trayectoria observada.
	# Una básica introduce más error y revisa posiciones menos consistentes.
	var skill := profile.get_intelligence_ratio()
	var probe_radius := profile.get_search_probe_radius()
	var forward_bias := lerpf(0.10, 0.48, skill)
	var candidate := (
		search_anchor_position
		+ side * probe_radius * sign_value
		+ forward * probe_radius * forward_bias
	)

	var jitter_radius := lerpf(probe_radius * 0.55, probe_radius * 0.08, skill)
	if jitter_radius > 0.0:
		candidate += Vector2.RIGHT.rotated(
			_random.randf_range(0.0, TAU)
		) * _random.randf_range(0.0, jitter_radius)

	search_target_position = candidate
	_search_probe_index += 1
	_search_retarget_time_left = profile.get_search_retarget_interval()


func _reset_search_pattern() -> void:
	_search_probe_index = 0
	_search_probe_limit = (
		profile.get_search_probe_count()
		if profile != null
		else 1
	)
	_search_retarget_time_left = 0.0


func _update_visual_contact_epoch() -> void:
	if has_line_of_sight == _was_raw_line_of_sight:
		return

	_was_raw_line_of_sight = has_line_of_sight
	has_confirmed_visual_contact = false

	if has_line_of_sight:
		_visual_epoch += 1


func _is_inside_view_cone(facing_direction: Vector2) -> bool:
	if profile.vision_angle_degrees >= 359.0:
		return true

	var direction_to_target := (
		target.global_position
		- owner_enemy.global_position
	)

	if direction_to_target.length_squared() < 0.001:
		return true

	if facing_direction.length_squared() < 0.001:
		facing_direction = Vector2.DOWN

	var half_angle_radians := deg_to_rad(
		profile.vision_angle_degrees * 0.5
	)

	return absf(
		facing_direction.normalized().angle_to(
			direction_to_target.normalized()
		)
	) <= half_angle_radians


func _has_clear_path_to_target() -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		owner_enemy.global_position,
		target.global_position,
		profile.sight_collision_mask,
		[owner_enemy.get_rid()]
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := owner_enemy.get_world_2d().direct_space_state.intersect_ray(
		query
	)

	if hit.is_empty():
		return true

	var collider: Variant = hit.get("collider")
	if collider == target:
		return true

	if collider is Node:
		var node := collider as Node
		while node != null:
			if node == target or node.is_in_group("player"):
				return true
			node = node.get_parent()

	return false
