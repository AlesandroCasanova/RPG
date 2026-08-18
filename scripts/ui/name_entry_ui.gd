class_name NameEntryUI
extends CanvasLayer


@onready var name_input: LineEdit = $Overlay/Center/Panel/Margin/Content/NameInput
@onready var confirm_button: Button = $Overlay/Center/Panel/Margin/Content/ConfirmButton
@onready var error_label: Label = $Overlay/Center/Panel/Margin/Content/ErrorLabel
@onready var continue_button: Button = $Overlay/Center/Panel/Margin/Content/ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("name_entry_ui")
	layer = 200
	confirm_button.pressed.connect(_confirm_name)
	continue_button.pressed.connect(_continue_game)
	name_input.text_submitted.connect(_on_name_submitted)
	get_tree().paused = true
	continue_button.visible = SaveGame.has_save()
	if SaveGame.has_pending_load():
		continue_button.visible = false
		_resume_pending_load.call_deferred()
	name_input.grab_focus.call_deferred()


func _on_name_submitted(_submitted_name: String) -> void:
	_confirm_name()


func _confirm_name() -> void:
	var clean_name := name_input.text.strip_edges()
	if clean_name.is_empty():
		error_label.text = "Escribí un nombre para continuar."
		name_input.grab_focus()
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("set_character_name"):
		error_label.text = "No se encontró al personaje."
		return
	player.set_character_name(clean_name)
	GameState.start_new_game(clean_name)
	get_tree().paused = false
	queue_free()


func _continue_game() -> void:
	if not SaveGame.request_load():
		error_label.text = "No se pudo cargar la partida."
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_character_name"):
		player.set_character_name(GameState.player_name)
	get_tree().paused = false
	queue_free()


func _resume_pending_load() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_character_name"):
		player.set_character_name(GameState.player_name)
	get_tree().paused = false
	queue_free()
