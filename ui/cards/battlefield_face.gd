class_name BattlefieldFace
extends Control
## How a permanent is drawn on the battlefield: the top of its Frame (name box or crown) and
## a border around its art, a large P/T box, and a chip for each keyword. It shows no other
## text, and turns sideways and darkens when tapped, with an upright tap symbol over its art.
## A creature with damage marked on it shows a Damage Chip over its toughness, and a
## permanent with counters on it a Counter Chip in the top left corner of its art.
##
## An attachment, such as an Equipment on a creature, is drawn attached (game ADR 0042):
## sideways whether tapped or not, so that its name runs down the strip of it that shows
## past the permanent it lies behind, with an Attached Mark in the corner past the end of
## its name. Tapped, it is darkened like any tapped permanent, with no tap symbol, since
## its art is hidden. A Tucked Card, a card in exile behind the permanent that exiled it
## (game ADR 0043), lies the same way with no Attached Mark, its name running the whole
## strip.
##
## Its footprint is that of the card at rest, upright or sideways. show_turn() draws the
## card part-way between the two inside that footprint, for Face Motion.

## The wheel over this face asks for its Card Face's rules text to scroll (A236).
signal rules_scroll_requested(steps: float)

## How dark a tapped face gets.
const TAPPED_SHADE: float = 0.45
## A P/T box's height on the Card Face, as a fraction of the card's height.
const CARD_FACE_BOX: float = 0.14
## How much of an attached face shows past the permanent it lies behind, of its height:
## its name.
const ATTACHED_SHOWN: float = 0.2
## For show_turn(): the face lies as it is drawn, all the way over if drawn attached.
const AS_DRAWN: float = -1.0
## The size the P/T box's image is resized to before it is drawn.
const POWER_TOUGHNESS_PIXELS: Vector2i = Vector2i(377, 206)

var _look: CardLook
var _card: Control
var _name: AnchoredText
var _shade: ColorRect
var _tap_symbol: TextureRect
var _turn: float = 0.0
var _damage_chip: DamageChip = null
var _counter_chip: CounterChip = null
var _chips: Array[KeywordChip] = []
var _is_attached: bool = false
var _attached_mark: AttachedMark = null


## A Battlefield Face's size when untapped, [param height] pixels tall.
static func size_for(height: float) -> Vector2:
	return Vector2(roundf(height * CardGeometry.FIELD_ASPECT), height)


## How wide the part of an attached face [param height] pixels tall that shows is.
static func attached_strip(height: float) -> float:
	return roundf(height * ATTACHED_SHOWN)


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


## The P/T box drawn on a creature with the Frame [param spec], at the one size every
## Battlefield Face draws it from.
static func power_toughness_texture(spec: FrameSpec) -> ImageTexture:
	return FrameBaker.source_texture(spec.power_toughness_image(), POWER_TOUGHNESS_PIXELS)


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


## Draws [param look] [param height] pixels tall (before any turn for being tapped), drawn
## attached with [param is_drawn_attached], and as a Tucked Card, which has no Attached
## Mark, with [param is_tucked] as well.
func setup(look: CardLook, height: float, is_drawn_attached: bool = false, is_tucked: bool = false) -> void:
	_look = look
	_is_attached = is_drawn_attached
	var has_mark: bool = _is_attached and not is_tucked
	var face_size: Vector2 = size_for(height)
	custom_minimum_size = Vector2(face_size.y, face_size.x) if look.is_tapped or _is_attached else face_size
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
	# The name of a face drawn attached stops short of its Attached Mark.
	var name_end: float = face_size.x - attached_strip(height) if has_mark else face_size.x - inset
	_name.setup(Rect2(inset, CardGeometry.TITLE.position.y * CardGeometry.BAKE_SIZE.y * scale_now,
			name_end - inset, CardGeometry.TITLE.size.y * CardGeometry.BAKE_SIZE.y * scale_now),
			[look.name] as Array[String], [Color.BLACK] as Array[Color], CardFonts.title(), 0.78,
			HORIZONTAL_ALIGNMENT_LEFT, AnchoredText.Fit.ELLIPSIS)
	shape.add_child(_name)
	if spec.is_creature:
		_add_power_toughness(shape, spec, height)
	_add_chips(shape, height, spec.is_creature)
	_add_tap_marks(shape, face_size, art)
	for kind: MmCounter.Kind in MmCounter.KINDS:
		# A permanent never keeps both kinds (CR 704.5q), so the first it has is all it has.
		if _counter_chip == null and look.counters.get(kind, 0) > 0:
			_counter_chip = CounterChip.make(art, power_toughness_box(height), kind, look.counters[kind])
			_card.add_child(_counter_chip)
	if spec.is_creature and look.damage_marked > 0:
		_damage_chip = DamageChip.make(power_toughness_box(height), look.damage_marked)
		_card.add_child(_damage_chip)
	if has_mark:
		# The card's black border is as thick as the gap above a crown.
		_attached_mark = AttachedMark.make(face_size, attached_strip(height),
				roundi(CardGeometry.CROWN.position.y * CardGeometry.BAKE_SIZE.y * scale_now),
				int(CardGeometry.CORNER * CardGeometry.BAKE_SIZE.x * scale_now))
		shape.add_child(_attached_mark)
		shape.move_child(_attached_mark, _shade.get_index())
	_card.pivot_offset = face_size / 2.0
	show_turn(1.0 if look.is_tapped else 0.0)


## The part that turns sideways when tapped.
func card() -> Control:
	return _card


func name_text() -> AnchoredText:
	return _name


## Whether this face is drawn lying behind another permanent: attached to it, or tucked.
func is_attached() -> bool:
	return _is_attached


## The Attached Mark of a face drawn attached, or null.
func attached_mark() -> AttachedMark:
	return _attached_mark


## Draws the card [param turn] of the way from upright (0) to sideways (1) for being
## tapped, darkened that much, about the middle of its footprint. [param lean] is how far
## it lies sideways for being attached (0 standing, 1 lying behind its permanent), which is
## all the way for a face drawn attached unless something else is said, as Face Motion
## says while the face is on its way. Tapped and lying down are the same quarter turn, so
## the card is turned by the larger of the two. The tap symbol is kept upright and is as
## solid as the card is tapped and not lying down; the Attached Mark is as solid as the card
## lies down.
func show_turn(turn: float, lean: float = AS_DRAWN) -> void:
	_turn = turn
	var lying: float = lean if lean != AS_DRAWN else (1.0 if _is_attached else 0.0)
	var turned: float = maxf(turn, lying)
	_card.position = (size - _card.size) / 2.0
	_card.rotation_degrees = 90.0 * turned
	_shade.visible = turn > 0.0
	_shade.color.a = TAPPED_SHADE * turn
	var symbol: float = turn * (1.0 - lying)
	_tap_symbol.visible = symbol > 0.0
	_tap_symbol.modulate.a = 0.5 * symbol
	_tap_symbol.rotation_degrees = -90.0 * turned
	if _attached_mark != null:
		_attached_mark.modulate.a = lying


## How far the card is turned toward sideways, from 0 to 1.
func turn() -> float:
	return _turn


func is_darkened() -> bool:
	return _shade.visible


## How dark the card is drawn: none upright, TAPPED_SHADE sideways.
func shade_alpha() -> float:
	return _shade.color.a if _shade.visible else 0.0


## The upright tap symbol over a tapped face's art, or null when untapped.
func tap_symbol() -> TextureRect:
	return _tap_symbol if _tap_symbol.visible else null


## The chip that says how many counters are on this permanent, or null for none.
func counter_chip() -> CounterChip:
	return _counter_chip


## The chip that says how much damage is marked on this creature, or null for none.
func damage_chip() -> DamageChip:
	return _damage_chip


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
	shape.add_child(CardShapes.image(power_toughness_texture(spec), box))
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


## The shade that darkens a tapped card and the tap symbol over its art, at half opacity
## when fully tapped. show_turn() says how much of each is seen.
func _add_tap_marks(shape: Panel, face_size: Vector2, art: Rect2) -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, TAPPED_SHADE)
	_shade.size = face_size
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.add_child(_shade)
	var side: float = minf(art.size.x, art.size.y) * 0.92
	_tap_symbol = CardShapes.image(ManaSymbols.texture("t"), Rect2(art.get_center() - Vector2(side, side) / 2.0, Vector2(side, side)))
	_tap_symbol.pivot_offset = Vector2(side, side) / 2.0
	shape.add_child(_tap_symbol)


## How much the baked border is scaled to make a face [param height] pixels tall.
static func _scale(height: float) -> float:
	return height / FrameBaker.field_border_height()
