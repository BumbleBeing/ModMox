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
