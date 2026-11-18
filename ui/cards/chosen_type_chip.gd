class_name ChosenTypeChip
extends RefCounted
## The Chosen Type Chip (game glossary, game ADR 0053): a permanent's chosen creature type,
## drawn as a Keyword Chip holding the type's name, first in the chips' row of its
## Battlefield Face. It is as tall as the keyword chips beside it and as wide as its name.
## Its words never shrink below SMALLEST_FONT_SIZE: on a face too small to show the whole
## name at that size, the name is cut short with an ellipsis. The Inspector always has it in
## full.

## Readable at 1080p (milestone 13's rule for a face's smallest words).
const SMALLEST_FONT_SIZE: int = 12
## The words are about this much of the chip's height, as a Keyword Chip's letters are.
const FILL: float = 0.5
const ELLIPSIS: String = "…"

## What the chip says: the name, or as much of it as fits with an ellipsis.
var shown_text: String = ""
var font_size: int = SMALLEST_FONT_SIZE
## Its width in pixels.
var width: float = 0.0
var side: float = 0.0


## How a chip [param chip_side] pixels tall shows [param creature_type] in at most
## [param widest] pixels.
static func fit(creature_type: String, chip_side: float, widest: float, font: Font = null) -> ChosenTypeChip:
	var made: ChosenTypeChip = ChosenTypeChip.new()
	var using: Font = font if font != null else CardFonts.title()
	made.side = chip_side
	made.font_size = maxi(SMALLEST_FONT_SIZE, floori(chip_side * FILL))
	var room: float = widest - _padding(chip_side)
	var text: String = creature_type
	if _width_of(text, using, made.font_size) > room:
		while text.length() > 1 and _width_of(text + ELLIPSIS, using, made.font_size) > room:
			text = text.substr(0, text.length() - 1)
		text = text.strip_edges() + ELLIPSIS
	made.shown_text = text
	made.width = minf(widest, maxf(chip_side, _width_of(text, using, made.font_size) + _padding(chip_side)))
	return made


## The chip itself, at [param at] on a face.
func make(at: Vector2) -> Panel:
	var panel: Panel = CardShapes.rounded(Vector2(width, side), side * 0.25, Color(0.08, 0.08, 0.1, 0.88))
	panel.name = "ChosenTypeChip"
	panel.position = at
	panel.add_child(CardShapes.outline(panel.size, side * 0.25, side / 16.0, Color(1, 1, 1, 0.55)))
	var words: Label = Label.new()
	words.text = shown_text
	words.add_theme_font_override("font", CardFonts.title())
	words.add_theme_font_size_override("font_size", font_size)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.size = panel.size
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(words)
	return panel


static func _padding(chip_side: float) -> float:
	return maxf(8.0, chip_side * 0.5)


static func _width_of(text: String, font: Font, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
