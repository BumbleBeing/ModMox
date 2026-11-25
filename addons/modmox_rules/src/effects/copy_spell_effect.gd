class_name CopySpellEffect
extends MmEffect
## "Copy [selection]" (CR 707.10), as Sage of the Skies's "copy this spell": puts a copy of
## each spell [member selection] finds onto the stack, all at once, owned and controlled by
## the player whose spell or ability copies it (SpellCopiedEvent). The copy has the spell's
## copiable values and the choices it was cast with: its mode, its X and its targets. It
## isn't cast. A copy of a permanent spell becomes a token as it resolves (CR 608.3f), which is
## not "created" (CR 111.13); one anywhere but the stack ceases to exist (CR 704.5e). A spell
## that has left the stack is copied no more, and an ability on the stack is not a spell.
## Later: "You may choose new targets for the copy" (CR 707.10c), once a card says so.

## What is copied: "this spell" (SourceSelection), or "target spell".
@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		if not found.is_object():
			continue
		var spell: MmGameObject = state.object(found.id)
		if spell == null or spell.zone() != state.stack or not spell.is_card_or_copy():
			continue
		events.append(SpellCopiedEvent.new(spell.id, context.controller_id))
	return events


func selections() -> Array[MmSelection]:
	var used: Array[MmSelection] = [selection]
	return used
