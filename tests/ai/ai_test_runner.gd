extends SceneTree


const ObservableTargetFixture = preload(
	"res://tests/ai/fixtures/observable_target_fixture.gd"
)

const EXPECTED_INTELLIGENCE_LEVELS: Array[int] = [20, 50, 80]

var assertion_count: int = 0
var failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_capability_thresholds()
	_test_impossible_actions_are_gated()
	_test_common_retreat_decision()
	_test_elite_flank_and_cover_decisions()
	_test_boss_dodge_and_interrupt_decisions()
	_test_empty_scores_fall_back_to_timed_hold()
	_test_same_seed_same_decisions()
	_test_cover_reservations()
	_test_cover_hold_commitment()
	_test_impact_preserves_confirmed_vision()
	_test_mixed_squad_assignments_are_consistent()
	_test_estimated_reach_drives_attack_planning()
	_test_dash_cancel_and_interrupt_windup_guards()
	await _test_observation_delay_filtering_and_no_raw_leak()
	await _test_visual_reacquisition_waits_for_reaction()
	await _test_low_intelligence_filters_telegraphs()
	await _test_mid_intelligence_reads_recovery_but_not_charge()
	await _test_charge_without_line_of_sight_is_not_observed()
	await _test_environment_obstacles_and_physical_cover()
	_test_variant_profiles_and_scenes_load()
	_finish()


func _test_capability_thresholds() -> void:
	var capabilities: Array[StringName] = [
		EnemyAIProfile.CAP_FLEE,
		EnemyAIProfile.CAP_SEARCH,
		EnemyAIProfile.CAP_HEAVY_ATTACK,
		EnemyAIProfile.CAP_TEAMWORK,
		EnemyAIProfile.CAP_FLANK,
		EnemyAIProfile.CAP_CIRCLE,
		EnemyAIProfile.CAP_COVER,
		EnemyAIProfile.CAP_ADAPT_ATTACKS,
		EnemyAIProfile.CAP_READ_TELEGRAPHS,
		EnemyAIProfile.CAP_DODGE,
		EnemyAIProfile.CAP_DASH,
		EnemyAIProfile.CAP_INTERRUPT,
		EnemyAIProfile.CAP_CHARGED_ATTACK,
		EnemyAIProfile.CAP_PREDICT
	]
	var expected_by_level: Dictionary = {
		20: [true, true, false, false, false, false, false, false, false, false, false, false, false, false],
		50: [true, true, true, true, true, true, true, true, false, false, false, false, false, false],
		80: [true, true, true, true, true, true, true, true, true, true, true, true, true, true]
	}
	var reaction_times: Array[float] = []
	var decision_noises: Array[float] = []
	var mistake_chances: Array[float] = []
	for intelligence: int in EXPECTED_INTELLIGENCE_LEVELS:
		var profile := _make_profile(float(intelligence), 801 + intelligence)
		var expected: Array = expected_by_level[intelligence]
		for index: int in capabilities.size():
			_expect_equal(
				profile.is_capability_enabled(capabilities[index]),
				bool(expected[index]),
				"capability %s al %d%%" % [String(capabilities[index]), intelligence]
			)
		reaction_times.append(profile.get_reaction_time())
		decision_noises.append(profile.get_decision_noise())
		mistake_chances.append(profile.get_mistake_chance())
	_expect(reaction_times[0] > reaction_times[1] and reaction_times[1] > reaction_times[2], "la reacción mejora de 20 a 50 y 80")
	_expect(decision_noises[0] > decision_noises[1] and decision_noises[1] > decision_noises[2], "el ruido de decisión baja de 20 a 50 y 80")
	_expect(mistake_chances[0] > mistake_chances[1] and mistake_chances[1] > mistake_chances[2], "los errores bajan de 20 a 50 y 80")
	var override_profile := _make_profile(20.0, 99)
	override_profile.dodge_mode = EnemyAIProfile.CapabilityMode.ENABLED
	_expect(override_profile.is_capability_enabled(EnemyAIProfile.CAP_DODGE), "ENABLED permite una capacidad bajo el umbral")
	override_profile.intelligence_percent = 80.0
	override_profile.dodge_mode = EnemyAIProfile.CapabilityMode.DISABLED
	_expect(not override_profile.is_capability_enabled(EnemyAIProfile.CAP_DODGE), "DISABLED bloquea una capacidad sobre el umbral")
	var no_search_profile := _make_profile(50.0, 5050)
	no_search_profile.search_mode = EnemyAIProfile.CapabilityMode.DISABLED
	var no_search_brain := EnemyUtilityBrain.new()
	no_search_brain.configure(no_search_profile)
	no_search_brain.current_action = &"none"
	var memory_context := _base_context()
	memory_context["visible"] = false
	memory_context["can_attack"] = false
	memory_context["attack_reaches"] = false
	var memory_scores := no_search_brain.score_actions(memory_context)
	_expect(not memory_scores.has(EnemyUtilityBrain.ACTION_SEARCH), "DISABLED elimina la acción search")
	_expect_equal(float(memory_scores.get(EnemyUtilityBrain.ACTION_APPROACH, -1.0)), 0.0, "sin search tampoco persigue memoria bajo el alias approach")


func _test_impossible_actions_are_gated() -> void:
	var context := _base_context()
	context.merge({
		"target_action": &"charge",
		"target_phase": &"telegraph",
		"target_facing_me": true,
		"inside_target_threat": true,
		"cover_available": true,
		"dash_ready": true,
		"interrupt_reaches": true
	}, true)
	var common_scores := _scores_for(20.0, context)
	for forbidden: StringName in [
		EnemyUtilityBrain.ACTION_FLANK,
		EnemyUtilityBrain.ACTION_CIRCLE,
		EnemyUtilityBrain.ACTION_COVER,
		EnemyUtilityBrain.ACTION_DODGE,
		EnemyUtilityBrain.ACTION_INTERRUPT
	]:
		_expect(not common_scores.has(forbidden), "20%% no genera acción imposible %s" % String(forbidden))
	var elite_scores := _scores_for(50.0, context)
	for allowed: StringName in [
		EnemyUtilityBrain.ACTION_FLANK,
		EnemyUtilityBrain.ACTION_CIRCLE,
		EnemyUtilityBrain.ACTION_COVER
	]:
		_expect(elite_scores.has(allowed), "50%% habilita acción táctica %s" % String(allowed))
	for forbidden: StringName in [
		EnemyUtilityBrain.ACTION_DODGE,
		EnemyUtilityBrain.ACTION_INTERRUPT
	]:
		_expect(not elite_scores.has(forbidden), "50%% no genera acción de jefe %s" % String(forbidden))
	var boss_scores := _scores_for(80.0, context)
	_expect(boss_scores.has(EnemyUtilityBrain.ACTION_DODGE), "80% genera dodge")
	_expect(boss_scores.has(EnemyUtilityBrain.ACTION_INTERRUPT), "80% genera interrupt")
	var safe_context := _base_context()
	safe_context["cover_available"] = false
	safe_context["interrupt_reaches"] = false
	var safe_scores := _scores_for(80.0, safe_context)
	_expect(float(safe_scores.get(EnemyUtilityBrain.ACTION_DODGE, -1.0)) <= 0.0, "dodge sin amenaza tiene utilidad nula")
	_expect(float(safe_scores.get(EnemyUtilityBrain.ACTION_COVER, -1.0)) <= 0.0, "cover inexistente tiene utilidad nula")
	_expect(float(safe_scores.get(EnemyUtilityBrain.ACTION_INTERRUPT, -1.0)) <= 0.0, "interrupt sin telegraph tiene utilidad nula")


func _test_common_retreat_decision() -> void:
	var context := _base_context()
	context.merge({
		"can_attack": false,
		"attack_reaches": false,
		"cooldown_ready": false,
		"health_ratio": 0.02,
		"stamina_ratio": 0.20,
		"distance": 58.0,
		"role": &"waiting"
	}, true)
	_expect_equal(
		_decide_without_error(20.0, context),
		EnemyUtilityBrain.ACTION_RETREAT,
		"el goblin común huye con vida crítica"
	)


func _test_elite_flank_and_cover_decisions() -> void:
	var flank_context := _base_context()
	flank_context.merge({
		"can_attack": false,
		"attack_reaches": false,
		"cooldown_ready": false,
		"distance": 58.0,
		"role": &"flank"
	}, true)
	_expect_equal(
		_decide_without_error(50.0, flank_context),
		EnemyUtilityBrain.ACTION_FLANK,
		"el élite flanquea cuando recibe ese rol"
	)
	var cover_context := _base_context()
	cover_context.merge({
		"can_attack": false,
		"attack_reaches": false,
		"health_ratio": 0.20,
		"stamina_ratio": 0.10,
		"distance": 82.0,
		"role": &"support",
		"target_action": &"charge",
		"target_phase": &"telegraph",
		"target_facing_me": true,
		"inside_target_threat": true,
		"cover_available": true
	}, true)
	_expect_equal(
		_decide_without_error(50.0, cover_context),
		EnemyUtilityBrain.ACTION_COVER,
		"el élite elige cobertura cuando está expuesto y debilitado"
	)


func _test_boss_dodge_and_interrupt_decisions() -> void:
	var dodge_context := _base_context()
	dodge_context.merge({
		"can_attack": false,
		"attack_reaches": false,
		"distance": 55.0,
		"target_action": &"charge",
		"target_phase": &"telegraph",
		"target_facing_me": true,
		"inside_target_threat": true,
		"dash_ready": true,
		"interrupt_reaches": false
	}, true)
	_expect_equal(
		_decide_without_error(80.0, dodge_context),
		EnemyUtilityBrain.ACTION_DODGE,
		"el jefe esquiva una carga que lo amenaza"
	)
	var interrupt_context := _base_context()
	interrupt_context.merge({
		"can_attack": false,
		"attack_reaches": false,
		"distance": 55.0,
		"target_action": &"charge",
		"target_phase": &"telegraph",
		"target_facing_me": false,
		"inside_target_threat": false,
		"dash_ready": false,
		"interrupt_reaches": true
	}, true)
	_expect_equal(
		_decide_without_error(80.0, interrupt_context),
		EnemyUtilityBrain.ACTION_INTERRUPT,
		"el jefe interrumpe una carga alcanzable"
	)


func _test_empty_scores_fall_back_to_timed_hold() -> void:
	var profile := _make_profile(0.0, 707)
	profile.search_mode = EnemyAIProfile.CapabilityMode.DISABLED
	profile.flee_mode = EnemyAIProfile.CapabilityMode.DISABLED
	profile.approach_utility = 0.0
	profile.hold_utility = 0.0
	var brain := EnemyUtilityBrain.new()
	brain.configure(profile, 3)
	brain.decision_time_left = 0.0
	brain.commitment_time_left = 0.0
	brain.last_was_mistake = true
	brain.last_selected_score = 99.0
	brain.last_decision_confidence = 1.0
	var context := _base_context()
	context["visible"] = false
	context["can_attack"] = false
	context["attack_reaches"] = false
	context["cooldown_ready"] = false
	context["stamina_ratio"] = 1.0
	_expect_equal(brain.decide(context), EnemyUtilityBrain.ACTION_HOLD, "sin acciones viables cae en HOLD")
	_expect(brain.decision_time_left > 0.0, "el HOLD fallback rearma el intervalo de decisión")
	_expect(brain.commitment_time_left > 0.0, "el HOLD fallback recibe compromiso normal")
	_expect(not brain.last_was_mistake, "el HOLD fallback limpia el flag de error")
	_expect_equal(brain.last_selected_score, 0.0, "el HOLD fallback limpia el score seleccionado")
	_expect_equal(brain.last_decision_confidence, 0.0, "el HOLD fallback limpia la confianza stale")


func _test_same_seed_same_decisions() -> void:
	var profile := _make_profile(50.0, 424242)
	var first := EnemyUtilityBrain.new()
	var second := EnemyUtilityBrain.new()
	var offset_variant := EnemyUtilityBrain.new()
	first.configure(profile, 7)
	second.configure(profile, 7)
	offset_variant.configure(profile, 8)
	_expect_equal(first.decision_time_left, second.decision_time_left, "mismo seed y offset reproducen el reloj inicial")
	_expect(not is_equal_approx(first.decision_time_left, offset_variant.decision_time_left), "offset distinto evita sincronizar enemigos con el mismo perfil")
	var context := _base_context()
	context.merge({
		"can_attack": true,
		"attack_reaches": true,
		"distance": 76.0,
		"role": &"flank",
		"cover_available": true,
		"health_ratio": 0.38,
		"stamina_ratio": 0.54
	}, true)
	for turn: int in 24:
		context["distance"] = 55.0 + float(turn % 5) * 11.0
		var first_action := first.decide(context)
		var second_action := second.decide(context)
		_expect_equal(first_action, second_action, "mismo seed produce la misma acción en turno %d" % turn)
		_expect_equal(first.last_scores, second.last_scores, "mismo seed produce los mismos scores en turno %d" % turn)
		_expect_equal(first.last_was_mistake, second.last_was_mistake, "mismo seed reproduce errores en turno %d" % turn)


func _test_cover_reservations() -> void:
	var point := EnemyCoverPoint.new()
	var first := Node2D.new()
	var second := Node2D.new()
	_expect(point.is_available_for(first), "una cobertura nueva está libre")
	point.reserve(first, 1.0)
	_expect(point.is_available_for(first) and not point.is_available_for(second), "la reserva es exclusiva salvo para su dueño")
	_expect(not point.reserve(second, 1.0), "otro enemigo no puede sobrescribir una reserva activa")
	_expect(point.is_available_for(first), "un intento rival no desplaza al dueño de la cobertura")
	point.release(second)
	_expect(not point.is_available_for(second), "un tercero no puede liberar una reserva ajena")
	point.release(first)
	_expect(point.is_available_for(second), "el dueño puede liberar la cobertura")
	point.free()
	first.free()
	second.free()


func _test_cover_hold_commitment() -> void:
	var enemy := Enemy.new()
	enemy.ai_profile = _make_profile(50.0, 5150)
	enemy.ai_profile.cover_hold_duration = 0.5
	enemy.ai_profile.maximum_commitment = 0.25
	enemy.utility_brain = EnemyUtilityBrain.new()
	enemy.utility_brain.configure(enemy.ai_profile, 5)
	var point := EnemyCoverPoint.new()
	point.position = Vector2.ZERO
	enemy.ai_action = &"cover"
	enemy.ai_cover_candidate = {"point": point, "position": Vector2.ZERO}
	enemy._begin_cover_hold()
	_expect(enemy.ai_is_holding_cover, "llegar al marcador inicia un compromiso real de cobertura")
	_expect(is_equal_approx(enemy.ai_cover_hold_time_left, 0.5), "el hold usa cover_hold_duration del perfil")
	var challenger := Node2D.new()
	_expect(not point.is_available_for(challenger), "el punto permanece reservado durante el hold")
	enemy._update_ai_mobility_timers(0.25)
	_expect(enemy.ai_is_holding_cover, "la cobertura no se abandona antes de tiempo")
	enemy._update_ai_mobility_timers(0.30)
	_expect(not enemy.ai_is_holding_cover, "la cobertura termina al expirar su duración")
	_expect(enemy.ai_cover_reentry_cooldown_left > 0.0, "al salir aplica cooldown contra loops de cobertura")
	_expect(point.is_available_for(challenger), "al terminar libera la reserva")
	challenger.free()
	point.free()
	enemy.free()


func _test_impact_preserves_confirmed_vision() -> void:
	var perception := EnemyPerception.new()
	perception.profile = _make_profile(80.0, 8180)
	perception.has_line_of_sight = true
	perception.has_confirmed_visual_contact = true
	perception.notice_position(Vector2(12.0, 8.0))
	_expect(perception.has_confirmed_visual_contact, "recibir daño no borra una visión ya confirmada")
	perception.has_line_of_sight = false
	perception.notice_position(Vector2(24.0, 8.0))
	_expect(not perception.has_confirmed_visual_contact, "un impacto oculto solo revela posición, no visión")


func _test_mixed_squad_assignments_are_consistent() -> void:
	var common_profile := _make_profile(20.0, 120)
	var elite_profile := _make_profile(50.0, 150)
	var common_data := EnemyData.new()
	common_data.squad_id = &"test_pack"
	common_data.coordination_radius = 500.0
	common_data.max_simultaneous_attackers = 1
	var elite_data := common_data.duplicate() as EnemyData
	var pressure := _make_squad_enemy(Vector2.ZERO, Vector2(50.0, 0.0), common_data, common_profile)
	var waiting := _make_squad_enemy(Vector2(10.0, 0.0), Vector2(500.0, 0.0), common_data, common_profile)
	var flanker := _make_squad_enemy(Vector2(20.0, 0.0), Vector2(600.0, 0.0), elite_data, elite_profile)
	var members: Array[Node] = [pressure, waiting, flanker]
	var coordinator := EnemySquadCoordinator.new()
	var pressure_assignment := coordinator.get_assignment(pressure, members, Vector2(50.0, 0.0), common_data, common_profile)
	var waiting_assignment := coordinator.get_assignment(waiting, members, Vector2(500.0, 0.0), common_data, common_profile)
	var flank_assignment := coordinator.get_assignment(flanker, members, Vector2(600.0, 0.0), elite_data, elite_profile)
	_expect_equal(StringName(pressure_assignment.get("role")), &"pressure", "la escuadra mixta concede un solo token al miembro listo")
	_expect(bool(pressure_assignment.get("can_attack")), "el rol pressure puede atacar")
	_expect_equal(StringName(waiting_assignment.get("role")), &"waiting", "el común sin token espera sin fingir teamwork")
	_expect(not bool(waiting_assignment.get("can_attack")), "el común waiting no rompe el límite de atacantes")
	_expect_equal(StringName(flank_assignment.get("role")), &"flank", "solo el élite capaz recibe el rol flank")
	_expect(not bool(flank_assignment.get("can_attack")), "el flanqueador no roba el token de presión")
	pressure.free()
	waiting.free()
	flanker.free()


func _make_squad_enemy(
	position: Vector2,
	estimated_target: Vector2,
	data: EnemyData,
	profile: EnemyAIProfile
) -> Enemy:
	var enemy := Enemy.new()
	enemy.position = position
	enemy.enemy_data = data
	enemy.ai_profile = profile
	enemy.health = data.max_health
	enemy.stamina = data.max_stamina
	enemy.perception = EnemyPerception.new()
	enemy.perception.is_aware = true
	enemy.perception.last_known_position = estimated_target
	return enemy


func _test_estimated_reach_drives_attack_planning() -> void:
	var enemy := Enemy.new()
	enemy.enemy_data = EnemyData.new()
	enemy.ai_profile = _make_profile(80.0, 8080)
	enemy.primary_attack = AttackData.new()
	enemy.primary_attack.hitbox_length = 48.0
	enemy.primary_attack.hitbox_width = 30.0
	enemy.primary_attack.hitbox_start_offset = 8.0
	enemy.perception = EnemyPerception.new()
	enemy.perception.profile = enemy.ai_profile
	enemy.perception.is_aware = true
	enemy.perception.has_confirmed_visual_contact = true
	enemy.perception.last_known_position = Vector2(42.0, 0.0)
	_expect_equal(enemy._get_reachable_attacks().size(), 1, "el planeamiento ataca una estimación dentro del hitbox")
	enemy.perception.last_known_position = Vector2(180.0, 0.0)
	_expect_equal(enemy._get_reachable_attacks().size(), 0, "el planeamiento no consulta un collider real fuera de la estimación")
	enemy.free()


func _test_dash_cancel_and_interrupt_windup_guards() -> void:
	var packed := load("res://scenes/enemies/goblin/goblin_boss.tscn") as PackedScene
	var enemy := packed.instantiate() as Enemy
	enemy.enemy_animated = enemy.get_node_or_null("EnemyAnimated") as AnimatedSprite2D
	enemy.navigation_agent = enemy.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	enemy.health = enemy.enemy_data.max_health
	enemy.stamina = enemy.enemy_data.max_stamina
	enemy.utility_brain = EnemyUtilityBrain.new()
	enemy.utility_brain.configure(enemy.ai_profile, 91)
	enemy.tactical_positioning = EnemyTacticalPositioning.new()
	enemy.tactical_positioning.configure(enemy.ai_profile, 91)
	enemy.ai_dash_time_left = 0.12
	enemy.ai_dash_direction = Vector2.RIGHT
	enemy.enemy_animated.self_modulate = Color(0.72, 0.9, 1.25, 1.0)
	enemy._cancel_ai_dash()
	_expect_equal(enemy.ai_dash_time_left, 0.0, "un impacto puede cancelar por completo el timer de dash")
	_expect_equal(enemy.ai_dash_direction, Vector2.ZERO, "cancelar dash limpia la dirección pendiente")
	_expect_equal(enemy.enemy_animated.self_modulate, Color.WHITE, "cancelar dash restaura el telegraph visual")
	enemy.perception = EnemyPerception.new()
	enemy.perception.profile = enemy.ai_profile
	enemy.perception.is_aware = true
	enemy.perception.has_confirmed_visual_contact = true
	enemy.perception.last_known_position = Vector2(-50.0, 0.0)
	enemy.perception.observation_source = &"vision"
	enemy.perception.observation = {
		"source": &"vision",
		"action": &"charge",
		"phase": &"telegraph",
		"facing": Vector2.RIGHT
	}
	enemy.current_attack = enemy.interrupt_attack
	enemy.current_attack_phase = "windup"
	enemy.ai_action = &"attack"
	enemy.debug_distance_to_player = 50.0
	_expect(not enemy._try_reactive_attack_cancel(), "el gancho interruptor no se autocancela para esquivar la carga que intenta cortar")
	_expect(enemy.current_attack == enemy.interrupt_attack, "el ataque interruptor conserva su windup")
	enemy.free()


func _test_observation_delay_filtering_and_no_raw_leak() -> void:
	var fixture := await _create_perception_fixture(false)
	var enemy := fixture["enemy"] as CharacterBody2D
	var target := fixture["target"] as CharacterBody2D
	var world := fixture["world"] as Node2D
	target.global_position = Vector2(120.0, 0.0)
	target.velocity = Vector2(100.0, 0.0)
	var profile := _make_profile(80.0, 1771)
	_configure_fixed_perception(profile, 0.20, 28.0)
	var perception := EnemyPerception.new()
	perception.configure(enemy, target, profile, 11)
	perception.update(0.01, Vector2.RIGHT)
	_expect(perception.has_line_of_sight, "fixture de percepción tiene LOS")
	_expect(not perception.has_confirmed_visual_contact, "LOS raw todavía no autoriza decisiones visuales")
	_expect(not perception.get_observed_combat_state().has("source"), "no entrega observación en el frame de captura")
	perception.update(0.18, Vector2.RIGHT)
	_expect(not perception.get_observed_combat_state().has("source"), "respeta la demora antes del umbral")
	perception.update(0.03, Vector2.RIGHT)
	var observed := perception.get_observed_combat_state()
	_expect(not observed.is_empty(), "entrega observación después de reaction_time")
	_expect(perception.has_confirmed_visual_contact, "el contacto visual se confirma después de reaction_time")
	_expect_equal(StringName(observed.get("source", &"none")), &"vision", "la fuente entregada es visión")
	_expect_equal(StringName(observed.get("action", &"none")), &"charge", "80% reconoce una carga visible")
	_expect(float(observed.get("cue_age", 0.0)) >= 0.19, "la edad incluye la demora real")
	_expect_equal(Vector2(observed.get("position", Vector2.ZERO)), perception.last_known_position, "position pública es la estimada")
	_expect_equal(Vector2(observed.get("velocity", Vector2.ZERO)), perception.estimated_velocity, "velocity pública es la estimada")
	_expect(Vector2(observed.get("velocity", Vector2.ZERO)) != target.velocity, "no filtra la velocidad raw exacta")
	_expect(not observed.has("raw_position") and not observed.has("raw_velocity"), "no expone aliases de datos raw")
	_expect(not observed.has("private_probe"), "la vista filtrada no reenvía campos privados del proveedor")
	world.queue_free()
	await process_frame


func _test_visual_reacquisition_waits_for_reaction() -> void:
	var fixture := await _create_perception_fixture(false)
	var enemy := fixture["enemy"] as CharacterBody2D
	var target := fixture["target"] as CharacterBody2D
	var world := fixture["world"] as Node2D
	target.global_position = Vector2(90.0, 0.0)
	var profile := _make_profile(80.0, 2771)
	_configure_fixed_perception(profile, 0.10, 8.0)
	profile.vision_range = 120.0
	var perception := EnemyPerception.new()
	perception.configure(enemy, target, profile, 12)
	perception.update(0.01, Vector2.RIGHT)
	perception.update(0.11, Vector2.RIGHT)
	_expect(perception.has_confirmed_visual_contact, "el primer contacto fue confirmado")
	target.global_position = Vector2(300.0, 0.0)
	perception.update(0.02, Vector2.RIGHT)
	_expect(not perception.has_line_of_sight and not perception.has_confirmed_visual_contact, "perder LOS elimina el permiso visual")
	target.global_position = Vector2(90.0, 0.0)
	perception.update(0.01, Vector2.RIGHT)
	_expect(perception.has_line_of_sight, "la reaparición se detecta como estímulo raw")
	_expect(not perception.has_confirmed_visual_contact, "la reaparición no salta la reacción durante memoria")
	perception.update(0.06, Vector2.RIGHT)
	perception.update(0.02, Vector2.RIGHT)
	_expect(not perception.has_confirmed_visual_contact, "una muestra pendiente del epoch anterior no confirma la reaparición")
	perception.update(0.08, Vector2.RIGHT)
	_expect(perception.has_confirmed_visual_contact, "el nuevo epoch visual se confirma tras su propia demora")
	world.queue_free()
	await process_frame


func _test_low_intelligence_filters_telegraphs() -> void:
	var fixture := await _create_perception_fixture(false)
	var enemy := fixture["enemy"] as CharacterBody2D
	var target := fixture["target"] as CharacterBody2D
	var world := fixture["world"] as Node2D
	target.global_position = Vector2(90.0, 0.0)
	var profile := _make_profile(20.0, 981)
	_configure_fixed_perception(profile, 0.10, 12.0)
	var perception := EnemyPerception.new()
	perception.configure(enemy, target, profile, 4)
	perception.update(0.01, Vector2.RIGHT)
	perception.update(0.11, Vector2.RIGHT)
	var observed := perception.get_observed_combat_state()
	_expect(not observed.is_empty(), "20% recibe posición tras su demora")
	_expect_equal(StringName(observed.get("action", &"missing")), &"none", "20% no reconoce la carga")
	_expect_equal(StringName(observed.get("phase", &"missing")), &"none", "20% no recibe la fase del ataque")
	_expect_equal(StringName(observed.get("attack_family", &"missing")), &"none", "20% no recibe la familia del ataque")
	world.queue_free()
	await process_frame


func _test_mid_intelligence_reads_recovery_but_not_charge() -> void:
	var charge_fixture := await _create_perception_fixture(false)
	var charge_enemy := charge_fixture["enemy"] as CharacterBody2D
	var charge_target := charge_fixture["target"] as CharacterBody2D
	var charge_world := charge_fixture["world"] as Node2D
	charge_target.global_position = Vector2(90.0, 0.0)
	var profile := _make_profile(50.0, 1050)
	_configure_fixed_perception(profile, 0.10, 12.0)
	var charge_perception := EnemyPerception.new()
	charge_perception.configure(charge_enemy, charge_target, profile, 4)
	charge_perception.update(0.01, Vector2.RIGHT)
	charge_perception.update(0.11, Vector2.RIGHT)
	var charge_observed := charge_perception.get_observed_combat_state()
	_expect_equal(StringName(charge_observed.get("action", &"missing")), &"none", "50% todavía no anticipa una carga")
	_expect_equal(StringName(charge_observed.get("phase", &"missing")), &"none", "50% filtra la fase telegraph")
	charge_world.queue_free()
	await process_frame

	var recovery_fixture := await _create_perception_fixture(false)
	var recovery_enemy := recovery_fixture["enemy"] as CharacterBody2D
	var recovery_target := recovery_fixture["target"] as CharacterBody2D
	var recovery_world := recovery_fixture["world"] as Node2D
	recovery_target.global_position = Vector2(90.0, 0.0)
	recovery_target.set("observable_action", &"attack")
	recovery_target.set("observable_phase", &"recovery")
	var recovery_perception := EnemyPerception.new()
	recovery_perception.configure(recovery_enemy, recovery_target, profile, 5)
	recovery_perception.update(0.01, Vector2.RIGHT)
	recovery_perception.update(0.11, Vector2.RIGHT)
	var recovery_observed := recovery_perception.get_observed_combat_state()
	_expect_equal(StringName(recovery_observed.get("action", &"none")), &"attack", "50% reconoce una apertura ya visible")
	_expect_equal(StringName(recovery_observed.get("phase", &"none")), &"recovery", "50% conserva recovery para adaptar su ataque")
	_expect_equal(StringName(recovery_observed.get("attack_family", &"missing")), &"none", "50% no obtiene la familia privada del golpe")
	recovery_world.queue_free()
	await process_frame


func _test_charge_without_line_of_sight_is_not_observed() -> void:
	var fixture := await _create_perception_fixture(true)
	var enemy := fixture["enemy"] as CharacterBody2D
	var target := fixture["target"] as CharacterBody2D
	var world := fixture["world"] as Node2D
	target.global_position = Vector2(120.0, 0.0)
	target.velocity = Vector2.ZERO
	var profile := _make_profile(80.0, 811)
	_configure_fixed_perception(profile, 0.10, 8.0)
	profile.hearing_range = 0.0
	var perception := EnemyPerception.new()
	perception.configure(enemy, target, profile, 2)
	for _step: int in 8:
		perception.update(0.05, Vector2.RIGHT)
	_expect(not perception.has_line_of_sight, "la pared bloquea LOS")
	_expect(not perception.heard_target, "la carga quieta detrás de pared no produce oído")
	_expect(not perception.is_aware, "sin estímulo no adquiere conciencia")
	var observed := perception.get_observed_combat_state()
	_expect(not observed.has("source") and StringName(observed.get("action", &"none")) == &"none", "una carga sin LOS nunca llega al snapshot")
	profile.hearing_range = 200.0
	profile.hearing_velocity_threshold = 40.0
	target.set("movement_noise", 100.0)
	perception.update(0.01, Vector2.RIGHT)
	perception.update(0.11, Vector2.RIGHT)
	observed = perception.get_observed_combat_state()
	_expect(perception.heard_target, "una señal ruidosa detrás de pared sí puede oírse")
	_expect_equal(StringName(observed.get("source", &"none")), &"hearing", "la señal ocluida conserva fuente auditiva")
	_expect_equal(StringName(observed.get("action", &"missing")), &"none", "el oído no revela una carga ni su telegraph")
	world.queue_free()
	await process_frame


func _test_environment_obstacles_and_physical_cover() -> void:
	var packed := load("res://scenes/tutorial/frontier_environment.tscn") as PackedScene
	var environment := packed.instantiate() as Node2D
	root.add_child(environment)
	await process_frame
	var collisions := environment.get_node("Collisions")
	var static_body_count := 0
	for node: Node in collisions.get_children():
		if not node is StaticBody2D:
			continue
		static_body_count += 1
		_expect(node.get_node_or_null("NavigationObstacle2D") is NavigationObstacle2D, "%s replica su collider en avoidance" % node.name)
	_expect(static_body_count >= 12, "el escenario incluye obstáculos físicos en la zona de combate")
	var observer := CharacterBody2D.new()
	observer.position = Vector2(3495.0, 790.0)
	environment.add_child(observer)
	await physics_frame
	var positioning := EnemyTacticalPositioning.new()
	_expect(
		positioning._is_sight_blocked(observer, observer.global_position, Vector2(3000.0, 790.0), 1),
		"las rocas orientales bloquean físicamente visión y ataques hacia el acceso oeste"
	)
	_expect(
		not positioning._is_sight_blocked(observer, Vector2(3000.0, 1180.0), Vector2(2800.0, 1180.0), 1),
		"una línea abierta no recibe cobertura falsa"
	)
	environment.queue_free()
	await process_frame


func _test_variant_profiles_and_scenes_load() -> void:
	var profile_paths := _collect_files("res://data/ai", ".tres")
	var found_profiles: Dictionary = {}
	for path: String in profile_paths:
		var resource := load(path)
		if resource is EnemyAIProfile:
			var profile := resource as EnemyAIProfile
			var level := roundi(profile.intelligence_percent)
			if level in EXPECTED_INTELLIGENCE_LEVELS:
				found_profiles[level] = path
	for level: int in EXPECTED_INTELLIGENCE_LEVELS:
		_expect(found_profiles.has(level), "existe y carga un perfil de IA al %d%%" % level)
	var scene_paths := _collect_files("res://scenes/enemies", ".tscn")
	var found_scenes: Dictionary = {}
	for path: String in scene_paths:
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate()
		var enemy := _find_enemy(instance)
		if enemy != null:
			var profile := enemy.get("ai_profile") as EnemyAIProfile
			if profile != null:
				var level := roundi(profile.intelligence_percent)
				if level in EXPECTED_INTELLIGENCE_LEVELS:
					found_scenes[level] = path
					var data := enemy.get("enemy_data") as EnemyData
					if data != null:
						enemy.set("stamina", data.max_stamina)
					var available_attacks: Array[AttackData] = enemy._get_available_attacks()
					var expected_attack_count: int = int({20: 1, 50: 2, 80: 3}.get(level, 0))
					_expect_equal(available_attacks.size(), expected_attack_count, "la escena %d%% solo habilita sus ataques físicos/cognitivos" % level)
					_expect_equal(enemy._can_ai_dash(), level == 80, "solo la variante 80% puede ejecutar dash")
					var animated := enemy.get_node_or_null("EnemyAnimated") as AnimatedSprite2D
					enemy.enemy_animated = animated
					enemy._setup_action_animations()
					_expect(animated != null and animated.sprite_frames.has_animation(&"walk_s"), "la variante %d%% instala animación walk por familia visual" % level)
					_expect(animated != null and animated.sprite_frames.has_animation(&"attack_s"), "la variante %d%% instala telegraph attack por familia visual" % level)
					if level == 80:
						_expect(data != null and data.can_dash, "la escena 80% posee dash físico")
						_expect(data != null and data.can_cancel_attack_windup, "la escena 80% puede cancelar windup")
						var interrupt_attack := enemy.get("interrupt_attack") as AttackData
						_expect(interrupt_attack != null, "la escena 80% equipa un ataque interruptor físico")
						_expect(interrupt_attack != null and interrupt_attack.knockback_force > 150.0, "el ataque interruptor supera el umbral base de carga")
		instance.free()
	for level: int in EXPECTED_INTELLIGENCE_LEVELS:
		_expect(found_scenes.has(level), "existe, instancia y conecta una escena enemiga al %d%%" % level)


func _make_profile(intelligence: float, seed: int) -> EnemyAIProfile:
	var profile := EnemyAIProfile.new()
	profile.intelligence_percent = intelligence
	profile.deterministic_seed = seed
	return profile


func _configure_fixed_perception(profile: EnemyAIProfile, reaction: float, error: float) -> void:
	profile.reaction_time_at_zero = reaction
	profile.reaction_time_at_hundred = reaction
	profile.reaction_time_multiplier = 1.0
	profile.memory_position_error_at_zero = error
	profile.memory_position_error_at_hundred = error
	profile.vision_range = 500.0
	profile.vision_angle_degrees = 360.0
	profile.hearing_range = 0.0
	profile.sight_collision_mask = 1


func _base_context() -> Dictionary:
	return {
		"visible": true,
		"aware": true,
		"can_attack": true,
		"attack_reaches": true,
		"cooldown_ready": true,
		"health_ratio": 1.0,
		"stamina_ratio": 1.0,
		"distance": 58.0,
		"role": &"pressure",
		"target_action": &"none",
		"target_phase": &"none",
		"target_facing_me": false,
		"inside_target_threat": false,
		"cover_available": false,
		"dash_ready": false,
		"interrupt_reaches": false
	}


func _scores_for(intelligence: float, context: Dictionary) -> Dictionary:
	var profile := _make_profile(intelligence, 300 + roundi(intelligence))
	var brain := EnemyUtilityBrain.new()
	brain.configure(profile)
	brain.current_action = &"none"
	return brain.score_actions(context)


func _decide_without_error(intelligence: float, context: Dictionary) -> StringName:
	var profile := _make_profile(intelligence, 600 + roundi(intelligence))
	profile.decision_error_multiplier = 0.0
	var brain := EnemyUtilityBrain.new()
	brain.configure(profile)
	brain.current_action = &"none"
	return brain.decide(context)


func _create_perception_fixture(with_wall: bool) -> Dictionary:
	var world := Node2D.new()
	world.name = "AIPerceptionFixture"
	root.add_child(world)
	var enemy := CharacterBody2D.new()
	enemy.name = "Observer"
	enemy.global_position = Vector2.ZERO
	world.add_child(enemy)
	var target := ObservableTargetFixture.new() as CharacterBody2D
	target.name = "ObservableTarget"
	target.global_position = Vector2(120.0, 0.0)
	world.add_child(target)
	if with_wall:
		var wall := StaticBody2D.new()
		wall.name = "Occluder"
		wall.position = Vector2(60.0, 0.0)
		wall.collision_layer = 1
		wall.collision_mask = 0
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(12.0, 180.0)
		collision.shape = shape
		wall.add_child(collision)
		world.add_child(wall)
	await physics_frame
	return {"world": world, "enemy": enemy, "target": target}


func _collect_files(directory: String, extension: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(extension):
			result.append(directory.path_join(file_name))
	for child_directory: String in DirAccess.get_directories_at(directory):
		result.append_array(_collect_files(directory.path_join(child_directory), extension))
	return result


func _find_enemy(node: Node) -> Enemy:
	if node is Enemy:
		return node as Enemy
	for child: Node in node.get_children():
		var result := _find_enemy(child)
		if result != null:
			return result
	return null


func _expect(condition: bool, message: String) -> void:
	assertion_count += 1
	if not condition:
		failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s | esperado=%s actual=%s" % [message, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("AI_TESTS_OK | %d assertions" % assertion_count)
		quit(0)
		return
	printerr("AI_TESTS_FAILED | %d/%d" % [failures.size(), assertion_count])
	for failure: String in failures:
		printerr(" - " + failure)
	quit(1)
