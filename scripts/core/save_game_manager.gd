extends Node


signal game_saved
signal game_loaded
signal save_failed(message: String)


const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

var pending_load_data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		if request_load():
			get_tree().paused = false
			get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	var controller := get_tree().get_first_node_in_group("save_controller")
	if player == null or controller == null:
		return _fail("Todavía no se puede guardar en este momento.")
	var inventory: Node = player.get_inventory() if player.has_method("get_inventory") else null
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game_state": GameState.get_save_data(),
		"player": {
			"name": player.get_character_name() if player.has_method("get_character_name") else GameState.player_name,
			"position": [player.global_position.x, player.global_position.y],
			"health": int(player.get("health")),
			"stamina": float(player.get("stamina")),
			"mana": float(player.get("mana"))
		},
		"inventory": inventory.get_save_data() if inventory != null and inventory.has_method("get_save_data") else {},
		"progress": controller.get_save_data() if controller.has_method("get_save_data") else {},
		"world_map": world_map.get_save_data() if world_map != null and world_map.has_method("get_save_data") else {}
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return _fail("No se pudo abrir el archivo de guardado.")
	file.store_string(JSON.stringify(data, "\t"))
	game_saved.emit()
	_notify("Partida guardada · F9 para cargar", Color(0.45, 1.0, 0.58, 1.0))
	return true


func request_load() -> bool:
	if not has_save():
		return _fail("No existe una partida guardada.")
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return _fail("No se pudo leer la partida guardada.")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("El archivo de guardado no es válido.")
	pending_load_data = (parsed as Dictionary).duplicate(true)
	GameState.load_save_data(Dictionary(pending_load_data.get("game_state", {})))
	return true


func has_pending_load() -> bool:
	return not pending_load_data.is_empty()


func apply_pending_save(controller: Node) -> bool:
	if pending_load_data.is_empty() or controller == null:
		return false
	var data := pending_load_data
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return _fail("No se encontró al jugador para cargar la partida.")
	var player_data := Dictionary(data.get("player", {}))
	if player.has_method("set_character_name"):
		player.set_character_name(String(player_data.get("name", GameState.player_name)))
	var saved_position := Array(player_data.get("position", []))
	if saved_position.size() >= 2:
		player.global_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	player.set("health", clampi(int(player_data.get("health", player.get("max_health"))), 1, int(player.get("max_health"))))
	player.set("stamina", clampf(float(player_data.get("stamina", player.get("max_stamina"))), 0.0, float(player.get("max_stamina"))))
	player.set("mana", clampf(float(player_data.get("mana", player.get("max_mana"))), 0.0, float(player.get("max_mana"))))
	var inventory: Node = player.get_inventory() if player.has_method("get_inventory") else null
	if inventory != null and inventory.has_method("load_save_data"):
		inventory.load_save_data(Dictionary(data.get("inventory", {})))
	if controller.has_method("load_save_data"):
		controller.load_save_data(Dictionary(data.get("progress", {})))
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	if world_map != null and world_map.has_method("load_save_data"):
		world_map.load_save_data(Dictionary(data.get("world_map", {})))
	pending_load_data.clear()
	game_loaded.emit()
	_notify("Partida cargada", Color(0.55, 0.82, 1.0, 1.0))
	return true


func delete_save() -> bool:
	if not has_save():
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH)) == OK


func _fail(message: String) -> bool:
	save_failed.emit(message)
	_notify(message, Color(1.0, 0.38, 0.3, 1.0))
	return false


func _notify(message: String, color: Color) -> void:
	var tracker := get_tree().get_first_node_in_group("quest_tracker")
	if tracker != null and tracker.has_method("show_notification"):
		tracker.show_notification(message, color)
