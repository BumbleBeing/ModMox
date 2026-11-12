class_name Deckbox
extends RefCounted
## The Decks the Hero has saved in the run.

var _decks: Array[Deck] = []


func decks() -> Array[Deck]:
	return _decks.duplicate()


## Whether a Deck other than [param except] has [param name], ignoring capitals.
func is_name_taken(name: String, except: Deck = null) -> bool:
	for deck: Deck in _decks:
		if deck != except and deck.name.nocasecmp_to(name) == 0:
			return true
	return false


## Keeps [param deck]. A Deck already kept stays where it is.
func put(deck: Deck) -> void:
	if not _decks.has(deck):
		_decks.append(deck)
