class_name Collection
extends RefCounted
## Every Run Card the Hero owns in the run (ADR 0028). It alone owns them and gives each
## its identity; a Deck only points at them. A basic land is not in it until its first Mod
## (A558).

var _cards: Array[DeckbuilderCard] = []
var _next_id: int = 1


## Takes ownership of [param run_card], with any Mods (Hexes among them) it arrives with.
func add(run_card: MmRunCard, mods: Array[Mod] = []) -> DeckbuilderCard:
	var card: DeckbuilderCard = DeckbuilderCard.new(_next_id, run_card)
	_next_id += 1
	for mod: Mod in mods:
		card.attach(mod)
	_cards.append(card)
	return card


## Takes ownership of [param card], a basic land that has just taken its first Mod, and
## gives it an identity that lasts the run in place of the Working Deck's.
func adopt(card: DeckbuilderCard) -> void:
	if owns(card):
		return
	card.id = _next_id
	_next_id += 1
	_cards.append(card)


func cards() -> Array[DeckbuilderCard]:
	return _cards.duplicate()


## The card with identity [param id], or null.
func card(id: int) -> DeckbuilderCard:
	for owned: DeckbuilderCard in _cards:
		if owned.id == id:
			return owned
	return null


func owns(owned: DeckbuilderCard) -> bool:
	return _cards.has(owned)


## Gives up [param owned], as when it is sold or lost. Its identity is never given again;
## the caller takes it out of every Deck (Deckbox.forget).
func remove(owned: DeckbuilderCard) -> void:
	_cards.erase(owned)


## The Collection as plain data, for a saved run (ADR 0074): each card's identity, its Card
## Definition's path and the paths of its Mods, in the order earned.
func to_data() -> Dictionary:
	var saved: Array = []
	for owned: DeckbuilderCard in _cards:
		saved.append({"id": owned.id, "base": SavedRun.path_of(owned.run_card.base), "mods": SavedRun.paths_of(owned.mods)})
	return {"next_id": _next_id, "cards": saved}


## The Collection [param data] holds, as to_data() made it: each card a new Run Card of its
## Card Definition, with its Mods attached again in order.
static func from_data(data: Dictionary) -> Collection:
	var collection: Collection = Collection.new()
	for entry: Dictionary in data["cards"]:
		var run_card: MmRunCard = MmRunCard.new()
		run_card.base = load(str(entry["base"])) as MmCardDefinition
		var owned: DeckbuilderCard = DeckbuilderCard.new(int(entry["id"]), run_card)
		for path: Variant in entry["mods"]:
			owned.attach(load(str(path)) as Mod)
		collection._cards.append(owned)
	collection._next_id = int(data["next_id"])
	return collection


## The identity the next card taken in will get. It is part of the run's state.
func next_id() -> int:
	return _next_id
