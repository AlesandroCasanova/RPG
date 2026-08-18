class_name WorldMapUI
extends CanvasLayer


const WORLD_BOUNDS: Rect2 = Rect2(100, 100, 3800, 1400)
const MINI_VIEW_SIZE := Vector2i(220, 160)
const FULL_VIEW_SIZE := Vector2i(960, 360)
const MINI_WORLD_ZOOM := 0.18
const FULL_WORLD_ZOOM := 0.25

var world_bounds: Rect2 = WORLD_BOUNDS
var player: Node2D
var mini_panel: PanelContainer
var full_overlay: ColorRect
var mini_canvas: WorldMapCanvas
var full_canvas: WorldMapCanvas
var mini_world_view: TextureRect
var full_world_view: TextureRect
var mini_viewport: SubViewport
var full_viewport: SubViewport
var mini_camera: Camera2D
var full_camera: Camera2D
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
	add_to_group("world_map_ui")
	layer = 30
	mini_panel = $MiniPanel
	mini_canvas = $MiniPanel/MiniCanvas/Markers
	mini_world_view = $MiniPanel/MiniCanvas/MiniWorldView
	full_overlay = $FullOverlay
	full_canvas = $FullOverlay/FullPanel/Content/FullCanvas/Markers
	full_world_view = $FullOverlay/FullPanel/Content/FullCanvas/FullWorldView
	full_title = $FullOverlay/FullPanel/Content/FullTitle
	mini_canvas.map_owner = self
	full_canvas.map_owner = self
	_create_world_viewports()
	call_deferred("_find_player")


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if is_instance_valid(mini_camera):
		mini_camera.global_position = player.global_position
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


func get_save_data() -> Dictionary:
	var discovered: Array[String] = []
	for location_id: StringName in locations:
		if bool(locations[location_id]["discovered"]):
			discovered.append(String(location_id))
	return {"discovered_locations": discovered}


func load_save_data(data: Dictionary) -> void:
	var discovered := Array(data.get("discovered_locations", []))
	for location_id: StringName in locations:
		locations[location_id]["discovered"] = String(location_id) in discovered


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and is_instance_valid(mini_camera):
		mini_camera.global_position = player.global_position


func _create_world_viewports() -> void:
	mini_viewport = _create_world_viewport("MiniMapViewport", MINI_VIEW_SIZE, MINI_WORLD_ZOOM)
	mini_camera = mini_viewport.get_node("MapCamera") as Camera2D
	mini_world_view.texture = mini_viewport.get_texture()
	mini_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	full_viewport = _create_world_viewport("FullMapViewport", FULL_VIEW_SIZE, FULL_WORLD_ZOOM)
	full_camera = full_viewport.get_node("MapCamera") as Camera2D
	full_camera.global_position = world_bounds.get_center()
	full_world_view.texture = full_viewport.get_texture()
	full_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _create_world_viewport(viewport_name: String, viewport_size: Vector2i, camera_zoom: float) -> SubViewport:
	var map_viewport := SubViewport.new()
	map_viewport.name = viewport_name
	map_viewport.size = viewport_size
	map_viewport.disable_3d = true
	map_viewport.transparent_bg = false
	map_viewport.handle_input_locally = false
	add_child(map_viewport)
	map_viewport.world_2d = get_viewport().world_2d
	var camera := Camera2D.new()
	camera.name = "MapCamera"
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	camera.position_smoothing_enabled = false
	map_viewport.add_child(camera)
	camera.enabled = true
	return map_viewport


func world_to_map_position(world_position: Vector2, canvas_size: Vector2, compact: bool) -> Vector2:
	if compact and is_instance_valid(player):
		return canvas_size * 0.5 + (world_position - player.global_position) * MINI_WORLD_ZOOM
	return canvas_size * 0.5 + (world_position - world_bounds.get_center()) * FULL_WORLD_ZOOM


func _toggle_full_map() -> void:
	map_open = not map_open
	full_overlay.visible = map_open
	mini_panel.visible = not map_open
	if map_open and is_instance_valid(full_viewport):
		full_camera.global_position = world_bounds.get_center()
		full_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	get_tree().paused = map_open
