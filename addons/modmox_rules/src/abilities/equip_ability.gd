class_name EquipAbility
extends ActivatedAbility
## The keyword "Equip [cost]" (CR 702.6): "[Cost]: Attach this permanent to target creature
## you control. Activate only as a sorcery." Authored with its [member mana_cost] alone: it
## is made with its target, its effect and its Activation Restriction, which are saved with
## it like any activated ability's, so a Modification changes them the same way.


func _init() -> void:
	var creature: HasCardTypeFilter = HasCardTypeFilter.new()
	creature.card_type = MmCardTypes.CardType.CREATURE
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	var both: AllOfFilter = AllOfFilter.new()
	both.filters = [creature, yours]
	var requirement: TargetRequirement = TargetRequirement.new()
	requirement.filter = both
	var chosen: TargetSelection = TargetSelection.new()
	chosen.target_index = 0
	var attach: AttachEffect = AttachEffect.new()
	attach.attachment = SourceSelection.new()
	attach.to = chosen
	targets = [requirement]
	effects = [attach]
	is_sorcery_speed = true


func describe() -> String:
	return "equip"
