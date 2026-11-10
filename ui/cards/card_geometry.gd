class_name CardGeometry
extends RefCounted
## Where things sit on a card, as fractions of the full card (2010 × 2814 in the source
## frames), so every layout scales to any card size.

## Width over height of a whole card.
const ASPECT: float = 2010.0 / 2814.0
## The size frames are baked at: half the source frames (A209).
const BAKE_SIZE: Vector2i = Vector2i(1005, 1407)
## A card's rounded corner radius, as a fraction of its width.
const CORNER: float = 0.044

const CROWN: Rect2 = Rect2(44.0 / 2010.0, 53.0 / 2814.0, 1922.0 / 2010.0, 493.0 / 2814.0)
## The black strip that hides the frame's top edge under a crown.
const CROWN_COVER: Rect2 = Rect2(0.0, 0.0, 1.0, 137.0 / 2814.0)
const POWER_TOUGHNESS: Rect2 = Rect2(0.7573, 0.8848, 0.188, 0.0733)
const ART: Rect2 = Rect2(0.0767, 0.1129, 0.8476, 0.4429)
const TITLE: Rect2 = Rect2(0.0854, 0.0522, 0.8292, 0.0543)
const TYPE_LINE: Rect2 = Rect2(0.0854, 0.5664, 0.8292, 0.0543)
const RULES: Rect2 = Rect2(0.086, 0.6303, 0.828, 0.2875)
const POWER_TOUGHNESS_TEXT: Rect2 = Rect2(0.7928, 0.902, 0.1367, 0.0372)
## Where the artist is credited, in the black border under the frame.
const ARTIST: Rect2 = Rect2(0.075, 0.936, 0.6, 0.024)

## Mana cost pips: right edge, top and diameter (of the height), and the drop shadow's
## offset (x of the width, y of the height).
const PIPS_RIGHT: float = 0.9292
const PIPS_TOP: float = 0.0613
const PIP_DIAMETER: float = 0.0338
const PIP_SHADOW: Vector2 = Vector2(-0.001, 0.0029)

## The Battlefield Face keeps the frame's rows from the top down to the bottom of the art
## window, then the strip under the rules box, so its art gets a full border cut from the
## card's own frame.
const FIELD_TOP_END: float = 0.5551
const FIELD_BOTTOM_START: float = 0.9178
const FIELD_BOTTOM_END: float = 0.9566
## The frame's side rails, up to the art window.
const FIELD_SIDE: float = 0.0771
const FIELD_ART_TOP: float = 0.113
## The stretchable part starts below the crown, so a crown is never stretched.
const FIELD_TOP_MARGIN: float = 0.194
## A Battlefield Face is 110% as wide as it is tall (locked by the user).
const FIELD_ASPECT: float = 1.1
## Its P/T box is 1.6 times the Card Face's, relative to the card (locked by the user).
const FIELD_POWER_TOUGHNESS_SCALE: float = 1.6


## [param fraction] of a card of [param size], in pixels.
static func on_card(fraction: Rect2, size: Vector2) -> Rect2:
	return Rect2(fraction.position * size, fraction.size * size)


## The P/T text's place inside the P/T box image, as fractions of the box.
static func power_toughness_text_in_box() -> Rect2:
	var box: Rect2 = POWER_TOUGHNESS
	var text: Rect2 = POWER_TOUGHNESS_TEXT
	return Rect2((text.position - box.position) / box.size, text.size / box.size)
