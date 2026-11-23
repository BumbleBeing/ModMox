class_name CantBeBlockedAbility
extends StaticAbility
## "This creature can't be blocked." (CR 509.1b): a restriction on each blocker, so no
## creature may block it. It is not a keyword.


func describe() -> String:
	return "this creature can't be blocked"
