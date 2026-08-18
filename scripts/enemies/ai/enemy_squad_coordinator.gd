class_name EnemySquadCoordinator
extends RefCounted


func get_assignment(
	subject: CharacterBody2D,
	enemies: Array[Node],
	target: CharacterBody2D,
	enemy_data: EnemyData,
	profile: EnemyAIProfile
) -> Dictionary:

	var result: Dictionary = {
		"role": &"support",
		"position": target.global_position,
		"can_attack": false
	}


	var ranked_enemies: Array[Node] = _rank_enemies(
		enemies,
		target
	)

	var my_index: int = ranked_enemies.find(subject)


	if my_index < 0:

		return result


	var pressure_count: int = mini(
		enemy_data.max_simultaneous_attackers,
		ranked_enemies.size()
	)


	if my_index < pressure_count:

		result["role"] = &"pressure"
		result["can_attack"] = true
		result["position"] = _ring_position(
			target.global_position,
			enemy_data.attack_slot_radius,
			my_index,
			maxi(pressure_count, 1),
			0.0
		)
		return result


	var tactical_index: int = my_index - pressure_count
	var flank_count: int = mini(
		2,
		maxi(ranked_enemies.size() - pressure_count, 0)
	)


	if tactical_index < flank_count:

		result["role"] = &"flank"


		var target_to_subject: Vector2 = (
			subject.global_position
			- target.global_position
		)


		if target_to_subject.length_squared() < 0.001:

			target_to_subject = Vector2.DOWN


		var side: float = -1.0 if tactical_index == 0 else 1.0
		var flank_direction: Vector2 = (
			target_to_subject.normalized().rotated(
				side * PI * 0.5
			)
		)


		result["position"] = (
			target.global_position
			+ flank_direction * profile.flank_radius
		)
		return result


	var support_index: int = tactical_index - flank_count
	var support_count: int = maxi(
		ranked_enemies.size() - pressure_count - flank_count,
		1
	)


	result["position"] = _ring_position(
		target.global_position,
		profile.support_radius,
		support_index,
		support_count,
		PI / float(support_count)
	)


	return result


func _rank_enemies(
	enemies: Array[Node],
	target: CharacterBody2D
) -> Array[Node]:

	var ranked: Array[Node] = enemies.duplicate()


	for left: int in range(ranked.size()):

		var best_index: int = left
		var best_score: float = _readiness_score(
			ranked[left],
			target
		)


		for right: int in range(left + 1, ranked.size()):

			var candidate_score: float = _readiness_score(
				ranked[right],
				target
			)


			if candidate_score > best_score:

				best_index = right
				best_score = candidate_score


		if best_index != left:

			var swap: Node = ranked[left]
			ranked[left] = ranked[best_index]
			ranked[best_index] = swap


	return ranked


func _readiness_score(
	enemy: Node,
	target: CharacterBody2D
) -> float:

	if not enemy is Node2D:

		return -INF


	var enemy_2d: Node2D = enemy as Node2D
	var distance: float = enemy_2d.global_position.distance_to(
		target.global_position
	)
	var distance_score: float = 1.0 / maxf(distance, 1.0)

	var health_ratio: float = 1.0
	var stamina_ratio: float = 1.0
	var combat_readiness: float = 0.0
	var data_variant: Variant = enemy.get("enemy_data")


	if data_variant is EnemyData:

		var data: EnemyData = data_variant as EnemyData
		health_ratio = float(enemy.get("health")) / maxf(
			float(data.max_health),
			1.0
		)
		stamina_ratio = float(enemy.get("stamina")) / maxf(
			data.max_stamina,
			1.0
		)


	var current_attack_variant: Variant = enemy.get("current_attack")


	if current_attack_variant is AttackData:

		combat_readiness += 2.0

	else:

		var cooldown_left: float = float(
			enemy.get("attack_cooldown_left")
		)


		combat_readiness -= minf(cooldown_left, 2.0) * 0.8


	return (
		distance_score * 90.0
		+ health_ratio * 0.35
		+ stamina_ratio * 0.25
		+ combat_readiness
		- float(enemy.get_instance_id() % 97) * 0.00001
	)


func _ring_position(
	center: Vector2,
	radius: float,
	index: int,
	count: int,
	angle_offset: float
) -> Vector2:

	var angle: float = (
		angle_offset
		+ TAU * float(index) / float(maxi(count, 1))
	)


	return center + Vector2.RIGHT.rotated(angle) * radius
