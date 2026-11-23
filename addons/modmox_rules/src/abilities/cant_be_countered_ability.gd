class_name CantBeCounteredAbility
extends StaticAbility
## "This spell can't be countered." It works while its card is a spell on the stack, where
## CounterEffect passes over it: a counter may still target it, and resolves doing nothing
## to it, since "can't" beats "can" (CR 101.2). It is not a keyword.


func describe() -> String:
	return "this spell can't be countered"
