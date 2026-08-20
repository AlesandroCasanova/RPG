class_name EnemyCombatMemory
extends RefCounted


var owner_enemy: CharacterBody2D = null
var profile: EnemyAIProfile = null

var _clock: float = 0.0
var _last_observation_sequence: int = -1

var _last_action: StringName = &"none"
var _last_phase: StringName = &"none"
var _last_locomotion: StringName = &"idle"
var _last_offensive_signature: StringName = &"none"
var _last_offensive_signature_age: float = 999.0

var _attack_signal: float = 0.0
var _charge_signal: float = 0.0
var _recovery_signal: float = 0.0
var _dash_signal: float = 0.0
var _approach_signal: float = 0.0
var _retreat_signal: float = 0.0
var _lateral_signal: float = 0.0
var _repeat_signal: float = 0.0
var _dash_then_attack_signal: float = 0.0
var _recent_dash_time: float = 999.0

var _damage_received_signal: float = 0.0
var _windup_punished_signal: float = 0.0

# Memoria de combinaciones observadas.
var _event_chain: Array[StringName] = []
var _event_times: Array[float] = []
var _pattern_weights: Dictionary = {}
var _last_event_token: StringName = &"none"
var _last_event_time: float = -999.0

var _attack_outcomes: Dictionary = {
	&"primary": {"hits": 0.0, "attempts": 0.0},
	&"heavy": {"hits": 0.0, "attempts": 0.0},
	&"charged": {"hits": 0.0, "attempts": 0.0},
	&"other": {"hits": 0.0, "attempts": 0.0}
}


func configure(
	enemy: CharacterBody2D,
	ai_profile: EnemyAIProfile
) -> void:
	owner_enemy = enemy
	profile = ai_profile


func update(
	delta: float,
	observed: Dictionary,
	has_confirmed_visual_contact: bool,
	enemy_position: Vector2
) -> void:
	if profile == null:
		return

	_clock += delta
	_recent_dash_time += maxf(delta, 0.0)
	_last_offensive_signature_age += maxf(delta, 0.0)
	_decay(delta)

	if not profile.is_capability_enabled(EnemyAIProfile.CAP_ADAPT_ATTACKS):
		return

	if not has_confirmed_visual_contact:
		return

	if StringName(observed.get("source", &"none")) != &"vision":
		return

	var sequence := int(observed.get("sequence", -1))
	if sequence < 0 or sequence == _last_observation_sequence:
		return
	_last_observation_sequence = sequence

	var confidence := clampf(
		float(observed.get("confidence", 0.0)),
		0.0,
		1.0
	)
	if confidence <= 0.01:
		return

	var weight := confidence * profile.get_combat_learning_strength()
	if weight <= 0.0:
		return

	var action := StringName(observed.get("action", &"none"))
	var phase := StringName(observed.get("phase", &"none"))
	var locomotion := StringName(observed.get("locomotion", &"idle"))
	var attack_family := StringName(observed.get("attack_family", &"none"))

	# DASH es un evento de secuencia.
	if locomotion == &"dash" and _last_locomotion != &"dash":
		_dash_signal += weight
		_recent_dash_time = 0.0
		_record_behavior_event(&"dash", weight)

	# CHARGE es un evento separado para aprender charge -> dash -> attack.
	if action == &"charge" and _last_action != &"charge":
		_charge_signal += weight
		_record_behavior_event(&"charge", weight)

	var offensive_now := action in [&"attack", &"charge"]
	var offensive_before := _last_action in [&"attack", &"charge"]

	if offensive_now and not offensive_before:
		_attack_signal += weight

		var signature := (
			attack_family
			if attack_family != &"none"
			else action
		)

		if action != &"charge":
			_record_behavior_event(signature, weight)

		if _recent_dash_time <= 0.95 and action != &"charge":
			_dash_then_attack_signal += weight

		_record_offensive_signature(signature, weight)

	if phase == &"recovery" and _last_phase != &"recovery":
		_recovery_signal += weight

	_learn_movement_tendency(
		observed,
		enemy_position,
		weight
	)

	_last_action = action
	_last_phase = phase
	_last_locomotion = locomotion


func record_enemy_attack_result(
	attack_key: StringName,
	hit: bool
) -> void:
	if profile == null:
		return
	if not profile.is_capability_enabled(EnemyAIProfile.CAP_ADAPT_ATTACKS):
		return

	var key := attack_key
	if not _attack_outcomes.has(key):
		key = &"other"

	var stats := Dictionary(_attack_outcomes[key])
	stats["attempts"] = float(stats.get("attempts", 0.0)) + 1.0
	if hit:
		stats["hits"] = float(stats.get("hits", 0.0)) + 1.0
	_attack_outcomes[key] = stats


func record_damage_received(was_in_windup: bool) -> void:
	if profile == null:
		return
	if not profile.is_capability_enabled(EnemyAIProfile.CAP_ADAPT_ATTACKS):
		return

	var weight := maxf(profile.get_combat_learning_strength(), 0.05)
	_damage_received_signal += weight

	if was_in_windup:
		_windup_punished_signal += weight


func get_context() -> Dictionary:
	if profile == null:
		return _empty_context()

	if not profile.is_capability_enabled(EnemyAIProfile.CAP_ADAPT_ATTACKS):
		return _empty_context()

	var dominant := _get_dominant_pattern()
	var dominant_key := String(dominant.get("key", ""))
	var dominant_weight := float(dominant.get("weight", 0.0))
	var pattern_confidence := _get_pattern_confidence(dominant_weight)

	var repeat_confidence := _saturate_signal(_repeat_signal, 2.8)
	var dash_attack_confidence := _saturate_signal(
		_dash_then_attack_signal,
		2.5
	)

	# MEM ahora significa: "confianza actual en que reconocí un patrón".
	# No es tiempo de combate ni cantidad total de observaciones.
	var adaptive_confidence := maxf(
		pattern_confidence,
		repeat_confidence * 0.72
	)
	adaptive_confidence = maxf(
		adaptive_confidence,
		dash_attack_confidence * 0.78
	)
	adaptive_confidence = minf(
		adaptive_confidence,
		profile.get_adaptive_confidence_cap()
	)

	var movement_total := (
		_approach_signal
		+ _retreat_signal
		+ _lateral_signal
	)

	var approach_tendency := 0.0
	var retreat_tendency := 0.0
	var lateral_tendency := 0.0

	if movement_total > 0.001:
		approach_tendency = _approach_signal / movement_total
		retreat_tendency = _retreat_signal / movement_total
		lateral_tendency = _lateral_signal / movement_total

	var attack_pressure := _saturate_signal(_attack_signal, 3.0)

	var charge_tendency := 0.0
	if _attack_signal > 0.001:
		charge_tendency = clampf(
			_charge_signal / _attack_signal,
			0.0,
			1.0
		)

	var punishes_windup := 0.0
	if _damage_received_signal > 0.001:
		punishes_windup = clampf(
			_windup_punished_signal / _damage_received_signal,
			0.0,
			1.0
		)

	var primary_stats := _get_attack_outcome_context(&"primary")
	var heavy_stats := _get_attack_outcome_context(&"heavy")
	var charged_stats := _get_attack_outcome_context(&"charged")

	return {
		"adaptive_confidence": clampf(adaptive_confidence, 0.0, 1.0),
		"dominant_pattern": dominant_key,
		"dominant_pattern_confidence": pattern_confidence,
		"player_attack_pressure": attack_pressure,
		"player_charge_tendency": charge_tendency,
		"player_dash_tendency": _saturate_signal(_dash_signal, 2.5),
		"player_dash_attack_tendency": maxf(
			dash_attack_confidence,
			_pattern_contains_confidence("dash>")
		),
		"player_recovery_exposure": _saturate_signal(_recovery_signal, 3.0),
		"player_approach_tendency": clampf(approach_tendency, 0.0, 1.0),
		"player_retreat_tendency": clampf(retreat_tendency, 0.0, 1.0),
		"player_lateral_tendency": clampf(lateral_tendency, 0.0, 1.0),
		"player_repeat_tendency": maxf(
			repeat_confidence,
			pattern_confidence
		),
		"player_punishes_windup": punishes_windup,
		"primary_success": float(primary_stats.get("success", 0.5)),
		"primary_success_confidence": float(primary_stats.get("confidence", 0.0)),
		"heavy_success": float(heavy_stats.get("success", 0.5)),
		"heavy_success_confidence": float(heavy_stats.get("confidence", 0.0)),
		"charged_success": float(charged_stats.get("success", 0.5)),
		"charged_success_confidence": float(charged_stats.get("confidence", 0.0))
	}


func get_debug_summary() -> String:
	var context := get_context()

	var confidence := roundi(
		float(context.get("adaptive_confidence", 0.0)) * 100.0
	)
	var pressure := roundi(
		float(context.get("player_attack_pressure", 0.0)) * 100.0
	)
	var charge := roundi(
		float(context.get("player_charge_tendency", 0.0)) * 100.0
	)
	var repeat := roundi(
		float(context.get("player_repeat_tendency", 0.0)) * 100.0
	)

	var pattern := String(context.get("dominant_pattern", ""))
	if pattern.is_empty():
		pattern = "-"

	return "MEM %d%% | PRES %d%% | CARGA %d%% | REP %d%% | PAT %s" % [
		confidence,
		pressure,
		charge,
		repeat,
		pattern
	]


func _record_behavior_event(
	token: StringName,
	weight: float
) -> void:
	if token == &"none":
		return

	# Evita que varias muestras del mismo evento creen una combinación falsa.
	if (
		token == _last_event_token
		and _clock - _last_event_time <= 0.18
	):
		return

	# Un silencio largo corta la cadena de combo.
	if _clock - _last_event_time > 2.40:
		_event_chain.clear()
		_event_times.clear()

	_event_chain.append(token)
	_event_times.append(_clock)
	_last_event_token = token
	_last_event_time = _clock

	while _event_chain.size() > 4:
		_event_chain.pop_front()
		_event_times.pop_front()

	# Aprende secuencias de 2 y 3 eventos.
	for length in range(2, mini(_event_chain.size(), 3) + 1):
		var start_index := _event_chain.size() - length
		var key := _make_pattern_key(start_index)
		var multiplier := 0.72 if length == 2 else 1.0
		_pattern_weights[key] = (
			float(_pattern_weights.get(key, 0.0))
			+ weight * multiplier
		)


func _make_pattern_key(start_index: int) -> String:
	var parts: PackedStringArray = []

	for i in range(start_index, _event_chain.size()):
		parts.append(String(_event_chain[i]))

	return ">".join(parts)


func _record_offensive_signature(
	signature: StringName,
	weight: float
) -> void:
	var repeat_window := maxf(
		profile.get_combat_memory_half_life() * 0.55,
		2.2
	)

	if (
		signature != &"none"
		and _last_offensive_signature != &"none"
		and signature == _last_offensive_signature
		and _last_offensive_signature_age <= repeat_window
	):
		_repeat_signal += weight

	if signature != &"none":
		_last_offensive_signature = signature
		_last_offensive_signature_age = 0.0


func _get_dominant_pattern() -> Dictionary:
	var best_key := ""
	var best_weight := 0.0

	for key_variant: Variant in _pattern_weights.keys():
		var key := String(key_variant)
		var weight := float(_pattern_weights[key_variant])

		if weight > best_weight:
			best_weight = weight
			best_key = key

	return {
		"key": best_key,
		"weight": best_weight
	}


func _get_pattern_confidence(weight: float) -> float:
	# Una sola observación NO constituye aprendizaje.
	var baseline := 1.20
	var useful_weight := maxf(weight - baseline, 0.0)

	if useful_weight <= 0.0:
		return 0.0

	var required := maxf(
		profile.get_pattern_evidence_required(),
		1.5
	)

	var result := 1.0 - exp(
		-useful_weight / required
	)

	return minf(
		clampf(result, 0.0, 1.0),
		profile.get_adaptive_confidence_cap()
	)


func _pattern_contains_confidence(fragment: String) -> float:
	var best := 0.0

	for key_variant: Variant in _pattern_weights.keys():
		var key := String(key_variant)
		if not key.contains(fragment):
			continue

		best = maxf(
			best,
			_get_pattern_confidence(
				float(_pattern_weights[key_variant])
			)
		)

	return best


func _learn_movement_tendency(
	observed: Dictionary,
	enemy_position: Vector2,
	weight: float
) -> void:
	var target_position := Vector2(
		observed.get(
			"estimated_position",
			observed.get("position", Vector2.ZERO)
		)
	)
	var target_velocity := Vector2(
		observed.get("estimated_velocity", Vector2.ZERO)
	)

	if target_velocity.length_squared() < 100.0:
		return

	var to_enemy := enemy_position - target_position
	if to_enemy.length_squared() < 0.001:
		return

	var radial_alignment := (
		target_velocity.normalized()
		.dot(to_enemy.normalized())
	)

	var sample_weight := weight * 0.22

	if radial_alignment > 0.35:
		_approach_signal += sample_weight * radial_alignment
	elif radial_alignment < -0.35:
		_retreat_signal += sample_weight * absf(radial_alignment)
	else:
		_lateral_signal += sample_weight * (1.0 - absf(radial_alignment))


func _get_attack_outcome_context(
	attack_key: StringName
) -> Dictionary:
	var stats := Dictionary(
		_attack_outcomes.get(
			attack_key,
			{"hits": 0.0, "attempts": 0.0}
		)
	)

	var hits := maxf(float(stats.get("hits", 0.0)), 0.0)
	var attempts := maxf(float(stats.get("attempts", 0.0)), 0.0)

	var success := (hits + 1.0) / (attempts + 2.0)
	var confidence := 1.0 - exp(-attempts / 3.0)

	return {
		"success": clampf(success, 0.0, 1.0),
		"confidence": clampf(confidence, 0.0, 1.0)
	}


func _decay(delta: float) -> void:
	var half_life := profile.get_combat_memory_half_life()
	var factor := pow(
		0.5,
		delta / maxf(half_life, 0.001)
	)

	_attack_signal *= factor
	_charge_signal *= factor
	_recovery_signal *= factor
	_dash_signal *= factor
	_approach_signal *= factor
	_retreat_signal *= factor
	_lateral_signal *= factor
	_damage_received_signal *= factor
	_windup_punished_signal *= factor

	# Las repeticiones/combinaciones cambian más rápido que una tendencia general.
	var pattern_half_life := maxf(half_life * 0.55, 0.75)
	var pattern_factor := pow(
		0.5,
		delta / pattern_half_life
	)

	_repeat_signal *= pattern_factor
	_dash_then_attack_signal *= pattern_factor

	var remove_keys: Array = []
	for key_variant: Variant in _pattern_weights.keys():
		var decayed := (
			float(_pattern_weights[key_variant])
			* pattern_factor
		)
		if decayed <= 0.025:
			remove_keys.append(key_variant)
		else:
			_pattern_weights[key_variant] = decayed

	for key_variant: Variant in remove_keys:
		_pattern_weights.erase(key_variant)

	if _last_offensive_signature_age > maxf(half_life, 3.0):
		_last_offensive_signature = &"none"

	if _clock - _last_event_time > 2.40:
		_event_chain.clear()
		_event_times.clear()

	for key_variant: Variant in _attack_outcomes.keys():
		var stats := Dictionary(_attack_outcomes[key_variant])
		stats["hits"] = float(stats.get("hits", 0.0)) * factor
		stats["attempts"] = float(stats.get("attempts", 0.0)) * factor
		_attack_outcomes[key_variant] = stats


func _saturate_signal(
	value: float,
	scale: float
) -> float:
	return clampf(
		1.0 - exp(
			-maxf(value, 0.0)
			/ maxf(scale, 0.001)
		),
		0.0,
		1.0
	)


func _empty_context() -> Dictionary:
	return {
		"adaptive_confidence": 0.0,
		"dominant_pattern": "",
		"dominant_pattern_confidence": 0.0,
		"player_attack_pressure": 0.0,
		"player_charge_tendency": 0.0,
		"player_dash_tendency": 0.0,
		"player_dash_attack_tendency": 0.0,
		"player_recovery_exposure": 0.0,
		"player_approach_tendency": 0.0,
		"player_retreat_tendency": 0.0,
		"player_lateral_tendency": 0.0,
		"player_repeat_tendency": 0.0,
		"player_punishes_windup": 0.0,
		"primary_success": 0.5,
		"primary_success_confidence": 0.0,
		"heavy_success": 0.5,
		"heavy_success_confidence": 0.0,
		"charged_success": 0.5,
		"charged_success_confidence": 0.0
	}
