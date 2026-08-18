class_name EnemyTacticalPositioning
extends RefCounted


var _random := RandomNumberGenerator.new()


func configure(profile: EnemyAIProfile, seed_offset: int = 0) -> void:
	if profile.deterministic_seed > 0:
		_random.seed = profile.deterministic_seed + seed_offset * 104729
	else:
		_random.randomize()


func find_best_cover(
	enemy: CharacterBody2D,
	threat_position: Vector2,
	profile: EnemyAIProfile
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for node: Node in enemy.get_tree().get_nodes_in_group("ai_cover_points"):
		var point := node as EnemyCoverPoint
		if point == null or not point.is_available_for(enemy):
			continue
		if _is_physically_occupied(enemy, point):
			continue
		var travel_distance := enemy.global_position.distance_to(point.global_position)
		if travel_distance > profile.cover_search_radius:
			continue
		var threat_distance := threat_position.distance_to(point.global_position)
		var physical_cover := _is_sight_blocked(enemy, point.global_position, threat_position, profile.sight_collision_mask)
		if not physical_cover and not point.designer_confirmed_cover:
			continue
		var distance_score := 1.0 - travel_distance / maxf(profile.cover_search_radius, 1.0)
		var separation_score := clampf(threat_distance / maxf(profile.preferred_distance * 2.0, 1.0), 0.0, 1.0)
		var score := point.cover_quality * 1.5 + distance_score + separation_score
		if physical_cover:
			score += 0.75
		candidates.append({"point": point, "position": point.global_position, "score": score})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_score := float(a.get("score", -INF))
			var b_score := float(b.get("score", -INF))
			if is_equal_approx(a_score, b_score):
				var a_point := a.get("point") as Node
				var b_point := b.get("point") as Node
				return a_point.get_instance_id() < b_point.get_instance_id()
			return a_score > b_score
	)
	var selected_index := 0
	# Un táctico medio conoce coberturas válidas, pero a veces escoge la segunda
	# o tercera mejor. Nunca elige un punto inválido para simular torpeza.
	if candidates.size() > 1 and _random.randf() < profile.get_mistake_chance() * 0.9:
		selected_index = _random.randi_range(1, mini(candidates.size() - 1, 2))
	return candidates[selected_index].duplicate()


func get_circle_position(
	enemy: CharacterBody2D,
	target_position: Vector2,
	profile: EnemyAIProfile
) -> Vector2:
	var radial := enemy.global_position - target_position
	if radial.length_squared() < 0.001:
		radial = Vector2.DOWN
	var side := -1.0 if enemy.get_instance_id() % 2 == 0 else 1.0
	var tangent := radial.normalized().rotated(side * PI * 0.5)
	var desired_radial := radial.normalized() * profile.circle_radius
	return target_position + desired_radial + tangent * profile.circle_radius * 0.55


func get_dodge_direction(
	enemy: CharacterBody2D,
	threat_position: Vector2,
	threat_facing: Vector2
) -> Vector2:
	var away := enemy.global_position - threat_position
	if away.length_squared() < 0.001:
		away = Vector2.DOWN
	var facing := threat_facing.normalized() if threat_facing.length_squared() > 0.001 else -away.normalized()
	var side := -1.0 if enemy.get_instance_id() % 2 == 0 else 1.0
	var lateral := facing.rotated(side * PI * 0.5)
	return (lateral * 0.78 + away.normalized() * 0.62).normalized()


func _is_sight_blocked(
	enemy: CharacterBody2D,
	from: Vector2,
	to: Vector2,
	mask: int
) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, mask, [enemy.get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := enemy.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider := hit.get("collider") as Node
	while collider != null:
		if collider.is_in_group("player"):
			return false
		collider = collider.get_parent()
	return true


func _is_physically_occupied(enemy: CharacterBody2D, point: EnemyCoverPoint) -> bool:
	for node: Node in enemy.get_tree().get_nodes_in_group("enemies"):
		if node == enemy or not node is Node2D:
			continue
		if node.has_method("is_enemy_alive") and not bool(node.call("is_enemy_alive")):
			continue
		if (node as Node2D).global_position.distance_to(point.global_position) <= point.occupancy_radius:
			return true
	return false
