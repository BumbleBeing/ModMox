class_name CostReductionAbility
extends StaticAbility
## A static ability of a spell that makes it cost less to cast (CR 601.2f), such as
## affinity. Each kind is its own subclass and says how much mana it takes off, generic or
## colored; the cast takes that off the cost being paid, the mana cost or an alternative
## cost, by CR 118.7 (see MmManaCost.reduced_by()). The spell's mana value never changes
## (CR 202.3).


## The mana [param spell] costs less for [param player_id] to cast right now, or null for
## none. [param spell] is the card being cast, in the zone it is cast from or on the stack.
func reduction(_state: MmGameState, _spell: MmGameObject, _player_id: int) -> MmManaCost:
	assert(false, "%s must override reduction()." % get_script().resource_path)
	return null


func describe() -> String:
	return "cost reduction"
