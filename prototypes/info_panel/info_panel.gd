extends Control
## PROTOTYPE (milestone 13l, the Info Panel overhaul): throwaway. The Info Panel grown to
## 360 wide and the hand strip's height, the Pass Button moved to the strip's right end,
## and a question's answers selected in the panel and given with the Pass Button or Space,
## on a mock board with no engine. Nothing here is ported as it is; what the user signs off
## on is rebuilt test-first in ui/encounter/.
##
## Run: godot --path . res://prototypes/info_panel/info_panel.tscn
## Keys: [ and ] switch state, R resets it. Left and Right move the Selected Answer, Up and
##   Down step X, Space presses the Pass Button.
## For a picture: add -- --state=ward [--select=0] [--x=1] --shot=/absolute/path.png

const SCREEN: Vector2 = Vector2(1920, 1080)
const CARDS: String = "res://content/cards/"
const PLAINS: String = CARDS + "alpha/plains.tres"
const HERO_CREATURES: Array[String] = [CARDS + "alpha/savannah_lions.tres", CARDS + "mirrodin/taj_nar_swordsmith.tres"]
const VILLAIN_CREATURES: Array[String] = [
	CARDS + "darksteel/leonin_shikari.tres", CARDS + "phyrexia_all_will_be_one/leonin_lightbringer.tres",
]
const HAND: Array[String] = [
	CARDS + "alpha/serra_angel.tres", CARDS + "alpha/white_knight.tres", CARDS + "theros/leonin_snarecaster.tres",
	CARDS + "alpha/savannah_lions.tres", PLAINS,
]

# The new places, in place of EncounterLayout's "info", "pass", "hold" and "hero_hand".
const BOX_WIDTH: float = 360.0
const PASS_HEIGHT: float = 96.0
const PAD: float = 6.0
const INSET: float = 12.0
const ROW_HEIGHT: float = 44.0
const ROW_GAP: float = 8.0

const FILL: Color = Color("#2c323c")
const BORDER: Color = Color("#8a93a6")
const BUTTON: Color = Color("#4b4e55")
const SELECTED: Color = Color("#6f7682")
const MUTED: Color = Color(1, 1, 1, 0.65)
const REFUSED: Color = Color(1, 0.45, 0.4)
const DIM: float = 0.45
const PROMPT_FONT: int = 22
const SMALL_PROMPT_FONT: int = 18
const SMALL_FONT: int = 16
const BUTTON_FONT: int = 20
const PASS_FONT: int = 26
const NONE: int = -1
## The button borders to weigh. Each is drawn in whole pixels with stepped corners.
const BORDERS: Array[String] = ["A", "B", "C"]
const BORDER_NAMES: Dictionary[String, String] = {"A": "Steel frame", "B": "Ink and rim", "C": "Bevel"}
const INK: Color = Color("#0b0d11")
const STEEL: Color = Color("#aab2c2")
## A border's rings are this many pixels thick, and its corners step in blocks of it.
const RING: int = 3
## The stepper: how wide each end is, and the flat gray of the well its number sits in.
const STEPPER_END: float = 46.0
const WELL: Color = Color("#1e2228")
const CORNER_STEPS: int = 2
const MOST_X: int = 4

## Each state: what the panel asks, and what its Answer Row and the Pass Button hold.
## "answers" are selected and given with the Pass Button; "action" is one button that acts.
const STATES: Array[String] = [
	"priority", "held", "paying", "may", "ward", "x", "attackers", "refusal", "long", "option", "idle",
]
const STATE: Dictionary[String, Dictionary] = {
	"priority": {"prompt": "Your priority\nPrecombat main, your turn", "pass": "Pass Priority", "can_pass": true},
	"held": {"prompt": "Your priority\nPrecombat main, your turn", "pass": "Pass Priority", "can_pass": true, "holds": true},
	"paying": {"prompt": "Pay for Serra Angel\n{3}{W}{W}", "action": "Cancel [X]", "pass": "Pass Priority"},
	"may": {"prompt": "Leonin Snarecaster's ability: tap target creature?", "answers": ["Yes", "No"], "starts": 0},
	"ward": {"prompt": "Pay ward for Leonin Lightbringer: {2}", "answers": ["Pay {2}", "No"], "starts": NONE},
	"x": {"prompt": "Pay {X} for Taj-Nar Swordsmith?", "answers": ["Pay {%d}", "No"], "starts": NONE, "steps": true},
	"attackers": {"prompt": "Declare attackers", "action": "Declare All", "pass": "Attack with 0", "can_pass": true},
	"refusal": {
		"prompt": "Choose a target for Swords to Plowshares", "action": "Cancel [X]", "pass": "Pass Priority",
		"refused": "Leonin Lightbringer has ward, and you can't pay for it.",
	},
	"long": {
		"prompt": "Taj-Nar Swordsmith's ability: search your library for an Equipment card with mana value 2 or less",
		"pass": "Pass Priority",
	},
	"option": {"option": "Leonin Shikari: {1}{W}, {T}: Tap target creature. Activate only as a sorcery.", "pass": "Pass Priority", "can_pass": true},
	"idle": {"prompt": "", "pass": "Pass Priority", "is_idle": true},
}

var _state: String = "priority"
var _selected: int = 0
var _x: int = 2
## What the Hero last answered, shown on the prototype's bar.
var _answered: String = ""
## Which button border is drawn: see _plate().
var _border: String = "A"
var _plates: Dictionary[String, StyleBoxTexture] = {}

var _regions: Dictionary[String, Rect2] = {}
var _layer: Control
var _info_box: Rect2
var _pass_box: Rect2
var _hold_box: Rect2
var _hand_box: Rect2
var _flash: Panel


func _ready() -> void:
	_regions = EncounterLayout.regions(SCREEN)
	var battlefield_left: float = _regions["hero_lands"].position.x
	var battlefield_width: float = _regions["hero_lands"].size.x
	var strip_top: float = _regions["pass"].position.y - EncounterLayout.INFO_PAD
	_info_box = Rect2(battlefield_left, strip_top + PAD, BOX_WIDTH, SCREEN.y - strip_top - PAD * 2.0)
	_pass_box = Rect2(battlefield_left + battlefield_width - BOX_WIDTH, SCREEN.y - PAD - PASS_HEIGHT, BOX_WIDTH, PASS_HEIGHT)
	_hold_box = Rect2(battlefield_left, PAD, BOX_WIDTH, _regions["hold"].size.y)
	var hand_inset: float = BOX_WIDTH + EncounterLayout.GUTTER
	_hand_box = Rect2(battlefield_left + hand_inset, strip_top, battlefield_width - hand_inset * 2.0, SCREEN.y - strip_top)
	var shot: String = ""
	var select: int = -2
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			shot = argument.trim_prefix("--shot=")
		elif argument.begins_with("--state="):
			_state = argument.trim_prefix("--state=")
		elif argument.begins_with("--select="):
			select = int(argument.trim_prefix("--select="))
		elif argument.begins_with("--border="):
			_border = argument.trim_prefix("--border=")
		elif argument.begins_with("--x="):
			_x = int(argument.trim_prefix("--x="))
	if shot != "":
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_selected = STATE[_state].get("starts", NONE)
	if select > -2:
		_selected = select
	_rebuild(shot == "")
	if shot != "":
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var answers: Array = STATE[_state].get("answers", [])
	match key.keycode:
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var step: int = -1 if key.keycode == KEY_BRACKETLEFT else 1
			_enter(STATES[(STATES.find(_state) + step + STATES.size()) % STATES.size()])
		KEY_R:
			_enter(_state)
		KEY_B:
			_border = BORDERS[(BORDERS.find(_border) + 1) % BORDERS.size()]
			_rebuild(false)
		KEY_LEFT, KEY_RIGHT:
			if not answers.is_empty():
				_select(0 if key.keycode == KEY_LEFT else 1)
		KEY_UP, KEY_DOWN:
			if STATE[_state].get("steps", false):
				_step(1 if key.keycode == KEY_UP else -1)
		KEY_SPACE:
			_press_pass()


func _enter(state: String) -> void:
	_state = state
	_selected = STATE[state].get("starts", NONE)
	_x = 2
	_answered = ""
	_rebuild(true)


func _select(index: int) -> void:
	_selected = index
	_rebuild(false)


func _step(by: int) -> void:
	_x = clampi(_x + by, 0, MOST_X)
	_selected = 0
	_rebuild(false)


func _press_pass() -> void:
	var state: Dictionary = STATE[_state]
	var answers: Array = state.get("answers", [])
	if answers.is_empty():
		if state.get("can_pass", false):
			_answered = state["pass"]
			_rebuild(false)
		return
	if _selected == NONE:
		return
	_answered = _answer_words(_selected)
	_rebuild(false)


## What answer [param index] of this state reads: "Yes", "Pay {2}", "No".
func _answer_words(index: int) -> String:
	var words: String = STATE[_state]["answers"][index]
	return words % _x if words.contains("%d") else words


func _rebuild(flashes: bool) -> void:
	if _layer != null:
		_layer.queue_free()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	_build_board()
	_build_panels()
	_build_piles()
	_build_hand()
	_build_info()
	_build_pass()
	if STATE[_state].get("holds", false):
		_build_hold()
	_build_bar()
	# The border flashes once when a question other than priority arrives.
	if flashes and not STATE[_state].get("is_idle", false) and _state not in ["priority", "held", "option"]:
		_flash.modulate.a = 1.0
		create_tween().tween_property(_flash, "modulate:a", 0.0, 0.3)


# The Info Panel ----------------------------------------------------------------------------

func _build_info() -> void:
	var state: Dictionary = STATE[_state]
	var info: Control = Control.new()
	info.position = _info_box.position
	info.size = _info_box.size
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(info)
	var back: Panel = Panel.new()
	back.size = _info_box.size
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", DitherShading.plate(FILL.lightened(0.06), FILL.darkened(0.3), BORDER, 8, 2, 0,
		int(_info_box.size.y)))
	back.modulate.a = DIM if state.get("is_idle", false) else 1.0
	info.add_child(back)
	_flash = CardShapes.outline(_info_box.size, 8, 3, Color.WHITE)
	_flash.modulate.a = 0.0
	info.add_child(_flash)
	var inside: float = _info_box.size.x - INSET * 2.0
	if state.has("option"):
		# An Option Menu row in full, in place of everything else.
		var option: SymbolLabel = _words(state["option"], PROMPT_FONT, Rect2(INSET, 8, inside, _info_box.size.y - 16))
		option.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_child(option)
		return
	var prompt_text: String = state["prompt"]
	var font_size: int = PROMPT_FONT if _line_count(prompt_text, PROMPT_FONT, inside) <= 2 else SMALL_PROMPT_FONT
	var prompt: SymbolLabel = _words(prompt_text, font_size, Rect2(INSET, 8, inside, 64))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(prompt)
	var row_top: float = _info_box.size.y - INSET - ROW_HEIGHT
	if state.has("refused"):
		# One line as a rule, two when it must: it grows upward from the Answer Row.
		var refused: Label = _label("", SMALL_FONT, REFUSED, Vector2(INSET, row_top - 52))
		refused.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		refused.add_theme_constant_override("line_spacing", -2)
		refused.size = Vector2(inside, 48)
		refused.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		refused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		refused.text = state["refused"]
		info.add_child(refused)
	var half: float = (inside - ROW_GAP) / 2.0
	var answers: Array = state.get("answers", [])
	for index: int in answers.size():
		var box: Rect2 = Rect2(INSET + (half + ROW_GAP) * index, row_top, half, ROW_HEIGHT)
		var is_selected: bool = index == _selected
		if index == 0 and state.get("steps", false):
			info.add_child(_stepper(box, is_selected))
		else:
			info.add_child(_answer(_answer_words(index), box, is_selected, _select.bind(index)))
	if state.has("action"):
		info.add_child(_answer(state["action"], Rect2(INSET, row_top, inside, ROW_HEIGHT), false, func() -> void: pass))


## One half of the Answer Row: a shaded button that selects its answer, lit while selected.
func _answer(text: String, box: Rect2, is_selected: bool, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	button.add_theme_font_size_override("font_size", BUTTON_FONT + UiText.RAISE)
	_shade(button, SELECTED if is_selected else BUTTON, is_selected)
	button.pressed.connect(on_press)
	if text.contains("{"):
		var line: SymbolLabel = _words(text, BUTTON_FONT, Rect2(0, 6, box.size.x, 30))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(line)
	else:
		button.text = text
	return button


## The X stepper as the Pay answer: one plate, bordered as any answer is, whose ends are the
## − and the + and whose middle is a flat dark well holding the number. A click on an end
## steps X; a click anywhere on it, or a step, selects it.
func _stepper(box: Rect2, is_selected: bool) -> Button:
	var plate: Button = _answer("", box, is_selected, _select.bind(0))
	var face: float = box.size.y - DitherShading.LIP
	# The frame is the ring and the dark line inside it.
	var frame: float = RING + 1.0
	var end: float = STEPPER_END
	var well: ColorRect = ColorRect.new()
	well.color = WELL
	well.position = Vector2(end, frame)
	well.size = Vector2(box.size.x - end * 2.0, face - frame * 2.0)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(well)
	for x: float in [end - 1.0, box.size.x - end]:
		var divider: ColorRect = ColorRect.new()
		divider.color = WELL.darkened(0.5)
		divider.position = Vector2(x, frame)
		divider.size = Vector2(1, face - frame * 2.0)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(divider)
	var amount: Label = _label(str(_x), 24, Color.WHITE, well.position)
	amount.size = well.size
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(amount)
	plate.add_child(_stepper_end("−", Rect2(frame, frame, end - 1.0 - frame, face - frame * 2.0), _x > 0, _step.bind(-1)))
	plate.add_child(_stepper_end("+", Rect2(box.size.x - end + 1.0, frame, end - 1.0 - frame, face - frame * 2.0), _x < MOST_X,
		_step.bind(1)))
	return plate


## One end of the stepper: its sign, drawn straight on the plate's own face, and the
## click that steps. It has no plate of its own, only a lighter face under the cursor.
func _stepper_end(sign_text: String, box: Rect2, is_enabled: bool, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = sign_text
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	button.disabled = not is_enabled
	button.add_theme_font_size_override("font_size", 24 + UiText.RAISE)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = Color(1, 1, 1, 0.0)
		if state == "hover":
			flat.bg_color = Color(1, 1, 1, 0.12)
		elif state in ["pressed", "hover_pressed"]:
			flat.bg_color = Color(0, 0, 0, 0.25)
		button.add_theme_stylebox_override(state, flat)
	button.pressed.connect(on_press)
	return button


## Shades [param button] with the border being weighed, in every state.
func _shade(button: Button, color: Color, is_selected: bool) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state: String in ButtonShading.STATES:
		button.add_theme_stylebox_override(state, _plate(color, state, int(button.size.y), is_selected))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", ButtonShading.DISABLED_TEXT)


## A button plate with a pixel border, its corners stepped rather than rounded.
## A, Steel frame: a light steel ring with a dark line inside it.
## B, Ink and rim: a near-black ring with a light rim inside it.
## C, Bevel: a near-black ring, then a rim lit at the top and left and dark at the bottom
##    and right.
## A selected button's outer ring is white. A disabled one lies flat, with no lip.
func _plate(fill: Color, state: String, height: int, is_selected: bool) -> StyleBoxTexture:
	var key: String = "%s/%s/%s/%d/%s" % [_border, fill.to_html(), state, height, is_selected]
	if _plates.has(key):
		return _plates[key]
	var is_disabled: bool = state == "disabled"
	var is_pressed: bool = state in ["pressed", "hover_pressed"]
	if is_disabled:
		fill = ButtonShading.DISABLED
	elif state == "hover":
		fill = fill.lightened(InspectorParts.HOVER_LIGHTEN)
	var lip: int = 0 if is_disabled else (DitherShading.PRESSED_LIP if is_pressed else DitherShading.LIP)
	# A pressed button sits down on its lip: its face starts lower.
	var drop: int = 0 if is_disabled or not is_pressed else DitherShading.LIP - DitherShading.PRESSED_LIP
	var face_height: int = height - lip - drop
	var top: Color = fill.darkened(0.2) if is_pressed else fill.lightened(0.12)
	var bottom: Color = fill.lightened(0.02) if is_pressed else fill.darkened(0.25)
	var outer: Color = STEEL if _border == "A" else INK
	if is_selected:
		outer = Color.WHITE
	elif is_disabled:
		outer = outer.lerp(FILL, 0.6)
	var lip_color: Color = STEEL.darkened(0.55) if _border == "A" else INK
	var corner: int = RING * (CORNER_STEPS + 3)
	var width: int = corner * 2 + DitherShading.BLOCK * 4
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			var face_y: int = y - drop
			var color: Color = Color(0, 0, 0, 0)
			if _is_in(x, face_y, width, face_height, 0):
				var shaded: Color = DitherShading.band_color(x, face_y, face_height, top, bottom)
				if not _is_in(x, face_y, width, face_height, RING):
					color = outer
				elif _border == "A":
					color = shaded if _is_in(x, face_y, width, face_height, RING + 1) else fill.darkened(0.65)
				elif _is_in(x, face_y, width, face_height, RING * 2):
					color = shaded
				elif _border == "B":
					color = fill.lightened(0.2 if is_disabled else 0.45)
				else:
					# C: the rim is lit where it faces up or left.
					var is_lit: bool = face_y < RING * 2 or x < RING * 2
					var is_shadowed: bool = face_y >= face_height - RING * 2 or x >= width - RING * 2
					color = fill.lightened(0.5) if is_lit and not is_shadowed else fill.darkened(0.5)
					if is_disabled:
						color = color.lerp(fill, 0.6)
			elif lip > 0 and _is_in(x, face_y - lip, width, face_height, 0):
				color = lip_color
			image.set_pixel(x, y, color)
	var made: StyleBoxTexture = StyleBoxTexture.new()
	made.texture = ImageTexture.create_from_image(image)
	made.texture_margin_left = corner
	made.texture_margin_right = corner
	made.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	made.content_margin_left = 8
	made.content_margin_right = 8
	made.content_margin_top = drop
	made.content_margin_bottom = lip
	_plates[key] = made
	return made


## Whether the pixel is inside a [param width] × [param height] box shrunk by
## [param depth], whose corners step in RING-sized blocks.
func _is_in(x: int, y: int, width: int, height: int, depth: int) -> bool:
	var from_side: int = mini(x, width - 1 - x) - depth
	var from_end: int = mini(y, height - 1 - y) - depth
	if from_side < 0 or from_end < 0:
		return false
	return from_side / RING + from_end / RING >= CORNER_STEPS


# The Pass Button ---------------------------------------------------------------------------

func _build_pass() -> void:
	var state: Dictionary = STATE[_state]
	var answers: Array = state.get("answers", [])
	var words: String = state.get("pass", "")
	var can_press: bool = state.get("can_pass", false)
	var has_key: bool = true
	if not answers.is_empty():
		can_press = _selected != NONE
		words = _answer_words(_selected) if can_press else "Choose an answer"
		has_key = can_press
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.position = _pass_box.position
	button.size = _pass_box.size
	button.disabled = not can_press
	_shade(button, Inspector.palette().button, false)
	button.pressed.connect(_press_pass)
	_layer.add_child(button)
	var face: float = _pass_box.size.y - (DitherShading.LIP if can_press else 0)
	var color: Color = Color.WHITE if can_press else ButtonShading.DISABLED_TEXT
	var line: SymbolLabel = _words(words, PASS_FONT, Rect2(0, face / 2.0 - (32 if has_key else 20), _pass_box.size.x, 40), color)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(line)
	if has_key:
		var key: Label = _label("SPACE", SMALL_FONT, Color(color, color.a * 0.6), Vector2(0, face / 2.0 + 10))
		key.size = Vector2(_pass_box.size.x, 24)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(key)


func _build_hold() -> void:
	var hold: HoldPanel = HoldPanel.new()
	hold.place(_hold_box)
	hold.set_key_down(true)
	_layer.add_child(hold)


## The prototype's own bar, top middle, clear of the Hold Panel.
func _build_bar() -> void:
	var box: Rect2 = Rect2(_hold_box.end.x + 40.0, 6, 520, 60)
	var bar: Panel = _panel(box, Color("#3a2a10"), Color("#f1dc9a"))
	var answered: String = "   answered: %s" % _answered if _answered != "" else ""
	bar.add_child(_label("PROTOTYPE  [ %s ]  %d of %d   border %s: %s%s\n[ ] state   ← → answer   ↑ ↓ X   SPACE   R reset   B border" % [
		_state, STATES.find(_state) + 1, STATES.size(), _border, BORDER_NAMES[_border], answered], 12, Color("#f1dc9a"), Vector2(10, 6)))


# The board ---------------------------------------------------------------------------------

func _build_board() -> void:
	var back: ColorRect = ColorRect.new()
	back.color = Color("#161a21")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(back)
	for row: String in ["villain_lands", "villain_nonlands", "hero_nonlands", "hero_lands"]:
		_panel(_regions[row], Color("#1c212a"), Color("#2a303b"))
	_place_row(_copies(PLAINS, 5), _regions["villain_lands"])
	_place_row(VILLAIN_CREATURES, _regions["villain_nonlands"])
	_place_row(HERO_CREATURES, _regions["hero_nonlands"])
	_place_row(_copies(PLAINS, 6), _regions["hero_lands"])


func _copies(file: String, count: int) -> Array[String]:
	var files: Array[String] = []
	files.resize(count)
	files.fill(file)
	return files


func _place_row(files: Array[String], row: Rect2) -> void:
	var height: float = row.size.y - 24.0
	var face_size: Vector2 = BattlefieldFace.size_for(height)
	var total: float = files.size() * face_size.x + (files.size() - 1) * 16.0
	var x: float = row.position.x + (row.size.x - total) / 2.0
	for file: String in files:
		var face: BattlefieldFace = BattlefieldFace.new()
		face.setup(_look(file), height)
		face.position = Vector2(x, row.position.y + (row.size.y - face_size.y) / 2.0)
		_layer.add_child(face)
		x += face_size.x + 16.0


func _build_panels() -> void:
	for side: String in ["villain", "hero"]:
		var box: Rect2 = _regions[side + "_panel"]
		var panel: Panel = _panel(box)
		var parts: Dictionary[String, Rect2] = EncounterLayout.panel(box)
		panel.add_child(_label("Kemba, Kha Enduring" if side == "villain" else "Jackson", 22, Color.WHITE,
			parts["name"].position - box.position + Vector2(20, 0)))
		_panel(parts["portrait"], Color("#2b3140"))
		_layer.add_child(_label("20", 34, Color.WHITE, parts["life"].position))


func _build_piles() -> void:
	for pile: String in ["villain_exile", "villain_graveyard", "villain_library", "hero_library", "hero_graveyard", "hero_exile"]:
		var rect: Rect2 = _regions[pile]
		_panel(EncounterLayout.zone_plates(_regions)[pile], Color("#1c212a"), Color("#2a303b"))
		var width: float = EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT
		var card: Rect2 = Rect2(rect.get_center().x - width / 2.0, rect.position.y, width, EncounterLayout.PILE_HEIGHT)
		if pile.ends_with("library"):
			var card_back: Panel = CardBack.make(card.size.y)
			card_back.position = card.position
			_layer.add_child(card_back)
		else:
			_panel(card, Color("#161a21"), Color("#2a303b"))


## The hand, centered between the Info Panel and the Pass Button's column.
func _build_hand() -> void:
	var height: float = EncounterLayout.HAND_CARD_HEIGHT
	var card: Vector2 = Vector2(height * CardGeometry.ASPECT, height)
	var rest: Array[Vector2] = EncounterLayout.hand_rest(HAND.size(), _hand_box, card)
	for index: int in HAND.size():
		var face: CardFace = CardFace.new()
		face.setup(_look(HAND[index]), height)
		face.position = rest[index]
		_layer.add_child(face)


# Helpers -----------------------------------------------------------------------------------

func _look(file: String) -> CardLook:
	return CardLook.of_definition(load(file) as MmCardDefinition)


## How many lines [param text] takes at [param font_size] in [param width].
func _line_count(text: String, font_size: int, width: float) -> int:
	var font: Font = get_theme_default_font()
	var raised: int = font_size + UiText.RAISE
	# A mana symbol is about as wide as two letters of its line.
	var plain: String = text.replace("{", "").replace("}", "0")
	return roundi(font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, width, raised).y / font.get_height(raised))


func _words(text: String, font_size: int, box: Rect2, color: Color = Color.WHITE) -> SymbolLabel:
	var line: SymbolLabel = SymbolLabel.new()
	line.set_font_size(font_size + UiText.RAISE)
	line.position = box.position
	line.size = box.size
	line.write_in(text, color)
	return line


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
	label.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
