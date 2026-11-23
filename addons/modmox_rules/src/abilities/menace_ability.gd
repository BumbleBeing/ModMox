class_name MenaceAbility
extends StaticAbility
## The keyword menace. CR 702.111b: it can't be blocked except by two or more creatures, a
## restriction on the whole declaration of blockers (CR 509.1b), checked by
## DeclareBlockersDecision once every block is made.


func describe() -> String:
	return "menace"
