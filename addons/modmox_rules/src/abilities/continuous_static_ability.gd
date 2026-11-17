class_name ContinuousStaticAbility
extends StaticAbility
## A static ability that changes characteristics through continuous effects, such as
## "White creatures get +1/+1" (CR 604.2, 611.3). Its effects apply to whatever matches
## right now, from the moment its source is on the battlefield or in the command zone, with
## its source's timestamp (CR 613.7a). With a [member condition] it reads "As long as
## [condition], [effects]", and its effects apply only while the condition is true.

@export var effects: Array[MmContinuousEffect] = []
## Asked of the game as it is right now, as its effects are about to apply (CR 611.3a).
@export var condition: MmCondition = null


func describe() -> String:
	return "static ability (%d continuous effects)" % effects.size()
