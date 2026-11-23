class_name ChosenXValue
extends MmValue
## "X" where a mana cost has {X} (CR 107.3a, ADR 0076): the X chosen as the spell was cast, read
## from the spell or ability's source. For a permanent spell entering the battlefield, the
## source is still the spell, so "enters with X counters" reads it (CR 107.3m). 0 for anything
## not cast with an X, and with no context at all, as a static ability's Filter may be asked.


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	if state == null or context == null:
		return 0
	var source: MmGameObject = state.object(context.source_object_id)
	return 0 if source == null else source.chosen_x
