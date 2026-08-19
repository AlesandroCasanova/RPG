class_name EnemyAIProfile
extends Resource


enum CapabilityMode {
	AUTO,
	DISABLED,
	ENABLED
}

enum CombatPersonality {
	BALANCED,
	AGGRESSIVE,
	CAUTIOUS,
	OPPORTUNIST,
	DUELIST,
	BERSERKER,
	PACK_HUNTER,
	DEFENSIVE
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
const CAP_COMBO: StringName = &"combo"


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
@export var combo_mode: CapabilityMode = CapabilityMode.AUTO


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

## Arquetipo de combate. No cambia el IQ: dos enemigos igual de inteligentes
## pueden tomar decisiones distintas por personalidad.
@export_enum("Equilibrado", "Agresivo", "Cauteloso", "Oportunista", "Duelista", "Berserker", "Cazador de manada", "Defensivo")
var combat_personality: int = CombatPersonality.BALANCED

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


@export_category("Memoria adaptativa")

@export_range(0.5, 30.0, 0.1)
var adaptive_memory_half_life: float = 6.0

@export_range(0.0, 2.0, 0.05)
var adaptive_learning_strength: float = 1.0

@export_range(0.0, 2.0, 0.05)
var adaptive_influence: float = 0.70

@export_range(1.0, 20.0, 0.5)
var adaptive_evidence_at_zero: float = 8.0

@export_range(1.0, 20.0, 0.5)
var adaptive_evidence_at_hundred: float = 2.5

@export_range(0.0, 2.0, 0.05)
var attack_history_influence: float = 0.55


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


@export_category("Movimiento tactico")

## Tiempo base durante el que un flanco/soporte mantiene su ancla espacial
## antes de aceptar otro punto. Evita perseguir objetivos tacticos que cambian
## cada frame.
@export_range(0.10, 3.0, 0.05)
var tactical_anchor_lock_time: float = 0.65

## Si el jugador se aleja esta distancia del origen usado para crear el ancla,
## se permite recalcular antes de que termine el compromiso.
@export_range(5.0, 500.0, 1.0)
var tactical_anchor_retarget_distance: float = 58.0

## Distancia maxima desde la que la IA puede decidir preparar un ataque aunque
## la hitbox todavia no alcance.
@export_range(20.0, 600.0, 1.0)
var attack_setup_max_distance: float = 175.0

## En que parte util del alcance intenta colocarse antes de atacar.
## 0 = muy cerca del inicio de la hitbox, 1 = cerca del borde exterior.
@export_range(0.05, 0.95, 0.05)
var attack_setup_reach_ratio: float = 0.72

## Tolerancia para considerar alcanzada la postura de preparacion.
@export_range(2.0, 80.0, 1.0)
var attack_setup_position_tolerance: float = 13.0

## Movimiento del objetivo necesario para recalcular una postura de ataque.
@export_range(5.0, 300.0, 1.0)
var attack_setup_retarget_distance: float = 42.0

## Pausa de estabilizacion de una IA muy basica antes de comprometer el golpe.
@export_range(0.0, 1.0, 0.01)
var attack_setup_hold_at_zero: float = 0.30

## Pausa de estabilizacion de una IA maestra antes de comprometer el golpe.
@export_range(0.0, 1.0, 0.01)
var attack_setup_hold_at_hundred: float = 0.07

## Cuanto angulo lateral intenta construir una IA basica al preparar un golpe.
@export_range(0.0, 60.0, 1.0)
var attack_setup_angle_at_zero_degrees: float = 3.0

## Cuanto angulo lateral intenta construir una IA experta al preparar un golpe.
@export_range(0.0, 90.0, 1.0)
var attack_setup_angle_at_hundred_degrees: float = 24.0

## Longitud del siguiente paso tactico durante una orbita.
@export_range(10.0, 250.0, 1.0)
var circle_step_distance: float = 52.0

## Fuerza tangencial de la orbita alrededor del jugador.
@export_range(0.1, 3.0, 0.05)
var circle_tangent_strength: float = 1.0

## Cuanto corrige el radio mientras rodea al objetivo.
@export_range(0.1, 4.0, 0.05)
var circle_radial_correction: float = 1.25

## Paso lateral/diagonal breve que intenta hacer despues de terminar un ataque.
@export_range(0.0, 250.0, 1.0)
var post_attack_reposition_distance: float = 56.0

## Tiempo maximo dedicado a ese reposicionamiento.
@export_range(0.0, 2.0, 0.01)
var post_attack_reposition_duration: float = 0.34

## Distancia minima al objetivo tactico para gastar dash al acercarse.
@export_range(20.0, 1000.0, 1.0)
var approach_dash_min_distance: float = 205.0

## Distancia minima para usar dash al flanquear, retirarse o reposicionarse.
@export_range(20.0, 1000.0, 1.0)
var reposition_dash_min_distance: float = 125.0

## Porcentaje de stamina que intenta conservar despues de un dash tactico.
@export_range(0.0, 1.0, 0.05)
var dash_stamina_reserve_ratio: float = 0.20

## Margen para no pasarse de largo del punto deseado con el dash.
@export_range(0.0, 200.0, 1.0)
var dash_stop_buffer: float = 28.0


@export_category("Lectura espacial y prediccion")

## Estimacion visual del largo de una amenaza cuerpo a cuerpo del Player.
## La IA no lee la hitbox privada: aproxima el peligro desde señales observables.
@export_range(10.0, 300.0, 1.0)
var player_threat_length_estimate: float = 78.0

@export_range(10.0, 250.0, 1.0)
var player_threat_width_estimate: float = 62.0

@export_range(0.0, 100.0, 1.0)
var player_threat_start_offset_estimate: float = 12.0

@export_range(0.5, 3.0, 0.05)
var heavy_threat_length_multiplier: float = 1.15

@export_range(0.5, 3.0, 0.05)
var charged_threat_length_multiplier: float = 1.35

@export_range(0.0, 2.0, 0.01)
var predictive_attack_extra_horizon: float = 0.22

@export_range(0.0, 500.0, 1.0)
var maximum_predictive_lead: float = 105.0

@export_range(0.0, 1.0, 0.01)
var predicted_danger_threshold: float = 0.22

@export_range(20.0, 300.0, 1.0)
var predictive_dodge_step_distance: float = 105.0

@export_range(0.0, 100.0, 1.0)
var predictive_dodge_safety_padding: float = 18.0


@export_category("Posturas de combate")

## Tiempo minimo que conserva una postura antes de cambiar por una razon menor.
@export_range(0.05, 2.0, 0.01)
var stance_lock_at_zero: float = 0.62

@export_range(0.05, 2.0, 0.01)
var stance_lock_at_hundred: float = 0.24


@export_category("Coordinacion avanzada")

## Separacion minima entre el inicio de ataques de miembros de la misma escuadra.
@export_range(0.0, 2.0, 0.01)
var team_attack_stagger: float = 0.18

## Margen de seguridad del token de ataque por si una accion queda interrumpida.
@export_range(0.1, 5.0, 0.05)
var attack_token_grace: float = 0.75


@export_category("Combos de IA")

@export_range(1, 5, 1)
var combo_max_steps: int = 3

@export_range(0.0, 1.0, 0.01)
var combo_chance_at_zero: float = 0.04

@export_range(0.0, 1.0, 0.01)
var combo_chance_at_hundred: float = 0.72

## Pausa visual minima entre golpes encadenados.
@export_range(0.0, 0.5, 0.01)
var combo_link_delay: float = 0.07

## Reserva de stamina que una IA intenta conservar al encadenar.
@export_range(0.0, 1.0, 0.05)
var combo_stamina_reserve_ratio: float = 0.12

## Si esta activo, un combo normalmente continua solo tras conectar el golpe previo.
@export var combo_prefers_confirmed_hit: bool = true

@export_range(0.0, 2.0, 0.05)
var combo_primary_to_heavy_bias: float = 0.70


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


func get_stance_lock_time() -> float:
	var skill := pow(get_intelligence_ratio(), 0.75)
	return maxf(lerpf(stance_lock_at_zero, stance_lock_at_hundred, skill), 0.05)


func get_threat_prediction_strength() -> float:
	if not is_capability_enabled(CAP_READ_TELEGRAPHS):
		return 0.0
	var base := lerpf(0.25, 1.0, get_intelligence_ratio())
	if is_capability_enabled(CAP_PREDICT):
		base = minf(base + 0.22, 1.15)
	return base


func get_combo_probability() -> float:
	if not is_capability_enabled(CAP_COMBO):
		return 0.0
	var skill := pow(get_intelligence_ratio(), 0.85)
	var result := lerpf(combo_chance_at_zero, combo_chance_at_hundred, skill)
	match combat_personality:
		CombatPersonality.AGGRESSIVE:
			result *= 1.12
		CombatPersonality.OPPORTUNIST:
			result *= 1.18
		CombatPersonality.DUELIST:
			result *= 1.08
		CombatPersonality.BERSERKER:
			result *= 1.32
		CombatPersonality.CAUTIOUS, CombatPersonality.DEFENSIVE:
			result *= 0.72
	return clampf(result, 0.0, 0.95)


func get_personality_action_multiplier(action: StringName) -> float:
	match combat_personality:
		CombatPersonality.AGGRESSIVE:
			match action:
				&"attack": return 1.22
				&"approach": return 1.18
				&"retreat", &"cover": return 0.72
		CombatPersonality.CAUTIOUS:
			match action:
				&"dodge", &"circle", &"hold", &"cover": return 1.18
				&"attack": return 0.88
		CombatPersonality.OPPORTUNIST:
			match action:
				&"attack", &"interrupt": return 1.18
				&"hold", &"circle": return 1.08
		CombatPersonality.DUELIST:
			match action:
				&"circle", &"dodge", &"attack": return 1.14
				&"cover": return 0.72
		CombatPersonality.BERSERKER:
			match action:
				&"attack", &"approach": return 1.35
				&"retreat", &"cover", &"hold": return 0.48
		CombatPersonality.PACK_HUNTER:
			match action:
				&"flank": return 1.34
				&"circle", &"hold": return 1.12
		CombatPersonality.DEFENSIVE:
			match action:
				&"dodge", &"retreat", &"cover", &"hold": return 1.28
				&"attack", &"approach": return 0.78
	return 1.0


func get_personality_attack_kind_multiplier(attack_kind: int) -> float:
	match combat_personality:
		CombatPersonality.AGGRESSIVE:
			if attack_kind == AttackData.AttackKind.HEAVY:
				return 1.16
		CombatPersonality.CAUTIOUS:
			if attack_kind == AttackData.AttackKind.PRIMARY:
				return 1.14
			if attack_kind == AttackData.AttackKind.CHARGED:
				return 0.72
		CombatPersonality.OPPORTUNIST:
			if attack_kind in [AttackData.AttackKind.HEAVY, AttackData.AttackKind.CHARGED]:
				return 1.14
		CombatPersonality.DUELIST:
			if attack_kind == AttackData.AttackKind.PRIMARY:
				return 1.18
		CombatPersonality.BERSERKER:
			if attack_kind == AttackData.AttackKind.HEAVY:
				return 1.28
			if attack_kind == AttackData.AttackKind.CHARGED:
				return 1.12
		CombatPersonality.DEFENSIVE:
			if attack_kind == AttackData.AttackKind.PRIMARY:
				return 1.12
	return 1.0


func get_personality_stance_multiplier(stance: StringName) -> float:
	match combat_personality:
		CombatPersonality.AGGRESSIVE:
			return 1.28 if stance in [&"aggressive", &"pressure"] else (0.72 if stance == &"defensive" else 1.0)
		CombatPersonality.CAUTIOUS:
			return 1.26 if stance == &"defensive" else (1.10 if stance == &"neutral" else 0.92)
		CombatPersonality.OPPORTUNIST:
			return 1.34 if stance == &"punish" else 1.0
		CombatPersonality.DUELIST:
			return 1.18 if stance in [&"neutral", &"punish"] else 1.0
		CombatPersonality.BERSERKER:
			return 1.38 if stance in [&"aggressive", &"pressure"] else (0.45 if stance == &"defensive" else 1.0)
		CombatPersonality.PACK_HUNTER:
			return 1.22 if stance == &"pressure" else 1.0
		CombatPersonality.DEFENSIVE:
			return 1.38 if stance == &"defensive" else (0.74 if stance == &"aggressive" else 1.0)
	return 1.0


func get_tactical_anchor_lock_time() -> float:
	var skill := get_intelligence_ratio()
	return maxf(
		tactical_anchor_lock_time * lerpf(0.78, 1.18, skill),
		0.10
	)


func get_attack_setup_hold_time() -> float:
	var skill := pow(get_intelligence_ratio(), 0.82)
	var base_time := lerpf(
		attack_setup_hold_at_zero,
		attack_setup_hold_at_hundred,
		skill
	)
	# La paciencia estira un poco la preparacion; la agresividad la acorta.
	var personality_factor := clampf(
		1.0 + (patience - 1.0) * 0.18 - (aggression - 1.0) * 0.12,
		0.72,
		1.35
	)
	return maxf(base_time * personality_factor, 0.0)


func get_attack_setup_angle_bias_radians() -> float:
	var skill := get_intelligence_ratio()
	var angle_degrees := lerpf(
		attack_setup_angle_at_zero_degrees,
		attack_setup_angle_at_hundred_degrees,
		skill
	)
	return deg_to_rad(angle_degrees)


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


func get_combat_memory_half_life() -> float:
	var skill := get_intelligence_ratio()
	return maxf(
		adaptive_memory_half_life * lerpf(0.70, 1.20, skill),
		0.5
	)


func get_combat_learning_strength() -> float:
	if not is_capability_enabled(CAP_ADAPT_ATTACKS):
		return 0.0
	var skill := pow(get_intelligence_ratio(), 0.80)
	return maxf(
		adaptive_learning_strength * lerpf(0.35, 1.0, skill),
		0.0
	)


func get_pattern_evidence_required() -> float:
	var skill := get_intelligence_ratio()
	return maxf(
		lerpf(adaptive_evidence_at_zero, adaptive_evidence_at_hundred, skill),
		1.0
	)


func get_adaptive_influence() -> float:
	if not is_capability_enabled(CAP_ADAPT_ATTACKS):
		return 0.0
	var skill := pow(get_intelligence_ratio(), 0.75)
	return maxf(
		adaptive_influence * lerpf(0.35, 1.0, skill),
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
		CAP_DASH: return 50.0
		CAP_INTERRUPT: return 70.0
		CAP_CHARGED_ATTACK: return 75.0
		CAP_PREDICT: return 80.0
		CAP_COMBO: return 60.0
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
		CAP_COMBO: return combo_mode
	return CapabilityMode.DISABLED
