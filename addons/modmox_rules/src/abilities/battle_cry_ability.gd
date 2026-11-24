class_name BattleCryAbility
extends TriggeredAbility
## The keyword battle cry (CR 702.91a): "Whenever this creature attacks, each other attacking
## creature gets +1/+0 until end of turn." Authored with nothing: it is made with its trigger
## and its effect, which are saved with it like any triggered ability's, so a Modification
## changes them the same way, as ExaltedAbility is. Each instance triggers on its own
## (CR 702.91b). What it pumps is fixed as it resolves (CR 611.2c), so a creature put onto
## the battlefield attacking later gets nothing.


func _init() -> void:
	var attacks: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	attacks.filter = IsSourceFilter.new()
	trigger = attacks
	var other: NotFilter = NotFilter.new()
	other.filter = IsSourceFilter.new()
	var other_attacking_creatures: AllOfFilter = AllOfFilter.new()
	other_attacking_creatures.filters = [HasCardTypeFilter.new(), IsAttackingFilter.new(), other]
	var each: EachSelection = EachSelection.new()
	each.filter = other_attacking_creatures
	var one: ConstantValue = ConstantValue.new()
	one.value = 1
	var none: ConstantValue = ConstantValue.new()
	none.value = 0
	var plus_one: ModifyPowerToughnessContinuousEffect = ModifyPowerToughnessContinuousEffect.new()
	plus_one.power = one
	plus_one.toughness = none
	plus_one.affected = each
	var until_end_of_turn: CreateContinuousEffect = CreateContinuousEffect.new()
	until_end_of_turn.continuous = plus_one
	effects = [until_end_of_turn]


func describe() -> String:
	return "battle cry"
