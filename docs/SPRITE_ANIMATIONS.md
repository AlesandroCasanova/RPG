# Animaciones de personajes

## Hojas actuales

Las nuevas hojas cardinales están organizadas en una grilla de cuatro columnas
por cuatro filas:

- fila 1: sur;
- fila 2: oeste;
- fila 3: norte;
- fila 4: este.

Las columnas representan cuatro fases consecutivas de la acción. El cargador
`res://scripts/animation/sprite_sheet_animation.gd` calcula el tamaño de cada
celda desde la textura, por lo que admite hojas con distintas resoluciones.

## Jugador

En `res://assets/characters/player/sprites/actions/`:

- caminar;
- caminar agachado;
- ataque con espada;
- dash con estela azul.

El idle conserva las ocho orientaciones originales. Para las acciones nuevas,
las diagonales se resuelven hacia la orientación cardinal más cercana.

## Goblin

En `res://assets/characters/enemies/goblin/sprites/actions/`:

- caminar;
- ataque con espada corta y escudo.

Las animaciones se reproducen desde los estados reales de navegación y ataque,
no desde temporizadores visuales independientes.
