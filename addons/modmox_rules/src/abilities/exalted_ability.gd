class_name ExaltedAbility
extends TriggeredAbility
## The keyword exalted (CR 702.83a): "Whenever a creature you control attacks alone, that
## creature gets +1/+1 until end of turn." Authored with nothing: it is made with its trigger
## and its effect, which are saved with it like any triggered ability's, so a Modification
## changes them the same way, as WardAbility is. Each instance triggers on its own
## (CR 702.83b).


func _init() -> void:
	var attacks_alone: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	attacks_alone.whose = MmTrigger.Whose.YOU
	attacks_alone.alone = true
	trigger = attacks_alone
	var one: ConstantValue = ConstantValue.new()
	one.value = 1
	var plus_one: ModifyPowerToughnessContinuousEffect = ModifyPowerToughnessContinuousEffect.new()
	plus_one.power = one
	plus_one.toughness = one.duplicate()
	plus_one.affected = TriggeringObjectSelection.new()
	var until_end_of_turn: CreateContinuousEffect = CreateContinuousEffect.new()
	until_end_of_turn.continuous = plus_one
	effects = [until_end_of_turn]


func describe() -> String:
	return "exalted"
