# Guardado y carga

El guardado se escribe como JSON en `user://savegame.json` e incluye nombre,
posición, recursos vitales, inventario, equipo, accesos rápidos, etapa de la
misión, mapa y decisiones narrativas.

- `F5`: guardado rápido.
- `F9`: carga rápida.

Al iniciar, la pantalla de nombre ofrece `Continuar partida guardada` cuando
existe un archivo. El sistema vive en `scripts/core/save_game_manager.gd` y el
estado narrativo global en `scripts/core/game_state.gd`.

