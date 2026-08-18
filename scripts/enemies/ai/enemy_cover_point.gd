class_name EnemyCoverPoint
extends Marker2D


@export_range(0.0, 2.0, 0.05) var cover_quality: float = 1.0
@export var designer_confirmed_cover: bool = true
@export_range(8.0, 200.0, 1.0) var occupancy_radius: float = 42.0

var _reserved_by: WeakRef
var _reservation_time_left := 0.0


func _ready() -> void:
	add_to_group("ai_cover_points")


func _physics_process(delta: float) -> void:
	_reservation_time_left = maxf(_reservation_time_left - delta, 0.0)
	if _reservation_time_left <= 0.0:
		_reserved_by = null


func is_available_for(enemy: Node2D) -> bool:
	if _reserved_by == null:
		return true
	var owner := _reserved_by.get_ref() as Node2D
	return owner == null or owner == enemy


func reserve(enemy: Node2D, duration: float) -> bool:
	if not is_available_for(enemy):
		return false
	_reserved_by = weakref(enemy)
	_reservation_time_left = maxf(duration, 0.1)
	return true


func release(enemy: Node2D) -> void:
	if _reserved_by == null:
		return
	if _reserved_by.get_ref() == enemy:
		_reserved_by = null
		_reservation_time_left = 0.0
