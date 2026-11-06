class_name CountValue
extends MmValue
## "The number of [selection]", such as the number of non-Wall creatures you control.

@export var selection: MmSelection


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	return selection.select(state, context).size()
