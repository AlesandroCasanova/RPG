class_name EnemyData
extends Resource

@export_category("Identidad")
@export var enemy_name: String = "Enemy"

@export_category("Vida")
@export_range(1, 100000, 1)
var max_health: int = 100

@export_category("Movimiento e IA")
@export_range(0.0, 5000.0, 1.0)
var move_speed: float = 120.0
@export_range(0.0, 10000.0, 1.0)
var detection_range: float = 300.0

@export_category("Combate grupal")
@export_range(1, 20, 1)
var max_simultaneous_attackers: int = 2
@export_range(0.0, 1000.0, 1.0)
var attack_slot_radius: float = 42.0
@export_range(1, 64, 1)
var attack_slot_count: int = 12
@export_range(0.0, 2000.0, 1.0)
var waiting_slot_radius: float = 115.0
@export_range(1, 64, 1)
var waiting_slot_count: int = 16

@export_category("Knockback")
@export_range(0.0, 5000.0, 1.0)
var knockback_force: float = 120.0

# 0.0 = recibe todo el empuje.
# 0.5 = recibe la mitad.
# 1.0 = inmune al knockback.
@export_range(0.0, 1.0, 0.05)
var knockback_resistance: float = 0.0

@export_range(0.0, 10000.0, 1.0)
var knockback_friction: float = 1400.0

@export_category("Stagger / Recuperación")

# El knockback EFECTIVO debe superar este valor para que,
# además del empuje, el enemigo quede recuperándose.
@export_range(0.0, 5000.0, 1.0)
var stagger_threshold: float = 160.0

# Fuerza efectiva a partir de la cual ya se usa la duración
# máxima de recuperación.
@export_range(0.0, 5000.0, 1.0)
var stagger_force_for_max_duration: float = 380.0

# Tiempo mínimo de recuperación cuando apenas se supera
# el umbral.
@export_range(0.0, 10.0, 0.01)
var stagger_min_duration: float = 0.12

# Tiempo máximo de recuperación para golpes muy fuertes.
@export_range(0.0, 10.0, 0.01)
var stagger_max_duration: float = 0.45

@export_category("Avoidance")
@export_range(0.0, 1000.0, 1.0)
var avoidance_radius: float = 22.0
@export_range(0.0, 5000.0, 1.0)
var avoidance_neighbor_distance: float = 120.0
@export_range(0, 32, 1)
var avoidance_max_neighbors: int = 8
@export_range(0.0, 10.0, 0.05)
var avoidance_time_horizon: float = 0.6
