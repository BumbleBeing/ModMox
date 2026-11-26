class_name SpellsCantBeCounteredAbility
extends StaticAbility
## "[filter] spells you control can't be countered", as Destiny Spinner's "Creature and
## enchantment spells you control can't be countered." (engine ADR 0062's second addendum): a static
## ability of a permanent, working while it is on the battlefield, for each spell its
## controller controls that matches [member filter]. CounterRules asks it beside a spell's own
## CantBeCounteredAbility: a counter may still target such a spell, and resolves doing nothing
## to it, since "can't" beats "can" (CR 101.2). "You control" is part of the words, so the
## filter leaves it out. It is not a keyword.

@export var filter: MmFilter


func describe() -> String:
	return "spells you control can't be countered"
