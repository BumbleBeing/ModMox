class_name ModSlotRow
extends Control
## A card's Mod Slots drawn on its face in the deckbuilder: a row of bubbles in the black
## border under the frame, each empty or filled by a green chip for a Mod or a red one for
## a Hex, in the order they were earned. A basic land has them like any card (A558). Each
## bubble is a 16 x 16 sprite from ui/sprites/mod_slots/, drawn as one picture so that it
## fades with the card it is on.

enum Slot { EMPTY, MOD, HEX }

## The black bar under the frame runs from here to the bottom of the card, of its height
## (measured on the baked frames). The bubbles sit just above the middle of it.
const BAR_TOP: float = 0.929
## How far above the bar's middle the row sits, in units, whatever the card's size.
const LIFT: float = 1.0
const FOLDER: String = "res://ui/sprites/mod_slots/"
## A bubble sprite's width and height, and the bubble's inside it: the rest is the air
## between one bubble and the next.
const SPRITE: float = 16.0
const BUBBLE: float = 12.0
const MOD_CHIP: Color = Color("#4cc46a")
const HEX_CHIP: Color = Color("#e5484d")

## The sprites, kept loaded: a canvas only borrows a texture it is handed while drawing.
static var _textures: Array[Texture2D] = []

var _slots: Array[Slot] = []
var _sprite: float = 0.0


## What fills each of [param card]'s Mod Slots, in order.
static func slots_of(card: DeckbuilderCard) -> Array[Slot]:
	var result: Array[Slot] = []
	for index: int in card.mod_slots():
		if index >= card.mods.size():
			result.append(Slot.EMPTY)
		else:
			result.append(Slot.HEX if card.mods[index].is_hex else Slot.MOD)
	return result


## The color of a Mod's or a Hex's chip, for whatever is drawn beside the bubbles.
static func color_of(slot: Slot) -> Color:
	return HEX_CHIP if slot == Slot.HEX else MOD_CHIP


static func texture_of(slot: Slot) -> Texture2D:
	if _textures.is_empty():
		for name: String in ["empty", "mod", "hex"]:
			_textures.append(load(FOLDER + name + ".png") as Texture2D)
	return _textures[slot]


## How large a bubble's sprite is drawn on a Card Face [param card_height] tall: whole
## multiples of 16 pixels while the bar under the frame has room for them, and smaller only
## on a card so small that its bar is shorter than one bubble.
static func sprite_size(card_height: float) -> float:
	var bar: float = card_height * (1.0 - BAR_TOP)
	return SPRITE * maxf(floorf(bar / SPRITE), minf(1.0, bar / BUBBLE))


## Shows [param card]'s Mod Slots, placed for a Card Face [param card_height] tall.
func setup(card: DeckbuilderCard, card_height: float) -> void:
	_slots = slots_of(card)
	_sprite = sprite_size(card_height)
	var is_whole: bool = is_equal_approx(_sprite, roundf(_sprite / SPRITE) * SPRITE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if is_whole else CanvasItem.TEXTURE_FILTER_LINEAR
	size = Vector2(_slots.size() * _sprite, _sprite)
	var middle: Vector2 = Vector2(card_height * CardGeometry.ASPECT / 2.0, card_height * (BAR_TOP + 1.0) / 2.0 - LIFT)
	# On whole pixels, so that a sprite's pixels stay square.
	position = (middle - size / 2.0).round() if is_whole else middle - size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func slots() -> Array[Slot]:
	return _slots


func _draw() -> void:
	for index: int in _slots.size():
		draw_texture_rect(texture_of(_slots[index]), Rect2(index * _sprite, 0.0, _sprite, _sprite), false)


## Draws one Mod Slot on [param canvas], from inside its _draw(): its sprite, drawn so that
## the bubble in it is [param diameter] wide around [param middle].
static func draw_bubble(canvas: CanvasItem, middle: Vector2, diameter: float, slot: Slot) -> void:
	var sprite: float = diameter * SPRITE / BUBBLE
	canvas.draw_texture_rect(texture_of(slot), Rect2(middle - Vector2(sprite, sprite) / 2.0, Vector2(sprite, sprite)), false)
