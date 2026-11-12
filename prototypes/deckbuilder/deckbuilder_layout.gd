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
## The Collection grid: how tall a card is before any zoom, how small and large the zoom
## slider makes it, the gap between cards, and how many unzoomed rows the pane shows.
const COLLECTION_CARD_HEIGHT: float = 250.0
const COLLECTION_CARD_SMALLEST: float = 150.0
const COLLECTION_CARD_LARGEST: float = 379.0
const CARD_GAP: float = 8.0
const COLLECTION_ROWS_SHOWN: float = 1.5
## Room at the right of a scrolling pane for its scroll bar.
const SCROLL_BAR: float = 14.0
const COLUMN_GAP: float = 6.0
const COLUMN_PAD: float = 8.0
const COLUMN_HEADER: float = 30.0
## How much of each card in a column shows above the next, of its height: its name strip.
const FAN_SHOWN: float = 0.112
## A little air between one name strip and the next.
const FAN_GAP: float = 2.0
## How small and large the deck zoom slider makes the columns' cards, as a share of the
## size at which the eight columns exactly fill the strip.
const DECK_ZOOM_SMALLEST: float = 0.6
const DECK_ZOOM_LARGEST: float = 1.8

var size: Vector2
## How tall a Collection card is now: the zoom slider changes it, the pane keeps its size.
var collection_card_height: float = COLLECTION_CARD_HEIGHT
## How large the columns' cards are drawn, 1 being the size at which the eight columns
## exactly fill the strip. Larger, the columns widen and the strip scrolls sideways.
var deck_zoom: float = 1.0


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
	var width: float = column_width()
	var height: float = strip.size.y - (SCROLL_BAR if columns_overflow() else 0.0)
	return Rect2(strip.position.x + index * (width + COLUMN_GAP), strip.position.y, width, height)


## How wide a column is: its card, the padding either side, and room for a scroll bar.
func column_width() -> float:
	return column_card_height() * CardGeometry.ASPECT + 2.0 * COLUMN_PAD + SCROLL_BAR


## How wide the eight columns are together.
func columns_width() -> float:
	return WorkingDeck.COLUMN_COUNT * (column_width() + COLUMN_GAP) - COLUMN_GAP


## Whether the columns are too wide for the strip, which then scrolls sideways.
func columns_overflow() -> bool:
	return columns_width() > deck().size.x + 0.5


## How tall a card in a column is: as wide as a column that fills an eighth of the strip
## allows, times the deck zoom.
func column_card_height() -> float:
	var fitted: float = (deck().size.x - COLUMN_GAP * (WorkingDeck.COLUMN_COUNT - 1)) / WorkingDeck.COLUMN_COUNT
	return (fitted - 2.0 * COLUMN_PAD - SCROLL_BAR) / CardGeometry.ASPECT * deck_zoom


## How far down a column its card at [param index] starts.
func fan_offset(index: int) -> float:
	return index * fan_step()


## How far each card in a column starts below the one before it.
func fan_step() -> float:
	return column_card_height() * FAN_SHOWN + FAN_GAP


## The place in a column of [param count] cards that a card dropped [param y] below the
## top of the fan goes to: above the card whose name strip starts nearest, or the bottom.
func fan_place_at(y: float, count: int) -> int:
	return clampi(roundi(y / fan_step()), 0, count)


## How far in from the left of a column's fan its cards start, so that they sit in the
## middle of the column with the scroll bar's room shared between both sides.
func fan_left() -> float:
	return SCROLL_BAR / 2.0


## How tall [param count] fanned cards are together: every name strip and one whole card.
func fan_height(count: int) -> float:
	return 0.0 if count == 0 else fan_offset(count - 1) + column_card_height()


## How many cards fit across the Collection grid.
func collection_columns() -> int:
	var card_width: float = collection_card_height * CardGeometry.ASPECT
	var room: float = collection().size.x - 2.0 * PAD - SCROLL_BAR
	return maxi(1, floori((room + CARD_GAP) / (card_width + CARD_GAP)))


## Where the Collection's card at [param index] sits inside the grid it scrolls in.
func collection_cell(index: int) -> Rect2:
	var card: Vector2 = Vector2(collection_card_height * CardGeometry.ASPECT, collection_card_height)
	var across: int = collection_columns()
	var place: Vector2 = Vector2(index % across, index / across) * (card + Vector2(CARD_GAP, CARD_GAP))
	return Rect2(place, card)


## How tall the Collection grid is with [param count] cards in it.
func collection_grid_height(count: int) -> float:
	return 0.0 if count == 0 else collection_cell(count - 1).end.y


## How tall the card in the inspector is: as wide as the inspector allows.
func inspector_card_height() -> float:
	return (INSPECTOR_WIDTH - 2.0 * PAD) / CardGeometry.ASPECT
