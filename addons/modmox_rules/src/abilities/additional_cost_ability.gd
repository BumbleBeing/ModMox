class_name AdditionalCostAbility
extends StaticAbility
## "As an additional cost to cast this spell, [costs]" (CR 601.2f, 118.8), as Fear of
## Isolation's "return a permanent you control to its owner's hand". It works only as its card
## is cast: the spell is offered only while every one of [member costs] can be paid, and
## CastProcedure adds them to the rest of the cost, a flashback cost's included. Each that
## asks a choice is asked once the mana is paid (CR 601.2g-h, engine ADR 0086), so a land just
## tapped for mana may be returned; the rest are paid with it. A cost paid stays paid whatever
## becomes of the spell. It does nothing on the battlefield.
##
## With [member or_mana_cost] or [member or_costs] it reads "[costs] or [the other costs]", as
## Bayou Groff's "sacrifice a creature or pay {3}" (CR 601.2b, engine ADR 0086's third
## addendum): its card is offered a second cast from the hand, after the first, as a card with
## an alternative cost is, that pays the other costs instead, its mana added to the mana cost
## (CR 601.2f). The spell's mana value is still its mana cost's (CR 202.3).
# Later: the choice for a card cast from anywhere but the hand, and with an alternative cost
# or bestowed, once a card has both.

@export var costs: Array[MmCost] = []
## The mana of the other choice, or null for none.
@export var or_mana_cost: MmManaCost = null
## The other choice's costs besides its mana.
@export var or_costs: Array[MmCost] = []


## Whether there is another choice of costs: "[costs] or [the other costs]".
func has_choice() -> bool:
	return or_mana_cost != null or not or_costs.is_empty()


## The costs besides mana paid for [param other], the other choice, or for the first.
func costs_for(other: bool) -> Array[MmCost]:
	return or_costs if other and has_choice() else costs


## The mana paid for [param other], the other choice, or for the first, which has none.
func mana_for(other: bool) -> MmManaCost:
	return or_mana_cost if other else null
