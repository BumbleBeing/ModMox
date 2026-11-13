class_name WorkingDeck
extends RefCounted
## The unsaved copy of a Deck being edited in the deckbuilder (ADR 0028): which cards are
## in it and which column each was put in. Saving writes it to the Deckbox; dropping it
## throws it away. Mods are not part of it.
##
## The columns are free piles: a card stays in the column, and at the place in it, where
## it was put, and nothing is sorted unless sort() is asked for. The piles are never saved,
## so a Deck reopens sorted, with every card in its own column.

## The columns: mana value 0 to 5, then 6 and above, then lands.
const COLUMN_COUNT: int = 8
const SIX_PLUS_COLUMN: int = 6
const LANDS_COLUMN: int = 7
const NO_COLUMN: int = -1
## The place in a column that is under every card already there.
const AT_BOTTOM: int = -1
## A Deck is legal at this many cards or more.
const MINIMUM_SIZE: int = 40

var name: String = ""

var _collection: Collection
var _deckbox: Deckbox
var _deck: Deck = null
## Basic land name to its Card Definition.
var _basic_lands: Dictionary[String, MmCardDefinition] = {}
## One pile of cards for each column, top to bottom.
var _piles: Array[Array] = []
## Basic lands take identities below zero, since the Collection never gave them one.
var _next_basic_id: int = -1
var _saved: String = ""


## A Working Deck over [param deck], or a new empty one if it is null.
func _init(collection: Collection, deckbox: Deckbox, basic_lands: Array[MmCardDefinition], deck: Deck = null) -> void:
	_collection = collection
	_deckbox = deckbox
	_deck = deck
	for column: int in COLUMN_COUNT:
		_piles.append([] as Array[DeckbuilderCard])
	for land: MmCardDefinition in basic_lands:
		_basic_lands[land.name] = land
	if deck != null:
		name = deck.name
		for id: int in deck.card_ids:
			var card: DeckbuilderCard = collection.card(id)
			if card != null:
				add_to_own_column(card)
		for land_name: String in deck.basic_lands:
			for index: int in deck.basic_lands[land_name]:
				add_basic_land(land_name)
		sort()
	_saved = _signature()


## Puts a Collection card in [param column], above the card now at [param place] or at the
## bottom if that is left out. False if it is already in, is not the Collection's, or the
## column does not exist.
func add(card: DeckbuilderCard, column: int, place: int = AT_BOTTOM) -> bool:
	if contains(card) or not _collection.owns(card) or not _is_column(column):
		return false
	_place(card, column, place)
	return true


## Puts a Collection card at the bottom of the column its mana value gives it.
func add_to_own_column(card: DeckbuilderCard) -> bool:
	return add(card, own_column_of(card))


## Adds a fresh basic land named [param land_name] to the lands column, or returns null if
## there is no such basic land.
func add_basic_land(land_name: String) -> DeckbuilderCard:
	if not _basic_lands.has(land_name):
		return null
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = _basic_lands[land_name]
	var card: DeckbuilderCard = DeckbuilderCard.new(_next_basic_id, run_card)
	_next_basic_id -= 1
	_place(card, LANDS_COLUMN)
	return card


## Moves a card already in the Deck to [param column], above the card at [param place] or
## to the bottom if that is left out. The place is counted with the moved card taken out.
func move(card: DeckbuilderCard, column: int, place: int = AT_BOTTOM) -> bool:
	if not contains(card) or not _is_column(column):
		return false
	_piles[column_of(card)].erase(card)
	_place(card, column, place)
	return true


## Takes a card out. A Collection card stays owned; a free basic land is gone.
func remove(card: DeckbuilderCard) -> bool:
	if not contains(card):
		return false
	_piles[column_of(card)].erase(card)
	return true


func contains(card: DeckbuilderCard) -> bool:
	return column_of(card) != NO_COLUMN


func column_of(card: DeckbuilderCard) -> int:
	for column: int in COLUMN_COUNT:
		if _piles[column].has(card):
			return column
	return NO_COLUMN


## The column a card belongs in as it reads now: lands, or its mana value.
func own_column_of(card: DeckbuilderCard) -> int:
	if card.is_land():
		return LANDS_COLUMN
	return mini(card.mana_value(), SIX_PLUS_COLUMN)


## The cards in [param column], top to bottom, in the order they were put there.
func cards_in(column: int) -> Array[DeckbuilderCard]:
	var result: Array[DeckbuilderCard] = []
	result.assign(_piles[column])
	return result


## Every card in the Deck, column by column.
func cards() -> Array[DeckbuilderCard]:
	var result: Array[DeckbuilderCard] = []
	for pile: Array in _piles:
		result.append_array(pile)
	return result


## How many free basic lands named [param land_name] are in the Deck. One that has taken a
## Mod is a Collection card with a name of its own, and is not counted (A558).
func basic_land_count(land_name: String) -> int:
	return _basic_land_counts().get(land_name, 0)


## Puts every card back in its own column, and each column in order: white to green,
## multicolor, colorless, then by name.
func sort() -> void:
	var all: Array[DeckbuilderCard] = cards()
	all.sort_custom(func(a: DeckbuilderCard, b: DeckbuilderCard) -> bool: return a.sorts_before(b))
	for pile: Array in _piles:
		pile.clear()
	for card: DeckbuilderCard in all:
		_piles[own_column_of(card)].append(card)


func size() -> int:
	return cards().size()


func is_legal() -> bool:
	return size() >= MINIMUM_SIZE


## Whether the name or contents differ from what was last saved. Columns do not count.
func has_unsaved_changes() -> bool:
	return _signature() != _saved


## Writes the Deck to the Deckbox, legal or not. Returns why it was refused, or "".
func save() -> String:
	var trimmed: String = name.strip_edges()
	if trimmed == "":
		return "A Deck needs a name."
	if _deckbox.is_name_taken(trimmed, _deck):
		return "Another Deck is already named %s." % trimmed
	if _deck == null:
		_deck = Deck.new()
	name = trimmed
	_deck.name = trimmed
	_deck.card_ids = _collection_ids()
	_deck.basic_lands = _basic_land_counts()
	_deckbox.put(_deck)
	_saved = _signature()
	return ""


func _is_column(column: int) -> bool:
	return column >= 0 and column < COLUMN_COUNT


func _place(card: DeckbuilderCard, column: int, place: int = AT_BOTTOM) -> void:
	var pile: Array = _piles[column]
	if place < 0 or place >= pile.size():
		pile.append(card)
	else:
		pile.insert(place, card)


func _collection_ids() -> Array[int]:
	var ids: Array[int] = []
	for card: DeckbuilderCard in cards():
		if _collection.owns(card):
			ids.append(card.id)
	ids.sort()
	return ids


func _basic_land_counts() -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	for card: DeckbuilderCard in cards():
		if not _collection.owns(card):
			var land_name: String = card.run_card.base.name
			counts[land_name] = counts.get(land_name, 0) + 1
	return counts


## Everything saving keeps, as text that is equal exactly when two states would save alike.
func _signature() -> String:
	var counts: Dictionary[String, int] = _basic_land_counts()
	var lands: PackedStringArray = []
	var land_names: Array[String] = counts.keys()
	land_names.sort()
	for land_name: String in land_names:
		lands.append("%s x%d" % [land_name, counts[land_name]])
	return "%s|%s|%s" % [name.strip_edges(), _collection_ids(), ",".join(lands)]
