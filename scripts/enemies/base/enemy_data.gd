class_name EnemyData
extends Resource


# =========================================================
# IDENTIDAD
# =========================================================

@export_category("Identidad")

@export var enemy_name: String = "Enemy"


# =========================================================
# VIDA
# =========================================================

@export_category("Vida")

@export_range(1, 100000, 1)
var max_health: int = 100


# =========================================================
# MOVIMIENTO E IA
# =========================================================

@export_category("Movimiento e IA")

@export_range(0.0, 5000.0, 1.0)
var move_speed: float = 120.0

@export_range(0.0, 10000.0, 1.0)
var detection_range: float = 300.0


# =========================================================
# COMBATE AVANZADO
# =========================================================

@export_category("Combate avanzado")

# Permite utilizar el recurso Heavy Attack asignado
# al Enemy.
@export var can_use_heavy_attacks: bool = false


# Permite utilizar el recurso Charged Attack asignado
# al Enemy.
@export var can_use_charged_attacks: bool = false


# Knockback EFECTIVO necesario para cancelar un ataque
# que el enemigo esté preparando.
#
# Ejemplo:
# 160:
#
# ataque player normal = 120 -> no cancela.
# ataque player pesado = 220 -> cancela.
# ataque player cargado = 380 -> cancela.
@export_range(0.0, 5000.0, 1.0)
var attack_interrupt_knockback_threshold: float = 160.0


# =========================================================
# STAMINA INTERNA
# =========================================================

@export_category("Stamina interna")

# Si está desactivado, este enemigo ignora por completo
# los costos de stamina de AttackData.
@export var uses_stamina: bool = false


@export_range(1.0, 10000.0, 1.0)
var max_stamina: float = 100.0


@export_range(0.0, 1000.0, 1.0)
var stamina_regen_rate: float = 22.0


@export_range(0.0, 10.0, 0.05)
var stamina_regen_delay: float = 0.80


# =========================================================
# COMBATE GRUPAL
# =========================================================

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


# =========================================================
# LOOT
# =========================================================

@export_category("Loot")

@export var loot_table: Array[LootEntry] = []


# =========================================================
# KNOCKBACK
# =========================================================

@export_category("Knockback")

@export_range(0.0, 5000.0, 1.0)
var knockback_force: float = 120.0


# 0.0 = recibe todo.
# 0.5 = recibe la mitad.
# 1.0 = inmunidad.
@export_range(0.0, 1.0, 0.05)
var knockback_resistance: float = 0.0


@export_range(0.0, 10000.0, 1.0)
var knockback_friction: float = 1400.0


# =========================================================
# STAGGER / RECUPERACIÓN
# =========================================================

@export_category("Stagger / Recuperación")

@export_range(0.0, 5000.0, 1.0)
var stagger_threshold: float = 160.0


@export_range(0.0, 5000.0, 1.0)
var stagger_force_for_max_duration: float = 380.0


@export_range(0.0, 10.0, 0.01)
var stagger_min_duration: float = 0.12


@export_range(0.0, 10.0, 0.01)
var stagger_max_duration: float = 0.45


# =========================================================
# AVOIDANCE
# =========================================================

@export_category("Avoidance")

@export_range(0.0, 1000.0, 1.0)
var avoidance_radius: float = 22.0


@export_range(0.0, 5000.0, 1.0)
var avoidance_neighbor_distance: float = 120.0


@export_range(0, 32, 1)
var avoidance_max_neighbors: int = 8


@export_range(0.0, 10.0, 0.05)
var avoidance_time_horizon: float = 0.6
