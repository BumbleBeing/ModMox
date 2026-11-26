class_name UndyingAbility
extends TriggeredAbility
## The keyword undying (CR 702.93a): "When this creature dies, if it had no +1/+1 counters on
## it, return it to the battlefield under its owner's control with a +1/+1 counter on it."
## Authored with nothing: it is made with its trigger, its intervening "if" and its effect,
## which are saved with it like any triggered ability's, so a Modification changes them the
## same way, as EvolveAbility is. The "if" reads the creature as it last existed on the
## battlefield, as it triggers and again as it resolves (CR 603.4, 603.10a). "It" is the card
## the creature became in the graveyard (TriggeringCardSelection, engine ADR 0096), so a card
## that has left the graveyard by then stays where it is, and a token never comes back
## (CR 111.8).


func _init() -> void:
	var dies: ZoneChangeTrigger = ZoneChangeTrigger.new()
	dies.any_from_zone = false
	dies.from_zone = MmZone.Kind.BATTLEFIELD
	dies.to_zone = MmZone.Kind.GRAVEYARD
	dies.filter = IsSourceFilter.new()
	trigger = dies
	var with_counter: HasCountersFilter = HasCountersFilter.new()
	with_counter.kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
	var none: NotFilter = NotFilter.new()
	none.filter = with_counter
	var had_none: SelectionMatchesCondition = SelectionMatchesCondition.new()
	had_none.selection = TriggeringObjectSelection.new()
	had_none.filter = none
	condition = had_none
	var one: ConstantValue = ConstantValue.new()
	one.value = 1
	var back: ReturnToBattlefieldEffect = ReturnToBattlefieldEffect.new()
	back.selection = TriggeringCardSelection.new()
	back.counters = one
	back.counter_kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
	effects = [back]


func describe() -> String:
	return "undying"
