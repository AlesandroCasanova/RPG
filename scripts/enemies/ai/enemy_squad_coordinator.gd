class_name EnemySquadCoordinator
extends RefCounted


static var _cache_frame: int = -1
static var _active_enemies_cache: Dictionary = {}
static var _component_cache: Dictionary = {}
static var _ranking_cache: Dictionary = {}

# Tokens persistentes: evitan que varios miembros comiencen el golpe en el
# mismo instante aunque todos hayan encontrado una ventana valida.
static var _attack_tokens: Dictionary = {}
static var _last_attack_start_by_component: Dictionary = {}


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
		"can_attack": false,
		"coordination_quality": 0.0
	}
	var squad := _filter_squad(enemies, subject, subject_data)
	var ranked := _get_cached_ranking(squad)
	var my_index := ranked.find(subject)
	if my_index < 0:
		return result

	var base_quality := subject_profile.get_group_coordination_quality()
	var leader_bonus := _get_leader_bonus(squad, subject, subject_profile)
	var coordination_quality := clampf(base_quality + leader_bonus, 0.0, 1.0)
	result["coordination_quality"] = coordination_quality

	var pressure_count := mini(_get_attack_token_count(ranked), ranked.size())
	var pressure_snapshot := get_pressure_snapshot(subject, subject_data)
	result["group_attacking_count"] = int(pressure_snapshot.get("attacking", 0))
	result["group_ready_count"] = ranked.size()

	# Sin trabajo en equipo, el enemigo no recibe flancos/formaciones perfectas.
	# Puede coincidir con un rol de presión por proximidad, pero su slot tiene
	# error y no entiende rotaciones complejas.
	if not subject_profile.is_capability_enabled(EnemyAIProfile.CAP_TEAMWORK):
		var crude_pressure := my_index < pressure_count
		result["role"] = &"pressure" if crude_pressure else &"waiting"
		result["can_attack"] = crude_pressure
		var crude_count := maxi(ranked.size(), 1)
		var crude_position := _ring_position(
			target_position,
			subject_data.attack_slot_radius if crude_pressure else subject_profile.support_radius,
			my_index,
			crude_count,
			0.0
		)
		result["position"] = _apply_formation_error(
			crude_position,
			target_position,
			subject,
			subject_profile.get_formation_error()
		)
		return result

	if my_index < pressure_count:
		result["role"] = &"pressure"
		result["can_attack"] = true
		var pressure_position := _ring_position(
			target_position,
			subject_data.attack_slot_radius,
			my_index,
			maxi(pressure_count, 1),
			0.0
		)
		result["position"] = _apply_formation_error(
			pressure_position,
			target_position,
			subject,
			subject_profile.get_formation_error() * 0.45
		)
		return result

	var max_flankers := 0
	if coordination_quality >= 0.38:
		max_flankers = 1
	if coordination_quality >= 0.72:
		max_flankers = 2

	var flankers: Array[Node] = []
	if max_flankers > 0:
		for enemy: Node in ranked.slice(pressure_count):
			var candidate_profile := enemy.get("ai_profile") as EnemyAIProfile
			if candidate_profile != null and candidate_profile.is_capability_enabled(EnemyAIProfile.CAP_FLANK):
				flankers.append(enemy)
				if flankers.size() >= max_flankers:
					break

	var flank_index := flankers.find(subject)
	if flank_index >= 0:
		result["role"] = &"flank"
		var target_to_subject := subject.global_position - target_position
		if target_to_subject.length_squared() < 0.001:
			target_to_subject = Vector2.DOWN
		var side := -1.0 if flank_index == 0 else 1.0
		var flank_direction := target_to_subject.normalized().rotated(side * PI * 0.5)
		var flank_position := target_position + flank_direction * subject_profile.flank_radius
		result["position"] = _apply_formation_error(
			flank_position,
			target_position,
			subject,
			subject_profile.get_formation_error() * 0.35
		)
		return result

	var waiting_index := maxi(my_index - pressure_count, 0)
	var waiting_count := maxi(ranked.size() - pressure_count, 1)
	result["role"] = &"support" if coordination_quality >= 0.45 else &"waiting"
	var support_position := _ring_position(
		target_position,
		subject_profile.support_radius,
		waiting_index,
		waiting_count,
		PI / float(waiting_count)
	)
	result["position"] = _apply_formation_error(
		support_position,
		target_position,
		subject,
		subject_profile.get_formation_error()
	)
	return result


func request_attack_commit(
	subject: CharacterBody2D,
	subject_data: EnemyData,
	subject_profile: EnemyAIProfile,
	expected_duration: float
) -> bool:
	if subject == null or subject_data == null or subject_profile == null:
		return false
	_cleanup_attack_tokens()
	var subject_id := subject.get_instance_id()
	if _attack_tokens.has(subject_id):
		refresh_attack_commit(subject, subject_profile, expected_duration)
		return true
	var active := get_active_enemies(subject.get_tree())
	var component := _filter_squad(active, subject, subject_data)
	var member_ids := _member_id_set(component)
	var limit := mini(_get_attack_token_count(component), component.size())
	var active_count := 0
	for token_id: Variant in _attack_tokens:
		if member_ids.has(int(token_id)):
			active_count += 1
	if active_count >= maxi(limit, 1):
		return false
	var component_key := _component_key(component, subject_data.squad_id)
	var now := float(Time.get_ticks_msec()) / 1000.0
	var last_start := float(_last_attack_start_by_component.get(component_key, -9999.0))
	var coordination_quality := clampf(
		subject_profile.get_group_coordination_quality()
		+ _get_leader_bonus(component, subject, subject_profile),
		0.0,
		1.0
	)
	var stagger := subject_profile.get_team_attack_stagger() * lerpf(0.45, 1.12, coordination_quality)
	if active_count > 0 and now - last_start < stagger:
		return false
	_attack_tokens[subject_id] = {
		"enemy": weakref(subject),
		"component": component_key,
		"expires": now + maxf(expected_duration, 0.05) + subject_profile.get_attack_token_grace()
	}
	_last_attack_start_by_component[component_key] = now
	return true


func refresh_attack_commit(
	subject: CharacterBody2D,
	subject_profile: EnemyAIProfile,
	expected_duration: float
) -> void:
	if subject == null or subject_profile == null:
		return
	_cleanup_attack_tokens()
	var subject_id := subject.get_instance_id()
	if not _attack_tokens.has(subject_id):
		return
	var token: Dictionary = _attack_tokens[subject_id]
	var now := float(Time.get_ticks_msec()) / 1000.0
	token["expires"] = now + maxf(expected_duration, 0.05) + subject_profile.get_attack_token_grace()
	_attack_tokens[subject_id] = token


func release_attack_commit(subject: CharacterBody2D) -> void:
	if subject == null:
		return
	_attack_tokens.erase(subject.get_instance_id())


func get_pressure_snapshot(
	subject: CharacterBody2D,
	subject_data: EnemyData
) -> Dictionary:
	if subject == null or subject_data == null:
		return {"attacking": 0, "members": 0}
	_cleanup_attack_tokens()
	var active := get_active_enemies(subject.get_tree())
	var component := _filter_squad(active, subject, subject_data)
	var member_ids := _member_id_set(component)
	var attacking := 0
	for token_id: Variant in _attack_tokens:
		if member_ids.has(int(token_id)):
			attacking += 1
	return {
		"attacking": attacking,
		"members": component.size()
	}


func _get_leader_bonus(
	members: Array[Node],
	subject: CharacterBody2D,
	subject_profile: EnemyAIProfile
) -> float:
	if subject == null or subject_profile == null:
		return 0.0
	var best := 0.0
	for member: Node in members:
		if member == subject or not is_instance_valid(member) or not member is Node2D:
			continue
		var leader_profile := member.get("ai_profile") as EnemyAIProfile
		if leader_profile == null or not leader_profile.is_capability_enabled(EnemyAIProfile.CAP_LEADERSHIP):
			continue
		if (member as Node2D).global_position.distance_to(subject.global_position) > leader_profile.leadership_command_radius:
			continue
		best = maxf(best, leader_profile.get_leadership_bonus())
	return best


func _apply_formation_error(
	position: Vector2,
	center: Vector2,
	subject: CharacterBody2D,
	error_radius: float
) -> Vector2:
	if subject == null or error_radius <= 0.0:
		return position
	# Error determinista por instancia/frame de asignación: evita jitter por frame.
	var hash_value := int(subject.get_instance_id() * 1103515245 + 12345)
	var angle := fmod(float(abs(hash_value % 10000)) / 10000.0 * TAU, TAU)
	var magnitude := error_radius * (0.35 + float(abs(hash_value % 997)) / 997.0 * 0.65)
	var candidate := position + Vector2.RIGHT.rotated(angle) * magnitude
	# No deja que el error mande al enemigo exactamente al centro del objetivo.
	if candidate.distance_to(center) < 18.0:
		var away := candidate - center
		if away.length_squared() < 0.001:
			away = Vector2.DOWN
		candidate = center + away.normalized() * 18.0
	return candidate


static func _cleanup_attack_tokens() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	var erase_ids: Array[int] = []
	for token_id: Variant in _attack_tokens:
		var token: Dictionary = _attack_tokens[token_id]
		var enemy_ref := token.get("enemy") as WeakRef
		var enemy: Object = enemy_ref.get_ref() if enemy_ref != null else null
		if enemy == null or now >= float(token.get("expires", 0.0)):
			erase_ids.append(int(token_id))
	for token_id: int in erase_ids:
		_attack_tokens.erase(token_id)


static func _member_id_set(members: Array[Node]) -> Dictionary:
	var result: Dictionary = {}
	for member: Node in members:
		if is_instance_valid(member):
			result[member.get_instance_id()] = true
	return result


static func _component_key(members: Array[Node], squad_id: StringName) -> String:
	var ids: Array[int] = []
	for member: Node in members:
		if is_instance_valid(member):
			ids.append(member.get_instance_id())
	ids.sort()
	return "%s|%s" % [String(squad_id), str(ids)]


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
