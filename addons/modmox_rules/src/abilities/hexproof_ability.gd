class_name HexproofAbility
extends StaticAbility
## The keyword hexproof (CR 702.11b): "This permanent can't be the target of spells or
## abilities your opponents control." HexproofRules asks whether a permanent has it against
## a player.
# Later: "hexproof from [quality]" (CR 702.11d), once a card has it.


func describe() -> String:
	return "hexproof"
