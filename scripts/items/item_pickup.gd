class_name ItemPickup
extends Area2D


@export var item_data: ItemData

@export_range(1, 999, 1)
var quantity: int = 1


var item_label: Label = null

var item_sprite: Sprite2D = null

var nearby_player: Node2D = null


func _ready() -> void:

	add_to_group("item_pickups")

	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false


	if not body_entered.is_connected(_on_body_entered):

		body_entered.connect(_on_body_entered)


	if not body_exited.is_connected(_on_body_exited):

		body_exited.connect(_on_body_exited)


	_create_label()
	_create_icon_sprite()
	queue_redraw()


func _create_label() -> void:

	item_label = Label.new()
	item_label.position = Vector2(-80.0, -48.0)
	item_label.custom_minimum_size = Vector2(160.0, 28.0)
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 13)
	item_label.add_theme_color_override("font_outline_color", Color.BLACK)
	item_label.add_theme_constant_override("outline_size", 4)
	item_label.z_index = 50
	add_child(item_label)
	_update_label()


func _update_label() -> void:

	if item_label == null:

		return


	if item_data == null:

		item_label.text = "Loot sin configurar"
		item_label.modulate = Color.RED
		return


	item_label.text = item_data.display_name


	if quantity > 1:

		item_label.text += " x" + str(quantity)


	if nearby_player != null:

		item_label.text = "[F] Recoger  " + item_label.text


	item_label.modulate = item_data.get_rarity_color()


func _create_icon_sprite() -> void:

	if item_data == null or item_data.icon == null:

		return


	item_sprite = Sprite2D.new()
	item_sprite.texture = item_data.icon
	item_sprite.position = Vector2(0.0, -4.0)
	item_sprite.z_index = 10


	var texture_size: Vector2 = item_data.icon.get_size()
	var largest_dimension: float = maxf(
		texture_size.x,
		texture_size.y
	)
	var icon_scale: float = 46.0 / maxf(largest_dimension, 1.0)
	item_sprite.scale = Vector2.ONE * icon_scale
	add_child(item_sprite)


func _on_body_entered(body: Node2D) -> void:

	if item_data == null or not body.has_method("get_inventory"):

		return


	nearby_player = body
	_update_label()


func _on_body_exited(body: Node2D) -> void:

	if body != nearby_player:

		return


	nearby_player = null
	_update_label()


func _unhandled_input(event: InputEvent) -> void:

	if nearby_player == null:

		return


	if not event.is_action_pressed("interact"):

		return


	_collect(nearby_player)
	get_viewport().set_input_as_handled()


func _collect(body: Node2D) -> void:

	if item_data == null or not body.has_method("get_inventory"):

		return


	var inventory: PlayerInventory = body.get_inventory()


	if inventory == null:

		return


	var remaining: int = inventory.add_item(
		item_data,
		quantity
	)
	var collected: int = quantity - remaining


	if collected <= 0:

		return


	print(
		"LOOT: ",
		item_data.display_name,
		" x",
		collected
	)


	if remaining <= 0:

		queue_free()
		return


	quantity = remaining
	_update_label()


func _draw() -> void:

	var color: Color = Color.WHITE


	if item_data != null:

		color = item_data.get_rarity_color()


	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -17.0),
		Vector2(17.0, 0.0),
		Vector2(0.0, 17.0),
		Vector2(-17.0, 0.0)
	])
	draw_colored_polygon(points, Color(color, 0.72))
	draw_polyline(
		PackedVector2Array([
			points[0],
			points[1],
			points[2],
			points[3],
			points[0]
		]),
		Color(color, 1.0),
		3.0,
		true
	)
