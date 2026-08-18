# Primer capítulo: El Paso de Maela

La escena principal es `res://scenes/tutorial/first_encounter.tscn`.

## Flujo implementado

1. El jugador elige su nombre.
2. Maela asigna el primer aporte al asentamiento.
3. Ivar entrega una espada y botas incompletas.
4. Nara entrega provisiones y configura los accesos rápidos.
5. El jugador recolecta los recursos del sendero.
6. Una avanzada goblin con combatientes comunes y un guardia élite ocupa la
   antigua zona segura.
7. Tras derrotarla, el jugador informa a Maela.
8. El consejo presenta una decisión: fortificar el refugio o seguir la
   corrupción.
9. La decisión cambia el objetivo y el texto de la primera expedición.
10. El jugador examina el punto marcado y vuelve con Maela.
11. El capítulo termina y la consecuencia queda guardada.

## Sistemas reutilizables

- `data/npcs/`: identidad y conversaciones asignadas a cada NPC.
- `data/dialogues/chapter_01/`: textos, cinemáticas y elecciones.
- `scripts/ui/dialogue_ui.gd`: presentación lineal y ramificada.
- `scripts/core/save_game_manager.gd`: persistencia completa.
- `scripts/core/game_state.gd`: decisiones narrativas globales.
- `scripts/tutorial/first_encounter_controller.gd`: estados del capítulo.
- `scripts/tutorial/investigation_point.gd`: pistas examinables.
- `scripts/ui/world_map_ui.gd`: mapa, descubrimientos y objetivos.
- `data/ai/goblin/`: perfiles de inteligencia goblin de 20, 50 y 80 %.
- `scripts/enemies/ai/`: percepción, memoria, utilidad y táctica reutilizables.

En el encuentro actual, `GoblinScout` y `GoblinForager` usan la variante común
de 20 %, mientras que `GoblinGuard` usa la variante élite de 50 %. El perfil de
jefe de 80 % queda disponible para encuentros posteriores y para el sandbox de
IA `res://scenes/debug/ai_sandbox.tscn`. La explicación de capacidades y
creación de variantes está en `docs/COMBAT_AI.md`.

## Controles del capítulo

- `F`: hablar, continuar y examinar.
- `I`: inventario.
- `M`: mapa.
- `F5`: guardar.
- `F9`: cargar.
