class_name DeckboxScreen
extends Control
## The Deckbox: the run's saved Decks, the Active Deck marked with a star, and the only door
## to the deckbuilder (ADR 0037). A click selects a Deck; Edit Deck, Duplicate Deck, Set
## Active and Delete Deck then act on it, and New Deck is always there. Before an encounter
## the Villain is shown and Start, disabled while the Active Deck is illegal, plays it;
## opened from the map it has Close, which checks nothing, and its title is centered.
## Signed off as the prototype in prototypes/deckbox (milestone 16).

const ENCOUNTER: String = "res://ui/encounter/encounter_screen.tscn"
const DECKBUILDER: String = RunFlow.DECKBUILDER
const SELECTION_BUTTONS: Array[String] = ["Edit Deck", "Duplicate Deck", "Set Active", "Delete Deck"]
const STAR: String = "res://ui/sprites/deckbox/active_star.png"
const VILLAIN_PORTRAIT: String = "res://ui/sprites/portraits/purple_demon.png"
## Pixel art is drawn at a whole multiple of its size.
const STAR_SCALE: int = 2
const PORTRAIT_SIZE: int = 64

## The outside panel is slate; the list inside it dark gray, with sienna rows on it.
const SLATE: Color = Color("#2a2f37")
const SLATE_BORDER: Color = Color("#14171c")
const LIST: Color = Color("#1c1d20")
const ROW: Color = Color("#452212")
const ROW_BORDER: Color = Color("#1f0e07")
const COUNT_PLATE: Color = DeckbuilderLook.BAR_PANEL
const ILLEGAL: Color = Color("#e5484d")
## How much a Deck's row or a button lightens under the cursor.
const HOVER_LIGHTEN: float = 0.10

const PANE_SIZE: Vector2 = Vector2(1040, 920)
const PANE_RADIUS: int = 16
const ROW_HEIGHT: int = 72
const BUTTON_HEIGHT: int = 42
const SCROLLBAR_WIDTH: int = 12
const SCROLLBAR_GAP: int = 6
const PIP_SIZE: int = 22
## The pip image for each color, as ManaSymbols names them.
const PIPS: Dictionary[MmCardTypes.CardColor, String] = {
	MmCardTypes.CardColor.WHITE: "w", MmCardTypes.CardColor.BLUE: "u", MmCardTypes.CardColor.BLACK: "b",
	MmCardTypes.CardColor.RED: "r", MmCardTypes.CardColor.GREEN: "g",
}

## Whether the screen reads the run from RunFlow when it is ready. Tests hand it one.
var starts_itself: bool = true
## How the screen opens another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: SceneFade.change_scene(get_tree(), scene)

var _run: Run = null
var _villain: String = ""
var _selected: Deck = null
var _title: Label
var _list: VBoxContainer
var _rows: Array[PanelContainer] = []
var _buttons: Dictionary[String, Button] = {}
var _confirm: Control = null
var _confirm_question: Label = null
var _confirm_text: Label = null
var _confirm_buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	theme = DeckbuilderLook.theme()
	if not starts_itself:
		return
	# Opened on its own (godot --path . res://ui/deckbox/deckbox_screen.tscn), it begins a
	# debug run; --screenshot=/absolute/path.png saves a picture and quits.
	if RunFlow.run == null:
		RunFlow.start(Run.debug(1))
	begin(RunFlow.run, RunFlow.villain)
	var picture: String = EncounterScreen.screenshot_path(OS.get_cmdline_user_args())
	if picture != "":
		for frame: int in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## Opens on [param run]'s Decks. [param villain] is the deck name of the Villain the
## encounter is against, or "" when the Deckbox is opened from the map.
func begin(run: Run, villain: String) -> void:
	_run = run
	_villain = villain
	_build()
	_refresh()


func selected() -> Deck:
	return _selected


func button(text: String) -> Button:
	return _buttons.get(text, null) as Button


func villain_shown() -> String:
	return _villain


func title_alignment() -> HorizontalAlignment:
	return _title.horizontal_alignment


func row_names() -> Array[String]:
	var names: Array[String] = []
	for deck: Deck in _run.deckbox.decks():
		names.append(deck.name)
	return names


func row_rect(index: int) -> Rect2:
	return _rows[index].get_global_rect()


func row_has_star(index: int) -> bool:
	return (_rows[index].get_meta("star") as TextureRect).texture != null


func row_count_text(index: int) -> String:
	return (_rows[index].get_meta("count") as Label).text


func is_row_count_red(index: int) -> bool:
	return (_rows[index].get_meta("count") as Label).get_theme_color("font_color") == ILLEGAL


func row_pips(index: int) -> Array[String]:
	var pips: Array[String] = []
	pips.assign(_rows[index].get_meta("pips"))
	return pips


## Selects the Deck in row [param index], as a click on it does; a click on the Deck
## already selected lets it go.
func click_row(index: int) -> void:
	var deck: Deck = _run.deckbox.decks()[index]
	_selected = null if deck == _selected else deck
	_refresh()


## Lightens row [param index] while the cursor is over it, and puts it back after.
func hover_row(index: int, is_over: bool) -> void:
	if index >= _rows.size():
		return
	var row: PanelContainer = _rows[index]
	if row.is_queued_for_deletion() or not row.is_inside_tree():
		return
	row.add_theme_stylebox_override("panel", _row_plate(row.get_meta("deck") as Deck, is_over))


## Lights the row the cursor is on once new rows are laid out: a row made under a still
## cursor hears of no entering until it moves.
func _light_row_under_cursor() -> void:
	if not is_inside_tree() or _confirm != null:
		return
	var cursor: Vector2 = get_global_mouse_position()
	for index: int in _rows.size():
		if _rows[index].get_global_rect().has_point(cursor):
			hover_row(index, true)


func row_plate(index: int) -> StyleBox:
	return _rows[index].get_theme_stylebox("panel")


## The top tone of a Deck's row, lit while the cursor is over it.
static func row_top(is_lit: bool) -> Color:
	var top: Color = ROW.lightened(0.12)
	return top.lightened(HOVER_LIGHTEN) if is_lit else top


static func _row_bottom(is_lit: bool) -> Color:
	var bottom: Color = ROW.darkened(0.3)
	return bottom.lightened(HOVER_LIGHTEN) if is_lit else bottom


func is_confirming_delete() -> bool:
	return _confirm != null


## What the delete confirmation says: its question, then what follows from it.
func confirm_text() -> String:
	return "%s\n%s" % [_confirm_question.text, _confirm_text.text] if _confirm != null else ""


func confirm_button(text: String) -> Button:
	return _confirm_buttons.get(text, null) as Button


func _build() -> void:
	var bench: ColorRect = ColorRect.new()
	bench.color = DeckbuilderLook.BENCH
	bench.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bench)

	var pane: PanelContainer = PanelContainer.new()
	var face: StyleBoxTexture = DitherShading.plate(SLATE.lightened(0.06), SLATE.darkened(0.3), SLATE_BORDER,
			PANE_RADIUS, 2, 0, int(PANE_SIZE.y))
	face.set_content_margin_all(32)
	pane.add_theme_stylebox_override("panel", face)
	pane.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pane.position = (Vector2(1920, 1080) - PANE_SIZE) / 2.0
	pane.size = PANE_SIZE
	add_child(pane)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	pane.add_child(column)
	column.add_child(_heading())
	column.add_child(_list_well())
	column.add_child(_button_bar())


func _heading() -> Control:
	var heading: HBoxContainer = HBoxContainer.new()
	_title = Label.new()
	_title.text = "Deckbox"
	_title.add_theme_font_override("font", DeckbuilderLook.bold())
	_title.add_theme_font_size_override("font_size", 40)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_title)
	if _villain == "":
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		heading.add_child(_villain_strip())
	return heading


## "vs." over the Villain's name, beside their Portrait in a rounded frame.
func _villain_strip() -> Control:
	var strip: HBoxContainer = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 16)
	var words: VBoxContainer = VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var versus: Label = Label.new()
	versus.text = "vs."
	versus.add_theme_color_override("font_color", DeckbuilderLook.MUTED)
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	words.add_child(versus)
	var villain_name: Label = Label.new()
	villain_name.text = _villain_title()
	villain_name.add_theme_font_override("font", DeckbuilderLook.bold())
	villain_name.add_theme_font_size_override("font_size", 24)
	villain_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	words.add_child(villain_name)
	strip.add_child(words)
	var frame: PanelContainer = PanelContainer.new()
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = LIST
	back.border_color = DeckbuilderLook.PANEL_EDGE
	back.set_border_width_all(DeckbuilderLook.PANEL_EDGE_WIDTH)
	back.set_corner_radius_all(8)
	back.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", back)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = load(VILLAIN_PORTRAIT) as Texture2D
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	frame.add_child(portrait)
	strip.add_child(frame)
	return strip


## The Villain's deck name as a title: "white_black" reads "White-Black Villain".
func _villain_title() -> String:
	var words: PackedStringArray = []
	for word: String in _villain.split("_"):
		words.append(word.capitalize())
	return "%s Villain" % "-".join(words)


func _list_well() -> Control:
	var well: PanelContainer = PanelContainer.new()
	var hollow: StyleBoxFlat = StyleBoxFlat.new()
	hollow.bg_color = LIST
	hollow.border_color = DeckbuilderLook.PANEL_EDGE
	hollow.set_border_width_all(DeckbuilderLook.PANEL_EDGE_WIDTH)
	hollow.set_corner_radius_all(6)
	hollow.set_content_margin_all(12)
	well.add_theme_stylebox_override("panel", hollow)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The scrollbar's room is kept whether it shows or not, so rows never change width.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	_style_scrollbar(scroll.get_v_scroll_bar())
	well.add_child(scroll)
	var gap: MarginContainer = MarginContainer.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.add_theme_constant_override("margin_right", SCROLLBAR_GAP)
	scroll.add_child(gap)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	gap.add_child(_list)
	return well


## A dark track and a gray grabber that lightens under the cursor and while held. The room
## kept for the bar is read from its track, so the track carries the width.
func _style_scrollbar(bar: VScrollBar) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = DeckbuilderLook.HOLLOW
	track.set_corner_radius_all(5)
	track.content_margin_left = SCROLLBAR_WIDTH / 2.0
	track.content_margin_right = SCROLLBAR_WIDTH / 2.0
	bar.custom_minimum_size = Vector2(SCROLLBAR_WIDTH, 0)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	var states: Dictionary[String, Color] = {
		"grabber": DeckbuilderLook.BUTTON,
		"grabber_highlight": DeckbuilderLook.BUTTON_HOVER,
		"grabber_pressed": DeckbuilderLook.BUTTON_HOVER.lightened(0.1),
	}
	for state: String in states:
		var grabber: StyleBoxFlat = StyleBoxFlat.new()
		grabber.bg_color = states[state]
		grabber.border_color = states[state].darkened(0.45)
		grabber.set_border_width_all(1)
		grabber.set_corner_radius_all(5)
		bar.add_theme_stylebox_override(state, grabber)


func _button_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	_add_button(bar, "New Deck", _new_deck)
	for text: String in SELECTION_BUTTONS:
		_add_button(bar, text, _on_selection_button.bind(text))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var finish: Button = _add_button(bar, "Close" if _villain == "" else "Start", _close if _villain == "" else _start)
	finish.custom_minimum_size = Vector2(140, 0)
	return bar


func _add_button(parent: Control, text: String, on_press: Callable) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fill: Color = DeckbuilderLook.BUTTON
	made.add_theme_stylebox_override("normal", DitherShading.button_plate(fill, false, BUTTON_HEIGHT))
	made.add_theme_stylebox_override("hover", DitherShading.button_plate(fill.lightened(HOVER_LIGHTEN), false, BUTTON_HEIGHT))
	made.add_theme_stylebox_override("pressed", DitherShading.button_plate(fill, true, BUTTON_HEIGHT))
	made.add_theme_stylebox_override("hover_pressed", DitherShading.button_plate(fill, true, BUTTON_HEIGHT))
	made.add_theme_stylebox_override("disabled", DitherShading.disabled_plate(DeckbuilderLook.BUTTON_DISABLED, BUTTON_HEIGHT))
	made.pressed.connect(on_press)
	parent.add_child(made)
	_buttons[text] = made
	return made


func _refresh() -> void:
	for row: PanelContainer in _rows:
		row.queue_free()
	_rows.clear()
	var decks: Array[Deck] = _run.deckbox.decks()
	if not decks.has(_selected):
		_selected = null
	for index: int in decks.size():
		var row: PanelContainer = _row(decks[index], index)
		_list.add_child(row)
		_rows.append(row)
	_light_row_under_cursor.call_deferred()
	var has_selection: bool = _selected != null
	for text: String in SELECTION_BUTTONS:
		_buttons[text].disabled = not has_selection
	if has_selection:
		_buttons["Set Active"].disabled = _run.deckbox.is_active(_selected)
	if _buttons.has("Start"):
		var active: Deck = _run.deckbox.active()
		_buttons["Start"].disabled = active == null or not _run.deckbox.is_legal(active)


func _row(deck: Deck, index: int) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.set_meta("deck", deck)
	row.add_theme_stylebox_override("panel", _row_plate(deck, false))
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_input.bind(index))
	row.mouse_entered.connect(hover_row.bind(index, true))
	row.mouse_exited.connect(hover_row.bind(index, false))

	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var star: TextureRect = TextureRect.new()
	star.texture = load(STAR) as Texture2D if _run.deckbox.is_active(deck) else null
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(16 * STAR_SCALE, 16 * STAR_SCALE)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(star)
	row.set_meta("star", star)
	var name_label: Label = Label.new()
	name_label.text = deck.name
	name_label.add_theme_font_override("font", DeckbuilderLook.bold())
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	line.add_child(name_label)
	line.add_child(_tally(deck, row))
	return row


## A row's Dither-Shaded face: brass-edged when its Deck is selected, lightened when
## [param is_lit].
func _row_plate(deck: Deck, is_lit: bool) -> StyleBoxTexture:
	var is_selected: bool = deck == _selected
	var face: StyleBoxTexture = DitherShading.plate(row_top(is_lit), _row_bottom(is_lit),
			DeckbuilderLook.BRASS if is_selected else ROW_BORDER, 6, 3 if is_selected else 1, 0, ROW_HEIGHT)
	face.content_margin_left = 16
	face.content_margin_right = 20
	return face


## The Deck's colors as pips, then its card count, red under the legal size, on a shaded
## gray plate.
func _tally(deck: Deck, row: PanelContainer) -> Control:
	var plate: PanelContainer = PanelContainer.new()
	var face: StyleBoxFlat = StyleBoxFlat.new()
	face.bg_color = COUNT_PLATE
	face.set_corner_radius_all(5)
	DeckbuilderLook.shade(face, 3)
	face.content_margin_left = 10
	face.content_margin_right = 12
	face.content_margin_top = 4
	face.content_margin_bottom = 6
	plate.add_theme_stylebox_override("panel", face)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(line)
	var pips: Array[String] = []
	for color: MmCardTypes.CardColor in _run.deckbox.colors_of(deck, _run.collection):
		var pip: TextureRect = TextureRect.new()
		pip.texture = ManaSymbols.texture(PIPS[color])
		pip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pip.custom_minimum_size = Vector2(PIP_SIZE, PIP_SIZE)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(pip)
		pips.append(PIPS[color])
	row.set_meta("pips", pips)
	var count: Label = Label.new()
	count.text = "%d cards" % deck.size()
	count.add_theme_color_override("font_color", DeckbuilderLook.TEXT if _run.deckbox.is_legal(deck) else ILLEGAL)
	count.custom_minimum_size = Vector2(84, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(count)
	row.set_meta("count", count)
	return plate


func _on_row_input(event: InputEvent, index: int) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		click_row(index)


func _new_deck() -> void:
	navigate.call(RunFlow.edit(null))


func _on_selection_button(text: String) -> void:
	match text:
		"Edit Deck":
			navigate.call(RunFlow.edit(_selected))
		"Duplicate Deck":
			_selected = _run.deckbox.duplicate_deck(_selected)
			_refresh()
		"Set Active":
			_run.deckbox.set_active(_selected)
			_refresh()
		"Delete Deck":
			_ask_delete()


func _start() -> void:
	EncounterScreen.request = _run.encounter_request(_villain)
	navigate.call(ENCOUNTER)


func _close() -> void:
	navigate.call(RunFlow.back_from_deckbox)


## The confirmation before a Deck is deleted, in the list's dark gray with its gray edge.
func _ask_delete() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confirm)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0, 0, 0, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(veil)
	var box: PanelContainer = PanelContainer.new()
	var face: StyleBoxFlat = StyleBoxFlat.new()
	face.bg_color = LIST
	face.border_color = DeckbuilderLook.PANEL_EDGE
	face.set_border_width_all(DeckbuilderLook.PANEL_EDGE_WIDTH)
	face.set_corner_radius_all(8)
	face.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", face)
	_confirm.add_child(box)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	box.add_child(column)
	_confirm_question = Label.new()
	_confirm_question.text = "Delete \"%s\"?" % _selected.name
	_confirm_question.add_theme_font_override("font", DeckbuilderLook.bold())
	_confirm_question.add_theme_font_size_override("font_size", 24)
	_confirm_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_confirm_question)
	_confirm_text = Label.new()
	_confirm_text.text = "Its cards stay in your Collection."
	if _run.deckbox.is_active(_selected):
		_confirm_text.text += "\nIt is your Active Deck, so you will have none."
	_confirm_text.add_theme_color_override("font_color", DeckbuilderLook.MUTED)
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_confirm_text)
	var answers: HBoxContainer = HBoxContainer.new()
	answers.alignment = BoxContainer.ALIGNMENT_CENTER
	answers.add_theme_constant_override("separation", 16)
	column.add_child(answers)
	_confirm_buttons.clear()
	var keep: Dictionary[String, Button] = _buttons
	_buttons = {}
	_confirm_buttons["Delete Deck"] = _add_button(answers, "Delete Deck", _delete_selected)
	_confirm_buttons["Cancel"] = _add_button(answers, "Cancel", _close_confirm)
	_buttons = keep
	box.reset_size()
	box.position = (Vector2(1920, 1080) - box.get_combined_minimum_size()) / 2.0


func _delete_selected() -> void:
	_run.deckbox.delete(_selected)
	_selected = null
	_close_confirm()
	_refresh()


func _close_confirm() -> void:
	_confirm.queue_free()
	_confirm = null
	_confirm_question = null
	_confirm_text = null
	_confirm_buttons.clear()
