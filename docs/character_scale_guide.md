# Escala visual de personajes 2.5D

La referencia del proyecto es un humano adulto de aproximadamente **115 px de
altura visible en el mundo**, con el origen del nodo colocado a la altura de los
pies.

## Escala canónica

- Jugador: frame de 320 × 384 px, escala `0.30` → 115.2 px de alto.
- NPC humano: imagen de 1024 × 1536 px, escala `0.075` → 115.2 px de alto.
- Centro visual del jugador y NPC humano: aproximadamente `y = -58`.
- El origen lógico y de ordenación Y permanece en `y = 0`, bajo los pies.

## Variaciones permitidas

- Adulto humano estándar: 112–118 px.
- Persona baja/joven: 105–111 px.
- Persona alta: 119–125 px.
- Más de 125 px sólo para criaturas grandes, élites o personajes cuya altura
  tenga una razón narrativa clara.

No se debe escalar el nodo completo para modificar la estatura, porque también
deforma colisiones, distancia de interacción, textos y marcadores. Se modifica
únicamente el `CharacterSprite`; las colisiones se ajustan por separado.
