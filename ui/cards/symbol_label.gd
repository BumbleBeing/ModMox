class_name SymbolLabel
extends RichTextLabel
## A line or more of interface text whose {X} symbols are drawn from the mana symbol images,
## as a Card Face's rules text draws them: "{2}{U}, {T}: Draw a card." shows two pips and
## the tap symbol, never the braces. Anything outside a Card Face that prints an ability, a
## cost or a sentence that names one is written with this, and never with a plain Label.
##
## It is as tall as what is written in it and wraps at its width.

## A symbol's side, of the font's size.
const SYMBOL_SIZE: float = 1.0

var _written: String = ""
var _symbols: Array[String] = []
var _font_size: int = 16


func _init() -> void:
	fit_content = true
	scroll_active = false
	bbcode_enabled = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_font_size(_font_size)


## Sets the size of the words and, with them, of the symbols. Set it before writing.
func set_font_size(font_size: int) -> void:
	_font_size = font_size
	add_theme_font_size_override("normal_font_size", font_size)


## Writes [param text] in place of what was written, each {X} symbol in it as its image. A
## symbol there is no image for stays as text.
func write(text: String) -> void:
	_written = text
	_symbols.clear()
	clear()
	_write_run(text)


## Writes [param text] in [param color], as write() does.
func write_in(text: String, color: Color) -> void:
	_written = text
	_symbols.clear()
	clear()
	push_color(color)
	_write_run(text)
	pop()


## Writes [param lines] one under another, as write() does, with [param between] between
## each two, each line whose index is in [param dimmed] in [param dim_color].
func write_lines(lines: Array[String], dimmed: Array[int], dim_color: Color, between: String = "\n") -> void:
	_written = between.join(lines)
	_symbols.clear()
	clear()
	for index: int in lines.size():
		if index > 0:
			add_text(between)
		if dimmed.has(index):
			push_color(dim_color)
		_write_run(lines[index])
		if dimmed.has(index):
			pop()


## What was written, with its symbols in braces.
func written() -> String:
	return _written


## The image drawn for each symbol, in order, such as "t" for {T}.
func symbols() -> Array[String]:
	return _symbols


func _write_run(text: String) -> void:
	var symbol: RegEx = RegEx.create_from_string("\\{[^}]+\\}")
	var side: int = roundi(_font_size * SYMBOL_SIZE)
	var from: int = 0
	for found: RegExMatch in symbol.search_all(text):
		add_text(text.substr(from, found.get_start() - from))
		var image: String = ManaSymbols.image_for(found.get_string())
		if image == "":
			add_text(found.get_string())
		else:
			add_image(ManaSymbols.texture(image), side, side, Color.WHITE, INLINE_ALIGNMENT_CENTER)
			_symbols.append(image)
		from = found.get_end()
	add_text(text.substr(from))
