class_name CounterChip
extends Control
## The Counter Chip (game glossary): a shaded bead in the top left corner of a permanent's
## art that says how many counters of one kind are on it, with their sign: green and "+2"
## for +1/+1 counters, violet and "-2" for -1/-1 counters. It is the Damage Chip's bead in
## another color and place, so the two can be told apart at a glance and never overlap. The
## power and toughness box already shows what the counters add up to.

## How far the chip stands in from the art's top and left edges: one unit.
const INSET: float = 4.0
const PLUS_DARK: Color = Color("#0f4a1c")
const PLUS_LIGHT: Color = Color("#6fe06a")
const MINUS_DARK: Color = Color("#34104f")
const MINUS_LIGHT: Color = Color("#c07af0")
## The number's font size as a fraction of the chip's height: a sign and one digit, and
## anything longer.
const NUMBER_SIZE: float = 0.6
const LONG_NUMBER_SIZE: float = 0.46

var kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
var amount: int = 0


## Where the chip goes on a face whose art is at [param art] and whose power and toughness
## box is at [param box]: in the art's top left corner, the size of a Damage Chip.
static func box_in(art: Rect2, box: Rect2) -> Rect2:
	return Rect2(art.position + Vector2(INSET, INSET), DamageChip.box_over(box).size)


## A chip saying [param count] counters of [param counter_kind], placed for a face whose
## art is at [param art] and whose power and toughness box is at [param box].
static func make(art: Rect2, box: Rect2, counter_kind: MmCounter.Kind, count: int) -> CounterChip:
	var chip: CounterChip = CounterChip.new()
	var place: Rect2 = box_in(art, box)
	chip.kind = counter_kind
	chip.amount = count
	chip.position = place.position
	chip.size = place.size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


## What a chip for [param count] counters of [param counter_kind] reads: "+2" or "-2".
static func label_of(counter_kind: MmCounter.Kind, count: int) -> String:
	return ("+" if MmCounter.power_toughness_change(counter_kind) > 0 else "-") + str(count)


## The bead's color at its rim, for [param counter_kind].
static func dark_of(counter_kind: MmCounter.Kind) -> Color:
	return PLUS_DARK if counter_kind == MmCounter.Kind.PLUS_ONE_PLUS_ONE else MINUS_DARK


## The bead's color at its highlight, for [param counter_kind].
static func light_of(counter_kind: MmCounter.Kind) -> Color:
	return PLUS_LIGHT if counter_kind == MmCounter.Kind.PLUS_ONE_PLUS_ONE else MINUS_LIGHT


func label() -> String:
	return label_of(kind, amount)


func font_size() -> int:
	return int(size.y * (NUMBER_SIZE if label().length() <= 2 else LONG_NUMBER_SIZE))


## Where the number's baseline starts so that it sits in the middle of the chip, centered
## on the digits' own height as the Damage Chip's is.
func number_at() -> Vector2:
	var font: Font = CardFonts.title()
	var width: float = font.get_string_size(label(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size()).x
	var digit_height: float = font.get_ascent(font_size()) * DamageChip.DIGIT_HEIGHT
	return Vector2(size.x / 2.0 - width / 2.0, size.y / 2.0 + digit_height / 2.0)


func _draw() -> void:
	var middle: Vector2 = size / 2.0
	var radius: float = size.x / 2.0
	draw_circle(middle + Vector2(0, radius * 0.12), radius * 1.04, Color(0, 0, 0, 0.45), true, -1.0, true)
	draw_circle(middle, radius, DamageChip.RIM, true, -1.0, true)
	for step: int in DamageChip.SHADES:
		var along: float = DamageChip.shade_along(step)
		draw_circle(DamageChip.shade_center(middle, radius, along), DamageChip.shade_radius(radius, along),
			dark_of(kind).lerp(light_of(kind), along), true, -1.0, true)
	var at: Vector2 = number_at()
	# A dark outline: the number is smaller than a Damage Chip's and sits on a lighter bead.
	for offset: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(0, 2)]:
		draw_string(CardFonts.title(), at + offset, label(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size(), Color(0, 0, 0, 0.8))
	draw_string(CardFonts.title(), at, label(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size(), Color.WHITE)
