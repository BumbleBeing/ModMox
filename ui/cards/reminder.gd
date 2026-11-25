class_name Reminder
extends RefCounted
## What one keyword means, as the Inspector lists it beside its Keyword Icon.

## The file name of its Keyword Icon in ui/sprites/keywords/, or "" for a keyword with no
## Keyword Chip, which is listed with no icon (engine ADR 0089).
var icon: String = ""
## The keyword as the card has it, such as "Flying" or "Protection from black".
var keyword: String = ""
var text: String = ""
