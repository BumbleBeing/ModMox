class_name SpellMode
extends Resource
## One mode of a modal spell (CR 700.2): a "•" line after "Choose one —", with its own
## target requirements and effects. Its targets are numbered from 0, since exactly one mode
## is chosen (ADR 0046).

@export var targets: Array[TargetRequirement] = []
@export var effects: Array[MmEffect] = []
