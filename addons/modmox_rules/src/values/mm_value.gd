class_name MmValue
extends Resource
## A number in an ability, worked out when it is needed (ADR 0002). Subclasses describe
## one kind each, such as ConstantValue.


## The number this value stands for right now.
func evaluate(_state: MmGameState, _context: MmEffectContext) -> int:
	assert(false, "%s must override evaluate()." % get_script().resource_path)
	return 0
