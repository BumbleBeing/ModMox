class_name CollectionFilter
extends RefCounted
## What the Collection pane is showing: a search, the filters and a sort order. Filters of
## one kind combine as "any of these"; different kinds must all hold. Multicolor is the
## exception: with it on, a card must be multicolor and have every chosen color. Rarity has
## a place in the bar but nothing to filter until cards have one.

enum SortKey { COLOR, MANA_VALUE, NAME, TYPE }

## The mana value that stands for itself and everything above it.
const TOP_MANA_VALUE: int = 6
## Card types in the order a sort by type lists them.
const TYPE_ORDER: Array[MmCardTypes.CardType] = [
	MmCardTypes.CardType.CREATURE, MmCardTypes.CardType.INSTANT, MmCardTypes.CardType.SORCERY,
	MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.ENCHANTMENT, MmCardTypes.CardType.LAND,
]

## Every word must be found in the card's name, type line or Rules Text.
var search: String = ""
var colors: Array[MmCardTypes.CardColor] = []
var multicolor: bool = false
var colorless: bool = false
var card_types: Array[MmCardTypes.CardType] = []
var mana_values: Array[int] = []
var sort_key: SortKey = SortKey.COLOR


func is_active() -> bool:
	return (search.strip_edges() != "" or not colors.is_empty() or multicolor or colorless
			or not card_types.is_empty() or not mana_values.is_empty())


## Drops the search and every filter. The sort order stays.
func clear() -> void:
	search = ""
	colors = []
	multicolor = false
	colorless = false
	card_types = []
	mana_values = []


func matches(card: DeckbuilderCard) -> bool:
	return _matches_search(card) and _matches_color(card) and _matches_type(card) and _matches_mana_value(card)


## The cards of [param cards] that match, in the sort order.
func apply(cards: Array[DeckbuilderCard]) -> Array[DeckbuilderCard]:
	var result: Array[DeckbuilderCard] = cards.filter(matches)
	result.sort_custom(_comes_before)
	return result


func _matches_search(card: DeckbuilderCard) -> bool:
	var look: CardLook = card.look()
	var text: String = ("%s\n%s\n%s" % [look.name, look.type_line(), look.rules_text]).to_lower()
	for word: String in search.to_lower().split(" ", false):
		if not text.contains(word):
			return false
	return true


func _matches_color(card: DeckbuilderCard) -> bool:
	if colors.is_empty() and not multicolor and not colorless:
		return true
	var card_colors: Array[MmCardTypes.CardColor] = card.look().colors
	if card_colors.is_empty():
		return colorless
	if multicolor:
		# With multicolor on, the chosen colors narrow it: the card must have every one.
		return card_colors.size() > 1 and colors.all(
				func(color: MmCardTypes.CardColor) -> bool: return card_colors.has(color))
	for color: MmCardTypes.CardColor in card_colors:
		if colors.has(color):
			return true
	return false


func _matches_type(card: DeckbuilderCard) -> bool:
	if card_types.is_empty():
		return true
	for card_type: MmCardTypes.CardType in card_types:
		if card.look().has_card_type(card_type):
			return true
	return false


func _matches_mana_value(card: DeckbuilderCard) -> bool:
	return mana_values.is_empty() or mana_values.has(mini(card.mana_value(), TOP_MANA_VALUE))


func _comes_before(a: DeckbuilderCard, b: DeckbuilderCard) -> bool:
	var keys_a: Array[int] = _sort_keys(a)
	var keys_b: Array[int] = _sort_keys(b)
	for index: int in keys_a.size():
		if keys_a[index] != keys_b[index]:
			return keys_a[index] < keys_b[index]
	return a.comes_before_by_name(b)


## The numbers a card is ordered by before its name, most important first.
func _sort_keys(card: DeckbuilderCard) -> Array[int]:
	match sort_key:
		SortKey.COLOR:
			return [card.color_rank(), card.mana_value()]
		SortKey.MANA_VALUE:
			return [card.mana_value(), card.color_rank()]
		SortKey.TYPE:
			return [_type_rank(card)]
	return []


func _type_rank(card: DeckbuilderCard) -> int:
	for rank: int in TYPE_ORDER.size():
		if card.look().has_card_type(TYPE_ORDER[rank]):
			return rank
	return TYPE_ORDER.size()
