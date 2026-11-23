class_name ProtectionRules
extends RefCounted
## Whether a permanent has protection from something (CR 702.16). Asked here, not by
## ProtectionAbility, which may not use its own class as a value (conventions, "The run
## ends clean").


## Whether [param protected] has protection from [param source_id] right now.
static func protects(state: MmGameState, protected: MmGameObject, source_id: int) -> bool:
	for ability: MmAbility in state.characteristics_of(protected).abilities:
		var protection: ProtectionAbility = ability as ProtectionAbility
		if protection != null and protection.matches(state, protected, source_id):
			return true
	return false
