extends Control
## PROTOTYPE (card track, choosing a color): throwaway. How the Hero chooses the color of
## "Add one mana of any color", the mana ability of the Treasure Jewel Thief makes: "{T},
## Sacrifice this token: Add one mana of any color." On a mock board with no engine, built
## from the real UI pieces. It is the Hero's first main phase. They control three untapped
## Forests, Llanowar Elves, Grizzly Bears and a Treasure, and hold Savannah Lions, Lightning
## Bolt, Giant Growth and Serra Angel. Nothing here is ported as it is; what the user signs
## off on is rebuilt test-first in ui/encounter/.
##
## Two situations, switched with P:
## - At priority: the Hero clicks the Treasure with nothing to pay, and the mana goes to
##   their pool. No color glows, since every one can be chosen (as in game ADR 0053).
## - Paying for Savannah Lions by hand (Auto-tap off): the Forests can't pay its {W}, so the
##   Hero clicks the Treasure. The color that pays what is still owed glows green.
## Either way the color is asked: Auto-tap would choose it and ask nothing.
##
## A. Option Menu: the dropdown opens at the click with a row for each color, "Add {W}" to
##    "Add {G}". All five rows show (the real menu shows three and scrolls). Pointing at a
##    row shows the ability in full in the Info Panel.
## B. Pip fan: the five mana symbols fan out in an arc over the Treasure. One click chooses.
## C. Info Panel: "Choose a color for Treasure", with a pip for each color in the Answer
##    Row. A click, or Left and Right, selects; the Pass Button or Space gives it.
## D. Mana buttons: the Hero's five colored mana buttons glow as the choices. One click
##    makes that color.
## In every variant a click anywhere else, or X, closes the choice without making mana.
##
## Run: godot --path . res://prototypes/choose_color/choose_color.tscn
## Keys: 1 to 4 pick the variant, P switches the situation, R resets.
## For a picture: add -- --variant=A [--paying] [--open] [--point=0..4] [--pick=0..4]
##   [--chosen=0..4] --shot=/absolute/path.png

const VARIANTS: Array[String] = ["A", "B", "C", "D"]
const VARIANT_NAMES: Dictionary[String, String] = {
	"A": "Option Menu",
	"B": "Pip fan",
	"C": "Info Panel",
	"D": "Mana buttons",
}
const SCREEN: Vector2 = Vector2(1920, 1080)
## The five colors in WUBRG order, as MmMana.Type numbers them.
const COLORS: Array[String] = ["W", "U", "B", "R", "G"]
const WHITE_INDEX: int = 0
const PICKED: Color = Color.WHITE
const PLAIN: Color = Color("#8a93a6")
const CARDS: String = "res://content/cards/"
const FOREST: String = CARDS + "alpha/forest.tres"
const PLAINS: String = CARDS + "alpha/plains.tres"
const LIONS: String = CARDS + "alpha/savannah_lions.tres"
const BOLT: String = CARDS + "alpha/lightning_bolt.tres"
const GROWTH: String = CARDS + "alpha/giant_growth.tres"
const ANGEL: String = CARDS + "alpha/serra_angel.tres"
const VILLAIN_LANDS: Array[String] = [FOREST, FOREST, PLAINS, PLAINS, CARDS + "ravnica_city_of_guilds/temple_garden.tres"]
const VILLAIN_CREATURES: Array[String] = [CARDS + "zendikar_rising/prowling_felidar.tres", CARDS + "ikoria_lair_of_behemoths/frondland_felidar.tres"]
const HERO_CREATURES: Array[String] = [CARDS + "alpha/llanowar_elves.tres", CARDS + "alpha/grizzly_bears.tres"]
const HERO_LAND_COUNT: int = 3
const PORTRAITS: String = "res://ui/sprites/portraits/"
const TREASURE_TEXT: String = "{T}, Sacrifice this token: Add one mana of any color."
const CHOOSE_PROMPT: String = "Choose a color for Treasure"
const CHOOSE_PASS: String = "Choose a color"
const PRIORITY_PROMPT: String = "Your priority\nMain 1, your turn"
const LIBRARY_COUNT: int = 31
const FAN_PIP: float = 56.0

var _variant: String = "A"
var _is_paying: bool = false
## The Treasure was clicked and its color is being asked.
var _is_open: bool = false
## A and B: the color under the cursor, for a picture; -1 for none.
var _pointed: int = -1
## C: the Selected Answer, or -1.
var _picked: int = -1
## The color the Treasure made, or -1 while it is still on the battlefield.
var _chosen: int = -1

var _regions: Dictionary[String, Rect2] = {}
var _layer: Control
var _treasure_face: BattlefieldFace
var _hero_mana: Array[Button] = []
var _prompt: SymbolLabel
var _info: Control
var _pass_button: PassButton


func _ready() -> void:
	_regions = EncounterLayout.regions(SCREEN)
	var shot: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			shot = argument.trim_prefix("--shot=")
		elif argument.begins_with("--variant="):
			_variant = argument.trim_prefix("--variant=")
		elif argument == "--paying":
			_is_paying = true
		elif argument == "--open":
			_is_open = true
		elif argument.begins_with("--point="):
			_pointed = int(argument.trim_prefix("--point="))
		elif argument.begins_with("--pick="):
			_picked = int(argument.trim_prefix("--pick="))
		elif argument.begins_with("--chosen="):
			_chosen = int(argument.trim_prefix("--chosen="))
	if shot != "":
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
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
		KEY_1, KEY_2, KEY_3, KEY_4:
			_variant = VARIANTS[key.keycode - KEY_1]
			_reset()
		KEY_P:
			_is_paying = not _is_paying
			_reset()
		KEY_R:
			_reset()
		KEY_X:
			if _is_open:
				_close()
		KEY_LEFT, KEY_RIGHT:
			if _is_open and _variant == "C":
				var step: int = -1 if key.keycode == KEY_LEFT else 1
				_picked = 0 if _picked < 0 else clampi(_picked + step, 0, COLORS.size() - 1)
				_rebuild()
		KEY_SPACE:
			if _is_open and _variant == "C" and _picked >= 0:
				_choose(_picked)


func _reset() -> void:
	_is_open = false
	_pointed = -1
	_picked = -1
	_chosen = -1
	_rebuild()


## Whether the Lions are paid for: the Treasure made {W} while paying.
func _is_paid() -> bool:
	return _is_paying and _chosen == WHITE_INDEX


## Whether [param color] pays what is still owed: {W}, while paying for the Lions.
func _is_useful(color: int) -> bool:
	return _is_paying and not _is_paid() and color == WHITE_INDEX


func _rebuild() -> void:
	if _layer != null:
		_layer.queue_free()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	_hero_mana.clear()
	_build_board()
	_build_panels()
	_build_piles()
	_build_hand()
	_build_stack()
	_build_info()
	_build_switcher()
	if _is_open:
		_build_choice()


# The board ------------------------------------------------------------------------------

func _build_board() -> void:
	var back: ColorRect = ColorRect.new()
	back.color = Color("#161a21")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(back)
	for row: String in ["villain_lands", "villain_nonlands", "hero_nonlands", "hero_lands"]:
		_panel(_regions[row], Color("#1c212a"), Color("#2a303b"))
	_place_row(_looks(VILLAIN_LANDS), _regions["villain_lands"])
	_place_row(_looks(VILLAIN_CREATURES), _regions["villain_nonlands"])
	var creatures: Array[CardLook] = _looks(HERO_CREATURES)
	if _chosen < 0:
		creatures.append(_treasure_look())
	var faces: Array[BattlefieldFace] = _place_row(creatures, _regions["hero_nonlands"])
	var lands: Array[String] = []
	lands.resize(HERO_LAND_COUNT)
	lands.fill(FOREST)
	var land_faces: Array[BattlefieldFace] = _place_row(_looks(lands), _regions["hero_lands"])
	var mana: Color = DecisionClicks.color_of(DecisionClicks.Kind.MANA)
	# At priority every untapped source can be tapped; paying for {W}, only the Treasure helps.
	if not _is_paying and not _is_open:
		var sources: Array[BattlefieldFace] = land_faces.duplicate()
		sources.append(faces[0])
		for face: BattlefieldFace in sources:
			BorderEffects.add_glow(face, face.size, mana)
	_treasure_face = faces[-1] if _chosen < 0 else null
	if _treasure_face == null:
		return
	if _is_open:
		BorderEffects.add_glow(_treasure_face, _treasure_face.size, PICKED)
	elif not _is_paid():
		BorderEffects.add_glow(_treasure_face, _treasure_face.size, mana)
		ClickCatcher.add(_treasure_face, _treasure_face.size).clicked.connect(_open_choice)


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


## The Treasure as the Hero sees it. There is no Token Definition or art for it yet.
func _treasure_look() -> CardLook:
	var look: CardLook = CardLook.new()
	look.is_token = true
	look.name = "Treasure"
	look.card_types.append(MmCardTypes.CardType.ARTIFACT)
	look.subtypes.append("Treasure")
	look.rules_text = TREASURE_TEXT
	return look


func _build_panels() -> void:
	for side: String in ["villain", "hero"]:
		var box: Rect2 = _regions[side + "_panel"]
		_panel(box)
		var parts: Dictionary[String, Rect2] = EncounterLayout.panel(box)
		var name_label: Label = _label("Frondland Felidar" if side == "villain" else "Hero", 24, Color.WHITE, parts["name"].position)
		name_label.size.x = parts["name"].size.x
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_layer.add_child(name_label)
		var portrait: TextureRect = CardShapes.image(load(PORTRAITS + ("frondland_felidar.png" if side == "villain" else "white_wizard.png")) as Texture2D, parts["portrait"])
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_layer.add_child(portrait)
		_panel(parts["life"], Color(0.05, 0.06, 0.08, 0.85), Color(0, 0, 0, 0))
		var life: Label = _label("20", 34, Color.WHITE, parts["life"].position)
		life.size = parts["life"].size
		life.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		life.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_layer.add_child(life)
		for type: int in 6:
			var amount: int = 1 if side == "hero" and type == _chosen and not _is_paid() else 0
			var button: Button = _mana_button(parts["mana_%d" % type], type, amount)
			if side == "hero" and type < COLORS.size():
				_hero_mana.append(button)


## A mana button as the Player Panel draws it: dim with none of its color.
func _mana_button(box: Rect2, type: int, amount: int) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = PlayerPanel.PLAIN_COLOR.lightened(0.18) if state == "hover" else PlayerPanel.PLAIN_COLOR
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	var pip: float = minf(box.size.x - 6.0, 24.0)
	button.add_child(CardShapes.image(ManaSymbols.texture((MmMana.SYMBOLS[type] as String).to_lower()),
			Rect2((box.size.x - pip) / 2.0, 5, pip, pip)))
	var count: Label = _label("(%d)" % amount, 14, Color.WHITE, Vector2(0, 30))
	count.size.x = box.size.x
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(count)
	button.modulate = Color(1, 1, 1, 1.0 if amount > 0 else 0.55)
	_layer.add_child(button)
	return button


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


## The hand, a card that can be cast now glowing green. While paying, the Lions are on the
## stack and nothing can be cast.
func _build_hand() -> void:
	var files: Array[String] = [BOLT, GROWTH, ANGEL]
	if not _is_paying:
		files.push_front(LIONS)
	var hand: Rect2 = _regions["hero_hand"]
	var height: float = EncounterLayout.HAND_CARD_HEIGHT
	var width: float = height * CardGeometry.ASPECT
	# The cards overlap, as in the Hand Strip, when they would not fit side by side.
	var step: float = minf(width + 10.0, (hand.size.x - width) / maxf(1.0, files.size() - 1.0))
	var x: float = hand.get_center().x - ((files.size() - 1) * step + width) / 2.0
	for file: String in files:
		var face: CardFace = CardFace.new()
		face.setup(_look(file), height)
		face.position = Vector2(x, SCREEN.y - height * 0.42)
		_layer.add_child(face)
		if not _is_paying and not _is_open and _can_cast(file):
			BorderEffects.add_glow(face, face.size, DecisionClicks.color_of(DecisionClicks.Kind.PLAY))
		x += step


## Whether [param file] can be cast at priority: Forests and the Elves make {G}, and the
## Treasure any one color, or the color it made.
func _can_cast(file: String) -> bool:
	match file:
		GROWTH:
			return true
		LIONS:
			return _chosen < 0 or _chosen == WHITE_INDEX
		BOLT:
			return _chosen < 0 or _chosen == COLORS.find("R")
	return false


func _build_stack() -> void:
	if not _is_paying:
		return
	var window: ZoneWindow = ZoneWindow.new("Stack", false, PLAIN)
	window.size = Vector2(460, 140)
	window.position = Vector2(_regions["battlefield"].end.x - 480.0, _regions["villain_nonlands"].position.y + 20.0)
	_layer.add_child(window)
	window.show_title("Stack (1)")
	window.open()
	window.body().add_child(StackEntry.new("savannah_lions", "Savannah Lions", "", PLAIN))


# The Info Panel and the Pass Button --------------------------------------------------------

func _build_info() -> void:
	var box: Rect2 = _regions["info"]
	var info: Control = Control.new()
	info.position = box.position
	info.size = box.size
	_layer.add_child(info)
	_info = info
	var back: Panel = Panel.new()
	back.size = box.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.add_theme_stylebox_override("panel", DitherShading.plate(InfoPanel.FILL.lightened(0.06),
		InfoPanel.FILL.darkened(0.3), InfoPanel.BORDER, 8, 2, 0, maxi(1, int(box.size.y))))
	info.add_child(back)
	_prompt = SymbolLabel.new()
	_prompt.set_font_size(InfoPanel.PROMPT_FONT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(InfoPanel.INSET, InfoPanel.TOP)
	_prompt.size = Vector2(box.size.x - InfoPanel.INSET * 2.0, 0)
	info.add_child(_prompt)
	var row: Rect2 = Rect2(InfoPanel.INSET, box.size.y - InfoPanel.INSET - InfoPanel.ROW_HEIGHT,
		box.size.x - InfoPanel.INSET * 2.0, InfoPanel.ROW_HEIGHT)
	var pass_button: PassButton = PassButton.new()
	_pass_button = pass_button
	pass_button.place(_regions["pass"])
	pass_button.show_key("SPACE")
	_layer.add_child(pass_button)
	var asks_here: bool = _is_open and _variant != "A"
	if asks_here:
		_prompt.write(CHOOSE_PROMPT)
	elif _is_paying and not _is_paid():
		_prompt.write("Pay for Savannah Lions\n{W}")
		_answer_button(info, Rect2(row.position, row.size), InfoPanel.CANCEL_FORMAT % "X", false)
	else:
		_prompt.write(PRIORITY_PROMPT)
	if _is_open and _variant == "A" and _pointed >= 0:
		_prompt.write(_option_in_full(_pointed))
	if _is_open and _variant == "C":
		_build_answer_pips(info, row)
		if _picked < 0:
			pass_button.show_confirm(CHOOSE_PASS, false, false)
		else:
			pass_button.show_confirm("Add {%s}" % COLORS[_picked], true, true)
			pass_button.pressed.connect(func() -> void: _choose(_picked))
		return
	pass_button.show_pass(not (_is_paying and not _is_paid()))


## A row of the Option Menu, written out in full as the Info Panel shows it under the cursor.
func _option_in_full(color: int) -> String:
	return "{T}, Sacrifice this token: Add {%s}." % COLORS[color]


## C: a pip for each color across the Answer Row, the Selected Answer's ring white.
func _build_answer_pips(info: Control, row: Rect2) -> void:
	var gap: float = InfoPanel.ROW_GAP
	var width: float = (row.size.x - gap * (COLORS.size() - 1)) / COLORS.size()
	for color: int in COLORS.size():
		var box: Rect2 = Rect2(row.position + Vector2((width + gap) * color, 0), Vector2(width, row.size.y))
		var button: Button = _answer_button(info, box, "", color == _picked)
		var pip: float = 30.0
		var face: float = SteelFrame.face_height(box.size.y)
		button.add_child(CardShapes.image(ManaSymbols.texture(COLORS[color].to_lower()),
			Rect2((box.size.x - pip) / 2.0, (face - pip) / 2.0, pip, pip)))
		if _is_useful(color):
			BorderEffects.add_glow(button, button.size, DecisionClicks.color_of(DecisionClicks.Kind.PLAY))
		button.pressed.connect(func() -> void:
			_picked = color
			_rebuild())


## A button of the Answer Row, framed as the Info Panel frames its own.
func _answer_button(info: Control, box: Rect2, words: String, is_lit: bool) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	button.text = words
	button.add_theme_font_size_override("font_size", InfoPanel.BUTTON_FONT + UiText.RAISE)
	SteelFrame.apply(button, InfoPanel.SELECTED if is_lit else InfoPanel.BUTTON, is_lit)
	info.add_child(button)
	if words.begins_with("Cancel"):
		button.pressed.connect(_reset)
	return button


# The choice ---------------------------------------------------------------------------------

func _build_choice() -> void:
	# A click anywhere but on a choice closes it, as a click outside the Option Menu does.
	var away: Control = Control.new()
	away.set_anchors_preset(Control.PRESET_FULL_RECT)
	away.mouse_filter = Control.MOUSE_FILTER_STOP
	away.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed:
			_close())
	_layer.add_child(away)
	match _variant:
		"A":
			_build_menu()
		"B":
			_build_fan()
		"C":
			# The Info Panel and the Pass Button answer: lift them over the catcher.
			_layer.move_child(_info, -1)
			_layer.move_child(_pass_button, -1)
		"D":
			var green: Color = DecisionClicks.color_of(DecisionClicks.Kind.PLAY)
			for color: int in _hero_mana.size():
				var button: Button = _hero_mana[color]
				_layer.move_child(button, -1)
				button.modulate = Color.WHITE
				# Every color glows, or nothing would say the buttons can be clicked; paying,
				# only the one that pays does.
				if not _is_paying or _is_useful(color):
					BorderEffects.add_glow(button, button.size, green)
				button.pressed.connect(_choose.bind(color))


## A: the Option Menu's box and rows, as OptionMenu draws them, with every row shown.
func _build_menu() -> void:
	var at: Vector2 = _treasure_face.position + _treasure_face.size / 2.0
	var field: Rect2 = _regions["battlefield"]
	var rows: int = COLORS.size()
	var menu: Vector2 = Vector2(EncounterLayout.MENU_WIDTH,
		rows * EncounterLayout.MENU_ROW + (rows - 1) * EncounterLayout.MENU_GAP + EncounterLayout.MENU_PAD * 2.0)
	var box: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.13, 0.98)
	style.border_color = InfoPanel.BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	box.add_theme_stylebox_override("panel", style)
	box.position = Vector2(clampf(at.x, field.position.x, field.end.x - menu.x), clampf(at.y, field.position.y, field.end.y - menu.y))
	box.size = menu
	_layer.add_child(box)
	for color: int in rows:
		var row: Button = Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.position = Vector2(EncounterLayout.MENU_PAD, EncounterLayout.MENU_PAD + color * (EncounterLayout.MENU_ROW + EncounterLayout.MENU_GAP))
		row.size = Vector2(menu.x - EncounterLayout.MENU_PAD * 2.0, EncounterLayout.MENU_ROW)
		for state: String in ["normal", "hover", "pressed"]:
			var flat: StyleBoxFlat = StyleBoxFlat.new()
			var is_lit: bool = state != "normal" or color == _pointed
			flat.bg_color = PlayerPanel.PLAIN_COLOR.lightened(0.22) if is_lit else PlayerPanel.PLAIN_COLOR
			flat.set_corner_radius_all(4)
			row.add_theme_stylebox_override(state, flat)
		var words: SymbolLabel = SymbolLabel.new()
		words.set_font_size(18)
		words.position = Vector2(10, 7)
		words.size = Vector2(row.size.x - 20, 0)
		words.write("Add {%s}" % COLORS[color])
		row.add_child(words)
		if _is_useful(color):
			BorderEffects.add_glow(row, row.size, DecisionClicks.color_of(DecisionClicks.Kind.PLAY))
		row.mouse_entered.connect(func() -> void: _prompt.write(_option_in_full(color)))
		row.mouse_exited.connect(func() -> void: _prompt.write("Pay for Savannah Lions\n{W}" if _is_paying else PRIORITY_PROMPT))
		row.pressed.connect(_choose.bind(color))
		box.add_child(row)


## B: the five pips in an arc over the Treasure, white on the left to green on the right.
func _build_fan() -> void:
	var center: Vector2 = _treasure_face.position + Vector2(_treasure_face.size.x / 2.0, _treasure_face.size.y * 0.45)
	var radius: float = _treasure_face.size.x * 0.5 + FAN_PIP * 0.9
	for color: int in COLORS.size():
		var angle: float = deg_to_rad(180.0 - 30.0 - 30.0 * color)
		var middle: Vector2 = center + Vector2(cos(angle), -sin(angle)) * radius
		var button: Button = Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.size = Vector2.ONE * FAN_PIP
		button.position = middle - button.size / 2.0
		for state: String in ["normal", "hover", "pressed"]:
			var disc: StyleBoxFlat = StyleBoxFlat.new()
			var is_lit: bool = state != "normal" or color == _pointed
			disc.bg_color = Color(0.09, 0.1, 0.13, 0.96).lightened(0.25 if is_lit else 0.0)
			disc.border_color = Color.WHITE if is_lit else InfoPanel.BORDER
			disc.set_border_width_all(2)
			disc.set_corner_radius_all(int(FAN_PIP / 2.0))
			button.add_theme_stylebox_override(state, disc)
		var pip: float = FAN_PIP - 14.0
		button.add_child(CardShapes.image(ManaSymbols.texture(COLORS[color].to_lower()), Rect2(7, 7, pip, pip)))
		if _is_useful(color):
			BorderEffects.add_glow(button, button.size, DecisionClicks.color_of(DecisionClicks.Kind.PLAY))
		button.pressed.connect(_choose.bind(color))
		_layer.add_child(button)


# Answers ------------------------------------------------------------------------------------

func _open_choice() -> void:
	_is_open = true
	_pointed = -1
	_picked = -1
	_rebuild()


func _close() -> void:
	_is_open = false
	_pointed = -1
	_picked = -1
	_rebuild()


## The Treasure is tapped and sacrificed for [param color].
func _choose(color: int) -> void:
	_chosen = color
	_is_open = false
	_pointed = -1
	_picked = -1
	_rebuild()


func _build_switcher() -> void:
	var bar: Panel = _panel(Rect2(_regions["hold"].position, Vector2(_regions["hold"].size.x, 64)), Color("#3a2a10"), Color("#f1dc9a"))
	var situation: String = "Paying for Savannah Lions" if _is_paying else "At priority"
	bar.add_child(_label("PROTOTYPE  %s. %s  (keys 1–4)\n%s  (P)   R: reset" % [_variant, VARIANT_NAMES[_variant], situation],
		14, Color("#f1dc9a"), Vector2(10, 6)))


# Helpers ------------------------------------------------------------------------------------

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
