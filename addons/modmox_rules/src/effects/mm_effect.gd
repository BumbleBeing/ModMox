class_name MmEffect
extends Resource
## One thing an ability does, such as adding mana. Subclasses describe one kind each.


## Carries out this effect through events.
func resolve(_state: MmGameState, _context: MmEffectContext) -> void:
	assert(false, "%s must override resolve()." % get_script().resource_path)


## Whether this effect has a target (CR 115). Used to classify mana abilities.
func has_targets() -> bool:
	return false


## Whether this effect could add mana (CR 605.1a). Used to classify mana abilities.
func adds_mana() -> bool:
	return false
