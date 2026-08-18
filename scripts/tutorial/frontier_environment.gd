class_name FrontierEnvironment
extends Node


const GROUND_TEXTURE: Texture2D = preload(
	"res://assets/environment/frontier_pass/moss_ground.png"
)

const PATH_TEXTURE: Texture2D = preload(
	"res://assets/environment/frontier_pass/dirt_path.png"
)

const OAK_TEXTURE: Texture2D = preload(
	"res://assets/environment/frontier_pass/ancient_oak.png"
)

const ROCK_TEXTURE: Texture2D = preload(
	"res://assets/environment/frontier_pass/mossy_rocks.png"
)

const GRASS_TEXTURE: Texture2D = preload(
	"res://assets/environment/frontier_pass/tall_grass.png"
)

const COTTAGE_TEXTURE: Texture2D = preload(
	"res://assets/environment/frontier_pass/ranger_cottage.png"
)

const WATCHTOWER_TEXTURE: Texture2D = preload(
	"res://assets/environment/frontier_pass/ruined_watchtower.png"
)

const CORRUPTION_TEXTURE: Texture2D = preload(
	"res://assets/environment/frontier_pass/corruption_scar.png"
)


func _ready() -> void:

	call_deferred("_build_environment")


func _build_environment() -> void:

	var world: Node2D = get_node("../World") as Node2D
	var environment: Node2D = world.get_node("Environment") as Node2D


	var original_ground: CanvasItem = world.get_node_or_null("Ground") as CanvasItem


	if original_ground != null:

		original_ground.visible = false


	var original_tree: CanvasItem = environment.get_node_or_null(
		"TreeTest"
	) as CanvasItem


	if original_tree != null:

		original_tree.visible = false


	_expand_navigation(world)


	for pickup_name: String in [
		"LootSword",
		"LootBoots",
		"LootCharm",
		"LootMaterials"
	]:

		var pickup: Node = world.get_node_or_null(pickup_name)


		if pickup != null:

			pickup.queue_free()


	for ground_position: Vector2 in [
		Vector2(700, 430),
		Vector2(1900, 430),
		Vector2(700, 1080),
		Vector2(1900, 1080)
	]:

		_add_floor_sprite(
			world,
			GROUND_TEXTURE,
			ground_position,
			Vector2(1.08, 0.58),
			-20
		)


	for path_data: Dictionary in [
		{"position": Vector2(1080, 540), "rotation": 0.12},
		{"position": Vector2(820, 485), "rotation": -0.08},
		{"position": Vector2(565, 445), "rotation": -0.12},
		{"position": Vector2(1320, 650), "rotation": 0.28},
		{"position": Vector2(1550, 790), "rotation": 0.18},
		{"position": Vector2(1810, 885), "rotation": 0.07},
		{"position": Vector2(2040, 1010), "rotation": 0.26},
		{"position": Vector2(2200, 1240), "rotation": 0.55}
	]:

		var path_sprite: Sprite2D = _add_floor_sprite(
			world,
			PATH_TEXTURE,
			path_data["position"],
			Vector2(0.32, 0.075),
			-19
		)
		path_sprite.rotation = float(path_data["rotation"])


	_add_prop(
		environment,
		"RangerCottage",
		COTTAGE_TEXTURE,
		Vector2(1115, 430),
		Vector2.ONE * 0.29
	)
	_add_prop(
		environment,
		"AncientOak",
		OAK_TEXTURE,
		Vector2(420, 430),
		Vector2.ONE * 0.25
	)
	_add_prop(
		environment,
		"MossyRocks",
		ROCK_TEXTURE,
		Vector2(680, 345),
		Vector2.ONE * 0.15
	)
	_add_prop(
		environment,
		"RuinedWatchtower",
		WATCHTOWER_TEXTURE,
		Vector2(2100, 1000),
		Vector2.ONE * 0.27
	)


	var dormant_heart: Node2D = _add_prop(
		environment,
		"DormantCorruptedHeart",
		CORRUPTION_TEXTURE,
		Vector2(2260, 1300),
		Vector2.ONE * 0.2
	)
	dormant_heart.modulate = Color(0.62, 0.52, 0.62, 0.72)


	var oak_positions: Array[Vector2] = [
		Vector2(310, 760),
		Vector2(520, 1160),
		Vector2(1120, 1020),
		Vector2(1420, 430),
		Vector2(1920, 520),
		Vector2(2420, 860)
	]


	for index: int in range(oak_positions.size()):

		_add_prop(
			environment,
			"FrontierOak" + str(index + 1),
			OAK_TEXTURE,
			oak_positions[index],
			Vector2.ONE * (0.19 + float(index % 2) * 0.025)
		)


	var rock_positions: Array[Vector2] = [
		Vector2(980, 830),
		Vector2(1370, 1050),
		Vector2(1740, 550),
		Vector2(2350, 1080)
	]


	for index: int in range(rock_positions.size()):

		_add_prop(
			environment,
			"FrontierRocks" + str(index + 1),
			ROCK_TEXTURE,
			rock_positions[index],
			Vector2.ONE * 0.12
		)


	var grass_positions: Array[Vector2] = [
		Vector2(520, 540),
		Vector2(600, 585),
		Vector2(735, 600),
		Vector2(465, 355),
		Vector2(840, 345),
		Vector2(1220, 590),
		Vector2(1280, 760),
		Vector2(1500, 690),
		Vector2(1690, 940),
		Vector2(1870, 760),
		Vector2(2020, 1180),
		Vector2(2350, 1380)
	]


	for index: int in range(grass_positions.size()):

		var grass: Node2D = _add_prop(
			environment,
			"TallGrass" + str(index + 1),
			GRASS_TEXTURE,
			grass_positions[index],
			Vector2.ONE * (0.115 + float(index % 3) * 0.01)
		)
		grass.modulate = Color(0.83, 0.9, 0.78, 0.92)


	_add_blocker(
		environment,
		"CottageBlocker",
		Vector2(1115, 410),
		Vector2(250, 115)
	)
	_add_blocker(
		environment,
		"OakBlocker",
		Vector2(420, 412),
		Vector2(100, 70)
	)
	_add_blocker(
		environment,
		"RockBlocker",
		Vector2(680, 335),
		Vector2(145, 72)
	)
	_add_blocker(
		environment,
		"WatchtowerBlocker",
		Vector2(2100, 980),
		Vector2(180, 120)
	)


func _expand_navigation(world: Node2D) -> void:

	var navigation_region: NavigationRegion2D = world.get_node_or_null(
		"NavigationRegion2D"
	) as NavigationRegion2D


	if navigation_region == null:

		return


	var navigation_polygon: NavigationPolygon = NavigationPolygon.new()
	navigation_polygon.vertices = PackedVector2Array([
		Vector2(120, 120),
		Vector2(2480, 120),
		Vector2(2480, 1480),
		Vector2(120, 1480)
	])
	navigation_polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation_region.navigation_polygon = navigation_polygon


func _add_floor_sprite(
	parent: Node,
	texture: Texture2D,
	position: Vector2,
	scale: Vector2,
	z_index: int
) -> Sprite2D:

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.position = position
	sprite.scale = scale
	sprite.z_index = z_index
	parent.add_child(sprite)
	return sprite


func _add_prop(
	parent: Node2D,
	prop_name: String,
	texture: Texture2D,
	ground_position: Vector2,
	prop_scale: Vector2
) -> Node2D:

	var prop: Node2D = Node2D.new()
	prop.name = prop_name
	prop.position = ground_position
	parent.add_child(prop)


	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = prop_scale
	sprite.position.y = -texture.get_height() * prop_scale.y * 0.5
	prop.add_child(sprite)
	return prop


func _add_blocker(
	parent: Node2D,
	blocker_name: String,
	position: Vector2,
	size: Vector2
) -> void:

	var body: StaticBody2D = StaticBody2D.new()
	body.name = blocker_name
	body.position = position
	parent.add_child(body)


	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
