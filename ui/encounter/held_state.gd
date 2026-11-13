class_name HeldState
extends RefCounted
## What the Emblems and Potions buttons say about what a player holds (ADR 0032, A526): a
## button glows while something could be used now, has its own color while anything is
## left to use or always works, and is gray otherwise.

enum Look { GRAY, PLAIN, GLOWING }


## Whether a click answers something on [param held], an Emblem or a Potion.
static func is_usable(held: MmObjectView, clicks: DecisionClicks) -> bool:
	return not clicks.options_of(held.id).is_empty()


## Whether [param emblem] has nothing left to give: it has abilities, and every one is a
## once-each-game ability that is Spent. One with a static or triggered ability, or an
## ability that can be activated again, is never used up.
static func is_used_up(emblem: MmObjectView) -> bool:
	if emblem.abilities.is_empty():
		return false
	for index: int in emblem.abilities.size():
		var activated: ActivatedAbility = emblem.abilities[index] as ActivatedAbility
		if activated == null or not activated.is_once_each_game or not emblem.spent_ability_indexes.has(index):
			return false
	return true


## How the Emblems button of the player who controls [param emblems] looks.
static func emblems_look(emblems: Array[MmObjectView], clicks: DecisionClicks) -> Look:
	var is_any_left: bool = false
	for emblem: MmObjectView in emblems:
		if is_usable(emblem, clicks):
			return Look.GLOWING
		if not is_used_up(emblem):
			is_any_left = true
	return Look.PLAIN if is_any_left else Look.GRAY


## How the Potions button of the player who holds [param potions] looks.
static func potions_look(potions: Array[MmObjectView], clicks: DecisionClicks) -> Look:
	for potion: MmObjectView in potions:
		if is_usable(potion, clicks):
			return Look.GLOWING
	return Look.GRAY if potions.is_empty() else Look.PLAIN
