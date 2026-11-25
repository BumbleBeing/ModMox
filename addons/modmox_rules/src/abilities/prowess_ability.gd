class_name ProwessAbility
extends TriggeredAbility
## The keyword prowess (CR 702.108a): "Whenever you cast a noncreature spell, this creature
## gets +1/+1 until end of turn." Authored with nothing: it is made with its trigger and its
## effect, which are saved with it like any triggered ability's, so a Modification changes
## them the same way, as ExaltedAbility is. It triggers as the spell becomes cast, so it
## resolves before the spell does. A copy of a spell was never cast (CR 707.10), so it
## triggers nothing. Each instance triggers on its own (CR 702.108b).


func _init() -> void:
	var creature: HasCardTypeFilter = HasCardTypeFilter.new()
	creature.card_type = MmCardTypes.CardType.CREATURE
	var noncreature: NotFilter = NotFilter.new()
	noncreature.filter = creature
	var cast: SpellCastTrigger = SpellCastTrigger.new()
	cast.whose = MmTrigger.Whose.YOU
	cast.filter = noncreature
	trigger = cast
	var one: ConstantValue = ConstantValue.new()
	one.value = 1
	var plus_one: ModifyPowerToughnessContinuousEffect = ModifyPowerToughnessContinuousEffect.new()
	plus_one.power = one
	plus_one.toughness = one.duplicate()
	plus_one.affected = SourceSelection.new()
	var until_end_of_turn: CreateContinuousEffect = CreateContinuousEffect.new()
	until_end_of_turn.continuous = plus_one
	effects = [until_end_of_turn]


func describe() -> String:
	return "prowess"
