class_name ChooseYesOrNoDecision
extends MmPendingDecision
## A player says yes or no as an effect of a resolving spell or ability begins (CR 608.2d):
## its controller, whether to do what a "you may" offers (CR 603.5), or, with a [member cost],
## the player who may pay it, whether to pay it to keep a spell or ability from being
## countered, as for ward (CR 118.12, 702.21a, ADR 0062). Its targets were chosen already, as
## it was put on the stack (CR 603.3d). Or, with an [member entry_cost], the player playing a
## land with an AsEntersPayOrEntersTappedAbility, whether to pay it so that the land enters
## untapped, asked before it moves (CR 614.12, ADR 0052). Answer: a Choice value; yes to a
## [member cost] is paid one PayManaDecision at a time, as a cast's mana is, and yes to an
## [member entry_cost] at once.

enum Choice { YES, NO }

## The spell or ability asking, or 0 for a question asked as a permanent enters.
var stack_object_id: int
## What the question is about, so that it can be put in words: what happens on yes for a
## "you may", and the effect that counters unless the cost is paid for one with a
## [member cost]. Card data, never changed.
var effect: MmEffect
## What saying yes pays, or null for a "you may", where yes pays nothing. Card data, never
## changed.
var cost: MmManaCost
## The permanent asked about as it enters, still where it is coming from, or 0.
var entering_object_id: int = 0
## What saying yes pays as that permanent enters, such as 2 life, or null. Card data, never
## changed.
var entry_cost: MmCost = null


func _init(deciding_player_id: int, object_id: int, offered: MmEffect, to_pay: MmManaCost = null) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	effect = offered
	cost = to_pay


## Whether to pay [param to_pay] so that [param entering_id] enters untapped (ADR 0052).
static func as_entering(deciding_player_id: int, entering_id: int, to_pay: MmCost) -> ChooseYesOrNoDecision:
	var asked: ChooseYesOrNoDecision = ChooseYesOrNoDecision.new(deciding_player_id, 0, null)
	asked.entering_object_id = entering_id
	asked.entry_cost = to_pay
	return asked


func validate(answer: Variant) -> String:
	return _check_choice(answer, Choice.size())


func describe() -> String:
	if entry_cost != null:
		return "player %d: pay or not as object %d enters" % [player_id, entering_object_id]
	if cost != null:
		return "player %d: pay %s or not for object %d" % [player_id, cost.describe(), stack_object_id]
	return "player %d: yes or no for object %d" % [player_id, stack_object_id]
