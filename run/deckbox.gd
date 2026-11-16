class_name Deckbox
extends RefCounted
## The Decks the Hero has saved in the run, and which one is the Active Deck (ADR 0037).
## Only the Deckbox screen's Start checks a Deck's legality; nothing here refuses an
## illegal one.

## A Deck is legal at this many cards or more (A540).
const MINIMUM_SIZE: int = 40

var _decks: Array[Deck] = []
var _active: Deck = null


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


## The Active Deck, or null when there is none.
func active() -> Deck:
	return _active


func is_active(deck: Deck) -> bool:
	return deck != null and deck == _active


## Makes [param deck] the Active Deck. A Deck the Deckbox does not keep cannot be.
func set_active(deck: Deck) -> void:
	if _decks.has(deck):
		_active = deck


func is_legal(deck: Deck) -> bool:
	return deck.size() >= MINIMUM_SIZE


## A copy of [param deck] with the same cards, kept right after it under the first free
## name of "Name (copy)", "Name (copy 2)" and so on. The original stays active if it was.
func duplicate_deck(deck: Deck) -> Deck:
	var copy: Deck = Deck.new()
	copy.card_ids = deck.card_ids.duplicate()
	copy.basic_lands = deck.basic_lands.duplicate()
	copy.name = "%s (copy)" % deck.name
	var number: int = 2
	while is_name_taken(copy.name):
		copy.name = "%s (copy %d)" % [deck.name, number]
		number += 1
	_decks.insert(_decks.find(deck) + 1, copy)
	return copy


## Throws [param deck] away; its cards stay in the Collection. Deleting the Active Deck
## leaves none.
func delete(deck: Deck) -> void:
	_decks.erase(deck)
	if _active == deck:
		_active = null


## Takes the Run Card with identity [param id] out of every Deck, for a card that has left
## the Collection (A542).
func forget(id: int) -> void:
	for deck: Deck in _decks:
		deck.card_ids.erase(id)


## The colors of [param deck]'s cards in white, blue, black, red, green order. Basic lands
## are counted, not held, so they add none; a colorless Deck has none.
func colors_of(deck: Deck, collection: Collection) -> Array[MmCardTypes.CardColor]:
	var seen: Dictionary[MmCardTypes.CardColor, bool] = {}
	for id: int in deck.card_ids:
		var card: DeckbuilderCard = collection.card(id)
		if card == null:
			continue
		for color: MmCardTypes.CardColor in card.characteristics().colors:
			seen[color] = true
	var colors: Array[MmCardTypes.CardColor] = []
	for color: MmCardTypes.CardColor in MmCardTypes.CardColor.values():
		if seen.has(color):
			colors.append(color)
	return colors
