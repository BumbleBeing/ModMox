class_name ChooseYesOrNoDecision
extends MmPendingDecision
## The controller of a resolving spell or ability says whether to do what a "you may"
## offers, as that effect begins (CR 603.5, 608.2d). Its targets were chosen already, as it
## was put on the stack (CR 603.3d). Answer: a Choice value.
# Later: a yes or no that is not an effect's, such as Temple Garden's "As this land enters,
# you may pay 2 life", once a card needs one.

enum Choice { YES, NO }

var stack_object_id: int
## What happens on yes, so that what is asked can be put in words. Card data, never
## changed.
var effect: MmEffect


func _init(deciding_player_id: int, object_id: int, offered: MmEffect) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	effect = offered


func validate(answer: Variant) -> String:
	return _check_choice(answer, Choice.size())


func describe() -> String:
	return "player %d: yes or no for object %d" % [player_id, stack_object_id]
