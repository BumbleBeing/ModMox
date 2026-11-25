extends Control
## PROTOTYPE (card track, looking at the top cards): throwaway. How the Hero answers Militia
## Bugler's "When this creature enters, look at the top four cards of your library. You may
## reveal a creature card with power 2 or less from among them and put it into your hand.
## Put the rest on the bottom of your library in a random order." (CR 701.20e), on a mock
## board with no engine, built from the real UI pieces and the surveil prototype's board.
## Militia Bugler has just entered and its trigger is resolving; the top four cards of the
## Hero's library are Plains, Savannah Lions (2/1), Serra Angel (4/4) and White Knight
## (2/2), so the Lions and the Knight may be taken. Militia Bugler is not in Content yet,
## so its look is made here by hand, with no art. Nothing here is ported as it is; what the
## user signs off on is rebuilt test-first in ui/encounter/.
##
## A. Look window (after the Surveil window, game ADR 0069): a window titled "Look at 4"
##    holds the four cards face up in a row, left to right from the top of the library, with
##    no dragging, since the rest go to the bottom in a random order. The cards that may be
##    taken glow green; a click selects one, with a white Glow, and a second lets it go.
##    "Hand" is baked into the window's bottom edge: a strip along the bottom, as the title
##    bar runs along the top, exactly as tall as the button, with Hand centered in it, so it
##    stays at the middle of the bottom however the window is resized. It flies the selected
##    card out of the window into the hand with a Card Flight; then no other may be taken. "Done" on the Pass Button flies the rest,
##    turning face down, onto the Library pile, and the window closes.
## B. Library window (after a search's, game ADR 0058): the Library window holds only the
##    top four cards, face up in a row. The cards that may be taken glow green; a click
##    selects one, white, and a second lets it go. Nothing moves until the Pass Button,
##    which reads "Take nothing" or "Take Savannah Lions", SPACE under it: the card taken
##    flies into the hand and the rest onto the Library pile, and the window closes.
## Both ask in the Info Panel: "Militia Bugler: you may put a creature card with power 2 or less into
## your hand. The rest go to the bottom."
## Once answered, the board shows the result (the card in the hand, the library one card
## shorter) until R resets.
##
## Run: godot --path . res://prototypes/militia_bugler/militia_bugler.tscn
## Keys: [ ] switch variant, R resets, Space presses the Pass Button.
## For a picture: add -- --variant=A|B [--pick=N] [--hand] [--answer] [--fly] [--wide]
##   --shot=/absolute/path.png
##   (--pick selects the Nth card of the row; in A, --hand then sends it to the hand;
##   --answer presses the Pass Button; --fly holds the cards half-way through their flight;
##   --wide opens the window 360 pixels wider and 80 taller, as if resized by hand.)

const VARIANTS: Array[String] = ["A", "B"]
const VARIANT_NAMES: Dictionary[String, String] = {
	"A": "Look window",
	"B": "Library window",
}
const SCREEN: Vector2 = Vector2(1920, 1080)
const PLAY: Color = Color("#7be36a")
const PICKED: Color = Color.WHITE
const PLAIN: Color = Color("#8a93a6")
const TRIGGER_COLOR: Color = Color("#e0c46a")
const CARDS: String = "res://content/cards/"
const PLAINS: String = CARDS + "alpha/plains.tres"
const HERO_CREATURES: Array[String] = [CARDS + "alpha/samite_healer.tres"]
const VILLAIN_CREATURES: Array[String] = [CARDS + "darksteel/leonin_shikari.tres", CARDS + "phyrexia_all_will_be_one/kemba_kha_enduring.tres"]
const HAND: Array[String] = [CARDS + "alpha/pearled_unicorn.tres"]
## The Hero's graveyard, oldest first.
const GRAVEYARD: Array[String] = [CARDS + "alpha/savannah_lions.tres"]
## Five Plains, three tapped for Militia Bugler.
const LAND_COUNT: int = 5
const TAPPED_FOR_CAST: int = 3
const LIBRARY_COUNT: int = 31
## The top four cards of the Hero's library, top first, and whether each may be taken: a
## creature card with power 2 or less.
const LOOKED_AT: Array[String] = [PLAINS, CARDS + "alpha/savannah_lions.tres", CARDS + "alpha/serra_angel.tres",
	CARDS + "alpha/white_knight.tres"]
const MAY_TAKE: Array[bool] = [false, true, false, true]
## A unit of space: four pixels at 1080p.
const UNIT: float = 4.0
const HAND_BUTTON: Vector2 = Vector2(50.0 * UNIT, InfoPanel.ROW_HEIGHT)
## A: the space between the scrolled cards and the Hand strip.
const STRIP_GAP: float = 2.0 * UNIT
const PROMPT: String = "Militia Bugler: you may put a creature card with power 2 or less into your hand. The rest go to the bottom."

var _variant: String = "A"
## "" while asked, then "done".
var _outcome: String = ""
## The cards still in the window, as indexes into LOOKED_AT in the order shown; the card
## selected, or -1; the card taken into the hand, or -1; and the cards on the bottom.
var _row: Array[int] = [0, 1, 2, 3]
var _picked: int = -1
var _taken: int = -1
var _bottomed: Array[int] = []
## Whether the answer has been given and the rest are on their way to the bottom, and the
## Pass Button's words as it was pressed.
var _is_answering: bool = false
var _given_words: String = ""
var _pass_button: PassButton
## The cards in the air, timed by the encounter's own CardFlights and drawn as its Flight
## Cards on a layer over everything, each going to "hand" or "library"; and whether the
## clock is held, for a picture.
var _flights: CardFlights = CardFlights.new()
var _flight_cards: Dictionary[int, FlightCard] = {}
var _destinations: Dictionary[int, String] = {}
var _flight_host: Control
var _is_held_in_air: bool = false
## The window, and where it was and how big when last drawn, kept through the redraw a
## click or a landing makes, so a window moved or resized by hand stays so.
var _window: ZoneWindow
var _window_rect: Rect2 = Rect2()
## The row's faces by card.
var _row_faces: Dictionary[int, CardFace] = {}

var _regions: Dictionary[String, Rect2] = {}
var _layer: Control


func _ready() -> void:
	_flights.seconds = Pacing.FLIGHT_SECONDS
	_flight_host = Control.new()
	_flight_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flight_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flight_host)
	_regions = EncounterLayout.regions(SCREEN)
	var shot: String = ""
	var to_hand: bool = false
	var answer: bool = false
	var fly: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			shot = argument.trim_prefix("--shot=")
		elif argument.begins_with("--variant="):
			_variant = argument.trim_prefix("--variant=")
		elif argument.begins_with("--pick="):
			_picked = _row[int(argument.trim_prefix("--pick="))]
		elif argument == "--hand":
			to_hand = true
		elif argument == "--answer":
			answer = true
		elif argument == "--fly":
			fly = true
		elif argument == "--wide":
			_window_rect = Rect2(Vector2.ZERO, Vector2(-1, -1))
	if shot != "":
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_rebuild()
	if to_hand or answer:
		# The row's faces are placed by their window a frame after it is built.
		await get_tree().process_frame
		await get_tree().process_frame
		if to_hand and _variant == "A":
			_send_to_hand()
			if not fly or answer:
				_land_everything()
		if answer:
			_pass_button.pressed.emit()
		if fly:
			# A frame is never counted as longer than CardFlights.LONGEST_FRAME.
			for step: int in 9:
				_flights.advance(_flights.seconds * 0.05)
			_is_held_in_air = true
		else:
			_land_everything()
	if shot != "":
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var step: int = -1 if key.keycode == KEY_BRACKETLEFT else 1
			_variant = VARIANTS[(VARIANTS.find(_variant) + step + VARIANTS.size()) % VARIANTS.size()]
			_reset()
		KEY_R:
			_reset()
		KEY_SPACE:
			if _pass_button != null and not _pass_button.disabled:
				_pass_button.pressed.emit()


func _reset() -> void:
	_outcome = ""
	_row = [0, 1, 2, 3]
	_picked = -1
	_taken = -1
	_bottomed.clear()
	_is_answering = false
	_window_rect = Rect2()
	_window = null
	_flights.clear()
	for card: FlightCard in _flight_cards.values():
		card.queue_free()
	_flight_cards.clear()
	_destinations.clear()
	_is_held_in_air = false
	_rebuild()


func _is_asking() -> bool:
	return _outcome == ""


## Whether [param index] may be selected now: a card that may be taken, while none has been.
func _may_pick(index: int) -> bool:
	return MAY_TAKE[index] and _taken < 0 and not _is_answering


func _rebuild() -> void:
	if _window != null and is_instance_valid(_window):
		_window_rect = Rect2(_window.position, _window.size)
	_window = null
	if _layer != null:
		_layer.queue_free()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	# Cards in the air are drawn over every window.
	move_child(_flight_host, -1)
	_row_faces.clear()
	_build_board()
	_build_panels()
	_build_piles()
	_build_hand()
	if _is_asking():
		_build_stack()
	_build_info()
	if _is_asking() and not _row.is_empty():
		_build_window()
	_build_switcher()


# The board ------------------------------------------------------------------------------

func _build_board() -> void:
	var back: ColorRect = ColorRect.new()
	back.color = Color("#161a21")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(back)
	for row: String in ["villain_lands", "villain_nonlands", "hero_nonlands", "hero_lands"]:
		_panel(_regions[row], Color("#1c212a"), Color("#2a303b"))
	var villain_lands: Array[String] = []
	villain_lands.resize(5)
	villain_lands.fill(PLAINS)
	_place_row(_looks(villain_lands), _regions["villain_lands"])
	_place_row(_looks(VILLAIN_CREATURES), _regions["villain_nonlands"])
	var creatures: Array[CardLook] = _looks(HERO_CREATURES)
	creatures.append(_militia_bugler())
	var faces: Array[BattlefieldFace] = _place_row(creatures, _regions["hero_nonlands"])
	if _is_asking():
		# The trigger's source carries its Stack Mark while it resolves.
		BorderEffects.add_mark(faces[-1], faces[-1].size, TRIGGER_COLOR, true)
	var lands: Array[String] = []
	lands.resize(LAND_COUNT)
	lands.fill(PLAINS)
	var land_faces: Array[BattlefieldFace] = _place_row(_looks(lands), _regions["hero_lands"])
	for index: int in TAPPED_FOR_CAST:
		land_faces[index].show_turn(1.0)


func _place_row(looks: Array[CardLook], row: Rect2) -> Array[BattlefieldFace]:
	var placed: Array[BattlefieldFace] = []
	var height: float = row.size.y - 24.0
	var face_size: Vector2 = BattlefieldFace.size_for(height)
	var total: float = looks.size() * face_size.x + (looks.size() - 1) * 16.0
	var x: float = row.position.x + (row.size.x - total) / 2.0
	for look: CardLook in looks:
		var face: BattlefieldFace = BattlefieldFace.new()
		face.setup(look, height)
		face.position = Vector2(x, row.position.y + (row.size.y - face_size.y) / 2.0)
		_layer.add_child(face)
		placed.append(face)
		x += face_size.x + 16.0
	return placed


func _build_panels() -> void:
	for side: String in ["villain", "hero"]:
		var box: Rect2 = _regions[side + "_panel"]
		var panel: Panel = _panel(box)
		var parts: Dictionary[String, Rect2] = EncounterLayout.panel(box)
		panel.add_child(_label("Kemba, Kha Enduring" if side == "villain" else "Jackson", 22, Color.WHITE,
			parts["name"].position - box.position + Vector2(20, 0)))
		var portrait: Panel = _panel(parts["portrait"], Color("#2b3140"))
		portrait.add_child(_label("(portrait)", 16, Color(1, 1, 1, 0.3), Vector2(40, 80)))
		_layer.add_child(_label("20", 34, Color.WHITE, parts["life"].position))


func _build_piles() -> void:
	for pile: String in ["villain_exile", "villain_graveyard", "villain_library", "hero_library", "hero_graveyard", "hero_exile"]:
		var rect: Rect2 = _regions[pile]
		_panel(EncounterLayout.zone_plates(_regions)[pile], Color("#1c212a"), Color("#2a303b"))
		var card: Rect2 = _pile_card(pile)
		var count: int = 0
		if pile == "hero_library":
			count = _library_count()
			_add_back(card)
		elif pile == "villain_library":
			count = LIBRARY_COUNT
			_add_back(card)
		elif pile == "hero_graveyard":
			count = GRAVEYARD.size()
			var face: CardFace = CardFace.new()
			face.setup(_look(GRAVEYARD[-1]), card.size.y)
			face.show_graveyard_chips()
			face.position = card.position
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_layer.add_child(face)
		else:
			_panel(card, Color("#161a21"), Color("#2a303b"))
		var label: Label = _label("%s (%d)" % [pile.get_slice("_", 1).capitalize(), count], 15, Color(1, 1, 1, 0.55),
			Vector2(rect.position.x, card.end.y + 1))
		label.size.x = rect.size.x
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_layer.add_child(label)


## The Hero's library: one card shorter once a card is in the hand, or on its way there.
func _library_count() -> int:
	var gone: bool = _taken >= 0 or _destinations.values().has("hand")
	return LIBRARY_COUNT - (1 if gone else 0)


func _add_back(card: Rect2) -> Panel:
	var back: Panel = CardBack.make(card.size.y)
	back.position = card.position
	_layer.add_child(back)
	return back


func _pile_card(pile: String) -> Rect2:
	var rect: Rect2 = _regions[pile]
	var width: float = EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT
	return Rect2(rect.get_center().x - width / 2.0, rect.position.y, width, EncounterLayout.PILE_HEIGHT)


## The Hero's hand: its cards, and the card taken once it has landed there.
func _build_hand() -> void:
	var files: Array[String] = HAND.duplicate()
	if _taken >= 0:
		files.append(LOOKED_AT[_taken])
	for index: int in files.size():
		var face: CardFace = CardFace.new()
		face.setup(_look(files[index]), EncounterLayout.HAND_CARD_HEIGHT)
		face.position = _hand_slot(index, files.size())
		_layer.add_child(face)


## Where card [param index] of a hand of [param count] cards is drawn.
func _hand_slot(index: int, count: int) -> Vector2:
	var hand: Rect2 = _regions["hero_hand"]
	var height: float = EncounterLayout.HAND_CARD_HEIGHT
	var width: float = height * CardGeometry.ASPECT
	var x: float = hand.get_center().x - (count * width + (count - 1) * 10.0) / 2.0
	return Vector2(x + index * (width + 10.0), SCREEN.y - height * 0.42)


## The Stack Window while the trigger resolves, its entry as StackItem words a triggered
## ability: its effect, then its controller.
func _build_stack() -> void:
	var window: ZoneWindow = ZoneWindow.new("Stack", false, PLAIN)
	window.size = Vector2(460, 140)
	window.position = Vector2(_regions["battlefield"].end.x - 480.0, 110)
	_layer.add_child(window)
	window.show_title("Stack (1)")
	window.open()
	window.body().add_child(StackEntry.new("", "Look at the top four cards of your library.", "Jackson", TRIGGER_COLOR, true))


# The question -----------------------------------------------------------------------------

## The Info Panel as game ADR 0066 draws it: Dither Shaded, its prompt centered at the top;
## dim while nothing is asked. The Pass Button reads Done (A), or what it takes (B).
func _build_info() -> void:
	var box: Rect2 = _regions["info"]
	var info: Control = Control.new()
	info.position = box.position
	info.size = box.size
	_layer.add_child(info)
	var back: Panel = Panel.new()
	back.size = box.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.add_theme_stylebox_override("panel", DitherShading.plate(InfoPanel.FILL.lightened(0.06), InfoPanel.FILL.darkened(0.3),
		InfoPanel.BORDER, 8, 2, 0, maxi(1, int(box.size.y))))
	back.modulate.a = 1.0 if _is_asking() else InfoPanel.DIM
	info.add_child(back)
	_pass_button = PassButton.new()
	_pass_button.place(_regions["pass"])
	_layer.add_child(_pass_button)
	if not _is_asking():
		_pass_button.show_pass(true)
		return
	var prompt: SymbolLabel = SymbolLabel.new()
	prompt.set_font_size(InfoPanel.PROMPT_FONT + UiText.RAISE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(InfoPanel.INSET, InfoPanel.TOP)
	prompt.size = Vector2(box.size.x - InfoPanel.INSET * 2.0, 0)
	info.add_child(prompt)
	_write_fitted(prompt, PROMPT)
	if _is_answering:
		_pass_button.show_confirm(_given_words, false, true)
		return
	if _variant == "A":
		_pass_button.show_confirm("Done", true, true)
	else:
		_pass_button.show_confirm(_take_words(), true, true)
	_pass_button.pressed.connect(_answer)


## B: "Take nothing", or "Take Savannah Lions" with a card selected.
func _take_words() -> String:
	return "Take nothing" if _picked < 0 else "Take " + _look(LOOKED_AT[_picked]).name


## The window, placed and sized as the Library window is (game ADR 0055): left of the piles,
## over the Hero's side, the cards at the Library window's height, four wide. A: "Look at 4",
## with Hand under the row. B: the Library window's title, holding only the four.
func _build_window() -> void:
	var card: Vector2 = _row_card()
	var room: float = PileWindow.GLOW_ROOM
	var width: float = 4.0 * card.x + 3.0 * PileWindow.GAP + room * 2.0
	var height: float = room * 2.0 + card.y
	var window: ZoneWindow = ZoneWindow.new("Look" if _variant == "A" else "Library", _variant == "B", PLAIN)
	# The bar above and the margins round the scrolled body, as ZoneWindow lays them out; in A
	# the Hand strip along the bottom takes the place of the bottom margin.
	var below: float = STRIP_GAP + HAND_BUTTON.y + 2.0 if _variant == "A" else 14.0
	window.size = Vector2(width + 16.0 + 4.0, ZoneWindow.BAR_HEIGHT + 8.0 + height + below)
	var battlefield: Rect2 = _regions["battlefield"]
	if _window_rect.size == Vector2(-1, -1):
		window.size += Vector2(360, 80)  # --wide
	window.position = Vector2(_regions["piles"].position.x - window.size.x - 5.0 * UNIT, battlefield.end.y - window.size.y - 2.0 * UNIT)
	if _window_rect.has_area():
		window.position = _window_rect.position
		window.size = _window_rect.size
	_window = window
	_layer.add_child(window)
	window.show_title("Look at 4" if _variant == "A" else "Top 4 of Jackson's Library")
	window.open()
	var area: Control = Control.new()
	area.custom_minimum_size = Vector2(width, height)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.body().add_child(area)
	for place: int in _row.size():
		var index: int = _row[place]
		var face: CardFace = CardFace.new()
		face.setup(_look(LOOKED_AT[index]), card.y)
		face.position = Vector2(room + place * (card.x + PileWindow.GAP), room)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(face)
		if index == _picked:
			BorderEffects.add_glow(face, face.size, PICKED)
		elif _may_pick(index):
			BorderEffects.add_glow(face, face.size, PLAY)
		if _may_pick(index):
			ClickCatcher.add(face, face.size).clicked.connect(_toggle.bind(index))
		_row_faces[index] = face
	if _variant == "A":
		_bake_hand_strip(window, below)


## A: the Hand strip, baked into the window's bottom edge as the title bar is into its top:
## inside the border, as tall as Hand, in the title bar's color, its bottom corners rounded
## to the window's. Hand is anchored to the strip's middle, so it stays centered however
## the window is resized. The scrolled body ends above it, and the resize grip stays on top.
func _bake_hand_strip(window: ZoneWindow, below: float) -> void:
	var strip: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(PLAIN, 0.35)
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	strip.add_theme_stylebox_override("panel", style)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_left = 2
	strip.offset_right = -2
	strip.offset_bottom = -2
	strip.offset_top = -2 - HAND_BUTTON.y
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(strip)
	# Under the resize grip, ZoneWindow's last child.
	window.move_child(strip, window.get_child_count() - 2)
	window.scroll().offset_bottom = -below
	var hand: Button = Button.new()
	hand.text = "Hand"
	hand.focus_mode = Control.FOCUS_NONE
	hand.anchor_left = 0.5
	hand.anchor_right = 0.5
	hand.anchor_top = 0.0
	hand.anchor_bottom = 1.0
	hand.offset_left = -HAND_BUTTON.x / 2.0
	hand.offset_right = HAND_BUTTON.x / 2.0
	hand.offset_top = 0
	hand.offset_bottom = 0
	hand.add_theme_font_size_override("font_size", InfoPanel.BUTTON_FONT + UiText.RAISE)
	hand.disabled = _picked < 0
	hand.pressed.connect(_send_to_hand)
	strip.add_child(hand)
	SteelFrame.apply(hand, InfoPanel.BUTTON)


func _row_card() -> Vector2:
	return Vector2(PileWindow.CARD_HEIGHT * CardGeometry.ASPECT, PileWindow.CARD_HEIGHT)


## A click selects a card that may be taken, and a second lets it go.
func _toggle(index: int) -> void:
	if not _may_pick(index):
		return
	_picked = -1 if _picked == index else index
	_rebuild()


# Answers ----------------------------------------------------------------------------------

## A: Hand flies the selected card from the window into the hand.
func _send_to_hand() -> void:
	if _picked < 0 or not _row_faces.has(_picked):
		return
	_fly(_picked, "hand")
	_row.erase(_picked)
	_picked = -1
	_rebuild()


## The Pass Button. A: Done. B: takes the selected card, if any. Either way the rest fly
## face down onto the Library pile, and the answer is given once they land.
func _answer() -> void:
	_given_words = "Done" if _variant == "A" else _take_words()
	if _variant == "B" and _picked >= 0:
		_fly(_picked, "hand")
		_row.erase(_picked)
		_picked = -1
	_is_answering = true
	for index: int in _row.duplicate():
		_fly(index, "library")
	_row.clear()
	if _flight_cards.is_empty():
		_outcome = "done"
	_rebuild()


## Puts card [param index] in the air from where it is drawn in the window to the hand, face
## up, or to the Library pile, turning face down.
func _fly(index: int, destination: String) -> void:
	var face: CardFace = _row_faces[index]
	var from: FacePose = FacePose.of(face.get_global_rect().get_center(), face.size.y, 0.0)
	var to: FacePose
	var look: CardLook = _look(LOOKED_AT[index])
	var card: FlightCard
	if destination == "hand":
		var height: float = EncounterLayout.HAND_CARD_HEIGHT
		var slot: Vector2 = _hand_slot(HAND.size(), HAND.size() + 1)
		to = FacePose.of(slot + Vector2(height * CardGeometry.ASPECT, height) / 2.0, height, 0.0)
		card = FlightCard.new(FlightCard.Kind.CARD, look, FlightCard.Kind.CARD, look)
	else:
		var pile: Rect2 = _pile_card("hero_library")
		to = FacePose.of(pile.get_center(), pile.size.y, 0.0)
		card = FlightCard.new(FlightCard.Kind.CARD, look, FlightCard.Kind.BACK, look)
	_flight_host.add_child(card)
	_flight_cards[index] = card
	_destinations[index] = destination
	_flights.launch(index, from, to)
	card.show_pose(from, 0.0)


## For a picture: every card in the air lands at once.
func _land_everything() -> void:
	for step: int in 200:
		if _flight_cards.is_empty():
			return
		_flights.advance(CardFlights.LONGEST_FRAME)
		_process(0.0)


## Each card in the air flies on; one that has landed joins the hand or the library, and
## the answer is given once the last of the rest is on the bottom.
func _process(delta: float) -> void:
	if _flight_cards.is_empty():
		return
	if not _is_held_in_air:
		_flights.advance(delta)
	for index: int in _flight_cards.keys():
		var card: FlightCard = _flight_cards[index]
		card.show_pose(_flights.pose_of(index), _flights.along_of(index))
		if _flights.has_landed(index) and not _is_held_in_air:
			_flights.land(index)
			_flight_cards.erase(index)
			card.queue_free()
			if _destinations[index] == "hand":
				_taken = index
			else:
				_bottomed.append(index)
			_destinations.erase(index)
			if _is_answering and _flight_cards.is_empty():
				_outcome = "done"
			_rebuild()


## Writes [param words] centered at the panel's prompt size, or smaller where that would
## take more than two lines, as the Info Panel does.
func _write_fitted(prompt: SymbolLabel, words: String) -> void:
	var font: Font = get_theme_default_font()
	var size_now: int = InfoPanel.PROMPT_FONT
	var raised: int = size_now + UiText.RAISE
	var lines: float = font.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, prompt.size.x, raised).y / font.get_height(raised)
	if roundi(lines) > InfoPanel.PROMPT_LINES:
		size_now = InfoPanel.SMALL_PROMPT_FONT
	prompt.set_font_size(size_now + UiText.RAISE)
	prompt.write(words)


func _build_switcher() -> void:
	var bar: Panel = _panel(Rect2(_regions["hold"].position, Vector2(_regions["hold"].size.x, 64)), Color("#3a2a10"), Color("#f1dc9a"))
	bar.add_child(_label("PROTOTYPE [ %s ] %s\nR: reset" % [_variant, VARIANT_NAMES[_variant]], 14, Color("#f1dc9a"), Vector2(10, 6)))


# Helpers ----------------------------------------------------------------------------------

## Militia Bugler's look, made by hand: the card is not in Content yet. Its reminder text is
## left off the face, as for any card that is not a basic land.
func _militia_bugler() -> CardLook:
	var look: CardLook = CardLook.new()
	look.name = "Militia Bugler"
	look.colors = [MmCardTypes.CardColor.WHITE]
	look.card_types = [MmCardTypes.CardType.CREATURE]
	look.subtypes = ["Human", "Soldier"]
	var cost: MmManaCost = MmManaCost.new()
	cost.generic = 2
	cost.symbols = [MmMana.Type.WHITE]
	look.mana_cost = cost
	look.power = 2
	look.toughness = 3
	look.base_power = 2
	look.base_toughness = 3
	look.rules_text = "Vigilance\nWhen this creature enters, look at the top four cards of your library. You may reveal a creature card with power 2 or less from among them and put it into your hand. Put the rest on the bottom of your library in a random order."
	return look


func _look(file: String) -> CardLook:
	return CardLook.of_definition(load(file) as MmCardDefinition)


func _looks(files: Array[String]) -> Array[CardLook]:
	var looks: Array[CardLook] = []
	for file: String in files:
		looks.append(_look(file))
	return looks


func _panel(box: Rect2, fill: Color = Color("#20252e"), border: Color = Color("#3a414d")) -> Panel:
	var panel: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = box.position
	panel.size = box.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(panel)
	return panel


func _label(text: String, font_size: int, color: Color, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
