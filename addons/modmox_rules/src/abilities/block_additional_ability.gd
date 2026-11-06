class_name BlockAdditionalAbility
extends StaticAbility
## "This creature can block [count] additional creatures each combat" (CR 509.1a). Each
## extra block must be of a different attacker; the defending player divides its combat
## damage among the attackers it blocks (CR 510.1d).

## A rule parameter rather than an amount in an effect, so a plain number (A121).
@export var count: int = 1


func describe() -> String:
	return "can block %d additional creatures" % count
