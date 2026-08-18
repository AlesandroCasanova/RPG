# IA de combate

## Flujo

Cada enemigo procesa el combate en este orden:

1. Percibe al jugador mediante visión y audición.
2. Conserva durante unos segundos su última posición conocida.
3. El coordinador asigna un rol grupal.
4. El cerebro puntúa las acciones disponibles.
5. Mantiene la intención durante un intervalo corto para evitar movimientos nerviosos.

## Roles

- `pressure`: ocupa el frente y tiene permiso para atacar.
- `flank`: se desplaza hacia un lateral y puede reemplazar al atacante durante su cooldown.
- `support`: conserva espacio y espera una apertura.
- `unaware`: todavía no detectó al jugador o agotó su memoria.

## Acciones de utilidad

- `attack`
- `approach`
- `flank`
- `hold`
- `retreat`
- `search`

Las preferencias del goblin están en
`res://data/ai/goblin_tactician.tres`. El recurso permite ajustar sentidos,
memoria, personalidad, compromiso, distancias tácticas y pesos de utilidad sin
modificar código.

## Depuración visual

Con `debug_combat` activado, cada goblin muestra:

- rol, acción y tipo de percepción sobre su cabeza;
- puntuaciones de utilidad abreviadas;
- arco de visión;
- radio de audición;
- posición táctica asignada;
- última posición recordada en violeta cuando pierde contacto visual.

Estados de percepción:

- `VISION`: contacto visual directo.
- `OIDO`: detectó movimiento cercano.
- `MEM`: busca una posición recordada.
- `CALMA`: no está en combate.

## Sigilo y ruido del jugador

Mantener `CTRL` activa el estado de sigilo. El jugador se mueve más lento y su
ruido baja al 12 % del valor normal. Caminar agachado no supera el umbral
auditivo actual del goblin, pero entrar en su cono de visión todavía permite que
lo detecte. Sprint y dash generan más ruido que caminar.

Mientras no existan sprites definitivos de agachado, el personaje se comprime
ligeramente y muestra la etiqueta `SIGILO` sobre su cabeza.

## Prueba inicial recomendada

Ejecutar `world.tscn` y observar a los tres goblins. Uno debe presionar mientras
los otros flanquean. Después de un ataque, el cooldown reduce temporalmente la
prioridad del atacante y otro goblin ocupa su rol. Alejarse o cubrirse detrás del
árbol permite comprobar la búsqueda por memoria.
