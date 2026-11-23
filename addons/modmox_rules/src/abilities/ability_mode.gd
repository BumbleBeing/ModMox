class_name AbilityMode
extends Resource
## One mode of a modal spell or modal triggered ability (CR 700.2): a "•" line after "Choose
## one —", with its own target requirements and effects. Its targets are numbered from 0,
## since exactly one mode is chosen (ADR 0046).

@export var targets: Array[TargetRequirement] = []
@export var effects: Array[MmEffect] = []
## The target requirements an overload changed to "each" (CR 702.96b, ADR 0014), numbered
## as they were; its effects find what each could have chosen through OverloadedSelection.
@export var overloaded_targets: Array[TargetRequirement] = []

