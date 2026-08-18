class_name EnemyAIProfile
extends Resource


enum CapabilityMode {
	AUTO,
	DISABLED,
	ENABLED
}


const CAP_FLEE: StringName = &"flee"
const CAP_SEARCH: StringName = &"search"
const CAP_HEAVY_ATTACK: StringName = &"heavy_attack"
const CAP_TEAMWORK: StringName = &"teamwork"
const CAP_FLANK: StringName = &"flank"
const CAP_CIRCLE: StringName = &"circle"
const CAP_COVER: StringName = &"cover"
const CAP_ADAPT_ATTACKS: StringName = &"adapt_attacks"
const CAP_READ_TELEGRAPHS: StringName = &"read_telegraphs"
const CAP_DODGE: StringName = &"dodge"
const CAP_DASH: StringName = &"dash"
const CAP_INTERRUPT: StringName = &"interrupt"
const CAP_CHARGED_ATTACK: StringName = &"charged_attack"
const CAP_PREDICT: StringName = &"predict"


@export_category("Inteligencia")

@export_range(0.0, 100.0, 1.0)
var intelligence_percent: float = 20.0

@export_range(0.0, 2.0, 0.05)
var decision_error_multiplier: float = 1.0

@export_range(0.0, 2.0, 0.05)
var reaction_time_multiplier: float = 1.0

@export_range(0.0, 2.0, 0.05)
var memory_error_multiplier: float = 1.0

@export_range(0, 2147483647, 1)
var deterministic_seed: int = 0


@export_category("Capacidades")

@export var flee_mode: CapabilityMode = CapabilityMode.AUTO
@export var search_mode: CapabilityMode = CapabilityMode.AUTO
@export var heavy_attack_mode: CapabilityMode = CapabilityMode.AUTO
@export var teamwork_mode: CapabilityMode = CapabilityMode.AUTO
@export var flank_mode: CapabilityMode = CapabilityMode.AUTO
@export var circle_mode: CapabilityMode = CapabilityMode.AUTO
@export var cover_mode: CapabilityMode = CapabilityMode.AUTO
@export var adapt_attacks_mode: CapabilityMode = CapabilityMode.AUTO
@export var read_telegraphs_mode: CapabilityMode = CapabilityMode.AUTO
@export var dodge_mode: CapabilityMode = CapabilityMode.AUTO
@export var dash_mode: CapabilityMode = CapabilityMode.AUTO
@export var interrupt_mode: CapabilityMode = CapabilityMode.AUTO
@export var charged_attack_mode: CapabilityMode = CapabilityMode.AUTO
@export var predict_mode: CapabilityMode = CapabilityMode.AUTO


@export_category("Reaccion e incertidumbre")

@export_range(0.01, 3.0, 0.01)
var reaction_time_at_zero: float = 0.90

@export_range(0.01, 3.0, 0.01)
var reaction_time_at_hundred: float = 0.10

@export_range(0.0, 2.0, 0.01)
var decision_noise_at_zero: float = 0.48

@export_range(0.0, 2.0, 0.01)
var decision_noise_at_hundred: float = 0.025

@export_range(0.0, 1.0, 0.01)
var mistake_chance_at_zero: float = 0.42

@export_range(0.0, 1.0, 0.01)
var mistake_chance_at_hundred: float = 0.015

@export_range(0.0, 256.0, 1.0)
var memory_position_error_at_zero: float = 110.0

@export_range(0.0, 256.0, 1.0)
var memory_position_error_at_hundred: float = 4.0

@export_range(0.0, 2.0, 0.01)
var prediction_horizon_at_hundred: float = 0.65


@export_category("Percepcion")

@export_range(1.0, 5000.0, 1.0)
var vision_range: float = 360.0

@export_range(1.0, 360.0, 1.0)
var vision_angle_degrees: float = 210.0

@export_range(0.0, 5000.0, 1.0)
var hearing_range: float = 180.0

@export_range(0.0, 1000.0, 1.0)
var hearing_velocity_threshold: float = 45.0

@export_range(0.0, 30.0, 0.1)
var memory_duration: float = 4.0

@export_flags_2d_physics
var sight_collision_mask: int = 1


@export_category("Ritmo de decision")

@export_range(0.05, 2.0, 0.01)
var decision_interval: float = 0.20

@export_range(0.05, 3.0, 0.05)
var minimum_commitment: float = 0.35

@export_range(0.05, 5.0, 0.05)
var maximum_commitment: float = 0.85


@export_category("Personalidad")

@export_range(0.0, 2.0, 0.05)
var aggression: float = 1.0

@export_range(0.0, 2.0, 0.05)
var courage: float = 0.85

@export_range(0.0, 2.0, 0.05)
var teamwork: float = 1.15

@export_range(0.0, 2.0, 0.05)
var patience: float = 0.8

@export_range(0.0, 1.0, 0.05)
var retreat_health_ratio: float = 0.25


@export_category("Posicionamiento tactico")

@export_range(10.0, 1000.0, 1.0)
var preferred_distance: float = 58.0

@export_range(0.0, 100.0, 1.0)
var target_radius_estimate: float = 14.0

@export_range(10.0, 2000.0, 1.0)
var flank_radius: float = 105.0

@export_range(10.0, 2000.0, 1.0)
var support_radius: float = 145.0

@export_range(10.0, 1000.0, 1.0)
var retreat_distance: float = 175.0

@export_range(10.0, 2000.0, 1.0)
var circle_radius: float = 82.0

@export_range(10.0, 3000.0, 1.0)
var cover_search_radius: float = 260.0

@export_range(0.0, 10.0, 0.1)
var cover_hold_duration: float = 1.15


@export_category("Esquiva y desplazamiento")

@export_range(0.0, 500.0, 1.0)
var danger_padding: float = 30.0


@export_category("Pesos de utilidad")

@export_range(0.0, 5.0, 0.05)
var attack_utility: float = 1.35

@export_range(0.0, 5.0, 0.05)
var approach_utility: float = 1.0

@export_range(0.0, 5.0, 0.05)
var flank_utility: float = 1.15

@export_range(0.0, 5.0, 0.05)
var hold_utility: float = 0.75

@export_range(0.0, 5.0, 0.05)
var retreat_utility: float = 1.4

@export_range(0.0, 5.0, 0.05)
var search_utility: float = 1.0

@export_range(0.0, 5.0, 0.05)
var circle_utility: float = 0.9

@export_range(0.0, 5.0, 0.05)
var cover_utility: float = 1.0

@export_range(0.0, 5.0, 0.05)
var dodge_utility: float = 1.8

@export_range(0.0, 5.0, 0.05)
var interrupt_utility: float = 1.45


func get_intelligence_ratio() -> float:
	return clampf(intelligence_percent / 100.0, 0.0, 1.0)


func get_intelligence_label() -> String:
	if intelligence_percent < 26.0:
		return "Instintiva"
	if intelligence_percent < 51.0:
		return "Táctica básica"
	if intelligence_percent < 76.0:
		return "Táctica avanzada"
	if intelligence_percent < 91.0:
		return "Estratégica"
	return "Maestra"


func is_capability_enabled(capability: StringName) -> bool:
	var threshold := _get_capability_threshold(capability)
	var mode := _get_capability_mode(capability)
	if mode == CapabilityMode.ENABLED:
		return true
	if mode == CapabilityMode.DISABLED:
		return false
	return intelligence_percent >= threshold


func get_reaction_time() -> float:
	var skill := pow(get_intelligence_ratio(), 0.82)
	return maxf(
		lerpf(reaction_time_at_zero, reaction_time_at_hundred, skill)
		* reaction_time_multiplier,
		0.01
	)


func get_decision_noise() -> float:
	var skill := pow(get_intelligence_ratio(), 0.78)
	return maxf(
		lerpf(decision_noise_at_zero, decision_noise_at_hundred, skill)
		* decision_error_multiplier,
		0.0
	)


func get_mistake_chance() -> float:
	var skill := pow(get_intelligence_ratio(), 0.85)
	return clampf(
		lerpf(mistake_chance_at_zero, mistake_chance_at_hundred, skill)
		* decision_error_multiplier,
		0.0,
		1.0
	)


func get_memory_position_error() -> float:
	var skill := get_intelligence_ratio()
	return maxf(
		lerpf(memory_position_error_at_zero, memory_position_error_at_hundred, skill)
		* memory_error_multiplier,
		0.0
	)


func get_prediction_horizon() -> float:
	if not is_capability_enabled(CAP_PREDICT):
		return 0.0
	return prediction_horizon_at_hundred * get_intelligence_ratio()


func get_effective_decision_interval() -> float:
	return maxf(
		decision_interval * lerpf(1.85, 0.72, get_intelligence_ratio()),
		0.04
	)


func _get_capability_threshold(capability: StringName) -> float:
	match capability:
		CAP_FLEE: return 0.0
		CAP_SEARCH: return 10.0
		CAP_HEAVY_ATTACK: return 30.0
		CAP_TEAMWORK: return 35.0
		CAP_FLANK: return 35.0
		CAP_CIRCLE: return 40.0
		CAP_COVER: return 45.0
		CAP_ADAPT_ATTACKS: return 50.0
		CAP_READ_TELEGRAPHS: return 60.0
		CAP_DODGE: return 65.0
		CAP_DASH: return 70.0
		CAP_INTERRUPT: return 70.0
		CAP_CHARGED_ATTACK: return 75.0
		CAP_PREDICT: return 80.0
	return 101.0


func _get_capability_mode(capability: StringName) -> CapabilityMode:
	match capability:
		CAP_FLEE: return flee_mode
		CAP_SEARCH: return search_mode
		CAP_HEAVY_ATTACK: return heavy_attack_mode
		CAP_TEAMWORK: return teamwork_mode
		CAP_FLANK: return flank_mode
		CAP_CIRCLE: return circle_mode
		CAP_COVER: return cover_mode
		CAP_ADAPT_ATTACKS: return adapt_attacks_mode
		CAP_READ_TELEGRAPHS: return read_telegraphs_mode
		CAP_DODGE: return dodge_mode
		CAP_DASH: return dash_mode
		CAP_INTERRUPT: return interrupt_mode
		CAP_CHARGED_ATTACK: return charged_attack_mode
		CAP_PREDICT: return predict_mode
	return CapabilityMode.DISABLED
