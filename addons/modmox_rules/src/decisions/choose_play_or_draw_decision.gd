class_name ChoosePlayOrDrawDecision
extends MmPendingDecision
## The chooser decides whether to play first or let the other player start (CR 103.1).
## Answer: a Choice value.

enum Choice { PLAY, DRAW }


func validate(answer: Variant) -> String:
	return _check_choice(answer, Choice.size())


func describe() -> String:
	return "player %d: play or draw" % player_id
