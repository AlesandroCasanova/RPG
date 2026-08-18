class_name DialogueEntryData
extends Resource


@export var speaker: String = ""
@export_multiline var text: String = ""
@export_enum("left", "right") var side: String = "right"
@export var portrait: Texture2D

