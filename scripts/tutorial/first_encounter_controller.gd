class_name FirstEncounterController
extends Node


enum Stage {
	MEET_MAELA,
	GET_EQUIPMENT,
	GET_SUPPLIES,
	GATHER_RESOURCES,
	TRAVEL_TO_GATHERING_ZONE,
	DEFEAT_GOBLINS,
	RETURN_TO_MAELA,
	COUNCIL_DECISION,
	INVESTIGATE_COUNCIL_CHOICE,
	RETURN_FROM_EXPEDITION,
	COMPLETED
}


const BASIC_SWORD: ItemData = preload("res://data/items/equipment/rusted_sword.tres")
const PATCHED_BOOTS: ItemData = preload("res://data/items/equipment/patched_boots.tres")
const HEALING_DRAUGHT: ItemData = preload("res://data/items/consumables/weak_healing_draught.tres")
const STAMINA_TONIC: ItemData = preload("res://data/items/consumables/bitter_stamina_tonic.tres")
const MANA_VIAL: ItemData = preload("res://data/items/consumables/clouded_mana_vial.tres")
const AMBUSH_DIALOGUE: DialogueData = preload("res://data/dialogues/chapter_01/ambush.tres")
const COUNCIL_DIALOGUE: DialogueData = preload("res://data/dialogues/chapter_01/council.tres")
const FORTIFY_INVESTIGATION: DialogueData = preload("res://data/dialogues/chapter_01/investigation_fortify.tres")
const TRACK_INVESTIGATION: DialogueData = preload("res://data/dialogues/chapter_01/investigation_track.tres")


var stage: Stage = Stage.MEET_MAELA
var player: CharacterBody2D
var inventory: PlayerInventory
var maela: TutorialNPC
var ivar: TutorialNPC
var nara: TutorialNPC
var dialogue: DialogueUI
var tracker: QuestTracker
var world_map: WorldMapUI
var investigation_point: InvestigationPoint
var goblins: Array[Enemy] = []
var gatherables: Array[GatherableResource] = []
var defeated_goblins := 0
var gathered_resources := 0
var gatherables_total := 0


func _ready() -> void:
	add_to_group("save_controller")
	call_deferred("_initialize")


func _initialize() -> void:
	player = get_node("../World/Environment/Player") as CharacterBody2D
	inventory = player.get_inventory()
	maela = get_node("../World/Environment/Maela") as TutorialNPC
	ivar = get_node("../World/Environment/Ivar") as TutorialNPC
	nara = get_node("../World/Environment/Nara") as TutorialNPC
	dialogue = get_node("../DialogueUI") as DialogueUI
	tracker = get_node("../QuestTracker") as QuestTracker
	world_map = get_node("../WorldMapUI") as WorldMapUI
	investigation_point = get_node("../World/Environment/CouncilInvestigation") as InvestigationPoint
	var camera := player.get_node("Camera2D") as Camera2D
	camera.zoom = Vector2(0.9, 0.9)
	camera.limit_left = 100
	camera.limit_top = 100
	camera.limit_right = 3900
	camera.limit_bottom = 1500
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		goblins.append(enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.defeated.connect(_on_goblin_defeated)
	for node: Node in get_tree().get_nodes_in_group("tutorial_gatherables"):
		var gatherable := node as GatherableResource
		if gatherable != null:
			gatherables.append(gatherable)
			gatherable.collected.connect(_on_resource_collected)
	gatherables_total = gatherables.size()
	_disable_combat_debug()
	maela.interacted.connect(_on_maela_interacted)
	ivar.interacted.connect(_on_ivar_interacted)
	nara.interacted.connect(_on_nara_interacted)
	investigation_point.investigated.connect(_on_investigation_completed)
	investigation_point.set_active(false)
	if SaveGame.has_pending_load():
		SaveGame.apply_pending_save(self)
	else:
		_apply_stage_state(true)
		SaveGame.save_game()


func _process(_delta: float) -> void:
	if stage == Stage.TRAVEL_TO_GATHERING_ZONE and player.global_position.x >= 2920.0:
		_start_ambush()


func _disable_combat_debug() -> void:
	player.set("show_attack_debug", false)
	for enemy: Enemy in goblins:
		enemy.debug_combat = false
		enemy.debug_ai_scores = false
		enemy.queue_redraw()
		var debug_label := enemy.get_node_or_null("AIDebugLabel") as Label
		if debug_label != null:
			debug_label.visible = false


func _set_only_active_npc(active_npc: TutorialNPC) -> void:
	for npc: TutorialNPC in [maela, ivar, nara]:
		var enabled := npc == active_npc
		npc.set_interaction_enabled(enabled)
		npc.set_quest_marker("!" if enabled else "", Color(0.95, 0.72, 0.24, 1))


func _on_maela_interacted() -> void:
	match stage:
		Stage.MEET_MAELA:
			dialogue.show_npc_dialogue(maela.npc_data, &"intro", _begin_equipment_step)
		Stage.RETURN_TO_MAELA:
			dialogue.show_npc_dialogue(maela.npc_data, &"report_goblins", _begin_council)
		Stage.COUNCIL_DECISION:
			dialogue.show_dialogue_data(COUNCIL_DIALOGUE, _on_council_choice)
		Stage.RETURN_FROM_EXPEDITION:
			dialogue.show_npc_dialogue(maela.npc_data, &"chapter_end", _complete_chapter)


func _begin_equipment_step() -> void:
	stage = Stage.GET_EQUIPMENT
	_apply_stage_state()


func _on_ivar_interacted() -> void:
	if stage != Stage.GET_EQUIPMENT:
		return
	dialogue.show_npc_dialogue(ivar.npc_data, &"equipment", _give_basic_equipment)


func _give_basic_equipment() -> void:
	inventory.add_item(BASIC_SWORD, 1)
	inventory.add_item(PATCHED_BOOTS, 1)
	stage = Stage.GET_SUPPLIES
	_apply_stage_state()
	tracker.show_notification("Equipo común recibido · faltan varias piezas", Color(0.92, 0.92, 0.90, 1))


func _on_nara_interacted() -> void:
	if stage != Stage.GET_SUPPLIES:
		return
	dialogue.show_npc_dialogue(nara.npc_data, &"supplies", _give_supplies)


func _give_supplies() -> void:
	inventory.add_item(HEALING_DRAUGHT, 2)
	inventory.add_item(STAMINA_TONIC, 1)
	inventory.add_item(MANA_VIAL, 1)
	inventory.assign_quick_slot(0, HEALING_DRAUGHT)
	inventory.assign_quick_slot(1, STAMINA_TONIC)
	inventory.assign_quick_slot(2, MANA_VIAL)
	stage = Stage.GATHER_RESOURCES
	_apply_stage_state()


func _on_resource_collected(_resource: GatherableResource) -> void:
	if stage != Stage.GATHER_RESOURCES:
		return
	gathered_resources += 1
	_apply_stage_state()
	if gathered_resources >= gatherables_total:
		stage = Stage.TRAVEL_TO_GATHERING_ZONE
		_apply_stage_state()
		tracker.show_notification("Carga completa · es hora de regresar...", Color(0.72, 0.92, 0.55, 1))


func _start_ambush() -> void:
	stage = Stage.DEFEAT_GOBLINS
	dialogue.show_dialogue_data(AMBUSH_DIALOGUE, _activate_ambush_combat)


func _activate_ambush_combat(_choice_id: StringName = &"") -> void:
	_apply_stage_state()
	tracker.show_notification("¡Goblins! La corrupción los empujó hasta los campos", Color(1.0, 0.35, 0.24, 1))


func _on_goblin_defeated(_enemy: Enemy) -> void:
	if stage != Stage.DEFEAT_GOBLINS:
		return
	defeated_goblins += 1
	_apply_stage_state()
	if defeated_goblins >= goblins.size():
		stage = Stage.RETURN_TO_MAELA
		_apply_stage_state()
		tracker.show_notification("Sobreviviste por poco · registrá los cuerpos antes de volver", Color(0.88, 0.72, 0.38, 1))


func _begin_council() -> void:
	stage = Stage.COUNCIL_DECISION
	_apply_stage_state()
	tracker.show_notification("El consejo espera tu decisión", Color(0.86, 0.68, 0.36, 1))


func _on_council_choice(choice_id: StringName) -> void:
	if choice_id not in [&"fortify_refuge", &"track_corruption"]:
		return
	GameState.set_story_flag(&"council_choice", String(choice_id))
	stage = Stage.INVESTIGATE_COUNCIL_CHOICE
	_apply_stage_state()
	SaveGame.save_game()


func _on_investigation_completed(_point: InvestigationPoint) -> void:
	if stage != Stage.INVESTIGATE_COUNCIL_CHOICE:
		return
	var choice := StringName(GameState.get_story_flag(&"council_choice", "track_corruption"))
	var data := FORTIFY_INVESTIGATION if choice == &"fortify_refuge" else TRACK_INVESTIGATION
	dialogue.show_dialogue_data(data, _begin_return_from_expedition)


func _begin_return_from_expedition(_choice_id: StringName = &"") -> void:
	stage = Stage.RETURN_FROM_EXPEDITION
	_apply_stage_state()
	SaveGame.save_game()


func _complete_chapter() -> void:
	stage = Stage.COMPLETED
	GameState.set_story_flag(&"chapter_01_completed", true)
	_apply_stage_state()
	SaveGame.save_game()
	tracker.show_notification("Capítulo completado · tu decisión ya afecta al refugio", Color(0.45, 1.0, 0.58, 1))


func _apply_stage_state(show_intro_notification: bool = false) -> void:
	if player == null:
		return
	_set_only_active_npc(null)
	investigation_point.set_active(false)
	for enemy: Enemy in goblins:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	match stage:
		Stage.MEET_MAELA:
			_set_only_active_npc(maela)
			tracker.set_quest("EL PRIMER APORTE", "Hablá con Maela. Hoy empezás a trabajar por el asentamiento.", "ACERCATE Y PULSÁ F")
			world_map.set_quest_marker(maela.global_position, "Hablá con Maela")
			if show_intro_notification:
				tracker.show_notification("Refugio de Ceniza · Un hogar que apenas resiste", Color(0.86, 0.68, 0.36, 1))
		Stage.GET_EQUIPMENT:
			_set_only_active_npc(ivar)
			tracker.set_quest("EL PRIMER APORTE", "Pedile a Ivar el equipo común de recolección.", "RECIBIRÁS EQUIPO INCOMPLETO")
			world_map.set_quest_marker(ivar.global_position, "Recogé el equipo")
		Stage.GET_SUPPLIES:
			_set_only_active_npc(nara)
			tracker.set_quest("EL PRIMER APORTE", "Hablá con Nara antes de salir.", "I ABRE INVENTARIO · ARRASTRÁ PARA EQUIPAR")
			world_map.set_quest_marker(nara.global_position, "Recogé provisiones")
		Stage.GATHER_RESOURCES:
			tracker.set_quest("RECOLECCIÓN SEGURA", "Recolectá bayas, fibras y chatarra a lo largo de la senda.", "%d / %d RECURSOS · F RECOLECTA" % [gathered_resources, gatherables_total])
			world_map.set_quest_marker(Vector2(1980, 780), "Campos de recolección")
		Stage.TRAVEL_TO_GATHERING_ZONE:
			tracker.set_quest("MÁS ALLÁ DEL CAMPO", "Continuá por la senda hacia el antiguo lindero.", "LOS RECURSOS ESTÁN ASEGURADOS")
			world_map.set_quest_marker(Vector2(3150, 770), "Lindero oriental")
		Stage.DEFEAT_GOBLINS:
			for enemy: Enemy in goblins:
				if is_instance_valid(enemy):
					enemy.process_mode = Node.PROCESS_MODE_INHERIT
			tracker.set_quest("LA ZONA YA NO ES SEGURA", "Sobreviví a la avanzada goblin.", "%d / %d ENEMIGOS" % [defeated_goblins, goblins.size()])
			world_map.clear_quest_marker()
		Stage.RETURN_TO_MAELA:
			_set_only_active_npc(maela)
			tracker.set_quest("MALAS NOTICIAS", "Regresá al asentamiento y contale a Maela.", "LA ZONA SEGURA HA CAÍDO")
			world_map.set_quest_marker(maela.global_position, "Regresá con Maela")
		Stage.COUNCIL_DECISION:
			_set_only_active_npc(maela)
			tracker.set_quest("EL CONSEJO DE CENIZA", "Participá del consejo y elegí cómo responder.", "TU DECISIÓN TENDRÁ CONSECUENCIAS")
			world_map.set_quest_marker(maela.global_position, "Consejo del refugio")
		Stage.INVESTIGATE_COUNCIL_CHOICE:
			investigation_point.set_active(true)
			var fortify := String(GameState.get_story_flag(&"council_choice", "")) == "fortify_refuge"
			var objective := "Marcá el punto más vulnerable del lindero." if fortify else "Seguí las vetas de corrupción hasta su origen visible."
			tracker.set_quest("PRIMERA EXPEDICIÓN", objective, "F EXAMINA LA ZONA MARCADA")
			world_map.set_quest_marker(investigation_point.global_position, "Punto de reconocimiento")
			world_map.discover_location(&"corrupted_heart")
		Stage.RETURN_FROM_EXPEDITION:
			_set_only_active_npc(maela)
			tracker.set_quest("UNA RESPUESTA PARA EL CONSEJO", "Regresá con Maela y presentá tus conclusiones.", "EL REFUGIO ESPERA")
			world_map.set_quest_marker(maela.global_position, "Informá al consejo")
		Stage.COMPLETED:
			tracker.mark_completed("La expansión de la maldición ha comenzado. La decisión del consejo quedó registrada.")
			world_map.clear_quest_marker()


func get_save_data() -> Dictionary:
	return {
		"stage": int(stage),
		"defeated_goblins": defeated_goblins,
		"gathered_resources": gathered_resources,
		"investigation_completed": investigation_point.completed if investigation_point != null else false
	}


func load_save_data(data: Dictionary) -> void:
	stage = clampi(int(data.get("stage", int(Stage.MEET_MAELA))), int(Stage.MEET_MAELA), int(Stage.COMPLETED)) as Stage
	defeated_goblins = clampi(int(data.get("defeated_goblins", 0)), 0, goblins.size())
	gathered_resources = clampi(int(data.get("gathered_resources", 0)), 0, gatherables_total)
	var remove_all_gatherables := stage > Stage.GATHER_RESOURCES
	for index: int in gatherables.size():
		if is_instance_valid(gatherables[index]) and (remove_all_gatherables or index < gathered_resources):
			gatherables[index].queue_free()
	var remove_all_goblins := stage > Stage.DEFEAT_GOBLINS
	for index: int in goblins.size():
		if is_instance_valid(goblins[index]) and (remove_all_goblins or index < defeated_goblins):
			goblins[index].queue_free()
	if bool(data.get("investigation_completed", false)):
		investigation_point.completed = true
	_apply_stage_state()
