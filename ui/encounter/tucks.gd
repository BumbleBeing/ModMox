class_name Tucks
extends RefCounted
## Which cards in exile are Tucked Cards (game glossary, ADR 0043): a card an object's
## ability exiled is drawn behind that object for as long as it stands on the battlefield,
## and is in its owner's exile pile like any other card once it has gone. The engine says
## which object exiled a card (MmObjectView.exiled_with_object_id); the screen says which
## permanents stand where a card can be tucked behind them.


## The Tucked Cards [param view] shows behind each of [param host_ids], by the ID of the
## permanent that exiled each, in object ID order: the first lies nearest its permanent.
static func by_host(view: MmPlayerView, host_ids: Array[int]) -> Dictionary[int, Array]:
	var cards: Array[MmObjectView] = []
	for player_id: int in view.exiles:
		for card: MmObjectView in view.exiles[player_id]:
			if is_tucked(card, host_ids):
				cards.append(card)
	cards.sort_custom(func(a: MmObjectView, b: MmObjectView) -> bool: return a.id < b.id)
	var tucked: Dictionary[int, Array] = {}
	for card: MmObjectView in cards:
		if not tucked.has(card.exiled_with_object_id):
			tucked[card.exiled_with_object_id] = []
		tucked[card.exiled_with_object_id].append(card)
	return tucked


## The player who owns each Tucked Card [param view] shows behind one of
## [param host_ids], by the card's object ID: the player whose exile it is in.
static func owners(view: MmPlayerView, host_ids: Array[int]) -> Dictionary[int, int]:
	var found: Dictionary[int, int] = {}
	for player_id: int in view.exiles:
		for card: MmObjectView in view.exiles[player_id]:
			if is_tucked(card, host_ids):
				found[card.id] = player_id
	return found


## The cards among [param cards], one exile in its own order, that are not tucked behind
## any of [param host_ids]: the ones its pile shows.
static func loose(cards: Array, host_ids: Array[int]) -> Array:
	var found: Array = []
	for card: MmObjectView in cards:
		if not is_tucked(card, host_ids):
			found.append(card)
	return found


## Whether [param card], in exile, is tucked behind one of [param host_ids].
static func is_tucked(card: MmObjectView, host_ids: Array[int]) -> bool:
	return card.exiled_with_object_id != 0 and host_ids.has(card.exiled_with_object_id)
