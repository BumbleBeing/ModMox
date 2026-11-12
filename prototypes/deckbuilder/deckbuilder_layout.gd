class_name DeckbuilderLayout
extends RefCounted
## Where every part of the deckbuilder sits, worked out from the screen's size alone so it
## can be tested without a window. Designed at 1920 × 1080: the top bar, the inspector and
## the filter bar keep their size, the Collection keeps its share of the height, and the
## rest goes to the deck columns.

const GUTTER: float = 12.0
const PAD: float = 10.0
const TOP_BAR_HEIGHT: float = 64.0
## As wide as the Encounter Screen's sidebar, where its inspector will go (13h).
const INSPECTOR_WIDTH: float = 340.0
const FILTER_BAR_HEIGHT: float = 52.0
## The Collection grid: how tall a card is, the gap between cards, and how many rows show.
const COLLECTION_CARD_HEIGHT: float = 190.0
const CARD_GAP: float = 8.0
const COLLECTION_ROWS_SHOWN: float = 2.0
## Room at the right of a scrolling pane for its scroll bar.
const SCROLL_BAR: float = 14.0
const COLUMN_GAP: float = 6.0
const COLUMN_PAD: float = 8.0
const COLUMN_HEADER: float = 30.0
## How much of each card in a column shows above the next, of its height: its name strip.
const FAN_SHOWN: float = 0.112

var size: Vector2


func _init(screen_size: Vector2) -> void:
	size = screen_size


func top_bar() -> Rect2:
	return Rect2(GUTTER, GUTTER, size.x - 2.0 * GUTTER, TOP_BAR_HEIGHT)


func inspector() -> Rect2:
	var top: float = top_bar().end.y + GUTTER
	return Rect2(GUTTER, top, INSPECTOR_WIDTH, size.y - top - GUTTER)


func filter_bar() -> Rect2:
	var left: float = inspector().end.x + GUTTER
	return Rect2(left, inspector().position.y, size.x - left - GUTTER, FILTER_BAR_HEIGHT)


func collection() -> Rect2:
	var bar: Rect2 = filter_bar()
	var height: float = (COLLECTION_ROWS_SHOWN * (COLLECTION_CARD_HEIGHT + CARD_GAP) - CARD_GAP + 2.0 * PAD)
	return Rect2(bar.position.x, bar.end.y + GUTTER, bar.size.x, height)


## The strip the eight columns stand in.
func deck() -> Rect2:
	var pane: Rect2 = collection()
	var top: float = pane.end.y + GUTTER
	return Rect2(pane.position.x, top, pane.size.x, size.y - top - GUTTER)


func column(index: int) -> Rect2:
	var strip: Rect2 = deck()
	var width: float = (strip.size.x - COLUMN_GAP * (WorkingDeck.COLUMN_COUNT - 1)) / WorkingDeck.COLUMN_COUNT
	return Rect2(strip.position.x + index * (width + COLUMN_GAP), strip.position.y, width, strip.size.y)


## How tall a card in a column is: as wide as the column allows.
func column_card_height() -> float:
	return (column(0).size.x - 2.0 * COLUMN_PAD - SCROLL_BAR) / CardGeometry.ASPECT


## How far down a column its card at [param index] starts.
func fan_offset(index: int) -> float:
	return index * column_card_height() * FAN_SHOWN


## How tall [param count] fanned cards are together: every name strip and one whole card.
func fan_height(count: int) -> float:
	return 0.0 if count == 0 else fan_offset(count - 1) + column_card_height()


## How many cards fit across the Collection grid.
func collection_columns() -> int:
	var card_width: float = COLLECTION_CARD_HEIGHT * CardGeometry.ASPECT
	var room: float = collection().size.x - 2.0 * PAD - SCROLL_BAR
	return maxi(1, floori((room + CARD_GAP) / (card_width + CARD_GAP)))


## Where the Collection's card at [param index] sits inside the grid it scrolls in.
func collection_cell(index: int) -> Rect2:
	var card: Vector2 = Vector2(COLLECTION_CARD_HEIGHT * CardGeometry.ASPECT, COLLECTION_CARD_HEIGHT)
	var across: int = collection_columns()
	var place: Vector2 = Vector2(index % across, index / across) * (card + Vector2(CARD_GAP, CARD_GAP))
	return Rect2(place, card)


## How tall the Collection grid is with [param count] cards in it.
func collection_grid_height(count: int) -> float:
	return 0.0 if count == 0 else collection_cell(count - 1).end.y


## How tall the card in the inspector is: as wide as the inspector allows.
func inspector_card_height() -> float:
	return (INSPECTOR_WIDTH - 2.0 * PAD) / CardGeometry.ASPECT
