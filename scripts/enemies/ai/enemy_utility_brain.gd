class_name EnemyUtilityBrain
extends RefCounted


const ACTION_ATTACK: StringName = &"attack"
const ACTION_APPROACH: StringName = &"approach"
const ACTION_FLANK: StringName = &"flank"
const ACTION_HOLD: StringName = &"hold"
const ACTION_RETREAT: StringName = &"retreat"
const ACTION_SEARCH: StringName = &"search"
const ACTION_CIRCLE: StringName = &"circle"
const ACTION_COVER: StringName = &"cover"
const ACTION_DODGE: StringName = &"dodge"
const ACTION_INTERRUPT: StringName = &"interrupt"


var profile: EnemyAIProfile
var current_action: StringName = ACTION_HOLD
var commitment_time_left := 0.0
var decision_time_left := 0.0
var last_raw_scores: Dictionary = {}
var last_scores: Dictionary = {}
var last_decision_confidence := 0.0
var last_selected_score := 0.0
var last_was_mistake := false

var _random := RandomNumberGenerator.new()


func configure(ai_profile: EnemyAIProfile, seed_offset: int = 0) -> void:
	profile = ai_profile
	if profile.deterministic_seed > 0:
		_random.seed = profile.deterministic_seed + seed_offset * 7919
	else:
		_random.randomize()
	decision_time_left = _random.randf_range(0.0, profile.get_effective_decision_interval())


func update_timers(delta: float) -> void:
	decision_time_left = maxf(decision_time_left - delta, 0.0)
	commitment_time_left = maxf(commitment_time_left - delta, 0.0)


func should_reconsider(force: bool = false) -> bool:
	return force or (decision_time_left <= 0.0 and commitment_time_left <= 0.0)


func decide(context: Dictionary) -> StringName:
	last_raw_scores = score_actions(context)
	last_scores = _apply_decision_uncertainty(last_raw_scores)
	var ranked := _rank_actions(last_scores)
	if ranked.is_empty():
		current_action = ACTION_HOLD
		last_was_mistake = false
		last_selected_score = 0.0
		last_decision_confidence = 0.0
		decision_time_left = profile.get_effective_decision_interval()
		commitment_time_left = _random.randf_range(
			profile.minimum_commitment,
			profile.maximum_commitment
		)
		return current_action
	var selected_index := 0
	last_was_mistake = false
	# Un error cognitivo puede elegir una alternativa viable y subóptima,
	# pero nunca una acción imposible ni una opción absurdamente peor.
	var second_is_plausible := (
		ranked.size() > 1
		and float(ranked[1].get("score", 0.0))
		>= maxf(float(ranked[0].get("score", 0.0)) * 0.20, 0.025)
	)
	if second_is_plausible and _random.randf() < profile.get_mistake_chance():
		selected_index = 1
		last_was_mistake = true
	current_action = StringName(ranked[selected_index].get("action", ACTION_HOLD))
	last_selected_score = float(ranked[selected_index].get("score", 0.0))
	var best_score := float(ranked[0].get("score", 0.0))
	var second_score := float(ranked[1].get("score", best_score)) if ranked.size() > 1 else 0.0
	last_decision_confidence = clampf(
		(best_score - second_score) / maxf(absf(best_score), 0.1),
		0.0,
		1.0
	)
	decision_time_left = profile.get_effective_decision_interval()
	commitment_time_left = _random.randf_range(
		profile.minimum_commitment,
		profile.maximum_commitment
	)
	return current_action


func interrupt_commitment() -> void:
	commitment_time_left = 0.0
	decision_time_left = 0.0


func score_actions(context: Dictionary) -> Dictionary:
	var visible := bool(context.get("visible", false))
	var aware := bool(context.get("aware", false))
	var can_attack := bool(context.get("can_attack", false))
	var attack_reaches := bool(context.get("attack_reaches", false))
	var attack_setup_viable := bool(context.get("attack_setup_viable", false))
	var cooldown_ready := bool(context.get("cooldown_ready", false))
	var health_ratio := clampf(float(context.get("health_ratio", 1.0)), 0.0, 1.0)
	var stamina_ratio := clampf(float(context.get("stamina_ratio", 1.0)), 0.0, 1.0)
	var distance := float(context.get("distance", 9999.0))
	var role := StringName(context.get("role", &"support"))
	var target_action := StringName(context.get("target_action", &"none"))
	var target_phase := StringName(context.get("target_phase", &"none"))

	var reads_telegraphs := profile.is_capability_enabled(
		EnemyAIProfile.CAP_READ_TELEGRAPHS
	)
	var adapts := profile.is_capability_enabled(
		EnemyAIProfile.CAP_ADAPT_ATTACKS
	)

	var target_charging := reads_telegraphs and target_action == &"charge"
	var target_telegraphing := (
		reads_telegraphs
		and (
			target_charging
			or target_phase == &"telegraph"
		)
	)
	var target_recovering := target_phase == &"recovery"
	var can_pursue_memory := profile.is_capability_enabled(
		EnemyAIProfile.CAP_SEARCH
	)

	var inside_target_threat := bool(
		context.get("inside_target_threat", false)
	)
	var target_facing_me := bool(
		context.get("target_facing_me", false)
	)
	var cover_available := bool(
		context.get("cover_available", false)
	)
	var dash_ready := bool(
		context.get("dash_ready", false)
	)
	var interrupt_reaches := bool(
		context.get("interrupt_reaches", false)
	)
	var threat_danger := clampf(
		float(context.get("threat_danger", 0.0)),
		0.0,
		1.0
	)
	var stance := StringName(context.get("stance", &"neutral"))
	var group_attacking_count := maxi(int(context.get("group_attacking_count", 0)), 0)
	var group_ready_count := maxi(int(context.get("group_ready_count", 1)), 1)

	# -----------------------------------------------------
	# MEMORIA ADAPTATIVA
	# -----------------------------------------------------
	# Estos datos no son "lectura de inputs". Llegan de patrones que el enemigo
	# fue acumulando a partir de observaciones visuales y resultados de combate.
	var adaptive_confidence := clampf(
		float(context.get("adaptive_confidence", 0.0)),
		0.0,
		1.0
	)
	var adaptive_weight := (
		profile.get_adaptive_influence()
		* adaptive_confidence
		if adapts
		else 0.0
	)

	var player_attack_pressure := clampf(
		float(context.get("player_attack_pressure", 0.0)),
		0.0,
		1.0
	)
	var player_charge_tendency := clampf(
		float(context.get("player_charge_tendency", 0.0)),
		0.0,
		1.0
	)
	var player_dash_tendency := clampf(
		float(context.get("player_dash_tendency", 0.0)),
		0.0,
		1.0
	)
	var player_recovery_exposure := clampf(
		float(context.get("player_recovery_exposure", 0.0)),
		0.0,
		1.0
	)
	var player_approach_tendency := clampf(
		float(context.get("player_approach_tendency", 0.0)),
		0.0,
		1.0
	)
	var player_retreat_tendency := clampf(
		float(context.get("player_retreat_tendency", 0.0)),
		0.0,
		1.0
	)
	var player_lateral_tendency := clampf(
		float(context.get("player_lateral_tendency", 0.0)),
		0.0,
		1.0
	)
	var player_repeat_tendency := clampf(
		float(context.get("player_repeat_tendency", 0.0)),
		0.0,
		1.0
	)
	var player_punishes_windup := clampf(
		float(context.get("player_punishes_windup", 0.0)),
		0.0,
		1.0
	)

	var low_health_pressure := clampf(
		(profile.retreat_health_ratio - health_ratio)
		/ maxf(profile.retreat_health_ratio, 0.01),
		0.0,
		1.0
	)

	var danger_cue := (
		1.0
		if (
			visible
			and target_telegraphing
			and target_facing_me
		)
		else 0.0
	)

	var scores: Dictionary = {}

	# -----------------------------------------------------
	# ATTACK
	# -----------------------------------------------------
	var attack_is_valid := (
		visible
		and can_attack
		and (attack_reaches or attack_setup_viable)
		and cooldown_ready
	)
	var attack_score := 0.0

	if attack_is_valid:
		attack_score = profile.attack_utility * profile.aggression
		attack_score *= stamina_ratio * 0.45 + 0.55

		# Si todavia no llega, no considera esto un golpe inmediato: es una
		# intencion de entrar en postura, alinear distancia y recien comprometer.
		if not attack_reaches:
			var setup_distance_factor := 1.0 - clampf(
				distance / maxf(profile.attack_setup_max_distance, 1.0),
				0.0,
				1.0
			)
			attack_score *= 0.58 + setup_distance_factor * 0.30

		if (
			target_recovering
			and adapts
		):
			attack_score *= 1.35

		if danger_cue > 0.0 and inside_target_threat:
			attack_score *= 0.28

		if adaptive_weight > 0.0:
			# Si el jugador expone recuperaciones a menudo, el enemigo aprende a
			# capitalizar esas ventanas. Si presiona mucho y no está recuperando,
			# se vuelve algo menos ansioso por iniciar un intercambio frontal.
			attack_score *= (
				1.0
				+ adaptive_weight
				* player_recovery_exposure
				* 0.24
			)

			if not target_recovering:
				attack_score *= (
					1.0
					- adaptive_weight
					* player_attack_pressure
					* 0.16
				)

			attack_score *= (
				1.0
				+ adaptive_weight
				* player_retreat_tendency
				* 0.10
			)

	if threat_danger > 0.0:
		attack_score *= lerpf(1.0, 0.34, threat_danger)

	# Si ya hay aliados comprometidos, una personalidad cooperativa evita
	# convertir cada ventana en un ataque simultaneo. El token grupal sigue
	# siendo la barrera definitiva; esto solo mejora la intencion previa.
	if group_attacking_count > 0 and group_ready_count > 1:
		attack_score *= clampf(1.0 - float(group_attacking_count) * 0.12 * profile.teamwork, 0.58, 1.0)

	scores[ACTION_ATTACK] = attack_score

	# -----------------------------------------------------
	# APPROACH
	# -----------------------------------------------------
	var approach_score := profile.approach_utility
	approach_score *= (
		1.0
		if aware and (visible or can_pursue_memory)
		else 0.0
	)
	approach_score *= clampf(
		distance / maxf(profile.preferred_distance, 1.0),
		0.12,
		2.1
	)
	approach_score *= 1.15 if role == &"pressure" else 0.72

	if danger_cue > 0.0 and inside_target_threat:
		approach_score *= 0.30

	if adaptive_weight > 0.0:
		approach_score *= (
			1.0
			+ adaptive_weight
			* player_retreat_tendency
			* 0.32
		)

		if inside_target_threat:
			approach_score *= (
				1.0
				- adaptive_weight
				* player_attack_pressure
				* 0.22
			)

	scores[ACTION_APPROACH] = approach_score

	# -----------------------------------------------------
	# HOLD / BAIT
	# -----------------------------------------------------
	var hold_score := profile.hold_utility * profile.patience
	hold_score *= 1.25 if role in [&"support", &"waiting"] else 0.45
	hold_score *= 1.0 if aware else 0.0
	hold_score += (1.0 - stamina_ratio) * 0.4

	if adaptive_weight > 0.0:
		# Un jugador que entra mucho hacia el enemigo puede ser cebado: sostener
		# la posición gana valor en lugar de perseguirlo todo el tiempo.
		hold_score += (
			adaptive_weight
			* player_approach_tendency
			* profile.patience
			* 0.34
		)
		hold_score += (
			adaptive_weight
			* player_repeat_tendency
			* 0.12
		)

	scores[ACTION_HOLD] = hold_score

	# -----------------------------------------------------
	# FLANK
	# -----------------------------------------------------
	if profile.is_capability_enabled(EnemyAIProfile.CAP_FLANK):
		var flank_score := profile.flank_utility * profile.teamwork
		flank_score *= 1.35 if role == &"flank" else 0.18
		flank_score *= 1.0 if aware and visible else 0.0

		if adaptive_weight > 0.0:
			flank_score *= (
				1.0
				+ adaptive_weight
				* (
					player_attack_pressure * 0.14
					+ player_lateral_tendency * 0.12
				)
			)

		scores[ACTION_FLANK] = flank_score

	# -----------------------------------------------------
	# RETREAT
	# -----------------------------------------------------
	if profile.is_capability_enabled(EnemyAIProfile.CAP_FLEE):
		var retreat_score := (
			profile.retreat_utility
			* low_health_pressure
			* (3.0 - profile.courage)
		)

		retreat_score += (1.0 - stamina_ratio) * 0.26
		retreat_score += danger_cue * 0.2
		retreat_score *= 1.0 if aware else 0.0

		if adaptive_weight > 0.0 and aware:
			retreat_score += (
				adaptive_weight
				* player_attack_pressure
				* (0.12 + (1.0 - stamina_ratio) * 0.22)
			)

		scores[ACTION_RETREAT] = retreat_score

	# -----------------------------------------------------
	# SEARCH
	# -----------------------------------------------------
	if profile.is_capability_enabled(EnemyAIProfile.CAP_SEARCH):
		var search_score := (
			profile.search_utility
			* (1.0 if aware and not visible else 0.0)
		)
		scores[ACTION_SEARCH] = search_score

	# -----------------------------------------------------
	# CIRCLE
	# -----------------------------------------------------
	if profile.is_capability_enabled(EnemyAIProfile.CAP_CIRCLE):
		var distance_fit := (
			1.0
			- clampf(
				absf(distance - profile.circle_radius)
				/ maxf(profile.circle_radius, 1.0),
				0.0,
				1.0
			)
		)

		var circle_score := (
			profile.circle_utility
			* (0.45 + distance_fit * 0.55)
		)

		circle_score *= (
			1.2
			if role in [&"flank", &"support"]
			else 0.55
		)
		circle_score *= 1.0 if visible else 0.0

		if adaptive_weight > 0.0:
			circle_score *= (
				1.0
				+ adaptive_weight
				* (
					player_attack_pressure * 0.26
					+ player_dash_tendency * 0.15
					+ player_approach_tendency * 0.12
				)
			)

		scores[ACTION_CIRCLE] = circle_score

	# -----------------------------------------------------
	# COVER
	# -----------------------------------------------------
	if profile.is_capability_enabled(EnemyAIProfile.CAP_COVER):
		var cover_score := profile.cover_utility
		cover_score *= (
			1.0
			if cover_available and visible
			else 0.0
		)

		cover_score *= (
			0.35
			+ (1.0 - stamina_ratio) * 0.75
			+ low_health_pressure * 0.8
			+ danger_cue * 0.65
		)

		if adaptive_weight > 0.0:
			cover_score *= (
				1.0
				+ adaptive_weight
				* (
					player_attack_pressure * 0.22
					+ player_charge_tendency * 0.25
				)
			)

		scores[ACTION_COVER] = cover_score

	# -----------------------------------------------------
	# DODGE
	# -----------------------------------------------------
	if profile.is_capability_enabled(EnemyAIProfile.CAP_DODGE):
		var dodge_score := profile.dodge_utility * maxf(danger_cue, threat_danger)
		if threat_danger > 0.0:
			dodge_score *= 0.72 + threat_danger * 0.95
		else:
			dodge_score *= 1.0 if inside_target_threat else 0.22
		dodge_score *= 1.25 if dash_ready else 0.72
		dodge_score *= stamina_ratio * 0.45 + 0.55

		# La memoria solo refuerza una amenaza que está siendo observada ahora.
		# Nunca genera una esquiva "psíquica" sin telegraph visible.
		if adaptive_weight > 0.0 and danger_cue > 0.0:
			dodge_score *= (
				1.0
				+ adaptive_weight
				* (
					player_charge_tendency * 0.30
					+ player_repeat_tendency * 0.18
				)
			)

		scores[ACTION_DODGE] = dodge_score

	# -----------------------------------------------------
	# INTERRUPT
	# -----------------------------------------------------
	if profile.is_capability_enabled(EnemyAIProfile.CAP_INTERRUPT):
		var interrupt_score := profile.interrupt_utility
		interrupt_score *= (
			1.0
			if (
				visible
				and target_telegraphing
				and interrupt_reaches
				and cooldown_ready
			)
			else 0.0
		)
		interrupt_score *= 1.25 if target_charging else 0.8

		if adaptive_weight > 0.0 and interrupt_score > 0.0:
			interrupt_score *= (
				1.0
				+ adaptive_weight
				* (
					player_charge_tendency * 0.34
					+ player_repeat_tendency * 0.16
				)
			)

		scores[ACTION_INTERRUPT] = interrupt_score

	# -----------------------------------------------------
	# POSTURA Y PERSONALIDAD
	# -----------------------------------------------------
	# La postura describe el estado tactico del momento; la personalidad
	# describe el estilo estable del enemigo. Se combinan sin alterar el IQ.
	for action_variant: Variant in scores:
		var action := StringName(action_variant)
		var score := float(scores[action_variant])
		if score <= 0.0:
			continue

		match stance:
			&"defensive":
				if action in [ACTION_DODGE, ACTION_RETREAT, ACTION_COVER, ACTION_HOLD, ACTION_CIRCLE]:
					score *= 1.22
				elif action in [ACTION_ATTACK, ACTION_APPROACH]:
					score *= 0.76
			&"aggressive":
				if action in [ACTION_ATTACK, ACTION_APPROACH, ACTION_INTERRUPT]:
					score *= 1.18
				elif action in [ACTION_RETREAT, ACTION_COVER]:
					score *= 0.78
			&"pressure":
				if action in [ACTION_APPROACH, ACTION_ATTACK, ACTION_FLANK]:
					score *= 1.16
			&"punish":
				if action in [ACTION_ATTACK, ACTION_INTERRUPT]:
					score *= 1.34
				elif action in [ACTION_RETREAT, ACTION_SEARCH]:
					score *= 0.72

		score *= profile.get_personality_action_multiplier(action)
		scores[action_variant] = score

	# -----------------------------------------------------
	# PERSISTENCIA
	# -----------------------------------------------------
	if (
		current_action in scores
		and float(scores[current_action]) > 0.0
	):
		var persistence_bonus := 0.08
		persistence_bonus += (
			adaptive_weight
			* (0.04 + profile.patience * 0.03)
		)
		scores[current_action] = (
			float(scores[current_action])
			+ persistence_bonus
		)

	return scores


func _apply_decision_uncertainty(raw_scores: Dictionary) -> Dictionary:
	var noisy_scores := raw_scores.duplicate()
	var amplitude := profile.get_decision_noise()
	for action: Variant in noisy_scores:
		var score := float(noisy_scores[action])
		if score <= 0.0:
			continue
		noisy_scores[action] = score + _random.randf_range(-amplitude, amplitude)
	return noisy_scores


func _rank_actions(scores: Dictionary) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for action: Variant in scores:
		var score := float(scores[action])
		if score <= 0.0:
			continue
		ranked.append({"action": StringName(action), "score": score})
	ranked.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_score := float(a.get("score", -INF))
			var b_score := float(b.get("score", -INF))
			if is_equal_approx(a_score, b_score):
				return String(a.get("action", "")) < String(b.get("action", ""))
			return a_score > b_score
	)
	return ranked
