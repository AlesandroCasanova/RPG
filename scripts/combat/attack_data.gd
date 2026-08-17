class_name AttackData
extends Resource


# =========================================================
# TIPO DE ATAQUE
# =========================================================

enum AttackKind {
	PRIMARY,
	HEAVY,
	CHARGED
}


# =========================================================
# IDENTIDAD
# =========================================================

@export_category("Identidad")

@export var attack_name: String = "Attack"

@export var attack_kind: AttackKind = (
	AttackKind.PRIMARY
)


# =========================================================
# DAÑO
# =========================================================

@export_category("Daño")

@export_range(0, 100000, 1)
var damage: int = 10


# =========================================================
# TIEMPOS
# =========================================================

@export_category("Tiempos")

# Tiempo previo al impacto.
# Sirve como telegraph / preparación del ataque.
@export_range(0.0, 10.0, 0.01)
var windup_time: float = 0.10


# Tiempo durante el cual el ataque está en su fase activa.
# Por ahora el daño se resuelve una sola vez al comenzar
# esta fase, pero este valor nos servirá después para
# animaciones y ataques más complejos.
@export_range(0.0, 10.0, 0.01)
var active_time: float = 0.08


# Tiempo que el enemigo queda comprometido después
# del golpe.
@export_range(0.0, 10.0, 0.01)
var recovery_time: float = 0.18


# Solo se utiliza realmente en ataques CHARGED.
# Es tiempo adicional de carga antes del windup.
@export_range(0.0, 10.0, 0.01)
var charge_time: float = 0.0


# Tiempo mínimo antes de poder comenzar otro ataque.
@export_range(0.0, 60.0, 0.05)
var cooldown: float = 1.0


# =========================================================
# STAMINA
# =========================================================

@export_category("Stamina")

@export_range(0.0, 10000.0, 1.0)
var stamina_cost: float = 0.0


# =========================================================
# IA
# =========================================================

@export_category("IA")

# Peso relativo al elegir este ataque.
#
# Ejemplo:
#
# Primary = 1.0
# Heavy = 0.5
# Charged = 0.25
#
# El primary tenderá a utilizarse más frecuentemente.
#
# Más adelante Combat Intelligence reemplazará/ampliará
# esta selección.
@export_range(0.0, 100.0, 0.05)
var ai_weight: float = 1.0


# =========================================================
# HITBOX
# =========================================================

@export_category("Hitbox")

@export_range(1.0, 1000.0, 1.0)
var hitbox_length: float = 48.0


@export_range(1.0, 1000.0, 1.0)
var hitbox_width: float = 30.0


@export_range(0.0, 500.0, 1.0)
var hitbox_start_offset: float = 8.0


# =========================================================
# KNOCKBACK
# =========================================================

@export_category("Knockback")

@export_range(0.0, 5000.0, 1.0)
var knockback_force: float = 80.0
