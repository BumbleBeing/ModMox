class_name SumValue
extends MmValue
## "[a] plus [b]", or "[a] plus [b] plus [c]": every addend added up, such as the number of
## creatures you control plus the number of Equipment you control. A permanent counted by
## two addends counts in each. With no addends, 0.

@export var addends: Array[MmValue] = []


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	var total: int = 0
	for addend: MmValue in addends:
		total += addend.evaluate(state, context)
	return total
