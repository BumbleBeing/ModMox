class_name StoreLayout
extends RefCounted
## Where the Store's screen puts things (milestone 24, signed off as prototypes/store_screen/
## step 1, A, the bench), worked out apart from its nodes: a pane across the top, the
## Inspector down the left, the cards in the middle at most five to a row with the rows
## evened out, cheapest first and then by name, and the Items in a column at the right,
## Potions and then Armor, each cheapest first. With no Items the cards' pane takes their room.
## What an Item says is written as the Satchel's entries are.

const SCREEN: Vector2 = Vector2(1920, 1080)
const MARGIN: float = 12.0
const BAR: Rect2 = Rect2(12, 12, 1896, 72)
const BODY_TOP: float = 96.0
const BODY_HEIGHT: float = 972.0
const INSPECTOR_WIDTH: float = 340.0
const INSPECTOR_PAD: float = 10.0
const ITEMS_WIDTH: float = 388.0
const MOST_IN_A_ROW: int = 5
const CARD_HEIGHT: float = 280.0
const CARD_GAP: int = 20
const ROW_GAP: int = 4
## The room round the cards on their pane, and round the Items on theirs.
const CARDS_PAD: float = 24.0
const ITEMS_PAD: float = 12.0
## The Items' entries stand this far apart, the room each keeps above it to rise into counted.
const ENTRY_GAP: float = 12.0
## A 32 × 32 icon is drawn at three times its size on an entry, as in the Satchel.
const ICON_SIDE: float = SatchelLook.ICON_SIDE
## How wide an entry's words are, beside its picture.
const WORDS_WIDTH: float = ITEMS_WIDTH - 2.0 * ITEMS_PAD - 2.0 * StoreLook.PAPER_PADDING.x - ICON_SIDE - 14.0 \
		- DeckbuilderLayout.SCROLL_BAR


## How many cards stand in each row, top to bottom, for [param count] cards: at most five to
## a row, the rows evened out, so six stand three and three, not five and one.
static func row_sizes(count: int) -> Array[int]:
	var sizes: Array[int] = []
	if count <= 0:
		return sizes
	var rows: int = ceili(count / float(MOST_IN_A_ROW))
	var per_row: int = ceili(count / float(rows))
	var left: int = count
	while left > 0:
		sizes.append(mini(per_row, left))
		left -= per_row
	return sizes


## The cards of [param stock] in the order they stand: cheapest first, then by name.
static func cards_in_order(stock: StoreStock) -> Array[StoreGood]:
	return _in_order(stock, StoreGood.Kind.CARD)


## The Items of [param stock] in the order they stand: Potions, then Armor, each cheapest
## first, then by name.
static func items_in_order(stock: StoreStock) -> Array[StoreGood]:
	return _in_order(stock, StoreGood.Kind.POTION) + _in_order(stock, StoreGood.Kind.ARMOR)


## The Inspector's pane.
static func inspector_rect() -> Rect2:
	return Rect2(MARGIN, BODY_TOP, INSPECTOR_WIDTH, BODY_HEIGHT)


## The cards' pane, wider when there are no Items.
static func cards_rect(has_items: bool) -> Rect2:
	var left: float = MARGIN + INSPECTOR_WIDTH + MARGIN
	var right: float = SCREEN.x - MARGIN - (ITEMS_WIDTH + MARGIN if has_items else 0.0)
	return Rect2(left, BODY_TOP, right - left, BODY_HEIGHT)


static func items_rect() -> Rect2:
	return Rect2(SCREEN.x - MARGIN - ITEMS_WIDTH, BODY_TOP, ITEMS_WIDTH, BODY_HEIGHT)


## What [param good], a Potion or an Armor, says on its entry, as the Satchel writes one: its
## name, its type line ("Rare Potion", "Cuirass") and its words, a sentence to a line.
static func entry_of(good: StoreGood) -> SatchelEntry:
	var entry: SatchelEntry = SatchelEntry.new()
	entry.name = good.name()
	if good.kind == StoreGood.Kind.POTION:
		entry.potion = good.potion
		entry.type_line = SatchelEntries.POTION_TYPE % Inspector.RARITY_NAMES[good.potion.rarity]
		entry.lines = AbilityText.lines_of(good.potion.abilities, AbilityText.POTION_NOUN)
	else:
		entry.armor = good.armor
		entry.type_line = Armor.slot_name(good.armor.slot)
		entry.lines = StartingConditionText.lines_of(good.armor.starting_conditions)
	return entry


static func _in_order(stock: StoreStock, kind: StoreGood.Kind) -> Array[StoreGood]:
	var goods: Array[StoreGood] = stock.goods().filter(func(good: StoreGood) -> bool: return good.kind == kind)
	goods.sort_custom(func(a: StoreGood, b: StoreGood) -> bool:
		if a.price() != b.price():
			return a.price() < b.price()
		return a.name().naturalnocasecmp_to(b.name()) < 0)
	return goods
