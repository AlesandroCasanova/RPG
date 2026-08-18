# Inventario, loot y equipamiento

## Controles

- `I`: abrir o cerrar el inventario.
- `F`: recoger el objeto cercano cuando aparece el aviso contextual.
- Doble clic sobre un equipo: equiparlo.
- También se puede seleccionar un objeto y pulsar `Equipar`.
- Los botones de la derecha quitan el equipo de cada ranura.

El juego queda pausado mientras el inventario está abierto.

## Interfaz visual

El panel utiliza `res://assets/ui/inventory/inventory_frame.png`. Los controles,
textos y botones continúan siendo elementos nativos de Godot colocados sobre el
marco, por lo que pueden modificarse y traducirse sin editar la imagen.

Los iconos finales de esta primera tanda se encuentran en
`res://assets/items/icons/`. Se muestran en la lista, en las ranuras equipadas y
como representación visual del loot en el mundo.

## Loot

Los objetos no se recogen automáticamente: al entrar en el radio del rombo
aparece `[F] Recoger`. La rareza controla el color del drop, el aviso y el
nombre en el inventario.

La escena reutilizable es `res://scenes/items/item_pickup.tscn`. Cada instancia
solo necesita un `ItemData` y una cantidad.

Los enemigos pueden definir una tabla de `LootEntry` dentro de su `EnemyData`.
Cada entrada configura objeto, probabilidad y cantidad mínima/máxima. El goblin
actual deja fragmentos con 85% de probabilidad (1 a 3) y tiene 12% de
probabilidad de dejar una Espada mellada.

## Equipo de prueba

- Espada mellada: +3 Fuerza y +1 Destreza.
- Botas de acechador: +2 Destreza y +2 Aguante.
- Amuleto de hierro: +3 Vitalidad y +2 Voluntad.
- Fragmento goblin: material apilable utilizado para validar stacks.

## Crear objetos

Los objetos son recursos `.tres` basados en
`res://scripts/items/item_data.gd`. Pueden configurar identidad, descripción,
rareza, tamaño del stack, ranura y atributos. Para añadir uno nuevo no es
necesario modificar el código del jugador ni del inventario.

Ranuras actuales:

- arma;
- armadura;
- accesorio.

El inventario del jugador tiene inicialmente 20 espacios. Los objetos equipados
permanecen visibles dentro del inventario con el prefijo `[E]`.
