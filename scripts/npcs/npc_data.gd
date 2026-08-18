class_name NPCData
extends Resource


@export_category("Identidad")
@export var npc_id: StringName = &"npc"
@export var display_name: String = "Personaje"
@export var portrait: Texture2D
@export var interaction_text: String = "[F] Hablar con {name}"

@export_category("Diálogos")
@export var dialogues: Array[DialogueData] = []


func get_dialogue(dialogue_id: StringName) -> DialogueData:
	for dialogue: DialogueData in dialogues:
		if dialogue != null and dialogue.dialogue_id == dialogue_id:
			return dialogue
	return null


func get_interaction_text() -> String:
	return interaction_text.replace("{name}", display_name)
