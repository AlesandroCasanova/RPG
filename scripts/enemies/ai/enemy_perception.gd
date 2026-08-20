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
var _sense_poll_time_left := 0.0
var _pending_observations: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()
var _clock := 0.0
var _visual_epoch := 0
var _was_raw_line_of_sight := false
var _search_retarget_time_left := 0.0
var _search_probe_index := 0
var _search_probe_limit := 1
var _last_seen_velocity := Vector2.ZERO
var _search_anchor_reached := false
var _search_forward_direction := Vector2.ZERO
var _has_visual_history := false
var _hearing_cue_refresh_time_left := 0.0
var _proximity_cue_refresh_time_left := 0.0

# Búsqueda territorial alrededor del ÚLTIMO PUNTO VISTO.
# HOME = posición idle/spawn.
# Fases:
# 0 = RUSH al último punto visto
# 1 = ir desde el centro al primer punto del perímetro
# 2 = caminar la vuelta completa del perímetro
# 3 = volver al idle
# 4 = terminado
var home_position := Vector2.ZERO
var _search_phase: int = 0
var _search_perimeter_center := Vector2.ZERO
var _search_perimeter_radius: float = 0.0
var _search_perimeter_start_angle: float = 0.0
var _search_perimeter_direction_sign: float = 1.0
var _search_perimeter_point_count: int = 16
var _search_perimeter_step: int = 0
var _search_perimeter_target := Vector2.ZERO


func configure(
	enemy: CharacterBody2D,
	new_target: CharacterBody2D,
	ai_profile: EnemyAIProfile,
	seed_offset: int = 0
) -> void:
	owner_enemy = enemy
	target = new_target
	profile = ai_profile
	home_position = enemy.global_position if enemy != null else Vector2.ZERO

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
	_search_anchor_reached = false
	_search_forward_direction = Vector2.ZERO
	_has_visual_history = false
	_hearing_cue_refresh_time_left = 0.0
	_proximity_cue_refresh_time_left = 0.0
	_search_phase = 0
	_search_perimeter_center = Vector2.ZERO
	_search_perimeter_radius = 0.0
	_search_perimeter_start_angle = 0.0
	_search_perimeter_direction_sign = 1.0
	_search_perimeter_point_count = 16
	_search_perimeter_step = 0
	_search_perimeter_target = Vector2.ZERO
	_sense_poll_time_left = 0.0


func clear_awareness_after_escape() -> void:
	# Conserva el target asignado para poder detectarlo otra vez en el futuro,
	# pero borra la persecución/memoria del combate que acaba de abandonar.
	_reset_perception_state()


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

	_sample_cooldown = maxf(_sample_cooldown - delta, 0.0)
	_sense_poll_time_left = maxf(_sense_poll_time_left - delta, 0.0)
	_search_retarget_time_left = maxf(_search_retarget_time_left - delta, 0.0)
	_hearing_cue_refresh_time_left = maxf(_hearing_cue_refresh_time_left - delta, 0.0)
	_proximity_cue_refresh_time_left = maxf(_proximity_cue_refresh_time_left - delta, 0.0)
	observation_age += delta

	if not is_instance_valid(owner_enemy):
		is_aware = false
		is_suspicious = false
		return

	if not is_instance_valid(target):
		has_line_of_sight = false
		heard_target = false
		proximity_detected = false
		_forget_over_time(delta)
		return

	if _sense_poll_time_left <= 0.0:
		_update_raw_senses(facing_direction)
		var distance_to_target := owner_enemy.global_position.distance_to(target.global_position)
		_sense_poll_time_left = profile.get_sense_poll_interval(
			distance_to_target,
			is_aware
		)

	# Detecta el instante en que un objetivo visible desaparece tras cobertura.
	# La IA no conoce la nueva posición oculta: conserva únicamente la última
	# observación que realmente llegó a percibir.
	if had_raw_visual_contact and not has_line_of_sight and is_aware:
		_enter_suspicion()

	_update_visual_contact_epoch()

	if is_instance_valid(target) and _sample_cooldown <= 0.0:
		var should_sample_cue := has_line_of_sight
		if heard_target and _hearing_cue_refresh_time_left <= 0.0:
			should_sample_cue = true
		elif (
			proximity_detected
			and not _has_visual_history
			and _proximity_cue_refresh_time_left <= 0.0
		):
			# Si ya hubo una observación visual real, PROX solo mantiene
			# awareness/sospecha. No toma otra posición exacta detrás de pared.
			should_sample_cue = true

		if should_sample_cue:
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


func abandon_current_search_probe() -> void:
	if not is_aware or has_line_of_sight or owner_enemy == null:
		return

	# RC7:
	# Un punto que el enemigo NO alcanzó no cuenta como perímetro recorrido.
	# La resolución del obstáculo queda a cargo del movimiento local del Enemy.
	#
	# Solo hay una excepción: el último punto visto (fase 0) puede ser
	# físicamente imposible por quedar dentro de una roca. En ese caso se toma
	# la posición alcanzable más cercana como centro y recién ahí se inicia
	# el perímetro.
	if _search_phase == 0:
		search_anchor_position = owner_enemy.global_position
		_begin_perimeter_search()

	_search_retarget_time_left = 0.0


func get_search_phase_label() -> String:
	match _search_phase:
		0:
			return "RUSH ULTIMO PUNTO"
		1:
			return "IR AL PERIMETRO"
		2:
			var percent := roundi(get_search_perimeter_progress() * 100.0)
			return "RECORRER PERIMETRO %d%%" % percent
		3:
			return "VOLVER IDLE"
		_:
			return "FIN"


func get_search_phase() -> int:
	return _search_phase


func is_search_rushing_to_last_seen() -> bool:
	return (
		is_aware
		and not has_line_of_sight
		and _search_phase == 0
	)


func is_search_walking_perimeter() -> bool:
	return (
		is_aware
		and not has_line_of_sight
		and _search_phase in [1, 2]
	)


func get_search_home_position() -> Vector2:
	return home_position


func get_search_perimeter_center() -> Vector2:
	if _search_perimeter_center != Vector2.ZERO:
		return _search_perimeter_center
	return search_anchor_position


func get_search_perimeter_radius() -> float:
	if _search_perimeter_radius > 0.0:
		return _search_perimeter_radius
	if profile == null:
		return 0.0

	# IQ100 recorre prácticamente el radio entero de visión.
	return profile.vision_range * lerpf(
		0.72,
		0.95,
		profile.get_intelligence_ratio()
	)


func get_search_perimeter_progress() -> float:
	if _search_phase < 2:
		return 0.0
	if _search_perimeter_point_count <= 0:
		return 0.0
	return clampf(
		float(_search_perimeter_step)
		/ float(_search_perimeter_point_count),
		0.0,
		1.0
	)


func get_search_perimeter_step() -> int:
	return _search_perimeter_step


func get_search_perimeter_point_count() -> int:
	return _search_perimeter_point_count


func get_search_perimeter_point(step: int) -> Vector2:
	if _search_perimeter_center == Vector2.ZERO:
		return Vector2.ZERO

	var count := maxi(_search_perimeter_point_count, 1)
	var safe_step := clampi(step, 0, count)
	var normalized_step := float(safe_step) / float(count)

	var angle := (
		_search_perimeter_start_angle
		+ TAU
		* normalized_step
		* _search_perimeter_direction_sign
	)

	return (
		_search_perimeter_center
		+ Vector2.RIGHT.rotated(angle)
		* _search_perimeter_radius
	)


func complete_search_perimeter_rejoin(rejoin_step: int) -> void:
	# Solo se llama cuando el enemigo alcanzó FÍSICAMENTE el punto futuro.
	var count := maxi(_search_perimeter_point_count, 1)
	var safe_step := clampi(rejoin_step, 0, count)

	if safe_step >= count:
		_search_phase = 3
		_search_perimeter_step = count
		_search_perimeter_target = home_position
		search_target_position = home_position
		return

	_search_phase = 2
	_search_perimeter_step = safe_step + 1
	_update_perimeter_target()


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
	has_line_of_sight = false
	heard_target = false
	proximity_detected = false

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

	var skill := profile.get_intelligence_ratio()
	if source == &"hearing":
		# El sonido actualiza una ZONA, no una coordenada GPS continua.
		_hearing_cue_refresh_time_left = lerpf(1.35, 0.72, skill)
	elif source == &"proximity":
		# Proximidad sirve para saber que "hay alguien muy cerca", pero no para
		# copiar cada desplazamiento detrás de una pared.
		_proximity_cue_refresh_time_left = lerpf(1.85, 1.05, skill)

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
	var previous_last_known_position := last_known_position
	var had_visual_history := _has_visual_history
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
	if source == &"hearing":
		position_error = maxf(
			position_error,
			lerpf(72.0, 26.0, skill)
		)
	elif source == &"proximity":
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

	if (
		source in [&"hearing", &"proximity"]
		and had_visual_history
		and not has_line_of_sight
	):
		# Tras haber visto al objetivo, una pista no visual mantiene awareness,
		# pero NO desplaza el último punto visto. La búsqueda territorial se ocupa
		# de barrer la zona completa.
		last_known_position = previous_last_known_position
		estimated_velocity = _last_seen_velocity * 0.15

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
		_has_visual_history = true
		last_seen_position = last_known_position
		_last_seen_velocity = estimated_velocity
		search_anchor_position = last_seen_position
		search_target_position = last_seen_position
		_search_forward_direction = estimated_velocity.normalized() if estimated_velocity.length_squared() > 1.0 else Vector2.ZERO
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

		# Una pista auditiva puede desplazar la búsqueda solo si representa un
		# cambio espacial importante. No sigue pequeñas variaciones detrás de muro.
		var retarget_threshold := maxf(
			profile.get_search_probe_radius() * 0.72,
			52.0
		)
		var should_retarget_search := (
			search_anchor_position == Vector2.ZERO
			or last_known_position.distance_to(search_anchor_position) >= retarget_threshold
		)

		# Si ya existe memoria visual, PROXIMITY solo mantiene sospecha/awareness.
		# No reemplaza el último punto realmente visto.
		if source in [&"hearing", &"proximity"] and had_visual_history:
			should_retarget_search = false

		if should_retarget_search:
			search_anchor_position = last_known_position
			search_target_position = last_known_position
			_search_forward_direction = estimated_velocity.normalized() if estimated_velocity.length_squared() > 1.0 else Vector2.ZERO
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

	# SEARCH RC6 usa el ÚLTIMO PUNTO REALMENTE VISTO como centro.
	# La trayectoria observada no mueve el centro: solo decide por qué sector
	# del perímetro empezar a buscar.
	search_anchor_position = last_seen_position

	if search_anchor_position == Vector2.ZERO:
		search_anchor_position = last_known_position

	search_target_position = search_anchor_position
	_search_forward_direction = _last_seen_velocity
	if _search_forward_direction.length_squared() < 1.0:
		_search_forward_direction = search_anchor_position - owner_enemy.global_position
	if _search_forward_direction.length_squared() > 0.001:
		_search_forward_direction = _search_forward_direction.normalized()
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

	var search_committed := (
		_has_visual_history
		and search_anchor_position != Vector2.ZERO
		and _search_phase >= 0
		and _search_phase <= 3
	)

	is_aware = (
		memory_time_left > 0.0
		or is_suspicious
		or search_committed
	)

	if not is_aware:
		observation_source = &"none"
		observation_confidence = 0.0
		estimated_velocity = Vector2.ZERO
		search_anchor_position = Vector2.ZERO
		search_target_position = Vector2.ZERO


func _update_search_plan(_delta: float) -> void:
	if not is_aware or has_line_of_sight or owner_enemy == null:
		return

	if search_anchor_position == Vector2.ZERO:
		search_anchor_position = last_seen_position
	if search_anchor_position == Vector2.ZERO:
		search_anchor_position = last_known_position

	if home_position == Vector2.ZERO:
		home_position = owner_enemy.global_position

	var arrival := maxf(profile.search_arrival_distance, 12.0)

	# ---------------------------------------------------------
	# FASE 0 — LLEGAR LO MÁS RÁPIDO POSIBLE AL ÚLTIMO PUNTO
	# ---------------------------------------------------------
	if _search_phase == 0:
		search_target_position = search_anchor_position

		if owner_enemy.global_position.distance_to(search_anchor_position) <= arrival:
			_begin_perimeter_search()
		return

	# ---------------------------------------------------------
	# FASE 1 — DESDE EL ÚLTIMO PUNTO IR AL BORDE DEL PERÍMETRO
	# ---------------------------------------------------------
	if _search_phase == 1:
		if _search_perimeter_target == Vector2.ZERO:
			_update_perimeter_target()

		search_target_position = _search_perimeter_target

		if owner_enemy.global_position.distance_to(search_target_position) <= arrival * 1.15:
			# Ya está en el borde. El punto 0 es el inicio; el paso 1 empieza
			# el recorrido real de la circunferencia.
			_search_phase = 2
			_search_perimeter_step = 1
			_update_perimeter_target()
		return

	# ---------------------------------------------------------
	# FASE 2 — CAMINAR TODA LA VUELTA DEL PERÍMETRO
	# ---------------------------------------------------------
	if _search_phase == 2:
		if _search_perimeter_step > _search_perimeter_point_count:
			_search_phase = 3
			search_target_position = home_position
			return

		if _search_perimeter_target == Vector2.ZERO:
			_update_perimeter_target()

		search_target_position = _search_perimeter_target

		if owner_enemy.global_position.distance_to(search_target_position) <= arrival * 1.20:
			_search_perimeter_step += 1

			if _search_perimeter_step > _search_perimeter_point_count:
				_search_phase = 3
				search_target_position = home_position
			else:
				_update_perimeter_target()
		return

	# ---------------------------------------------------------
	# FASE 3 — VUELTA COMPLETA SIN ENCONTRARLO: REGRESAR AL IDLE
	# ---------------------------------------------------------
	if _search_phase == 3:
		search_target_position = home_position

		if owner_enemy.global_position.distance_to(home_position) <= arrival * 1.25:
			_finish_full_search_sweep()
		return


func _begin_perimeter_search() -> void:
	_search_phase = 1
	_search_perimeter_center = search_anchor_position
	_search_perimeter_radius = get_search_perimeter_radius()

	var skill := profile.get_intelligence_ratio()

	# IQ alto usa más puntos: la circunferencia se ve suave y cubre mejor.
	_search_perimeter_point_count = clampi(
		roundi(lerpf(10.0, 20.0, skill)),
		10,
		20
	)

	var forward := _search_forward_direction
	if forward.length_squared() < 0.001:
		forward = _last_seen_velocity
	if forward.length_squared() < 0.001:
		forward = search_anchor_position - home_position
	if forward.length_squared() < 0.001:
		forward = Vector2.RIGHT
	forward = forward.normalized()

	# Empieza la circunferencia por el sector hacia el que vio desplazarse al
	# Player por última vez.
	_search_perimeter_start_angle = forward.angle()

	var tangent := forward.orthogonal()
	if _last_seen_velocity.length_squared() > 1.0:
		_search_perimeter_direction_sign = (
			1.0
			if tangent.dot(_last_seen_velocity.normalized()) >= 0.0
			else -1.0
		)
	else:
		_search_perimeter_direction_sign = (
			1.0
			if _random.randf() >= 0.5
			else -1.0
		)

	_search_perimeter_step = 0
	_update_perimeter_target()


func _update_perimeter_target() -> void:
	if _search_perimeter_center == Vector2.ZERO:
		_search_perimeter_center = search_anchor_position

	if _search_perimeter_radius <= 0.0:
		_search_perimeter_radius = get_search_perimeter_radius()

	_search_perimeter_target = get_search_perimeter_point(
		_search_perimeter_step
	)
	search_target_position = _search_perimeter_target


func _finish_full_search_sweep() -> void:
	is_aware = false
	is_suspicious = false
	has_confirmed_visual_contact = false
	memory_time_left = 0.0
	suspicion_time_left = 0.0
	observation_source = &"memory"
	observation_confidence *= 0.35
	search_target_position = home_position
	_search_perimeter_target = Vector2.ZERO
	_search_phase = 4


func _reset_search_pattern() -> void:
	_search_probe_index = 0
	_search_anchor_reached = false
	_search_probe_limit = (
		profile.get_search_probe_count()
		if profile != null
		else 1
	)
	_search_retarget_time_left = 0.0

	_search_phase = 0
	_search_perimeter_center = Vector2.ZERO
	_search_perimeter_radius = 0.0
	_search_perimeter_start_angle = 0.0
	_search_perimeter_direction_sign = 1.0
	_search_perimeter_point_count = 16
	_search_perimeter_step = 0
	_search_perimeter_target = Vector2.ZERO


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
