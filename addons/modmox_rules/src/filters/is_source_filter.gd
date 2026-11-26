class_name IsSourceFilter
extends MmFilter
## Matches the spell or ability's own source: "this creature", as in "When this creature
## dies". Once the source has left its zone, the new object it became there is "this" too
## (engine ADR 0096's addendum), so "another target creature card" in a "dies" ability, as
## Gixian Puppeteer's, never chooses the card that died.


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	if not candidate.is_object() or context.source_object_id == 0:
		return false
	if candidate.id == context.source_object_id:
		return true
	var source: MmGameObject = state.object_or_last_known(context.source_object_id)
	return source != null and source.became_object_id != 0 and candidate.id == source.became_object_id
