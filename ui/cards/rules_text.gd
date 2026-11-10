class_name RulesText
extends Control
## A Card Face's rules text. Words wrap, {X} symbols are drawn inline from the mana symbol
## images, and reminder text in parentheses is italic. The text shrinks to fit, but never
## below three quarters of its largest size; past that it scrolls (A236), by the wheel
## over either of the card's faces or by dragging its scroll bar.

## A wheel step scrolls this many lines.
const LINES_PER_STEP: float = 1.5
const LINE_SPACING: float = 1.18
const PARAGRAPH_GAP: float = 0.4
## How far down from a line's top its baseline sits, as a fraction of the font size.
const ASCENT: float = 0.9
const SYMBOL_SIZE: float = 0.8
const SYMBOL_GAP: float = 0.06
## Text is centered while it fits; this much of the box stays clear.
const FILL: float = 0.92

var font_size: int = 8

var _paragraphs: Array[Array] = []  # each paragraph: its words; each word: its Segments
var _lines: Array[Array] = []  # each line: its PlacedSegments; empty marks a paragraph gap
var _largest_font_size: int = 8
var _content_height: float = 0.0
var _scroll_bar: VScrollBar = null
## Width kept clear of text for the scroll bar.
var _reserve: float = 0.0
var _body: Font
var _italic: Font


## A run of text or one symbol, within a word.
class Segment:
	extends RefCounted
	var text: String = ""
	var is_symbol: bool = false
	var is_italic: bool = false


class PlacedSegment:
	extends RefCounted
	var segment: Segment
	var x: float = 0.0


## Lays [param text] out in [param box], at most [param largest_size] points. A scroll bar,
## when one is needed, is at most [param bar_height] tall (it stops above a P/T box).
func setup(box: Rect2, text: String, largest_size: float, bar_height: float) -> void:
	position = box.position
	size = box.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body = CardFonts.body()
	_italic = CardFonts.italic()
	_paragraphs = _parse(text)
	_largest_font_size = maxi(AnchoredText.SMALLEST_FONT_SIZE, floori(largest_size))
	font_size = _largest_font_size
	while font_size > smallest_font_size() and _layout() > size.y * FILL:
		font_size -= 1
	_content_height = _layout()
	if overflows():
		_add_scroll_bar(bar_height)
	queue_redraw()


func smallest_font_size() -> int:
	return maxi(7, floori(_largest_font_size * 0.75))


func overflows() -> bool:
	return _content_height > size.y * FILL


func has_scroll_bar() -> bool:
	return _scroll_bar != null


func scroll_bar_height() -> float:
	return _scroll_bar.size.y if _scroll_bar != null else 0.0


func line_height() -> float:
	return font_size * LINE_SPACING


func content_height() -> float:
	return _content_height


## Space below the last line when scrolled to the bottom.
func bottom_padding() -> float:
	return font_size * 0.6


func scroll_offset() -> float:
	return _scroll_bar.value if _scroll_bar != null else 0.0


## Scrolls by [param steps] wheel steps; negative scrolls up. Does nothing when it fits.
func scroll_lines(steps: float) -> void:
	if _scroll_bar != null:
		_scroll_bar.value += steps * line_height() * LINES_PER_STEP


## The symbols in the text, in order, such as "{T}".
func symbols() -> Array[String]:
	var found: Array[String] = []
	for paragraph: Array in _paragraphs:
		for word: Array in paragraph:
			for segment: Segment in word:
				if segment.is_symbol:
					found.append(segment.text)
	return found


func _add_scroll_bar(bar_height: float) -> void:
	var thin: float = maxf(4.0, size.x * 0.025)
	_reserve = thin + 2.0
	_content_height = _layout()
	_scroll_bar = VScrollBar.new()
	_scroll_bar.size = Vector2(thin, minf(size.y, bar_height) - 4.0)
	_scroll_bar.position = Vector2(size.x - thin - 1.0, 2.0)
	_scroll_bar.step = 0.0
	_scroll_bar.max_value = _content_height + bottom_padding()
	_scroll_bar.page = size.y
	_scroll_bar.value_changed.connect(func(_value: float) -> void: queue_redraw())
	add_child(_scroll_bar)


func _draw() -> void:
	var top: float = (size.y - _content_height) / 2.0
	if _scroll_bar != null:
		top = font_size * 0.3 - _scroll_bar.value
	var baseline: float = top + font_size * ASCENT
	for line: Array in _lines:
		if line.is_empty():
			baseline += font_size * PARAGRAPH_GAP
			continue
		for placed: PlacedSegment in line:
			if placed.segment.is_symbol:
				var image_name: String = ManaSymbols.image_for(placed.segment.text)
				if image_name != "":
					var symbol: float = font_size * SYMBOL_SIZE
					var center: float = baseline - font_size * AnchoredText.CAP_HEIGHT / 2.0
					draw_texture_rect(ManaSymbols.texture(image_name), Rect2(placed.x, center - symbol / 2.0, symbol, symbol), false)
			else:
				draw_string(_font_for(placed.segment), Vector2(placed.x, baseline), placed.segment.text,
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
		baseline += line_height()


## Lays the text out at the current font size; returns its height.
func _layout() -> float:
	_lines = []
	var pad: float = size.x * 0.035
	var width: float = size.x - pad * 2.0 - _reserve
	var space: float = _body.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var height: float = 0.0
	for index: int in _paragraphs.size():
		if index > 0:
			_lines.append([])
			height += font_size * PARAGRAPH_GAP
		var line: Array[PlacedSegment] = []
		var x: float = 0.0
		for word: Array in _paragraphs[index]:
			var word_width: float = 0.0
			for segment: Segment in word:
				word_width += _width_of(segment)
			if x > 0.0 and x + word_width > width:
				_lines.append(line)
				height += line_height()
				line = []
				x = 0.0
			for segment: Segment in word:
				var placed: PlacedSegment = PlacedSegment.new()
				placed.segment = segment
				placed.x = pad + x
				line.append(placed)
				x += _width_of(segment)
			x += space
		_lines.append(line)
		height += line_height()
	return height


func _width_of(segment: Segment) -> float:
	if segment.is_symbol:
		return font_size * (SYMBOL_SIZE + SYMBOL_GAP)
	return _font_for(segment).get_string_size(segment.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _font_for(segment: Segment) -> Font:
	return _italic if segment.is_italic else _body


## Splits [param text] into paragraphs of words of segments. Reminder text runs from a word
## starting with "(" to the word that closes it.
static func _parse(text: String) -> Array[Array]:
	var paragraphs: Array[Array] = []
	var in_reminder: bool = false
	for paragraph_text: String in text.split("\n"):
		var words: Array = []
		for word_text: String in paragraph_text.split(" ", false):
			if word_text.begins_with("("):
				in_reminder = true
			var word: Array[Segment] = []
			var rest: String = word_text
			while rest != "":
				var open: int = rest.find("{")
				var close: int = rest.find("}", open)
				if open == -1 or close == -1:
					word.append(_segment(rest, false, in_reminder))
					break
				if open > 0:
					word.append(_segment(rest.left(open), false, in_reminder))
				word.append(_segment(rest.substr(open, close - open + 1), true, in_reminder))
				rest = rest.substr(close + 1)
			words.append(word)
			if word_text.contains(")"):
				in_reminder = false
		paragraphs.append(words)
	return paragraphs


static func _segment(text: String, is_symbol: bool, is_italic: bool) -> Segment:
	var segment: Segment = Segment.new()
	segment.text = text
	segment.is_symbol = is_symbol
	segment.is_italic = is_italic
	return segment
