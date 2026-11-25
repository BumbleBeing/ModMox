class_name SkulkAbility
extends StaticAbility
## The keyword skulk. CR 702.118b: it can't be blocked by creatures with greater power, a
## restriction on each blocker (CR 509.1b), as flying is, asked by CombatProcedure as
## blockers are declared, with the powers they have then. A change of power afterward undoes
## no block. A second instance changes nothing (CR 702.118c).


func describe() -> String:
	return "skulk"
