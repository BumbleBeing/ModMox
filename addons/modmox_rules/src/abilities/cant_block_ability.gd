class_name CantBlockAbility
extends StaticAbility
## "This creature can't block." (CR 509.1a): a restriction on its controller's declaration of
## blockers, so it is never among them, as Phoenix Chick says. It is not a keyword.


func describe() -> String:
	return "this creature can't block"
