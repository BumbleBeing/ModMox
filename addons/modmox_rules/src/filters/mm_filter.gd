class_name MmFilter
extends Resource
## A condition a player or Game Object either meets or does not, such as "is a creature"
## (ADR 0002). Filters combine with AllOfFilter (and), AnyOfFilter (or) and NotFilter, so
## one vocabulary serves targeting, "each" effects, static abilities and searches.


## Whether [param candidate] meets this condition right now.
func matches(_state: MmGameState, _candidate: MmReference, _context: MmEffectContext) -> bool:
	assert(false, "%s must override matches()." % get_script().resource_path)
	return false
