class_name CostReductionAbility
extends StaticAbility
## A static ability of a spell that makes it cost less to cast (CR 601.2f): "This spell costs
## {1} less to cast for each [amount]", as Leyline Binding's "for each basic land type among
## lands you control" is. It takes off generic mana only, as much as [member amount] comes
## to for the caster, never less than none (CR 107.1b). A kind of reduction that works out
## its mana another way, such as affinity, is a subclass that overrides reduction(). The
## cast takes the mana off the cost being paid, the mana cost or an alternative cost, by
## CR 118.7 (see MmManaCost.reduced_by()). The spell's mana value never changes (CR 202.3).

## How much generic mana it takes off, worked out with the caster as "you" and the spell as
## its source. Unused by a subclass that overrides reduction().
@export var amount: MmValue


## The mana [param spell] costs less for [param player_id] to cast right now, or null for
## none. [param spell] is the card being cast, in the zone it is cast from or on the stack.
func reduction(state: MmGameState, spell: MmGameObject, player_id: int) -> MmManaCost:
	var reduced: MmManaCost = MmManaCost.new()
	if amount != null:
		reduced.generic = maxi(0, amount.evaluate(state, MmEffectContext.new(player_id, spell.id)))
	return reduced


func describe() -> String:
	return "cost reduction"
