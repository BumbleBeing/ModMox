class_name MmEffect
extends Resource
## One thing a spell or ability does, such as dealing damage. Subclasses describe one kind
## each, and refer to who or what they affect only through Selections (ADR 0014).


## Carries out this effect through events.
func resolve(_state: MmGameState, _context: MmEffectContext) -> void:
	assert(false, "%s must override resolve()." % get_script().resource_path)


## The Selections this effect uses. Subclasses with Selections override this.
func selections() -> Array[MmSelection]:
	return []


## Whether this effect uses a target (CR 115). Worked out from its Selections.
func has_targets() -> bool:
	for selection: MmSelection in selections():
		if selection != null and selection.is_targeted():
			return true
	return false


## Whether this effect could add mana (CR 605.1a). Used to classify mana abilities.
func adds_mana() -> bool:
	return false
