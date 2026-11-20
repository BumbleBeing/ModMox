class_name EnchantAbility
extends StaticAbility
## The keyword "Enchant [quality]" (CR 702.5) of an Aura (CR 303.4), such as "Enchant land":
## [member filter] says what the Aura may be attached to (AttachmentRules). An Aura spell
## targets what it may enchant (CR 303.4a), so the cast, the check that it can be cast, the
## recheck as it resolves and the AI all read that target from aura_spell(), which
## CastProcedure.spell_ability_of() hands them for a card with this ability (ADR 0064).
# Later: "Enchant player" (CR 303.4a), once a card enchants one.

## What the Aura may enchant. Matched against permanents only.
@export var filter: MmFilter

## The spell ability an Aura spell resolves with, made once from [member filter].
var _aura_spell: SpellAbility = null


## A spell ability with one target requirement, "target [permanent matching the filter]",
## and no effects: as it resolves, the Aura enters attached to that target (CR 303.4a,
## ResolutionProcedure). Card data: never changed once made.
func aura_spell() -> SpellAbility:
	if _aura_spell == null:
		var permanent: AllOfFilter = AllOfFilter.new()
		permanent.filters = [IsPermanentFilter.new(), filter]
		var requirement: TargetRequirement = TargetRequirement.new()
		requirement.filter = permanent
		_aura_spell = SpellAbility.new()
		_aura_spell.targets = [requirement]
	return _aura_spell


## Whether an Aura with this ability may be attached to [param to] (CR 303.4a).
func may_enchant(state: MmGameState, to: MmGameObject, aura: MmGameObject) -> bool:
	return filter == null or filter.matches(state, MmReference.to_object(to.id), MmEffectContext.new(aura.controller_id, aura.id))


func describe() -> String:
	return "enchant"
