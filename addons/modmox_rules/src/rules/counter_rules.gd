class_name CounterRules
extends RefCounted
## Whether a spell can be countered (CR 701.6, 101.2): asked by CounterEffect as it would
## counter it, and by the AI before it aims a counter. Asked here, not by the abilities that
## stop it, which may not use their own class as a value (conventions, "The run ends clean").


## Whether [param spell], an object on the stack, can be countered: an ability can always be
## (CR 701.6b); a spell can't be while it has "This spell can't be countered." itself, or while
## a permanent its controller controls has a SpellsCantBeCounteredAbility whose filter it
## matches (engine ADR 0062's second addendum).
static func can_be_countered(state: MmGameState, spell: MmGameObject) -> bool:
	if not spell.is_card_or_copy():
		return true
	if state.characteristics_of(spell).has_ability(CantBeCounteredAbility):
		return false
	var candidate: MmReference = MmReference.to_object(spell.id)
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.controller_id != spell.controller_id:
			continue
		var context: MmEffectContext = MmEffectContext.new(permanent.controller_id, permanent.id)
		for ability: MmAbility in state.characteristics_of(permanent).abilities:
			var shield: SpellsCantBeCounteredAbility = ability as SpellsCantBeCounteredAbility
			if shield != null and (shield.filter == null or shield.filter.matches(state, candidate, context)):
				return false
	return true
