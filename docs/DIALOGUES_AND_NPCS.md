# Editar NPC y diálogos

## Cambiar un NPC

Los archivos principales son `data/npcs/maela.tres`, `ivar.tres` y `nara.tres`.
Cada uno contiene `npc_id`, `display_name`, `portrait`, el texto de interacción
y la lista de conversaciones. Cambiar `display_name` actualiza el nombre del
diálogo normal y el aviso `[F] Hablar con ...`.

## Cambiar textos

Las conversaciones están en `data/dialogues/chapter_01/`. Cada recurso tiene
`dialogue_id`, entradas y elecciones. En un diálogo perteneciente a un NPC se
puede dejar `speaker` vacío para usar automáticamente su nombre y retrato.

El token `{player_name}` inserta el nombre elegido al comenzar.

## Añadir una conversación

1. Crear un `DialogueData` dentro de `data/dialogues/<capítulo>/`.
2. Agregar entradas `DialogueEntryData` desde el inspector.
3. Añadir el recurso a `dialogues` dentro del archivo del NPC.
4. Mostrarlo desde la misión:

```gdscript
dialogue.show_npc_dialogue(npc.npc_data, &"dialogue_id", callback)
```

Para conversaciones grupales se usa `show_dialogue_data`. Si contiene
elecciones, el callback recibe el `choice_id` seleccionado.

