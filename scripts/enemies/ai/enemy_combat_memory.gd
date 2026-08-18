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

var _attack_signal: float = 0.0
var _charge_signal: float = 0.0
var _recovery_signal: float = 0.0
var _dash_signal: float = 0.0
var _approach_signal: float = 0.0
var _retreat_signal: float = 0.0
var _lateral_signal: float = 0.0
var _repeat_signal: float = 0.0

var _damage_received_signal: float = 0.0
var _windup_punished_signal: float = 0.0
var _evidence: float = 0.0

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

	var confidence := clampf(float(observed.get("confidence", 0.0)), 0.0, 1.0)
	if confidence <= 0.01:
		return

	var learning_weight := confidence * profile.get_combat_learning_strength()
	if learning_weight <= 0.0:
		return

	var action := StringName(observed.get("action", &"none"))
	var phase := StringName(observed.get("phase", &"none"))
	var locomotion := StringName(observed.get("locomotion", &"idle"))
	var attack_family := StringName(observed.get("attack_family", &"none"))

	var offensive_now := action in [&"attack", &"charge"]
	var offensive_before := _last_action in [&"attack", &"charge"]

	if offensive_now and not offensive_before:
		_attack_signal += learning_weight
		_record_offensive_signature(
			attack_family if attack_family != &"none" else action,
			learning_weight
		)

	if action == &"charge" and _last_action != &"charge":
		_charge_signal += learning_weight

	if phase == &"recovery" and _last_phase != &"recovery":
		_recovery_signal += learning_weight

	if locomotion == &"dash" and _last_locomotion != &"dash":
		_dash_signal += learning_weight

	_learn_movement_tendency(
		observed,
		enemy_position,
		learning_weight
	)

	_evidence += learning_weight

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

	_evidence += profile.get_combat_learning_strength() * 0.75


func record_damage_received(was_in_windup: bool) -> void:
	if profile == null:
		return
	if not profile.is_capability_enabled(EnemyAIProfile.CAP_ADAPT_ATTACKS):
		return

	var weight := maxf(profile.get_combat_learning_strength(), 0.05)
	_damage_received_signal += weight
	if was_in_windup:
		_windup_punished_signal += weight
	_evidence += weight * 0.75
	else:
		_evidence += weight * 0.25


func get_context() -> Dictionary:
	if profile == null:
		return _empty_context()

	if not profile.is_capability_enabled(EnemyAIProfile.CAP_ADAPT_ATTACKS):
		return _empty_context()

	var evidence_required := profile.get_pattern_evidence_required()
	var adaptive_confidence := 1.0 - exp(
		-_evidence / maxf(evidence_required, 0.001)
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
		"player_attack_pressure": attack_pressure,
		"player_charge_tendency": charge_tendency,
		"player_dash_tendency": _saturate_signal(_dash_signal, 2.5),
		"player_recovery_exposure": _saturate_signal(_recovery_signal, 3.0),
		"player_approach_tendency": clampf(approach_tendency, 0.0, 1.0),
		"player_retreat_tendency": clampf(retreat_tendency, 0.0, 1.0),
		"player_lateral_tendency": clampf(lateral_tendency, 0.0, 1.0),
		"player_repeat_tendency": _saturate_signal(_repeat_signal, 2.0),
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
	return "MEM %d%% | PRES %d%% | CARGA %d%%" % [
		confidence,
		pressure,
		charge
	]


func _learn_movement_tendency(
	observed: Dictionary,
	enemy_position: Vector2,
	weight: float
) -> void:
	var target_position := Vector2(
		observed.get("estimated_position", observed.get("position", Vector2.ZERO))
	)
	var target_velocity := Vector2(observed.get("estimated_velocity", Vector2.ZERO))

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


func _record_offensive_signature(
	signature: StringName,
	weight: float
) -> void:
	if (
		signature != &"none"
		and _last_offensive_signature != &"none"
		and signature == _last_offensive_signature
	):
		_repeat_signal += weight

	if signature != &"none":
		_last_offensive_signature = signature


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
	var factor := pow(0.5, delta / maxf(half_life, 0.001))

	_attack_signal *= factor
	_charge_signal *= factor
	_recovery_signal *= factor
	_dash_signal *= factor
	_approach_signal *= factor
	_retreat_signal *= factor
	_lateral_signal *= factor
	_repeat_signal *= factor
	_damage_received_signal *= factor
	_windup_punished_signal *= factor
	_evidence *= factor

	for key: Variant in _attack_outcomes.keys():
		var stats := Dictionary(_attack_outcomes[key])
		stats["hits"] = float(stats.get("hits", 0.0)) * factor
		stats["attempts"] = float(stats.get("attempts", 0.0)) * factor
		_attack_outcomes[key] = stats


func _saturate_signal(value: float, scale: float) -> float:
	return clampf(
		1.0 - exp(-maxf(value, 0.0) / maxf(scale, 0.001)),
		0.0,
		1.0
	)


func _empty_context() -> Dictionary:
	return {
		"adaptive_confidence": 0.0,
		"player_attack_pressure": 0.0,
		"player_charge_tendency": 0.0,
		"player_dash_tendency": 0.0,
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
