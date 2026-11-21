class_name ClickOption
extends RefCounted
## One thing a click can answer: a row of the Option Menu (game glossary) when the thing
## clicked offers more than one.

## The answer to submit to the Pending Decision.
var answer: int
## What the option is, in full: an ability's cost and effect, or a spell's name. The Info
## Panel shows it while the cursor is on the option's row.
var text: String
## What the option's row of the Option Menu reads: text, or for one color of mana of any
## color only "Add {W}" (game ADR 0073).
var row_text: String
## Whether it activates a mana ability.
var is_mana: bool
## The color of mana it makes, an MmMana.Type, when it is one of the colors of an ability
## that adds mana of any color (engine ADR 0072); MmMana.NO_TYPE for anything else.
var mana_type: int = MmMana.NO_TYPE
## Whether its row of the Option Menu glows green: a color that pays something still owed
## while the Hero pays by hand (game ADR 0073).
var has_glow: bool = false


func _init(option_answer: int, option_text: String, is_mana_ability: bool = false) -> void:
	answer = option_answer
	text = option_text
	row_text = option_text
	is_mana = is_mana_ability
