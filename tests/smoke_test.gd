extends SceneTree


var dialogue_finished := false
var selected_choice: StringName = &""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not InputMap.has_action("quick_save") or not InputMap.has_action("quick_load"):
		_fail("Faltan las acciones de guardado rápido.")
		return
	var save_key := InputMap.action_get_events("quick_save")[0] as InputEventKey
	var load_key := InputMap.action_get_events("quick_load")[0] as InputEventKey
	if save_key.physical_keycode != KEY_F5 or load_key.physical_keycode != KEY_F9:
		_fail("Las acciones de guardado no están asignadas a F5/F9.")
		return
	var result := change_scene_to_file("res://scenes/tutorial/first_encounter.tscn")
	if result != OK:
		_fail("No se pudo abrir la escena principal.")
		return
	await process_frame
	await process_frame
	var name_ui := get_first_node_in_group("name_entry_ui")
	if name_ui == null:
		# La UI no usaba grupo originalmente; se obtiene por la escena actual.
		name_ui = current_scene.get_node_or_null("World/NameEntryUI")
	if name_ui == null:
		_fail("No apareció la selección de nombre.")
		return
	name_ui.name_input.text = "Prueba"
	name_ui._confirm_name()
	await process_frame
	await process_frame
	await process_frame
	var controller := get_first_node_in_group("save_controller")
	var player := get_first_node_in_group("player")
	var dialogue := get_first_node_in_group("dialogue_ui") as DialogueUI
	if controller == null or player == null or dialogue == null:
		_fail("No se inicializaron los sistemas principales.")
		return
	if player.get_character_name() != "Prueba":
		_fail("El nombre no llegó al jugador.")
		return
	var maela := load("res://data/npcs/maela.tres") as NPCData
	var council := load("res://data/dialogues/chapter_01/council.tres") as DialogueData
	if maela == null or maela.get_dialogue(&"intro") == null or council == null or council.choices.size() != 2:
		_fail("Los recursos narrativos no cargaron correctamente.")
		return
	dialogue.show_npc_dialogue(maela, &"intro", _on_dialogue_finished)
	for _index: int in maela.get_dialogue(&"intro").entries.size():
		dialogue._advance()
	await process_frame
	if not dialogue_finished:
		_fail("El callback de diálogo lineal no se ejecutó.")
		return
	dialogue.show_dialogue_data(council, _on_choice_finished)
	for _index: int in council.entries.size():
		dialogue._advance()
	dialogue._select_choice(council.choices[0])
	for _index: int in council.choices[0].response_entries.size():
		dialogue._advance()
	await process_frame
	if selected_choice != &"fortify_refuge":
		_fail("La elección de diálogo no devolvió su identificador.")
		return
	var save_game := root.get_node_or_null("SaveGame")
	if save_game == null or not save_game.save_game() or not save_game.request_load() or not save_game.apply_pending_save(controller):
		_fail("El ciclo guardar/cargar falló.")
		return
	if not save_game.request_load() or reload_current_scene() != OK:
		_fail("No se pudo preparar la carga con reinicio de escena.")
		return
	for _index: int in 6:
		await process_frame
	if save_game.has_pending_load() or get_first_node_in_group("player").get_character_name() != "Prueba":
		_fail("La carga rápida no restauró la escena y el nombre.")
		return
	print("SMOKE_TEST_OK")
	quit(0)


func _on_dialogue_finished() -> void:
	dialogue_finished = true


func _on_choice_finished(choice_id: StringName) -> void:
	selected_choice = choice_id


func _fail(message: String) -> void:
	push_error("SMOKE_TEST: " + message)
	quit(1)
