class_name EvolveAbility
extends TriggeredAbility
## The keyword evolve (CR 702.100a): "Whenever a creature you control enters, if that
## creature has greater power or toughness than this creature, put a +1/+1 counter on this
## creature." Authored with nothing: it is made with its trigger, its intervening "if" and its
## effect, which are saved with it like any triggered ability's, so a Modification changes
## them the same way, as BattleCryAbility is. The "if" compares as it triggers and again as
## it resolves (CR 702.100b, 603.4), a creature that has left by then as it last existed
## (CR 608.2h). A noncreature permanent never triggers it (CR 702.100c), and nor does its own
## creature, which is not greater than itself. Each instance triggers on its own
## (CR 702.100d).


func _init() -> void:
	var enters: ZoneChangeTrigger = ZoneChangeTrigger.new()
	enters.to_zone = MmZone.Kind.BATTLEFIELD
	enters.filter = HasCardTypeFilter.new()
	enters.whose = MmTrigger.Whose.YOU
	trigger = enters
	var greater: AnyOfFilter = AnyOfFilter.new()
	greater.filters = [_greater_power(), _greater_toughness()]
	var bigger: SelectionMatchesCondition = SelectionMatchesCondition.new()
	bigger.selection = TriggeringObjectSelection.new()
	bigger.filter = greater
	condition = bigger
	var counter: PutCountersEffect = PutCountersEffect.new()
	counter.kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
	counter.amount = _one()
	counter.recipients = SourceSelection.new()
	effects = [counter]


func describe() -> String:
	return "evolve"


## "With greater power than this creature": this creature's power plus 1, or greater.
func _greater_power() -> PowerFilter:
	var power: PowerValue = PowerValue.new()
	power.selection = SourceSelection.new()
	var filter: PowerFilter = PowerFilter.new()
	filter.comparison = PowerFilter.Comparison.OR_GREATER
	filter.amount_value = _plus_one(power)
	return filter


## "With greater toughness than this creature": this creature's toughness plus 1, or greater.
func _greater_toughness() -> ToughnessFilter:
	var toughness: ToughnessValue = ToughnessValue.new()
	toughness.selection = SourceSelection.new()
	var filter: ToughnessFilter = ToughnessFilter.new()
	filter.comparison = ToughnessFilter.Comparison.OR_GREATER
	filter.amount_value = _plus_one(toughness)
	return filter


func _plus_one(value: MmValue) -> SumValue:
	var sum: SumValue = SumValue.new()
	sum.addends = [value, _one()]
	return sum


func _one() -> ConstantValue:
	var one: ConstantValue = ConstantValue.new()
	one.value = 1
	return one
