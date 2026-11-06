class_name ContinuousStaticAbility
extends StaticAbility
## A static ability that changes characteristics through continuous effects, such as
## "White creatures get +1/+1" (CR 604.2, 611.3). Its effects apply to whatever matches
## right now, from the moment its source is on the battlefield or in the command zone, with
## its source's timestamp (CR 613.7a).

@export var effects: Array[MmContinuousEffect] = []


func describe() -> String:
	return "static ability (%d continuous effects)" % effects.size()
