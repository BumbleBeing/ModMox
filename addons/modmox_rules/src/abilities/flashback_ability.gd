class_name FlashbackAbility
extends StaticAbility
## The keyword "Flashback [cost]" (CR 702.34a): its card may be cast from its owner's
## graveyard by paying this cost instead of its mana cost (an alternative cost, CR 118.9),
## with its card type's usual timing. Cast that way, it is exiled instead of going anywhere
## else whenever it would leave the stack. The cost is [member mana_cost], null when it has
## no mana in it (Group Project's "Tap three untapped creatures you control"), and
## [member costs], paid once the mana is (CR 601.2h), as an activated ability's are.

## The mana part of the flashback cost. Null when it has no mana in it.
@export var mana_cost: MmManaCost = null
## Every other part of the flashback cost, such as "Pay 3 life".
@export var costs: Array[MmCost] = []


func describe() -> String:
	return "flashback (%d other costs)" % costs.size()
