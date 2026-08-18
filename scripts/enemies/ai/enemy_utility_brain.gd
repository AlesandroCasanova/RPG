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
	var cooldown_ready := bool(context.get("cooldown_ready", false))
	var health_ratio := clampf(float(context.get("health_ratio", 1.0)), 0.0, 1.0)
	var stamina_ratio := clampf(float(context.get("stamina_ratio", 1.0)), 0.0, 1.0)
	var distance := float(context.get("distance", 9999.0))
	var role := StringName(context.get("role", &"support"))
	var target_action := StringName(context.get("target_action", &"none"))
	var target_phase := StringName(context.get("target_phase", &"none"))
	var reads_telegraphs := profile.is_capability_enabled(EnemyAIProfile.CAP_READ_TELEGRAPHS)
	var target_charging := reads_telegraphs and target_action == &"charge"
	var target_telegraphing := reads_telegraphs and (target_charging or target_phase == &"telegraph")
	var target_recovering := target_phase == &"recovery"
	var can_pursue_memory := profile.is_capability_enabled(EnemyAIProfile.CAP_SEARCH)
	var inside_target_threat := bool(context.get("inside_target_threat", false))
	var target_facing_me := bool(context.get("target_facing_me", false))
	var cover_available := bool(context.get("cover_available", false))
	var dash_ready := bool(context.get("dash_ready", false))
	var interrupt_reaches := bool(context.get("interrupt_reaches", false))
	var low_health_pressure := clampf(
		(profile.retreat_health_ratio - health_ratio)
		/ maxf(profile.retreat_health_ratio, 0.01),
		0.0,
		1.0
	)
	var danger_cue := 1.0 if visible and target_telegraphing and target_facing_me else 0.0
	var scores: Dictionary = {}

	var attack_is_valid := visible and can_attack and attack_reaches and cooldown_ready
	var attack_score := 0.0
	if attack_is_valid:
		attack_score = profile.attack_utility * profile.aggression
		attack_score *= stamina_ratio * 0.45 + 0.55
		attack_score *= 1.35 if target_recovering and profile.is_capability_enabled(EnemyAIProfile.CAP_ADAPT_ATTACKS) else 1.0
		attack_score *= 0.28 if danger_cue > 0.0 and inside_target_threat else 1.0
	scores[ACTION_ATTACK] = attack_score

	var approach_score := profile.approach_utility
	approach_score *= 1.0 if aware and (visible or can_pursue_memory) else 0.0
	approach_score *= clampf(distance / maxf(profile.preferred_distance, 1.0), 0.12, 2.1)
	approach_score *= 1.15 if role == &"pressure" else 0.72
	approach_score *= 0.30 if danger_cue > 0.0 and inside_target_threat else 1.0
	scores[ACTION_APPROACH] = approach_score

	var hold_score := profile.hold_utility * profile.patience
	hold_score *= 1.25 if role in [&"support", &"waiting"] else 0.45
	hold_score *= 1.0 if aware else 0.0
	hold_score += (1.0 - stamina_ratio) * 0.4
	scores[ACTION_HOLD] = hold_score

	if profile.is_capability_enabled(EnemyAIProfile.CAP_FLANK):
		var flank_score := profile.flank_utility * profile.teamwork
		flank_score *= 1.35 if role == &"flank" else 0.18
		flank_score *= 1.0 if aware and visible else 0.0
		scores[ACTION_FLANK] = flank_score

	if profile.is_capability_enabled(EnemyAIProfile.CAP_FLEE):
		var retreat_score := profile.retreat_utility * low_health_pressure * (3.0 - profile.courage)
		retreat_score += (1.0 - stamina_ratio) * 0.26
		retreat_score += danger_cue * 0.2
		retreat_score *= 1.0 if aware else 0.0
		scores[ACTION_RETREAT] = retreat_score

	if profile.is_capability_enabled(EnemyAIProfile.CAP_SEARCH):
		var search_score := profile.search_utility * (1.0 if aware and not visible else 0.0)
		scores[ACTION_SEARCH] = search_score

	if profile.is_capability_enabled(EnemyAIProfile.CAP_CIRCLE):
		var distance_fit := 1.0 - clampf(absf(distance - profile.circle_radius) / maxf(profile.circle_radius, 1.0), 0.0, 1.0)
		var circle_score := profile.circle_utility * (0.45 + distance_fit * 0.55)
		circle_score *= 1.2 if role in [&"flank", &"support"] else 0.55
		circle_score *= 1.0 if visible else 0.0
		scores[ACTION_CIRCLE] = circle_score

	if profile.is_capability_enabled(EnemyAIProfile.CAP_COVER):
		var cover_score := profile.cover_utility
		cover_score *= 1.0 if cover_available and visible else 0.0
		cover_score *= 0.35 + (1.0 - stamina_ratio) * 0.75 + low_health_pressure * 0.8 + danger_cue * 0.65
		scores[ACTION_COVER] = cover_score

	if profile.is_capability_enabled(EnemyAIProfile.CAP_DODGE):
		var dodge_score := profile.dodge_utility * danger_cue
		dodge_score *= 1.0 if inside_target_threat else 0.22
		dodge_score *= 1.25 if dash_ready else 0.72
		dodge_score *= stamina_ratio * 0.45 + 0.55
		scores[ACTION_DODGE] = dodge_score

	if profile.is_capability_enabled(EnemyAIProfile.CAP_INTERRUPT):
		var interrupt_score := profile.interrupt_utility
		interrupt_score *= 1.0 if visible and target_telegraphing and interrupt_reaches and cooldown_ready else 0.0
		interrupt_score *= 1.25 if target_charging else 0.8
		scores[ACTION_INTERRUPT] = interrupt_score

	if current_action in scores and float(scores[current_action]) > 0.0:
		scores[current_action] = float(scores[current_action]) + 0.08
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
