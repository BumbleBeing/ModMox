class_name MmCondition
extends Resource
## Something true or false about the game right now, such as "this permanent is
## untapped". Used for intervening "if" clauses (CR 603.4). Subclasses describe one kind
## each.


func is_true(_state: MmGameState, _context: MmEffectContext) -> bool:
	assert(false, "%s must override is_true()." % get_script().resource_path)
	return false
