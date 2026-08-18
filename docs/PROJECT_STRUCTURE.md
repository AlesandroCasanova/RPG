# Organización del proyecto

La estructura actual es correcta para un RPG de este tamaño. Separa el arte,
los datos editables, las escenas y la lógica. No conviene agrupar todo por
capítulo porque inventario, combate, UI y NPC son sistemas reutilizables.

```text
assets/                     Arte fuente organizado por dominio
data/                       Recursos editables desde el inspector
  dialogues/chapter_01/     Conversaciones y decisiones del capítulo
  npcs/                     Identidad, retrato y diálogos de cada NPC
  items/                    Consumibles, equipo y materiales
  enemies/                  Cuerpo, estadísticas y habilidades físicas
  ai/                       Inteligencia, personalidad y capacidades
  attacks/                  Ataques reutilizables por especie
scenes/                     Composición de nodos por dominio
  enemies/base/             Actor enemigo común
  enemies/<especie>/        Variantes listas para instanciar
  debug/                    Sandboxes manuales aislados
scripts/
  core/                     Estado global y guardado/carga
  dialogue/                 Clases de recursos narrativos
  enemies/ai/               Percepción, utilidad y táctica reutilizables
  enemies/base/             Ejecución física común de enemigos
  npcs/ player/ items/      Lógica de gameplay por dominio
  tutorial/                 Orquestación exclusiva del capítulo inicial
  ui/                       Interfaces reutilizables
tests/                      Pruebas automáticas sin interfaz
  ai/                       Capacidades, decisiones y percepción enemiga
  navigation_bake_test.gd   Rutas alrededor de colliders del escenario
docs/                       Guías de edición y arquitectura
```

## Reglas para mantenerla cómoda

1. El contenido se guarda en `data/`; la lógica, en `scripts/`.
2. Una escena no debe contener párrafos largos de diálogo.
3. Los sistemas globales van en `scripts/core/`, no en el controlador del mapa.
4. Cada capítulo puede tener su carpeta dentro de `data/dialogues/`.
5. No se deben mover recursos que ya tienen rutas estables sin una necesidad
   concreta: Godot puede actualizar referencias, pero los `preload` escritos en
   código necesitan revisión manual.
6. Una variante enemiga combina recursos; no debe copiar `enemy.gd` solo para
   cambiar inteligencia o personalidad.
7. La inteligencia se configura en `data/ai/`; dash, ataques disponibles y
   otras herramientas físicas se configuran en `data/enemies/`.

La guía completa para crear perfiles y variantes enemigas está en
`docs/COMBAT_AI.md`.

El siguiente crecimiento natural sería crear `scenes/chapters/chapter_02/` o
`scenes/regions/` cuando exista un segundo mapa real. Todavía no hace falta.
