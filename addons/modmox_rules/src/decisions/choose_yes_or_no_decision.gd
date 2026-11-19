class_name ChooseYesOrNoDecision
extends MmPendingDecision
## A player says yes or no as an effect of a resolving spell or ability begins (CR 608.2d):
## its controller, whether to do what a "you may" offers (CR 603.5), or, with a [member cost],
## the player who may pay it, whether to pay it to keep a spell or ability from being
## countered, as for ward (CR 118.12, 702.21a, ADR 0062). Its targets were chosen already, as
## it was put on the stack (CR 603.3d). Answer: a Choice value; yes to a cost is paid one
## PayManaDecision at a time, as a cast's mana is.
# Later: a yes or no that is not an effect's, such as Temple Garden's "As this land enters,
# you may pay 2 life", once a card needs one.

enum Choice { YES, NO }

var stack_object_id: int
## What the question is about, so that it can be put in words: what happens on yes for a
## "you may", and the effect that counters unless the cost is paid for one with a
## [member cost]. Card data, never changed.
var effect: MmEffect
## What saying yes pays, or null for a "you may", where yes pays nothing. Card data, never
## changed.
var cost: MmManaCost


func _init(deciding_player_id: int, object_id: int, offered: MmEffect, to_pay: MmManaCost = null) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	effect = offered
	cost = to_pay


func validate(answer: Variant) -> String:
	return _check_choice(answer, Choice.size())


func describe() -> String:
	if cost != null:
		return "player %d: pay %s or not for object %d" % [player_id, cost.describe(), stack_object_id]
	return "player %d: yes or no for object %d" % [player_id, stack_object_id]
