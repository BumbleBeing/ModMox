class_name AdditionalLandPlaysAbility
extends StaticAbility
## "You may play [count] additional lands on each of your turns" (CR 305.2), from a
## permanent or an Emblem its controller controls.

@export var count: int = 1


func describe() -> String:
	return "%d additional land plays" % count
