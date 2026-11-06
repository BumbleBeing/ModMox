class_name ConstantValue
extends MmValue
## A fixed number, such as the 2 in "Add {R}{R}".

@export var value: int = 0


func evaluate(_state: MmGameState, _context: MmEffectContext) -> int:
	return value
