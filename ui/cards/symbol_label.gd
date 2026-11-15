class_name SymbolLabel
extends RichTextLabel
## A line or more of interface text whose {X} symbols are drawn from the mana symbol images,
## as a Card Face's rules text draws them: "{2}{U}, {T}: Draw a card." shows two pips and
## the tap symbol, never the braces. Anything outside a Card Face that prints an ability, a
## cost or a sentence that names one is written with this, and never with a plain Label.
##
## Each symbol drawn has one space before and after it, added as it is drawn where the text
## has none, though never at the start or end of a line, so that it stands apart from the
## words around it (A599). What was written is kept as written.
##
## It is as tall as what is written in it and wraps at its width.

## A symbol's side, of the font's size.
const SYMBOL_SIZE: float = 1.0

var _written: String = ""
## What is drawn, with its symbols in braces and the spaces added around them.
var _shown: String = ""
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
	_start()
	_write_run(text)


## Writes [param text] in [param color], as write() does.
func write_in(text: String, color: Color) -> void:
	_written = text
	_start()
	push_color(color)
	_write_run(text)
	pop()


## Writes [param lines] one under another, as write() does, with [param between] between
## each two, each line whose index is in [param dimmed] in [param dim_color].
func write_lines(lines: Array[String], dimmed: Array[int], dim_color: Color, between: String = "\n") -> void:
	_written = between.join(lines)
	_start()
	for index: int in lines.size():
		if index > 0:
			_add(between)
		if dimmed.has(index):
			push_color(dim_color)
		_write_run(lines[index])
		if dimmed.has(index):
			pop()


## What was written, with its symbols in braces.
func written() -> String:
	return _written


## What is drawn, its symbols in braces, with the spaces added around them.
func shown() -> String:
	return _shown


## The image drawn for each symbol, in order, such as "t" for {T}.
func symbols() -> Array[String]:
	return _symbols


func _start() -> void:
	_symbols.clear()
	_shown = ""
	clear()


## Writes [param text], each symbol with an image as that image, with a space before and
## after it wherever the text has none and the line goes on.
func _write_run(text: String) -> void:
	var symbol: RegEx = RegEx.create_from_string("\\{[^}]+\\}")
	var side: int = roundi(_font_size * SYMBOL_SIZE)
	var from: int = 0
	for found: RegExMatch in symbol.search_all(text):
		_add(text.substr(from, found.get_start() - from))
		var image: String = ManaSymbols.image_for(found.get_string())
		if image == "":
			_add(found.get_string())
		else:
			if not _shown.is_empty() and not _shown.ends_with(" ") and not _shown.ends_with("\n"):
				_add(" ")
			add_image(ManaSymbols.texture(image), side, side, Color.WHITE, INLINE_ALIGNMENT_CENTER)
			_shown += found.get_string()
			_symbols.append(image)
			var next: String = text.substr(found.get_end(), 1)
			if next != "" and next != " " and next != "\n":
				_add(" ")
		from = found.get_end()
	_add(text.substr(from))


func _add(words: String) -> void:
	add_text(words)
	_shown += words
