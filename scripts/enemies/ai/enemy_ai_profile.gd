class_name EnemyAIProfile
extends Resource


@export_category("Percepcion")

@export_range(1.0, 5000.0, 1.0)
var vision_range: float = 360.0

@export_range(1.0, 360.0, 1.0)
var vision_angle_degrees: float = 210.0

@export_range(0.0, 5000.0, 1.0)
var hearing_range: float = 180.0

@export_range(0.0, 1000.0, 1.0)
var hearing_velocity_threshold: float = 45.0

@export_range(0.0, 30.0, 0.1)
var memory_duration: float = 4.0

@export_flags_2d_physics
var sight_collision_mask: int = 1


@export_category("Ritmo de decision")

@export_range(0.05, 2.0, 0.01)
var decision_interval: float = 0.20

@export_range(0.05, 3.0, 0.05)
var minimum_commitment: float = 0.35

@export_range(0.05, 5.0, 0.05)
var maximum_commitment: float = 0.85


@export_category("Personalidad")

@export_range(0.0, 2.0, 0.05)
var aggression: float = 1.0

@export_range(0.0, 2.0, 0.05)
var courage: float = 0.85

@export_range(0.0, 2.0, 0.05)
var teamwork: float = 1.15

@export_range(0.0, 2.0, 0.05)
var patience: float = 0.8

@export_range(0.0, 1.0, 0.05)
var retreat_health_ratio: float = 0.25


@export_category("Posicionamiento tactico")

@export_range(10.0, 1000.0, 1.0)
var preferred_distance: float = 58.0

@export_range(10.0, 2000.0, 1.0)
var flank_radius: float = 105.0

@export_range(10.0, 2000.0, 1.0)
var support_radius: float = 145.0

@export_range(10.0, 1000.0, 1.0)
var retreat_distance: float = 175.0


@export_category("Pesos de utilidad")

@export_range(0.0, 5.0, 0.05)
var attack_utility: float = 1.35

@export_range(0.0, 5.0, 0.05)
var approach_utility: float = 1.0

@export_range(0.0, 5.0, 0.05)
var flank_utility: float = 1.15

@export_range(0.0, 5.0, 0.05)
var hold_utility: float = 0.75

@export_range(0.0, 5.0, 0.05)
var retreat_utility: float = 1.4

@export_range(0.0, 5.0, 0.05)
var search_utility: float = 1.0
