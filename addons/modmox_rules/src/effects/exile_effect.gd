class_name ExileEffect
extends MmEffect
## "Exile [selection]" (CR 701.13a): each selected permanent, or card in a graveyard, is put
## into exile, all at once. With [member links_to_source] each card it exiles
## remembers the ability's source, so a linked ability of that object can find "the exiled
## card" (CR 607.2a, ExiledWithSourceSelection).

@export var selection: MmSelection
## Whether the cards it exiles are remembered as exiled with its source, for a linked
## ability (CR 607.2a), as Oblivion Ring's are. Off for an exile nothing links to, such as
## Lion Sash's, so the screen never tucks its cards behind the source (game ADR 0043).
@export var links_to_source: bool = true


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var exiled: MmGameObject = state.object(found.id) if found.is_object() else null
		if exiled == null or exiled.zone() == null:
			continue
		if exiled.zone() != state.battlefield and exiled.zone().kind != MmZone.Kind.GRAVEYARD:
			continue
		var move: ZoneChangeEvent = ZoneChangeEvent.new(exiled, state.exile, MmZone.BOTTOM, ZoneChangeEvent.Reason.EXILE)
		if links_to_source:
			move.exiled_with_object_id = context.source_object_id
		events.append(move)
	return events


func selections() -> Array[MmSelection]:
	return [selection]
