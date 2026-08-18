class_name EnemySquadCoordinator
extends RefCounted


static var _cache_frame: int = -1
static var _active_enemies_cache: Dictionary = {}
static var _component_cache: Dictionary = {}
static var _ranking_cache: Dictionary = {}


func get_assignment(
	subject: CharacterBody2D,
	enemies: Array[Node],
	target_position: Vector2,
	subject_data: EnemyData,
	subject_profile: EnemyAIProfile
) -> Dictionary:
	var result := {
		"role": &"waiting",
		"position": target_position,
		"can_attack": false
	}
	var squad := _filter_squad(enemies, subject, subject_data)
	# Cada miembro ordena la misma lista usando la percepción propia de cada
	# candidato. Así una escuadra mixta conserva roles consistentes aunque sus
	# miembros tengan distinto error posicional sobre el objetivo.
	var ranked := _get_cached_ranking(squad)
	var my_index := ranked.find(subject)
	if my_index < 0:
		return result
	var pressure_count := mini(_get_attack_token_count(ranked), ranked.size())
	if my_index < pressure_count:
		result["role"] = &"pressure"
		result["can_attack"] = true
		result["position"] = _ring_position(
			target_position,
			subject_data.attack_slot_radius,
			my_index,
			maxi(pressure_count, 1),
			0.0
		)
		return result
	var flankers: Array[Node] = []
	for enemy: Node in ranked.slice(pressure_count):
		var candidate_profile := enemy.get("ai_profile") as EnemyAIProfile
		if candidate_profile != null and candidate_profile.is_capability_enabled(EnemyAIProfile.CAP_FLANK):
			flankers.append(enemy)
			if flankers.size() >= 2:
				break
	var flank_index := flankers.find(subject)
	if flank_index >= 0:
		result["role"] = &"flank"
		var target_to_subject := subject.global_position - target_position
		if target_to_subject.length_squared() < 0.001:
			target_to_subject = Vector2.DOWN
		var side := -1.0 if flank_index == 0 else 1.0
		var flank_direction := target_to_subject.normalized().rotated(side * PI * 0.5)
		result["position"] = target_position + flank_direction * subject_profile.flank_radius
		return result
	var waiting_index := maxi(my_index - pressure_count, 0)
	var waiting_count := maxi(ranked.size() - pressure_count, 1)
	result["role"] = (
		&"support"
		if subject_profile.is_capability_enabled(EnemyAIProfile.CAP_TEAMWORK)
		else &"waiting"
	)
	result["position"] = _ring_position(
		target_position,
		subject_profile.support_radius,
		waiting_index,
		waiting_count,
		PI / float(waiting_count)
	)
	return result


static func get_active_enemies(tree: SceneTree) -> Array[Node]:
	_ensure_frame_cache()
	if tree == null:
		return []
	var cache_key := tree.get_instance_id()
	if _active_enemies_cache.has(cache_key):
		var cached: Array[Node] = []
		for node: Node in _active_enemies_cache[cache_key]:
			if is_instance_valid(node):
				cached.append(node)
		return cached
	var active: Array[Node] = []
	for enemy: Node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if enemy.has_method("is_combat_active") and not bool(enemy.call("is_combat_active")):
			continue
		active.append(enemy)
	_active_enemies_cache[cache_key] = active.duplicate()
	return active


func _filter_squad(enemies: Array[Node], subject: CharacterBody2D, subject_data: EnemyData) -> Array[Node]:
	_ensure_frame_cache()
	var candidates: Array[Node] = []
	var seen_ids: Dictionary = {}
	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var data := enemy.get("enemy_data") as EnemyData
		if data == null or data.squad_id != subject_data.squad_id:
			continue
		var enemy_id := enemy.get_instance_id()
		if seen_ids.has(enemy_id):
			continue
		seen_ids[enemy_id] = true
		candidates.append(enemy)
	if not seen_ids.has(subject.get_instance_id()):
		candidates.append(subject)
	var member_ids: Array[int] = []
	for candidate: Node in candidates:
		member_ids.append(candidate.get_instance_id())
	member_ids.sort()
	var component_prefix := "%s|%s" % [String(subject_data.squad_id), str(member_ids)]
	var subject_key := "%s|%d" % [component_prefix, subject.get_instance_id()]
	if _component_cache.has(subject_key):
		var cached_component: Array[Node] = []
		for node: Node in _component_cache[subject_key]:
			if is_instance_valid(node):
				cached_component.append(node)
		if not cached_component.is_empty():
			return cached_component
	_cache_connected_components(candidates, component_prefix)
	if _component_cache.has(subject_key):
		return (_component_cache[subject_key] as Array).duplicate()
	return [subject]


func _cache_connected_components(candidates: Array[Node], cache_prefix: String) -> void:
	# Cada componente se construye una sola vez por frame y se indexa para todos
	# sus miembros. Evita repetir el BFS completo desde la perspectiva de cada IA.
	var visited: Dictionary = {}
	for seed: Node in candidates:
		var seed_id := seed.get_instance_id()
		if visited.has(seed_id):
			continue
		var component: Array[Node] = [seed]
		visited[seed_id] = true
		var frontier_index := 0
		while frontier_index < component.size():
			var current := component[frontier_index]
			frontier_index += 1
			var current_data := current.get("enemy_data") as EnemyData
			if current_data == null:
				continue
			for candidate: Node in candidates:
				var candidate_id := candidate.get_instance_id()
				if visited.has(candidate_id) or not candidate is Node2D:
					continue
				var candidate_data := candidate.get("enemy_data") as EnemyData
				if candidate_data == null:
					continue
				var shared_radius := maxf(current_data.coordination_radius, candidate_data.coordination_radius)
				if (candidate as Node2D).global_position.distance_to((current as Node2D).global_position) <= shared_radius:
					visited[candidate_id] = true
					component.append(candidate)
		for member: Node in component:
			_component_cache["%s|%d" % [cache_prefix, member.get_instance_id()]] = component.duplicate()


func _get_attack_token_count(enemies: Array[Node]) -> int:
	var result := 1
	for enemy: Node in enemies:
		var data := enemy.get("enemy_data") as EnemyData
		if data != null:
			result = maxi(result, data.max_simultaneous_attackers)
	return result


func _get_cached_ranking(enemies: Array[Node]) -> Array[Node]:
	_ensure_frame_cache()
	var member_ids: Array[int] = []
	for enemy: Node in enemies:
		member_ids.append(enemy.get_instance_id())
	member_ids.sort()
	var cache_key := str(member_ids)
	if _ranking_cache.has(cache_key):
		var cached: Array[Node] = []
		for node: Node in _ranking_cache[cache_key]:
			if is_instance_valid(node):
				cached.append(node)
		if cached.size() == enemies.size():
			return cached
	var ranked := _rank_enemies(enemies)
	_ranking_cache[cache_key] = ranked.duplicate()
	return ranked


static func _ensure_frame_cache() -> void:
	var current_frame := Engine.get_physics_frames()
	if _cache_frame == current_frame:
		return
	_cache_frame = current_frame
	_active_enemies_cache.clear()
	_component_cache.clear()
	_ranking_cache.clear()


func _rank_enemies(enemies: Array[Node]) -> Array[Node]:
	var ranked := enemies.duplicate()
	ranked.sort_custom(
		func(a: Node, b: Node) -> bool:
			var a_score := _readiness_score(a)
			var b_score := _readiness_score(b)
			if is_equal_approx(a_score, b_score):
				return a.get_instance_id() < b.get_instance_id()
			return a_score > b_score
	)
	return ranked


func _readiness_score(enemy: Node) -> float:
	if not enemy is Node2D:
		return -INF
	var target_position := (enemy as Node2D).global_position
	var enemy_perception := enemy.get("perception") as EnemyPerception
	if enemy_perception != null and enemy_perception.is_aware:
		target_position = enemy_perception.get_estimated_target_position(false)
	var distance := (enemy as Node2D).global_position.distance_to(target_position)
	var health_ratio := 1.0
	var stamina_ratio := 1.0
	var data := enemy.get("enemy_data") as EnemyData
	if data != null:
		health_ratio = float(enemy.get("health")) / maxf(float(data.max_health), 1.0)
		stamina_ratio = float(enemy.get("stamina")) / maxf(data.max_stamina, 1.0)
	# Un ataque ya iniciado conserva su token hasta terminar. Después el cooldown
	# penaliza al actor y permite rotar la presión hacia otro miembro.
	var is_attacking := enemy.get("current_attack") is AttackData
	var combat_readiness := 10.0 if is_attacking else 0.0
	if not is_attacking:
		combat_readiness -= minf(float(enemy.get("attack_cooldown_left")), 2.0) * 1.4
		if (
			Vector2(enemy.get("knockback_velocity")) != Vector2.ZERO
			or float(enemy.get("stagger_recovery_time_left")) > 0.0
		):
			combat_readiness -= 10.0
	return (
		1.0 / maxf(distance, 1.0) * 90.0
		+ health_ratio * 0.35
		+ stamina_ratio * 0.25
		+ combat_readiness
		- float(enemy.get_instance_id() % 97) * 0.00001
	)


func _ring_position(center: Vector2, radius: float, index: int, count: int, angle_offset: float) -> Vector2:
	var angle := angle_offset + TAU * float(index) / float(maxi(count, 1))
	return center + Vector2.RIGHT.rotated(angle) * radius
