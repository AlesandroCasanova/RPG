class_name WorldMapCanvas
extends Control


@export var compact: bool = false
var map_owner: WorldMapUI


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if map_owner == null:
		return
	var inner := Rect2(Vector2.ZERO, size)
	_draw_locations(inner)
	_draw_quest_marker(inner)
	_draw_player(inner)


func _draw_locations(inner: Rect2) -> void:
	for location_id: StringName in map_owner.locations:
		var location: Dictionary = map_owner.locations[location_id]
		if not bool(location.get("discovered", false)):
			continue
		var marker_position := _world_to_map(location["position"], inner)
		draw_circle(marker_position, 4.0 if compact else 8.0, location["color"])
		if not compact:
			draw_string(ThemeDB.fallback_font, marker_position + Vector2(12, 5), String(location["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.84, 0.68, 1.0))


func _draw_quest_marker(inner: Rect2) -> void:
	if not map_owner.has_quest_marker:
		return
	var marker_position := _world_to_map(map_owner.quest_position, inner)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.18
	draw_circle(marker_position, (7.0 if compact else 12.0) * pulse, Color(1.0, 0.72, 0.18, 0.95), false, 2.0 if compact else 4.0)


func _draw_player(inner: Rect2) -> void:
	if not is_instance_valid(map_owner.player):
		return
	var player_position := _world_to_map(map_owner.player.global_position, inner)
	var marker := PackedVector2Array([
		player_position + Vector2(0, -9), player_position + Vector2(7, 7),
		player_position, player_position + Vector2(-7, 7)
	])
	draw_colored_polygon(marker, Color(0.35, 0.75, 1.0, 1.0))
	draw_polyline(PackedVector2Array([marker[0], marker[1], marker[2], marker[3], marker[0]]), Color(0.04, 0.08, 0.12, 1.0), 2.0, true)


func _world_to_map(world_position: Vector2, inner: Rect2) -> Vector2:
	return inner.position + map_owner.world_to_map_position(world_position, inner.size, compact)
