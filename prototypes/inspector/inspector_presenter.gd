extends EncounterPresenter
## THROWAWAY (13h prototype): an Encounter Presenter that also keeps each card's Original,
## the look of its Card Definition with no Mods and nothing an encounter has done to it.
## The real build would put these on the snapshot.

## By Card Identity. A token or an Emblem has none.
var originals: Dictionary[int, CardLook] = {}


func _emit() -> void:
	super()
	for seen: MmObjectView in _snapshot.visible_objects():
		for card_id: int in [seen.card_id, seen.source_card_id]:
			if card_id == MmGameObject.NO_CARD or originals.has(card_id):
				continue
			var run_card: MmRunCard = _engine.run_card(card_id)
			if run_card == null or run_card.base == null or run_card.base.resource_path == "":
				continue
			originals[card_id] = CardLook.of_characteristics(MmCharacteristics.printed(run_card.base),
					run_card.base.resource_path.get_file().get_basename())
