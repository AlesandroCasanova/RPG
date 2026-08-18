class_name EnemyPerception
extends RefCounted


var owner_enemy: CharacterBody2D = null
var target: CharacterBody2D = null
var profile: EnemyAIProfile = null

var has_line_of_sight: bool = false
var heard_target: bool = false
var is_aware: bool = false
var last_known_position: Vector2 = Vector2.ZERO
var memory_time_left: float = 0.0


func configure(
	enemy: CharacterBody2D,
	new_target: CharacterBody2D,
	ai_profile: EnemyAIProfile
) -> void:

	owner_enemy = enemy
	target = new_target
	profile = ai_profile


func set_target(new_target: CharacterBody2D) -> void:

	target = new_target


func notice_position(world_position: Vector2) -> void:

	is_aware = true
	last_known_position = world_position
	memory_time_left = profile.memory_duration


func update(delta: float, facing_direction: Vector2) -> void:

	has_line_of_sight = false
	heard_target = false


	if not is_instance_valid(owner_enemy):

		is_aware = false
		return


	if not is_instance_valid(target):

		_forget_over_time(delta)
		return


	var distance_to_target: float = (
		owner_enemy.global_position.distance_to(
			target.global_position
		)
	)


	if distance_to_target <= profile.vision_range:

		has_line_of_sight = (
			_is_inside_view_cone(facing_direction)
			and
			_has_clear_path_to_target()
		)


	if distance_to_target <= profile.hearing_range:

		var movement_noise: float = target.velocity.length()


		if target.has_method("get_movement_noise_level"):

			movement_noise = float(
				target.get_movement_noise_level()
			)


		heard_target = (
			movement_noise
			>= profile.hearing_velocity_threshold
		)


	if has_line_of_sight or heard_target:

		is_aware = true
		last_known_position = target.global_position
		memory_time_left = profile.memory_duration
		return


	_forget_over_time(delta)


func _forget_over_time(delta: float) -> void:

	if memory_time_left > 0.0:

		memory_time_left = maxf(
			memory_time_left - delta,
			0.0
		)


	is_aware = memory_time_left > 0.0


func _is_inside_view_cone(facing_direction: Vector2) -> bool:

	if profile.vision_angle_degrees >= 359.0:

		return true


	var direction_to_target: Vector2 = (
		target.global_position
		- owner_enemy.global_position
	)


	if direction_to_target.length_squared() < 0.001:

		return true


	if facing_direction.length_squared() < 0.001:

		facing_direction = Vector2.DOWN


	var half_angle_radians: float = deg_to_rad(
		profile.vision_angle_degrees * 0.5
	)


	return absf(
		facing_direction.normalized().angle_to(
			direction_to_target.normalized()
		)
	) <= half_angle_radians


func _has_clear_path_to_target() -> bool:

	var query: PhysicsRayQueryParameters2D = (
		PhysicsRayQueryParameters2D.create(
			owner_enemy.global_position,
			target.global_position,
			profile.sight_collision_mask,
			[
				owner_enemy.get_rid()
			]
		)
	)


	query.collide_with_areas = true
	query.collide_with_bodies = true


	var hit: Dictionary = (
		owner_enemy.get_world_2d()
		.direct_space_state
		.intersect_ray(query)
	)


	if hit.is_empty():

		return true


	var collider: Variant = hit.get("collider")


	if collider == target:

		return true


	if collider is Node:

		var node: Node = collider as Node


		while node != null:

			if node == target or node.is_in_group("player"):

				return true


			node = node.get_parent()


	return false
