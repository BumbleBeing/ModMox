class_name ModSlotRow
extends Control
## A card's Mod Slots drawn on its face in the deckbuilder: a row of bubbles in the black
## border under the frame, each empty or filled by a green chip for a Mod or a red one for
## a Hex, in the order they were earned. A basic land has no Mod Slots and so no row.

enum Slot { EMPTY, MOD, HEX }

## The black bar under the frame runs from here to the bottom of the card, of its height
## (measured on the baked frames). The bubbles sit just above the middle of it.
const BAR_TOP: float = 0.929
## How far above the bar's middle the row sits, in units, whatever the card's size.
const LIFT: float = 1.0
## A bubble's width, of the card's height.
const DIAMETER: float = 0.0434
## The gap between bubbles, of a bubble's width.
const GAP: float = 0.35
const RIM: Color = Color("#8a93a0")
const HOLLOW: Color = Color("#14171b")
const MOD_CHIP: Color = Color("#4cc46a")
const HEX_CHIP: Color = Color("#e5484d")

var _slots: Array[Slot] = []
var _diameter: float = 0.0


## What fills each of [param card]'s Mod Slots, in order. Empty for a basic land.
static func slots_of(card: DeckbuilderCard) -> Array[Slot]:
	var result: Array[Slot] = []
	for index: int in card.mod_slots():
		if index >= card.mods.size():
			result.append(Slot.EMPTY)
		else:
			result.append(Slot.HEX if card.mods[index].is_hex else Slot.MOD)
	return result


static func color_of(slot: Slot) -> Color:
	return HEX_CHIP if slot == Slot.HEX else MOD_CHIP


## Shows [param card]'s Mod Slots, placed for a Card Face [param card_height] tall.
func setup(card: DeckbuilderCard, card_height: float) -> void:
	_slots = slots_of(card)
	_diameter = card_height * DIAMETER
	var width: float = _slots.size() * _diameter + maxi(_slots.size() - 1, 0) * _diameter * GAP
	size = Vector2(width, _diameter)
	position = Vector2((card_height * CardGeometry.ASPECT - width) / 2.0, card_height * (BAR_TOP + 1.0) / 2.0 - _diameter / 2.0 - LIFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func slots() -> Array[Slot]:
	return _slots


func _draw() -> void:
	var radius: float = _diameter / 2.0
	for index: int in _slots.size():
		var middle: Vector2 = Vector2(radius + index * _diameter * (1.0 + GAP), radius)
		draw_circle(middle, radius, RIM, true, -1.0, true)
		# The hollow is lit from the upper left like the chips, so its near wall is in
		# shadow and its floor catches a little light toward the lower right.
		draw_circle(middle, radius * 0.84, HOLLOW.darkened(0.5), true, -1.0, true)
		draw_circle(middle + Vector2(0.1, 0.12) * radius, radius * 0.68, HOLLOW.lightened(0.1), true, -1.0, true)
		if _slots[index] != Slot.EMPTY:
			_draw_chip(middle, radius * 0.7, color_of(_slots[index]))


## A chip lit from the upper left: a dark edge, the color, a paler patch and a small glint.
func _draw_chip(middle: Vector2, radius: float, color: Color) -> void:
	var toward_light: Vector2 = Vector2(-0.22, -0.26) * radius
	draw_circle(middle, radius, color.darkened(0.45), true, -1.0, true)
	draw_circle(middle + toward_light * 0.35, radius * 0.86, color, true, -1.0, true)
	draw_circle(middle + toward_light, radius * 0.55, color.lightened(0.3), true, -1.0, true)
	draw_circle(middle + toward_light * 1.7, radius * 0.2, Color(1, 1, 1, 0.85), true, -1.0, true)
