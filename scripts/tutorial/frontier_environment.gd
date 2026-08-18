class_name FrontierEnvironment
extends Node2D


signal navigation_bake_completed(success: bool, obstruction_count: int)


var navigation_bake_succeeded: bool = false
var navigation_bake_obstruction_count: int = 0


## La geometría y sus colliders siguen editándose en la escena. Al entrar al
## árbol, cada rectángulo físico recibe dos representaciones complementarias:
## un NavigationObstacle2D para avoidance local y un contorno obstruido en el
## NavigationPolygon horneado para que el path global rodee el escenario.
func _ready() -> void:
	_setup_avoidance_obstacles()
	_bake_navigation_polygon.call_deferred()


func _setup_avoidance_obstacles() -> void:
	var collisions := get_node_or_null("Collisions")
	if collisions == null:
		return
	for body_node: Node in collisions.get_children():
		var body := body_node as StaticBody2D
		if body == null or body.get_node_or_null("NavigationObstacle2D") != null:
			continue
		var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or not collision.shape is RectangleShape2D:
			continue
		var rectangle := collision.shape as RectangleShape2D
		var half_size := rectangle.size * 0.5
		var obstacle := NavigationObstacle2D.new()
		obstacle.name = "NavigationObstacle2D"
		obstacle.position = collision.position
		obstacle.rotation = collision.rotation
		obstacle.scale = collision.scale
		# Este orden coincide con el contorno de expulsión recomendado por Godot.
		obstacle.vertices = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		])
		obstacle.avoidance_enabled = true
		obstacle.avoidance_layers = 1
		body.add_child(obstacle)


func _bake_navigation_polygon() -> void:
	navigation_bake_succeeded = false
	navigation_bake_obstruction_count = 0

	var navigation_region := get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	var collisions := get_node_or_null("Collisions")
	if navigation_region == null or collisions == null:
		navigation_bake_completed.emit(false, 0)
		return

	var authored_polygon := navigation_region.navigation_polygon
	if authored_polygon == null or authored_polygon.get_outline_count() == 0:
		push_warning("FrontierEnvironment: falta el contorno exterior de navegación.")
		navigation_bake_completed.emit(false, 0)
		return

	var source_geometry := NavigationMeshSourceGeometryData2D.new()
	for outline_index: int in authored_polygon.get_outline_count():
		source_geometry.add_traversable_outline(
			authored_polygon.get_outline(outline_index)
		)

	for body_node: Node in collisions.get_children():
		var body := body_node as StaticBody2D
		if body == null:
			continue
		var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.disabled:
			continue
		var rectangle := collision.shape as RectangleShape2D
		if rectangle == null:
			continue
		source_geometry.add_obstruction_outline(
			_rectangle_outline_in_region_space(
				collision,
				rectangle,
				navigation_region
			)
		)
		navigation_bake_obstruction_count += 1

	var baked_polygon := NavigationPolygon.new()
	baked_polygon.agent_radius = authored_polygon.agent_radius
	NavigationServer2D.bake_from_source_geometry_data(
		baked_polygon,
		source_geometry
	)

	if baked_polygon.get_polygon_count() == 0:
		push_warning("FrontierEnvironment: el bake de navegación no produjo polígonos.")
		navigation_bake_completed.emit(
			false,
			navigation_bake_obstruction_count
		)
		return

	navigation_region.navigation_polygon = baked_polygon
	navigation_bake_succeeded = true
	navigation_bake_completed.emit(
		true,
		navigation_bake_obstruction_count
	)


func _rectangle_outline_in_region_space(
	collision: CollisionShape2D,
	rectangle: RectangleShape2D,
	navigation_region: NavigationRegion2D
) -> PackedVector2Array:
	var half_size := rectangle.size * 0.5
	var local_corners := PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])
	var region_corners := PackedVector2Array()
	for local_corner: Vector2 in local_corners:
		region_corners.append(
			navigation_region.to_local(
				collision.to_global(local_corner)
			)
		)
	return region_corners
