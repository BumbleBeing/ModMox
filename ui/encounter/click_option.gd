class_name ClickOption
extends RefCounted
## One thing a click can answer: a row of the Option Menu (game glossary) when the thing
## clicked offers more than one.

## The answer to submit to the Pending Decision.
var answer: int
## What the option is, in full: an ability's cost and effect, or a spell's name.
var text: String
## Whether it activates a mana ability.
var is_mana: bool


func _init(option_answer: int, option_text: String, is_mana_ability: bool = false) -> void:
	answer = option_answer
	text = option_text
	is_mana = is_mana_ability
