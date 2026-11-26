class_name MentorAbility
extends TriggeredAbility
## The keyword mentor (CR 702.134a): "Whenever this creature attacks, put a +1/+1 counter on
## target attacking creature with lesser power." Authored with nothing: it is made with its
## trigger, its target and its effect, which are saved with it like any triggered ability's,
## as BattleCryAbility is. "Lesser power" is this creature's power less one or less, worked
## out each time the target is checked, so a target as strong as this creature by then is
## illegal as it resolves (CR 608.2b), and a mentor that has left is compared as it last
## existed (PowerValue). Each instance triggers on its own (CR 702.134b).


func _init() -> void:
	var attacks: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	attacks.filter = IsSourceFilter.new()
	trigger = attacks
	var this_power: PowerValue = PowerValue.new()
	this_power.selection = SourceSelection.new()
	var one: ConstantValue = ConstantValue.new()
	one.value = 1
	var less_one: DifferenceValue = DifferenceValue.new()
	less_one.minuend = this_power
	less_one.subtrahend = one
	var lesser_power: PowerFilter = PowerFilter.new()
	lesser_power.comparison = PowerFilter.Comparison.OR_LESS
	lesser_power.amount_value = less_one
	var attacking_creature: AllOfFilter = AllOfFilter.new()
	attacking_creature.filters = [HasCardTypeFilter.new(), IsAttackingFilter.new(), lesser_power]
	var requirement: TargetRequirement = TargetRequirement.new()
	requirement.filter = attacking_creature
	targets = [requirement]
	var counter_amount: ConstantValue = ConstantValue.new()
	counter_amount.value = 1
	var counter: PutCountersEffect = PutCountersEffect.new()
	counter.kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
	counter.amount = counter_amount
	counter.recipients = TargetSelection.new()
	effects = [counter]


func describe() -> String:
	return "mentor"
