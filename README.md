# RPG · guía rápida del proyecto

La escena principal es `res://scenes/tutorial/first_encounter.tscn`.

## Dónde editar contenido

- NPC (nombre, retrato y lista de conversaciones): `data/npcs/`.
- Textos y elecciones: `data/dialogues/chapter_01/`.
- Objetos: `data/items/`.
- Cuerpo y habilidades físicas de enemigos: `data/enemies/`.
- Inteligencia, personalidad y capacidades: `data/ai/`.
- Ataques enemigos: `data/attacks/`.
- Flujo del capítulo: `scripts/tutorial/first_encounter_controller.gd`.

Para comparar la IA común 20, élite 50 y jefe 80, abrir
`res://scenes/debug/ai_sandbox.tscn` y ejecutar la escena actual con `F6`.

## Controles principales

- `WASD`: movimiento.
- `F`: interactuar o avanzar diálogo.
- `I`: inventario.
- `M`: mapa.
- `F5`: guardado rápido durante el gameplay.
- `F9`: carga rápida durante el gameplay.

La documentación de arquitectura está en `docs/PROJECT_STRUCTURE.md`, la guía
de IA reutilizable en `docs/COMBAT_AI.md` y la guía para escribir NPC y
conversaciones en `docs/DIALOGUES_AND_NPCS.md`.

## Pruebas rápidas

```text
godot --headless --path . --script res://tests/ai/ai_test_runner.gd
godot --headless --path . --script res://tests/navigation_bake_test.gd
godot --headless --path . --script res://tests/smoke_test.gd
```
