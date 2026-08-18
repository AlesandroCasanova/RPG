class_name EnemyPerception
extends RefCounted


var owner_enemy: CharacterBody2D
var target: CharacterBody2D
var profile: EnemyAIProfile

var has_line_of_sight := false
var has_confirmed_visual_contact := false
var heard_target := false
var is_aware := false
var last_known_position := Vector2.ZERO
var estimated_velocity := Vector2.ZERO
var memory_time_left := 0.0
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
		_pending_observations.clear()
		observation.clear()
		is_aware = false
		memory_time_left = 0.0
		has_line_of_sight = false
		has_confirmed_visual_contact = false
		heard_target = false
		last_known_position = Vector2.ZERO
		estimated_velocity = Vector2.ZERO
		observation_source = &"none"
		observation_confidence = 0.0
		observation_age = INF
		uncertainty_radius = 0.0
		_visual_epoch = 0
		_was_raw_line_of_sight = false
	target = new_target


func notice_position(world_position: Vector2) -> void:
	is_aware = true
	last_known_position = world_position
	estimated_velocity = Vector2.ZERO
	memory_time_left = profile.memory_duration
	observation_source = &"impact"
	observation_confidence = 0.9
	# Un golpe revela su origen, pero no invalida una visión ya confirmada. Si el
	# atacante estaba oculto, el impacto solo concede memoria espacial.
	if not has_line_of_sight:
		has_confirmed_visual_contact = false
	observation_age = 0.0
	uncertainty_radius = 8.0
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
	has_line_of_sight = false
	heard_target = false
	_sample_cooldown = maxf(_sample_cooldown - delta, 0.0)
	observation_age += delta
	if not is_instance_valid(owner_enemy):
		is_aware = false
		return
	if is_instance_valid(target):
		_update_raw_senses(facing_direction)
	_update_visual_contact_epoch()
	if is_instance_valid(target):
		if (has_line_of_sight or heard_target) and _sample_cooldown <= 0.0:
			_queue_observation()
	_deliver_ready_observations()
	if not has_line_of_sight and not heard_target:
		_forget_over_time(delta)
	elif is_aware:
		memory_time_left = profile.memory_duration
	if is_aware and not has_line_of_sight:
		uncertainty_radius += delta * profile.get_memory_position_error() * 0.35


func get_estimated_target_position(use_prediction: bool = true) -> Vector2:
	var result := last_known_position
	if use_prediction and observation_source == &"vision" and has_confirmed_visual_contact:
		result += estimated_velocity * profile.get_prediction_horizon() * observation_confidence
	return result


func get_observed_combat_state() -> Dictionary:
	var result := observation.duplicate(true)
	result["confidence"] = observation_confidence
	result["uncertainty_radius"] = uncertainty_radius
	result["age"] = observation_age
	# Una señal no se conserva como telegraph para siempre. Si el objetivo sigue
	# visible llegarán muestras nuevas; si se ocultó, queda solo memoria espacial.
	if observation_age > 1.15:
		result["action"] = &"none"
		result["phase"] = &"none"
		result["attack_family"] = &"none"
		result["charge_stage"] = &"none"
	return result


func _update_raw_senses(facing_direction: Vector2) -> void:
	var distance_to_target := owner_enemy.global_position.distance_to(target.global_position)
	if distance_to_target <= profile.vision_range:
		has_line_of_sight = _is_inside_view_cone(facing_direction) and _has_clear_path_to_target()
	if distance_to_target <= profile.hearing_range:
		var movement_noise := target.velocity.length()
		if target.has_method("get_movement_noise_level"):
			movement_noise = float(target.get_movement_noise_level())
		heard_target = movement_noise >= profile.hearing_velocity_threshold


func _queue_observation() -> void:
	var source: StringName = &"vision" if has_line_of_sight else &"hearing"
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
	_sample_cooldown = maxf(profile.get_reaction_time() * 0.55, 0.08)


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
			maxf(_clock - float(pending.get("captured_at", _clock)), 0.0),
			int(pending.get("visual_epoch", -1))
		)


func _deliver_observation(
	raw: Dictionary,
	source: StringName,
	cue_age: float,
	visual_epoch: int
) -> void:
	var skill := profile.get_intelligence_ratio()
	var source_multiplier := 1.0 if source == &"vision" else 2.2
	var position_error := profile.get_memory_position_error() * source_multiplier
	var error_direction := Vector2.RIGHT.rotated(_random.randf_range(0.0, TAU))
	var error_distance := _random.randf_range(0.0, position_error)
	estimated_velocity = Vector2(raw.get("velocity", Vector2.ZERO)) * lerpf(0.35, 0.96, skill)
	var reaction_compensation := estimated_velocity * minf(cue_age, 0.8) * skill
	last_known_position = (
		Vector2(raw.get("position", last_known_position))
		+ reaction_compensation
		+ error_direction * error_distance
	)
	observation_source = source
	observation_confidence = clampf(
		(0.95 if source == &"vision" else 0.62) * lerpf(0.62, 1.0, skill),
		0.0,
		1.0
	)
	uncertainty_radius = position_error
	observation_age = cue_age
	memory_time_left = profile.memory_duration
	is_aware = true
	if source == &"vision" and has_line_of_sight and visual_epoch == _visual_epoch:
		has_confirmed_visual_contact = true
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
		# Adaptar una respuesta a una recuperación ya visible es más simple que
		# anticipar un telegraph. El 50% puede reconocer esa apertura sin saber
		# que una carga está en curso ni qué ataque se prepara.
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


func _forget_over_time(delta: float) -> void:
	if memory_time_left > 0.0:
		memory_time_left = maxf(memory_time_left - delta, 0.0)
		observation_confidence *= exp(-delta / maxf(profile.memory_duration, 0.1))
	is_aware = memory_time_left > 0.0
	if not is_aware:
		observation_source = &"none"
		observation_confidence = 0.0
		estimated_velocity = Vector2.ZERO


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
	var direction_to_target := target.global_position - owner_enemy.global_position
	if direction_to_target.length_squared() < 0.001:
		return true
	if facing_direction.length_squared() < 0.001:
		facing_direction = Vector2.DOWN
	var half_angle_radians := deg_to_rad(profile.vision_angle_degrees * 0.5)
	return absf(facing_direction.normalized().angle_to(direction_to_target.normalized())) <= half_angle_radians


func _has_clear_path_to_target() -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		owner_enemy.global_position,
		target.global_position,
		profile.sight_collision_mask,
		[owner_enemy.get_rid()]
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := owner_enemy.get_world_2d().direct_space_state.intersect_ray(query)
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
