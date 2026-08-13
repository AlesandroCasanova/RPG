extends CanvasLayer


@onready var health_bar: ProgressBar = $PlayerHealthBar
@onready var health_label: Label = $HealthLabel


var player: CharacterBody2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group(
		"player"
	) as CharacterBody2D

	if player == null:
		print("HUD: Player no encontrado")
	else:
		print("HUD: Player encontrado")

	_style_health_bar()


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(
			"player"
		) as CharacterBody2D

		return

	var current_health: int = player.health
	var player_max_health: int = player.max_health

	health_bar.max_value = player_max_health
	health_bar.value = current_health

	health_label.text = (
		str(current_health)
		+ " / "
		+ str(player_max_health)
	)


func _style_health_bar() -> void:
	# Fondo oscuro.
	var background := StyleBoxFlat.new()

	background.bg_color = Color(
		0.08,
		0.08,
		0.08,
		0.95
	)

	background.border_color = Color(
		0.7,
		0.7,
		0.7,
		1.0
	)

	background.set_border_width_all(2)
	background.set_corner_radius_all(5)

	health_bar.add_theme_stylebox_override(
		"background",
		background
	)


	# Parte roja de HP.
	var fill := StyleBoxFlat.new()

	fill.bg_color = Color(
		0.75,
		0.05,
		0.05,
		1.0
	)

	fill.set_corner_radius_all(4)

	health_bar.add_theme_stylebox_override(
		"fill",
		fill
	)


	# Texto.
	health_label.add_theme_font_size_override(
		"font_size",
		17
	)

	health_label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	health_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	health_label.add_theme_constant_override(
		"outline_size",
		4
	)
