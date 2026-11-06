class_name ProtectionAbility
extends StaticAbility
## The keyword "protection from [quality]" (CR 702.16), with the quality as a Filter matched
## against the other object, such as "protection from black" or "protection from
## creatures" (A135). The protected permanent can't be:
## - dealt damage by a matching source: the damage is prevented (CR 702.16e);
## - blocked by a matching creature (CR 702.16c);
## - targeted by a matching spell or an ability from a matching source (CR 702.16b).
## Later: can't be enchanted or equipped (CR 702.16d), once Auras and Equipment exist.

@export var from: MmFilter


## Whether [param source_id] has the quality, from the point of view of [param protected].
## An ability on the stack has its source's quality (CR 702.16b).
func matches(state: MmGameState, protected: MmGameObject, source_id: int) -> bool:
	var source: MmGameObject = state.object_or_last_known(source_id)
	if source != null and source.definition == null and source.source_object_id != 0:
		source_id = source.source_object_id
	var context: MmEffectContext = MmEffectContext.new(protected.controller_id, protected.id)
	return from != null and from.matches(state, MmReference.to_object(source_id), context)


## Whether [param protected] has protection from [param source_id] right now.
static func protects(state: MmGameState, protected: MmGameObject, source_id: int) -> bool:
	for ability: MmAbility in state.characteristics_of(protected).abilities:
		var protection: ProtectionAbility = ability as ProtectionAbility
		if protection != null and protection.matches(state, protected, source_id):
			return true
	return false


## The prevention effect this ability generates for its permanent: all damage from matching
## sources (CR 702.16e). It is one more effect for the affected player to order (A135).
func prevention() -> PreventDamageReplacementEffect:
	var effect: PreventDamageReplacementEffect = PreventDamageReplacementEffect.new()
	effect.sources = _source_filter()
	return effect


func describe() -> String:
	return "protection"


## A Filter that matches a source exactly when this ability protects from it, following an
## ability on the stack to its source.
func _source_filter() -> MmFilter:
	var filter: ProtectedFromFilter = ProtectedFromFilter.new()
	filter.protection = self
	return filter
