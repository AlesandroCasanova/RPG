class_name EnemyUtilityBrain
extends RefCounted


const ACTION_ATTACK: StringName = &"attack"
const ACTION_APPROACH: StringName = &"approach"
const ACTION_FLANK: StringName = &"flank"
const ACTION_HOLD: StringName = &"hold"
const ACTION_RETREAT: StringName = &"retreat"
const ACTION_SEARCH: StringName = &"search"


var profile: EnemyAIProfile = null
var current_action: StringName = ACTION_HOLD
var commitment_time_left: float = 0.0
var decision_time_left: float = 0.0
var last_scores: Dictionary = {}


func configure(ai_profile: EnemyAIProfile) -> void:

	profile = ai_profile
	decision_time_left = randf_range(
		0.0,
		profile.decision_interval
	)


func update_timers(delta: float) -> void:

	decision_time_left = maxf(
		decision_time_left - delta,
		0.0
	)

	commitment_time_left = maxf(
		commitment_time_left - delta,
		0.0
	)


func should_reconsider(force: bool = false) -> bool:

	if force:

		return true


	return (
		decision_time_left <= 0.0
		and
		commitment_time_left <= 0.0
	)


func decide(context: Dictionary) -> StringName:

	last_scores = _score_actions(context)


	var best_action: StringName = ACTION_HOLD
	var best_score: float = -INF


	for action_variant: Variant in last_scores:

		var action: StringName = StringName(action_variant)
		var score: float = float(last_scores[action_variant])


		if score > best_score:

			best_score = score
			best_action = action


	current_action = best_action
	decision_time_left = profile.decision_interval
	commitment_time_left = randf_range(
		profile.minimum_commitment,
		profile.maximum_commitment
	)


	return current_action


func interrupt_commitment() -> void:

	commitment_time_left = 0.0
	decision_time_left = 0.0


func _score_actions(context: Dictionary) -> Dictionary:

	var visible: bool = bool(context.get("visible", false))
	var aware: bool = bool(context.get("aware", false))
	var can_attack: bool = bool(context.get("can_attack", false))
	var attack_reaches: bool = bool(context.get("attack_reaches", false))
	var cooldown_ready: bool = bool(context.get("cooldown_ready", false))
	var health_ratio: float = float(context.get("health_ratio", 1.0))
	var stamina_ratio: float = float(context.get("stamina_ratio", 1.0))
	var distance: float = float(context.get("distance", 9999.0))
	var role: StringName = StringName(context.get("role", &"support"))

	var low_health_pressure: float = clampf(
		(profile.retreat_health_ratio - health_ratio)
		/ maxf(profile.retreat_health_ratio, 0.01),
		0.0,
		1.0
	)

	var attack_score: float = profile.attack_utility
	attack_score *= profile.aggression
	attack_score *= stamina_ratio * 0.45 + 0.55
	attack_score *= 1.0 if can_attack else 0.08
	attack_score *= 1.0 if attack_reaches else 0.12
	attack_score *= 1.0 if cooldown_ready else 0.15
	attack_score *= 1.0 if visible else 0.25

	var approach_score: float = profile.approach_utility
	approach_score *= 1.0 if aware else 0.0
	approach_score *= clampf(
		distance / maxf(profile.preferred_distance, 1.0),
		0.15,
		2.0
	)
	approach_score *= 1.1 if role == &"pressure" else 0.65

	var flank_score: float = profile.flank_utility
	flank_score *= profile.teamwork
	flank_score *= 1.25 if role == &"flank" else 0.15
	flank_score *= 1.0 if aware else 0.0

	var hold_score: float = profile.hold_utility
	hold_score *= profile.patience
	hold_score *= 1.25 if role == &"support" else 0.35
	hold_score *= 1.0 if aware else 0.0

	var retreat_score: float = profile.retreat_utility
	retreat_score *= low_health_pressure
	retreat_score *= 3.0 - profile.courage
	retreat_score += (1.0 - stamina_ratio) * 0.35

	var search_score: float = profile.search_utility
	search_score *= 1.0 if aware and not visible else 0.0


	if current_action in [
		ACTION_APPROACH,
		ACTION_FLANK,
		ACTION_HOLD,
		ACTION_RETREAT,
		ACTION_SEARCH
	]:

		var inertia: float = float(
			{
				ACTION_APPROACH: approach_score,
				ACTION_FLANK: flank_score,
				ACTION_HOLD: hold_score,
				ACTION_RETREAT: retreat_score,
				ACTION_SEARCH: search_score
			}.get(current_action, 0.0)
		)

		match current_action:

			ACTION_APPROACH:
				approach_score = inertia + 0.08

			ACTION_FLANK:
				flank_score = inertia + 0.08

			ACTION_HOLD:
				hold_score = inertia + 0.08

			ACTION_RETREAT:
				retreat_score = inertia + 0.08

			ACTION_SEARCH:
				search_score = inertia + 0.08


	return {
		ACTION_ATTACK: attack_score,
		ACTION_APPROACH: approach_score,
		ACTION_FLANK: flank_score,
		ACTION_HOLD: hold_score,
		ACTION_RETREAT: retreat_score,
		ACTION_SEARCH: search_score
	}
