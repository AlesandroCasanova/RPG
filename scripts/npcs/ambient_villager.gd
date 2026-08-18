extends Node2D

@export var patrol_offset := Vector2(90, 0)
@export var patrol_seconds := 7.0
var origin := Vector2.ZERO
var elapsed := 0.0

func _ready() -> void:
	origin = position

func _process(delta: float) -> void:
	elapsed += delta
	var phase := (sin(elapsed * TAU / patrol_seconds) + 1.0) * 0.5
	position = origin + patrol_offset * phase
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		sprite.flip_h = cos(elapsed * TAU / patrol_seconds) < 0.0
