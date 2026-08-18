extends CharacterBody2D


var observable_action: StringName = &"charge"
var observable_phase: StringName = &"telegraph"
var observable_attack_family: StringName = &"charged"
var observable_charge_stage: StringName = &"ready"
var observable_locomotion: StringName = &"idle"
var observable_facing: Vector2 = Vector2.LEFT
var movement_noise: float = 0.0
var private_probe: int = 99173
var snapshot_sequence: int = 0


func get_combat_observable_snapshot() -> Dictionary:
	snapshot_sequence += 1
	return {
		"sequence": snapshot_sequence,
		"position": global_position,
		"velocity": velocity,
		"facing": observable_facing,
		"locomotion": observable_locomotion,
		"action": observable_action,
		"phase": observable_phase,
		"attack_family": observable_attack_family,
		"charge_stage": observable_charge_stage,
		"noise_level": movement_noise,
		"alive": true,
		# Este valor deliberadamente privado comprueba que Perception
		# construya una vista permitida en vez de reenviar todo el raw.
		"private_probe": private_probe
	}


func get_movement_noise_level() -> float:
	return movement_noise
