class_name DamageStaysAbility
extends StaticAbility
## "Damage isn't removed from this permanent during cleanup steps" (an exception to\n## CR 514.2).


func describe() -> String:
	return "damage isn't removed during cleanup"
