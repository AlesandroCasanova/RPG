extends Node


signal story_flag_changed(flag: StringName, value: Variant)


var player_name: String = "El Ambicioso"
var story_flags: Dictionary = {}
var has_started_game: bool = false


func start_new_game(new_player_name: String) -> void:
	player_name = new_player_name.strip_edges().left(24)
	story_flags.clear()
	has_started_game = true


func set_story_flag(flag: StringName, value: Variant = true) -> void:
	story_flags[flag] = value
	story_flag_changed.emit(flag, value)


func get_story_flag(flag: StringName, default_value: Variant = false) -> Variant:
	return story_flags.get(flag, default_value)


func get_save_data() -> Dictionary:
	return {
		"player_name": player_name,
		"story_flags": story_flags.duplicate(true),
		"has_started_game": has_started_game
	}


func load_save_data(data: Dictionary) -> void:
	player_name = String(data.get("player_name", "El Ambicioso"))
	story_flags = Dictionary(data.get("story_flags", {})).duplicate(true)
	has_started_game = bool(data.get("has_started_game", true))

