# IA de combate reutilizable

La IA enemiga se configura con recursos y se ejecuta desde la escena base del
enemigo. Un enemigo nuevo no necesita un script de IA propio: combina un
`EnemyData`, un `EnemyAIProfile`, sus `AttackData` y una escena que herede de
`enemy_base.tscn`.

El porcentaje de inteligencia no aumenta vida, daño ni velocidad. Determina
qué recursos tácticos puede comprender, cuánto tarda en reaccionar, cuánto
error comete al decidir y qué tan precisa es su memoria.

## Archivos principales

```text
scripts/enemies/base/enemy.gd                    Actor y ejecución de acciones
scripts/enemies/base/enemy_data.gd               Cuerpo, movilidad y equipo físico
scripts/enemies/ai/enemy_ai_profile.gd            Inteligencia y personalidad
scripts/enemies/ai/enemy_perception.gd            Visión, audición y memoria
scripts/enemies/ai/enemy_utility_brain.gd         Puntuación y elección de acciones
scripts/enemies/ai/enemy_squad_coordinator.gd    Roles y permisos de ataque
scripts/enemies/ai/enemy_tactical_positioning.gd Cobertura, círculo y esquiva
scripts/enemies/ai/enemy_cover_point.gd           Marcadores reservables
scripts/player/player.gd                          Señales de combate observables
data/ai/                                          Perfiles editables
data/enemies/                                     Estadísticas y habilidades físicas
data/attacks/                                     Ataques reutilizables
scenes/enemies/base/enemy_base.tscn               Escena base
```

Los recursos son definiciones compartidas: no deben almacenar cooldowns,
memoria, reservas ni la acción actual. Todo ese estado pertenece a cada
instancia de `Enemy` durante el gameplay.

## Flujo de una decisión

1. Percepción comprueba visión y ruido.
2. La observación entra en una cola durante el tiempo de reacción del perfil.
3. Al recibirla, se aplica error de posición, confianza y velocidad estimada.
4. Si se pierde contacto, la memoria conserva una estimación que se degrada.
5. El coordinador asigna un rol y un token de ataque cuando existe visión.
6. El cerebro descarta capacidades bloqueadas y puntúa las acciones válidas.
7. Aplica incertidumbre; una IA imperfecta puede elegir la segunda opción.
8. Mantiene la intención durante un compromiso breve para evitar temblores.
9. `Enemy` ejecuta movimiento, ataque, cobertura, esquiva o retirada.

El seed de un perfil puede fijarse para pruebas reproducibles. El sistema lo
combina con la instancia del enemigo para que varios enemigos que comparten el
mismo `.tres` no tomen todas sus decisiones al mismo tiempo.

## Inteligencia de 0 a 100

`intelligence_percent` es el control principal. En modo `AUTO`, las capacidades
se desbloquean en estos umbrales:

| IQ | Capacidad |
|---:|---|
| 0 | huir con poca vida |
| 10 | buscar la última posición conocida |
| 30 | elegir ataques pesados si el cuerpo puede usarlos |
| 35 | coordinación básica y flanqueo |
| 40 | circular alrededor del objetivo |
| 45 | buscar cobertura |
| 50 | adaptar el ataque al estado observado del jugador |
| 60 | reconocer telegraphs visibles |
| 65 | esquivar una amenaza reconocida |
| 70 | usar dash e intentar interrupciones |
| 75 | elegir ataques cargados si están equipados |
| 80 | predecir brevemente el movimiento observado |

Las bandas que muestra el depurador son:

- `0–25`: instintiva;
- `26–50`: táctica básica;
- `51–75`: táctica avanzada;
- `76–90`: estratégica;
- `91–100`: maestra.

Más IQ también reduce el intervalo de decisión, el ruido de utilidad, la
posibilidad de equivocarse y el error de memoria. Incluso al 100 % permanece un
piso de reacción y una pequeña incertidumbre: inteligencia no significa leer
inputs ni acertar siempre.

### Overrides de capacidades

Cada capacidad posee tres modos:

- `AUTO`: respeta el umbral de IQ;
- `DISABLED`: se prohíbe aunque el IQ alcance el umbral;
- `ENABLED`: se permite aunque el IQ sea inferior.

Esto permite crear excepciones sin escribir código. Por ejemplo, una bestia de
20 % puede tener una esquiva instintiva, o un hechicero de 90 % puede no usar
dash porque su diseño no lo requiere.

Los multiplicadores `decision_error_multiplier`, `reaction_time_multiplier` y
`memory_error_multiplier` afinan una criatura concreta sin cambiar su banda.

## Inteligencia no es habilidad física

Una decisión necesita permiso cognitivo y una herramienta física disponible.

| Configuración cognitiva (`EnemyAIProfile`) | Configuración física (`EnemyData`) |
|---|---|
| entiende `dash` | `can_dash`, velocidad, duración, costo y cooldown |
| entiende ataque pesado | `can_use_heavy_attacks` y un `heavy_attack` asignado |
| entiende ataque cargado | `can_use_charged_attacks` y un `charged_attack` asignado |
| reconoce peligro y decide cancelar | `can_cancel_attack_windup`, costo y cooldown |
| sabe interrumpir | un `interrupt_attack` equipado, con alcance, stamina y knockback reales |
| valora teamwork | `squad_id`, radio y cantidad máxima de atacantes |

Por lo tanto, subir un perfil a 80 % no le da automáticamente dash a cualquier
especie. El dash solo aparece si `CAP_DASH` está habilitada, `EnemyData.can_dash`
es verdadero, no hay cooldown y alcanza la stamina.

Esta separación también evita que cambiar la dificultad altere accidentalmente
el daño, los puntos de vida o la velocidad base.

## Percepción justa

La IA usa señales que un personaje podría observar en pantalla. El jugador
publica con `get_combat_observable_snapshot()`:

- posición y velocidad visibles;
- orientación;
- locomoción (`idle`, movimiento, sprint, crouch o dash);
- acción visible y fase (`telegraph`, activa o recuperación);
- etapa visible de carga; una vez liberado, la familia es un swing genérico si
  comparte la misma animación con los demás ataques.

No publica inputs, cooldowns, daño ni el instante exacto del impacto.

Una observación visual puede contener telegraphs. Una observación auditiva solo
informa movimiento aproximado y no revela el ataque. Ambas esperan el tiempo de
reacción del perfil antes de llegar a la memoria.

Al perder línea de visión:

- el enemigo recibe el rol `search`;
- pierde permiso para atacar;
- se mueve hacia su posición estimada, no hacia la posición real del jugador;
- aumenta su incertidumbre hasta que termina `memory_duration`;
- solo perfiles con predicción prolongan brevemente la última velocidad vista.

Mantener `CTRL` reduce el ruido del jugador al 12 % del normal. Sprint y dash
generan más ruido que caminar. El sigilo no vuelve invisible al jugador: entrar
en el cono de visión todavía permite detectarlo.

## Roles y ritmo de grupo

- `pressure`: posee un token de ataque y ocupa el anillo frontal.
- `flank`: busca un lateral; requiere la capacidad de flanquear.
- `support`: conserva espacio y espera una apertura con teamwork habilitado.
- `waiting`: espera un token sin fingir coordinación táctica.
- `search`: investiga la última estimación sin contacto visual.
- `unaware`: todavía no detectó una amenaza o agotó su memoria.

Los enemigos solo se coordinan si comparten `squad_id` y están dentro de
`coordination_radius`. `max_simultaneous_attackers` controla el ritmo y evita
que todo el grupo golpee a la vez. Este límite sigue siendo una regla de
legibilidad del combate, aunque algunos integrantes sean poco inteligentes.
El listado de miembros, los componentes conectados y el ranking de preparación
se cachean por frame de física; una horda no repite el mismo escaneo y BFS desde
cada integrante.

## Acciones de utilidad

El cerebro puede considerar:

- `attack`: usa un ataque que alcance y tenga recursos;
- `approach`: se acerca al slot asignado;
- `flank`: ocupa un lateral;
- `hold`: espera, recupera stamina y mantiene espacio;
- `retreat`: se aleja con poca vida o recursos;
- `search`: investiga memoria sin visión;
- `circle`: se desplaza tangencialmente alrededor del objetivo;
- `cover`: reserva un punto protegido;
- `dodge`: sale de una zona peligrosa, con dash si puede;
- `interrupt`: intenta cortar un telegraph mediante el ataque interruptor que
  tenga equipado físicamente.

Primero se calculan utilidades crudas. Después se aplica ruido proporcional a
la inteligencia. Las capacidades bloqueadas no entran en la competencia; las
acciones físicamente imposibles reciben utilidad cero y la ejecución vuelve a
validar alcance, cooldown y recursos. Cuando ocurre un error deliberado, el
cerebro elige una alternativa viable cercana a la mejor, no una acción
completamente aleatoria o imposible.

Los pesos del perfil (`attack_utility`, `cover_utility`, etc.) expresan
preferencias; personalidad modifica esas preferencias:

- `aggression`: presión ofensiva;
- `courage`: resistencia a retirarse;
- `teamwork`: valor de flanqueo y coordinación;
- `patience`: disposición a esperar;
- `retreat_health_ratio`: umbral de retirada.

## Cobertura

La cobertura se autoriza por IQ, pero necesita puntos colocados en el mapa.
Para crear uno:

1. Añadir un `EnemyCoverPoint` cerca del lado protegido de un obstáculo.
2. Mantenerlo sobre una zona navegable y alcanzable.
3. Ajustar `cover_quality` para priorizarlo.
4. Dejar `designer_confirmed_cover` activo si el diseño confirma el punto.
5. Evitar colocar dos marcadores casi superpuestos.

El nodo se registra automáticamente en `ai_cover_points`. El posicionador filtra
por `cover_search_radius`, disponibilidad y bloqueo físico o confirmación del
diseñador. Después puntúa calidad, distancia de viaje y separación respecto de
la amenaza. Cada punto se reserva temporalmente y también respeta
`occupancy_radius` para evitar que dos enemigos ocupen la misma cobertura. Un
perfil imperfecto puede escoger la segunda o tercera mejor cobertura válida.

Al llegar al marcador comienza un compromiso real de `cover_hold_duration`.
Durante ese período el enemigo mantiene o recupera el punto aunque el obstáculo
le corte la visión. Al terminar libera la reserva y aplica un breve cooldown de
reentrada para no reseleccionar inmediatamente la misma cobertura. La reserva
incluye el tiempo estimado de viaje y no puede ser sobrescrita por otro enemigo.

La validación actual no calcula el camino completo antes de seleccionar; por
eso los puntos deben colocarse manualmente sobre navegación accesible.

En el escenario tutorial, los colliders rectangulares se hornean además como
obstrucciones del `NavigationPolygon`. El path global rodea edificios y rocas,
mientras `NavigationObstacle2D` resuelve la separación local. Al agregar un
blocker rectangular dentro de `Collisions`, ambas representaciones se generan
automáticamente al instanciar `FrontierEnvironment`.

## Dash, esquiva e interrupción

El dash prueba primero la dirección deseada y varias alternativas angulares.
Solo comienza si el desplazamiento completo no está bloqueado, su destino sigue
sobre navegación y el trayecto no atraviesa a otro enemigo. Consume stamina,
activa cooldown y usa movimiento con colisión; no teletransporta ni concede
invulnerabilidad por sí solo.

Una esquiva avanzada exige:

1. telegraph percibido mediante visión;
2. tiempo de reacción ya transcurrido;
3. amenaza orientada hacia el enemigo;
4. capacidad de esquiva;
5. dash físico disponible, o retirada caminando como alternativa.

Un enemigo autorizado puede cancelar únicamente el `windup` de su propio
ataque para reaccionar a una carga visible. Debe pagar el costo configurado y
respetar `reactive_cancel_cooldown`; no puede cancelar gratis cualquier fase.

La interrupción usa un `interrupt_attack` explícito. Para que funcione debe
estar equipado, listo, alcanzar al jugador y tener una consecuencia física
real. El jefe de referencia equipa `goblin_interrupting_hook.tres`, cuyo
knockback puede cortar la carga base del jugador si el impacto llega a tiempo.

## Perfiles goblin de referencia

```text
data/ai/goblin/common_20.tres
data/ai/goblin/elite_50.tres
data/ai/goblin/boss_80.tres
```

### Goblin común · 20 %

- persigue y usa ataque primario;
- busca durante poco tiempo;
- huye con poca vida;
- reacciona lentamente y recuerda con bastante error;
- no flanquea, usa cobertura, dash ni lee cargas.

### Goblin élite · 50 %

- usa ataque pesado si está equipado;
- rota tokens, flanquea y circula;
- busca y reserva cobertura;
- adapta ataques a recuperaciones visibles;
- a veces elige una posición o acción secundaria en lugar de la óptima;
- todavía no lee telegraphs avanzados ni usa dash automático.

### Jefe goblin · 80 %

- conserva las capacidades anteriores;
- reconoce cargas después de su reacción, nunca instantáneamente;
- esquiva con dash si el cuerpo tiene recursos;
- puede interrumpir o cancelar su propio windup con costo;
- utiliza ataques cargados y predicción breve;
- mantiene incertidumbre suficiente para ser desafiante sin ser omnisciente.

Los datos físicos correspondientes están en `data/enemies/goblin/` y las
escenas listas para instanciar en `scenes/enemies/goblin/`.

## Crear un enemigo nuevo

1. Crear `data/enemies/<especie>/<variante>.tres` con `EnemyData`.
2. Configurar vida, movimiento, stamina, dash físico, ataques permitidos,
   resistencia, loot y `squad_id`.
3. Crear `data/ai/<especie>/<perfil>.tres` con `EnemyAIProfile`.
4. Elegir `intelligence_percent`; dejar capacidades en `AUTO` y aplicar solo
   overrides justificados por el diseño.
5. Crear los ataques en `data/attacks/<especie>/` como `AttackData`.
6. Heredar `scenes/enemies/base/enemy_base.tscn` y asignar los recursos.
7. Configurar sprite, colisión y animaciones con prefijos `idle`, `walk` y
   `attack` cuando corresponda.
8. Añadir puntos de cobertura al mapa si el perfil puede usarlos.
9. Probarlo solo y en grupo con `debug_combat` activo.

No dupliques `enemy.gd` para cambiar una personalidad. Crea otro perfil `.tres`.
Un script específico solo se justifica cuando la criatura posee una mecánica
corporal que la escena base no puede ejecutar todavía.

## Depuración

Con `debug_combat` activo, la etiqueta sobre el enemigo muestra:

```text
ROL | ACCIÓN | PERCEPCIÓN
IQ % | confianza de decisión | confianza de observación | ERROR
puntuaciones abreviadas
```

Estados de percepción:

- `VISION`: contacto visual directo;
- `OIDO`: observación generada por ruido;
- `MEM`: solo conserva una estimación;
- `CALMA`: no está consciente de una amenaza.

El dibujo adicional muestra cono de visión, radio de audición, objetivo táctico,
línea a la estimación percibida, hitbox del ataque y última posición recordada. Para comparar
perfiles, activa un seed fijo y observa múltiples decisiones, no un único duelo.

## Pruebas recomendadas

La escena `res://scenes/debug/ai_sandbox.tscn` contiene un common 20, un elite
50, un boss 80 y puntos de cobertura. Abrirla y ejecutar la escena actual con
`F6` permite comparar los tres perfiles. Cargar un ataque frente al jefe sirve
para observar reconocimiento, interrupción, cancelación de windup y dash.

La suite automatizada se ejecuta desde la raíz del proyecto con:

```text
godot --headless --path . --script res://tests/ai/ai_test_runner.gd
```

Finaliza con `AI_TESTS_OK` cuando pasan las comprobaciones de umbrales,
decisiones, seed, percepción justa y carga de recursos/escenas.

La suite actual ejecuta 254 aserciones e incluye una escuadra mixta para
verificar tokens y roles consistentes aun cuando cada integrante tenga una
estimación distinta del objetivo. También cubre reacquisición visual demorada,
alcance estimado, interrupción física, permanencia y reservas de cobertura,
animaciones de variantes y filtrado de señales privadas.

El bake de navegación y el flujo completo de nombre, diálogos, guardado e
inventario tienen runners separados:

```text
godot --headless --path . --script res://tests/navigation_bake_test.gd
godot --headless --path . --script res://tests/smoke_test.gd
```

La validación automática y manual debe comprobar al menos:

- umbrales y overrides de todas las capacidades;
- que 20/50/80 desbloqueen exactamente lo previsto;
- una acción físicamente imposible no llegue a ejecutarse pese al ruido;
- reproducción con seed y ausencia de sincronización entre enemigos;
- memoria imprecisa y pérdida de conocimiento al ocultarse;
- imposibilidad de leer cargas por sonido o a través de obstáculos;
- reacción a una carga solo después del retraso correspondiente;
- consumo y cooldown de dash y cancelación reactiva;
- reservas exclusivas de cobertura;
- límite de atacantes y filtrado por `squad_id`;
- carga de todos los recursos y escenas de referencia;
- combate grupal con common, elite y boss en un sandbox.

## Extensiones futuras

La arquitectura está preparada para sumar comportamientos globales y luego
habilitarlos por perfil:

- guardia, bloqueo, parry y guard break;
- ataques a distancia, magia y selección de proyectiles;
- apoyo, curación y protección de aliados;
- liderazgo y memoria compartida con retraso;
- adaptación estadística a patrones repetidos del jugador;
- fases de jefe con cambio de perfil;
- cover points con validación completa de ruta y rutas de escape;
- selección entre varios objetivos y tabla de amenaza;
- acciones configurables como recursos independientes;
- coordinador compartido por escuadrón para batallas numerosas.

Estas extensiones deben respetar siempre la misma regla: una IA solo puede
razonar sobre información percibida y solo puede ejecutar habilidades que su
cuerpo tenga configuradas.
