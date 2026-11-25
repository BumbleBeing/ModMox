class_name BestowAbility
extends StaticAbility
## The keyword "Bestow [cost]" (CR 702.103a, engine ADR 0089): "As you cast this spell, you
## may choose to cast it bestowed. If you do, you pay [cost] rather than its mana cost." Its
## card is offered a second cast from the hand, after the first, as an Adventurer card is,
## for [member mana_cost], an alternative cost (CR 118.9) that cost reductions take mana
## off as they do a mana cost. Bestowed, the spell is an Aura enchantment with enchant
## creature that has lost the creature type and its creature subtypes (CR 702.103b), which
## BestowRules makes of its characteristics while the object is bestowed, on the stack and
## on the battlefield. It resolves attached to its target, or ceases to be bestowed and
## resolves as an enchantment creature if that target is gone (CR 702.103e). Once it becomes
## unattached it ceases to be bestowed and stays on the battlefield, an enchantment creature
## again (CR 702.103f). Its mana value is its mana cost's (CR 202.3).
# Later: bestow from another zone than the hand, and a copy of a bestowed spell, once a card
# can do either.

## The cost paid instead of its mana cost.
@export var mana_cost: MmManaCost = null

## The enchant ability a bestowed object gains, made once.
var _enchant_creature: EnchantAbility = null


## "Enchant creature", which a bestowed object gains (CR 702.103b). Card data: never changed
## once made.
func enchant_creature() -> EnchantAbility:
	if _enchant_creature == null:
		_enchant_creature = EnchantAbility.new()
		_enchant_creature.filter = HasCardTypeFilter.new()  # Its card type is CREATURE.
	return _enchant_creature


func describe() -> String:
	return "bestow"
