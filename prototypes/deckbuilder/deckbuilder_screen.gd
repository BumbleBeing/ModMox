class_name DeckbuilderScreen
extends Control
## The deckbuilder: the Collection, the Working Deck in its eight columns, an inspector and
## a top bar. It only draws what the Working Deck and the Collection Filter say and places
## it where the DeckbuilderLayout works out.
##
## A left press picks a card up once the cursor has moved a little: dropped on a column it
## is added or moved there, at the place in the pile the cursor is over, and a Deck card
## dropped anywhere else is removed. The piles are free: nothing sorts them but the Sort
## button. A double-click
## adds a Collection card to its own column or takes a card out of the Deck. Nothing is
## rebuilt for any of this: faces are kept and moved.
##
## The inspector and the windows ease as the encounter's do (Easing, Pacing.EASE_SECONDS): a
## change of card eases the old one out and the new one in, and the Mod pop-up and the
## unsaved-changes prompt fade in and out.
##
## Movement is eased, never snapped: a held card glides to the cursor and, dropped on a
## column, on to its place there, the cards of a column slide to make room, the card under
## the cursor gains a glowing border, and the column a held card would drop into lights up.
##
## A right-click selects a card, which holds it in the inspector; a second right-click on
## it, one on empty space, or Escape lets it go. While a card is selected the inspector
## shows only that card; with none selected it shows the card under the cursor. Every card shows its Mod Slots on its face,
## a basic land too.
##
## Apply a Mod, in the inspector, opens the Mod pop-up over the screen for the selected
## card. A Mod applied there is used up and changes the card at once, wherever it shows; it
## has nothing to do with saving. A basic land's first Mod makes it a card of the
## Collection's, which then shows in the Collection too (A558).
##
## The name box renames the Working Deck. Save writes it to the Deckbox, legal or not, and
## stays on the screen; it refuses only a name that is empty or taken. Exit goes back to
## the main menu, asking first if there are unsaved changes.
##
## Steps 2 to 8 of the prototype.
## Add --screenshot=/absolute/path.png to save a picture and quit, and --select="Card Name"
## to have that Deck card selected in it, with --mods to open the Mod pop-up for it.

const BACKGROUND: Color = DeckbuilderLook.BENCH
const PANE: Color = DeckbuilderLook.PANE
const PANE_BORDER: Color = DeckbuilderLook.PANE_BORDER
const MUTED: Color = DeckbuilderLook.MUTED
const ILLEGAL: Color = Color("#e5484d")
## A Collection card that is already in the Deck is drawn this faint.
const IN_DECK_DIM: float = 0.5
## The face a held card was lifted from is drawn this faint until it is put down.
const LIFTED_DIM: float = 0.25
## How far the cursor must move with the button down before a card is picked up.
const DRAG_START: float = 6.0
const DROP_BORDER: Color = Color("#e8cf8a")
## The glowing border of the card under the cursor.
const HOVER_GLOW: Color = Color("#ffe9a8")
## How quickly a held card closes on the cursor, and a glow or a column border fades in or
## out: the share of the distance left that is covered each second, as an exponent.
const CARRY_RATE: float = 22.0
const GLOW_RATE: float = 14.0
## The border of the selected card.
const SELECTED_RING: Color = Color("#7fd4ff")
const MENU: String = "res://ui/menu/main_menu.tscn"
## The answers the unsaved-changes prompt offers, in order.
enum ExitAnswer { SAVE_AND_EXIT, EXIT_WITHOUT_SAVING, KEEP_BUILDING }
## How long a notice shows, and how long it takes to fade at the end, in seconds.
const NOTICE_TIME: float = 3.0
const NOTICE_FADE: float = 0.5
## The deckbuilder eases half again as slowly as the encounter does.
const EASE_STRETCH: float = 1.5
## How solid the white plate behind a basic land button's name and count is.
const LAND_PLATE_ALPHA: float = 0.25
const COLUMN_TITLES: Array[String] = ["0", "1", "2", "3", "4", "5", "6+", "Lands"]
## Each basic land's button color, in the order the buttons stand. The Plains' is dark
## enough for the white plate behind its name to show on it.
const LAND_COLORS: Dictionary[String, Color] = {
	"Plains": Color("#b3a97c"), "Island": Color("#2f6fb5"), "Swamp": Color("#544a5e"),
	"Mountain": Color("#b8452f"), "Forest": Color("#2f7d4a"),
}

## Whether the deckbuilder has been left for the main menu in this run of the game. The
## menu's --deckbuilder shortcut works only until then, so that Exit does not bounce back.
static var has_left: bool = false

## How long the inspector takes to change cards and a window to ease in or out, in seconds:
## the encounter's Pacing.EASE_SECONDS, stretched, when the screen starts itself, and none in tests and
## pictures, where everything comes and goes at once (as Easing has it).
var ease_seconds: float = 0.0
## Whether the screen makes its own sample run when it is ready. Tests hand it one.
var starts_itself: bool = true
## How the screen opens another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void:
	DeckbuilderScreen.has_left = true
	get_tree().change_scene_to_file(scene)

var _sample: DeckbuilderSample = null
var _working_deck: WorkingDeck = null
var _filter: CollectionFilter = CollectionFilter.new()
## The card a right-click selected, or null.
var _selected: DeckbuilderCard = null
## The card under the cursor, or null.
var _hovered_card: DeckbuilderCard = null
## The inspector's pane, the card it is showing (or null), and what that card's Mod Slots
## held when it was drawn, so it is redrawn only when one of them changes.
var _inspector_pane: Panel = null
var _inspector_shown: DeckbuilderCard = null
var _inspector_slots: int = -1
var _inspector: DeckbuilderInspector = null
## The Mod pop-up while it is open, or null.
var _mod_popup: ModPopup = null
var _save_button: Button = null
var _exit_button: Button = null
## The unsaved-changes prompt while it is open, or null.
var _exit_prompt: ChoicePrompt = null
## The line that says what Save just did, and how long it has left to show.
var _notice: Label = null
var _notice_left: float = 0.0
var _root: Control = null
var _column_faces: Dictionary[int, CardFace] = {}
var _column_panes: Array[Panel] = []
var _column_scrolls: Array[ScrollContainer] = []
var _column_fans: Array[Control] = []
var _column_counts: Array[Label] = []
var _land_buttons: Dictionary[String, Button] = {}
var _sort_button: Button = null
var _zoom_slider: HSlider = null
## The gray plate Zoom and the two sliders stand on.
var _zoom_panel: PanelContainer = null
var _deck_zoom_slider: HSlider = null
## How large the columns' cards are drawn, and the zoom their faces were last built at.
var _deck_zoom: float = 1.0
var _deck_built_zoom: float = 1.0
var _deck_scroll: ScrollContainer = null
var _land_counts: Dictionary[String, Label] = {}
## How tall a Collection card is drawn, set by the zoom slider.
var _collection_card_height: float = DeckbuilderLayout.COLLECTION_CARD_HEIGHT
## The height the Collection faces were last built at. While the slider is being dragged
## they are only scaled from it; they are rebuilt sharp when it is let go.
var _collection_built_height: float = DeckbuilderLayout.COLLECTION_CARD_HEIGHT
## The card under a left press that has not been released, and where it was pressed.
var _pressed: DeckbuilderCard = null
var _press_point: Vector2 = Vector2.ZERO
## The face following the cursor while a card is held, or null.
var _held: CardFace = null
## Where the held face is gliding to: its top left when centered on the cursor.
var _held_target: Vector2 = Vector2.ZERO
## The face under the cursor, or null, and every face whose glow is showing or fading.
var _hovered: CardFace = null
var _glowing: Array[CardFace] = []
## Where each Deck card's face is easing to inside its column's fan, by card id.
var _fan_places: Dictionary[int, Vector2] = {}
## The faces gliding from where a card was dropped to its place in a column, by card id.
## The card's own face in the column is unseen until its flyer lands.
var _flyers: Dictionary[int, CardFace] = {}
## How lit each column's border is, from 0 to 1.
var _column_lit: Array[float] = []
## The column the held card would drop into, or NO_COLUMN.
var _drop_column: int = WorkingDeck.NO_COLUMN
## The place in that column it would drop to: above the card now at this place.
var _drop_place: int = 0
var _collection_faces: Dictionary[int, CardFace] = {}
var _count_label: Label = null
var _name_box: LineEdit = null
var _filter_bar: FilterBar = null
var _collection_scroll: ScrollContainer = null
var _collection_grid: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = DeckbuilderLook.theme()
	resized.connect(_redraw)
	if not starts_itself:
		return
	begin(DeckbuilderSample.make())
	_select_named(OS.get_cmdline_user_args())
	var picture: String = EncounterScreen.screenshot_path(OS.get_cmdline_user_args())
	if picture == "":
		ease_seconds = Pacing.EASE_SECONDS * EASE_STRETCH
	if picture != "":
		for frame: int in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## Selects the Deck card named by --select= among [param arguments], if there is one, so
## that a picture can show the inspector at work.
func _select_named(arguments: PackedStringArray) -> void:
	for argument: String in arguments:
		if not argument.begins_with("--select="):
			continue
		for card: DeckbuilderCard in _working_deck.cards():
			if card.look().name == argument.trim_prefix("--select="):
				_selected = card
				_show_selection()
				_show_inspector()
				if arguments.has("--mods"):
					open_mod_popup()
				return


## Opens the deckbuilder on [param sample]'s saved Deck.
func begin(sample: DeckbuilderSample) -> void:
	_sample = sample
	_working_deck = sample.working_deck()
	_selected = null
	_make_basic_lands_ready()
	_redraw()


## Draws each basic land once and throws the face away, so that its frame and art are
## already made when the first one is added: baking a frame takes a fifth of a second.
func _make_basic_lands_ready() -> void:
	for land: MmCardDefinition in _sample.basic_lands:
		var face: CardFace = CardFace.new()
		face.setup(CardLook.of_characteristics(MmCharacteristics.printed(land), land.resource_path.get_file().get_basename()), 100.0)
		face.free()


func layout() -> DeckbuilderLayout:
	var places: DeckbuilderLayout = DeckbuilderLayout.new(size)
	places.collection_card_height = _collection_card_height
	places.deck_zoom = _deck_zoom
	return places


## The face of a card in the columns, or null if it is not in the Deck.
func column_face(card: DeckbuilderCard) -> CardFace:
	return _column_faces.get(card.id, null) as CardFace


## The face of a card in the Collection pane, or null if it is filtered out.
func collection_face(card: DeckbuilderCard) -> CardFace:
	var face: CardFace = _collection_faces.get(card.id, null) as CardFace
	return null if face != null and not face.visible else face


func working_deck() -> WorkingDeck:
	return _working_deck


## The face following the cursor while a card is held, or null.
func held_face() -> CardFace:
	return _held


## The button that adds the basic land named [param land].
func land_button(land: String) -> Button:
	return _land_buttons.get(land, null) as Button


func sort_button() -> Button:
	return _sort_button


## The card a right-click selected, or null.
func selected() -> DeckbuilderCard:
	return _selected


## The card the inspector is showing: the selected one, or with none selected the one
## under the cursor. A selected card holds the inspector, whatever the cursor is over.
func inspected() -> DeckbuilderCard:
	return _selected if _selected != null else _hovered_card


func inspector() -> DeckbuilderInspector:
	return _inspector


## The Card Face in the inspector, or null when it shows no card.
func inspector_face() -> CardFace:
	return _inspector.face()


## The inspector's Apply a Mod button, or null when it shows no card.
func apply_mod_button() -> Button:
	return _inspector.apply_button() if inspected() != null else null


## The Mod pop-up while it is open, or null.
func mod_popup() -> ModPopup:
	return _mod_popup


func save_button() -> Button:
	return _save_button


func exit_button() -> Button:
	return _exit_button


## The unsaved-changes prompt while it is open, or null.
func exit_prompt() -> ChoicePrompt:
	return _exit_prompt


## What the notice under the top bar says, or "" when none is showing.
func notice() -> String:
	return _notice.text if _notice != null and _notice.visible else ""


## Writes the Working Deck to the Deckbox and says so, or says why it was refused. True if
## it was saved.
func save() -> bool:
	var refusal: String = _working_deck.save()
	if refusal != "":
		_show_notice(refusal, true)
		return false
	_name_box.text = _working_deck.name
	_show_notice("Saved to the Deckbox.", false)
	_show_save()
	return true


## Leaves for the main menu, asking first if there are unsaved changes.
func exit() -> void:
	if _exit_prompt != null:
		return
	if not _working_deck.has_unsaved_changes():
		navigate.call(MENU)
		return
	close_mod_popup()
	_put_down()
	_exit_prompt = ChoicePrompt.new()
	_exit_prompt.z_index = 10
	_exit_prompt.setup("Unsaved changes", "This Deck has changes that have not been saved to the Deckbox.",
			["Save and exit", "Exit without saving", "Keep building"] as Array[String])
	_exit_prompt.chosen.connect(_on_exit_answer)
	add_child(_exit_prompt)
	Easing.fade_in(_exit_prompt, ease_seconds)


func _on_exit_answer(answer: int) -> void:
	Easing.fade_out_and_free(_exit_prompt, ease_seconds)
	_exit_prompt = null
	if answer == ExitAnswer.KEEP_BUILDING:
		return
	if answer == ExitAnswer.SAVE_AND_EXIT and not save():
		return
	navigate.call(MENU)


func _on_name_changed(text: String) -> void:
	_working_deck.name = text
	_show_save()


## Save is there to press only while there is something to save.
func _show_save() -> void:
	var is_changed: bool = _working_deck.has_unsaved_changes()
	_save_button.disabled = not is_changed
	_save_button.tooltip_text = "Save this Deck to the Deckbox." if is_changed else "There is nothing new to save."


func _show_notice(text: String, is_refusal: bool) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", ILLEGAL if is_refusal else DeckbuilderLook.TEXT)
	_notice.visible = true
	_notice.modulate.a = 1.0
	_notice_left = NOTICE_TIME


## Opens the Mod pop-up for the selected card, if it has an empty Mod Slot.
func open_mod_popup() -> void:
	if _mod_popup != null or _selected == null or not _selected.has_empty_mod_slot():
		return
	_put_down()
	_hovered_card = null
	_hover(null)
	_mod_popup = ModPopup.new()
	_mod_popup.z_index = 10
	_mod_popup.setup(_selected, _sample.held_mods)
	_mod_popup.applied.connect(_on_mod_applied)
	_mod_popup.closed.connect(close_mod_popup)
	add_child(_mod_popup)
	Easing.fade_in(_mod_popup, ease_seconds)


func close_mod_popup() -> void:
	if _mod_popup == null:
		return
	# It is gone at once to anyone who asks and to the mouse, and only drawn while it fades.
	Easing.fade_out_and_free(_mod_popup, ease_seconds)
	_mod_popup = null


## A held Mod goes on the selected card for good. Its faces are made again, since the card
## reads differently now, and it stays in the column it was in. A basic land that took its
## first Mod has a new identity from the Collection, and a face there from now on.
func _on_mod_applied(mod: Mod) -> void:
	var card: DeckbuilderCard = _selected
	var old_id: int = card.id
	close_mod_popup()
	if not _sample.held_mods.apply(mod, card, _sample.collection):
		return
	if card.id != old_id:
		for faces: Dictionary in [_column_faces, _flyers, _fan_places]:
			if faces.has(old_id):
				faces[card.id] = faces[old_id]
				faces.erase(old_id)
	if _collection_faces.has(card.id):
		_forget(_collection_faces[card.id])
		_collection_faces[card.id].queue_free()
	_collection_faces[card.id] = _new_face(card, _collection_built_height)
	_collection_grid.add_child(_collection_faces[card.id])
	if _column_faces.has(card.id):
		var old: CardFace = _column_faces[card.id]
		var fresh: CardFace = _new_face(card, old.size.y)
		fresh.position = old.position
		old.add_sibling(fresh)
		_forget(old)
		old.get_parent().remove_child(old)
		old.queue_free()
		_column_faces[card.id] = fresh
	_lay_out_collection(false)
	_show_deck()
	_show_selection()
	_filter_bar.show_count(_filter.apply(_sample.collection.cards()).size(), _sample.collection.cards().size())


## Whether [param face] wears the selected card's border.
func is_ringed(face: CardFace) -> bool:
	return face.get_node_or_null("Selected") != null


## The Mod Slots drawn on [param face], or null for a basic land's.
func mod_slots_on(face: CardFace) -> ModSlotRow:
	return DeckbuilderFace.mod_slots_on(face)


## A right-click at [param point]: the card there is selected, or let go if it already was.
## On empty space the selection is let go. Nothing happens while a card is held.
func right_click_at(point: Vector2) -> void:
	if _held != null:
		return
	var card: DeckbuilderCard = card_at(point)
	_selected = null if card == _selected else card
	_show_selection()
	_show_inspector()


func clear_selection() -> void:
	_selected = null
	_show_selection()
	_show_inspector()


func zoom_slider() -> HSlider:
	return _zoom_slider


func deck_zoom_slider() -> HSlider:
	return _deck_zoom_slider


## The strip the columns stand in, which scrolls sideways when they are too wide for it.
func deck_scroll() -> ScrollContainer:
	return _deck_scroll


## The number on the button that adds the basic land named [param land].
func zoom_panel() -> PanelContainer:
	return _zoom_panel


## The pale plate behind a basic land button's name and count.
func land_name_plate(land: String) -> Panel:
	return _land_buttons[land].get_node("NamePlate") as Panel


func land_count_label(land: String) -> Label:
	return _land_counts.get(land, null) as Label


## The place in the drop column a held card would drop to.
func drop_place() -> int:
	return _drop_place


## Draws the columns' cards at [param zoom] times the size that fills the strip. While the
## slider is still being dragged ([param is_settled] false) the faces are only scaled.
func zoom_deck(zoom: float, is_settled: bool = true) -> void:
	_deck_zoom = clampf(zoom, DeckbuilderLayout.DECK_ZOOM_SMALLEST, DeckbuilderLayout.DECK_ZOOM_LARGEST)
	for face: CardFace in _column_faces.values():
		if face.get_parent() != null:
			face.get_parent().remove_child(face)
		if is_settled and _deck_built_zoom != _deck_zoom:
			_forget(face)
			face.queue_free()
	if is_settled and _deck_built_zoom != _deck_zoom:
		_column_faces.clear()
		_fan_places.clear()
		_deck_built_zoom = _deck_zoom
	_draw_deck(layout())
	_show_selection()


## The face under the cursor, whose border glows, or null.
func hovered_face() -> CardFace:
	return _hovered


## How strongly [param face]'s border glows, from 0 to 1.
func glow_of(face: CardFace) -> float:
	var glow: Panel = face.get_node_or_null("Glow") as Panel
	return 0.0 if glow == null else glow.modulate.a


## The face gliding to [param card]'s place in a column, or null once it has landed.
func flyer(card: DeckbuilderCard) -> CardFace:
	return _flyers.get(card.id, null) as CardFace


## How lit [param column]'s border is, from 0 to 1.
func column_light(column: int) -> float:
	return _column_lit[column]


## Draws the Collection's cards [param height] tall. While the slider is still being
## dragged ([param is_settled] false) the faces are only scaled, which is quick but soft.
func zoom_collection(height: float, is_settled: bool = true) -> void:
	_collection_card_height = clampf(height, DeckbuilderLayout.COLLECTION_CARD_SMALLEST,
			DeckbuilderLayout.COLLECTION_CARD_LARGEST)
	if is_settled and _collection_built_height != _collection_card_height:
		_build_collection_faces()
	_lay_out_collection(false)
	_show_selection()


## The column a held card would drop into, or NO_COLUMN.
func drop_column() -> int:
	return _drop_column


## The card whose face is showing at [param point], or null. In a column it is the card
## whose face is on top there.
func card_at(point: Vector2) -> DeckbuilderCard:
	var column: int = column_at(point)
	if column != WorkingDeck.NO_COLUMN:
		if not _column_scrolls[column].get_global_rect().has_point(point):
			return null
		var cards: Array[DeckbuilderCard] = _working_deck.cards_in(column)
		for index: int in range(cards.size() - 1, -1, -1):
			if _column_faces[cards[index].id].get_global_rect().has_point(point):
				return cards[index]
		return null
	if _collection_scroll.get_global_rect().has_point(point):
		for card: DeckbuilderCard in _sample.collection.cards():
			var face: CardFace = _collection_faces[card.id]
			if face.visible and face.get_global_rect().has_point(point):
				return card
	return null


## The column a card released at [param point] goes to, or NO_COLUMN outside the columns.
func column_at(point: Vector2) -> int:
	if not layout().deck().has_point(point):
		return WorkingDeck.NO_COLUMN
	for column: int in _column_panes.size():
		var pane: Rect2 = _column_panes[column].get_global_rect().grow_individual(
				DeckbuilderLayout.COLUMN_GAP / 2.0, 0.0, DeckbuilderLayout.COLUMN_GAP / 2.0, 0.0)
		if point.x >= pane.position.x and point.x < pane.end.x:
			return column
	return WorkingDeck.NO_COLUMN


## The place in [param column] a card released at [param point] goes to: above the card
## whose name strip is nearest, counting the cards without the one that is held.
func place_at(column: int, point: Vector2) -> int:
	var count: int = _working_deck.cards_in(column).size()
	if _lifted() != null and _working_deck.column_of(_lifted()) == column:
		count -= 1
	return layout().fan_place_at(point.y - _column_fans[column].global_position.y, count)


## The left button goes down at [param point].
func press_at(point: Vector2) -> void:
	if _name_box.has_focus() and not _name_box.get_global_rect().has_point(point):
		_name_box.release_focus()
	_put_down()
	_pressed = card_at(point)
	_press_point = point


## The cursor moves to [param point]. With a card pressed, this picks it up once it has
## moved far enough, and then carries it. With none, the card under the cursor glows.
func drag_to(point: Vector2) -> void:
	if _pressed != null and _held == null and point.distance_to(_press_point) >= DRAG_START:
		if not _lift():
			_pressed = null
	_hovered_card = card_at(point) if _held == null else null
	_hover(_face_at(point) if _held == null else null)
	_show_inspector()
	if _held == null:
		return
	_held_target = point - _held.size / 2.0
	var column: int = column_at(point)
	_show_drop(column, 0 if column == WorkingDeck.NO_COLUMN else place_at(column, point))


## The left button comes up at [param point]: a held card is dropped there.
func release_at(point: Vector2) -> void:
	var card: DeckbuilderCard = _pressed
	if _held == null:
		_pressed = null
		return
	var column: int = column_at(point)
	if column != WorkingDeck.NO_COLUMN:
		var place: int = place_at(column, point)
		if _working_deck.contains(card):
			_working_deck.move(card, column, place)
		else:
			_working_deck.add(card, column, place)
		_fly(card, _held)
		_held = null
	elif _working_deck.contains(card):
		_working_deck.remove(card)
	_put_down()
	_show_deck()


## A double-click at [param point]: a Collection card joins the Deck in its own column, and
## a card in the Deck leaves it.
func double_click_at(point: Vector2) -> void:
	_put_down()
	var card: DeckbuilderCard = card_at(point)
	if card == null:
		return
	if _working_deck.contains(card):
		_working_deck.remove(card)
	else:
		_working_deck.add_to_own_column(card)
		var source: CardFace = _collection_faces[card.id]
		var copy: CardFace = _new_face(card, source.size.y)
		_root.add_child(copy)
		copy.scale = source.scale
		copy.global_position = source.global_position
		_fly(card, copy)
	_show_deck()


func _input(event: InputEvent) -> void:
	if _working_deck == null:
		return
	if _mod_popup != null or _exit_prompt != null:
		# A window has the screen: only Escape gets through, which closes the pop-up or
		# answers the prompt with Keep building.
		var pressed_key: InputEventKey = event as InputEventKey
		if pressed_key != null and pressed_key.pressed and pressed_key.keycode == KEY_ESCAPE:
			if _exit_prompt != null:
				_on_exit_answer(ExitAnswer.KEEP_BUILDING)
			else:
				close_mod_popup()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if not button.pressed:
			release_at(button.position)
		elif button.double_click:
			double_click_at(button.position)
		else:
			press_at(button.position)
	if button != null and button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		right_click_at(button.position)
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		clear_selection()
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		drag_to(motion.position)


func _process(delta: float) -> void:
	if _notice != null and _notice.visible:
		_notice_left -= delta
		_notice.modulate.a = clampf(_notice_left / NOTICE_FADE, 0.0, 1.0)
		_notice.visible = _notice_left > 0.0
	if _held != null:
		_held.position = _held.position.lerp(_held_target, _eased(CARRY_RATE, delta))
	_land_flyers(delta)
	for id: int in _column_faces:
		var seat: CardFace = _column_faces[id]
		seat.position = seat.position.lerp(_fan_places[id], _eased(CARRY_RATE, delta))
	for face: CardFace in _glowing.duplicate():
		var glow: Panel = _glow_on(face)
		glow.modulate.a = lerpf(glow.modulate.a, 1.0 if face == _hovered else 0.0, _eased(GLOW_RATE, delta))
		if face != _hovered and glow.modulate.a < 0.01:
			glow.queue_free()
			_glowing.erase(face)
	for column: int in _column_panes.size():
		var lit: float = lerpf(_column_lit[column], 1.0 if column == _drop_column else 0.0, _eased(GLOW_RATE, delta))
		_column_lit[column] = lit
		var style: StyleBoxFlat = _column_panes[column].get_theme_stylebox("panel") as StyleBoxFlat
		# A column's edge is gray, and turns to the drop color while a held card is over it.
		style.border_color = DeckbuilderLook.PANEL_EDGE.lerp(DROP_BORDER, lit)
		style.set_border_width_all(DeckbuilderLook.PANEL_EDGE_WIDTH)


## Sends [param face], which is on the screen and not in any pane, gliding to [param card]'s
## place in its column.
func _fly(card: DeckbuilderCard, face: CardFace) -> void:
	if _flyers.has(card.id):
		_flyers[card.id].queue_free()
	face.z_index = 2
	_flyers[card.id] = face


## Moves each flyer toward its card's face in the column, shrinking or growing it to that
## face's size, and swaps it for that face when it arrives.
func _land_flyers(delta: float) -> void:
	for id: int in _flyers.keys():
		var flying: CardFace = _flyers[id]
		var seat: CardFace = _column_faces.get(id, null) as CardFace
		if seat != null:
			var step: float = _eased(CARRY_RATE, delta)
			var goal: Vector2 = seat.get_parent_control().global_position + _fan_places[id]
			flying.global_position = flying.global_position.lerp(goal, step)
			flying.scale = flying.scale.lerp(seat.scale * (seat.size.y / flying.size.y), step)
			if flying.global_position.distance_to(goal) > 1.0:
				continue
			seat.modulate.a = 1.0
		flying.queue_free()
		_flyers.erase(id)


## Forgets [param face], which is about to be freed, so that nothing is left pointing at it.
func _forget(face: CardFace) -> void:
	_glowing.erase(face)
	if _hovered == face:
		_hovered = null
	face.z_index = 0


## The share of the way to cover this frame, so that easing looks the same at any frame rate.
func _eased(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


## The face showing at [param point], or null.
func _face_at(point: Vector2) -> CardFace:
	var card: DeckbuilderCard = card_at(point)
	if card == null:
		return null
	return _column_faces[card.id] if column_at(point) != WorkingDeck.NO_COLUMN else _collection_faces[card.id]


## [param face]'s glowing border, made unseen the first time it is asked for.
func _glow_on(face: CardFace) -> Panel:
	var glow: Panel = face.get_node_or_null("Glow") as Panel
	if glow != null:
		return glow
	glow = Panel.new()
	glow.name = "Glow"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = HOVER_GLOW
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(face.size.x * CardGeometry.CORNER))
	style.shadow_color = Color(HOVER_GLOW, 0.55)
	style.shadow_size = 7
	glow.add_theme_stylebox_override("panel", style)
	glow.size = face.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0
	face.add_child(glow)
	return glow


## Picks the pressed card up. False if it cannot be: a Collection card that is already in
## the Deck is moved from its column, not from the Collection pane.
func _lift() -> bool:
	var source: CardFace = _source_face(_pressed, _press_point)
	if source == null:
		return false
	_held = _new_face(_pressed, source.size.y)
	_held.z_index = 2
	_root.add_child(_held)
	_held.scale = source.scale
	_held.global_position = source.global_position
	_held_target = _held.position
	source.modulate.a = LIFTED_DIM
	_lay_out_columns()
	return true


## The face the pressed card is lifted from, or null if it may not be lifted from there.
func _source_face(card: DeckbuilderCard, point: Vector2) -> CardFace:
	if not _working_deck.contains(card):
		return _collection_faces[card.id]
	return _column_faces[card.id] if column_at(point) != WorkingDeck.NO_COLUMN else null


## Ends a press and frees the held face. The faces are put right by _show_deck().
func _put_down() -> void:
	_pressed = null
	_drop_column = WorkingDeck.NO_COLUMN
	_drop_place = 0
	if _held != null:
		_held.queue_free()
		_held = null
		_show_deck()


## Marks the column and the place in it that a held card would drop to. The column's
## border eases in, and the cards from that place down slide to leave a gap for it.
func _show_drop(column: int, place: int) -> void:
	if column == _drop_column and place == _drop_place:
		return
	_drop_column = column
	_drop_place = place
	_lay_out_columns()


## The card that is held, or null.
func _lifted() -> DeckbuilderCard:
	return _pressed if _held != null else null


## Makes [param face] the one under the cursor: it glows, and in a column it is drawn over
## the cards after it so that the whole of it can be read.
func _hover(face: CardFace) -> void:
	if face == _hovered:
		return
	if _hovered != null:
		_hovered.z_index = 0
	_hovered = face
	if face == null:
		return
	if _column_faces.values().has(face):
		face.z_index = 1
	if not _glowing.has(face):
		_glowing.append(face)


## Shows the Working Deck as it is now: the columns, which Collection cards are dimmed,
## and the size in the top bar. Faces are kept; nothing is rebuilt.
func _show_deck() -> void:
	_show_save()
	if _selected != null and _selected.is_basic_land() and not _working_deck.contains(_selected):
		_selected = null
	if _hovered_card != null and not _sample.collection.owns(_hovered_card) and not _working_deck.contains(_hovered_card):
		_hovered_card = null
	_lay_out_columns()
	_lay_out_collection(false)
	_show_count()
	_show_selection()
	_show_inspector()


## Puts the selected card's border on its faces, in the Collection and in its column, and
## takes it off every other face.
func _show_selection() -> void:
	var faces: Array[CardFace] = []
	faces.append_array(_collection_faces.values())
	faces.append_array(_column_faces.values())
	var chosen: Array[CardFace] = []
	if _selected != null:
		for held_in: Dictionary[int, CardFace] in [_collection_faces, _column_faces]:
			if held_in.has(_selected.id):
				chosen.append(held_in[_selected.id])
	for face: CardFace in faces:
		var ring: Panel = face.get_node_or_null("Selected") as Panel
		if chosen.has(face) and ring == null:
			ring = Panel.new()
			ring.name = "Selected"
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.draw_center = false
			style.border_color = SELECTED_RING
			style.set_border_width_all(maxi(2, roundi(face.size.x * 0.018)))
			style.set_corner_radius_all(roundi(face.size.x * CardGeometry.CORNER))
			ring.add_theme_stylebox_override("panel", style)
			ring.size = face.size
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.add_child(ring)
		elif not chosen.has(face) and ring != null:
			ring.name = "Unselected"
			ring.queue_free()


## A Card Face for [param card], [param height] tall, that takes no clicks and shows the
## card's Mod Slots if it has any, unless [param shows_slots] is false.
func _new_face(card: DeckbuilderCard, height: float, shows_slots: bool = true) -> CardFace:
	return DeckbuilderFace.make(card, height, shows_slots)


func _show_count() -> void:
	_count_label.text = "%d / %d cards" % [_working_deck.size(), WorkingDeck.MINIMUM_SIZE]
	_count_label.add_theme_color_override("font_color", DeckbuilderLook.TEXT if _working_deck.is_legal() else ILLEGAL)
	for land: String in _land_counts:
		_land_counts[land].text = str(_working_deck.basic_land_count(land))


func count_label() -> Label:
	return _count_label


func name_box() -> LineEdit:
	return _name_box


func filter_bar() -> FilterBar:
	return _filter_bar


## The search, filters and sort order the Collection pane is showing.
func collection_filter() -> CollectionFilter:
	return _filter


## Shows [param filter] in the bar and the Collection pane.
func show_filter(filter: CollectionFilter) -> void:
	_filter = filter
	_redraw()


func _redraw() -> void:
	close_mod_popup()
	if _exit_prompt != null:
		_exit_prompt.queue_free()
		_exit_prompt = null
	if _root != null:
		_root.queue_free()
	_column_faces.clear()
	_collection_faces.clear()
	_column_panes.clear()
	_column_scrolls.clear()
	_column_fans.clear()
	_column_counts.clear()
	_land_buttons.clear()
	_land_counts.clear()
	_pressed = null
	_held = null
	_hovered = null
	_hovered_card = null
	_inspector_pane = null
	_inspector_shown = null
	_inspector_slots = -1
	_inspector = null
	_glowing.clear()
	_fan_places.clear()
	_flyers.clear()
	_column_lit.clear()
	_drop_column = WorkingDeck.NO_COLUMN
	_drop_place = 0
	_deck_scroll = null
	_deck_built_zoom = _deck_zoom
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)
	if _working_deck == null:
		return
	var places: DeckbuilderLayout = layout()
	_draw_top_bar(places.top_bar())
	_inspector_pane = _pane(places.inspector())
	_inspector = DeckbuilderInspector.new()
	_inspector.apply_pressed.connect(open_mod_popup)
	_fill(_inspector_pane, _inspector)
	_draw_filter_bar(places.filter_bar())
	_draw_collection(places)
	_draw_deck(places)
	_show_selection()
	_show_inspector()


## Draws the strip the columns stand in and the eight columns, in place of any there, and
## puts the Deck's cards in them. The strip scrolls sideways when the deck zoom makes the
## columns too wide for it.
func _draw_deck(places: DeckbuilderLayout) -> void:
	if _deck_scroll != null:
		_deck_scroll.queue_free()
	_column_panes.clear()
	_column_scrolls.clear()
	_column_fans.clear()
	_column_counts.clear()
	_column_lit.clear()
	var strip: Rect2 = places.deck()
	_deck_scroll = ScrollContainer.new()
	_deck_scroll.position = strip.position
	_deck_scroll.size = strip.size
	_deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_deck_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_deck_scroll)
	var floor_under: Control = Control.new()
	floor_under.custom_minimum_size = Vector2(places.columns_width(), places.column(0).size.y)
	floor_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_scroll.add_child(floor_under)
	for column: int in WorkingDeck.COLUMN_COUNT:
		_draw_column(places, column, floor_under)
	_lay_out_columns()


func _draw_top_bar(place: Rect2) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_fill(_pane(place), row)
	_name_box = LineEdit.new()
	_name_box.text = _working_deck.name
	_name_box.placeholder_text = "Deck name"
	_name_box.custom_minimum_size = Vector2(300, 0)
	_name_box.add_theme_font_size_override("font_size", 22)
	_name_box.max_length = 40
	_name_box.text_changed.connect(_on_name_changed)
	_name_box.text_submitted.connect(func(_text: String) -> void: _name_box.release_focus())
	row.add_child(_name_box)
	_count_label = _label("", 22)
	_count_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(_count_label)
	_show_count()
	row.add_child(_spacer())
	for land: String in LAND_COLORS:
		var button: Button = _button("+" + land)
		button.tooltip_text = "Add a %s to the Deck. The number is how many are in it." % land
		_color(button, LAND_COLORS[land])
		_land_counts[land] = _count_badge(button)
		_make_live(button)
		button.pressed.connect(_on_land_pressed.bind(land))
		row.add_child(button)
		_land_buttons[land] = button
	row.add_child(_spacer())
	_zoom_panel = PanelContainer.new()
	var plate_style: StyleBoxFlat = StyleBoxFlat.new()
	plate_style.bg_color = DeckbuilderLook.BAR_PANEL
	plate_style.border_color = DeckbuilderLook.BUTTON_EDGE
	plate_style.set_border_width_all(1)
	plate_style.set_corner_radius_all(8)
	plate_style.content_margin_left = 12.0
	plate_style.content_margin_right = 12.0
	_zoom_panel.add_theme_stylebox_override("panel", plate_style)
	row.add_child(_zoom_panel)
	var zoom: HBoxContainer = HBoxContainer.new()
	zoom.add_theme_constant_override("separation", 10)
	_zoom_panel.add_child(zoom)
	zoom.add_child(_label("Zoom", 17, MUTED))
	zoom.add_child(_label("Collection", 17))
	_zoom_slider = _slider(DeckbuilderLayout.COLLECTION_CARD_SMALLEST, DeckbuilderLayout.COLLECTION_CARD_LARGEST,
			1.0, _collection_card_height, "How large the Collection's cards are drawn.")
	_zoom_slider.value_changed.connect(_on_zoom_changed)
	_zoom_slider.drag_ended.connect(_on_zoom_let_go)
	zoom.add_child(_zoom_slider)
	zoom.add_child(_label("Deck", 17))
	_deck_zoom_slider = _slider(DeckbuilderLayout.DECK_ZOOM_SMALLEST, DeckbuilderLayout.DECK_ZOOM_LARGEST,
			0.01, _deck_zoom, "How large the Deck's cards are drawn. Larger, the columns scroll sideways.")
	_deck_zoom_slider.value_changed.connect(_on_deck_zoom_changed)
	_deck_zoom_slider.drag_ended.connect(_on_deck_zoom_let_go)
	zoom.add_child(_deck_zoom_slider)
	_sort_button = _button("Sort")
	_sort_button.tooltip_text = "Put every card back in its own column."
	_make_live(_sort_button)
	_sort_button.pressed.connect(_on_sort_pressed)
	row.add_child(_sort_button)
	_save_button = _button("Save")
	_make_live(_save_button)
	_save_button.pressed.connect(save)
	row.add_child(_save_button)
	_exit_button = _button("Exit")
	_exit_button.tooltip_text = "Go back to the main menu."
	_make_live(_exit_button)
	_exit_button.pressed.connect(exit)
	row.add_child(_exit_button)
	_show_count()
	_show_save()
	_notice = _label("", 20)
	_notice.visible = false
	_notice.z_index = 5
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plate: StyleBoxFlat = StyleBoxFlat.new()
	plate.bg_color = DeckbuilderLook.HOLLOW
	plate.border_color = PANE_BORDER
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(6)
	plate.set_content_margin_all(10)
	_notice.add_theme_stylebox_override("normal", plate)
	_notice.position = Vector2(place.position.x, place.end.y + 6.0)
	_notice.custom_minimum_size = Vector2(DeckbuilderLayout.INSPECTOR_WIDTH, 0)
	_root.add_child(_notice)


func _on_land_pressed(land: String) -> void:
	_working_deck.add_basic_land(land)
	_show_deck()


func _on_zoom_changed(height: float) -> void:
	zoom_collection(height, false)


func _on_zoom_let_go(_has_changed: bool) -> void:
	zoom_collection(_zoom_slider.value)


func _on_deck_zoom_changed(zoom: float) -> void:
	zoom_deck(zoom, false)


func _on_deck_zoom_let_go(_has_changed: bool) -> void:
	zoom_deck(_deck_zoom_slider.value)


func _slider(smallest: float, largest: float, step: float, value: float, tip: String) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.min_value = smallest
	slider.max_value = largest
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(110, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = tip
	return slider


func _on_sort_pressed() -> void:
	_working_deck.sort()
	_show_deck()


## Shows the selected card, or with none selected the one under the cursor, in the inspector. Redrawn only
## when the card or its Mods change.
func _show_inspector() -> void:
	var card: DeckbuilderCard = inspected()
	var slots: int = -1 if card == null else card.mods.size()
	if card != _inspector_shown or slots != _inspector_slots or (card != null and _inspector.face() == null):
		_inspector_shown = card
		_inspector_slots = slots
		_inspector.show_card(card, layout().inspector_card_height(), ease_seconds)
	_show_apply()


## Apply a Mod is for the selected card, while it has an empty Mod Slot and a held Mod fits it.
func _show_apply() -> void:
	var card: DeckbuilderCard = _inspector_shown
	if card == null:
		return
	var why_not: String = ""
	if card != _selected:
		why_not = "Right-click the card to select it first."
	elif not card.has_empty_mod_slot():
		why_not = "All three Mod Slots are filled."
	elif not _sample.held_mods.has_applicable(card):
		why_not = "You hold no Mod that fits this card."
	_inspector.set_apply(why_not)


func _draw_filter_bar(place: Rect2) -> void:
	var owned: Array[DeckbuilderCard] = _sample.collection.cards()
	_filter_bar = FilterBar.new()
	_filter_bar.setup(_filter, _filter.apply(owned).size(), owned.size())
	_filter_bar.changed.connect(_on_filter_changed)
	_fill(_pane(place), _filter_bar, 8.0)


## Only the Collection pane changes with the filter, and its faces are kept: the bar is not
## rebuilt, so typing a search never loses the cursor.
func _on_filter_changed() -> void:
	var shown: int = _lay_out_collection(true)
	_filter_bar.show_count(shown, _sample.collection.cards().size())


func _draw_collection(places: DeckbuilderLayout) -> void:
	_collection_scroll = ScrollContainer.new()
	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fill(_pane(places.collection()), _collection_scroll)
	_collection_grid = Control.new()
	_collection_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collection_scroll.add_child(_collection_grid)
	_build_collection_faces()
	_lay_out_collection(true)


## Makes every Collection card's face at the size the zoom asks for, in place of any there.
func _build_collection_faces() -> void:
	for face: CardFace in _collection_faces.values():
		_forget(face)
		face.queue_free()
	_collection_faces.clear()
	_collection_built_height = _collection_card_height
	for card: DeckbuilderCard in _sample.collection.cards():
		var face: CardFace = _new_face(card, _collection_built_height)
		_collection_grid.add_child(face)
		_collection_faces[card.id] = face


## Shows the faces the filter lets through, in its order, and hides the rest. Returns how
## many are showing. A change of filter goes back to the top; a change of Deck stays put.
func _lay_out_collection(resets_scroll: bool) -> int:
	var places: DeckbuilderLayout = layout()
	var shown: Array[DeckbuilderCard] = _filter.apply(_sample.collection.cards())
	for face: CardFace in _collection_faces.values():
		face.visible = false
	for index: int in shown.size():
		var face: CardFace = _collection_faces[shown[index].id]
		face.visible = true
		face.scale = Vector2.ONE * (_collection_card_height / _collection_built_height)
		face.position = places.collection_cell(index).position
		face.modulate.a = IN_DECK_DIM if _working_deck.contains(shown[index]) else 1.0
	_collection_grid.custom_minimum_size = Vector2(0, places.collection_grid_height(shown.size()))
	if resets_scroll:
		_collection_scroll.scroll_vertical = 0
	return shown.size()


## Draws a column's pane, heading and the scrolling fan its cards go in, on the strip's
## [param floor_under].
func _draw_column(places: DeckbuilderLayout, column: int, floor_under: Control) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var place: Rect2 = places.column(column)
	place.position -= places.deck().position
	var pane: Panel = _pane(place, floor_under)
	_fill(pane, box, DeckbuilderLayout.COLUMN_PAD)
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, DeckbuilderLayout.COLUMN_HEADER - 4.0)
	box.add_child(header)
	header.add_child(_label(COLUMN_TITLES[column], 22))
	header.add_child(_spacer())
	var count: Label = _label("", 20, MUTED)
	header.add_child(count)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var fan: Control = Control.new()
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(fan)
	(pane.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = DeckbuilderLook.COLUMN
	_column_panes.append(pane)
	_column_lit.append(0.0)
	_column_scrolls.append(scroll)
	_column_fans.append(fan)
	_column_counts.append(count)


## Puts every Deck card's face in its column's fan, in order, making a face for a card that
## has just come in and freeing the face of one that has left. While a card is held it has
## no seat, and the column it is over leaves a gap where it would drop.
func _lay_out_columns() -> void:
	var places: DeckbuilderLayout = layout()
	var lifted: DeckbuilderCard = _lifted()
	var in_deck: Dictionary[int, bool] = {}
	for column: int in WorkingDeck.COLUMN_COUNT:
		var cards: Array[DeckbuilderCard] = _working_deck.cards_in(column)
		var fan: Control = _column_fans[column]
		var seats: int = 0
		for index: int in cards.size():
			var card: DeckbuilderCard = cards[index]
			in_deck[card.id] = true
			var face: CardFace = _column_faces.get(card.id, null) as CardFace
			if face == null:
				face = _new_face(card, places.column_card_height())
				_column_faces[card.id] = face
			face.scale = Vector2.ONE * (places.column_card_height() / face.size.y)
			var is_new_here: bool = face.get_parent() != fan
			if is_new_here:
				if face.get_parent() != null:
					face.get_parent().remove_child(face)
				fan.add_child(face)
			fan.move_child(face, index)
			if card == lifted:
				# The held card has left its seat: the others close up without it.
				face.modulate.a = 0.0
				continue
			if column == _drop_column and lifted != null and seats == _drop_place:
				seats += 1
			_fan_places[card.id] = Vector2(places.fan_left(), places.fan_offset(seats))
			seats += 1
			if is_new_here or not _fan_places.has(card.id):
				# New to this column, it starts in its place: its flyer does the gliding.
				face.position = _fan_places[card.id]
			face.modulate.a = 0.0 if _flyers.has(card.id) else 1.0
		if column == _drop_column and lifted != null and seats == _drop_place:
			seats += 1
		fan.custom_minimum_size = Vector2(0, places.fan_height(seats))
		_column_counts[column].text = str(cards.size())
	for id: int in _column_faces.keys():
		if not in_deck.has(id):
			_forget(_column_faces[id])
			_column_faces[id].queue_free()
			_column_faces.erase(id)
			_fan_places.erase(id)


## A bordered pane at [param place], added to [param parent] or else to the screen.
func _pane(place: Rect2, parent: Control = null) -> Panel:
	var pane: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANE
	style.border_color = DeckbuilderLook.PANEL_EDGE
	style.set_border_width_all(DeckbuilderLook.PANEL_EDGE_WIDTH)
	style.set_corner_radius_all(6)
	pane.add_theme_stylebox_override("panel", style)
	pane.position = place.position
	pane.size = place.size
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_root if parent == null else parent).add_child(pane)
	return pane


## Puts [param content] inside [param pane], [param pad] in from every edge.
func _fill(pane: Panel, content: Control, pad: float = DeckbuilderLayout.PAD) -> void:
	content.position = Vector2(pad, pad)
	content.size = pane.size - 2.0 * Vector2(pad, pad)
	pane.add_child(content)


func _label(text: String, font_size: int, color: Color = DeckbuilderLook.TEXT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Paints [param button] in [param color], with lettering that reads against it.
func _color(button: Button, color: Color) -> void:
	var shades: Dictionary[String, Color] = {
		"normal": color, "hover": color.lightened(0.15), "pressed": color.darkened(0.2),
	}
	for state: String in shades:
		var shade: Color = shades[state]
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = shade
		# Lit from above: a pale top edge, a dark lip underneath and a soft shadow.
		style.border_color = shade.darkened(0.35)
		style.border_width_bottom = 1 if state == "pressed" else 4
		style.set_corner_radius_all(7)
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 2)
		style.set_content_margin_all(6)
		style.content_margin_top = 9 if state == "pressed" else 6
		style.content_margin_left = 12
		style.content_margin_right = 44
		button.add_theme_stylebox_override(state, style)
	# The button's own lettering is hidden: its name is written again on a pale plate that
	# also holds its count, so
	# that it reads against any land's color. Every one is lettered in the same near-black.
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var plate: Panel = Panel.new()
	plate.name = "NamePlate"
	var pale: StyleBoxFlat = StyleBoxFlat.new()
	pale.bg_color = Color(1, 1, 1, LAND_PLATE_ALPHA)
	pale.set_corner_radius_all(5)
	plate.add_theme_stylebox_override("panel", pale)
	plate.anchor_right = 1.0
	plate.anchor_bottom = 1.0
	plate.offset_left = 6.0
	plate.offset_top = 6.0
	plate.offset_right = -6.0
	plate.offset_bottom = -9.0
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(plate)
	var lettering: Label = _label(button.text, 20, Color("#1a1d22"))
	lettering.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lettering.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The count's pill is on the plate too, at its right; the name is centered in the rest.
	lettering.offset_right = -36.0
	lettering.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(lettering)
	var shine: Panel = Panel.new()
	var gloss: StyleBoxFlat = StyleBoxFlat.new()
	gloss.bg_color = Color(1, 1, 1, 0.16)
	gloss.set_corner_radius_all(6)
	gloss.corner_radius_bottom_left = 0
	gloss.corner_radius_bottom_right = 0
	shine.add_theme_stylebox_override("panel", gloss)
	shine.anchor_right = 1.0
	shine.anchor_bottom = 0.42
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shine)


## A small dark pill at the right of [param button] for a number.
func _count_badge(button: Button) -> Label:
	var badge: Label = Label.new()
	badge.name = "Count"
	badge.text = "0"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 17)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.bg_color = Color(0, 0, 0, 0.6)
	pill.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("normal", pill)
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.anchor_top = 0.5
	badge.anchor_bottom = 0.5
	badge.offset_left = -38.0
	badge.offset_right = -8.0
	badge.offset_top = -12.0
	badge.offset_bottom = 12.0
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)
	return badge


## Lets a button made by _button() take clicks.
func _make_live(button: Button) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE


## A button that looks live but takes no clicks yet.
func _button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(84, 0)
	button.add_theme_font_size_override("font_size", 20)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
