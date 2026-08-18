extends SceneTree


const ENVIRONMENT_SCENE := preload(
	"res://scenes/tutorial/frontier_environment.tscn"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var environment := ENVIRONMENT_SCENE.instantiate() as FrontierEnvironment
	root.add_child(environment)

	for _frame: int in 4:
		await physics_frame

	if not environment.navigation_bake_succeeded:
		_fail("El bake de navegación no finalizó correctamente.")
		return
	var expected_obstruction_count := 0
	for body_node: Node in environment.get_node("Collisions").get_children():
		var body := body_node as StaticBody2D
		if body == null:
			continue
		var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null and not collision.disabled and collision.shape is RectangleShape2D:
			expected_obstruction_count += 1
	if environment.navigation_bake_obstruction_count != expected_obstruction_count:
		_fail(
			"Se esperaban %d obstrucciones rectangulares y se hornearon %d."
			% [expected_obstruction_count, environment.navigation_bake_obstruction_count]
		)
		return

	var region := environment.get_node("NavigationRegion2D") as NavigationRegion2D
	var polygon := region.navigation_polygon
	if polygon == null or polygon.get_polygon_count() <= 1:
		_fail("El NavigationPolygon no fue dividido alrededor de los blockers.")
		return

	var navigation_map := region.get_navigation_map()
	for body_node: Node in environment.get_node("Collisions").get_children():
		var body := body_node as StaticBody2D
		if body == null:
			continue
		var closest_point := NavigationServer2D.map_get_closest_point(
			navigation_map,
			body.global_position
		)
		if closest_point.distance_to(body.global_position) < 20.0:
			_fail("El centro de %s todavía pertenece a la superficie navegable." % body.name)
			return

	var path := NavigationServer2D.map_get_path(
		navigation_map,
		Vector2(1850.0, 980.0),
		Vector2(2350.0, 980.0),
		true
	)
	if path.size() < 3:
		_fail("La ruta de prueba no rodea el blocker de la torre.")
		return

	print(
		"NAVIGATION_BAKE_TEST_OK | blockers=",
		environment.navigation_bake_obstruction_count,
		" polygons=",
		polygon.get_polygon_count(),
		" path_points=",
		path.size()
	)
	quit(0)


func _fail(message: String) -> void:
	push_error("NAVIGATION_BAKE_TEST: " + message)
	quit(1)
