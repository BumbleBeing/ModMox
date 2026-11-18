class_name AttachedMark
extends Panel
## The Attached Mark (game glossary): a white square with a black plus in the corner of an
## attachment's Battlefield Face, past the end of its name, that says the permanent is
## attached to the one it lies behind (game ADR 0042). It is as wide as the strip of the
## card that shows, so it is flush with the permanent in front, and it is black where the
## card's own black border runs under it, so that border goes round the corner unbroken.
## Drawn from shapes, not a sprite: it is sized to the card, never a whole multiple of 16.

## The thin black edge on its two inner sides.
const EDGE: int = 2
## How far its plus reaches across the white, and how thick each arm is, of the white's side.
const PLUS_REACH: float = 0.6
const PLUS_ARM: float = 0.18

var _arms: Array[ColorRect] = []


## Where the mark goes on an upright card of [param card_size] of which a strip
## [param strip] wide shows: the top right corner, the bottom right as the card lies
## sideways.
static func box_on(card_size: Vector2, strip: float) -> Rect2:
	return Rect2(card_size.x - strip, 0.0, strip, strip)


## The white part of a mark [param side] across whose card border is [param rim] thick.
static func inside(side: float, rim: int) -> Rect2:
	return Rect2(EDGE, rim, side - EDGE - rim, side - EDGE - rim)


## A mark for a card of [param card_size] of which [param strip] shows, whose black border
## is [param rim] thick and whose corners are rounded by [param corner].
static func make(card_size: Vector2, strip: float, rim: int, corner: int) -> AttachedMark:
	var mark: AttachedMark = AttachedMark.new()
	var box: Rect2 = box_on(card_size, strip)
	mark.position = box.position
	mark.size = box.size
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look: StyleBoxFlat = StyleBoxFlat.new()
	look.bg_color = Color.WHITE
	look.border_color = Color.BLACK
	look.border_width_top = rim
	look.border_width_right = rim
	look.border_width_left = EDGE
	look.border_width_bottom = EDGE
	look.corner_radius_top_right = corner
	look.anti_aliasing = true
	mark.add_theme_stylebox_override("panel", look)
	var white: Rect2 = inside(strip, rim)
	var arm: float = maxf(2.0, roundf(white.size.x * PLUS_ARM))
	var reach: float = roundf(white.size.x * PLUS_REACH)
	for arm_size: Vector2 in [Vector2(reach, arm), Vector2(arm, reach)]:
		var stroke: ColorRect = ColorRect.new()
		stroke.color = Color.BLACK
		stroke.size = arm_size
		stroke.position = (white.get_center() - arm_size / 2.0).round()
		stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_child(stroke)
		mark._arms.append(stroke)
	return mark


func plus_color() -> Color:
	return _arms[0].color


## The middle of the plus, in the mark's own coordinates.
func plus_center() -> Vector2:
	return _arms[0].position + _arms[0].size / 2.0
