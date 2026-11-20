extends Control
## PROTOTYPE (card track, choosing X): throwaway. How the Hero chooses X for Taj-Nar
## Swordsmith's "When this creature enters, you may pay {X}. If you do, search your library
## for an Equipment card with mana value X or less, put it onto the battlefield, then
## shuffle." (engine ADR 0061), on a mock board with no engine, built from the real UI
## pieces. The trigger is resolving; the Hero has four untapped Plains, so X runs 0 to 4, and
## the Equipment left in their library are Short Sword and Darksteel Axe (mana value 1) and
## Lion Sash (2). Nothing here is ported as it is; what the user signs off on is rebuilt
## test-first in ui/encounter/.
##
## A. Stepper: the Info Panel asks "pay {X}?" with a − X + stepper, starting at the largest
##    X worth paying; the Pass Button pays, No declines. The lands that would be tapped glow.
## B. Pip row: a button for each X from {0} to {4} in the Info Panel; one click pays. The Xs
##    that find nothing a smaller X does not are dimmed; pointing at one says what it finds.
## C. Tap to count: X is the mana the Hero taps. Untapped lands glow; each click taps one
##    and raises X; the Pass Button pays what was tapped.
## D. Pick the card: the Library window opens on the Equipment X could find, each marked
##    with its mana value; clicking one sets X to it, and the search that follows takes it.
##
## Run: godot --path . res://prototypes/choose_x/choose_x.tscn
## Keys: ← → switch variant, R resets. No key pays, as with ward (game ADR 0060's addendum).
## For a picture: add -- --variant=A [--x=2] [--point=3] [--tapped=2] [--pick=2] [--paid]
##   --shot=/absolute/path.png

const VARIANTS: Array[String] = ["A", "B", "C", "D"]
const VARIANT_NAMES: Dictionary[String, String] = {
	"A": "Stepper",
	"B": "Pip row",
	"C": "Tap to count",
	"D": "Pick the card",
}
const SCREEN: Vector2 = Vector2(1920, 1080)
const PLAY: Color = Color("#7be36a")
const PICKED: Color = Color.WHITE
const PLAIN: Color = Color("#8a93a6")
const WOULD_TAP: Color = Color("#f1dc9a")
const MUTED: Color = Color(1, 1, 1, 0.65)
const TRIGGER_COLOR: Color = Color("#e0c46a")
const CARDS: String = "res://content/cards/"
const TAJ_NAR: String = CARDS + "mirrodin/taj_nar_swordsmith.tres"
const PLAINS: String = CARDS + "alpha/plains.tres"
const HERO_CREATURES: Array[String] = [CARDS + "alpha/savannah_lions.tres", TAJ_NAR]
const VILLAIN_CREATURES: Array[String] = [CARDS + "darksteel/leonin_shikari.tres", CARDS + "phyrexia_all_will_be_one/kemba_kha_enduring.tres"]
const HAND: Array[String] = [CARDS + "alpha/serra_angel.tres", CARDS + "alpha/white_knight.tres"]
## Six Plains, the first two tapped for Taj-Nar Swordsmith.
const LAND_COUNT: int = 6
const TAPPED_FOR_CAST: int = 2
const MOST: int = LAND_COUNT - TAPPED_FOR_CAST
## The Equipment in the Hero's library, by mana value.
const EQUIPMENT: Array[Dictionary] = [
	{"file": CARDS + "dominaria/short_sword.tres", "mv": 1},
	{"file": CARDS + "scars_of_mirrodin/darksteel_axe.tres", "mv": 1},
	{"file": CARDS + "kamigawa_neon_dynasty/lion_sash.tres", "mv": 2},
]
const LIBRARY_COUNT: int = 31

var _variant: String = "A"
var _x: int = -1
## B: the X the cursor is on, or -1.
var _pointed: int = -1
## C: how many of the untapped lands the Hero has tapped for X.
var _tapped: int = 0
## D: the Equipment clicked, or -1.
var _pick: int = -1
## "" while asked, then "paid" or "declined".
var _outcome: String = ""

var _regions: Dictionary[String, Rect2] = {}
var _layer: Control
var _land_faces: Array[BattlefieldFace] = []
var _hint: SymbolLabel


func _ready() -> void:
	_regions = EncounterLayout.regions(SCREEN)
	var shot: String = ""
	var paid: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			shot = argument.trim_prefix("--shot=")
		elif argument.begins_with("--variant="):
			_variant = argument.trim_prefix("--variant=")
		elif argument.begins_with("--x="):
			_x = int(argument.trim_prefix("--x="))
		elif argument.begins_with("--point="):
			_pointed = int(argument.trim_prefix("--point="))
		elif argument.begins_with("--tapped="):
			_tapped = int(argument.trim_prefix("--tapped="))
		elif argument.begins_with("--pick="):
			_pick = int(argument.trim_prefix("--pick="))
		elif argument == "--paid":
			paid = true
	if shot != "":
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if _x < 0:
		_x = _worth_most()
	if paid:
		_outcome = "paid"
	_rebuild()
	if shot != "":
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_LEFT, KEY_RIGHT:
			var step: int = -1 if key.keycode == KEY_LEFT else 1
			_variant = VARIANTS[(VARIANTS.find(_variant) + step + VARIANTS.size()) % VARIANTS.size()]
			_reset()
		KEY_R:
			_reset()


func _reset() -> void:
	_x = _worth_most()
	_pointed = -1
	_tapped = 0
	_pick = -1
	_outcome = ""
	_rebuild()


## The largest X that finds something no smaller X does: what the AI's CHEAP Agent pays.
func _worth_most() -> int:
	var most: int = 0
	for entry: Dictionary in EQUIPMENT:
		most = maxi(most, entry["mv"])
	return mini(most, MOST)


## The X this variant would pay now.
func _x_now() -> int:
	match _variant:
		"C":
			return _tapped
		"D":
			return EQUIPMENT[_pick]["mv"] if _pick >= 0 else -1
	return _x


## What X finds, in words: "Short Sword, Darksteel Axe or Lion Sash".
func _finds(x: int) -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in EQUIPMENT:
		if entry["mv"] <= x:
			names.append(_look(entry["file"]).name)
	return names


func _or_list(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " or " + names[-1]


func _rebuild() -> void:
	if _layer != null:
		_layer.queue_free()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	_build_board()
	_build_panels()
	_build_piles()
	_build_hand()
	_build_stack()
	_build_info()
	if _variant == "D" and _outcome == "":
		_build_library_window()
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
	_place_row(villain_lands, _regions["villain_lands"])
	_place_row(VILLAIN_CREATURES, _regions["villain_nonlands"])
	var creatures: Array[BattlefieldFace] = _place_row(HERO_CREATURES, _regions["hero_nonlands"])
	# The trigger's source carries its Stack Mark while it resolves.
	BorderEffects.add_mark(creatures[1], creatures[1].size, TRIGGER_COLOR, true)
	var lands: Array[String] = []
	lands.resize(LAND_COUNT)
	lands.fill(PLAINS)
	_land_faces = _place_row(lands, _regions["hero_lands"])
	var paying: int = _x_now() if _outcome == "paid" else 0
	for index: int in _land_faces.size():
		var face: BattlefieldFace = _land_faces[index]
		var untapped: int = index - TAPPED_FOR_CAST
		var is_tapped: bool = untapped < 0 or (_variant == "C" and untapped < _tapped) or untapped < paying
		face.show_turn(1.0 if is_tapped else 0.0)
		if _outcome != "" or untapped < 0:
			continue
		if _variant == "C":
			BorderEffects.add_glow(face, face.size, PICKED if is_tapped else PLAY)
			ClickCatcher.add(face, face.size).clicked.connect(_tap.bind(untapped))
		else:
			# What Auto-tap would tap for the X shown (game ADR 0031).
			var shown: int = _pointed if _variant == "B" and _pointed >= 0 else _x_now()
			if untapped < shown:
				BorderEffects.add_glow(face, face.size, WOULD_TAP)


func _place_row(files: Array[String], row: Rect2) -> Array[BattlefieldFace]:
	var placed: Array[BattlefieldFace] = []
	var height: float = row.size.y - 24.0
	var face_size: Vector2 = BattlefieldFace.size_for(height)
	var total: float = files.size() * face_size.x + (files.size() - 1) * 16.0
	var x: float = row.position.x + (row.size.x - total) / 2.0
	for file: String in files:
		var face: BattlefieldFace = BattlefieldFace.new()
		face.setup(_look(file), height)
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
		if pile.ends_with("library"):
			count = LIBRARY_COUNT
			var back: Panel = CardBack.make(card.size.y)
			back.position = card.position
			_layer.add_child(back)
		else:
			_panel(card, Color("#161a21"), Color("#2a303b"))
		var label: Label = _label("%s (%d)" % [pile.get_slice("_", 1).capitalize(), count], 15, Color(1, 1, 1, 0.55),
			Vector2(rect.position.x, card.end.y + 1))
		label.size.x = rect.size.x
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_layer.add_child(label)


func _pile_card(pile: String) -> Rect2:
	var rect: Rect2 = _regions[pile]
	var width: float = EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT
	return Rect2(rect.get_center().x - width / 2.0, rect.position.y, width, EncounterLayout.PILE_HEIGHT)


func _build_hand() -> void:
	var hand: Rect2 = _regions["hero_hand"]
	var height: float = EncounterLayout.HAND_CARD_HEIGHT
	var width: float = height * CardGeometry.ASPECT
	var x: float = hand.get_center().x - (HAND.size() * width + (HAND.size() - 1) * 10.0) / 2.0
	for file: String in HAND:
		var face: CardFace = CardFace.new()
		face.setup(_look(file), height)
		face.position = Vector2(x, SCREEN.y - height * 0.42)
		_layer.add_child(face)
		x += width + 10.0


func _build_stack() -> void:
	var window: ZoneWindow = ZoneWindow.new("Stack", false, PLAIN)
	window.size = Vector2(460, 140)
	window.position = Vector2(_regions["battlefield"].end.x - 480.0, 110)
	_layer.add_child(window)
	window.show_title("Stack (1)")
	window.open()
	var detail: String = "Paid %d: searching" % _x_now() if _outcome == "paid" else "You may pay X"
	window.body().add_child(StackEntry.new("taj_nar_swordsmith", "Taj-Nar Swordsmith's ability", detail, TRIGGER_COLOR, true))


# The question -----------------------------------------------------------------------------

func _build_info() -> void:
	var box: Rect2 = _regions["info"]
	var info: Control = Control.new()
	info.position = box.position
	info.size = box.size
	_layer.add_child(info)
	info.add_child(CardShapes.rounded(box.size, 8, Color("#2c323c")))
	info.add_child(CardShapes.outline(box.size, 8, 2, InfoPanel.BORDER))
	var inside: float = box.size.x - 24.0
	var prompt: SymbolLabel = SymbolLabel.new()
	prompt.set_font_size(18)
	prompt.position = Vector2(12, 8)
	prompt.size = Vector2(inside, 26)
	info.add_child(prompt)
	_hint = SymbolLabel.new()
	_hint.set_font_size(13)
	_hint.modulate = MUTED
	_hint.position = Vector2(12, 36)
	_hint.size = Vector2(inside, 34)
	info.add_child(_hint)
	var pass_button: PassButton = PassButton.new()
	pass_button.place(_regions["pass"])
	_layer.add_child(pass_button)
	if _outcome == "paid":
		prompt.write("Search your library for an Equipment card with mana value %d or less." % _x_now())
		pass_button.show_confirm("Search", false, false)
		return
	if _outcome == "declined":
		prompt.write("You didn't pay. Taj-Nar Swordsmith's ability does nothing.")
		pass_button.show_pass(true)
		return
	var no: Button = Button.new()
	no.text = InfoPanel.NO
	no.focus_mode = Control.FOCUS_NONE
	var no_width: float = {"A": 104.0, "B": 84.0}.get(_variant, InfoPanel.BUTTON_ROOM - 12)
	no.position = Vector2(box.size.x - 12 - no_width, box.size.y - 40)
	no.size = Vector2(no_width, 32)
	no.add_theme_font_size_override("font_size", 18)
	no.pressed.connect(_decline)
	info.add_child(no)
	match _variant:
		"A":
			prompt.write("Pay {X} for Taj-Nar Swordsmith?")
			var stepper: DamageStepper = DamageStepper.new(Rect2(12, box.size.y - 44, 160, 38), _x, false, _x > 0, _x < MOST)
			stepper.lowered.connect(_step.bind(-1))
			stepper.raised.connect(_step.bind(1))
			info.add_child(stepper)
			_pay_button(pass_button, _x)
		"B":
			prompt.write("Pay {X} for Taj-Nar Swordsmith?")
			_write_finds(_pointed)
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.position = Vector2(12, box.size.y - 42)
			info.add_child(row)
			for x: int in MOST + 1:
				row.add_child(_pip_button(x))
			pass_button.show_confirm("Choose X", false, false)
		"C":
			prompt.write("Pay {X} for Taj-Nar Swordsmith?")
			_hint.write("Click a land to tap it for X. " + _finds_words(_tapped))
			_pay_button(pass_button, _tapped)
		"D":
			prompt.write("Choose an Equipment to find.")
			if _pick >= 0:
				_write_finds(_x_now())
				_pay_button(pass_button, _x_now())
			else:
				_hint.write("X is the mana value of the card you choose.")
				pass_button.show_confirm("Pay", false, false)


func _write_finds(x: int) -> void:
	if x < 0:
		_hint.write("Point at an X to see what it can find.")
		return
	_hint.write(_finds_words(x))


func _finds_words(x: int) -> String:
	var found: Array[String] = _finds(x)
	if found.is_empty():
		return "{%d} finds no Equipment in your library." % x
	return "{%d} can find %s." % [x, _or_list(found)]


## The Pass Button reads "Pay {2}", its pip drawn over it, and no key presses it.
func _pay_button(pass_button: PassButton, x: int) -> void:
	pass_button.show_confirm(" ", true, false)
	pass_button.pressed.connect(_pay)
	var words: SymbolLabel = SymbolLabel.new()
	words.set_font_size(PassButton.CONFIRM_FONT)
	words.write("Pay {%d}" % x)
	words.size = Vector2(pass_button.size.x, 30)
	words.position = Vector2(0, (pass_button.size.y - 26) / 2.0)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pass_button.add_child(words)


## B: one pip button. An X that finds nothing a smaller X does not is dimmed, as the AI
## would never pay it.
func _pip_button(x: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(34, 34)
	button.focus_mode = Control.FOCUS_NONE
	var pip: TextureRect = CardShapes.image(ManaSymbols.texture(ManaSymbols.image_for(str(x))), Rect2(4, 4, 26, 26))
	button.add_child(pip)
	var is_worth: bool = x == 0 and not _finds(0).is_empty() or x > 0 and _finds(x).size() > _finds(x - 1).size()
	if not is_worth:
		button.modulate = Color(1, 1, 1, 0.45)
	if x == _pointed:
		BorderEffects.add_glow(button, button.custom_minimum_size, PLAY)
	button.mouse_entered.connect(func() -> void:
		_pointed = x
		_rebuild())
	button.pressed.connect(func() -> void:
		_x = x
		_pay())
	return button


## D: the Library window, opened on the Equipment X could find, each with its mana value.
func _build_library_window() -> void:
	var window: ZoneWindow = ZoneWindow.new("Library", true, PLAIN)
	var height: float = PileWindow.CARD_HEIGHT
	var width: float = height * CardGeometry.ASPECT
	window.size = Vector2(3.0 * (width + 8.0) + 56.0, height + 110.0)
	window.position = Vector2(_regions["piles"].position.x - window.size.x - 20.0, _regions["hero_library"].position.y - window.size.y + 120.0)
	_layer.add_child(window)
	window.show_title("Equipment in your library (%d)" % EQUIPMENT.size())
	window.open()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var room: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		room.add_theme_constant_override(side, PileWindow.GLOW_ROOM)
	room.add_child(row)
	window.body().add_child(room)
	for index: int in EQUIPMENT.size():
		var holder: Control = Control.new()
		holder.custom_minimum_size = Vector2(width, height)
		row.add_child(holder)
		var face: CardFace = CardFace.new()
		face.setup(_look(EQUIPMENT[index]["file"]), height)
		holder.add_child(face)
		BorderEffects.add_glow(face, face.size, PICKED if index == _pick else PLAY)
		ClickCatcher.add(face, face.size).clicked.connect(func() -> void:
			_pick = index
			_rebuild())
		var tag: Panel = CardShapes.rounded(Vector2(64, 30), 6, Color(0, 0, 0, 0.82))
		tag.position = Vector2(6, height * 0.42)
		face.add_child(tag)
		var words: SymbolLabel = SymbolLabel.new()
		words.set_font_size(16)
		words.write("X {%d}" % EQUIPMENT[index]["mv"])
		words.position = Vector2(6, 3)
		words.size = Vector2(56, 24)
		tag.add_child(words)


# Answers ----------------------------------------------------------------------------------

func _step(by: int) -> void:
	_x = clampi(_x + by, 0, MOST)
	_rebuild()


func _tap(untapped: int) -> void:
	# The lands are tapped left to right, whichever is clicked, as Plains are all alike.
	_tapped = _tapped - 1 if untapped < _tapped else _tapped + 1
	_rebuild()


func _pay() -> void:
	_outcome = "paid"
	_rebuild()


func _decline() -> void:
	_outcome = "declined"
	_rebuild()


func _build_switcher() -> void:
	var bar: Panel = _panel(Rect2(_regions["hold"].position, Vector2(_regions["hold"].size.x, 64)), Color("#3a2a10"), Color("#f1dc9a"))
	bar.add_child(_label("PROTOTYPE ◀ %s ▶ %s\nR: reset" % [_variant, VARIANT_NAMES[_variant]], 14, Color("#f1dc9a"), Vector2(10, 6)))


# Helpers ----------------------------------------------------------------------------------

func _look(file: String) -> CardLook:
	return CardLook.of_definition(load(file) as MmCardDefinition)


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
