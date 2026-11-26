class_name AlternativeCostAbility
extends StaticAbility
## "You may pay [mana cost] and [costs] rather than pay this spell's mana cost" (CR 118.9,
## engine ADR 0093), as Zahid, Djinn of the Lamp's "You may pay {3}{U} and tap an untapped
## artifact you control rather than pay this spell's mana cost." Its card is offered a second
## cast from the hand, after the first, as a card with bestow is, for [member mana_cost] and
## [member costs]. The costs that ask a choice are asked before the mana is paid, as a
## flashback cost's are (CR 601.2h), so a permanent tapped for one can't also pay mana.
## Cost reductions take mana off it as they do off a mana cost (CR 118.7), and an additional
## cost is paid with it (CR 118.8). The spell's mana value is still its mana cost's
## (CR 118.9c, 202.3). It does nothing on the battlefield.
# Later: casting for an alternative cost from another zone than the hand, once a card that
# is cast from one has such a cost (CR 118.9a allows only one alternative cost at a time).

## The mana part of the cost paid instead of the mana cost. Null when it has no mana in it.
@export var mana_cost: MmManaCost = null
## Every other part of that cost, such as tapping an untapped artifact you control.
@export var costs: Array[MmCost] = []


func describe() -> String:
	return "alternative cost (%d other costs)" % costs.size()
