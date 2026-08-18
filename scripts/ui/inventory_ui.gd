class_name InventoryUI
extends CanvasLayer


const INVENTORY_FRAME: Texture2D = preload(
	"res://assets/ui/inventory/inventory_frame.png"
)


var player: CharacterBody2D = null
var inventory: PlayerInventory = null

var backdrop: ColorRect = null
var panel: PanelContainer = null
var item_list: ItemList = null
var details_label: Label = null
var equipment_label: Label = null
var stats_label: Label = null
var equip_button: Button = null

var equipment_icons: Dictionary = {}

var selected_stack_index: int = -1
var previous_pause_state: bool = false


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_interface()
	call_deferred("_connect_inventory")


func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("inventory"):

		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return


	if panel.visible and event.is_action_pressed("ui_cancel"):

		_close_inventory()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:

	backdrop = ColorRect.new()
	backdrop.name = "InventoryBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.68)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.visible = false
	add_child(backdrop)


	panel = PanelContainer.new()
	panel.name = "InventoryPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -460.0
	panel.offset_top = -305.0
	panel.offset_right = 460.0
	panel.offset_bottom = 305.0
	panel.visible = false
	add_child(panel)


	var background: StyleBoxTexture = StyleBoxTexture.new()
	background.texture = INVENTORY_FRAME
	background.texture_margin_left = 108.0
	background.texture_margin_right = 108.0
	background.texture_margin_top = 108.0
	background.texture_margin_bottom = 108.0
	background.draw_center = true
	panel.add_theme_stylebox_override("panel", background)
	panel.theme = _create_inventory_theme()


	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)


	var main_column: VBoxContainer = VBoxContainer.new()
	main_column.add_theme_constant_override("separation", 12)
	margin.add_child(main_column)


	var header: HBoxContainer = HBoxContainer.new()
	main_column.add_child(header)


	var title: Label = Label.new()
	title.text = "INVENTARIO Y EQUIPAMIENTO"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.68, 0.86, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)


	var close_button: Button = Button.new()
	close_button.text = "Cerrar [I]"
	close_button.pressed.connect(_close_inventory)
	header.add_child(close_button)


	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	main_column.add_child(content)


	var inventory_column: VBoxContainer = VBoxContainer.new()
	inventory_column.custom_minimum_size = Vector2(430.0, 0.0)
	inventory_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(inventory_column)


	var inventory_title: Label = Label.new()
	inventory_title.text = "Objetos"
	inventory_title.add_theme_font_size_override("font_size", 18)
	inventory_column.add_child(inventory_title)


	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.select_mode = ItemList.SELECT_SINGLE
	item_list.fixed_icon_size = Vector2i(54, 54)
	item_list.icon_mode = ItemList.ICON_MODE_LEFT
	item_list.add_theme_constant_override("v_separation", 7)
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)
	inventory_column.add_child(item_list)


	var actions: HBoxContainer = HBoxContainer.new()
	inventory_column.add_child(actions)
	inventory_column.move_child(actions, 1)


	equip_button = Button.new()
	equip_button.text = "Equipar"
	equip_button.disabled = true
	equip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_button.pressed.connect(_equip_selected_item)
	actions.add_child(equip_button)


	var info_column: VBoxContainer = VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_column.add_theme_constant_override("separation", 10)
	content.add_child(info_column)


	var equipment_title: Label = Label.new()
	equipment_title.text = "Equipo actual"
	equipment_title.add_theme_font_size_override("font_size", 18)
	info_column.add_child(equipment_title)


	var equipment_row: HBoxContainer = HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 8)
	info_column.add_child(equipment_row)
	_add_equipment_slot(
		equipment_row,
		"ARMA",
		ItemData.EquipmentSlot.WEAPON
	)
	_add_equipment_slot(
		equipment_row,
		"ARMADURA",
		ItemData.EquipmentSlot.ARMOR
	)
	_add_equipment_slot(
		equipment_row,
		"ACCESORIO",
		ItemData.EquipmentSlot.ACCESSORY
	)


	var separator: HSeparator = HSeparator.new()
	info_column.add_child(separator)


	details_label = Label.new()
	details_label.text = "Seleccioná un objeto para ver sus detalles."
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.custom_minimum_size = Vector2(330.0, 70.0)
	info_column.add_child(details_label)


	stats_label = Label.new()
	stats_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	stats_label.add_theme_font_size_override("font_size", 14)
	info_column.add_child(stats_label)


func _create_inventory_theme() -> Theme:

	var inventory_theme: Theme = Theme.new()
	inventory_theme.set_color(
		"font_color",
		"Label",
		Color(0.9, 0.91, 0.94, 1.0)
	)
	inventory_theme.set_font_size("font_size", "Label", 14)
	inventory_theme.set_color(
		"font_color",
		"Button",
		Color(0.82, 0.88, 0.95, 1.0)
	)
	inventory_theme.set_color(
		"font_hover_color",
		"Button",
		Color.WHITE
	)
	inventory_theme.set_stylebox(
		"normal",
		"Button",
		_make_flat_box(
			Color(0.07, 0.09, 0.12, 0.96),
			Color(0.27, 0.42, 0.56, 0.9),
			4
		)
	)
	inventory_theme.set_stylebox(
		"hover",
		"Button",
		_make_flat_box(
			Color(0.1, 0.18, 0.25, 0.98),
			Color(0.42, 0.68, 0.9, 1.0),
			4
		)
	)
	inventory_theme.set_stylebox(
		"pressed",
		"Button",
		_make_flat_box(
			Color(0.04, 0.11, 0.17, 1.0),
			Color(0.3, 0.75, 1.0, 1.0),
			4
		)
	)
	inventory_theme.set_stylebox(
		"panel",
		"ItemList",
		_make_flat_box(
			Color(0.015, 0.02, 0.028, 0.88),
			Color(0.24, 0.35, 0.47, 0.78),
			6
		)
	)
	var selection_box: StyleBoxFlat = _make_flat_box(
		Color(0.08, 0.2, 0.3, 0.92),
		Color(0.38, 0.72, 0.98, 0.95),
		4
	)
	inventory_theme.set_stylebox("selected", "ItemList", selection_box)
	inventory_theme.set_stylebox("selected_focus", "ItemList", selection_box)


	return inventory_theme


func _make_flat_box(
	fill_color: Color,
	outline_color: Color,
	corner_radius: int
) -> StyleBoxFlat:

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = outline_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0


	return style


func _add_equipment_slot(
	parent: HBoxContainer,
	slot_name: String,
	slot: ItemData.EquipmentSlot
) -> void:

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)


	var title: Label = Label.new()
	title.text = slot_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(0.65, 0.75, 0.85, 1.0)
	column.add_child(title)


	var slot_panel: PanelContainer = PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(96.0, 82.0)


	var slot_style: StyleBoxFlat = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.015, 0.02, 0.03, 0.9)
	slot_style.border_color = Color(0.28, 0.43, 0.58, 0.85)
	slot_style.set_border_width_all(2)
	slot_style.set_corner_radius_all(5)
	slot_panel.add_theme_stylebox_override("panel", slot_style)
	column.add_child(slot_panel)


	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_child(icon_rect)
	equipment_icons[slot] = icon_rect


	var button: Button = Button.new()
	button.text = "Quitar"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_unequip_slot.bind(slot))
	column.add_child(button)


func _connect_inventory() -> void:

	player = get_tree().get_first_node_in_group("player") as CharacterBody2D


	if player == null or not player.has_method("get_inventory"):

		push_warning("InventoryUI: no se encontró el inventario del Player.")
		return


	inventory = player.get_inventory()


	if inventory == null:

		push_warning("InventoryUI: el Player no tiene nodo Inventory.")
		return


	inventory.inventory_changed.connect(_refresh)
	inventory.equipment_changed.connect(_refresh)
	_refresh()


func _toggle_inventory() -> void:

	if panel.visible:

		_close_inventory()
		return


	_open_inventory()


func _open_inventory() -> void:

	previous_pause_state = get_tree().paused
	backdrop.visible = true
	panel.visible = true
	get_tree().paused = true
	_refresh()


func _close_inventory() -> void:

	if not panel.visible:

		return


	backdrop.visible = false
	panel.visible = false
	get_tree().paused = previous_pause_state


func _refresh() -> void:

	if inventory == null:

		return


	item_list.clear()


	for index: int in range(inventory.stacks.size()):

		var stack: Dictionary = inventory.stacks[index]
		var item: ItemData = stack.get("item") as ItemData


		if item == null:

			continue


		var row_text: String = item.display_name
		var quantity: int = int(stack.get("quantity", 1))


		if quantity > 1:

			row_text += "  x" + str(quantity)


		if inventory.is_item_equipped(item):

			row_text = "[E] " + row_text


		item_list.add_item(row_text, item.icon)
		item_list.set_item_custom_fg_color(
			item_list.item_count - 1,
			item.get_rarity_color()
		)


	selected_stack_index = -1
	equip_button.disabled = true
	details_label.text = "Seleccioná un objeto para ver sus detalles."
	_update_equipment_text()
	_update_stats_text()


func _on_item_selected(index: int) -> void:

	selected_stack_index = index


	if inventory == null or index < 0 or index >= inventory.stacks.size():

		return


	var item: ItemData = inventory.stacks[index].get("item") as ItemData


	if item == null:

		return


	details_label.text = (
		item.display_name
		+ "\n\n"
		+ item.description
		+ "\n\n"
		+ item.get_bonus_text()
	)
	equip_button.disabled = not item.is_equipment()


func _on_item_activated(index: int) -> void:

	selected_stack_index = index
	_equip_selected_item()


func _equip_selected_item() -> void:

	if inventory == null:

		return


	inventory.equip_stack(selected_stack_index)


func _unequip_slot(slot: ItemData.EquipmentSlot) -> void:

	if inventory != null:

		inventory.unequip_slot(slot)


func _update_equipment_text() -> void:

	var weapon: ItemData = inventory.get_equipped_item(
		ItemData.EquipmentSlot.WEAPON
	)
	var armor: ItemData = inventory.get_equipped_item(
		ItemData.EquipmentSlot.ARMOR
	)
	var accessory: ItemData = inventory.get_equipped_item(
		ItemData.EquipmentSlot.ACCESSORY
	)


	_set_equipment_icon(ItemData.EquipmentSlot.WEAPON, weapon)
	_set_equipment_icon(ItemData.EquipmentSlot.ARMOR, armor)
	_set_equipment_icon(ItemData.EquipmentSlot.ACCESSORY, accessory)


func _set_equipment_icon(
	slot: ItemData.EquipmentSlot,
	item: ItemData
) -> void:

	var icon_rect: TextureRect = equipment_icons.get(slot) as TextureRect


	if icon_rect == null:

		return


	icon_rect.texture = item.icon if item != null else null
	icon_rect.tooltip_text = (
		item.display_name + "\n" + item.get_bonus_text()
		if item != null
		else "Ranura vacía"
	)


func _update_stats_text() -> void:

	if player == null:

		return


	stats_label.text = (
		"VIT " + str(player.get("effective_vitality"))
		+ "   FUE " + str(player.get("effective_strength"))
		+ "   DES " + str(player.get("effective_dexterity"))
		+ "   AGU " + str(player.get("effective_endurance"))
		+ "   INT " + str(player.get("effective_intelligence"))
		+ "   VOL " + str(player.get("effective_willpower"))
		+ "\nVida " + str(player.get("max_health"))
		+ "   Stamina " + str(roundi(float(player.get("max_stamina"))))
		+ "   Maná " + str(roundi(float(player.get("max_mana"))))
		+ "\nDaño " + str(player.get("attack_damage"))
		+ "   Magia " + str(snappedf(float(player.get("magic_power")), 0.1))
		+ "   Vel. " + str(roundi(float(player.get("speed"))))
		+ "\nATQ x"
		+ str(snappedf(float(player.get("attack_speed_multiplier")), 0.01))
		+ "   RES "
		+ str(roundi(float(player.get("knockback_resistance")) * 100.0))
		+ "%"
	)
