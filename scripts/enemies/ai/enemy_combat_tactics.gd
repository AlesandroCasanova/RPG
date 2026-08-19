class_name EnemyCombatTactics
extends RefCounted


const STANCE_NEUTRAL: StringName = &"neutral"
const STANCE_AGGRESSIVE: StringName = &"aggressive"
const STANCE_DEFENSIVE: StringName = &"defensive"
const STANCE_PRESSURE: StringName = &"pressure"
const STANCE_PUNISH: StringName = &"punish"


var profile: EnemyAIProfile = null
var current_stance: StringName = STANCE_NEUTRAL
var stance_time_left: float = 0.0

var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func configure(ai_profile: EnemyAIProfile, seed_offset: int = 0) -> void:
	profile = ai_profile
	if profile != null and profile.deterministic_seed > 0:
		_random.seed = profile.deterministic_seed + seed_offset * 104729
	else:
		_random.randomize()


func update(delta: float) -> void:
	stance_time_left = maxf(stance_time_left - delta, 0.0)


# =========================================================
# POSTURA DE COMBATE
# =========================================================

func select_stance(context: Dictionary) -> StringName:
	if profile == null:
		current_stance = STANCE_NEUTRAL
		return current_stance

	var threat_danger := clampf(float(context.get("threat_danger", 0.0)), 0.0, 1.0)
	var health_ratio := clampf(float(context.get("health_ratio", 1.0)), 0.0, 1.0)
	var stamina_ratio := clampf(float(context.get("stamina_ratio", 1.0)), 0.0, 1.0)
	var target_phase := StringName(context.get("target_phase", &"none"))
	var target_action := StringName(context.get("target_action", &"none"))
	var role := StringName(context.get("role", &"support"))
	var can_attack := bool(context.get("can_attack", false))
	var target_recovering := target_phase == &"recovery"
	var emergency := threat_danger >= 0.72 or health_ratio <= profile.retreat_health_ratio * 0.65

	if stance_time_left > 0.0 and not emergency:
		return current_stance

	var scores: Dictionary = {
		STANCE_NEUTRAL: 0.75,
		STANCE_AGGRESSIVE: 0.0,
		STANCE_DEFENSIVE: 0.0,
		STANCE_PRESSURE: 0.0,
		STANCE_PUNISH: 0.0
	}

	var aggression_score := profile.aggression * 0.62 + stamina_ratio * 0.38
	if can_attack:
		aggression_score += 0.22
	if role == &"pressure":
		aggression_score += 0.18
	scores[STANCE_AGGRESSIVE] = aggression_score

	var defensive_score := threat_danger * 1.35
	defensive_score += (1.0 - health_ratio) * (1.25 - minf(profile.courage * 0.18, 0.35))
	defensive_score += (1.0 - stamina_ratio) * 0.42
	if target_action in [&"attack", &"charge"]:
		defensive_score += 0.12
	scores[STANCE_DEFENSIVE] = defensive_score

	var pressure_score := profile.aggression * 0.42 + stamina_ratio * 0.30
	if role in [&"pressure", &"flank"]:
		pressure_score += 0.34
	if target_phase == &"telegraph" and threat_danger < 0.35:
		pressure_score += 0.16
	scores[STANCE_PRESSURE] = pressure_score

	var punish_score := 0.0
	if target_recovering:
		punish_score += 1.20
	if target_action == &"charge" and threat_danger < 0.42:
		punish_score += 0.42
	punish_score += clampf(float(context.get("player_recovery_exposure", 0.0)), 0.0, 1.0) * 0.32
	scores[STANCE_PUNISH] = punish_score

	for stance: Variant in scores:
		scores[stance] = float(scores[stance]) * profile.get_personality_stance_multiplier(StringName(stance))

	var best_stance: StringName = STANCE_NEUTRAL
	var best_score := -INF
	for stance: Variant in scores:
		var score := float(scores[stance])
		if score > best_score:
			best_score = score
			best_stance = StringName(stance)

	if best_stance != current_stance:
		current_stance = best_stance
		stance_time_left = profile.get_stance_lock_time()

	return current_stance


# =========================================================
# PREDICCION DE TRAYECTORIA
# =========================================================

func get_predicted_target_position(
	observed: Dictionary,
	fallback_position: Vector2,
	attack: AttackData = null
) -> Vector2:
	if profile == null or not profile.is_capability_enabled(EnemyAIProfile.CAP_PREDICT):
		return fallback_position

	var observed_position := Vector2(observed.get("estimated_position", fallback_position))
	var observed_velocity := Vector2(observed.get("estimated_velocity", Vector2.ZERO))
	if observed_velocity.length_squared() < 1.0:
		return observed_position

	var horizon := profile.get_prediction_horizon()
	if attack != null:
		var commitment := maxf(attack.windup_time + attack.charge_time, 0.0)
		horizon += minf(commitment, profile.predictive_attack_extra_horizon)

	var lead := observed_velocity * horizon
	if lead.length() > profile.maximum_predictive_lead:
		lead = lead.normalized() * profile.maximum_predictive_lead

	return observed_position + lead


# =========================================================
# MODELO DE AMENAZA OBSERVABLE
# =========================================================
# No consulta hitboxes privadas del Player. Construye una aproximacion espacial
# usando solamente posicion, facing, fase y familia observadas por Perception.

func build_observed_threat(
	enemy_position: Vector2,
	observed: Dictionary
) -> Dictionary:
	var empty := {
		"active": false,
		"danger": 0.0,
		"origin": Vector2.ZERO,
		"center": Vector2.ZERO,
		"direction": Vector2.DOWN,
		"half_length": 0.0,
		"half_width": 0.0,
		"phase": &"none"
	}
	if profile == null or not profile.is_capability_enabled(EnemyAIProfile.CAP_READ_TELEGRAPHS):
		return empty

	var action := StringName(observed.get("action", &"none"))
	var phase := StringName(observed.get("phase", &"none"))
	if action not in [&"attack", &"charge"]:
		return empty
	if phase not in [&"telegraph", &"active"]:
		return empty

	var direction := Vector2(observed.get("facing", Vector2.ZERO))
	if direction.length_squared() < 0.001:
		return empty
	direction = direction.normalized()

	var origin := Vector2(observed.get("estimated_position", Vector2.ZERO))
	var observed_velocity := Vector2(observed.get("estimated_velocity", Vector2.ZERO))
	var prediction_strength := profile.get_threat_prediction_strength()
	if observed_velocity.length_squared() > 1.0:
		var reaction_lead := observed_velocity * profile.get_reaction_time() * 0.45 * prediction_strength
		if reaction_lead.length() > profile.maximum_predictive_lead * 0.55:
			reaction_lead = reaction_lead.normalized() * profile.maximum_predictive_lead * 0.55
		origin += reaction_lead

	var length := profile.player_threat_length_estimate
	var width := profile.player_threat_width_estimate
	var family := StringName(observed.get("attack_family", &"none"))
	var charge_stage := StringName(observed.get("charge_stage", &"none"))

	if family == &"heavy":
		length *= profile.heavy_threat_length_multiplier
		width *= lerpf(1.0, profile.heavy_threat_length_multiplier, 0.45)
	elif family == &"charged" or charge_stage == &"ready":
		length *= profile.charged_threat_length_multiplier
		width *= lerpf(1.0, profile.charged_threat_length_multiplier, 0.55)
	elif action == &"charge":
		length *= profile.heavy_threat_length_multiplier

	var start_offset := profile.player_threat_start_offset_estimate
	var center := origin + direction * (start_offset + length * 0.5)
	var half_length := length * 0.5 + profile.predictive_dodge_safety_padding
	var half_width := width * 0.5 + profile.predictive_dodge_safety_padding
	var danger := _danger_at_point(enemy_position, center, direction, half_length, half_width)

	if phase == &"active":
		danger = clampf(danger * 1.12 + 0.08, 0.0, 1.0)
	else:
		danger *= lerpf(0.72, 1.0, prediction_strength)

	return {
		"active": true,
		"danger": danger,
		"origin": origin,
		"center": center,
		"direction": direction,
		"half_length": half_length,
		"half_width": half_width,
		"phase": phase,
		"family": family
	}


func get_evasion_candidates(
	enemy_position: Vector2,
	threat: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile == null or not bool(threat.get("active", false)):
		return result

	var attack_direction := Vector2(threat.get("direction", Vector2.DOWN)).normalized()
	var left := attack_direction.rotated(-PI * 0.5)
	var right := attack_direction.rotated(PI * 0.5)
	var back := -attack_direction
	var distance := profile.predictive_dodge_step_distance

	var candidates: Array[Vector2] = [
		left,
		right,
		(back + left * 0.75).normalized(),
		(back + right * 0.75).normalized(),
		back
	]

	for direction: Vector2 in candidates:
		var destination := enemy_position + direction * distance
		var danger_after := _danger_at_point(
			destination,
			Vector2(threat.get("center", Vector2.ZERO)),
			attack_direction,
			float(threat.get("half_length", 0.0)),
			float(threat.get("half_width", 0.0))
		)
		var lateral_value := absf(direction.dot(attack_direction.orthogonal()))
		var score := (1.0 - danger_after) * 1.35 + lateral_value * 0.28
		result.append({
			"direction": direction,
			"destination": destination,
			"danger_after": danger_after,
			"score": score
		})

	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	return result


func _danger_at_point(
	point: Vector2,
	center: Vector2,
	direction: Vector2,
	half_length: float,
	half_width: float
) -> float:
	if half_length <= 0.0 or half_width <= 0.0:
		return 0.0
	var relative := point - center
	var forward := absf(relative.dot(direction))
	var lateral := absf(relative.dot(direction.orthogonal()))
	var nx := forward / maxf(half_length, 0.001)
	var ny := lateral / maxf(half_width, 0.001)
	var edge := maxf(nx, ny)
	if edge >= 1.35:
		return 0.0
	return clampf(1.0 - (edge - 0.65) / 0.70, 0.0, 1.0)


func get_debug_stance_label() -> String:
	match current_stance:
		STANCE_AGGRESSIVE:
			return "AGRES"
		STANCE_DEFENSIVE:
			return "DEF"
		STANCE_PRESSURE:
			return "PRES"
		STANCE_PUNISH:
			return "CASTIGO"
		_:
			return "NEUTRO"
