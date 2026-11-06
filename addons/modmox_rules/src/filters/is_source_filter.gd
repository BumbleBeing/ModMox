class_name IsSourceFilter
extends MmFilter
## Matches the spell or ability's own source: "this creature", as in "When this creature
## dies".


func matches(_state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	return candidate.is_object() and candidate.id == context.source_object_id
