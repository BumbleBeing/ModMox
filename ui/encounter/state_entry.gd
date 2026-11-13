class_name StateEntry
extends RefCounted
## One entry of a State List: something true of a permanent right now that its Card Face
## does not say. The Inspector draws a title and a sentence and knows nothing of what
## kinds of entry there are.

## What it is, or the name of the card it came from.
var title: String = ""
var text: String = ""


func _init(entry_title: String = "", entry_text: String = "") -> void:
	title = entry_title
	text = entry_text
