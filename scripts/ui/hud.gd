extends CanvasLayer


# =========================================================
# NODOS
# =========================================================

@onready var health_bar: ProgressBar = $PlayerHealthBar
@onready var health_label: Label = $HealthLabel

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var stamina_label: Label = $StaminaLabel

@onready var mana_bar: ProgressBar = $ManaBar
@onready var mana_label: Label = $ManaLabel


# =========================================================
# PLAYER
# =========================================================

var player: CharacterBody2D = null


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	_find_player()


# =========================================================
# ACTUALIZAR HUD
# =========================================================

func _process(_delta: float) -> void:

	if not is_instance_valid(player):
		_find_player()
		return


	# -----------------------------------------------------
	# VIDA
	# -----------------------------------------------------

	var current_health: int = int(
		player.get("health")
	)

	var player_max_health: int = int(
		player.get("max_health")
	)


	health_bar.max_value = player_max_health

	health_bar.value = current_health


	health_label.text = (
		str(current_health)
		+ " / "
		+ str(player_max_health)
	)


	# -----------------------------------------------------
	# STAMINA
	# -----------------------------------------------------

	var current_stamina: float = float(
		player.get("stamina")
	)

	var player_max_stamina: float = float(
		player.get("max_stamina")
	)


	stamina_bar.max_value = player_max_stamina

	stamina_bar.value = current_stamina


	stamina_label.text = (
		str(int(round(current_stamina)))
		+ " / "
		+ str(int(round(player_max_stamina)))
	)


	# -----------------------------------------------------
	# MANÁ
	# -----------------------------------------------------

	var current_mana: float = float(player.get("mana"))
	var player_max_mana: float = float(player.get("max_mana"))

	mana_bar.max_value = player_max_mana
	mana_bar.value = current_mana
	mana_label.text = (
		str(int(round(current_mana)))
		+ " / "
		+ str(int(round(player_max_mana)))
	)


# =========================================================
# BUSCAR PLAYER
# =========================================================

func _find_player() -> void:

	player = get_tree().get_first_node_in_group(
		"player"
	) as CharacterBody2D


	if player == null:

		print(
			"HUD: Player no encontrado"
		)

	else:

		print(
			"HUD: Player encontrado"
		)


# =========================================================
# ESTILO VIDA
# =========================================================

func _style_health_bar() -> void:

	# -----------------------------------------------------
	# FONDO
	# -----------------------------------------------------

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


	background.set_border_width_all(
		2
	)


	background.set_corner_radius_all(
		5
	)


	health_bar.add_theme_stylebox_override(
		"background",
		background
	)


	# -----------------------------------------------------
	# VIDA ROJA
	# -----------------------------------------------------

	var fill := StyleBoxFlat.new()


	fill.bg_color = Color(
		0.75,
		0.05,
		0.05,
		1.0
	)


	fill.set_corner_radius_all(
		4
	)


	health_bar.add_theme_stylebox_override(
		"fill",
		fill
	)


	# -----------------------------------------------------
	# TEXTO
	# -----------------------------------------------------

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


# =========================================================
# ESTILO STAMINA
# =========================================================

func _style_stamina_bar() -> void:

	# -----------------------------------------------------
	# FONDO
	# -----------------------------------------------------

	var background := StyleBoxFlat.new()


	background.bg_color = Color(
		0.08,
		0.08,
		0.08,
		0.95
	)


	background.border_color = Color(
		0.65,
		0.65,
		0.65,
		1.0
	)


	background.set_border_width_all(
		2
	)


	background.set_corner_radius_all(
		4
	)


	stamina_bar.add_theme_stylebox_override(
		"background",
		background
	)


	# -----------------------------------------------------
	# STAMINA DORADA
	# -----------------------------------------------------

	var fill := StyleBoxFlat.new()


	fill.bg_color = Color(
		0.85,
		0.65,
		0.08,
		1.0
	)


	fill.set_corner_radius_all(
		3
	)


	stamina_bar.add_theme_stylebox_override(
		"fill",
		fill
	)


	# -----------------------------------------------------
	# TEXTO
	# -----------------------------------------------------

	stamina_label.add_theme_font_size_override(
		"font_size",
		14
	)


	stamina_label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)


	stamina_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)


	stamina_label.add_theme_constant_override(
		"outline_size",
		3
	)


# =========================================================
# ESTILO MANÁ
# =========================================================

func _style_mana_bar() -> void:

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	background.border_color = Color(0.55, 0.65, 0.8, 1.0)
	background.set_border_width_all(2)
	background.set_corner_radius_all(4)
	mana_bar.add_theme_stylebox_override("background", background)


	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.08, 0.35, 0.9, 1.0)
	fill.set_corner_radius_all(3)
	mana_bar.add_theme_stylebox_override("fill", fill)


	mana_label.add_theme_font_size_override("font_size", 14)
	mana_label.add_theme_color_override("font_color", Color.WHITE)
	mana_label.add_theme_color_override("font_outline_color", Color.BLACK)
	mana_label.add_theme_constant_override("outline_size", 3)
