class_name WardAbility
extends TriggeredAbility
## The keyword "Ward [cost]" (CR 702.21a, ADR 0062): "Whenever this permanent becomes the
## target of a spell or ability an opponent controls, counter it unless that player pays
## [cost]." Authored with its [member mana_cost] alone: it is made with its trigger and its
## effect, which are saved with it like any triggered ability's, so a Modification changes
## them the same way.
# Later: a ward cost that is not mana ("Ward—Pay 3 life"), once a card has one.

## The ward cost. Setting it changes what the effect this ability made asks to be paid.
@export var mana_cost: MmManaCost = null:
	set(value):
		mana_cost = value
		if effects.size() == 1 and effects[0] == _made_effect:
			_made_effect.unless_paid = value

## The effect this ability made for itself, so a later [member mana_cost] changes it and
## nothing else.
var _made_effect: CounterEffect = null


func _init() -> void:
	var becomes_target: BecomesTargetTrigger = BecomesTargetTrigger.new()
	becomes_target.filter = IsSourceFilter.new()
	becomes_target.whose = MmTrigger.Whose.OPPONENT
	trigger = becomes_target
	_made_effect = CounterEffect.new()
	_made_effect.selection = TriggeringObjectSelection.new()
	_made_effect.unless_paid = mana_cost
	effects = [_made_effect]


func describe() -> String:
	return "ward"
