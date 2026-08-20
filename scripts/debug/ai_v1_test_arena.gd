extends Node2D

const GOBLIN_SCENE = preload("res://scenes/enemies/goblin/goblin_common.tscn")
const P_BALANCED := 0
const MODE_AUTO := 0
const PLAYER_START := Vector2(1700.0, 780.0)

@onready var player = $World/Environment/Player
@onready var actors = $World/Environment/TestActors
@onready var wall_a = $World/Environment/TestGeometry/WallA
@onready var wall_b = $World/Environment/TestGeometry/WallB

@onready var title_label: Label = $TestHUD/Panel/Margin/VBox/Title
@onready var variant_label: Label = $TestHUD/Panel/Margin/VBox/Variant
@onready var instructions_label: Label = $TestHUD/Panel/Margin/VBox/Instructions
@onready var status_label: Label = $TestHUD/Panel/Margin/VBox/Status
@onready var notes_edit: LineEdit = $TestHUD/Panel/Margin/VBox/Notes
@onready var result_label: Label = $TestHUD/Panel/Margin/VBox/Result
@onready var prev_button: Button = $TestHUD/Panel/Margin/VBox/NavButtons/Prev
@onready var reset_button: Button = $TestHUD/Panel/Margin/VBox/NavButtons/Reset
@onready var next_button: Button = $TestHUD/Panel/Margin/VBox/NavButtons/Next
@onready var variant_button: Button = $TestHUD/Panel/Margin/VBox/ActionButtons/VariantButton
@onready var low_hp_button: Button = $TestHUD/Panel/Margin/VBox/ActionButtons/LowHP
@onready var debug_button: Button = $TestHUD/Panel/Margin/VBox/ActionButtons/Debug
@onready var pass_button: Button = $TestHUD/Panel/Margin/VBox/ResultButtons/Pass
@onready var fail_button: Button = $TestHUD/Panel/Margin/VBox/ResultButtons/Fail
@onready var copy_button: Button = $TestHUD/Panel/Margin/VBox/ResultButtons/Copy

var enemy = null
var debug_enabled := true
var elapsed := 0.0
var refresh_left := 0.0
var result := ""


func _ready() -> void:
	prev_button.visible = false
	next_button.visible = false
	variant_button.visible = false
	low_hp_button.visible = false

	reset_button.pressed.connect(_reset_test)
	debug_button.pressed.connect(_toggle_debug)
	pass_button.pressed.connect(_mark_ok)
	fail_button.pressed.connect(_mark_fail)
	copy_button.pressed.connect(_copy_report)

	_setup_test()


func _process(delta: float) -> void:
	elapsed += delta
	refresh_left -= delta

	if refresh_left <= 0.0:
		refresh_left = 0.20
		status_label.text = "FPS %d | HP %d/%d | %.1fs" % [
			Engine.get_frames_per_second(),
			player.health,
			player.max_health,
			elapsed
		]


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_R:
			_reset_test()
		KEY_K:
			_mark_ok()
		KEY_J:
			_mark_fail()


func _reset_test() -> void:
	_setup_test()


func _setup_test() -> void:
	elapsed = 0.0
	result = ""

	for child in actors.get_children():
		actors.remove_child(child)
		child.queue_free()

	player.global_position = PLAYER_START
	player.velocity = Vector2.ZERO
	player.health = player.max_health
	player.stamina = player.max_stamina
	player.mana = player.max_mana
	player.is_dead = false
	player.received_knockback_velocity = Vector2.ZERO
	player.is_dashing = false
	player.is_sprinting = false

	_set_wall_enabled(wall_a, false)
	_set_wall_enabled(wall_b, false)

	enemy = GOBLIN_SCENE.instantiate()
	enemy.name = "RC6_SearchPerimeter"
	enemy.position = Vector2(1980.0, 780.0)

	if enemy.ai_profile != null:
		var profile = enemy.ai_profile.duplicate(true)
		profile.resource_local_to_scene = true
		profile.intelligence_percent = 100.0
		profile.intelligence_variation_percent = 0.0
		profile.combat_personality = P_BALANCED
		profile.flee_mode = MODE_AUTO
		enemy.ai_profile = profile

	enemy.debug_combat = debug_enabled
	enemy.debug_ai_scores = debug_enabled

	actors.add_child(enemy)
	_update_panel()


func _set_wall_enabled(wall, enabled: bool) -> void:
	wall.visible = enabled
	wall.collision_layer = 1 if enabled else 0

	var obstacle = wall.get_node_or_null("NavigationObstacle2D")
	if obstacle != null:
		obstacle.avoidance_enabled = enabled


func _toggle_debug() -> void:
	debug_enabled = not debug_enabled

	if is_instance_valid(enemy):
		enemy.debug_combat = debug_enabled
		enemy.debug_ai_scores = debug_enabled

		var label = enemy.get_node_or_null("AIDebugLabel")
		if label != null:
			label.visible = debug_enabled

	debug_button.text = "Debug: ON" if debug_enabled else "Debug: OFF"


func _mark_ok() -> void:
	result = "OK"
	result_label.text = "Registrado: OK"


func _mark_fail() -> void:
	result = "FALLA"
	result_label.text = "Registrado: FALLA"


func _copy_report() -> void:
	var status := result if not result.is_empty() else "SIN MARCAR"
	var report := (
		"REPORTE IA V1 RC11\n"
		+ "=================\n"
		+ "TEST ÚNICO — SEARCH + perímetro adaptativo: "
		+ status
	)

	var note := notes_edit.text.strip_edges()
	if not note.is_empty():
		report += " | NOTA: " + note

	DisplayServer.clipboard_set(report)
	result_label.text = "Reporte RC6 copiado."


func _update_panel() -> void:
	title_label.text = "RC11 — TEST ÚNICO — SEARCH"
	variant_label.text = "Pared, Interrupt y Memoria siguen aprobados."
	instructions_label.text = (
		"1) Dejá que IQ100 te vea y después salí de su visión.\n"
		+ "2) Debe CORRER / DASHEAR hacia el ÚLTIMO PUNTO EXACTO donde te vio.\n"
		+ "3) Al llegar, toma ese punto como CENTRO del área de búsqueda.\n"
		+ "4) Va hasta el BORDE verde empezando por la dirección en la que te vio ir.\n"
		+ "5) Recorre CAMINANDO la CIRCUNFERENCIA VERDE COMPLETA (0→100%).\n"
		+ "6) Si una roca corta la ruta, debe RODEARLA y REINCORPORARSE unos checkpoints más adelante; el progreso solo cambia al llegar físicamente.\n"        + "7) Si te ve durante la vuelta vuelve al combate. Si completa el 100% "
		+ "sin encontrarte, regresa a su punto idle."
	)

	debug_button.text = "Debug: ON" if debug_enabled else "Debug: OFF"
	notes_edit.text = ""
	result_label.text = "Sin resultado registrado."
