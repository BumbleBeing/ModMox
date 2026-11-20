class_name ExileEffect
extends MmEffect
## "Exile [selection]" (CR 701.13a): each selected permanent, or card in a graveyard, is put
## into exile, all at once. With [member links_to_source] each card it exiles
## remembers the ability's source, so a linked ability of that object can find "the exiled
## card" (CR 607.2a, ExiledWithSourceSelection). With [member until_source_leaves] it reads
## "... until this permanent leaves the battlefield" (CR 610.3, ADR 0065): the cards it exiles
## come back by themselves once the source has left (ExileUntilRules), and if the source has
## already left when this resolves, it exiles nothing (CR 610.3c).

@export var selection: MmSelection
## Whether the cards it exiles are remembered as exiled with its source, for a linked
## ability (CR 607.2a), as Oblivion Ring's are. Off for an exile nothing links to, such as
## Lion Sash's, so the screen never tucks its cards behind the source (game ADR 0043).
@export var links_to_source: bool = true
## True for "exile [selection] until this permanent leaves the battlefield", as Leyline
## Binding's is (CR 610.3). Its cards are always remembered as exiled with the source.
@export var until_source_leaves: bool = false


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	if until_source_leaves and not _source_is_on_the_battlefield(state, context):
		return events  # CR 610.3c
	for found: MmReference in selection.select(state, context):
		var exiled: MmGameObject = state.object(found.id) if found.is_object() else null
		if exiled == null or exiled.zone() == null:
			continue
		if exiled.zone() != state.battlefield and exiled.zone().kind != MmZone.Kind.GRAVEYARD:
			continue
		var move: ZoneChangeEvent = ZoneChangeEvent.new(exiled, state.exile, MmZone.BOTTOM, ZoneChangeEvent.Reason.EXILE)
		if links_to_source or until_source_leaves:
			move.exiled_with_object_id = context.source_object_id
		move.exiled_until_source_leaves = until_source_leaves
		events.append(move)
	return events


static func _source_is_on_the_battlefield(state: MmGameState, context: MmEffectContext) -> bool:
	var source: MmGameObject = state.object(context.source_object_id)
	return source != null and source.zone() == state.battlefield


func selections() -> Array[MmSelection]:
	return [selection]
