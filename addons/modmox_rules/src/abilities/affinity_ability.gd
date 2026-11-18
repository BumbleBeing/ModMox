class_name AffinityAbility
extends CostReductionAbility
## The keyword "Affinity for [quality]" (CR 702.41a): "This spell costs {1} less to cast for
## each [quality] you control." It takes off generic mana only, one for each permanent the
## caster controls that matches [member filter]; "you control" is part of the keyword, so
## the filter leaves it out. Two instances each take their own amount off (CR 702.41b).

## What a permanent must be to count, such as a Cat for "Affinity for Cats".
@export var filter: MmFilter


func reduction(state: MmGameState, spell: MmGameObject, player_id: int) -> MmManaCost:
	var context: MmEffectContext = MmEffectContext.new(player_id, spell.id)
	var reduced: MmManaCost = MmManaCost.new()
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.controller_id == player_id and filter.matches(state, MmReference.to_object(permanent.id), context):
			reduced.generic += 1
	return reduced


func describe() -> String:
	return "affinity"
