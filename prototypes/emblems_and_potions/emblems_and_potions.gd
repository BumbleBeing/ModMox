extends Control
## PROTOTYPE (milestone 14, A529): throwaway. Shows how Emblems and Potions are clicked,
## with made-up data and no engine: the two buttons in their three states, the Emblems and
## Potions windows, a window closing as an ability is started and coming back on cancel or
## undo, a Potion in the Inspector, and the graybox Emblem Face. Nothing here is ported as
## it is; what the user signs off on is rebuilt test-first in ui/encounter/.
##
## Run: godot --path . res://prototypes/emblems_and_potions/emblems_and_potions.tscn
## For a picture: add -- --shot=/absolute/path.png [--open=emblems,potions] [--pin=potion|boon|sample] [--spent] [--no-priority] [--hover=potion]

const SIDEBAR: float = 420.0
const GOLD: Color = Color("#c9a544")
const PURPLE: Color = Color("#9a63d8")
const GRAY: Color = Color("#6b7280")
## The game's green Glow, "this can be played now" (DecisionClicks.Kind.PLAY).
const GLOW: Color = Color("#7be36a")
## Behind a Potion Icon wherever it is drawn: the palette's lightest earth.
const BEIGE: Color = Color("#e6dcbd")
## The circle behind the Potion's shape, in the middle of the beige: the next earth down.
const BEIGE_DARK: Color = Color("#a8926f")
const USED: String = "#7c8492"
const COMMON_GLOW: Color = Color("#8a8f98")
const ICON: Array[String] = [
	"................", "......oooo......", "......owwo......", "......oooo......",
	"......o..o......", "......o..o......", ".....o....o.....", "....o.h....o....",
	"...o.h......o...", "...oggggggggo...", "..oggGggggggGo..", "..oggggggGgggo..",
	"..ogGggggggggo..", "...oggggggggo...", "....oooooooo....", "................"]
const INKS: Dictionary[String, Color] = {
	"o": Color("#14141a"), "w": Color("#bd9771"), "g": Color("#3f9a52"), "G": Color("#8fe08a"), "h": Color("#ffffff")}

enum Timing { HERO_MAIN, VILLAIN_TURN, NO_PRIORITY }
enum Flow { IDLE, TARGETING, ON_STACK }

## Each Emblem: name, art key ("" for the gray box), and abilities of {text, kind}, where
## kind is "static", "instant" or "sorcery" (the last two are once each game).
var _emblems: Array[Dictionary] = [
	{"name": "Sample Boon: Howling Winds", "art": "howling_mine", "abilities": [
		{"text": "At the beginning of each player's draw step, that player draws an additional card.", "kind": "static"}]},
	{"name": "Diviner's Boon", "art": "", "abilities": [
		{"text": "{2}{U}: Draw two cards. Activate only as a sorcery and only once each game.", "kind": "sorcery"}]},
	{"name": "Electromancer's Boon", "art": "", "abilities": [
		{"text": "{R}: This emblem deals 3 damage to any target. Activate only once each game.", "kind": "instant", "targets": true}]},
]
var _spent: Dictionary[String, bool] = {}
var _potion_count: int = 1
var _timing: Timing = Timing.HERO_MAIN
var _flow: Flow = Flow.IDLE
## What is being activated: "potion" or an Emblem's name; and the window to bring back.
var _activating: String = ""
var _reopen: ZoneWindow = null
var _pinned: String = ""
## For a picture only: the entry drawn as if the cursor were on it.
var hovered_key: String = ""

var _icon: ImageTexture
var _sidebar: Panel
var _emblems_button: Button
var _potions_button: Button
var _readout: Label
var _prompt: Label
var _prompt_buttons: HBoxContainer
var _emblems_window: ZoneWindow
var _potions_window: ZoneWindow
var _inspector: Panel
var _creature: Button


func _ready() -> void:
	_icon = _make_icon()
	_build()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var shot: String = ""
	for argument: String in arguments:
		if argument.begins_with("--shot="):
			shot = argument.trim_prefix("--shot=")
		elif argument.begins_with("--open="):
			_emblems_window.set_open(argument.contains("emblems"))
			_potions_window.set_open(argument.contains("potions"))
		elif argument.begins_with("--pin="):
			_pinned = {"potion": "potion", "boon": "Electromancer's Boon", "sample": "Sample Boon: Howling Winds"}[argument.trim_prefix("--pin=")]
		elif argument.begins_with("--hover="):
			hovered_key = argument.trim_prefix("--hover=")
		elif argument == "--spent":
			_spent["Electromancer's Boon"] = true
			_spent["Diviner's Boon"] = true
		elif argument == "--no-priority":
			_timing = Timing.NO_PRIORITY
	_refresh()
	if shot != "":
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and _pinned != "":
		_pinned = ""
		_refresh()


# --- building ------------------------------------------------------------------------

func _build() -> void:
	var board: ColorRect = ColorRect.new()
	board.color = Color("#2a2f3a")
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_creature = Button.new()
	_creature.text = "Grizzly Bears\n2/2\n(a creature on the board)"
	_creature.position = Vector2(1050, 620)
	_creature.size = Vector2(190, 260)
	_creature.focus_mode = Control.FOCUS_NONE
	_creature.pressed.connect(_on_creature_pressed)
	add_child(_creature)
	_prompt = _label("", 22, Color.WHITE)
	_prompt.position = Vector2(SIDEBAR + 30, 20)
	add_child(_prompt)
	_prompt_buttons = HBoxContainer.new()
	_prompt_buttons.position = Vector2(SIDEBAR + 30, 60)
	add_child(_prompt_buttons)

	_sidebar = Panel.new()
	_sidebar.position = Vector2.ZERO
	_sidebar.size = Vector2(SIDEBAR, 1080)
	add_child(_sidebar)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(16, 16)
	column.size = Vector2(SIDEBAR - 32, 1048)
	column.add_theme_constant_override("separation", 8)
	_sidebar.add_child(column)
	column.add_child(_label("PROTOTYPE: Emblems and Potions", 20, Color("#f1dc9a")))
	column.add_child(_label("The Hero's panel (mock)", 15, Color("#9aa3af")))
	_emblems_button = _panel_button(func() -> void: _toggle(_emblems_window))
	column.add_child(_emblems_button)
	_potions_button = _panel_button(func() -> void: _toggle(_potions_window))
	column.add_child(_potions_button)
	column.add_child(HSeparator.new())
	column.add_child(_label("Pretend the game is in this state:", 15, Color("#9aa3af")))
	column.add_child(_plain_button("Change timing", func() -> void:
		_timing = ((_timing + 1) % 3) as Timing
		_refresh()))
	column.add_child(_plain_button("Spend / restore both Boons", func() -> void:
		var is_spent: bool = not _spent.get("Diviner's Boon", false)
		_spent["Diviner's Boon"] = is_spent
		_spent["Electromancer's Boon"] = is_spent
		_refresh()))
	column.add_child(_plain_button("Potions held: 0 / 1 / 2", func() -> void:
		_potion_count = (_potion_count + 1) % 3
		_refresh()))
	column.add_child(_plain_button("Remove / give Howling Winds (static)", func() -> void:
		if _emblems[0]["name"].begins_with("Sample"):
			_emblems.remove_at(0)
		else:
			_emblems.insert(0, {"name": "Sample Boon: Howling Winds", "art": "howling_mine", "abilities": [
				{"text": "At the beginning of each player's draw step, that player draws an additional card.", "kind": "static"}]})
		_refresh()))
	column.add_child(HSeparator.new())
	_readout = _label("", 15, Color("#d5dbe3"))
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_readout)
	column.add_child(_label("Left-click an entry that glows to use it.\nRight-click any entry to read it in the Inspector.", 15, Color("#9aa3af")))

	_emblems_window = ZoneWindow.new("Emblems", true, GOLD)
	_emblems_window.position = Vector2(SIDEBAR + 60, 180)
	_emblems_window.size = Vector2(560, 330)
	add_child(_emblems_window)
	_emblems_window.set_open(true)
	_potions_window = ZoneWindow.new("Potions", true, PURPLE)
	_potions_window.position = Vector2(SIDEBAR + 60, 560)
	_potions_window.size = Vector2(560, 200)
	add_child(_potions_window)
	_potions_window.set_open(true)

	_inspector = Panel.new()
	_inspector.position = Vector2.ZERO
	_inspector.size = Vector2(SIDEBAR, 1080)
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color("#22262e")
	_inspector.add_theme_stylebox_override("panel", back)
	add_child(_inspector)


# --- drawing the state -----------------------------------------------------------------

func _refresh() -> void:
	var usable_emblems: int = 0
	var live_emblems: int = 0
	_emblems_window.clear()
	for emblem: Dictionary in _emblems:
		var is_usable: bool = _is_usable(emblem)
		usable_emblems += 1 if is_usable else 0
		live_emblems += 0 if _is_used_up(emblem) else 1
		_emblems_window.body().add_child(_entry(_emblem_art(emblem, Vector2(64, 64)), emblem["name"], _rules_text(emblem), GOLD,
			is_usable, func() -> void: _start(emblem["name"], emblem["abilities"][0].get("targets", false), _emblems_window), emblem["name"]))
	_emblems_window.show_title("Jackson's Emblems (%d)" % _emblems.size())
	_potions_window.clear()
	var potion_usable: bool = _potion_count > 0 and _timing != Timing.NO_PRIORITY and _flow == Flow.IDLE
	for index: int in _potion_count:
		_potions_window.body().add_child(_entry(_icon, "Big Gulp", "[color=#9aa3af]Potion · Common[/color]\nTarget creature gets +2/+2 until end of turn.",
			PURPLE, potion_usable, func() -> void: _start("potion", true, _potions_window), "potion"))
	_potions_window.show_title("Jackson's Potions (%d)" % _potion_count)

	_style_button(_emblems_button, "⛨  Emblems (%d)" % _emblems.size(), GOLD if live_emblems > 0 else GRAY, usable_emblems > 0, _emblems.is_empty())
	_style_button(_potions_button, "⚗  Potions (%d)" % _potion_count, PURPLE if _potion_count > 0 else GRAY, potion_usable, _potion_count == 0)

	var timing_words: String = ["the Hero's main phase, empty stack", "the Villain's turn, the Hero has priority", "the Hero does not have priority"][_timing]
	_readout.text = "Timing: %s\nEmblems button: %s\nPotions button: %s\nAuto-pass: %s" % [timing_words,
		"glows" if usable_emblems > 0 else ("gold" if live_emblems > 0 else "gray"),
		"glows" if potion_usable else ("purple" if _potion_count > 0 else "gray"),
		"stops here if this step has a stop" if usable_emblems > 0 or potion_usable else "passes"]

	for child: Node in _prompt_buttons.get_children():
		child.queue_free()
	var what: String = "Big Gulp" if _activating == "potion" else _activating
	match _flow:
		Flow.IDLE:
			_prompt.text = ""
		Flow.TARGETING:
			_prompt.text = "%s: choose a target. Its window closed so the board is clear." % what
			_prompt_buttons.add_child(_plain_button("Cancel (the window comes back)", _take_back))
		Flow.ON_STACK:
			_prompt.text = "%s's ability is on the stack. Its window is closed." % what
			_prompt_buttons.add_child(_plain_button("Let it resolve", _resolve))
			_prompt_buttons.add_child(_plain_button("Undo (the window comes back)", _take_back))
	_creature.disabled = _flow != Flow.TARGETING
	_refresh_inspector()


func _refresh_inspector() -> void:
	for child: Node in _inspector.get_children():
		child.queue_free()
	_inspector.visible = _pinned != ""
	if _pinned == "":
		return
	var hint: Label = _label("[Click off to close]", 12, Color("#9aa3af"))
	hint.position = Vector2(0, 4)
	hint.size = Vector2(SIDEBAR, 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspector.add_child(hint)
	if _pinned == "potion":
		_inspector.add_child(_potion_view())
		return
	for emblem: Dictionary in _emblems:
		if emblem["name"] == _pinned:
			_inspector.add_child(_emblem_face(emblem))


## A Potion in the Inspector: its icon enlarged with hard edges and a Rarity glow, then its
## name, the type line "Potion" and its rules text.
func _potion_view() -> Control:
	var view: Control = Control.new()
	var frame: Panel = Panel.new()
	frame.position = Vector2(82, 60)
	frame.size = Vector2(256, 256)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BEIGE
	style.border_color = COMMON_GLOW
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(COMMON_GLOW, 0.7)
	style.shadow_size = 14
	frame.add_theme_stylebox_override("panel", style)
	view.add_child(frame)
	frame.add_child(_disc(Rect2(16, 16, 224, 224)))
	var picture: TextureRect = TextureRect.new()
	picture.texture = _icon
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.position = Vector2(16, 16)
	picture.size = Vector2(224, 224)
	frame.add_child(picture)
	var name_label: Label = _label("Big Gulp", 30, Color.WHITE)
	name_label.add_theme_font_override("font", CardFonts.title())
	name_label.position = Vector2(16, 340)
	name_label.size = Vector2(SIDEBAR - 32, 40)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view.add_child(name_label)
	var type_line: Label = _label("Potion", 18, Color("#9aa3af"))
	type_line.position = Vector2(16, 384)
	type_line.size = Vector2(SIDEBAR - 32, 24)
	type_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view.add_child(type_line)
	var text: Label = _label("Target creature gets +2/+2 until end of turn.", 20, Color("#e4e7ee"))
	text.position = Vector2(32, 430)
	text.size = Vector2(SIDEBAR - 64, 120)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view.add_child(text)
	return view


## The graybox Emblem Face: the size of a Card Face, with a plain gray frame, the art (a
## gray box when there is none), the name, the type line "Emblem", the rules text and the
## artist's credit. No Rarity glow.
func _emblem_face(emblem: Dictionary) -> Control:
	var face: Panel = Panel.new()
	face.position = Vector2(16, 28)
	face.size = Vector2(388, 543)
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = Color("#3a3f4a")
	frame.border_color = Color("#8a8f98")
	frame.set_border_width_all(10)
	frame.set_corner_radius_all(16)
	face.add_theme_stylebox_override("panel", frame)
	var name_label: Label = _label(emblem["name"], 22, Color.WHITE)
	name_label.add_theme_font_override("font", CardFonts.title())
	name_label.position = Vector2(22, 18)
	name_label.size = Vector2(344, 30)
	name_label.clip_text = true
	face.add_child(name_label)
	var art: TextureRect = TextureRect.new()
	art.position = Vector2(22, 54)
	art.size = Vector2(344, 250)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = _emblem_art(emblem, art.size)
	face.add_child(art)
	if emblem["art"] == "":
		var none: Label = _label("(art to come)", 16, Color("#c3c9d6"))
		none.position = art.position
		none.size = art.size
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		face.add_child(none)
	var type_line: Label = _label("Emblem", 18, Color("#e4e7ee"))
	type_line.position = Vector2(22, 310)
	face.add_child(type_line)
	var box: Panel = Panel.new()
	box.position = Vector2(22, 340)
	box.size = Vector2(344, 160)
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color("#d9dce3")
	box_style.set_corner_radius_all(4)
	box.add_theme_stylebox_override("panel", box_style)
	face.add_child(box)
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = "[color=#14141a]%s[/color]" % _rules_text(emblem)
	text.position = Vector2(8, 6)
	text.size = Vector2(328, 148)
	text.add_theme_font_size_override("normal_font_size", 17)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text)
	if emblem["art"] != "":
		var credit: Label = _label("Illus. %s" % ArtLibrary.shared().entries.get(emblem["art"], {}).get("artist", "?"), 12, Color("#c3c9d6"))
		credit.position = Vector2(22, 506)
		face.add_child(credit)
	return face


# --- the made-up rules -------------------------------------------------------------------

func _is_usable(emblem: Dictionary) -> bool:
	if _flow != Flow.IDLE or _spent.get(emblem["name"], false):
		return false
	var kind: String = emblem["abilities"][0]["kind"]
	return (kind == "instant" and _timing != Timing.NO_PRIORITY) or (kind == "sorcery" and _timing == Timing.HERO_MAIN)


## An Emblem with a static or triggered ability, or an activated one not yet spent, is
## never used up.
func _is_used_up(emblem: Dictionary) -> bool:
	return emblem["abilities"][0]["kind"] != "static" and _spent.get(emblem["name"], false)


func _rules_text(emblem: Dictionary) -> String:
	var text: String = emblem["abilities"][0]["text"]
	return "[color=%s]%s (used)[/color]" % [USED, text] if _spent.get(emblem["name"], false) else text


func _start(what: String, has_target: bool, window: ZoneWindow) -> void:
	_activating = what
	_reopen = window
	window.close()
	_flow = Flow.TARGETING
	if not has_target:
		_put_on_stack()
	_refresh()


func _on_creature_pressed() -> void:
	_put_on_stack()
	_refresh()


## The costs are paid as it goes on the stack: the Potion is gone and the ability Spent.
func _put_on_stack() -> void:
	_flow = Flow.ON_STACK
	if _activating == "potion":
		_potion_count -= 1
	else:
		_spent[_activating] = true


func _take_back() -> void:
	if _flow == Flow.ON_STACK:
		if _activating == "potion":
			_potion_count += 1
		else:
			_spent[_activating] = false
	_flow = Flow.IDLE
	_reopen.open()
	_refresh()


func _resolve() -> void:
	_flow = Flow.IDLE
	_refresh()


func _toggle(window: ZoneWindow) -> void:
	window.set_open(not window.is_open())


# --- small parts -----------------------------------------------------------------------

## One entry of a window, drawn like a ZoneEntry: a picture, a name and a line under it.
func _entry(picture: Texture2D, entry_name: String, detail: String, tint: Color, glows: bool, on_use: Callable, pin_key: String) -> Control:
	var entry: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#2c323c")
	style.border_color = GLOW if glows else tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(5)
	if glows:
		style.shadow_color = Color(GLOW, 0.6)
		style.shadow_size = 8
	entry.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(row)
	var art: TextureRect = TextureRect.new()
	art.texture = picture
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if picture == _icon else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	art.custom_minimum_size = Vector2(64, 64)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picture == _icon:
		var backing: ColorRect = ColorRect.new()
		backing.color = BEIGE
		backing.custom_minimum_size = Vector2(64, 64)
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(backing)
		# The small art: one art pixel (4 px here) wider all round than in the Inspector and
		# one lower, cut off by the beige box.
		backing.clip_contents = true
		backing.add_child(_disc(Rect2(0, 0, 64, 64), 1, 1))
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		backing.add_child(art)
	else:
		row.add_child(art)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)
	var name_label: Label = _label(entry_name, 20, Color.WHITE)
	name_label.add_theme_font_override("font", CardFonts.title())
	lines.add_child(name_label)
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.text = detail
	text.add_theme_font_size_override("normal_font_size", 15)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(text)
	if glows:
		# As a card in hand does under the cursor (ClickCatcher): brighter, with the hand.
		entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		entry.mouse_entered.connect(func() -> void: entry.modulate = ClickCatcher.BRIGHT)
		entry.mouse_exited.connect(func() -> void: entry.modulate = Color.WHITE)
		if hovered_key == pin_key:
			entry.modulate = ClickCatcher.BRIGHT
	entry.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click == null or not click.pressed:
			return
		if click.button_index == MOUSE_BUTTON_RIGHT:
			_pinned = "" if _pinned == pin_key else pin_key
			_refresh()
			accept_event()
		elif click.button_index == MOUSE_BUTTON_LEFT and glows:
			on_use.call()
			accept_event())
	return entry


func _emblem_art(emblem: Dictionary, wanted: Vector2) -> Texture2D:
	if emblem["art"] != "":
		return ArtLibrary.shared().cropped(emblem["art"], wanted)
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("#6b7280"))
	return ImageTexture.create_from_image(image)


## The darker circle behind a Potion Icon, drawn in the icon's own pixels so its edge steps
## as the icon's does. [param rect] is where the 16 x 16 icon itself is drawn, [param grow]
## how many art pixels wider than the icon's grid the circle is all round, and
## [param down] how many art pixels lower than the middle it sits.
func _disc(rect: Rect2, grow: int = 0, down: int = 0) -> TextureRect:
	var cells: int = 16 + 2 * grow
	var middle: float = (cells - 1) / 2.0
	var image: Image = Image.create(cells, cells, false, Image.FORMAT_RGBA8)
	for y: int in cells:
		for x: int in cells:
			if Vector2(x - middle, y - middle).length() <= cells / 2.0:
				image.set_pixel(x, y, BEIGE_DARK)
	var art_pixel: float = rect.size.x / 16.0
	var disc: TextureRect = TextureRect.new()
	disc.texture = ImageTexture.create_from_image(image)
	disc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.position = rect.position + Vector2(-grow, down - grow) * art_pixel
	disc.size = Vector2(cells, cells) * art_pixel
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc


func _make_icon() -> ImageTexture:
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y: int in 16:
		for x: int in 16:
			image.set_pixel(x, y, INKS.get(ICON[y][x], Color(0, 0, 0, 0)))
	return ImageTexture.create_from_image(image)


func _panel_button(on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(on_press)
	return button


func _plain_button(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	return button


## The three looks of a panel button: glowing, its own color, or gray.
func _style_button(button: Button, text: String, tint: Color, glows: bool, is_empty: bool) -> void:
	button.text = text
	button.disabled = is_empty
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		# Opaque, the color the see-through tint gives over the sidebar, so that the Glow
		# drawn behind the button does not show through and tint it.
		style.bg_color = Color("#1e2026").lerp(tint, 0.45 if state == "hover" else 0.25)
		style.border_color = GLOW if glows else tint
		style.set_border_width_all(2 if glows else 1)
		style.set_corner_radius_all(5)
		if glows:
			style.shadow_color = Color(GLOW, 0.6)
			style.shadow_size = 8
		button.add_theme_stylebox_override(state, style)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
