class_name ReconfigureAbility
extends ActivatedAbility
## One of the two activated abilities the keyword "Reconfigure [cost]" stands for
## (CR 702.151a), so a card with reconfigure has two, both with the same
## [member mana_cost]: "[Cost]: Attach this permanent to another target creature you
## control. Activate only as a sorcery", and with [member unattaches] "[Cost]: Unattach this
## permanent. Activate only if this permanent is attached to a creature and only as a
## sorcery". Authored with its [member mana_cost] and [member unattaches] alone: it is made
## with its target, its effect and its Activation Restrictions, which are saved with it
## like any activated ability's. While attached to a creature its permanent isn't a creature
## (CR 702.151b, LayerEngine), and it may be attached while it is one (CR 301.5c,
## AttachmentRules). It is not an equip ability, so InstantSpeedEquipAbility never lifts its
## "only as a sorcery".

## The unattaching half. Setting it remakes the target, effect and restrictions, unless the
## effects were changed by other means, such as being loaded from a file after it.
@export var unattaches: bool = false:
	set(value):
		unattaches = value
		if effects.size() == 1 and effects[0] == _made_effect:
			_make_half()

## The effect this ability last made for itself, so a later [member unattaches] replaces it
## and nothing else.
var _made_effect: MmEffect = null


func _init() -> void:
	is_sorcery_speed = true
	_make_half()


func describe() -> String:
	return "reconfigure (unattach)" if unattaches else "reconfigure"


func _make_half() -> void:
	if unattaches:
		var unattach: UnattachEffect = UnattachEffect.new()
		unattach.selection = SourceSelection.new()
		_made_effect = unattach
		targets = []
		is_only_while_attached = true
	else:
		var creature: HasCardTypeFilter = HasCardTypeFilter.new()
		creature.card_type = MmCardTypes.CardType.CREATURE
		var yours: ControlledByFilter = ControlledByFilter.new()
		yours.whose = MmTrigger.Whose.YOU
		var other: NotFilter = NotFilter.new()
		other.filter = IsSourceFilter.new()
		var all: AllOfFilter = AllOfFilter.new()
		all.filters = [creature, yours, other]
		var requirement: TargetRequirement = TargetRequirement.new()
		requirement.filter = all
		var chosen: TargetSelection = TargetSelection.new()
		chosen.target_index = 0
		var attach: AttachEffect = AttachEffect.new()
		attach.attachment = SourceSelection.new()
		attach.to = chosen
		_made_effect = attach
		targets = [requirement]
		is_only_while_attached = false
	effects = [_made_effect]
