class_name WorldMapUI
extends CanvasLayer


class MapCanvas extends Control:

	var map_owner: WorldMapUI

	var compact: bool = false


	func _process(_delta: float) -> void:

		queue_redraw()


	func _draw() -> void:

		if map_owner == null:

			return


		var inner: Rect2 = Rect2(
			Vector2(10, 10),
			size - Vector2(20, 20)
		)
		draw_rect(inner, Color(0.12, 0.105, 0.07, 1.0), true)


		if not compact:

			_draw_regions(inner)


		_draw_roads(inner)
		_draw_locations(inner)
		_draw_quest_marker(inner)
		_draw_player(inner)


	func _draw_regions(inner: Rect2) -> void:

		var refuge: Vector2 = _world_to_map(Vector2(950, 510), inner)
		var battlefield: Vector2 = _world_to_map(Vector2(1600, 810), inner)
		var tower: Vector2 = _world_to_map(Vector2(2100, 1010), inner)
		var heart: Vector2 = _world_to_map(Vector2(2260, 1300), inner)
		draw_circle(refuge, 76.0, Color(0.2, 0.32, 0.17, 0.42))
		draw_circle(battlefield, 108.0, Color(0.28, 0.18, 0.15, 0.4))
		draw_circle(tower, 72.0, Color(0.18, 0.22, 0.19, 0.4))
		draw_circle(heart, 62.0, Color(0.31, 0.08, 0.16, 0.42))


	func _draw_roads(inner: Rect2) -> void:

		var road_points: PackedVector2Array = PackedVector2Array()


		for world_point: Vector2 in map_owner.road_points:

			road_points.append(_world_to_map(world_point, inner))


		if road_points.size() >= 2:

			draw_polyline(
				road_points,
				Color(0.49, 0.37, 0.21, 0.9),
				(3.0 if compact else 8.0),
				true
			)


	func _draw_locations(inner: Rect2) -> void:

		for location_id: StringName in map_owner.locations:

			var location: Dictionary = map_owner.locations[location_id]


			if not bool(location.get("discovered", false)):

				continue


			var marker_position: Vector2 = _world_to_map(
				location["position"],
				inner
			)
			draw_circle(
				marker_position,
				(4.0 if compact else 8.0),
				location["color"]
			)


			if not compact:

				draw_string(
					ThemeDB.fallback_font,
					marker_position + Vector2(12, 5),
					String(location["name"]),
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					16,
					Color(0.9, 0.84, 0.68, 1.0)
				)


	func _draw_quest_marker(inner: Rect2) -> void:

		if not map_owner.has_quest_marker:

			return


		var marker_position: Vector2 = _world_to_map(
			map_owner.quest_position,
			inner
		)
		var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.18
		draw_circle(
			marker_position,
			(7.0 if compact else 12.0) * pulse,
			Color(1.0, 0.72, 0.18, 0.95),
			false,
			(2.0 if compact else 4.0)
		)


	func _draw_player(inner: Rect2) -> void:

		if not is_instance_valid(map_owner.player):

			return


		var player_position: Vector2 = _world_to_map(
			map_owner.player.global_position,
			inner
		)
		var marker: PackedVector2Array = PackedVector2Array([
			player_position + Vector2(0, -9),
			player_position + Vector2(7, 7),
			player_position,
			player_position + Vector2(-7, 7)
		])
		draw_colored_polygon(marker, Color(0.35, 0.75, 1.0, 1.0))
		draw_polyline(
			PackedVector2Array([
				marker[0], marker[1], marker[2], marker[3], marker[0]
			]),
			Color(0.04, 0.08, 0.12, 1.0),
			2.0,
			true
		)


	func _world_to_map(world_position: Vector2, inner: Rect2) -> Vector2:

		if compact and is_instance_valid(map_owner.player):

			var relative: Vector2 = (
				world_position - map_owner.player.global_position
			)
			return inner.get_center() + relative * 0.12


		var normalized: Vector2 = Vector2(
			(world_position.x - map_owner.world_bounds.position.x)
			/ map_owner.world_bounds.size.x,
			(world_position.y - map_owner.world_bounds.position.y)
			/ map_owner.world_bounds.size.y
		)
		return inner.position + normalized * inner.size


const WORLD_BOUNDS: Rect2 = Rect2(100, 100, 2400, 1400)


var world_bounds: Rect2 = WORLD_BOUNDS

var player: Node2D

var mini_panel: PanelContainer

var full_overlay: ColorRect

var mini_canvas: MapCanvas

var full_canvas: MapCanvas

var full_title: Label

var map_open: bool = false

var quest_position: Vector2 = Vector2.ZERO

var quest_label: String = ""

var has_quest_marker: bool = false

var road_points: Array[Vector2] = [
	Vector2(500, 430),
	Vector2(950, 510),
	Vector2(1320, 650),
	Vector2(1620, 820),
	Vector2(1910, 900),
	Vector2(2110, 1040),
	Vector2(2260, 1300)
]

var locations: Dictionary = {
	&"maela_refuge": {
		"name": "Refugio de Maela",
		"position": Vector2(1030, 430),
		"discovered": true,
		"color": Color(0.45, 0.9, 0.48, 1.0)
	},
	&"ashen_pass": {
		"name": "Paso de Ceniza",
		"position": Vector2(650, 480),
		"discovered": true,
		"color": Color(0.82, 0.72, 0.48, 1.0)
	},
	&"old_battlefield": {
		"name": "Campo de los Sin Nombre",
		"position": Vector2(1620, 820),
		"discovered": false,
		"color": Color(0.82, 0.4, 0.35, 1.0)
	},
	&"watchtower": {
		"name": "Torre Quebrada",
		"position": Vector2(2100, 1010),
		"discovered": false,
		"color": Color(0.55, 0.75, 0.68, 1.0)
	},
	&"corrupted_heart": {
		"name": "Fosa de los Murmullos",
		"position": Vector2(2260, 1300),
		"discovered": false,
		"color": Color(0.9, 0.25, 0.48, 1.0)
	}
}


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_interface()
	call_deferred("_find_player")


func _process(_delta: float) -> void:

	if not is_instance_valid(player):

		return


	for location_id: StringName in locations:

		var location: Dictionary = locations[location_id]


		if (
			not bool(location["discovered"])
			and player.global_position.distance_to(location["position"]) < 220.0
		):

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


func _build_interface() -> void:

	mini_panel = PanelContainer.new()
	mini_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mini_panel.offset_left = -246.0
	mini_panel.offset_top = -188.0
	mini_panel.offset_right = -22.0
	mini_panel.offset_bottom = -22.0
	mini_panel.add_theme_stylebox_override("panel", _make_style(0.88))
	add_child(mini_panel)


	mini_canvas = MapCanvas.new()
	mini_canvas.map_owner = self
	mini_canvas.compact = true
	mini_canvas.custom_minimum_size = Vector2(220, 160)
	mini_canvas.clip_contents = true
	mini_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_panel.add_child(mini_canvas)


	var mini_hint: Label = Label.new()
	mini_hint.text = "M  ·  MAPA"
	mini_hint.position = Vector2(12, 8)
	mini_hint.add_theme_font_size_override("font_size", 12)
	mini_hint.add_theme_color_override(
		"font_color",
		Color(0.9, 0.77, 0.45, 1.0)
	)
	mini_canvas.add_child(mini_hint)


	full_overlay = ColorRect.new()
	full_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full_overlay.color = Color(0.015, 0.012, 0.008, 0.94)
	full_overlay.visible = false
	full_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(full_overlay)


	var full_panel: PanelContainer = PanelContainer.new()
	full_panel.set_anchors_preset(Control.PRESET_CENTER)
	full_panel.offset_left = -510.0
	full_panel.offset_top = -310.0
	full_panel.offset_right = 510.0
	full_panel.offset_bottom = 310.0
	full_panel.add_theme_stylebox_override("panel", _make_style(1.0))
	full_overlay.add_child(full_panel)


	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	full_panel.add_child(content)


	full_title = Label.new()
	full_title.text = "MAPA DEL CONTINENTE"
	full_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	full_title.add_theme_font_size_override("font_size", 24)
	full_title.add_theme_color_override(
		"font_color",
		Color(0.92, 0.72, 0.34, 1.0)
	)
	content.add_child(full_title)


	full_canvas = MapCanvas.new()
	full_canvas.map_owner = self
	full_canvas.custom_minimum_size = Vector2(960, 520)
	full_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(full_canvas)


	var close_hint: Label = Label.new()
	close_hint.text = "M  ·  cerrar mapa     ◆ jugador     ◯ objetivo"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.add_theme_font_size_override("font_size", 14)
	close_hint.add_theme_color_override(
		"font_color",
		Color(0.68, 0.62, 0.5, 1.0)
	)
	content.add_child(close_hint)


func _make_style(alpha: float) -> StyleBoxFlat:

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.047, 0.032, alpha)
	style.border_color = Color(0.43, 0.31, 0.15, 1.0)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
