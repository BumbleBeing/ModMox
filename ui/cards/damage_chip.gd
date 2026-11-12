class_name DamageChip
extends Control
## The Damage Chip (game glossary): a shaded red bead with the damage marked on a creature,
## resting on the top of its power and toughness box, over the toughness (A361). Damage does
## not lower toughness (CR 120.3), so the box keeps showing the creature's characteristics
## and the chip says what has been dealt to it this turn.

## The chip's width as a fraction of the box's height, and how much of the chip stands above
## the box's top edge.
const WIDTH: float = 0.72
const RISE: float = 0.78
const RIM: Color = Color("#2a0606")
const DARK: Color = Color("#7d0f0f")
const LIGHT: Color = Color("#f25a4c")
const RIM_WIDTH: float = 2.0
## How many circles the shading is drawn with, from the whole bead down to its highlight.
const SHADES: int = 14
## Where the highlight sits from the bead's middle, and how wide it is, in radii.
const HIGHLIGHT: Vector2 = Vector2(-0.28, -0.3)
const HIGHLIGHT_SIZE: float = 0.12
## The number's font size as a fraction of the chip's height, and a digit's height as a
## fraction of the font's ascent.
const NUMBER_SIZE: float = 0.74
const DIGIT_HEIGHT: float = 0.68

var amount: int = 0


## Where the chip goes for a power and toughness box at [param box]: centered over the
## box's right half, resting on its top edge.
static func box_over(box: Rect2) -> Rect2:
	var side: float = box.size.y * WIDTH
	return Rect2(box.position.x + box.size.x * 0.75 - side / 2.0, box.position.y - side * RISE, side, side)


## A chip saying [param damage], placed for a power and toughness box at [param box].
static func make(box: Rect2, damage: int) -> DamageChip:
	var chip: DamageChip = DamageChip.new()
	var place: Rect2 = box_over(box)
	chip.amount = damage
	chip.position = place.position
	chip.size = place.size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


## How far shading circle number [param step] is from the rim (0) to the highlight (1).
static func shade_along(step: int) -> float:
	return step / float(SHADES - 1)


static func shade_color(along: float) -> Color:
	return DARK.lerp(LIGHT, along)


## The middle of the shading circle [param along] the way to the highlight, on a bead of
## [param radius] around [param middle].
static func shade_center(middle: Vector2, radius: float, along: float) -> Vector2:
	return middle + HIGHLIGHT * radius * along


static func shade_radius(radius: float, along: float) -> float:
	return lerpf(radius - RIM_WIDTH, radius * HIGHLIGHT_SIZE, along)


func font_size() -> int:
	return int(size.y * NUMBER_SIZE)


## Where the number's baseline starts so that the digits sit in the middle of the chip.
## Digits have no descender, so they are centered on their own height, not the line's.
func number_at() -> Vector2:
	var font: Font = CardFonts.title()
	var width: float = font.get_string_size(str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size()).x
	var digit_height: float = font.get_ascent(font_size()) * DIGIT_HEIGHT
	return Vector2(size.x / 2.0 - width / 2.0, size.y / 2.0 + digit_height / 2.0)


func _draw() -> void:
	var middle: Vector2 = size / 2.0
	var radius: float = size.x / 2.0
	draw_circle(middle + Vector2(0, radius * 0.12), radius * 1.04, Color(0, 0, 0, 0.45), true, -1.0, true)
	draw_circle(middle, radius, RIM, true, -1.0, true)
	for step: int in SHADES:
		var along: float = shade_along(step)
		draw_circle(shade_center(middle, radius, along), shade_radius(radius, along), shade_color(along), true, -1.0, true)
	var at: Vector2 = number_at()
	draw_string(CardFonts.title(), at + Vector2(0, 1), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size(), Color(0, 0, 0, 0.6))
	draw_string(CardFonts.title(), at, str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size(), Color.WHITE)
