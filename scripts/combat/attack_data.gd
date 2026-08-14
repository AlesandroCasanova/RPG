class_name AttackData
extends Resource


# =========================================================
# IDENTIDAD
# =========================================================

@export_category("Identidad")

@export var attack_name: String = "Attack"


# =========================================================
# DAÑO
# =========================================================

@export_category("Daño")

@export_range(0, 100000, 1)
var damage: int = 10

@export_range(0.0, 60.0, 0.05)
var cooldown: float = 1.0


# =========================================================
# HITBOX
# =========================================================

@export_category("Hitbox")

# Largo del área de ataque hacia adelante.
@export_range(1.0, 1000.0, 1.0)
var hitbox_length: float = 48.0


# Ancho lateral del ataque.
@export_range(1.0, 1000.0, 1.0)
var hitbox_width: float = 30.0


# Distancia desde el origen del personaje
# hasta donde comienza la hitbox.
@export_range(0.0, 500.0, 1.0)
var hitbox_start_offset: float = 8.0


# =========================================================
# KNOCKBACK
# =========================================================

@export_category("Knockback")

@export_range(0.0, 5000.0, 1.0)
var knockback_force: float = 80.0
