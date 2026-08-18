class_name CorpseLoot
extends Area2D


const LOOT_WINDOW := preload("res://scenes/ui/loot_window_ui.tscn")

@onready var corpse_sprite: AnimatedSprite2D = $CorpseSprite
@onready var sparkle: Node2D = $LootSparkle
@onready var sparkle_core: Polygon2D = $LootSparkle/Core
@onready var prompt: Label = $Prompt

var loot_stacks: Array[Dictionary] = []
var was_opened := false
var player: Node2D


func _ready() -> void:
	add_to_group("loot_corpses")
	player = get_tree().get_first_node_in_group("player") as Node2D
	refresh_loot_state()


func configure(source: AnimatedSprite2D, stacks: Array[Dictionary]) -> void:
	loot_stacks = stacks
	if source != null:
		corpse_sprite.sprite_frames = source.sprite_frames
		corpse_sprite.animation = source.animation
		corpse_sprite.frame = source.frame
		corpse_sprite.flip_h = source.flip_h
		corpse_sprite.scale = source.scale
	refresh_loot_state()


func _process(delta: float) -> void:
	sparkle.rotation += delta * 1.5
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	var nearby := is_instance_valid(player) and global_position.distance_to(player.global_position) <= 105.0
	prompt.visible = nearby and not loot_stacks.is_empty()
	if nearby and not loot_stacks.is_empty() and Input.is_action_just_pressed("interact"):
		var window := LOOT_WINDOW.instantiate() as LootWindowUI
		get_tree().current_scene.add_child(window)
		window.call_deferred("open_for", self)


func mark_opened() -> void:
	was_opened = true
	refresh_loot_state()


func refresh_loot_state() -> void:
	if not is_node_ready():
		return
	sparkle.visible = not loot_stacks.is_empty()
	prompt.visible = false
	if was_opened:
		sparkle_core.color = Color(0.95, 0.48, 0.12, 0.95)
	else:
		sparkle_core.color = Color(0.25, 1.0, 0.42, 0.98)
