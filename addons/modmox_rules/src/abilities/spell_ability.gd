class_name SpellAbility
extends MmAbility
## What an instant or sorcery does when it resolves (CR 113.3a): its target requirements
## and its effects, in order. A modal spell (CR 700.2) has [member modes] instead, and its
## own targets and effects are empty: what it does is the chosen mode's (ADR 0046).

## The chosen mode of a spell that is not modal, or of one whose mode is not chosen yet.
const NO_MODE: int = -1

@export var targets: Array[TargetRequirement] = []
@export var effects: Array[MmEffect] = []
## "Choose one —": one entry for each "•" line. Empty for a spell that is not modal.
@export var modes: Array[AbilityMode] = []


## Its modes: empty when it is not modal.
func modes_or_none() -> Array[AbilityMode]:
	return modes


## Whether this is a modal spell (CR 700.2).
func is_modal() -> bool:
	return not modes.is_empty()


## The target requirements of mode [param mode_index], or this ability's own for NO_MODE.
func targets_for(mode_index: int) -> Array[TargetRequirement]:
	return modes[mode_index].targets if mode_index != NO_MODE else targets


## The effects of mode [param mode_index], or this ability's own for NO_MODE.
func effects_for(mode_index: int) -> Array[MmEffect]:
	return modes[mode_index].effects if mode_index != NO_MODE else effects


func describe() -> String:
	if is_modal():
		return "modal spell ability (%d modes)" % modes.size()
	return "spell ability (%d targets, %d effects)" % [targets.size(), effects.size()]
