class_name SpellsCostLessAbility
extends StaticAbility
## "The [Nth] spell you cast each turn costs {[amount]} less to cast" (CR 601.2f), as
## Highspire Bell-Ringer's "The second spell you cast each turn costs {1} less to cast": a
## static ability of a permanent or Emblem that makes its controller's spells cost less,
## unlike a CostReductionAbility, which is the spell's own (engine ADR 0050's addendum). It
## takes off generic mana only (CR 118.7a), never less than none, from the mana cost or an
## alternative cost being paid. With [member nth_each_turn] above 0 it reduces only the
## caster's Nth spell this turn, counting every spell they cast this turn
## (MmPlayer.spells_cast_this_turn), those cast before its permanent was on the battlefield
## too. A spell is counted once it becomes cast (CR 601.2i), so the spell being cast is the
## Nth while N - 1 have been cast. Each instance takes its own amount off. The spell's mana
## value never changes (CR 202.3).

## How much generic mana it takes off.
@export var amount: int = 1
## "The second spell you cast each turn": with N above 0, only the caster's Nth spell this
## turn; with 0, every spell they cast.
@export var nth_each_turn: int = 0


## The mana it takes off a spell [param player_id] begins casting now, or null for none.
## Asked only of an ability whose permanent or Emblem [param player_id] controls.
func reduction(state: MmGameState, player_id: int) -> MmManaCost:
	if nth_each_turn > 0 and state.player(player_id).spells_cast_this_turn != nth_each_turn - 1:
		return null
	var reduced: MmManaCost = MmManaCost.new()
	reduced.generic = maxi(0, amount)
	return reduced


func describe() -> String:
	return "spells cost less"
