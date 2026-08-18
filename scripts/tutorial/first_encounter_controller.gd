class_name FirstEncounterController
extends Node


enum QuestStage {
	MEET_MAELA,
	HUNTING_PASS,
	RETURN_PASS,
	FIELD_QUEST_AVAILABLE,
	INVESTIGATE_FIELD,
	RETURN_EVIDENCE,
	FIND_IVAR,
	PURGE_HEART,
	RETURN_IVAR,
	COMPLETED
}


const REWARD_CHARM: ItemData = preload("res://data/items/equipment/iron_charm.tres")
const REWARD_BOOTS: ItemData = preload("res://data/items/equipment/stalker_boots.tres")
const REWARD_SWORD: ItemData = preload("res://data/items/equipment/rusted_sword.tres")
const REWARD_SHARDS: ItemData = preload("res://data/items/materials/goblin_shard.tres")
const PICKUP_SCENE: PackedScene = preload("res://scenes/items/item_pickup.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/enemies/goblin/goblin.tscn")


var stage: QuestStage = QuestStage.MEET_MAELA
var pass_enemies_total: int = 0
var pass_enemies_defeated: int = 0
var sites_investigated: int = 0
var field_enemies_total: int = 0
var field_enemies_defeated: int = 0
var heart_enemies_total: int = 0
var heart_enemies_defeated: int = 0

var player: Node2D
var maela: TutorialNPC
var ivar: TutorialNPC
var dialogue_ui: DialogueUI
var quest_tracker: QuestTracker
var world_map: WorldMapUI
var investigation_points: Array[InvestigationPoint] = []


func _ready() -> void:

	call_deferred("_initialize_campaign")


func _initialize_campaign() -> void:

	player = get_node("../World/Environment/Player") as Node2D
	maela = get_node("../Maela") as TutorialNPC
	ivar = get_node("../Ivar") as TutorialNPC
	dialogue_ui = get_node("../DialogueUI") as DialogueUI
	quest_tracker = get_node("../QuestTracker") as QuestTracker
	world_map = get_node("../WorldMapUI") as WorldMapUI

	var environment: Node = get_node("../World/Environment")
	maela.reparent(environment, true)
	ivar.reparent(environment, true)
	maela.position = Vector2(930, 505)
	ivar.position = Vector2(2025, 1070)
	player.position = Vector2(1010, 545)

	var camera: Camera2D = player.get_node("Camera2D") as Camera2D
	camera.limit_left = 100
	camera.limit_top = 100
	camera.limit_right = 2500
	camera.limit_bottom = 1500

	_disable_debug_visuals()
	_initialize_pass_enemies()
	_initialize_investigation_points(environment)

	maela.interacted.connect(_on_maela_interacted)
	ivar.interacted.connect(_on_ivar_interacted)
	maela.set_quest_marker("!", Color(1.0, 0.78, 0.18, 1.0))
	ivar.set_quest_marker("", Color.WHITE)
	ivar.set_interaction_enabled(false)
	quest_tracker.set_quest(
		"EL PASO DE MAELA",
		"Habla con Maela junto al refugio.",
		"ACÉRCATE Y PULSA F  ·  M ABRE EL MAPA"
	)
	world_map.set_quest_marker(maela.global_position, "Habla con Maela")
	quest_tracker.show_notification("Paso de Ceniza descubierto", Color(0.95, 0.78, 0.38, 1.0))


func _disable_debug_visuals() -> void:

	player.show_attack_debug = false
	for debug_polygon: Polygon2D in [
		player.normal_attack_debug,
		player.heavy_attack_debug,
		player.charged_attack_debug
	]:
		if debug_polygon != null:
			debug_polygon.visible = false


func _initialize_pass_enemies() -> void:

	var positions: Array[Vector2] = [Vector2(670, 405), Vector2(560, 475), Vector2(650, 555)]
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	pass_enemies_total = enemies.size()
	for index: int in range(enemies.size()):
		var enemy: Enemy = enemies[index] as Enemy
		if enemy == null:
			continue
		enemy.add_to_group("tutorial_targets")
		enemy.position = positions[index % positions.size()]
		_prepare_enemy_visuals(enemy)
		enemy.set_physics_process(false)
		enemy.defeated.connect(_on_pass_enemy_defeated)


func _initialize_investigation_points(environment: Node) -> void:

	var positions: Array[Vector2] = [Vector2(1390, 700), Vector2(1660, 870), Vector2(1880, 720)]
	var nodes: Array[Node] = get_tree().get_nodes_in_group("investigation_points")
	for index: int in range(nodes.size()):
		var point: InvestigationPoint = nodes[index] as InvestigationPoint
		if point == null:
			continue
		point.reparent(environment, true)
		point.position = positions[index % positions.size()]
		point.point_id = StringName("battlefield_scar_" + str(index + 1))
		point.set_active(false)
		point.investigated.connect(_on_investigation_point_used)
		investigation_points.append(point)


func _prepare_enemy_visuals(enemy: Enemy) -> void:

	enemy.debug_combat = false
	enemy.debug_ai_scores = false
	if enemy.debug_ai_label != null:
		enemy.debug_ai_label.visible = false
	enemy.queue_redraw()


func _on_maela_interacted() -> void:

	if dialogue_ui.is_dialogue_active():
		return
	match stage:
		QuestStage.MEET_MAELA:
			_show_intro_dialogue()
		QuestStage.HUNTING_PASS:
			_show_pass_progress()
		QuestStage.RETURN_PASS:
			_show_pass_completion()
		QuestStage.FIELD_QUEST_AVAILABLE:
			_show_world_revelation()
		QuestStage.INVESTIGATE_FIELD:
			_show_field_progress()
		QuestStage.RETURN_EVIDENCE:
			_show_evidence_dialogue()
		_:
			dialogue_ui.show_dialogue("Maela", [
				"Seguí el camino hacia el este. Ivar vigila desde la Torre Quebrada, si todavía conserva la razón.",
				"Abrí el mapa con M si perdés la ruta."
			])


func _on_ivar_interacted() -> void:

	if dialogue_ui.is_dialogue_active():
		return
	match stage:
		QuestStage.FIND_IVAR:
			_show_ivar_discovery()
		QuestStage.PURGE_HEART:
			dialogue_ui.show_dialogue("Ivar · Explorador marcado", [
				"La fosa queda al sudeste. Si empezás a oír tu propia voz llamándote desde allí, no le respondas.",
				"Destruí todo lo que se mueva alrededor del corazón negro."
			])
		QuestStage.RETURN_IVAR:
			_show_final_dialogue()
		QuestStage.COMPLETED:
			dialogue_ui.show_dialogue("Ivar", [
				"No purgaste el continente, pero hiciste callar una de sus heridas.",
				"Si querés unir los asentamientos, vas a necesitar que sus líderes crean en algo más que sobrevivir."
			])


func _show_intro_dialogue() -> void:

	maela.set_interaction_enabled(false)
	dialogue_ui.show_dialogue("Maela · Guardiana del Paso", [
		"Ahí estás. Llegaste justo antes de que el Paso de Ceniza quedara cerrado por completo.",
		"Tres goblins tomaron el sendero. En estas tierras hasta las alimañas aprendieron a cazar en grupo.",
		"Movete con WASD. Mantené CTRL para agacharte: harás menos ruido y podrás elegir cuándo empezar el combate.",
		"Atacá con clic izquierdo. El derecho prepara golpes fuertes; un doble toque de movimiento activa tu dash.",
		"Limpiá el paso y volvé. Si tu ambición es tan grande como decís, empezá demostrando que sirve para algo."
	], _accept_pass_quest)


func _accept_pass_quest() -> void:

	stage = QuestStage.HUNTING_PASS
	maela.set_quest_marker("", Color.WHITE)
	maela.set_interaction_enabled(true)
	for enemy_node: Node in get_tree().get_nodes_in_group("tutorial_targets"):
		enemy_node.set_physics_process(true)
	_update_pass_objective()
	world_map.set_quest_marker(Vector2(630, 480), "Limpia el Paso")
	quest_tracker.show_notification("Misión iniciada: limpia el sendero", Color(1.0, 0.78, 0.24, 1.0))


func _show_pass_progress() -> void:

	dialogue_ui.show_dialogue("Maela", [
		"Todavía escucho pasos entre los árboles.",
		"Usá la hierba alta para acercarte agachado. Si te rodean, rompé el cerco con un dash."
	])


func _on_pass_enemy_defeated(_enemy: Enemy) -> void:

	if stage != QuestStage.HUNTING_PASS:
		return
	pass_enemies_defeated += 1
	_update_pass_objective()
	if pass_enemies_defeated < pass_enemies_total:
		return
	stage = QuestStage.RETURN_PASS
	maela.set_quest_marker("?", Color(0.45, 1.0, 0.52, 1.0))
	quest_tracker.set_quest("EL PASO DE MAELA", "Regresa con Maela para informar la victoria.", "OBJETIVO CUMPLIDO")
	world_map.set_quest_marker(maela.global_position, "Regresa con Maela")
	quest_tracker.show_notification("Sendero despejado · vuelve con Maela", Color(0.45, 1.0, 0.52, 1.0))


func _update_pass_objective() -> void:

	quest_tracker.set_quest(
		"EL PASO DE MAELA",
		"Derrota a los goblins del sendero: " + str(pass_enemies_defeated) + "/" + str(pass_enemies_total),
		"CTRL: SIGILO  ·  CLIC: ATAQUE  ·  DOBLE WASD: DASH"
	)


func _show_pass_completion() -> void:

	maela.set_interaction_enabled(false)
	dialogue_ui.show_dialogue("Maela · Guardiana del Paso", [
		"Bien hecho. Escuché el último grito desde aquí; el sendero vuelve a estar abierto.",
		"No ganaste por fuerza solamente. Elegiste cómo entrar, cuándo golpear y cuándo apartarte.",
		"Tomá este amuleto y cinco fragmentos. Después hablá conmigo otra vez: hay algo peor que los goblins moviéndose al este."
	], _grant_pass_reward)


func _grant_pass_reward() -> void:

	_give_reward(REWARD_CHARM, 1)
	_give_reward(REWARD_SHARDS, 5)
	stage = QuestStage.FIELD_QUEST_AVAILABLE
	maela.set_quest_marker("!", Color(0.88, 0.4, 1.0, 1.0))
	maela.set_interaction_enabled(true)
	quest_tracker.set_quest("UNA HERIDA ANTIGUA", "Pregunta a Maela por la corrupción del este.", "NUEVA MISIÓN DISPONIBLE")
	world_map.set_quest_marker(maela.global_position, "Habla con Maela")
	quest_tracker.show_notification("Recompensa: Amuleto de hierro + 5 fragmentos", Color(0.55, 0.85, 1.0, 1.0))


func _show_world_revelation() -> void:

	maela.set_interaction_enabled(false)
	dialogue_ui.show_dialogue("Maela · Guardiana del Paso", [
		"Este continente nunca eligió aquella guerra. Los reinos de afuera lo usaron como campo de batalla y después lo abandonaron con sus muertos.",
		"Con los siglos, tanta muerte formó un cerco maldito. Nadie que intenta cruzarlo vuelve entero; hacia afuera ocurre lo mismo.",
		"Ahora la corrupción está creciendo. Los lugares de masacre llaman a la gente con voces conocidas y algunos regresan convertidos en bestias.",
		"Nuestros magos apenas conocen trucos básicos. Los antiguos se encerraron en torres ocultas, así que cada asentamiento manda guerreros y sabios a buscarlos.",
		"Examiná tres focos en el Campo de los Sin Nombre. No toques nada sin estar listo para pelear. Abrí el mapa con M para ver la ruta."
	], _start_field_quest)


func _start_field_quest() -> void:

	stage = QuestStage.INVESTIGATE_FIELD
	maela.set_quest_marker("", Color.WHITE)
	maela.set_interaction_enabled(true)
	for point: InvestigationPoint in investigation_points:
		point.set_active(true)
	_update_field_objective()
	world_map.set_quest_marker(Vector2(1620, 820), "Campo de los Sin Nombre")
	quest_tracker.show_notification("Nueva región marcada en el mapa", Color(0.9, 0.55, 1.0, 1.0))


func _show_field_progress() -> void:

	dialogue_ui.show_dialogue("Maela", [
		"Los focos están más allá del viejo camino, hacia el este.",
		"Si una voz promete mostrarte lo que querés, recordá que sólo conoce deseos tomados de otros muertos."
	])


func _on_investigation_point_used(point: InvestigationPoint) -> void:

	if stage != QuestStage.INVESTIGATE_FIELD:
		return
	sites_investigated += 1
	_update_field_objective()
	var whispers: Array[String] = [
		"Una voz bajo la tierra repite nombres de soldados que nadie recuerda.",
		"Por un instante sentís el deseo de caminar hacia el centro y dejar de resistirte.",
		"Entre las armas oxidadas hay marcas recientes. La corrupción no está despertando: está extendiéndose."
	]
	dialogue_ui.show_dialogue(
		"El murmullo de la fosa",
		[whispers[mini(sites_investigated - 1, whispers.size() - 1)]],
		_spawn_field_pack.bind(point.global_position)
	)


func _spawn_field_pack(center: Vector2) -> void:

	_spawn_corrupted_pack(center, 3, &"field", false)


func _update_field_objective() -> void:

	quest_tracker.set_quest(
		"VOCES BAJO LA TIERRA",
		"Focos examinados: " + str(sites_investigated) + "/3  ·  Corrompidos abatidos: " + str(field_enemies_defeated) + "/9",
		"EXPLORA EL CAMPO DE LOS SIN NOMBRE"
	)


func _on_phase_enemy_defeated(_enemy: Enemy, phase: StringName) -> void:

	if phase == &"field":
		field_enemies_defeated += 1
		_update_field_objective()
		_check_field_completion()
		return
	if phase == &"heart":
		heart_enemies_defeated += 1
		_update_heart_objective()
		if heart_enemies_defeated >= heart_enemies_total:
			stage = QuestStage.RETURN_IVAR
			ivar.set_quest_marker("?", Color(0.45, 1.0, 0.52, 1.0))
			world_map.set_quest_marker(ivar.global_position, "Regresa con Ivar")
			quest_tracker.show_notification("La Fosa de los Murmullos quedó en silencio", Color(0.5, 1.0, 0.62, 1.0))


func _check_field_completion() -> void:

	if stage != QuestStage.INVESTIGATE_FIELD or sites_investigated < 3 or field_enemies_total < 9 or field_enemies_defeated < field_enemies_total:
		return
	stage = QuestStage.RETURN_EVIDENCE
	maela.set_quest_marker("?", Color(0.45, 1.0, 0.52, 1.0))
	quest_tracker.set_quest("VOCES BAJO LA TIERRA", "Regresa con Maela y comparte lo descubierto.", "CAMPO DE BATALLA INVESTIGADO")
	world_map.set_quest_marker(maela.global_position, "Regresa con Maela")
	quest_tracker.show_notification("Conseguiste pruebas de la expansión", Color(0.5, 1.0, 0.62, 1.0))


func _show_evidence_dialogue() -> void:

	maela.set_interaction_enabled(false)
	dialogue_ui.show_dialogue("Maela", [
		"Entonces no era miedo de los exploradores. Las heridas están creciendo hacia terreno que nunca tocó la batalla.",
		"Ivar lideró la última incursión de nuestro paso. Volvió solo y con marcas negras; desde entonces vigila en la Torre Quebrada.",
		"En otros asentamientos, quien logra regresar liderando una expedición suele ser elevado a jefe. Ganarte a gente como él puede abrirte muchas puertas.",
		"Llevate estas botas y buscá a Ivar. Puede saber qué alimenta la fosa."
	], _grant_field_reward)


func _grant_field_reward() -> void:

	_give_reward(REWARD_BOOTS, 1)
	_give_reward(REWARD_SHARDS, 8)
	stage = QuestStage.FIND_IVAR
	maela.set_quest_marker("", Color.WHITE)
	maela.set_interaction_enabled(true)
	ivar.set_quest_marker("!", Color(1.0, 0.78, 0.18, 1.0))
	ivar.set_interaction_enabled(true)
	world_map.set_quest_marker(Vector2(2100, 1010), "Encuentra a Ivar")
	quest_tracker.set_quest("EL VIGÍA MARCADO", "Encuentra a Ivar en la Torre Quebrada.", "SIGUE EL CAMINO HACIA EL ESTE")


func _show_ivar_discovery() -> void:

	ivar.set_interaction_enabled(false)
	dialogue_ui.show_dialogue("Ivar · Explorador marcado", [
		"Maela te mandó. Todavía cree que estas marcas son heridas; yo sé que son una puerta que intenta abrirse.",
		"Mi expedición buscaba las torres de los antiguos magos. Vimos caminos donde el espacio se doblaba y hombres siguiendo voces de familiares muertos hacía siglos.",
		"Los continentes exteriores no vienen porque el cerco los destruye al acercarse. Nosotros tampoco podemos salir. La guerra terminó para ellos; para nosotros nunca terminó.",
		"Hay un corazón de corrupción al sudeste. Cada bestia que duerme cerca despierta más grande y más lista.",
		"Si querés devolverle futuro a esta tierra, empezá arrancando ese corazón. Yo mantendré abierta tu ruta de regreso."
	], _start_heart_quest)


func _start_heart_quest() -> void:

	stage = QuestStage.PURGE_HEART
	ivar.set_quest_marker("", Color.WHITE)
	ivar.set_interaction_enabled(true)
	_spawn_corrupted_pack(Vector2(2260, 1300), 5, &"heart", true)
	world_map.set_quest_marker(Vector2(2260, 1300), "Fosa de los Murmullos")
	quest_tracker.set_quest("EL CORAZÓN DE LA FOSA", "Destruye al corrompido mayor y su manada: 0/5", "LA FOSA ESTÁ AL SUDESTE")


func _update_heart_objective() -> void:

	quest_tracker.set_quest(
		"EL CORAZÓN DE LA FOSA",
		"Destruye al corrompido mayor y su manada: " + str(heart_enemies_defeated) + "/" + str(heart_enemies_total),
		"SOBREVIVE AL ENFRENTAMIENTO"
	)


func _show_final_dialogue() -> void:

	ivar.set_interaction_enabled(false)
	dialogue_ui.show_dialogue("Ivar · Explorador marcado", [
		"Lo sentí morir. Por primera vez en meses, la voz dentro de mi brazo dejó de susurrar.",
		"Pero esto era una raíz, no el árbol. Algo está haciendo que la corrupción avance y los magos probablemente saben qué es.",
		"Tomá esta espada. No es digna de una leyenda, pero puede ser el primer objeto de una historia que esta tierra necesita volver a creer.",
		"Uní asentamientos, ganate a sus líderes y encontrá a los antiguos. Después decidiremos si este continente vuelve a abrirse... o si abrimos una salida para nosotros."
	], _complete_campaign)


func _complete_campaign() -> void:

	_give_reward(REWARD_SWORD, 1)
	_give_reward(REWARD_SHARDS, 12)
	stage = QuestStage.COMPLETED
	ivar.set_quest_marker("", Color.WHITE)
	ivar.set_interaction_enabled(true)
	world_map.clear_quest_marker()
	world_map.discover_location(&"corrupted_heart")
	quest_tracker.mark_completed("Primer territorio asegurado · el mundo abierto continúa")
	quest_tracker.show_notification("Capítulo completado: Una ambición en tierra muerta", Color(1.0, 0.78, 0.32, 1.0))


func _spawn_corrupted_pack(center: Vector2, count: int, phase: StringName, include_boss: bool) -> void:

	for index: int in range(count):
		var enemy: Enemy = GOBLIN_SCENE.instantiate() as Enemy
		enemy.enemy_data = enemy.enemy_data.duplicate(true) as EnemyData
		enemy.enemy_data.enemy_name = "Devorador de recuerdos" if include_boss and index == 0 else "Merodeador corrompido"
		enemy.enemy_data.max_health = 520 if include_boss and index == 0 else 145
		enemy.enemy_data.move_speed = 105.0 if include_boss and index == 0 else 135.0
		enemy.debug_combat = false
		enemy.debug_ai_scores = false
		enemy.position = center + Vector2.from_angle(TAU * float(index) / float(maxi(count, 1))) * (95.0 if include_boss else 78.0)
		get_node("../World").add_child(enemy)
		enemy.modulate = Color(0.72, 0.34, 0.52, 1.0) if include_boss and index == 0 else Color(0.72, 0.55, 0.84, 1.0)
		if include_boss and index == 0:
			enemy.scale = Vector2.ONE * 1.35
		_prepare_enemy_visuals(enemy)
		enemy.defeated.connect(_on_phase_enemy_defeated.bind(phase))
		if phase == &"field":
			field_enemies_total += 1
		if phase == &"heart":
			heart_enemies_total += 1


func _give_reward(item: ItemData, quantity: int) -> void:

	var inventory: PlayerInventory = player.get_inventory()
	var remaining: int = inventory.add_item(item, quantity)
	if remaining <= 0:
		return
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item_data = item
	pickup.quantity = remaining
	get_node("../World").add_child(pickup)
	pickup.global_position = maela.global_position + Vector2(50, 10)
