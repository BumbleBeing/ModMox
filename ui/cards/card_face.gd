class_name CardFace
extends Control
## A card drawn in full: its Frame, art, name, mana cost, type line, rules text, P/T and
## artist. Used wherever a card is read rather than played on: the hand, the stack, zone
## viewers and the inspector.

var _look: CardLook
var _art: TextureRect = null
var _art_fallback: AnchoredText = null
var _title: AnchoredText
var _type_line: AnchoredText
var _artist: AnchoredText = null
var _rules: RulesText = null
var _shape: Panel = null
## The Keyword Chips shown, and where each is, in the face's own coordinates.
var _chips: Array[KeywordChip] = []
var _chip_rects: Array[Rect2] = []


## Draws [param look] [param height] pixels tall.
func setup(look: CardLook, height: float) -> void:
	_look = look
	var size_now: Vector2 = Vector2(height * CardGeometry.ASPECT, height)
	custom_minimum_size = size_now
	size = size_now
	mouse_filter = Control.MOUSE_FILTER_PASS
	var shape: Panel = CardShapes.rounded(size_now, size_now.x * CardGeometry.CORNER, Color.BLACK, true)
	add_child(shape)
	_shape = shape
	var spec: FrameSpec = FrameSpec.of(look)
	_add_art(shape, CardGeometry.on_card(CardGeometry.ART, size_now))
	shape.add_child(CardShapes.image(FrameBaker.texture(spec), Rect2(Vector2.ZERO, size_now)))
	var pips_left: float = _add_pips(shape, size_now)
	var title_box: Rect2 = CardGeometry.on_card(CardGeometry.TITLE, size_now)
	title_box.size.x = pips_left - title_box.position.x - CardGeometry.PIP_DIAMETER * size_now.y * 0.3
	_title = _text(shape, title_box, [look.name], [Color.BLACK], CardFonts.title(), 0.78, HORIZONTAL_ALIGNMENT_LEFT)
	_type_line = _text(shape, CardGeometry.on_card(CardGeometry.TYPE_LINE, size_now), look.type_line_texts(),
			look.type_line_colors(), CardFonts.title(), 0.68, HORIZONTAL_ALIGNMENT_LEFT)
	_add_rules(shape, size_now, spec)
	if spec.is_creature:
		_text(shape, CardGeometry.on_card(CardGeometry.POWER_TOUGHNESS_TEXT, size_now), look.power_toughness_texts(),
				look.power_toughness_colors(), CardFonts.title(), 1.1, HORIZONTAL_ALIGNMENT_CENTER)
	var artist: String = ArtLibrary.shared().artist(look.art_key) if _art != null else ""
	if artist != "":
		# The artist, in the black border under the frame, two points larger than it fits.
		_artist = _text(shape, CardGeometry.on_card(CardGeometry.ARTIST, size_now), ["Illus. " + artist],
				[Color(1, 1, 1, 0.9)], CardFonts.body(), 0.9, HORIZONTAL_ALIGNMENT_LEFT, AnchoredText.Fit.ELLIPSIS, 2)


## Shows the Keyword Chips of a card in a graveyard, along the bottom of its art from the
## left as a Battlefield Face's run: flashback's, the one keyword that matters there.
func show_graveyard_chips() -> void:
	var chips: Array[KeywordChip] = KeywordChips.chips_for(_look.abilities, KeywordChips.Place.GRAVEYARD)
	if chips.is_empty() or not _chips.is_empty():
		return
	var art: Rect2 = CardGeometry.on_card(CardGeometry.ART, size)
	var chip: float = KeywordChips.chip_size(size.y, art.size.x)
	var gap: float = KeywordChips.gap(chip)
	var at: Vector2 = Vector2(art.position.x + gap, art.end.y - chip - gap)
	_chips = KeywordChips.shown(chips, KeywordChips.fit_count(chip, art.size.x))
	for keyword: KeywordChip in _chips:
		_shape.add_child(CardShapes.chip(keyword, at, chip))
		_chip_rects.append(Rect2(at, Vector2(chip, chip)))
		at.x += chip + gap


## The Keyword Chips shown, none until show_graveyard_chips().
func chips() -> Array[KeywordChip]:
	return _chips


## Where each chip in chips() is, in the face's own coordinates.
func chip_rects() -> Array[Rect2]:
	return _chip_rects


## The rules text, or null when the card has none.
func rules() -> RulesText:
	return _rules


func art() -> TextureRect:
	return _art


func art_fallback_text() -> AnchoredText:
	return _art_fallback


func title_text() -> AnchoredText:
	return _title


func type_line_text() -> AnchoredText:
	return _type_line


func artist_text() -> AnchoredText:
	return _artist


## Scrolls the rules text by [param steps] wheel steps, when it overflows. A Battlefield
## Face's rules_scroll_requested connects here.
func scroll_rules(steps: float) -> void:
	if _rules != null:
		_rules.scroll_lines(steps)


## Scrolls the rules text for a wheel event over this face. Returns whether it did, so a
## wheel over text that fits is left for the page.
func scroll_by_wheel(event: InputEvent) -> bool:
	var steps: float = BattlefieldFace.wheel_steps(event)
	if steps == 0.0 or _rules == null or not _rules.overflows():
		return false
	scroll_rules(steps)
	return true


func _gui_input(event: InputEvent) -> void:
	if scroll_by_wheel(event):
		accept_event()


func _add_art(shape: Panel, box: Rect2) -> void:
	var cropped: Texture2D = ArtLibrary.shared().cropped(_look.art_key, box.size)
	if cropped != null:
		_art = CardShapes.image(cropped, box)
		shape.add_child(_art)
		return
	var fallback: ColorRect = ColorRect.new()
	fallback.color = Color("#3a3f47")
	fallback.position = box.position
	fallback.size = box.size
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.add_child(fallback)
	_art_fallback = _text(fallback, Rect2(box.size * Vector2(0.05, 0.4), box.size * Vector2(0.9, 0.2)),
			[_look.name], [Color(1, 1, 1, 0.75)], CardFonts.body(), 0.8, HORIZONTAL_ALIGNMENT_CENTER)


## Draws the mana cost right-aligned, each pip over a drop-shadow disc; returns its left edge.
func _add_pips(shape: Panel, card_size: Vector2) -> float:
	var names: Array[String] = ManaSymbols.pip_names(_look.mana_cost)
	var diameter: float = CardGeometry.PIP_DIAMETER * card_size.y
	var top: float = CardGeometry.PIPS_TOP * card_size.y
	var left: float = CardGeometry.PIPS_RIGHT * card_size.x
	for index: int in range(names.size() - 1, -1, -1):
		left -= diameter
		var shadow: Panel = CardShapes.rounded(Vector2(diameter, diameter), diameter, Color.BLACK)
		shadow.position = Vector2(left, top) + CardGeometry.PIP_SHADOW * card_size
		shape.add_child(shadow)
		shape.add_child(CardShapes.image(ManaSymbols.texture(names[index]), Rect2(left, top, diameter, diameter)))
		left -= diameter * 0.08
	return left


func _add_rules(shape: Panel, card_size: Vector2, spec: FrameSpec) -> void:
	var text: String = _look.printed_rules_text()
	if text == "":
		return
	var box: Rect2 = CardGeometry.on_card(CardGeometry.RULES, card_size)
	# The scroll bar stops short of the P/T box, which overlaps the rules box's corner.
	var bar_height: float = box.size.y
	if spec.is_creature:
		bar_height = (CardGeometry.POWER_TOUGHNESS.position.y - CardGeometry.RULES.position.y - 0.004) * card_size.y
	_rules = RulesText.new()
	_rules.setup(box, text, CardGeometry.TYPE_LINE.size.y * card_size.y * 0.68, bar_height)
	shape.add_child(_rules)


static func _text(parent: Control, box: Rect2, texts: Array[String], colors: Array[Color], font: Font,
		fill: float, align: HorizontalAlignment, fit: AnchoredText.Fit = AnchoredText.Fit.SHRINK,
		bonus: int = 0) -> AnchoredText:
	var text: AnchoredText = AnchoredText.new()
	text.setup(box, texts, colors, font, fill, align, fit, bonus)
	parent.add_child(text)
	return text
