class_name WorldMapUI
extends CanvasLayer


const WORLD_BOUNDS: Rect2 = Rect2(100, 100, 3800, 1400)

var world_bounds: Rect2 = WORLD_BOUNDS
var player: Node2D
var mini_panel: PanelContainer
var full_overlay: ColorRect
var mini_canvas: WorldMapCanvas
var full_canvas: WorldMapCanvas
var full_title: Label
var map_open: bool = false
var quest_position: Vector2 = Vector2.ZERO
var quest_label: String = ""
var has_quest_marker: bool = false

var road_points: Array[Vector2] = [
	Vector2(500, 430), Vector2(950, 510), Vector2(1320, 650),
	Vector2(1620, 820), Vector2(1950, 880), Vector2(2280, 820),
	Vector2(2600, 930), Vector2(2920, 820), Vector2(3260, 760),
	Vector2(3500, 720)
]

var locations: Dictionary = {
	&"maela_refuge": {"name": "Refugio de Ceniza", "position": Vector2(1030, 560), "discovered": true, "color": Color(0.45, 0.9, 0.48, 1.0)},
	&"ashen_pass": {"name": "Paso de Ceniza", "position": Vector2(650, 480), "discovered": true, "color": Color(0.82, 0.72, 0.48, 1.0)},
	&"gathering_fields": {"name": "Campos de recolección", "position": Vector2(1980, 830), "discovered": false, "color": Color(0.63, 0.78, 0.42, 1.0)},
	&"old_battlefield": {"name": "Límite inseguro", "position": Vector2(3220, 760), "discovered": false, "color": Color(0.82, 0.4, 0.35, 1.0)},
	&"watchtower": {"name": "Torre Quebrada", "position": Vector2(3500, 720), "discovered": false, "color": Color(0.55, 0.75, 0.68, 1.0)},
	&"corrupted_heart": {"name": "Fosa de los Murmullos", "position": Vector2(3720, 1240), "discovered": false, "color": Color(0.9, 0.25, 0.48, 1.0)}
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	mini_panel = $MiniPanel
	mini_canvas = $MiniPanel/MiniCanvas
	full_overlay = $FullOverlay
	full_canvas = $FullOverlay/FullPanel/Content/FullCanvas
	full_title = $FullOverlay/FullPanel/Content/FullTitle
	mini_canvas.map_owner = self
	full_canvas.map_owner = self
	call_deferred("_find_player")


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	for location_id: StringName in locations:
		var location: Dictionary = locations[location_id]
		if not bool(location["discovered"]) and player.global_position.distance_to(location["position"]) < 220.0:
			location["discovered"] = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("map"):
		return
	if get_tree().paused and not map_open:
		return
	_toggle_full_map()
	get_viewport().set_input_as_handled()


func set_quest_marker(position: Vector2, label: String) -> void:
	quest_position = position
	quest_label = label
	has_quest_marker = true
	full_title.text = "MAPA DEL CONTINENTE  ·  " + label


func clear_quest_marker() -> void:
	has_quest_marker = false
	quest_label = ""
	full_title.text = "MAPA DEL CONTINENTE"


func discover_location(location_id: StringName) -> void:
	if locations.has(location_id):
		locations[location_id]["discovered"] = true


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D


func _toggle_full_map() -> void:
	map_open = not map_open
	full_overlay.visible = map_open
	mini_panel.visible = not map_open
	get_tree().paused = map_open
