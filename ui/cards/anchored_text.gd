class_name AnchoredText
extends Control
## One line of text pinned to a box on a card. Its baseline is worked out from the box's
## middle and the font size alone, so it never drifts out of its box however the card is
## sized. It either shrinks until it fits the box's width, or keeps its size and is cut
## short with an ellipsis.

enum Fit { SHRINK, ELLIPSIS }

## Capital letters are about this much of the font size tall.
const CAP_HEIGHT: float = 0.7
const ELLIPSIS: String = "…"
## Never shrinks below this.
const SMALLEST_FONT_SIZE: int = 4

var font_size: int = SMALLEST_FONT_SIZE

## Runs of text drawn one after another, each in its own color, so P/T can color each number.
var _texts: Array[String] = []
var _colors: Array[Color] = []
var _font: Font
var _align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT


## Pins [param texts] (one run per color in [param colors]) to [param box]. The text is at
## most [param fill] of the box's height, plus [param bonus] points.
func setup(box: Rect2, texts: Array[String], colors: Array[Color], font: Font, fill: float,
		align: HorizontalAlignment, fit: Fit, bonus: int = 0) -> void:
	assert(texts.size() == colors.size(), "One color per run of text.")
	position = box.position
	size = box.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texts = texts.duplicate()
	_colors = colors.duplicate()
	_font = font
	_align = align
	font_size = maxi(SMALLEST_FONT_SIZE, floori(size.y * fill)) + bonus
	if fit == Fit.ELLIPSIS:
		_cut_to_fit()
	else:
		while font_size > SMALLEST_FONT_SIZE and text_width() > size.x:
			font_size -= 1
	queue_redraw()


## The text as drawn, after any cut.
func shown_text() -> String:
	return "".join(PackedStringArray(_texts))


func text_width() -> float:
	var total: float = 0.0
	for text: String in _texts:
		total += _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return total


## The baseline's distance from the box's top: the capitals are centered in the box.
func baseline() -> float:
	return size.y / 2.0 + font_size * CAP_HEIGHT / 2.0


func _draw() -> void:
	var x: float = 0.0
	if _align == HORIZONTAL_ALIGNMENT_CENTER:
		x = (size.x - text_width()) / 2.0
	elif _align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = size.x - text_width()
	for index: int in _texts.size():
		draw_string(_font, Vector2(x, baseline()), _texts[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _colors[index])
		x += _font.get_string_size(_texts[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Cuts the last run short, ending it with an ellipsis, until everything fits.
func _cut_to_fit() -> void:
	var last: int = _texts.size() - 1
	var whole: String = _texts[last]
	var kept: int = whole.length()
	while text_width() > size.x and kept > 0:
		kept -= 1
		_texts[last] = whole.left(kept).strip_edges() + ELLIPSIS
