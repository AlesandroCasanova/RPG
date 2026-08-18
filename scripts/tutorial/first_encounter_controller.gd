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
	COMPLETED
}


const BASIC_SWORD: ItemData = preload("res://data/items/equipment/rusted_sword.tres")
const PATCHED_BOOTS: ItemData = preload("res://data/items/equipment/patched_boots.tres")
const HEALING_DRAUGHT: ItemData = preload("res://data/items/consumables/weak_healing_draught.tres")
const STAMINA_TONIC: ItemData = preload("res://data/items/consumables/bitter_stamina_tonic.tres")
const MANA_VIAL: ItemData = preload("res://data/items/consumables/clouded_mana_vial.tres")


var stage: Stage = Stage.MEET_MAELA
var player: CharacterBody2D
var inventory: PlayerInventory
var maela: TutorialNPC
var ivar: TutorialNPC
var nara: TutorialNPC
var dialogue: DialogueUI
var tracker: QuestTracker
var world_map: WorldMapUI
var goblins: Array[Enemy] = []
var defeated_goblins := 0
var gathered_resources := 0
var gatherables_total := 0


func _ready() -> void:
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
	_disable_combat_debug()
	for node: Node in get_tree().get_nodes_in_group("tutorial_gatherables"):
		var gatherable := node as GatherableResource
		if gatherable != null:
			gatherables_total += 1
			gatherable.collected.connect(_on_resource_collected)
	maela.interacted.connect(_on_maela_interacted)
	ivar.interacted.connect(_on_ivar_interacted)
	nara.interacted.connect(_on_nara_interacted)
	_set_only_active_npc(maela)
	tracker.set_quest(
		"EL PRIMER APORTE",
		"Habla con Maela. Hoy empezás a trabajar por el asentamiento.",
		"ACÉRCATE Y PULSA F"
	)
	world_map.set_quest_marker(maela.global_position, "Habla con Maela")
	tracker.show_notification("Refugio de Ceniza · Un hogar que apenas resiste", Color(0.86, 0.68, 0.36, 1))


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
	if stage == Stage.MEET_MAELA:
		dialogue.show_dialogue("Maela", [
			"Cumpliste la edad. Desde hoy, cada ración que comas también tendrás que ayudar a conseguirla.",
			"No es un castigo. Es la única forma en que este lugar sigue vivo. Los graneros están casi vacíos y ya racionamos la leña.",
			"Irás a la vieja zona de recolección del este. Siempre fue segura. Primero habla con Ivar: te dará lo poco que podemos prestar."
		], _begin_equipment_step)
	elif stage == Stage.RETURN_TO_MAELA:
		dialogue.show_dialogue("Maela", [
			"¿Goblins en la zona segura? Hace menos de una luna no había huellas ni fogatas allí.",
			"Entonces no fueron ellos los que se volvieron valientes. Algo los empujó hacia nosotros.",
			"La energía maldita vuelve a expandirse. Si alcanzó nuestros campos, este refugio ya no tiene tiempo para limitarse a sobrevivir.",
			"Descansa. Mañana reuniremos al consejo. Lo que viste cambia todo."
		], _complete_tutorial)


func _begin_equipment_step() -> void:
	stage = Stage.GET_EQUIPMENT
	_set_only_active_npc(ivar)
	tracker.set_quest("EL PRIMER APORTE", "Pide a Ivar el equipo común de recolección.", "RECIBIRÁS EQUIPO INCOMPLETO")
	world_map.set_quest_marker(ivar.global_position, "Recoge el equipo")


func _on_ivar_interacted() -> void:
	if stage != Stage.GET_EQUIPMENT:
		return
	dialogue.show_dialogue("Ivar", [
		"No pongas esa cara. La espada está mellada, pero todavía corta. Las botas pertenecieron a tres recolectores antes que a vos.",
		"No hay casco, guantes ni coraza para darte. Si volvés con recursos, quizá podamos fabricar algo que sí sea tuyo.",
		"Abrí la mochila con I. Arrastrá cada pieza sobre su silueta para equiparla."
	], _give_basic_equipment)


func _give_basic_equipment() -> void:
	inventory.add_item(BASIC_SWORD, 1)
	inventory.add_item(PATCHED_BOOTS, 1)
	stage = Stage.GET_SUPPLIES
	_set_only_active_npc(nara)
	tracker.set_quest("EL PRIMER APORTE", "Habla con Nara antes de salir.", "I ABRE INVENTARIO · ARRASTRA PARA EQUIPAR")
	world_map.set_quest_marker(nara.global_position, "Recoge provisiones")
	tracker.show_notification("Equipo común recibido · faltan varias piezas", Color(0.92, 0.92, 0.90, 1))


func _on_nara_interacted() -> void:
	if stage != Stage.GET_SUPPLIES:
		return
	dialogue.show_dialogue("Nara", [
		"Dos brebajes aguados, una raíz amarga y un poco de residuo mágico. No es medicina de ciudad, pero es todo lo que tenemos.",
		"Arrastralos a las casillas 1 a 6. En el camino, esas teclas pueden ser la diferencia entre volver o quedar tirado.",
		"Traé fibras, hongos secos y cualquier metal que encuentres. No te alejes de la senda: esa zona es segura."
	], _give_supplies)


func _give_supplies() -> void:
	inventory.add_item(HEALING_DRAUGHT, 2)
	inventory.add_item(STAMINA_TONIC, 1)
	inventory.add_item(MANA_VIAL, 1)
	inventory.assign_quick_slot(0, HEALING_DRAUGHT)
	inventory.assign_quick_slot(1, STAMINA_TONIC)
	inventory.assign_quick_slot(2, MANA_VIAL)
	stage = Stage.GATHER_RESOURCES
	_set_only_active_npc(null)
	tracker.set_quest("RECOLECCIÓN SEGURA", "Recolecta bayas, fibras y chatarra a lo largo de la senda.", "0 / " + str(gatherables_total) + " RECURSOS · F RECOLECTA")
	world_map.set_quest_marker(Vector2(1980, 780), "Campos de recolección")


func _on_resource_collected(_resource: GatherableResource) -> void:
	if stage != Stage.GATHER_RESOURCES:
		return
	gathered_resources += 1
	tracker.set_quest("RECOLECCIÓN SEGURA", "Recolecta los recursos marcados antes de continuar.", str(gathered_resources) + " / " + str(gatherables_total) + " RECURSOS")
	if gathered_resources >= gatherables_total:
		stage = Stage.TRAVEL_TO_GATHERING_ZONE
		tracker.set_quest("MÁS ALLÁ DEL CAMPO", "Continúa por la senda hacia el antiguo lindero.", "LOS RECURSOS ESTÁN ASEGURADOS")
		world_map.set_quest_marker(Vector2(3150, 770), "Lindero oriental")
		tracker.show_notification("Carga completa · es hora de regresar...", Color(0.72, 0.92, 0.55, 1))


func _start_ambush() -> void:
	stage = Stage.DEFEAT_GOBLINS
	dialogue.show_cinematic_dialogue([
		{"speaker": "Goblin", "side": "right", "text": "¡Maldito humano asqueroso! Dejá la bolsa y todo lo que llevás... o te destripamos acá mismo."},
		{"speaker": "El Ambicioso", "side": "left", "text": "Esta zona pertenece al asentamiento. Si quieren nuestros recursos, tendrán que quitármelos."},
		{"speaker": "Goblin", "side": "right", "text": "Je. El cachorro cree que puede elegir. ¡Mátenlo!"}
	], _activate_ambush_combat)


func _activate_ambush_combat() -> void:
	for enemy: Enemy in goblins:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
	tracker.set_quest("LA ZONA YA NO ES SEGURA", "Sobrevive a la avanzada goblin.", "0 / " + str(goblins.size()) + " ENEMIGOS")
	tracker.show_notification("¡Goblins! La corrupción los empujó hasta los campos", Color(1.0, 0.35, 0.24, 1))
	world_map.clear_quest_marker()


func _on_goblin_defeated(_enemy: Enemy) -> void:
	if stage != Stage.DEFEAT_GOBLINS:
		return
	defeated_goblins += 1
	tracker.set_quest("LA ZONA YA NO ES SEGURA", "Derrota a la avanzada y registra los cuerpos con F.", str(defeated_goblins) + " / " + str(goblins.size()) + " ENEMIGOS")
	if defeated_goblins >= goblins.size():
		stage = Stage.RETURN_TO_MAELA
		_set_only_active_npc(maela)
		tracker.set_quest("MALAS NOTICIAS", "Regresa al asentamiento y cuéntale a Maela.", "LA ZONA SEGURA HA CAÍDO")
		world_map.set_quest_marker(maela.global_position, "Regresa con Maela")
		tracker.show_notification("Sobreviviste por poco · registra los cuerpos antes de volver", Color(0.88, 0.72, 0.38, 1))


func _complete_tutorial() -> void:
	stage = Stage.COMPLETED
	_set_only_active_npc(null)
	tracker.mark_completed("El consejo se reunirá. La expansión de la maldición ha comenzado.")
	world_map.clear_quest_marker()
	tracker.show_notification("Tutorial completado · se abre el primer arco del asentamiento", Color(0.45, 1.0, 0.58, 1))
