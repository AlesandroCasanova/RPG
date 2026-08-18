extends CharacterBody2D


const SpriteSheetAnimationBuilder = preload(
	"res://scripts/animation/sprite_sheet_animation.gd"
)

const PLAYER_WALK_SHEET: Texture2D = preload(
	"res://assets/characters/player/sprites/actions/player_walk_cardinal.png"
)

const PLAYER_CROUCH_SHEET: Texture2D = preload(
	"res://assets/characters/player/sprites/actions/player_crouch_cardinal.png"
)

const PLAYER_ATTACK_SHEET: Texture2D = preload(
	"res://assets/characters/player/sprites/actions/player_attack_cardinal.png"
)

const PLAYER_DASH_SHEET: Texture2D = preload(
	"res://assets/characters/player/sprites/actions/player_dash_cardinal.png"
)


# =========================================================
# ATRIBUTOS PRIMARIOS
# =========================================================

@export_category("Atributos primarios")

@export_range(1, 99, 1)
var vitality: int = 5

@export_range(1, 99, 1)
var strength: int = 5

@export_range(1, 99, 1)
var dexterity: int = 5

@export_range(1, 99, 1)
var endurance: int = 5

@export_range(1, 99, 1)
var intelligence: int = 5

@export_range(1, 99, 1)
var willpower: int = 5

var effective_vitality: int = 5
var effective_strength: int = 5
var effective_dexterity: int = 5
var effective_endurance: int = 5
var effective_intelligence: int = 5
var effective_willpower: int = 5


# =========================================================
# MOVIMIENTO
# =========================================================

@export var speed: float = 300.0
@export var sprint_speed: float = 450.0
@export var sprint_stamina_per_second: float = 20.0

@export var crouch_speed: float = 80.0

@export_range(0.0, 1.0, 0.01)
var crouch_noise_multiplier: float = 0.12

@export_range(1.0, 3.0, 0.05)
var sprint_noise_multiplier: float = 1.35

@export_range(0.5, 1.0, 0.01)
var crouch_visual_height: float = 0.82

@export_range(0.0, 50.0, 1.0)
var crouch_visual_offset: float = 10.0


# =========================================================
# STAMINA
# =========================================================

@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 25.0
@export var stamina_regen_delay: float = 0.75

var stamina: float = 100.0
var stamina_regen_delay_left: float = 0.0

var is_sprinting: bool = false

var is_crouching: bool = false

var standing_sprite_scale: Vector2 = Vector2.ONE

var standing_sprite_position: Vector2 = Vector2.ZERO

var crouch_debug_label: Label = null


# =========================================================
# MANÁ / PODER MÁGICO
# =========================================================

@export var max_mana: float = 60.0
@export var mana_regen_rate: float = 5.0
@export var magic_power: float = 10.0

var mana: float = 60.0

var attack_speed_multiplier: float = 1.0


# =========================================================
# ESTADÍSTICAS BASE / EQUIPAMIENTO
# =========================================================

var base_speed: float = 0.0
var base_sprint_speed: float = 0.0
var base_crouch_speed: float = 0.0
var base_max_health: int = 0
var base_max_stamina: float = 0.0
var base_stamina_regen_rate: float = 0.0
var base_sprint_stamina_per_second: float = 0.0
var base_dash_stamina_cost: float = 0.0
var base_max_mana: float = 0.0
var base_mana_regen_rate: float = 0.0
var base_magic_power: float = 0.0
var base_attack_damage: int = 0
var base_heavy_attack_damage: int = 0
var base_charged_attack_damage: int = 0
var base_attack_knockback_force: float = 0.0
var base_heavy_attack_knockback_force: float = 0.0
var base_charged_attack_knockback_force: float = 0.0
var base_knockback_resistance: float = 0.0
var base_attack_duration: float = 0.0
var base_attack_cooldown: float = 0.0
var base_heavy_attack_windup: float = 0.0
var base_heavy_attack_hit_duration: float = 0.0
var base_heavy_attack_total_duration: float = 0.0
var base_charged_attack_windup: float = 0.0
var base_charged_attack_hit_duration: float = 0.0
var base_charged_attack_total_duration: float = 0.0


# =========================================================
# DASH
# =========================================================

@export var dash_speed: float = 850.0
@export var dash_duration: float = 0.14
@export var dash_cooldown: float = 0.40
@export var dash_double_tap_window: float = 0.25
@export var dash_stamina_cost: float = 25.0


# =========================================================
# VIDA
# =========================================================

@export var max_health: int = 100

var health: int = 100
var is_dead: bool = false


# =========================================================
# KNOCKBACK RECIBIDO
# =========================================================

@export_range(0.0, 1.0, 0.05)
var knockback_resistance: float = 0.0

@export_range(0.0, 10000.0, 1.0)
var received_knockback_friction: float = 1600.0

var received_knockback_velocity: Vector2 = Vector2.ZERO


# =========================================================
# ATAQUE NORMAL
# =========================================================

@export var attack_damage: int = 25
@export var attack_distance: float = 55.0
@export var attack_duration: float = 0.12
@export var attack_cooldown: float = 0.35

@export var attack_knockback_force: float = 120.0
@export var attack_hitstop_duration: float = 0.03


# =========================================================
# ATAQUE PESADO
# =========================================================

@export var heavy_attack_damage: int = 45
@export var heavy_attack_distance: float = 65.0
@export var heavy_attack_stamina_cost: float = 25.0

@export var heavy_attack_max_targets: int = 2

@export var heavy_attack_windup: float = 0.22
@export var heavy_attack_hit_duration: float = 0.18
@export var heavy_attack_total_duration: float = 0.70

@export var heavy_attack_knockback_force: float = 220.0
@export var heavy_attack_hitstop_duration: float = 0.06


# =========================================================
# ATAQUE CARGADO
# =========================================================

@export var charged_attack_required_hold: float = 1.0

@export var charged_attack_damage: int = 80
@export var charged_attack_distance: float = 55.0
@export var charged_attack_stamina_cost: float = 60.0

@export var charged_attack_windup: float = 0.18
@export var charged_attack_hit_duration: float = 0.22
@export var charged_attack_total_duration: float = 0.95

@export var charged_attack_max_targets: int = 8

@export var charged_attack_knockback_force: float = 380.0
@export var charged_attack_hitstop_duration: float = 0.10


# =========================================================
# CARGA
# =========================================================

@export var charge_move_multiplier: float = 0.55

# Solo un knockback EFECTIVO superior a este valor
# interrumpe una carga pesada/cargada en progreso.
# El valor efectivo ya tiene en cuenta knockback_resistance.
@export_range(0.0, 5000.0, 1.0)
var charged_attack_interrupt_knockback_threshold: float = 150.0


# =========================================================
# DEBUG
# =========================================================

@export var show_attack_debug: bool = true


# =========================================================
# NODOS
# =========================================================

@onready var player_animated: AnimatedSprite2D = (
	$PlayerAnimated
)


# =========================================================
# HITBOX NORMAL
# =========================================================

@onready var normal_attack_area: Area2D = (
	$NormalAttackArea
)

@onready var normal_attack_collision: CollisionShape2D = (
	$NormalAttackArea/CollisionShape2D
)


# =========================================================
# HITBOX PESADO
# =========================================================

@onready var heavy_attack_area: Area2D = (
	$HeavyAttackArea
)

@onready var heavy_attack_collision: CollisionShape2D = (
	$HeavyAttackArea/CollisionShape2D
)


# =========================================================
# HITBOX CARGADO
# =========================================================

@onready var charged_attack_area: Area2D = (
	$ChargedAttackArea
)

@onready var charged_attack_collision: CollisionShape2D = (
	$ChargedAttackArea/CollisionShape2D
)


# =========================================================
# APUNTADO
# =========================================================

var aim_direction: Vector2 = Vector2.DOWN
var last_facing: String = "s"

var locked_attack_direction: Vector2 = Vector2.DOWN


# =========================================================
# ESTADO DEL ATAQUE
# =========================================================

var attack_action_time_left: float = 0.0
var attack_hit_delay_left: float = 0.0
var attack_hit_time_left: float = 0.0

var attack_hitbox_active: bool = false
var attack_has_resolved: bool = false

var current_attack_name: String = ""
var current_attack_damage: int = 0
var current_attack_distance: float = 0.0
var current_attack_hit_duration: float = 0.0
var current_attack_max_targets: int = 1

var current_attack_knockback_force: float = 0.0
var current_attack_hitstop_duration: float = 0.0

var current_attack_area: Area2D = null
var current_attack_collision: CollisionShape2D = null
var current_attack_debug: Polygon2D = null

var hit_targets: Array[Node2D] = []


# =========================================================
# HITSTOP
# =========================================================

var hitstop_running: bool = false


# =========================================================
# DEBUG HITBOXES
# =========================================================

var normal_attack_debug: Polygon2D = null
var heavy_attack_debug: Polygon2D = null
var charged_attack_debug: Polygon2D = null


# =========================================================
# ATAQUE PESADO / CARGA
# =========================================================

var is_charging_heavy: bool = false
var heavy_hold_time: float = 0.0
var charged_attack_ready: bool = false


# =========================================================
# DASH
# =========================================================

var is_dashing: bool = false

var dash_direction: Vector2 = Vector2.ZERO

var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0


# =========================================================
# DOBLE TOQUE
# =========================================================

var last_tap_action: String = ""
var double_tap_time_left: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready() -> void:

	_capture_base_stats()

	health = max_health
	stamina = max_stamina
	mana = max_mana

	add_to_group("player")

	standing_sprite_scale = player_animated.scale
	standing_sprite_position = player_animated.position
	_setup_action_animations()
	_create_crouch_debug_label()

	collision_layer = 1


	print(
		"PLAYER CREADO | HP: ",
		health,
		" / ",
		max_health
	)

	print(
		"STAMINA: ",
		stamina,
		" / ",
		max_stamina
	)


	# -----------------------------------------------------
	# CONFIGURAR HITBOXES
	# -----------------------------------------------------

	_configure_attack_area(
		normal_attack_area,
		normal_attack_collision
	)

	_configure_attack_area(
		heavy_attack_area,
		heavy_attack_collision
	)

	_configure_attack_area(
		charged_attack_area,
		charged_attack_collision
	)


	# -----------------------------------------------------
	# DEBUG HITBOXES
	# -----------------------------------------------------

	normal_attack_debug = _create_attack_debug(
		normal_attack_area,
		normal_attack_collision
	)

	heavy_attack_debug = _create_attack_debug(
		heavy_attack_area,
		heavy_attack_collision
	)

	charged_attack_debug = _create_attack_debug(
		charged_attack_area,
		charged_attack_collision
	)


	_update_aim_from_mouse()

	_play_idle()


# =========================================================
# CONFIGURAR HITBOX
# =========================================================

func _configure_attack_area(
	area: Area2D,
	collision: CollisionShape2D
) -> void:

	area.collision_layer = 0
	area.collision_mask = 2

	area.monitoring = false
	area.monitorable = false

	collision.disabled = true


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta: float) -> void:

	if is_dead:

		velocity = Vector2.ZERO

		return


	# -----------------------------------------------------
	# TIMERS
	# -----------------------------------------------------

	_update_attack_state(delta)

	_update_dash_timers(delta)

	_update_stamina_regen(delta)

	_update_mana_regen(delta)

	_update_crouch_state()


	# -----------------------------------------------------
	# PESADO / CARGADO
	#
	# Esto se procesa ANTES del retorno por knockback.
	# Así, si el golpe recibido es leve y no supera el
	# umbral de interrupción, una carga que ya estaba en
	# progreso puede seguir acumulando tiempo.
	# -----------------------------------------------------

	_update_heavy_attack_input(
		delta
	)


	# -----------------------------------------------------
	# KNOCKBACK RECIBIDO
	#
	# Mientras el empuje está activo, WASD/dash no pueden
	# reemplazar inmediatamente esa velocidad.
	# -----------------------------------------------------

	if received_knockback_velocity != Vector2.ZERO:

		_process_received_knockback(
			delta
		)

		return


	# -----------------------------------------------------
	# APUNTADO
	# -----------------------------------------------------

	if attack_action_time_left <= 0.0:

		_update_aim_from_mouse()


	# -----------------------------------------------------
	# DASH
	# -----------------------------------------------------

	_handle_dash_input()


	# -----------------------------------------------------
	# DASH ACTIVO
	# -----------------------------------------------------

	if is_dashing:

		is_sprinting = false
		_set_crouching(false)

		velocity = (
			dash_direction
			* dash_speed
		)

		_play_action_animation("dash")

		move_and_slide()

		return


	# -----------------------------------------------------
	# WASD
	# -----------------------------------------------------

	var input_x: float = Input.get_axis(
		"move_left",
		"move_right"
	)

	var input_y: float = Input.get_axis(
		"move_up",
		"move_down"
	)

	var movement_input: Vector2 = Vector2(
		input_x,
		input_y
	)


	# -----------------------------------------------------
	# MOVIMIENTO ISOMÉTRICO
	# -----------------------------------------------------

	var iso_direction: Vector2 = Vector2(
		movement_input.x
		- movement_input.y,

		(
			movement_input.x
			+ movement_input.y
		) * 0.5
	)


	if iso_direction != Vector2.ZERO:

		iso_direction = (
			iso_direction.normalized()
		)


	# -----------------------------------------------------
	# VELOCIDAD BASE
	# -----------------------------------------------------

	is_sprinting = false

	var current_move_speed: float = (
		crouch_speed
		if is_crouching
		else speed
	)


	# -----------------------------------------------------
	# SPRINT
	# -----------------------------------------------------

	var can_sprint: bool = (
		movement_input != Vector2.ZERO
		and
		Input.is_action_pressed("sprint")
		and
		stamina > 0.0
		and
		not is_crouching
		and
		not is_charging_heavy
		and
		attack_action_time_left <= 0.0
	)


	if can_sprint:

		is_sprinting = true

		current_move_speed = sprint_speed

		_drain_stamina(
			sprint_stamina_per_second
			* delta
		)


	# -----------------------------------------------------
	# MOVIMIENTO DURANTE CARGA
	# -----------------------------------------------------

	if is_charging_heavy:

		current_move_speed *= (
			charge_move_multiplier
		)


	velocity = (
		iso_direction
		* current_move_speed
	)


	# -----------------------------------------------------
	# ANIMACIONES
	# -----------------------------------------------------

	if attack_action_time_left > 0.0 or is_charging_heavy:

		_play_action_animation("attack")

	elif movement_input != Vector2.ZERO:

		_play_walk()

	else:

		_play_idle()


	# -----------------------------------------------------
	# ATAQUE NORMAL
	# -----------------------------------------------------

	if Input.is_action_just_pressed(
		"attack"
	):

		_try_normal_attack()


	move_and_slide()


# =========================================================
# SIGILO / AGACHARSE
# =========================================================

func _update_crouch_state() -> void:

	var wants_to_crouch: bool = (
		Input.is_action_pressed("crouch")
		and
		not is_dashing
		and
		received_knockback_velocity == Vector2.ZERO
	)


	_set_crouching(wants_to_crouch)


func _set_crouching(new_state: bool) -> void:

	if is_crouching == new_state:

		return


	is_crouching = new_state


	var has_crouch_sprites: bool = player_animated.sprite_frames.has_animation(
		&"crouch_s"
	)


	if is_crouching and not has_crouch_sprites:

		player_animated.scale = Vector2(
			standing_sprite_scale.x,
			standing_sprite_scale.y * crouch_visual_height
		)
		player_animated.position = (
			standing_sprite_position
			+ Vector2(0.0, crouch_visual_offset)
		)

	else:

		player_animated.scale = standing_sprite_scale
		player_animated.position = standing_sprite_position


	if is_crouching:

		_play_action_animation("crouch")


	if crouch_debug_label != null:

		crouch_debug_label.visible = is_crouching


func _create_crouch_debug_label() -> void:

	crouch_debug_label = Label.new()
	crouch_debug_label.name = "CrouchDebugLabel"
	crouch_debug_label.text = "SIGILO"
	crouch_debug_label.position = Vector2(-45.0, -125.0)
	crouch_debug_label.custom_minimum_size = Vector2(90.0, 24.0)
	crouch_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crouch_debug_label.add_theme_font_size_override("font_size", 13)
	crouch_debug_label.add_theme_color_override(
		"font_color",
		Color(0.35, 0.9, 1.0, 1.0)
	)
	crouch_debug_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)
	crouch_debug_label.add_theme_constant_override("outline_size", 4)
	crouch_debug_label.z_index = 200
	crouch_debug_label.visible = false
	add_child(crouch_debug_label)


func get_movement_noise_level() -> float:

	var noise_level: float = velocity.length()


	if is_crouching:

		noise_level *= crouch_noise_multiplier

	elif is_sprinting or is_dashing:

		noise_level *= sprint_noise_multiplier


	return noise_level


# =========================================================
# EQUIPAMIENTO
# =========================================================

func _capture_base_stats() -> void:

	effective_vitality = vitality
	effective_strength = strength
	effective_dexterity = dexterity
	effective_endurance = endurance
	effective_intelligence = intelligence
	effective_willpower = willpower

	base_speed = speed
	base_sprint_speed = sprint_speed
	base_crouch_speed = crouch_speed
	base_max_health = max_health
	base_max_stamina = max_stamina
	base_stamina_regen_rate = stamina_regen_rate
	base_sprint_stamina_per_second = sprint_stamina_per_second
	base_dash_stamina_cost = dash_stamina_cost
	base_max_mana = max_mana
	base_mana_regen_rate = mana_regen_rate
	base_magic_power = magic_power
	base_attack_damage = attack_damage
	base_heavy_attack_damage = heavy_attack_damage
	base_charged_attack_damage = charged_attack_damage
	base_attack_knockback_force = attack_knockback_force
	base_heavy_attack_knockback_force = heavy_attack_knockback_force
	base_charged_attack_knockback_force = charged_attack_knockback_force
	base_knockback_resistance = knockback_resistance
	base_attack_duration = attack_duration
	base_attack_cooldown = attack_cooldown
	base_heavy_attack_windup = heavy_attack_windup
	base_heavy_attack_hit_duration = heavy_attack_hit_duration
	base_heavy_attack_total_duration = heavy_attack_total_duration
	base_charged_attack_windup = charged_attack_windup
	base_charged_attack_hit_duration = charged_attack_hit_duration
	base_charged_attack_total_duration = charged_attack_total_duration


func get_inventory() -> PlayerInventory:

	return get_node_or_null("Inventory") as PlayerInventory


func apply_equipment_bonuses(bonuses: Dictionary) -> void:

	var missing_health: int = maxi(max_health - health, 0)
	var missing_stamina: float = maxf(max_stamina - stamina, 0.0)
	var missing_mana: float = maxf(max_mana - mana, 0.0)


	effective_vitality = vitality + int(bonuses.get("vitality", 0))
	effective_strength = strength + int(bonuses.get("strength", 0))
	effective_dexterity = dexterity + int(bonuses.get("dexterity", 0))
	effective_endurance = endurance + int(bonuses.get("endurance", 0))
	effective_intelligence = intelligence + int(bonuses.get("intelligence", 0))
	effective_willpower = willpower + int(bonuses.get("willpower", 0))


	var vitality_delta: int = effective_vitality - vitality
	var strength_delta: int = effective_strength - strength
	var dexterity_delta: int = effective_dexterity - dexterity
	var endurance_delta: int = effective_endurance - endurance
	var intelligence_delta: int = effective_intelligence - intelligence
	var willpower_delta: int = effective_willpower - willpower


	max_health = maxi(
		base_max_health + vitality_delta * 12,
		1
	)
	max_stamina = maxf(
		base_max_stamina + float(endurance_delta) * 10.0,
		1.0
	)
	max_mana = maxf(
		base_max_mana
		+ float(intelligence_delta) * 12.0
		+ float(willpower_delta) * 4.0,
		1.0
	)

	health = clampi(max_health - missing_health, 1, max_health)
	stamina = clampf(max_stamina - missing_stamina, 0.0, max_stamina)
	mana = clampf(max_mana - missing_mana, 0.0, max_mana)


	speed = base_speed + float(dexterity_delta) * 8.0
	sprint_speed = base_sprint_speed + float(dexterity_delta) * 10.0
	crouch_speed = base_crouch_speed + float(dexterity_delta) * 6.0

	stamina_regen_rate = (
		base_stamina_regen_rate
		+ float(endurance_delta) * 1.5
	)
	sprint_stamina_per_second = maxf(
		base_sprint_stamina_per_second
		- float(endurance_delta) * 0.75,
		5.0
	)
	dash_stamina_cost = maxf(
		base_dash_stamina_cost
		- float(endurance_delta),
		5.0
	)

	mana_regen_rate = (
		base_mana_regen_rate
		+ float(willpower_delta) * 1.25
		+ float(intelligence_delta) * 0.35
	)
	magic_power = base_magic_power * (
		1.0
		+ float(intelligence_delta) * 0.08
		+ float(willpower_delta) * 0.025
	)


	var physical_damage_multiplier: float = (
		1.0 + float(strength_delta) * 0.06
	)
	attack_damage = roundi(
		float(base_attack_damage) * physical_damage_multiplier
	)
	heavy_attack_damage = roundi(
		float(base_heavy_attack_damage) * physical_damage_multiplier
	)
	charged_attack_damage = roundi(
		float(base_charged_attack_damage) * physical_damage_multiplier
	)


	var physical_force_multiplier: float = (
		1.0 + float(strength_delta) * 0.05
	)
	heavy_attack_knockback_force = (
		base_heavy_attack_knockback_force
		* physical_force_multiplier
	)
	charged_attack_knockback_force = (
		base_charged_attack_knockback_force
		* physical_force_multiplier
	)
	attack_knockback_force = (
		base_attack_knockback_force
		* physical_force_multiplier
	)


	knockback_resistance = clampf(
		base_knockback_resistance
		+ float(vitality_delta) * 0.01
		+ float(endurance_delta) * 0.005,
		0.0,
		1.0
	)


	attack_speed_multiplier = (
		1.0 + float(dexterity_delta) * 0.035
	)
	attack_duration = base_attack_duration / attack_speed_multiplier
	attack_cooldown = base_attack_cooldown / attack_speed_multiplier
	heavy_attack_windup = base_heavy_attack_windup / attack_speed_multiplier
	heavy_attack_hit_duration = base_heavy_attack_hit_duration / attack_speed_multiplier
	heavy_attack_total_duration = base_heavy_attack_total_duration / attack_speed_multiplier
	charged_attack_windup = base_charged_attack_windup / attack_speed_multiplier
	charged_attack_hit_duration = base_charged_attack_hit_duration / attack_speed_multiplier
	charged_attack_total_duration = base_charged_attack_total_duration / attack_speed_multiplier


	print(
		"EQUIPO ACTUALIZADO | HP ",
		max_health,
		" | ST ",
		max_stamina,
		" | MP ",
		max_mana,
		" | DAÑO ",
		attack_damage,
		" | VEL ",
		speed
	)


# =========================================================
# MANÁ
# =========================================================

func _update_mana_regen(delta: float) -> void:

	if mana >= max_mana:

		mana = max_mana
		return


	mana = minf(
		max_mana,
		mana + mana_regen_rate * delta
	)


func spend_mana(amount: float) -> bool:

	if amount <= 0.0:

		return true


	if mana < amount:

		return false


	mana = maxf(mana - amount, 0.0)
	return true


# =========================================================
# STAMINA
# =========================================================

func _update_stamina_regen(
	delta: float
) -> void:

	if stamina_regen_delay_left > 0.0:

		stamina_regen_delay_left = maxf(
			stamina_regen_delay_left
			- delta,
			0.0
		)

		return


	if stamina >= max_stamina:

		stamina = max_stamina

		return


	if is_charging_heavy:

		return


	stamina = minf(
		max_stamina,
		stamina
		+ stamina_regen_rate
		* delta
	)


# =========================================================
# GASTAR STAMINA
# =========================================================

func _spend_stamina(
	amount: float
) -> bool:

	if amount <= 0.0:

		return true


	if stamina < amount:

		return false


	stamina = maxf(
		stamina - amount,
		0.0
	)


	stamina_regen_delay_left = (
		stamina_regen_delay
	)


	return true


# =========================================================
# DRENAR STAMINA
# =========================================================

func _drain_stamina(
	amount: float
) -> void:

	if amount <= 0.0:

		return


	stamina = maxf(
		stamina - amount,
		0.0
	)


	stamina_regen_delay_left = (
		stamina_regen_delay
	)


# =========================================================
# INPUT PESADO / CARGADO
# =========================================================

func _update_heavy_attack_input(
	delta: float
) -> void:

	# -----------------------------------------------------
	# PRESIONAR DERECHO
	# -----------------------------------------------------

	if Input.is_action_just_pressed(
		"heavy_attack"
	):

		_begin_heavy_charge()


	# -----------------------------------------------------
	# MANTENER DERECHO
	# -----------------------------------------------------

	if is_charging_heavy:

		stamina_regen_delay_left = (
			stamina_regen_delay
		)


		if Input.is_action_pressed(
			"heavy_attack"
		):

			heavy_hold_time += delta


			if (
				not charged_attack_ready
				and
				heavy_hold_time
				>= charged_attack_required_hold
			):

				charged_attack_ready = true


				player_animated.self_modulate = Color(
					1.0,
					0.55,
					0.15,
					1.0
				)


				print(
					"ATAQUE CARGADO LISTO"
				)


	# -----------------------------------------------------
	# SOLTAR DERECHO
	# -----------------------------------------------------

	if Input.is_action_just_released(
		"heavy_attack"
	):

		if is_charging_heavy:

			_release_heavy_attack()


# =========================================================
# COMENZAR CARGA
# =========================================================

func _begin_heavy_charge() -> void:

	if is_dead:

		return


	if is_dashing:

		return


	# Una carga que ya estaba activa puede continuar durante
	# un knockback leve, pero no permitimos iniciar una carga
	# nueva en mitad de un empuje.
	if received_knockback_velocity != Vector2.ZERO:

		return


	if attack_action_time_left > 0.0:

		return


	if stamina < heavy_attack_stamina_cost:

		print(
			"SIN STAMINA PARA ATAQUE PESADO"
		)

		return


	is_charging_heavy = true

	heavy_hold_time = 0.0

	charged_attack_ready = false


	player_animated.self_modulate = Color(
		1.0,
		0.85,
		0.55,
		1.0
	)


# =========================================================
# SOLTAR PESADO / CARGADO
# =========================================================

func _release_heavy_attack() -> void:

	var was_charged: bool = (
		charged_attack_ready
	)


	_clear_heavy_charge()


	# =====================================================
	# CARGADO
	# =====================================================

	if was_charged:

		if _spend_stamina(
			charged_attack_stamina_cost
		):

			_start_attack(
				"cargado",
				charged_attack_damage,
				charged_attack_distance,
				charged_attack_windup,
				charged_attack_hit_duration,
				charged_attack_total_duration,
				charged_attack_area,
				charged_attack_collision,
				charged_attack_debug,
				charged_attack_max_targets,
				charged_attack_knockback_force,
				charged_attack_hitstop_duration
			)


			print(
				"ATAQUE CARGADO | Daño: ",
				charged_attack_damage,
				" | Stamina: ",
				stamina
			)


			return


		print(
			"STAMINA INSUFICIENTE PARA CARGADO"
		)


	# =====================================================
	# PESADO
	# =====================================================

	if _spend_stamina(
		heavy_attack_stamina_cost
	):

		_start_attack(
			"pesado",
			heavy_attack_damage,
			heavy_attack_distance,
			heavy_attack_windup,
			heavy_attack_hit_duration,
			heavy_attack_total_duration,
			heavy_attack_area,
			heavy_attack_collision,
			heavy_attack_debug,
			heavy_attack_max_targets,
			heavy_attack_knockback_force,
			heavy_attack_hitstop_duration
		)


		print(
			"ATAQUE PESADO | Daño: ",
			heavy_attack_damage,
			" | Stamina: ",
			stamina
		)


	else:

		print(
			"SIN STAMINA PARA ATAQUE PESADO"
		)


# =========================================================
# CANCELAR CARGA
# =========================================================

func _cancel_heavy_charge() -> void:

	if not is_charging_heavy:

		return


	print(
		"CARGA CANCELADA"
	)


	_clear_heavy_charge()


# =========================================================
# LIMPIAR CARGA
# =========================================================

func _clear_heavy_charge() -> void:

	is_charging_heavy = false

	heavy_hold_time = 0.0

	charged_attack_ready = false


	player_animated.self_modulate = (
		Color.WHITE
	)


# =========================================================
# ATAQUE NORMAL
# =========================================================

func _try_normal_attack() -> void:

	if is_dead:

		return


	if is_dashing:

		return


	if is_charging_heavy:

		return


	if attack_action_time_left > 0.0:

		return


	_start_attack(
		"normal",
		attack_damage,
		attack_distance,
		0.0,
		attack_duration,
		attack_cooldown,
		normal_attack_area,
		normal_attack_collision,
		normal_attack_debug,
		1,
		attack_knockback_force,
		attack_hitstop_duration
	)


	print(
		"ATAQUE NORMAL | Daño: ",
		attack_damage
	)


# =========================================================
# COMENZAR CUALQUIER ATAQUE
# =========================================================

func _start_attack(
	attack_name: String,
	damage: int,
	distance: float,
	hit_delay: float,
	hit_duration: float,
	total_duration: float,
	area: Area2D,
	collision: CollisionShape2D,
	debug_polygon: Polygon2D,
	max_targets: int,
	knockback_strength: float,
	hitstop_duration: float
) -> void:

	current_attack_name = (
		attack_name
	)

	current_attack_damage = (
		damage
	)

	current_attack_distance = (
		distance
	)

	current_attack_hit_duration = (
		hit_duration
	)

	current_attack_max_targets = (
		max_targets
	)

	current_attack_knockback_force = (
		knockback_strength
	)

	current_attack_hitstop_duration = (
		hitstop_duration
	)

	current_attack_area = (
		area
	)

	current_attack_collision = (
		collision
	)

	current_attack_debug = (
		debug_polygon
	)


	# -----------------------------------------------------
	# BLOQUEAR DIRECCIÓN
	# -----------------------------------------------------

	_update_aim_from_mouse()


	locked_attack_direction = (
		_get_facing_direction()
	)


	# -----------------------------------------------------
	# POSICIONAR HITBOX
	# -----------------------------------------------------

	_update_current_attack_area()


	# -----------------------------------------------------
	# ESTADO
	# -----------------------------------------------------

	attack_action_time_left = (
		total_duration
	)

	attack_hit_delay_left = (
		hit_delay
	)

	attack_hit_time_left = 0.0

	attack_hitbox_active = false

	attack_has_resolved = false


	hit_targets.clear()


	# -----------------------------------------------------
	# ATAQUE SIN WINDUP
	# -----------------------------------------------------

	if hit_delay <= 0.0:

		_activate_attack_hitbox()


# =========================================================
# ACTUALIZAR ATAQUE
# =========================================================

func _update_attack_state(
	delta: float
) -> void:

	if attack_action_time_left <= 0.0:

		return


	# -----------------------------------------------------
	# DURACIÓN TOTAL
	# -----------------------------------------------------

	attack_action_time_left = maxf(
		attack_action_time_left
		- delta,
		0.0
	)


	# -----------------------------------------------------
	# WINDUP
	# -----------------------------------------------------

	if (
		attack_hit_delay_left > 0.0
		and
		not attack_hitbox_active
	):

		attack_hit_delay_left = maxf(
			attack_hit_delay_left
			- delta,
			0.0
		)


		if attack_hit_delay_left <= 0.0:

			_activate_attack_hitbox()


	# -----------------------------------------------------
	# HITBOX ACTIVA
	# -----------------------------------------------------

	if attack_hitbox_active:

		attack_hit_time_left = maxf(
			attack_hit_time_left
			- delta,
			0.0
		)


		if attack_hit_time_left <= 0.0:

			_disable_attack_hitbox()


	# -----------------------------------------------------
	# FIN
	# -----------------------------------------------------

	if attack_action_time_left <= 0.0:

		_finish_attack()


# =========================================================
# ACTIVAR HITBOX
# =========================================================

func _activate_attack_hitbox() -> void:

	if attack_hitbox_active:

		return


	attack_hitbox_active = true


	attack_hit_time_left = (
		current_attack_hit_duration
	)


	if (
		show_attack_debug
		and
		current_attack_debug != null
	):

		current_attack_debug.visible = true


	# El impacto ocurre acá.
	_resolve_attack_hits()


# =========================================================
# DESACTIVAR HITBOX
# =========================================================

func _disable_attack_hitbox() -> void:

	attack_hitbox_active = false

	attack_hit_time_left = 0.0


	if current_attack_debug != null:

		current_attack_debug.visible = false


# =========================================================
# FINALIZAR ATAQUE
# =========================================================

func _finish_attack() -> void:

	_disable_attack_hitbox()


	attack_action_time_left = 0.0

	attack_hit_delay_left = 0.0


	current_attack_name = ""

	current_attack_damage = 0

	current_attack_distance = 0.0

	current_attack_hit_duration = 0.0

	current_attack_max_targets = 1

	current_attack_knockback_force = 0.0

	current_attack_hitstop_duration = 0.0


	current_attack_area = null

	current_attack_collision = null

	current_attack_debug = null


	attack_has_resolved = false


# =========================================================
# POSICIONAR HITBOX
# =========================================================

func _update_current_attack_area() -> void:

	if current_attack_area == null:

		return


	current_attack_area.position = (
		locked_attack_direction
		* current_attack_distance
	)


	current_attack_area.rotation = (
		locked_attack_direction.angle()
	)


# =========================================================
# RESOLVER IMPACTOS
# =========================================================

func _resolve_attack_hits() -> void:

	if attack_has_resolved:

		return


	if current_attack_collision == null:

		return


	attack_has_resolved = true


	var candidates: Array[Node2D] = (
		_get_attack_candidates()
	)


	if candidates.is_empty():

		return


	candidates.sort_custom(
		_sort_targets_by_distance
	)


	var targets_hit: int = 0


	for target: Node2D in candidates:

		if targets_hit >= current_attack_max_targets:

			break


		if not is_instance_valid(
			target
		):

			continue


		if target in hit_targets:

			continue


		# -------------------------------------------------
		# BLOQUEO
		# -------------------------------------------------

		if not _has_clear_attack_line(
			target
		):

			continue


		# -------------------------------------------------
		# IMPACTO
		# -------------------------------------------------

		hit_targets.append(
			target
		)


		target.take_damage(
			current_attack_damage,
			global_position,
			current_attack_knockback_force
		)


		targets_hit += 1


		print(
			"GOLPE CONFIRMADO | ",
			current_attack_name,
			" | ",
			target.name,
			" | Daño: ",
			current_attack_damage,
			" | Knockback: ",
			current_attack_knockback_force
		)


	# -----------------------------------------------------
	# HITSTOP
	# -----------------------------------------------------

	# Aunque alcance a varios enemigos,
	# hacemos un solo hitstop por golpe.
	if targets_hit > 0:

		_apply_hitstop(
			current_attack_hitstop_duration
		)


# =========================================================
# HITSTOP
# =========================================================

func _apply_hitstop(
	duration: float
) -> void:

	if duration <= 0.0:

		return


	if hitstop_running:

		return


	hitstop_running = true


	var previous_time_scale: float = (
		Engine.time_scale
	)


	# Queda al 5% por unos milisegundos.
	Engine.time_scale = 0.05


	# Este timer ignora Engine.time_scale.
	await get_tree().create_timer(
		duration,
		true,
		false,
		true
	).timeout


	Engine.time_scale = (
		previous_time_scale
	)


	hitstop_running = false


# =========================================================
# OBTENER CANDIDATOS DE LA HITBOX
# =========================================================

func _get_attack_candidates() -> Array[Node2D]:

	var candidates: Array[Node2D] = []


	if current_attack_collision == null:

		return candidates


	if current_attack_collision.shape == null:

		return candidates


	var query := (
		PhysicsShapeQueryParameters2D.new()
	)


	query.shape = (
		current_attack_collision.shape
	)


	query.transform = (
		current_attack_collision.global_transform
	)


	# Enemigos = Layer 2.
	query.collision_mask = 2

	query.collide_with_bodies = true
	query.collide_with_areas = false


	var excluded: Array[RID] = [
		get_rid()
	]


	query.exclude = (
		excluded
	)


	var space_state := (
		get_world_2d().direct_space_state
	)


	var results: Array[Dictionary] = (
		space_state.intersect_shape(
			query,
			32
		)
	)


	for result: Dictionary in results:

		var collider_value: Variant = (
			result.get(
				"collider"
			)
		)


		if not collider_value is Node2D:

			continue


		var body: Node2D = (
			collider_value as Node2D
		)


		if not body.has_method(
			"take_damage"
		):

			continue


		if candidates.has(
			body
		):

			continue


		candidates.append(
			body
		)


	return candidates


# =========================================================
# ORDENAR OBJETIVOS
# =========================================================

func _sort_targets_by_distance(
	a: Node2D,
	b: Node2D
) -> bool:

	var distance_a: float = (
		global_position.distance_squared_to(
			a.global_position
		)
	)


	var distance_b: float = (
		global_position.distance_squared_to(
			b.global_position
		)
	)


	return (
		distance_a < distance_b
	)


# =========================================================
# ¿HAY ALGO DELANTE?
# =========================================================

func _has_clear_attack_line(
	target: Node2D
) -> bool:

	var ray_query := (
		PhysicsRayQueryParameters2D.create(
			global_position,
			target.global_position
		)
	)


	# Layer 1 = escenario.
	# Layer 2 = enemigos.
	ray_query.collision_mask = 3

	ray_query.collide_with_bodies = true
	ray_query.collide_with_areas = false


	var excluded: Array[RID] = [
		get_rid()
	]


	ray_query.exclude = (
		excluded
	)


	var space_state := (
		get_world_2d().direct_space_state
	)


	var result: Dictionary = (
		space_state.intersect_ray(
			ray_query
		)
	)


	if result.is_empty():

		return true


	var collider_value: Variant = (
		result.get(
			"collider"
		)
	)


	return (
		collider_value == target
	)


# =========================================================
# DASH INPUT
# =========================================================

func _handle_dash_input() -> void:

	if Input.is_action_just_pressed(
		"move_left"
	):

		_register_direction_tap(
			"move_left",
			Vector2(-1.0, 0.0)
		)


	elif Input.is_action_just_pressed(
		"move_right"
	):

		_register_direction_tap(
			"move_right",
			Vector2(1.0, 0.0)
		)


	elif Input.is_action_just_pressed(
		"move_up"
	):

		_register_direction_tap(
			"move_up",
			Vector2(0.0, -1.0)
		)


	elif Input.is_action_just_pressed(
		"move_down"
	):

		_register_direction_tap(
			"move_down",
			Vector2(0.0, 1.0)
		)


# =========================================================
# DOBLE TOQUE
# =========================================================

func _register_direction_tap(
	action_name: String,
	input_direction: Vector2
) -> void:

	if (
		last_tap_action == action_name
		and
		double_tap_time_left > 0.0
	):

		last_tap_action = ""

		double_tap_time_left = 0.0


		if (
			dash_cooldown_left <= 0.0
			and
			not is_dashing
		):

			_start_dash(
				input_direction,
				action_name
			)


		return


	last_tap_action = (
		action_name
	)


	double_tap_time_left = (
		dash_double_tap_window
	)


# =========================================================
# COMENZAR DASH
# =========================================================

func _start_dash(
	input_direction: Vector2,
	action_name: String
) -> void:

	if attack_action_time_left > 0.0:

		return


	if stamina < dash_stamina_cost:

		print(
			"SIN STAMINA PARA DASH"
		)

		return


	if is_charging_heavy:

		_cancel_heavy_charge()


	if not _spend_stamina(
		dash_stamina_cost
	):

		return


	var iso_dash_direction: Vector2 = Vector2(
		input_direction.x
		- input_direction.y,

		(
			input_direction.x
			+ input_direction.y
		) * 0.5
	)


	if iso_dash_direction == Vector2.ZERO:

		return


	iso_dash_direction = (
		iso_dash_direction.normalized()
	)


	is_dashing = true


	dash_direction = (
		iso_dash_direction
	)


	_update_facing_from_aim(dash_direction)


	dash_time_left = (
		dash_duration
	)


	dash_cooldown_left = (
		dash_cooldown
	)


	print(
		"DASH: ",
		action_name,
		" | STAMINA: ",
		stamina
	)


# =========================================================
# TIMERS DASH
# =========================================================

func _update_dash_timers(
	delta: float
) -> void:

	if dash_cooldown_left > 0.0:

		dash_cooldown_left = maxf(
			dash_cooldown_left
			- delta,
			0.0
		)


	if double_tap_time_left > 0.0:

		double_tap_time_left = maxf(
			double_tap_time_left
			- delta,
			0.0
		)


		if double_tap_time_left <= 0.0:

			last_tap_action = ""


	if is_dashing:

		dash_time_left = maxf(
			dash_time_left
			- delta,
			0.0
		)


		if dash_time_left <= 0.0:

			_finish_dash()


# =========================================================
# TERMINAR DASH
# =========================================================

func _finish_dash() -> void:

	is_dashing = false

	dash_time_left = 0.0

	dash_direction = Vector2.ZERO

	velocity = Vector2.ZERO


# =========================================================
# APUNTADO CON MOUSE
# =========================================================

func _update_aim_from_mouse() -> void:

	var mouse_position: Vector2 = (
		get_global_mouse_position()
	)


	var direction_to_mouse: Vector2 = (
		mouse_position
		- global_position
	)


	if direction_to_mouse.length_squared() < 4.0:

		return


	aim_direction = (
		direction_to_mouse.normalized()
	)


	_update_facing_from_aim(
		aim_direction
	)


# =========================================================
# MOUSE → 8 DIRECCIONES
# =========================================================

func _update_facing_from_aim(
	direction: Vector2
) -> void:

	var angle_degrees: float = (
		rad_to_deg(
			direction.angle()
		)
	)


	if (
		angle_degrees >= -22.5
		and
		angle_degrees < 22.5
	):

		last_facing = "e"


	elif (
		angle_degrees >= 22.5
		and
		angle_degrees < 67.5
	):

		last_facing = "se"


	elif (
		angle_degrees >= 67.5
		and
		angle_degrees < 112.5
	):

		last_facing = "s"


	elif (
		angle_degrees >= 112.5
		and
		angle_degrees < 157.5
	):

		last_facing = "sw"


	elif (
		angle_degrees >= 157.5
		or
		angle_degrees < -157.5
	):

		last_facing = "w"


	elif (
		angle_degrees >= -157.5
		and
		angle_degrees < -112.5
	):

		last_facing = "nw"


	elif (
		angle_degrees >= -112.5
		and
		angle_degrees < -67.5
	):

		last_facing = "n"


	else:

		last_facing = "ne"


# =========================================================
# FACING → VECTOR
# =========================================================

func _get_facing_direction() -> Vector2:

	match last_facing:

		"n":
			return Vector2(0.0, -1.0)

		"ne":
			return Vector2(
				1.0,
				-1.0
			).normalized()

		"e":
			return Vector2(1.0, 0.0)

		"se":
			return Vector2(
				1.0,
				1.0
			).normalized()

		"s":
			return Vector2(0.0, 1.0)

		"sw":
			return Vector2(
				-1.0,
				1.0
			).normalized()

		"w":
			return Vector2(-1.0, 0.0)

		"nw":
			return Vector2(
				-1.0,
				-1.0
			).normalized()


	return Vector2.DOWN


# =========================================================
# IDLE
# =========================================================

func _play_idle() -> void:

	if is_crouching:

		_play_action_animation("crouch")
		return

	var animation_name: String = (
		"idle_" + last_facing
	)


	if player_animated.sprite_frames.has_animation(
		animation_name
	):

		if player_animated.animation != animation_name:

			player_animated.play(
				animation_name
			)


# =========================================================
# WALK
# =========================================================

func _play_walk() -> void:

	var animation_prefix: String = (
		"crouch"
		if is_crouching
		else "walk"
	)

	var animation_name: String = (
		animation_prefix
		+ "_"
		+ _get_cardinal_animation_facing()
	)


	if player_animated.sprite_frames.has_animation(
		animation_name
	):

		if player_animated.animation != animation_name:

			player_animated.play(
				animation_name
			)


	else:

		var idle_name: String = (
			"idle_" + last_facing
		)


		if player_animated.sprite_frames.has_animation(
			idle_name
		):

			if player_animated.animation != idle_name:

				player_animated.play(
					idle_name
				)


func _setup_action_animations() -> void:

	var frames: SpriteFrames = player_animated.sprite_frames


	SpriteSheetAnimationBuilder.add_cardinal_sheet(
		frames,
		PLAYER_WALK_SHEET,
		"walk",
		9.0,
		true
	)
	SpriteSheetAnimationBuilder.add_cardinal_sheet(
		frames,
		PLAYER_CROUCH_SHEET,
		"crouch",
		7.0,
		true
	)
	SpriteSheetAnimationBuilder.add_cardinal_sheet(
		frames,
		PLAYER_ATTACK_SHEET,
		"attack",
		28.0,
		false
	)
	SpriteSheetAnimationBuilder.add_cardinal_sheet(
		frames,
		PLAYER_DASH_SHEET,
		"dash",
		28.0,
		false
	)


func _play_action_animation(animation_prefix: String) -> void:

	var animation_name: StringName = StringName(
		animation_prefix
		+ "_"
		+ _get_cardinal_animation_facing()
	)


	if not player_animated.sprite_frames.has_animation(animation_name):

		return


	if player_animated.animation != animation_name:

		player_animated.play(animation_name)


func _get_cardinal_animation_facing() -> String:

	match last_facing:

		"n":
			return "n"

		"ne", "e", "se":
			return "e"

		"s":
			return "s"

		"sw", "w", "nw":
			return "w"


	return "s"


# =========================================================
# RECIBIR DAÑO
# =========================================================

func take_damage(
	amount: int,
	attacker_position: Vector2 = Vector2.ZERO,
	received_knockback: float = 0.0
) -> void:

	if is_dead:

		return


	health -= amount


	health = maxi(
		health,
		0
	)


	print(
		"=============================="
	)

	print(
		"PLAYER RECIBE ",
		amount,
		" DE DAÑO"
	)

	print(
		"HP PLAYER: ",
		health,
		" / ",
		max_health
	)

	print(
		"KNOCKBACK RECIBIDO: ",
		received_knockback
	)

	print(
		"=============================="
	)


	if health <= 0:

		_die()

		return


	# Un golpe enemigo interrumpe el dash para que el
	# knockback no sea anulado por su velocidad.
	if is_dashing:

		is_dashing = false

		dash_time_left = 0.0

		dash_direction = Vector2.ZERO


	is_sprinting = false


	# -----------------------------------------------------
	# INTERRUPCIÓN DE CARGA POR KNOCKBACK
	#
	# No todo golpe corta una carga.
	# Solo la corta si el knockback EFECTIVO, luego de aplicar
	# la resistencia del Player, supera el umbral configurable.
	# -----------------------------------------------------

	var effective_knockback: float = (
		_get_effective_received_knockback(
			received_knockback
		)
	)


	if (
		is_charging_heavy
		and
		effective_knockback
		> charged_attack_interrupt_knockback_threshold
	):

		print(
			"CARGA INTERRUMPIDA POR KNOCKBACK | Fuerza efectiva: ",
			effective_knockback,
			" | Umbral: ",
			charged_attack_interrupt_knockback_threshold
		)

		_cancel_heavy_charge()


	_apply_received_knockback(
		attacker_position,
		received_knockback
	)


	_flash_player_damage()


# =========================================================
# OBTENER KNOCKBACK EFECTIVO
# =========================================================

func _get_effective_received_knockback(
	received_knockback: float
) -> float:

	if received_knockback <= 0.0:

		return 0.0


	var resistance: float = clampf(
		knockback_resistance,
		0.0,
		1.0
	)


	return (
		received_knockback
		* (
			1.0
			- resistance
		)
	)


# =========================================================
# APLICAR KNOCKBACK RECIBIDO
# =========================================================

func _apply_received_knockback(
	attacker_position: Vector2,
	received_knockback: float
) -> void:

	if received_knockback <= 0.0:

		return


	var direction: Vector2 = (
		global_position
		- attacker_position
	)


	if direction.length_squared() < 0.001:

		direction = Vector2.DOWN

	else:

		direction = direction.normalized()


	var final_knockback: float = (
		_get_effective_received_knockback(
			received_knockback
		)
	)


	if final_knockback <= 0.0:

		return


	received_knockback_velocity = (
		direction
		* final_knockback
	)


# =========================================================
# PROCESAR KNOCKBACK RECIBIDO
# =========================================================

func _process_received_knockback(
	delta: float
) -> void:

	is_sprinting = false


	velocity = (
		received_knockback_velocity
	)


	move_and_slide()


	received_knockback_velocity = (
		received_knockback_velocity.move_toward(
			Vector2.ZERO,
			received_knockback_friction
			* delta
		)
	)


	if received_knockback_velocity.length() < 1.0:

		received_knockback_velocity = Vector2.ZERO

		velocity = Vector2.ZERO


# =========================================================
# ¿VIVO?
# =========================================================

func is_alive() -> bool:

	return not is_dead


# =========================================================
# FLASH PLAYER
# =========================================================

func _flash_player_damage() -> void:

	player_animated.modulate = Color(
		1.0,
		0.20,
		0.20,
		1.0
	)


	var tween: Tween = (
		create_tween()
	)


	tween.tween_property(
		player_animated,
		"modulate",
		Color.WHITE,
		0.15
	)


# =========================================================
# MUERTE
# =========================================================

func _die() -> void:

	if is_dead:

		return


	is_dead = true

	is_dashing = false

	is_sprinting = false


	if is_charging_heavy:

		_clear_heavy_charge()


	print(
		"=============================="
	)

	print(
		"PLAYER DERROTADO"
	)

	print(
		"=============================="
	)


	velocity = Vector2.ZERO

	dash_direction = Vector2.ZERO

	received_knockback_velocity = Vector2.ZERO


	attack_action_time_left = 0.0


	_disable_attack_hitbox()

	_hide_all_attack_debugs()


	player_animated.self_modulate = (
		Color.WHITE
	)


	player_animated.modulate = Color(
		0.35,
		0.35,
		0.35,
		1.0
	)


# =========================================================
# CREAR DEBUG SEGÚN LA HITBOX
# =========================================================

func _create_attack_debug(
	area: Area2D,
	collision: CollisionShape2D
) -> Polygon2D:

	var debug_polygon := (
		Polygon2D.new()
	)


	debug_polygon.name = (
		"AttackDebug"
	)


	if collision.shape is RectangleShape2D:

		var rectangle: RectangleShape2D = (
			collision.shape
			as RectangleShape2D
		)


		var half_size: Vector2 = (
			rectangle.size
			* 0.5
		)


		debug_polygon.polygon = (
			PackedVector2Array([
				Vector2(
					-half_size.x,
					-half_size.y
				),

				Vector2(
					half_size.x,
					-half_size.y
				),

				Vector2(
					half_size.x,
					half_size.y
				),

				Vector2(
					-half_size.x,
					half_size.y
				)
			])
		)


	else:

		debug_polygon.polygon = (
			PackedVector2Array([
				Vector2(-35.0, -22.5),
				Vector2(35.0, -22.5),
				Vector2(35.0, 22.5),
				Vector2(-35.0, 22.5)
			])
		)


	debug_polygon.color = Color(
		1.0,
		0.0,
		0.0,
		0.40
	)


	debug_polygon.visible = false


	area.add_child(
		debug_polygon
	)


	return debug_polygon


# =========================================================
# OCULTAR DEBUGS
# =========================================================

func _hide_all_attack_debugs() -> void:

	if normal_attack_debug != null:

		normal_attack_debug.visible = false


	if heavy_attack_debug != null:

		heavy_attack_debug.visible = false


	if charged_attack_debug != null:

		charged_attack_debug.visible = false
