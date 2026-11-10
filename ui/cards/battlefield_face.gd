class_name BattlefieldFace
extends Control
## How a permanent is drawn on the battlefield: the top of its Frame (name box or crown) and
## a border around its art, a large P/T box, and a chip for each keyword. It shows no other
## text, and turns sideways and darkens when tapped, with an upright tap symbol over its art.

## The wheel over this face asks for its Card Face's rules text to scroll (A236).
signal rules_scroll_requested(steps: float)

## How dark a tapped face gets.
const TAPPED_SHADE: float = 0.45
## A P/T box's height on the Card Face, as a fraction of the card's height.
const CARD_FACE_BOX: float = 0.14

var _look: CardLook
var _card: Control
var _name: AnchoredText
var _shade: ColorRect = null
var _tap_symbol: TextureRect = null
var _chips: Array[KeywordChip] = []


## A Battlefield Face's size when untapped, [param height] pixels tall.
static func size_for(height: float) -> Vector2:
	return Vector2(roundf(height * CardGeometry.FIELD_ASPECT), height)


## Where the art sits on a face [param height] pixels tall.
static func art_box(height: float) -> Rect2:
	var scale_now: float = _scale(height)
	var side: float = CardGeometry.FIELD_SIDE * CardGeometry.BAKE_SIZE.x * scale_now
	var top: float = CardGeometry.FIELD_ART_TOP * CardGeometry.BAKE_SIZE.y * scale_now
	var bottom: float = CardGeometry.FIELD_TOP_END * CardGeometry.BAKE_SIZE.y * scale_now
	return Rect2(side, top, size_for(height).x - side * 2.0, bottom - top)


## Where the P/T box sits on a face [param height] pixels tall.
static func power_toughness_box(height: float) -> Rect2:
	var box_height: float = height * CARD_FACE_BOX * CardGeometry.FIELD_POWER_TOUGHNESS_SCALE
	var box_size: Vector2 = Vector2(box_height * 377.0 / 206.0, box_height)
	var side: float = CardGeometry.FIELD_SIDE * CardGeometry.BAKE_SIZE.x * _scale(height)
	return Rect2(size_for(height) - box_size - Vector2(side * 0.55, side * 0.25), box_size)


## The width keyword chips have, from the art's left edge to the P/T box (or the art's
## right edge, for a noncreature).
static func chip_room(height: float, is_creature: bool) -> float:
	var art: Rect2 = art_box(height)
	var end: float = power_toughness_box(height).position.x if is_creature else art.end.x
	return end - art.position.x


## Wheel steps in [param event]: 1 down, -1 up, 0 for anything else.
static func wheel_steps(event: InputEvent) -> float:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return 0.0
	if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		return 1.0
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		return -1.0
	return 0.0


## Draws [param look] [param height] pixels tall (before any turn for being tapped).
func setup(look: CardLook, height: float) -> void:
	_look = look
	var face_size: Vector2 = size_for(height)
	custom_minimum_size = Vector2(face_size.y, face_size.x) if look.is_tapped else face_size
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	_card = Control.new()
	_card.size = face_size
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var spec: FrameSpec = FrameSpec.of(look)
	var scale_now: float = _scale(height)
	var shape: Panel = CardShapes.rounded(face_size, CardGeometry.CORNER * CardGeometry.BAKE_SIZE.x * scale_now, Color.BLACK, true)
	_card.add_child(shape)
	var art: Rect2 = art_box(height)
	var cropped: Texture2D = ArtLibrary.shared().cropped(look.art_key, art.size)
	if cropped != null:
		shape.add_child(CardShapes.image(cropped, art))
	shape.add_child(_border(spec, face_size, scale_now))
	var inset: float = CardGeometry.TITLE.position.x * CardGeometry.BAKE_SIZE.x * scale_now
	_name = AnchoredText.new()
	_name.setup(Rect2(inset, CardGeometry.TITLE.position.y * CardGeometry.BAKE_SIZE.y * scale_now,
			face_size.x - inset * 2.0, CardGeometry.TITLE.size.y * CardGeometry.BAKE_SIZE.y * scale_now),
			[look.name] as Array[String], [Color.BLACK] as Array[Color], CardFonts.title(), 0.78,
			HORIZONTAL_ALIGNMENT_LEFT, AnchoredText.Fit.ELLIPSIS)
	shape.add_child(_name)
	if spec.is_creature:
		_add_power_toughness(shape, spec, height)
	_add_chips(shape, height, spec.is_creature)
	if look.is_tapped:
		_show_tapped(shape, face_size, art)


## The part that turns sideways when tapped.
func card() -> Control:
	return _card


func name_text() -> AnchoredText:
	return _name


func is_darkened() -> bool:
	return _shade != null


## The upright tap symbol over a tapped face's art, or null when untapped.
func tap_symbol() -> TextureRect:
	return _tap_symbol


func chip_letters() -> Array[String]:
	var letters: Array[String] = []
	for chip: KeywordChip in _chips:
		letters.append(chip.letters)
	return letters


## Asks for the Card Face's rules text to scroll for a wheel event over this face.
func scroll_by_wheel(event: InputEvent) -> bool:
	var steps: float = wheel_steps(event)
	if steps == 0.0:
		return false
	rules_scroll_requested.emit(steps)
	return true


func _gui_input(event: InputEvent) -> void:
	if wheel_steps(event) != 0.0 and rules_scroll_requested.get_connections().size() > 0:
		scroll_by_wheel(event)
		accept_event()


## The border is drawn at its baked pixel size, then scaled; only its middle stretches.
func _border(spec: FrameSpec, face_size: Vector2, scale_now: float) -> NinePatchRect:
	var patch: NinePatchRect = NinePatchRect.new()
	patch.texture = FrameBaker.field_border_texture(spec)
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	patch.patch_margin_left = ceili(CardGeometry.FIELD_SIDE * CardGeometry.BAKE_SIZE.x) + 1
	patch.patch_margin_right = patch.patch_margin_left
	patch.patch_margin_top = roundi(CardGeometry.FIELD_TOP_MARGIN * CardGeometry.BAKE_SIZE.y)
	patch.patch_margin_bottom = FrameBaker.field_border_height() - roundi(CardGeometry.FIELD_TOP_END * CardGeometry.BAKE_SIZE.y)
	patch.size = face_size / scale_now
	patch.scale = Vector2(scale_now, scale_now)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return patch


func _add_power_toughness(shape: Panel, spec: FrameSpec, height: float) -> void:
	var box: Rect2 = power_toughness_box(height)
	shape.add_child(CardShapes.image(FrameBaker.source_texture(spec.power_toughness_image(), Vector2i(377, 206)), box))
	var text_box: Rect2 = CardGeometry.power_toughness_text_in_box()
	var text: AnchoredText = AnchoredText.new()
	text.setup(Rect2(box.position + text_box.position * box.size, text_box.size * box.size),
			_look.power_toughness_texts(), _look.power_toughness_colors(), CardFonts.title(), 1.1,
			HORIZONTAL_ALIGNMENT_CENTER, AnchoredText.Fit.SHRINK)
	shape.add_child(text)


## Chips run along the bottom of the art from the left toward the P/T box.
func _add_chips(shape: Panel, height: float, is_creature: bool) -> void:
	var all: Array[KeywordChip] = KeywordChips.chips_for(_look.abilities)
	if all.is_empty():
		return
	var room: float = chip_room(height, is_creature)
	var chip: float = KeywordChips.chip_size(height, room)
	var gap: float = KeywordChips.gap(chip)
	_chips = KeywordChips.shown(all, KeywordChips.fit_count(chip, room))
	var art: Rect2 = art_box(height)
	var at: Vector2 = Vector2(art.position.x + gap, art.end.y - chip - gap)
	for keyword: KeywordChip in _chips:
		shape.add_child(CardShapes.chip(keyword, at, chip))
		at.x += chip + gap


## Turns the face sideways and darkens it, with a tap symbol at half opacity over the art,
## turned back so it stays upright.
func _show_tapped(shape: Panel, face_size: Vector2, art: Rect2) -> void:
	_card.pivot_offset = face_size / 2.0
	_card.rotation_degrees = 90.0
	_card.position = (custom_minimum_size - face_size) / 2.0
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, TAPPED_SHADE)
	_shade.size = face_size
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.add_child(_shade)
	var side: float = minf(art.size.x, art.size.y) * 0.92
	_tap_symbol = CardShapes.image(ManaSymbols.texture("t"), Rect2(art.get_center() - Vector2(side, side) / 2.0, Vector2(side, side)))
	_tap_symbol.modulate = Color(1, 1, 1, 0.5)
	_tap_symbol.pivot_offset = Vector2(side, side) / 2.0
	_tap_symbol.rotation_degrees = -90.0
	shape.add_child(_tap_symbol)


## How much the baked border is scaled to make a face [param height] pixels tall.
static func _scale(height: float) -> float:
	return height / FrameBaker.field_border_height()
