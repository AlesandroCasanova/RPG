# Primer capítulo abierto: El Paso de Maela

La escena inicial es
`res://scenes/tutorial/first_encounter.tscn` y está configurada como escena
principal del proyecto.

La zona funciona como el primer sector de mundo abierto: el jugador puede
explorar desde el comienzo, descubrir lugares en el mapa y seguir la misión a
su ritmo.

## Flujo del capítulo

1. El jugador aparece frente al refugio de Maela.
2. Se acerca al NPC y pulsa `F`.
3. El diálogo presenta movimiento, sigilo, ataques y dash.
4. Al terminar el diálogo se activan tres goblins del sendero como tutorial de
   combate.
5. Cada muerte actualiza el objetivo en pantalla.
6. Tras la tercera baja, Maela muestra un `?` verde.
7. Al regresar y hablar, Maela entrega:
   - un Amuleto de hierro;
   - cinco Fragmentos goblin.
8. Maela explica la guerra exterior, la barrera maldita y la reciente expansión
   de la corrupción.
9. El jugador investiga tres cicatrices del antiguo campo de batalla. Cada una
   provoca susurros y una emboscada de tres corrompidos.
10. Al llevar la evidencia a Maela obtiene Botas de acechador y ocho fragmentos.
11. La pista conduce hasta Ivar, un explorador marcado que espera en la torre
    de vigilancia derruida.
12. Ivar cuenta qué ocurrió con su expedición y dirige al jugador al corazón
    corrupto.
13. La purga final enfrenta al jugador con cuatro corrompidos y el Devorador de
    recuerdos.
14. Al regresar con Ivar se completa el capítulo y se recibe una Espada oxidada
    y doce fragmentos.

Las recompensas van al inventario. Si estuviera lleno, aparecen físicamente
junto al NPC y pueden recogerse con `F`.

## Controles y navegación

- `M`: abre o cierra el mapa del territorio y pausa la acción.
- El minimapa permanece visible abajo a la derecha.
- `F`: hablar, examinar las cicatrices y recoger objetos.
- Los lugares se descubren al acercarse y quedan identificados en el mapa.
- El marcador dorado señala el objetivo activo de la misión.

El mapa inicial incluye el Refugio de Maela, Paso de Ceniza, Campo Antiguo,
Torre Derruida y Corazón Corrupto. Sus límites y ubicaciones se encuentran en
`scripts/ui/world_map_ui.gd`, preparados para crecer con nuevos sectores.

## Sistemas reutilizables

- `scripts/npcs/tutorial_npc.gd`: interacción contextual con NPC.
- `scripts/ui/dialogue_ui.gd`: diálogo lineal, pausa segura y callback final.
- `scripts/ui/quest_tracker.gd`: objetivo persistente y notificaciones.
- `scripts/tutorial/first_encounter_controller.gd`: estados y recompensa.
- `scripts/tutorial/frontier_environment.gd`: composición ambiental de la zona.
- `scripts/tutorial/investigation_point.gd`: pistas examinables y emboscadas.
- `scripts/ui/world_map_ui.gd`: minimapa, mapa general, descubrimientos y
  objetivos.

Los enemigos emiten la señal `defeated`, de modo que futuras misiones pueden
contabilizar bajas sin modificar su lógica de combate.

## Arte de la zona

El kit original está en `assets/environment/frontier_pass/`:

- suelo musgoso repetible;
- tierra de camino repetible;
- roble antiguo;
- formación de rocas con musgo;
- mata de hierba alta;
- refugio de guardabosques.
- torre de vigilancia derruida;
- cicatriz de corrupción del campo de batalla.

Maela tiene su propio sprite en
`assets/characters/npcs/maela/maela_idle.png`.
Ivar tiene su propio sprite en
`assets/characters/npcs/ivar/ivar_idle.png`.

`world.tscn` sigue siendo el mapa técnico original. La escena tutorial lo
instancia, oculta allí el piso/árbol y los pickups de prueba, y aplica el nuevo
entorno sin destruir el prototipo base.
