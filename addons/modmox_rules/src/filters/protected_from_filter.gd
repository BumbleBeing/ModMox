class_name ProtectedFromFilter
extends MmFilter
## Matches a source that [member protection] protects its permanent from. Built by
## ProtectionAbility for its prevention effect, never authored: the context's source is
## the protected permanent.

var protection: ProtectionAbility


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	var protected: MmGameObject = state.object_or_last_known(context.source_object_id)
	return candidate.is_object() and protected != null and protection.matches(state, protected, candidate.id)
