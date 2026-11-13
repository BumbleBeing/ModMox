class_name EncounterScreen
extends Control
## The Encounter Screen (game glossary): shows an encounter to the human and takes their
## answers. It draws only from the snapshots its Encounter Presenter hands it (ADR 0021):
## the Regions from EncounterLayout, and the Stack Window and Emblems windows over them.
## Every kind of decision has an input of its own (DecisionInputs).
##
## A permanent or a player's panel that a click answers something on takes the mouse (a
## ClickCatcher); everything else ignores it. One answer is given at once, and several open
## the Option Menu. The Info Panel says what is asked, and Escape opens the Pause Menu.
##
## Combat decisions are answered all at once, so their clicks build a CombatSelection kept
## here, outside the redrawn nodes: creatures chosen to attack or block step into the lane,
## lines join blockers to their attackers, and damage is divided with steppers on the
## recipients. The pass button confirms it, and undo takes back one click at a time.
##
## The Stack Window gives each spell and ability its own color (StackColors, kept here too)
## and marks what the entry under the cursor is about: its source with a solid border and
## its targets with a dashed one. A spell that can be targeted is clicked there. Triggers
## to be put in order appear above the stack and are dragged into place (a TriggerList,
## which a redraw replaces, and a TriggerOrder, kept here like the CombatSelection), and a
## choice between replacement effects is made in a window of its own.
##
## Permanents do not jump from one redraw to the next: a FaceMotion, kept here as well,
## remembers where each one's face was drawn, and every frame the screen places each face
## part-way to where the last redraw put it. A permanent that has left is drawn for a
## moment longer as a ghost, on a layer of its own that a redraw leaves alone.
##
## A card that changes zones flies there: CardFlights, kept here too, holds where each such
## card left from and where it lands, and a FlightCard is drawn in the air between them, on
## a layer over every window. What it lands on shows nothing of it until it arrives, and a
## permanent that flies away leaves no ghost.
##
## The Hero's hand is kept in their own order (a HandOrder) and its cards are dragged: a
## card held above the hand's strip is played when it is let go, and one let go over the
## strip is put down where the others made room. The card being held is a DragCard, kept
## here as well. Nothing is rebuilt between picking a card up and letting it go: the card's
## own face is lifted to a layer above the windows, and the rest of the hand is only told
## where to go. A double-click plays a card too, and one click does nothing.
##
## Through the pregame the opening-hand overlay covers everything right of the sidebar and
## holds the Hero's hand: play or draw, keep or mulligan, and the cards put on the bottom
## are answered there (an OpeningHand says what it reads, kept here). Cards to discard are
## chosen in the hand's strip with single clicks. Both build a CardPicks, kept here like
## the CombatSelection.
##
## Run with a request: godot --path . -- --hero=red_green --villain=white_black --seed=7
## Add --screenshot=/absolute/path.png to save a picture and quit.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const MENU: String = "res://ui/menu/main_menu.tscn"
const START_FORM: String = "res://ui/encounter/start_form.tscn"
## How much of the way to its place a card of the hand goes in a sixtieth of a second.
const HAND_EASE: float = 0.3
## How much lighter the card of the hand under the cursor is drawn, and how much of the way
## it goes to or from that in a sixtieth of a second.
const HAND_HOVER_LIGHT: Color = ClickCatcher.BRIGHT
const HAND_LIGHT_EASE: float = 0.4
## The Glow of a card of the hand chosen to be discarded (A401).
const PICKED_GLOW: Color = Color.WHITE
## What the Tap Preview shows when the cursor asks for nothing.
const NO_PREVIEW: int = -1
const LOSS_REASONS: Dictionary[MmPlayer.LossReason, String] = {
	MmPlayer.LossReason.ZERO_LIFE: "ran out of life",
	MmPlayer.LossReason.EMPTY_LIBRARY: "drew from an empty library",
	MmPlayer.LossReason.CONCEDED: "conceded",
}

## The encounter to play next, set by whoever opens this screen: the start form, or the
## command line. Temporary, until runs hand the encounter its setup (A246).
static var request: EncounterRequest = null

## Whether _ready() starts the requested encounter. Tests turn it off and call begin().
var starts_itself: bool = true
## Where the player's settings are kept, or "" to read and save none. A screen that starts
## itself uses the game's own file; one made in a test uses none unless it is given one.
var settings_path: String = ""
## How this screen leaves for another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: get_tree().change_scene_to_file(scene)

var _presenter: EncounterPresenter = null
var _snapshot: EncounterSnapshot = null
var _error: String = ""
var _board: Control
var _panels: Dictionary[int, PlayerPanel] = {}
var _stack_window: ZoneWindow
var _emblem_windows: Dictionary[int, ZoneWindow] = {}
## The Zone Window of each graveyard, exile and library, by its pile's Region, which of
## them have been given a place, and which are open only to answer a target (13f).
var _pile_windows: Dictionary[String, PileWindow] = {}
var _placed_piles: Array[String] = []
var _pile_state: PileWindows = PileWindows.new()
## What takes a click on each pile, by its Region.
var _pile_hosts: Dictionary[String, Control] = {}
var _faces: Dictionary[int, Control] = {}
var _face_sizes: Dictionary[int, Vector2] = {}
var _hand_faces: Array[CardFace] = []
var _hand_rest: Array[Vector2] = []
var _card_backs: Array[Control] = []
var _stack_entries: Array[StackEntry] = []
var _stack_items: Dictionary[int, StackItem] = {}
## Which color each object on the stack was given, kept across redraws (A335).
var _stack_colors: StackColors = StackColors.new()
var _stack_arrows: StackArrows = null
## The Hero's half-made order for the triggers being asked about, if any are.
var _trigger_order: TriggerOrder = TriggerOrder.new()
## The list they are dragged in, which a redraw replaces.
var _trigger_list: TriggerList = null
var _choice_window: ZoneWindow
var _choice_entries: Array[ZoneEntry] = []
## What the entry under the cursor has marked on the board.
var _marked: Array[Control] = []
## How long a Glow or mark takes to ease in or out: none until the game's pace is set.
var _ease_seconds: float = 0.0
## Through a redraw, the color each object glowed before it, so a Glow that has not changed
## is drawn at once and not eased in again; only one that changed eases.
var _glowed_before: Dictionary[int, Array] = {}
var _is_redrawing: bool = false
var _banner: Control = null
var _info: InfoPanel
var _hold_panel: HoldPanel
var _option_menu: OptionMenu
var _pause_menu: PauseMenu
## Over the Info Panel: passes priority, or confirms a choice being made (A489).
var _pass_button: PassButton
var _clicks: DecisionClicks = DecisionClicks.new()
var _regions: Dictionary[String, Rect2] = {}
var _is_paused: bool = false
## Each scrolling line's object IDs, by the same keys as _lines.
var _line_ids: Dictionary[String, Array] = {}
var _block_lines: BlockLines
## The Hero's half-made answer to the combat decision being asked, if one is.
var _selection: CombatSelection = CombatSelection.new()
var _steppers: Dictionary[int, DamageStepper] = {}
var _player_steppers: Dictionary[int, DamageStepper] = {}
var _are_windows_placed: bool = false
## Each scrolling line of permanents, and how far each was scrolled, by "hero_creatures",
## "hero_others", "villain_creatures" or "villain_others", so a redraw keeps its place.
var _lines: Dictionary[String, ScrollRow] = {}
var _line_offsets: Dictionary[String, float] = {}
var _pile_labels: Dictionary[String, Label] = {}
## Where each permanent's face is drawn on its way to its place (A356).
var _motion: FaceMotion = FaceMotion.new()
## Each permanent's face's place in its parent as the layout put it, by object ID.
var _rest: Dictionary[int, Vector2] = {}
var _ghost_layer: Control
var _ghosts: Dictionary[int, BattlefieldFace] = {}
## The cards in the air between two zones, by the ID of the Game Object each lands as, the
## route each is on, and the card drawn for each (13d-2).
var _flights: CardFlights = CardFlights.new()
var _flight_routes: Dictionary[int, CardFlights.Route] = {}
var _flight_cards: Dictionary[int, FlightCard] = {}
var _flight_layer: Control
## The Game Objects of the cards on their way from a library to a hand, in the order they
## left: a card drawn joins the hand when it lands.
var _drawing: Array[int] = []
## A drawn card has landed, and the hand is to be drawn again with it.
var _has_draw_landed: bool = false
## The redraw under way adds a card that landed, so the hand eases apart from where it was.
var _is_hand_easing: bool = false
## The Game Speed in use, and the presenter that waits at it once the game's pace is set.
var _speed: GameSpeed.Speed = GameSpeed.Speed.NORMAL
## What the player has chosen, as last read or saved.
var _settings: GameSettings = GameSettings.new()
var _paced_presenter: EncounterPresenter = null
## Where the art of each Stack Window entry was last seen, by object ID, in this screen's
## coordinates, and whether the entries drawn now have found their places: they find them
## a frame after a redraw, and a card can leave the stack before that frame comes.
var _stack_art_places: Dictionary[int, Vector2] = {}
var _are_stack_entries_placed: bool = false
## Whether the next redraw puts every face straight at its place, as the first one does: a rewind,
## or a window of another size (A365).
var _is_snapping: bool = false
var _drawn_size: Vector2 = Vector2.ZERO
## The order the Hero keeps their hand in, and the card of it they are holding (13e-1).
var _hand_order: HandOrder = HandOrder.new()
var _drag: DragCard = DragCard.new()
## The Card Identity of each of _hand_faces, and how far each is turning toward.
var _hand_cards: Array[int] = []
var _hand_turns: Array[float] = []
var _drag_layer: Control
var _lifted_face: CardFace = null
## What the pregame has said so far, and the overlay that shows it (13e-2).
var _opening: OpeningHand = OpeningHand.new()
var _overlay: OpeningHandOverlay
## The Hero's half-made choice of cards to put on the bottom or to discard, if one is asked.
var _picks: CardPicks = CardPicks.new()
## The answer whose payment the Tap Preview (game glossary) shows, or NO_PREVIEW. Kept
## outside the redrawn nodes, so a redraw draws the preview again.
var _previewed: int = NO_PREVIEW
## The Inspector, which lies over the sidebar while a card is pinned, and which card that
## is: kept here, outside everything a redraw replaces (ADR 0033).
var _inspector: Inspector
var _inspection: Inspection = Inspection.new()
## The card the Inspector was last told to show.
var _inspected: int = Inspection.NOTHING
## What the Pinned card's ring is on, or null.
var _pin_host: Control = null

## The Backdrop behind everything and the layer that dims it, built once and kept outside
## everything a redraw replaces; both null for the plain Backdrop (ADR 0035).
var _backdrop_name: String = Backdrops.PLAIN
var _backdrop: Control = null
var _backdrop_dimmer: ColorRect = null
## The plates behind the rows and piles, over the Backdrop and under the board.
var _zone_plates: ZonePlates


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Backdrops.SLATE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_zone_plates = ZonePlates.new()
	_zone_plates.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_zone_plates)
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	_ghost_layer = Control.new()
	_ghost_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost_layer)
	_block_lines = BlockLines.new()
	add_child(_block_lines)
	for player_id: int in [VILLAIN, HERO]:
		var panel: PlayerPanel = PlayerPanel.new(player_id, "HERO" if player_id == HERO else "VILLAIN")
		panel.mana_pressed.connect(_answer)
		panel.player_clicked.connect(_answer)
		panel.emblems_pressed.connect(_toggle_emblems.bind(player_id))
		panel.stop_toggled.connect(func(step: MmTurn.Step) -> void: _presenter.toggle_stop(player_id, step))
		panel.undo_pressed.connect(undo)
		panel.yield_toggled.connect(toggle_yield)
		add_child(panel)
		_panels[player_id] = panel
	# Over the player panels and under every window.
	_inspector = Inspector.new()
	_inspector.hide()
	add_child(_inspector)
	_stack_window = ZoneWindow.new("Stack", false, Color("#8a93a6"))
	_stack_window.size = Vector2(400, 400)
	_stack_window.hide()
	add_child(_stack_window)
	_choice_window = ZoneWindow.new("Replacement", false, StackColors.PLAIN)
	_choice_window.size = Vector2(470, 260)
	_choice_window.hide()
	add_child(_choice_window)
	for player_id: int in [HERO, VILLAIN]:
		var emblems: ZoneWindow = ZoneWindow.new("Emblems", true, PlayerPanel.GOLD)
		emblems.size = Vector2(300, 220)
		emblems.hide()
		add_child(emblems)
		_emblem_windows[player_id] = emblems
	for key: String in EncounterLayout.pile_keys():
		var is_row: bool = key.ends_with("library")
		var pile_window: PileWindow = PileWindow.new(PileWindow.Arrangement.ROW if is_row else PileWindow.Arrangement.GRID,
			Color("#6f7f9a") if key.begins_with("hero") else Color("#9a6f6f"))
		pile_window.card_clicked.connect(_on_object_clicked)
		pile_window.hide()
		add_child(pile_window)
		_pile_windows[key] = pile_window
	_info = InfoPanel.new()
	_info.cancel_pressed.connect(func() -> void: _command(_presenter.cancel_cast))
	_info.all_attack_pressed.connect(func() -> void:
		if not _is_paused and _selection.select_all():
			_redraw())
	_info.undeclare_all_pressed.connect(func() -> void:
		if not _is_paused and _selection.clear_attackers():
			_redraw())
	add_child(_info)
	_pass_button = PassButton.new()
	_pass_button.pressed.connect(pass_priority)
	add_child(_pass_button)
	_hold_panel = HoldPanel.new()
	add_child(_hold_panel)
	# Over the board, its windows and the Info Panel; the Emblems windows open over it, so
	# a Status can be read while deciding whether to keep (A392).
	_overlay = OpeningHandOverlay.new()
	_overlay.answered.connect(_answer_overlay)
	_overlay.card_clicked.connect(_put_on_bottom)
	_overlay.confirmed.connect(_confirm_picks)
	_overlay.closed.connect(_show_landed_hand)
	add_child(_overlay)
	for player_id: int in [HERO, VILLAIN]:
		move_child(_emblem_windows[player_id], _overlay.get_index())
	_drag_layer = Control.new()
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_layer)
	# Over every window, wherever a click has brought one to the front, and over the card
	# of the hand that is raised.
	_flight_layer = Control.new()
	_flight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flight_layer.z_index = 2
	add_child(_flight_layer)
	_option_menu = OptionMenu.new()
	_option_menu.closed.connect(_on_menu_closed)
	_option_menu.chosen.connect(_answer)
	_option_menu.pointed.connect(func(text: String) -> void: _info.show_option(text))
	add_child(_option_menu)
	_pause_menu = PauseMenu.new()
	_pause_menu.resume_pressed.connect(set_paused.bind(false))
	_pause_menu.concede_confirmed.connect(_concede)
	_pause_menu.quit_confirmed.connect(leave.bind(MENU))
	_pause_menu.speed_chosen.connect(set_game_speed)
	_pause_menu.auto_pass_chosen.connect(set_auto_passing)
	_pause_menu.auto_tap_chosen.connect(set_auto_tapping)
	_pause_menu.keys_changed.connect(_on_keys_changed)
	_pause_menu.key_bindings = _settings.key_bindings
	add_child(_pause_menu)
	resized.connect(_redraw)
	if not starts_itself:
		return
	if request == null:
		request = EncounterRequest.from_arguments(OS.get_cmdline_user_args())
	if request == null:
		request = EncounterRequest.new()
	show_backdrop(request.backdrop)
	var presenter: EncounterPresenter = EncounterPresenter.new(request.setup(), request.villain_agent())
	presenter.names = request.names()
	var picture: String = screenshot_path(OS.get_cmdline_user_args())
	if picture == "":
		settings_path = GameSettings.PATH
		load_settings()
		use_settings(presenter)
		use_game_pace(presenter)
	begin(presenter)
	if picture != "":
		for frame: int in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## Draws the Backdrop named [param backdrop] behind everything, under its dim layer, in
## place of any shown before. Both are built here once and no redraw touches them; the
## plain Backdrop is the slate alone, with nothing over it (ADR 0035).
func show_backdrop(backdrop: String) -> void:
	for old: Control in [_backdrop, _backdrop_dimmer]:
		if old != null:
			remove_child(old)
			old.queue_free()
	_backdrop_name = backdrop if Backdrops.has(backdrop) else Backdrops.PLAIN
	_backdrop = Backdrops.make(_backdrop_name)
	_backdrop_dimmer = null
	if _backdrop == null:
		return
	_backdrop_dimmer = Backdrops.dimmer()
	# Just over the slate, which is the first child.
	for layer: Control in [_backdrop_dimmer, _backdrop]:
		add_child(layer)
		move_child(layer, 1)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The name of the Backdrop shown.
func backdrop_name() -> String:
	return _backdrop_name


## What draws the Backdrop, or null for the plain one.
func backdrop() -> Control:
	return _backdrop


## What draws the Zone Plates behind the rows and piles.
func zone_plates() -> ZonePlates:
	return _zone_plates


## The layer that dims the Backdrop, or null for the plain one.
func backdrop_dimmer() -> ColorRect:
	return _backdrop_dimmer


## Where [param arguments] ask for a picture to be saved, or "" if they do not.
static func screenshot_path(arguments: PackedStringArray) -> String:
	for argument: String in arguments:
		if argument.begins_with("--screenshot="):
			return argument.trim_prefix("--screenshot=")
	return ""


## Plays at the game's pace: [param presenter] holds the Villain's answers back, faces
## take time to move and cards fly between zones (Pacing), all at the Game Speed in use.
## Without this nothing waits or moves at any speed, which is what tests and screenshots
## want (A369). Call it before begin().
func use_game_pace(presenter: EncounterPresenter) -> void:
	_paced_presenter = presenter
	_apply_speed()


## Reads what the player chose from settings_path: the Game Speed, and Auto-pass and
## Auto-tap for use_settings().
func load_settings() -> void:
	_settings = GameSettings.load_from(settings_path)
	_speed = _settings.game_speed
	_pause_menu.key_bindings = _settings.key_bindings
	_pause_menu.show_game_speed(_speed)
	_apply_speed()


## Gives [param presenter] the Auto-pass and Auto-tap the player chose. Call it before begin(). Without
## it a presenter keeps its own, which is what tests want.
func use_settings(presenter: EncounterPresenter) -> void:
	presenter.set_auto_passing(_settings.is_auto_passing)
	presenter.set_auto_tapping(_settings.is_auto_tapping)


## Turns Auto-pass on or off for the encounter that is running, and keeps the choice for
## the next one. Under the Pause Menu nothing is passed until the game resumes.
func set_auto_passing(is_on: bool) -> void:
	_presenter.set_auto_passing(is_on)
	_pause_menu.show_auto_pass(is_on)
	_settings.is_auto_passing = is_on
	_settings.save_to(settings_path)


## Turns Auto-tap on or off for the encounter that is running, and keeps the choice for the
## next one. A payment already under way stays with whoever was making it.
func set_auto_tapping(is_on: bool) -> void:
	_presenter.set_auto_tapping(is_on)
	_pause_menu.show_auto_tap(is_on)
	_settings.is_auto_tapping = is_on
	_settings.save_to(settings_path)


## Starts a Yield, or ends the one in force (the Yield Turn box). One started while the
## Hero is declaring attackers or blockers also confirms them as they stand, as the Pass
## Button would: the Hero who yields is done with the turn, and a second click to say "no
## attacks" would be one too many (A494).
func toggle_yield() -> void:
	if _is_paused:
		return
	var is_starting: bool = not _presenter.is_yielding()
	_presenter.set_yielding(is_starting)
	var is_declaring: bool = _snapshot.decision is DeclareAttackersDecision or _snapshot.decision is DeclareBlockersDecision
	if is_starting and is_declaring and _selection.is_active() and _selection.is_complete():
		_answer(_selection.answer())
	else:
		_redraw()


func game_speed() -> GameSpeed.Speed:
	return _speed


## Plays at [param speed] from now on, the encounter that is running included, and keeps
## the choice for the next one.
func set_game_speed(speed: GameSpeed.Speed) -> void:
	_speed = speed
	_pause_menu.show_game_speed(speed)
	_apply_speed()
	_settings.game_speed = speed
	_settings.save_to(settings_path)


## Gives a paced screen Pacing's numbers at the Game Speed in use.
func _apply_speed() -> void:
	if _paced_presenter == null:
		return
	_paced_presenter.action_wait_msec = GameSpeed.msec(Pacing.ACTION_MSEC, _speed)
	_paced_presenter.mana_wait_msec = GameSpeed.msec(Pacing.MANA_MSEC, _speed)
	_paced_presenter.step_wait_msec = GameSpeed.msec(Pacing.STEP_MSEC, _speed)
	_motion.seconds = GameSpeed.seconds(Pacing.MOVE_SECONDS, _speed)
	_flights.seconds = GameSpeed.seconds(Pacing.FLIGHT_SECONDS, _speed)
	_flights.gap_seconds = GameSpeed.seconds(Pacing.DRAW_GAP_SECONDS, _speed)
	_overlay.motion().seconds = GameSpeed.seconds(Pacing.DEAL_SECONDS, _speed)
	_overlay.motion().gap_seconds = GameSpeed.seconds(Pacing.DEAL_GAP_SECONDS, _speed)
	set_ease_seconds(GameSpeed.seconds(Pacing.EASE_SECONDS, _speed))


## Lets Glows, marks and windows ease in and out over [param seconds] (Pacing.EASE_SECONDS
## in a real encounter). Tests and screenshots leave it at none.
func set_ease_seconds(seconds: float) -> void:
	_ease_seconds = seconds
	for window: ZoneWindow in [_stack_window, _choice_window, _emblem_windows[HERO], _emblem_windows[VILLAIN]]:
		window.ease_seconds = seconds
	for key: String in _pile_windows:
		_pile_windows[key].ease_seconds = seconds
		_pile_windows[key].glow_seconds = seconds
	_option_menu.ease_seconds = seconds
	_pause_menu.ease_seconds = seconds


## Shows the encounter [param presenter] runs, and starts it.
func begin(presenter: EncounterPresenter) -> void:
	_presenter = presenter
	_presenter.changed.connect(_show)
	_presenter.start()


func _process(delta: float) -> void:
	if _presenter == null:
		return
	# A move in flight finishes under the Pause Menu (A368).
	advance_motion(delta)
	if _is_paused:
		return
	set_hold_key_down(Input.is_key_pressed(hold_key()))
	_presenter.poll()
	_spread_hand(EncounterLayout.ease_weight(HAND_EASE, delta))
	_light_hand(EncounterLayout.ease_weight(HAND_LIGHT_EASE, delta))
	follow_preview(_ease_seconds)


## A press on a card of the hand is taken here, before anything under the card can have it:
## a card that has risen under the cursor lies over the Hero's lands, and a land that can be
## tapped would otherwise take a press on the card's top edge. Only what is drawn over the
## hand comes first (_is_covered). While a card is pressed or held, the mouse is followed
## wherever it goes, over windows and buttons too.
func _input(event: InputEvent) -> void:
	_pin_with(event)
	if _is_trigger_pressed():
		_follow_trigger(event)
		return
	var mouse: InputEventMouse = make_input_local(event) as InputEventMouse
	var click: InputEventMouseButton = mouse as InputEventMouseButton
	if not _drag.is_pressed() and not _drag.is_holding():
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _is_covered(click.position) \
				and press_hand(click.position, click.double_click):
			get_viewport().set_input_as_handled()
		return
	if mouse is InputEventMouseMotion:
		drag_to(mouse.position)
	if click == null:
		return
	if click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		release_hand(click.position)
	elif click.button_index == MOUSE_BUTTON_RIGHT and click.pressed and _drag.is_holding():
		cancel_drag()
		get_viewport().set_input_as_handled()


## Whether a trigger being ordered is pressed or held.
func _is_trigger_pressed() -> bool:
	return _trigger_list != null and is_instance_valid(_trigger_list) and _trigger_list.is_pressed()


## While a trigger is pressed or held the mouse is followed wherever it goes, as it is for
## a card of the hand: the entry moves with it, letting go puts it down, and a right-click
## puts it back (A394).
func _follow_trigger(event: InputEvent) -> void:
	var mouse: InputEventMouse = _trigger_list.make_input_local(event) as InputEventMouse
	var click: InputEventMouseButton = mouse as InputEventMouseButton
	if mouse is InputEventMouseMotion:
		_trigger_list.drag_to(mouse.position)
	elif click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		_trigger_list.drag_to(click.position)
		_trigger_list.release()
	elif click != null and click.button_index == MOUSE_BUTTON_RIGHT and click.pressed and _trigger_list.is_holding():
		_trigger_list.cancel()
		get_viewport().set_input_as_handled()


## A press that no card of the hand, window, button or ClickCatcher took lands here, on the
## screen itself: a click on the empty board. It cannot be taken in _unhandled_input(): this
## Control stops the mouse, so a press never gets that far.
func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		click_empty_board()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	# A key can arrive before an encounter has begun.
	if _presenter == null or key == null or not key.pressed or key.echo:
		return
	press_key(key.keycode)


func _exit_tree() -> void:
	# Never leave a worker thread running an encounter nobody is showing.
	if _presenter != null:
		_presenter.wait_until_idle()


## Does what pressing [param keycode] does. While a row of the Controls Page waits for a key,
## the key is that row's, Escape only stopping the wait. Otherwise Escape lets the Pinned
## card go if there is one, and if not opens and closes the Pause Menu; and while the menu
## is closed any other key does what the Key Bindings say: it passes, undoes, or cancels
## as the Info Panel's Cancel button does when that is showing (ADR 0034).
func press_key(keycode: Key) -> void:
	if _is_paused and _pause_menu.is_waiting_for_key():
		_pause_menu.take_key(keycode)
	elif keycode == KEY_ESCAPE and not _is_paused and _inspection.pinned() != Inspection.NOTHING:
		# Escape lets the Pinned card go before it opens the Pause Menu (A459).
		let_pinned_go()
	elif keycode == KEY_ESCAPE:
		set_paused(not _is_paused)
	elif _is_paused:
		return
	else:
		match _settings.key_bindings.pressed_action(keycode):
			KeyBindings.Action.PASS:
				pass_priority()
			KeyBindings.Action.UNDO:
				undo()
			KeyBindings.Action.CANCEL:
				if _info.cancel_button() != null:
					_command(_presenter.cancel_cast)


## The Hold Key (game glossary): whichever key holding priority is bound to.
func hold_key() -> Key:
	return _settings.key_bindings.key_of(KeyBindings.Action.HOLD)


## The Key Bindings in use.
func key_bindings() -> KeyBindings:
	return _settings.key_bindings


## A key was bound on the Controls Page, or every key reset: the bindings are kept and the
## buttons that name a key name the new one.
func _on_keys_changed() -> void:
	_settings.save_to(settings_path)
	_show_key_labels()


## The Pass Button, the Undo button and the Cancel button each name the key that does
## what they do.
func _show_key_labels() -> void:
	var keys: KeyBindings = _settings.key_bindings
	_pass_button.show_key(keys.label_of(KeyBindings.Action.PASS))
	_panels[HERO].show_undo_key(keys.label_of(KeyBindings.Action.UNDO))
	_info.show_cancel_key(keys.label_of(KeyBindings.Action.CANCEL))


## While a choice is being made the Pass Button confirms it: it reads [param text] and can
## be pressed only when [param is_complete]. Undo is open whenever there is a click to take
## back ([param can_undo]).
func _show_confirm(text: String, is_complete: bool, can_undo: bool) -> void:
	_pass_button.show_confirm(text, is_complete)
	if can_undo:
		_panels[HERO].show_undo(true)


## Opens or closes the Pause Menu. While it is open nothing on the board can be done and the
## presenter collects nothing from the Villain, so the game carries on from exactly where it
## was (A289, A299).
func set_paused(is_on: bool) -> void:
	if _snapshot == null:
		return
	_is_paused = is_on
	_presenter.set_paused(is_on)
	_option_menu.close()
	if is_on:
		# A card being held goes back to the hand (A381).
		cancel_drag()
		_pause_menu.show_auto_pass(_presenter.is_auto_passing())
		_pause_menu.show_auto_tap(_presenter.is_auto_tapping())
		_pause_menu.open(_regions["battlefield"], not _snapshot.is_over())
	else:
		_pause_menu.close()


func is_paused() -> bool:
	return _is_paused


## Whether the Hold Key is down: nothing is passed for the Hero while it is, and the
## Hold Panel says so.
func set_hold_key_down(is_down: bool) -> void:
	_presenter.is_hold_key_down = is_down
	_hold_panel.set_key_down(is_down)


## What a click on nothing does: the blockers picked up are put down, unassigned (A314).
func click_empty_board() -> void:
	if not _is_paused and _selection.put_down():
		_error = ""
		_redraw()


## Passes priority, as the pass button and the space bar do. While a combat decision is
## being answered it confirms the selection instead, once that is complete, and while
## triggers are being ordered it confirms their order, and while cards are being put on the
## bottom or chosen to discard it confirms those.
func pass_priority() -> void:
	if _picks.is_active():
		_confirm_picks()
	elif _trigger_order.is_active():
		if not _is_paused:
			_answer(_trigger_order.answer())
	elif not _selection.is_active():
		_command(_presenter.pass_priority)
	elif _selection.is_complete() and not _is_paused:
		_answer(_selection.answer())


## Undoes the Hero's last click of a half-made selection or choice of cards, or their last move of a trigger,
## and otherwise their last answer, as the undo button and Z do (A320, A339).
func undo() -> void:
	if not _is_paused and _picks.undo():
		_show_picks_changed()
	elif _picks.is_bottoming():
		# Keeping is final (A406): with no card to take back there is nothing to undo.
		return
	elif not _is_paused and _trigger_order.undo():
		_show_trigger_order()
	elif not _is_paused and _selection.undo():
		_error = ""
		_redraw()
	else:
		_command(_presenter.undo)


## Leaves for [param scene], once a thinking Villain has finished.
func leave(scene: String) -> void:
	_presenter.wait_until_idle()
	navigate.call(scene)


## Whether something drawn over the hand is under [param cursor]: an open window, the
## Option Menu, or the opening-hand overlay. A press there is theirs, never the card's
## beneath.
func _is_covered(cursor: Vector2) -> bool:
	if _option_menu.is_open():
		return true
	var windows: Array[Control] = [_stack_window, _choice_window]
	if _overlay.is_open():
		windows.append(_overlay)
	windows.append_array(_emblem_windows.values())
	windows.append_array(_pile_windows.values())
	for window: Control in windows:
		# A window fading out is already closed: the cursor is not over it.
		if Easing.is_shown(window) and Rect2(window.position, window.size).has_point(cursor):
			return true
	return false


## The card of the Hero's hand that [param cursor] is on, as a Card Identity, or
## DragCard.NONE. The card nearest the cursor counts where it is drawn and also where the
## cursor is sending it: the hand eases toward the cursor over several frames, fewer when a
## frame is slow, and a press made on arriving must not miss the card for being early.
func hand_card_at(cursor: Vector2) -> int:
	if _hand_faces.is_empty():
		return DragCard.NONE
	var card: Vector2 = _hand_faces[0].size
	var rest: Array[Vector2] = _hand_rest_now()
	if not EncounterLayout.is_cursor_over_hand(rest, card, cursor):
		return DragCard.NONE
	var drawn: int = hand_card_under(cursor)
	if drawn != DragCard.NONE:
		return drawn
	var index: int = roundi(EncounterLayout.hand_cursor_place(rest, card, cursor))
	var is_on_it: bool = Rect2(_hand_faces[index].position, card).grow(8.0).has_point(cursor) \
			or Rect2(hand_places(cursor)[index], card).grow(8.0).has_point(cursor)
	return _hand_cards[index] if is_on_it else DragCard.NONE


## The card of the Hero's hand drawn under [param cursor], as a Card Identity, or
## DragCard.NONE: the one seen there, turned and parted as it is, and of two that overlap
## the one on top. This is the card that is lit.
func hand_card_under(cursor: Vector2) -> int:
	var found: int = DragCard.NONE
	for index: int in _hand_faces.size():
		var face: CardFace = _hand_faces[index]
		if not Rect2(Vector2.ZERO, face.size).has_point(face.get_transform().affine_inverse() * cursor):
			continue
		# A later card is drawn over an earlier one, and a raised one over them all.
		if face.z_index > 0:
			return _hand_cards[index]
		found = _hand_cards[index]
	return found


## The left button went down at [param cursor]. On a card of the hand this is the start of
## a drag, or with [param is_double] it plays the card: at once if there is one way to, or
## from the Option Menu, opened there, if there are several (A377). One click alone does
## nothing (A371). A double-click on a card that cannot be played is a press like any
## other: two tries at a drag in quick succession arrive as one, and the second must not be
## swallowed. Returns whether a card of the hand was under the cursor.
func press_hand(cursor: Vector2, is_double: bool) -> bool:
	var card_id: int = DragCard.NONE if _is_paused or _snapshot == null else hand_card_at(cursor)
	if card_id == DragCard.NONE:
		return false
	var options: Array[ClickOption] = _hand_options(card_id) if is_double else ([] as Array[ClickOption])
	if options.size() > 1:
		_option_menu.open(options, cursor, _regions["battlefield"])
	elif options.size() == 1:
		_answer(options[0].answer)
	else:
		_drag.press(card_id, cursor, cursor - _hand_faces[_hand_cards.find(card_id)].position)
	return true


## The mouse moved to [param cursor] with a card pressed or held. Once it has moved far
## enough the card is picked up and follows the cursor; the hand makes room for it while it
## is over the hand's strip, and over the panels at the left it is let go of (A371).
func drag_to(cursor: Vector2) -> void:
	if _drag.move(cursor):
		_lift()
	if not _drag.is_holding():
		return
	if EncounterLayout.is_over_panels(cursor, _regions):
		cancel_drag()
		return
	var is_above: bool = EncounterLayout.is_above_hand(cursor, _regions)
	var gap: int = DragCard.NONE
	if not is_above:
		gap = EncounterLayout.hand_gap(_hand_faces.size(), _regions["hero_hand"], _lifted_face.size, cursor)
	if _drag.hover(is_above, gap):
		_lay_out_hand()
	_lifted_face.position = _drag.place()


## The left button came up at [param cursor]. A card that was pressed and never picked up
## has been clicked. A held card let go above the hand's strip is
## played: at once with one way to play it, from the Option Menu with several, the card
## waiting where it was let go (A372). One that cannot be played right now goes back to its
## place without a word (A380). Over the strip it is put down where the hand made room.
func release_hand(cursor: Vector2) -> void:
	drag_to(cursor)
	if not _drag.is_holding():
		if _drag.is_pressed():
			# Let go where it was pressed: a click, which chooses a card to discard (A400).
			var clicked: int = _drag.card_id()
			_drag.drop()
			_click_hand(clicked)
		return
	if not _drag.is_above():
		_put_down(_drag.gap())
		return
	var options: Array[ClickOption] = _hand_options(_drag.card_id())
	if options.is_empty():
		_put_back()
	elif options.size() > 1:
		_drag.wait()
		_lay_out_hand()
		_option_menu.open(options, cursor, _regions["battlefield"])
	else:
		# The answer brings a redraw of its own, accepted or refused, and a refused card
		# must not stay held with the button up.
		_drag.drop()
		_answer(options[0].answer)


## Lets go of a card that is pressed, held or waiting on the Option Menu, back to its place
## in the hand: a right-click, the panels at the left, or the Pause Menu opening.
func cancel_drag() -> void:
	if _drag.is_lifted():
		_put_back()
	else:
		_drag.drop()


func drag_card() -> DragCard:
	return _drag


func hand_order() -> HandOrder:
	return _hand_order


## The face of the card being held or waiting on the Option Menu, or null.
func lifted_face() -> CardFace:
	return _lifted_face


## The Inspector, which lies over the sidebar while a card is pinned (ADR 0033).
func inspector() -> Inspector:
	return _inspector


## Which card is pinned, and so shown in the Inspector.
func inspection() -> Inspection:
	return _inspection


## A right-click at [param cursor]: on a card it pins that card, and on the Pinned card or
## on nothing it lets the Pinned card go. On the Inspector itself it does nothing, and
## while a card or a trigger is held it puts that down and pins nothing.
func right_click_at(cursor: Vector2) -> void:
	if _snapshot == null or _is_paused or _is_over_inspector(cursor):
		return
	_inspection.set_dragging(_is_dragging())
	_inspection.right_click(inspectable_at(cursor))
	_show_inspected(false)


## Lets the Pinned card go.
func let_pinned_go() -> void:
	_inspection.let_go()
	_show_inspected(false)


## The card drawn at [param cursor] that a right-click there pins, as a Game Object ID, or
## Inspection.NOTHING. An entry of an open window comes first, since windows lie over
## everything; then, through the pregame, a card of the opening hand, and otherwise a card
## of the Hero's hand and then a permanent. A card the Hero may not see is never there: the
## Villain's hand and a library's unknown cards are drawn as backs with no Game Object.
## Worked out from where things are drawn, as _hovered_answer() is.
func inspectable_at(cursor: Vector2) -> int:
	var at: Vector2 = get_global_transform() * cursor
	var entries: Dictionary[int, Control] = _inspectable_entries()
	for object_id: int in entries:
		if entries[object_id].is_visible_in_tree() and entries[object_id].get_global_rect().has_point(at):
			return object_id
	if _overlay.is_open() and not _overlay.is_closing():
		return _opening_card_at(cursor)
	if _is_covered(cursor):
		return Inspection.NOTHING
	var in_hand: MmObjectView = _hand_view(hand_card_under(cursor)) if not _hand_faces.is_empty() else null
	if in_hand != null:
		return in_hand.id
	for object_id: int in _faces:
		var face: Control = _faces[object_id]
		if _snapshot.looks.has(object_id) and is_instance_valid(face) and face.is_visible_in_tree() \
				and Rect2(Vector2.ZERO, _face_sizes[object_id]).has_point(face.get_global_transform().affine_inverse() * at):
			return object_id
	return Inspection.NOTHING


## The card of the opening hand drawn at [param cursor], or Inspection.NOTHING: none while
## cards are in the air, when they may be face down, and none under an Emblems window.
func _opening_card_at(cursor: Vector2) -> int:
	if _overlay.motion().is_moving():
		return Inspection.NOTHING
	for window: ZoneWindow in _emblem_windows.values():
		if Easing.is_shown(window) and Rect2(window.position, window.size).has_point(cursor):
			return Inspection.NOTHING
	var object_id: int = _overlay.card_at(cursor - _overlay.position)
	return object_id if object_id != OpeningHandOverlay.NONE and _snapshot.looks.has(object_id) else Inspection.NOTHING


## Every card shown in an open window, by Game Object ID: the stack's entries, each Emblem
## and the face-up cards of the piles.
func _inspectable_entries() -> Dictionary[int, Control]:
	var entries: Dictionary[int, Control] = {}
	if Easing.is_shown(_stack_window):
		for object_id: int in _stack_items:
			var entry: StackEntry = stack_entry_of(object_id)
			if entry != null and is_instance_valid(entry):
				entries[object_id] = entry
	for player_id: int in _emblem_windows:
		var window: ZoneWindow = _emblem_windows[player_id]
		if not Easing.is_shown(window):
			continue
		var rows: Array[Node] = window.body().get_children()
		var emblems: Array[MmObjectView] = _emblems_of(player_id)
		if rows.size() != emblems.size():
			continue
		for index: int in rows.size():
			entries[emblems[index].id] = rows[index] as Control
	for key: String in _pile_windows:
		var pile: PileWindow = _pile_windows[key]
		if not Easing.is_shown(pile):
			continue
		for object_id: int in pile.entries():
			if object_id != PileWindow.UNKNOWN and pile.face_of(object_id) != null:
				entries[object_id] = pile.face_of(object_id)
	return entries


## The Emblems [param player_id] controls, in the order their window lists them.
func _emblems_of(player_id: int) -> Array[MmObjectView]:
	var emblems: Array[MmObjectView] = []
	for emblem: MmObjectView in _snapshot.view.command:
		if emblem.controller_id == player_id:
			emblems.append(emblem)
	return emblems


## Whether a card of the hand or a trigger being ordered is held.
func _is_dragging() -> bool:
	return _drag.is_holding() or (_is_trigger_pressed() and _trigger_list.is_holding())


func _is_over_inspector(cursor: Vector2) -> bool:
	return Easing.is_shown(_inspector) and Rect2(_inspector.position, _inspector.size).has_point(cursor)


## A press of a mouse button, before anything else has it: a right-click pins or lets go,
## and a left-click anywhere but on the Inspector lets the Pinned card go and then does
## whatever it does (A459, A461).
func _pin_with(event: InputEvent) -> void:
	var click: InputEventMouseButton = make_input_local(event) as InputEventMouseButton
	if click == null or not click.pressed or _snapshot == null or _is_paused:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		right_click_at(click.position)
	elif click.button_index == MOUSE_BUTTON_LEFT and not _is_over_inspector(click.position) \
			and _inspection.pinned() != Inspection.NOTHING:
		let_pinned_go()


## After a redraw: cards that are gone are forgotten, the Inspector is where the sidebar
## is, and what it shows is drawn again from the new snapshot.
func _redraw_inspector() -> void:
	var seen_ids: Array[int] = []
	seen_ids.assign(_snapshot.looks.keys())
	_inspection.keep_only(seen_ids)
	_inspector.position = _regions["sidebar"].position
	_inspector.size = _regions["sidebar"].size
	_show_inspected(true)


## Shows the Pinned card, if it or the snapshot has changed, and puts the ring on it. An ability on the stack is read as the card it came from: as
## that card is now if it can still be seen, and otherwise as its Original.
func _show_inspected(is_new_snapshot: bool) -> void:
	var shown: int = _inspection.shown()
	_show_pin()
	if shown == _inspected and not is_new_snapshot:
		return
	_inspected = shown
	if shown == Inspection.NOTHING:
		Easing.disappear(_inspector, _ease_seconds)
		return
	var subject: int = shown
	var look: CardLook = _snapshot.look_of(shown)
	var seen: MmObjectView = _seen(shown)
	if seen != null and seen.ability != null:
		if _snapshot.looks.has(seen.source_object_id):
			subject = seen.source_object_id
			look = _snapshot.look_of(subject)
		elif _snapshot.original_of(shown) != null:
			look = _snapshot.original_of(shown)
	var glow: Variant = Inspector.glow_of(_snapshot.rarity_of(shown)) if _snapshot.has_rarity(shown) else null
	_inspector.show_card(shown, look, _snapshot.original_of(shown), glow, _snapshot.state_list_of(subject),
		_ease_seconds if Easing.is_shown(_inspector) else 0.0)
	Easing.appear(_inspector, _ease_seconds)


## Puts the ring on whatever the Pinned card is drawn as, and takes it off what it was on.
func _show_pin() -> void:
	var host: Control = _pin_host_now()
	if _pin_host != null and is_instance_valid(_pin_host) and _pin_host != host:
		BorderEffects.remove_pin(_pin_host)
	_pin_host = host
	if host != null and not BorderEffects.has_pin(host):
		BorderEffects.add_pin(host, _face_sizes[_inspection.pinned()] if _faces.get(_inspection.pinned()) == host else host.size)


## What the Pinned card is drawn as right now, or null: an entry of a window, a card of the
## opening hand, a card of the hand, or a permanent's face.
func _pin_host_now() -> Control:
	var pinned: int = _inspection.pinned()
	if pinned == Inspection.NOTHING or _snapshot == null:
		return null
	var entries: Dictionary[int, Control] = _inspectable_entries()
	if entries.has(pinned):
		return entries[pinned]
	if _overlay.is_open():
		return _overlay.face_of(pinned)
	var seen: MmObjectView = _seen(pinned)
	if seen != null and _snapshot.view.hand.has(seen) and _hand_cards.has(seen.card_id):
		return _hand_faces[_hand_cards.find(seen.card_id)]
	var face: Control = _faces.get(pinned, null) as Control
	return face if face != null and is_instance_valid(face) else null


## Lets [param delta] seconds of Face Motion and Card Flights go by, as every frame does:
## faces on their way are drawn further along, ghosts fade, block lines follow their
## creatures, and cards in the air fly on.
func advance_motion(delta: float) -> void:
	var was_moving: bool = _motion.is_moving()
	_motion.advance(delta)
	if was_moving:
		_pose_faces()
		_show_block_lines()
	_flights.advance(delta)
	_pose_flights()
	if _has_draw_landed:
		_has_draw_landed = false
		_is_hand_easing = true
		_redraw()
		_is_hand_easing = false


func face_motion() -> FaceMotion:
	return _motion


func card_flights() -> CardFlights:
	return _flights


## The card drawn in the air on its way to being Game Object [param object_id], or null
## once it has landed.
func flight_card_of(object_id: int) -> FlightCard:
	return _flight_cards.get(object_id, null) as FlightCard


## The fading face of Game Object [param object_id], which has left the battlefield, or
## null once it has gone.
func ghost_of(object_id: int) -> BattlefieldFace:
	return _ghosts.get(object_id, null) as BattlefieldFace


## The Control that draws Game Object [param object_id], or null if none is on screen.
func face_of(object_id: int) -> Control:
	return _faces.get(object_id, null) as Control


func player_panel(player_id: int) -> PlayerPanel:
	return _panels[player_id]


func stack_window() -> ZoneWindow:
	return _stack_window


## What the Stack Window lists, from the top of the stack down.
func stack_entries() -> Array[StackEntry]:
	return _stack_entries


## The Stack Window's entry for Game Object [param object_id], or null.
func stack_entry_of(object_id: int) -> StackEntry:
	var ids: Array = _stack_items.keys()
	return _stack_entries[ids.find(object_id)] if ids.has(object_id) else null


## The arrows between the Stack Window's entries, or null while the stack is empty.
func stack_arrows() -> StackArrows:
	return _stack_arrows


## The Hero's half-made order for the triggers being asked about.
func trigger_order() -> TriggerOrder:
	return _trigger_order


## The triggers being ordered, as the Stack Window lists them above the stack.
func trigger_entries() -> Array[StackEntry]:
	if _trigger_list == null or not is_instance_valid(_trigger_list):
		return []
	return _trigger_list.entries_in_order()


## The list the triggers being ordered are dragged in, or null when none are.
func trigger_list() -> TriggerList:
	return _trigger_list if _trigger_list != null and is_instance_valid(_trigger_list) else null


## The window that asks which replacement effect applies first.
func choice_window() -> ZoneWindow:
	return _choice_window


func choice_entries() -> Array[ZoneEntry]:
	return _choice_entries


## What takes a click on the choice window's entry number [param index].
func choice_catcher(index: int) -> ClickCatcher:
	return ClickCatcher.of(_choice_entries[index])


## The Zone Window of the pile in Region [param key], such as "hero_graveyard".
func pile_window(key: String) -> PileWindow:
	return _pile_windows[key]


## What takes a click on the pile in Region [param key].
func pile_catcher(key: String) -> ClickCatcher:
	return ClickCatcher.of(_pile_hosts[key])


## The colors the pile in Region [param key] glows in: a target's, while a card in it can
## be chosen.
func pile_glow(key: String) -> Array[Color]:
	return BorderEffects.glow_colors(_pile_hosts[key])


func emblems_window(player_id: int) -> ZoneWindow:
	return _emblem_windows[player_id]


func opening_overlay() -> OpeningHandOverlay:
	return _overlay


func opening_hand() -> OpeningHand:
	return _opening


## The Hero's half-made choice of cards to put on the bottom or to discard.
func card_picks() -> CardPicks:
	return _picks


func info_panel() -> InfoPanel:
	return _info


func hold_panel() -> HoldPanel:
	return _hold_panel


func option_menu() -> OptionMenu:
	return _option_menu


func pause_menu() -> PauseMenu:
	return _pause_menu


## The Hero's half-made answer to the combat decision being asked.
func selection() -> CombatSelection:
	return _selection


func block_lines() -> BlockLines:
	return _block_lines


## The damage stepper on Game Object [param object_id], or null.
func stepper_of(object_id: int) -> DamageStepper:
	return _steppers.get(object_id, null) as DamageStepper


## The damage stepper on [param player_id]'s portrait, or null.
func player_stepper(player_id: int) -> DamageStepper:
	return _player_steppers.get(player_id, null) as DamageStepper


## What takes a click on Game Object [param object_id], or null if clicking it does nothing.
func click_catcher(object_id: int) -> ClickCatcher:
	return ClickCatcher.of(_faces[object_id]) if _faces.has(object_id) else null


## How many card backs stand for the Villain's hand.
func villain_card_back_count() -> int:
	return _card_backs.size()


## The scrolling line named [param key] ("hero_creatures", "hero_others",
## "villain_creatures" or "villain_others"), or null if that player has none there.
func line(key: String) -> ScrollRow:
	return _lines.get(key, null) as ScrollRow


## What is written under the pile in Region [param key], such as "Exile (0)".
func pile_text(key: String) -> String:
	return _pile_labels[key].text


## The Hero's controls live in their player panel, under the Emblems button.
func pass_button() -> Button:
	return _pass_button


func undo_button() -> Button:
	return _panels[HERO].undo_button()


func yield_button() -> Button:
	return _panels[HERO].yield_button()


## The end-of-encounter banner, or null while the encounter goes on. It is not on the
## board, so that no block line is drawn across it, and a redraw replaces it.
func banner() -> Control:
	return _banner


## The words on the end-of-encounter banner, or "" while the encounter goes on.
func banner_text() -> String:
	return (_banner.get_meta("text") as String) if _banner != null else ""


func _answer(hero_answer: Variant) -> void:
	_command(_presenter.answer.bind(hero_answer))


## Runs a presenter command and shows why it was refused, if it was. An accepted one
## brings a new snapshot, which clears the last reason.
func _command(command: Callable) -> void:
	var reason: String = command.call()
	if reason != "":
		_error = reason
		_redraw()


func _show(snapshot: EncounterSnapshot) -> void:
	if not _selection.is_for(snapshot.decision if CombatSelection.covers(snapshot.decision) else null):
		_selection = CombatSelection.new(snapshot.decision)
	var order: OrderTriggersDecision = snapshot.decision as OrderTriggersDecision
	if not _trigger_order.is_for(order):
		_trigger_order = TriggerOrder.new(order)
	if not _picks.is_for(snapshot.decision if CardPicks.covers(snapshot.decision) else null):
		_picks = CardPicks.new(snapshot.decision)
	# Where each card that changed zones was is read from what is still drawn.
	var begun: Array[CardFlights.Route] = _begin_flights(snapshot)
	_opening.read(snapshot)
	_snapshot = snapshot
	_error = ""
	_is_snapping = _is_snapping or snapshot.is_rewind
	var hand: Array[int] = []
	for card: MmObjectView in snapshot.view.hand:
		hand.append(card.card_id)
	_hand_order.update(hand, snapshot.is_rewind)
	if not hand.has(_drag.card_id()):
		# The card being held has left the hand (A380).
		_drag.drop()
	# An answer means something else in a new snapshot, so the preview is asked for afresh,
	# and shown at once: the cursor may not have moved.
	_previewed = NO_PREVIEW
	_redraw()
	follow_preview(0.0)
	_aim_flights(begun)


## A pile was clicked: its window opens, or closes if it was open.
func _toggle_pile(key: String) -> void:
	if _is_paused:
		return
	var window: PileWindow = _pile_windows[key]
	if window.is_open():
		window.close()
	else:
		_open_pile(key)
	_pile_state.toggled(key, window.is_open(), _clicks)


## Opens the window of the pile in Region [param key], with what the zone holds now: beside
## its pile the first time, and where it was left after that.
func _open_pile(key: String) -> void:
	var window: PileWindow = _pile_windows[key]
	if not _placed_piles.has(key):
		window.position = EncounterLayout.pile_window_position(_regions[key], window.size, _placed_piles.size())
		_placed_piles.append(key)
	window.fit()
	_fill_pile_window(key)
	window.open()
	window.move_to_front()


## Shows in the window of the pile in Region [param key] what its zone holds.
func _fill_pile_window(key: String) -> void:
	var view: MmPlayerView = _snapshot.view
	var player_id: int = HERO if key.begins_with("hero") else VILLAIN
	var cards: Array = view.graveyards.get(player_id, [])
	var zone_name: String = "Graveyard"
	if key.ends_with("exile"):
		cards = view.exiles.get(player_id, [])
		zone_name = "Exile"
	elif key.ends_with("library"):
		cards = view.libraries.get(player_id, [])
		zone_name = "Library"
	_pile_windows[key].show_cards("%s %s" % [_snapshot.names.possessive(player_id), zone_name], cards, _snapshot, _clicks)


## Opens the pile windows a target is only to be found in, closes the ones that were open
## for a target now chosen, and shows in every open one what its zone holds now. A closed
## window is filled when it opens, so a redraw pays nothing for it.
func _show_pile_windows() -> void:
	var open: Array[String] = []
	for key: String in _pile_windows:
		if _pile_windows[key].is_open():
			open.append(key)
	_pile_state.follow(_snapshot.decision, _clicks, open)
	for key: String in _pile_state.to_close:
		_pile_windows[key].close()
	for key: String in _pile_state.to_open:
		_open_pile(key)
	for key: String in _pile_windows:
		if _pile_windows[key].is_open():
			_fill_pile_window(key)


## What takes a click on the pile in Region [param key], over its card and its label, and
## glows while a card in it can be chosen as a target.
func _add_pile_host(key: String, pile_rect: Rect2) -> void:
	var card: Vector2 = Vector2(EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT, EncounterLayout.PILE_HEIGHT)
	var host: Control = Control.new()
	host.position = pile_rect.position + Vector2((pile_rect.size.x - card.x) / 2.0, 0)
	host.size = card
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(host)
	_pile_hosts[key] = host
	if _clicks.piles().has(key):
		BorderEffects.add_glow(host, card, DecisionClicks.color_of(DecisionClicks.Kind.TARGET), _ease_seconds)
	ClickCatcher.add(host, card + Vector2(0, EncounterLayout.PILE_LABEL)).clicked.connect(_toggle_pile.bind(key))


func _toggle_emblems(player_id: int) -> void:
	var window: ZoneWindow = _emblem_windows[player_id]
	window.set_open(not window.is_open())
	window.move_to_front()


func _concede() -> void:
	_command(_presenter.concede)
	set_paused(false)


## A permanent that a click answers something on was clicked: one answer is given at once,
## and several open the Option Menu where the cursor is (A285, A286).
func _on_object_clicked(object_id: int) -> void:
	if _is_paused:
		return
	if _selection.is_clickable(object_id):
		if _selection.click(object_id):
			_error = ""
			_redraw()
		elif not _selection.refused().is_empty():
			_error = _refusal_text(_selection.refused())
			_redraw()
		return
	var options: Array[ClickOption] = _clicks.options_of(object_id)
	if options.size() == 1:
		_answer(options[0].answer)
	elif options.size() > 1:
		_option_menu.open(options, get_local_mouse_position(), _regions["battlefield"])


## Why a group of blockers was not assigned: which of them cannot block the attacker
## clicked (A432).
func _refusal_text(refused: Array) -> String:
	var names: Dictionary[int, String] = {}
	for seen: MmObjectView in _snapshot.visible_objects():
		names[seen.id] = seen.name
	var blockers: PackedStringArray = []
	for pair: Array in refused:
		blockers.append(names.get(pair[0], "That creature"))
	return "%s cannot block %s." % [" and ".join(blockers), names.get(refused[0][1], "that attacker")]


## Draws everything from the latest snapshot. Reads nothing else, so it is safe while the
## Villain is thinking.
func _redraw() -> void:
	if _snapshot == null:
		return
	_option_menu.close()
	_clear_marks()
	_glowed_before.clear()
	for object_id: int in _faces:
		if is_instance_valid(_faces[object_id]) and BorderEffects.glow_color(_faces[object_id]) != null:
			_glowed_before[object_id] = BorderEffects.glow_colors(_faces[object_id])
	_is_redrawing = true
	if _is_snapping or size != _drawn_size:
		# A rewind or a window of another size: every card in the air is where it lands.
		_clear_flights()
	_overlay.glow_seconds = _ease_seconds
	for panel: PlayerPanel in _panels.values():
		panel.glow_seconds = _ease_seconds
	var unseen: Array[int] = _unseen_faces()
	var hand_was: Dictionary[int, Transform2D] = {}
	if _is_hand_easing:
		for index: int in _hand_faces.size():
			hand_was[_hand_cards[index]] = Transform2D(_hand_faces[index].rotation, _hand_faces[index].position)
	for child: Node in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	_faces.clear()
	_face_sizes.clear()
	_hand_faces.clear()
	_hand_rest.clear()
	_hand_cards.clear()
	_card_backs.clear()
	_lines.clear()
	_line_ids.clear()
	_steppers.clear()
	_player_steppers.clear()
	_pile_labels.clear()
	_pile_hosts.clear()
	if _banner != null:
		remove_child(_banner)
		_banner.queue_free()
	_banner = null
	var view: MmPlayerView = _snapshot.view
	# While the Villain thinks the Hero is asked nothing, so nothing glows or takes a click.
	var glow: DecisionClicks = DecisionClicks.of(null if _snapshot.is_over() else _snapshot.decision, view)
	if _snapshot.payment_left != null and not _snapshot.is_over():
		# Auto-tap is paying: what it has still to tap glows until its turn comes.
		glow = DecisionClicks.of_payment(_snapshot.payment_left)
	# While blockers are picked up, the attackers any of them can block glow as targets (A313, A431).
	for attacker_id: int in _selection.target_ids():
		glow.glow_as(attacker_id, DecisionClicks.Kind.TARGET)
	_clicks = glow
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(size)
	_regions = regions
	_place_windows(regions["battlefield"])
	var plates: Array[Rect2] = []
	plates.assign(EncounterLayout.zone_plates(regions).values())
	_zone_plates.place(plates)

	var sidebar: ColorRect = ColorRect.new()
	sidebar.color = Color("#22262e")
	sidebar.position = regions["sidebar"].position
	sidebar.size = regions["sidebar"].size
	_board.add_child(sidebar)
	var middle: ColorRect = ColorRect.new()
	middle.color = Color(1, 1, 1, 0.12)
	middle.position = Vector2(regions["battlefield"].position.x, (regions["villain_nonlands"].end.y + regions["hero_nonlands"].position.y) / 2.0)
	middle.size = Vector2(regions["battlefield"].size.x, 2)
	_board.add_child(middle)

	_panels[VILLAIN].show_snapshot(_snapshot, glow, _presenter.stops, regions["villain_panel"], false, false)
	_panels[HERO].show_snapshot(_snapshot, glow, _presenter.stops, regions["hero_panel"], true, _presenter.is_yielding())
	_pass_button.place(regions["pass"])
	_pass_button.show_pass(_snapshot.decision is PriorityDecision)
	_show_key_labels()
	if _selection.is_active():
		_show_confirm(_selection.confirm_text(), _selection.is_complete(), _selection.can_undo())
	elif _trigger_order.is_active():
		_show_confirm("Confirm order", true, _trigger_order.can_undo())
	_add_player_stepper()
	_draw_villain_hand(view.hand_sizes.get(VILLAIN, 0) - _drawing_count(VILLAIN), regions["villain_hand"])
	_draw_row(_permanents(view, VILLAIN, true), regions["villain_lands"], glow)
	_draw_nonlands(view, VILLAIN, regions["villain_nonlands"], glow)
	_draw_nonlands(view, HERO, regions["hero_nonlands"], glow)
	_draw_row(_permanents(view, HERO, true), regions["hero_lands"], glow)
	# Through the pregame the overlay holds the hand, and its strip is empty (A384).
	if not _opening.is_open():
		_draw_hand(view, regions["hero_hand"], glow)
	for player_id: int in [VILLAIN, HERO]:
		var who: String = "hero" if player_id == HERO else "villain"
		_draw_library(view.library_sizes.get(player_id, 0), who + "_library", regions[who + "_library"])
		_draw_pile("Graveyard", view.graveyards.get(player_id, []), who + "_graveyard", regions[who + "_graveyard"])
		_draw_pile("Exile", view.exiles.get(player_id, []), who + "_exile", regions[who + "_exile"])
		for zone: String in ["library", "graveyard", "exile"]:
			_add_pile_host("%s_%s" % [who, zone], regions["%s_%s" % [who, zone]])
		_fill_emblems_window(view, player_id)
	_fill_stack_window(view)
	_fill_choice_window(view)
	_show_pile_windows()
	_info.show_snapshot(_snapshot, _error, regions["info"], _selection.hint())
	_info.show_undeclare(not _selection.attacker_ids().is_empty())
	_hold_panel.place(regions["hold"])
	_info.show_option(_release_text())
	_move_faces(unseen)
	_tint_arrows()
	_show_block_lines()
	if _snapshot.is_over():
		_draw_banner(view)
	_show_overlay()
	_show_picks()
	_spread_hand(1.0)
	# A card that was in the hand eases from where it was to make room for one that landed.
	for index: int in _hand_faces.size():
		if hand_was.has(_hand_cards[index]):
			_hand_faces[index].position = hand_was[_hand_cards[index]].origin
			_hand_faces[index].rotation = hand_was[_hand_cards[index]].get_rotation()
	_hide_landing_places()
	if _preview_plan() != null:
		_panels[HERO].mark_pool(_preview_plan().pool_types)
	_is_redrawing = false
	_glowed_before.clear()
	_redraw_inspector()


## How long [param object_id]'s Glow takes to become [param color] (null for none, or the
## colors of a Glow of two): through a redraw, no time if that is how it glowed before;
## otherwise the usual time.
func _glow_seconds_for(object_id: int, color: Variant) -> float:
	if not _is_redrawing:
		return _ease_seconds
	var colors: Array[Color] = []
	if color is Array:
		colors.assign(color)
	elif color != null:
		colors.append(color)
	var before: Array[Color] = []
	before.assign(_glowed_before.get(object_id, []))
	return 0.0 if before == colors else _ease_seconds


## The Stack Window and Emblems windows stay inside the battlefield; each opens at its own
## place the first time and afterwards stays where it was left.
func _place_windows(battlefield: Rect2) -> void:
	if not _are_windows_placed:
		_are_windows_placed = true
		_stack_window.position = Vector2(battlefield.end.x - 410, battlefield.position.y + 170)
		_choice_window.position = battlefield.get_center() - _choice_window.size / 2.0
		_emblem_windows[HERO].position = Vector2(battlefield.position.x + 400, battlefield.end.y - 240)
		_emblem_windows[VILLAIN].position = Vector2(battlefield.position.x + 400, battlefield.position.y + 10)
	for window: ZoneWindow in [_stack_window, _choice_window, _emblem_windows[HERO], _emblem_windows[VILLAIN]]:
		window.bounds = battlefield
		window.fit()
	for key: String in _pile_windows:
		_pile_windows[key].bounds = battlefield
		_pile_windows[key].fit()


## A player's lands, or their other permanents. Lands of one name stand together.
func _permanents(view: MmPlayerView, player_id: int, are_lands: bool) -> Array[MmObjectView]:
	var found: Array[MmObjectView] = []
	for permanent: MmObjectView in view.battlefield:
		var is_land: bool = permanent.card_types.has(MmCardTypes.CardType.LAND) and not permanent.is_creature
		if permanent.controller_id == player_id and is_land == are_lands:
			found.append(permanent)
	if not are_lands:
		return found
	var names: Array[String] = []
	for land: MmObjectView in found:
		names.append(land.name)
	var grouped: Array[MmObjectView] = []
	for index: int in EncounterLayout.land_order(names):
		grouped.append(found[index])
	return grouped


func _draw_row(permanents: Array[MmObjectView], row_rect: Rect2, glow: DecisionClicks) -> void:
	var is_tapped: Array[bool] = []
	for permanent: MmObjectView in permanents:
		is_tapped.append(permanent.is_tapped)
	var footprints: Array[Rect2] = EncounterLayout.row(is_tapped, row_rect)
	var height: float = EncounterLayout.row_face_height(is_tapped, row_rect)
	for index: int in permanents.size():
		var permanent: MmObjectView = permanents[index]
		var face: BattlefieldFace = BattlefieldFace.new()
		face.setup(_snapshot.look_of(permanent.id), height)
		face.position = footprints[index].position
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(face)
		_remember_face(permanent.id, face, footprints[index].size, glow)


## A player's nonland permanents: creatures toward the left and middle, and the rest to
## their right, smaller and set back (A276). Each group keeps its faces' size and scrolls
## when it overflows (A278). Once attackers are declared, creatures out of the combat are
## drawn smaller and those in it step toward the middle (A279).
func _draw_nonlands(view: MmPlayerView, player_id: int, row_rect: Rect2, glow: DecisionClicks) -> void:
	var is_hero: bool = player_id == HERO
	var who: String = "hero" if is_hero else "villain"
	var creatures: Array[MmObjectView] = []
	var others: Array[MmObjectView] = []
	var is_combat_on: bool = false
	for permanent: MmObjectView in view.battlefield:
		is_combat_on = is_combat_on or permanent.is_attacking
	for permanent: MmObjectView in _permanents(view, player_id, false):
		if permanent.is_creature:
			creatures.append(permanent)
		else:
			others.append(permanent)
	creatures = _fighting_first(creatures)
	var groups: Dictionary[String, Rect2] = EncounterLayout.nonland_groups(row_rect, _tapped(others), is_hero)
	var creature_heights: Array[float] = []
	for creature: MmObjectView in creatures:
		creature_heights.append(roundf(EncounterLayout.creature_height(row_rect)
				* EncounterLayout.bystander_scale(is_combat_on, _is_in_combat(creature))))
	var other_heights: Array[float] = []
	for other: MmObjectView in others:
		other_heights.append(EncounterLayout.others_height(row_rect))
	# The creatures' line reaches COMBAT_STEP past its Region toward the middle, so a
	# creature that steps forward is not cut off.
	var creature_rect: Rect2 = groups["creatures"]
	if is_hero:
		creature_rect.position.y -= EncounterLayout.COMBAT_STEP
	creature_rect.size.y += EncounterLayout.COMBAT_STEP
	var creature_top: float = EncounterLayout.COMBAT_STEP if is_hero else 0.0
	_draw_line(who + "_creatures", creatures, creature_heights, creature_rect, groups["creatures"].size.y, creature_top, glow, is_hero)
	if not others.is_empty():
		_draw_line(who + "_others", others, other_heights, groups["others"], groups["others"].size.y, 0.0, glow, is_hero)


## Draws one scrolling line. Its faces are centered in a band [param band_height] tall that
## starts [param band_top] below the line's top.
func _draw_line(key: String, permanents: Array[MmObjectView], heights: Array[float], line_rect: Rect2,
		band_height: float, band_top: float, glow: DecisionClicks, is_hero: bool) -> void:
	var is_tapped: Array[bool] = _tapped(permanents)
	var line: ScrollRow = ScrollRow.new(line_rect, EncounterLayout.line_width(is_tapped, heights), _line_offsets.get(key, 0.0))
	line.scrolled.connect(func(offset: float) -> void: _line_offsets[key] = offset)
	line.scrolled.connect(func(_offset: float) -> void:
		_carry_faces()
		_tint_arrows()
		_show_block_lines())
	_line_offsets[key] = line.offset()
	_board.add_child(line)
	_lines[key] = line
	var ids: Array[int] = []
	for permanent: MmObjectView in permanents:
		ids.append(permanent.id)
	_line_ids[key] = ids
	var footprints: Array[Rect2] = EncounterLayout.line(is_tapped, heights, band_height)
	for index: int in permanents.size():
		var permanent: MmObjectView = permanents[index]
		var face: BattlefieldFace = BattlefieldFace.new()
		face.setup(_snapshot.look_of(permanent.id), heights[index])
		face.position = footprints[index].position + Vector2(0, band_top)
		if _is_in_combat(permanent):
			face.position.y += EncounterLayout.combat_step(is_hero)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.content().add_child(face)
		_remember_face(permanent.id, face, footprints[index].size, glow)


func _tapped(permanents: Array[MmObjectView]) -> Array[bool]:
	var is_tapped: Array[bool] = []
	for permanent: MmObjectView in permanents:
		is_tapped.append(permanent.is_tapped)
	return is_tapped


## Whether [param permanent] stands forward in the lane: attacking or blocking, or chosen
## to by the Hero and not yet confirmed.
func _is_in_combat(permanent: MmObjectView) -> bool:
	return _is_fighting(permanent) or _selection.is_chosen(permanent.id)


## Whether the engine has [param permanent] attacking or blocking.
func _is_fighting(permanent: MmObjectView) -> bool:
	return permanent.is_attacking or not permanent.blocking_ids.is_empty()


## Creatures in combat stand to the left of the rest: attackers in object ID order, and
## blockers in the order of the attackers they block, so no two block lines cross. Only
## those the engine has in combat: while the Hero is choosing, nothing changes places under
## the cursor.
func _fighting_first(creatures: Array[MmObjectView]) -> Array[MmObjectView]:
	var ids: Array[int] = []
	var is_fighting: Array[bool] = []
	var blocked: Array[int] = []
	for creature: MmObjectView in creatures:
		ids.append(creature.id)
		is_fighting.append(_is_fighting(creature))
		blocked.append(creature.blocking_ids.min() if not creature.blocking_ids.is_empty() else EncounterLayout.NOT_BLOCKING)
	var ordered: Array[MmObjectView] = []
	for index: int in EncounterLayout.combat_order(ids, is_fighting, blocked):
		ordered.append(creatures[index])
	return ordered


func _remember_face(object_id: int, face: Control, face_size: Vector2, glow: DecisionClicks) -> void:
	_faces[object_id] = face
	_face_sizes[object_id] = face_size
	var colors: Array[Color] = _glow_colors(object_id, glow)
	if not colors.is_empty():
		BorderEffects.add_glow_of(face, face_size, colors, _glow_seconds_for(object_id, colors))
	if not glow.options_of(object_id).is_empty() or _selection.is_clickable(object_id):
		ClickCatcher.add(face, face_size).clicked.connect(_on_object_clicked.bind(object_id))
	_add_combat_marks(object_id, face, face_size)


## The answer whose payment the Tap Preview shows, or NO_PREVIEW.
func previewed_answer() -> int:
	return _previewed


## Asks the cursor what it wants previewed and, if that has changed, shows it, easing over
## [param seconds]: only what paying for it would tap keeps its blue Glow, and the pool
## mana it would spend glows (the Tap Preview). Called every frame. Nothing is rebuilt,
## which also keeps it within the rule for a held card.
func follow_preview(seconds: float) -> void:
	var wanted: int = _hovered_answer()
	if wanted == _previewed:
		return
	_previewed = wanted
	for object_id: int in _clicks.glowing_ids():
		var face: Control = _faces.get(object_id)
		if face == null or not is_instance_valid(face) or face == _lifted_face:
			continue
		if _clicks.kinds_of(object_id).has(DecisionClicks.Kind.MANA):
			BorderEffects.set_glow_of(face, _face_sizes[object_id], _glow_colors(object_id, _clicks), seconds)
	var plan: PaymentPlan = _preview_plan()
	_panels[HERO].glow_seconds = seconds
	_panels[HERO].mark_pool(plan.pool_types if plan != null else _clicks.pool_marks)


## What the Tap Preview shows the payment of, or null while it shows nothing. The
## presenter keeps each plan it has worked out, so asking again costs nothing.
func _preview_plan() -> PaymentPlan:
	return _presenter.payment_plan(_previewed) if _previewed != NO_PREVIEW else null


## The colors Game Object [param object_id] glows in: what [param glow] says, with its blue
## for mana kept only on what the Tap Preview's plan would tap.
func _glow_colors(object_id: int, glow: DecisionClicks) -> Array[Color]:
	var plan: PaymentPlan = _preview_plan()
	return glow.colors_of(object_id) if plan == null else glow.preview_colors_of(object_id, plan)


## The answer the cursor asks to see the payment of: the row of the Option Menu it is over,
## the card held, the card of the hand under it, or the permanent under it. Outside the
## menu only a thing that offers exactly one thing is previewed; one that offers several
## shows each when its row is pointed at. NO_PREVIEW for anything with no plan, which is
## everything while Auto-tap is off, and while the Hold Key is down, when the Hero will pay
## by hand.
func _hovered_answer() -> int:
	if _snapshot == null or not (_snapshot.decision is PriorityDecision) or not _presenter.is_auto_tapping():
		return NO_PREVIEW
	if _is_paused or _presenter.is_hold_key_down:
		return NO_PREVIEW
	var answer: int = NO_PREVIEW
	if _option_menu.is_open():
		answer = _option_menu.pointed_answer()
	elif _drag.is_lifted():
		answer = _only_answer(_hand_options(_drag.card_id()))
	else:
		var cursor: Vector2 = get_local_mouse_position()
		if _is_covered(cursor):
			return NO_PREVIEW
		var card_id: int = hand_card_under(cursor)
		if card_id != DragCard.NONE:
			answer = _only_answer(_hand_options(card_id))
		else:
			answer = _only_answer(_clicks.options_of(_permanent_under(cursor)))
	return answer if _presenter.payment_plan(answer) != null else NO_PREVIEW


static func _only_answer(options: Array[ClickOption]) -> int:
	return options[0].answer if options.size() == 1 else NO_PREVIEW


## The Game Object with a click answer whose face is drawn under [param cursor], turned as
## it is, or -1. Worked out from where the faces are, so it is right the moment a board is
## rebuilt, before Godot has said again what the mouse is over.
func _permanent_under(cursor: Vector2) -> int:
	var at: Vector2 = get_global_transform() * cursor
	for object_id: int in _clicks.clickable_ids():
		var face: Control = _faces.get(object_id)
		if face != null and is_instance_valid(face) and face.is_visible_in_tree() \
				and Rect2(Vector2.ZERO, _face_sizes[object_id]).has_point(face.get_global_transform().affine_inverse() * at):
			return object_id
	return -1


## What combat input draws on a face: a white outline on each blocker picked up and on the
## creature whose damage is being divided (A313, A325), how much that creature has left to
## give, and a stepper on each creature it can give damage to.
func _add_combat_marks(object_id: int, face: Control, face_size: Vector2) -> void:
	var divide: DivideCombatDamageDecision = _snapshot.decision as DivideCombatDamageDecision
	var is_source: bool = divide != null and _selection.is_active() and divide.source_id == object_id
	if is_source or (_selection.is_active() and _selection.picked_ids().has(object_id)):
		BorderEffects.add_pointer(face, face_size)
	if divide == null or not _selection.is_active():
		return
	if is_source:
		face.add_child(DamageStepper.left_chip(EncounterLayout.stepper_rect(face_size), _selection.left_to_assign()))
	for index: int in divide.recipients.size():
		if divide.recipients[index].is_object() and divide.recipients[index].id == object_id:
			var stepper: DamageStepper = _stepper(index, EncounterLayout.stepper_rect(face_size))
			face.add_child(stepper)
			_steppers[object_id] = stepper


func _stepper(index: int, box: Rect2) -> DamageStepper:
	var stepper: DamageStepper = DamageStepper.new(box, _selection.amounts()[index], _selection.is_lethal(index),
			_selection.can_lower(index), _selection.can_raise(index))
	stepper.lowered.connect(_change_amount.bind(index, -1))
	stepper.raised.connect(_change_amount.bind(index, 1))
	return stepper


func _change_amount(index: int, change: int) -> void:
	if not _is_paused and _selection.change_amount(index, change):
		_redraw()


## With trample the attacked player is given damage too: their stepper is on their portrait.
func _add_player_stepper() -> void:
	var divide: DivideCombatDamageDecision = _snapshot.decision as DivideCombatDamageDecision
	if divide == null or not _selection.is_active() or not divide.includes_player():
		return
	var index: int = divide.recipients.size() - 1
	var player_id: int = divide.recipients[index].id
	var portrait: Panel = _panels[player_id].portrait()
	var stepper: DamageStepper = _stepper(index, EncounterLayout.stepper_rect(portrait.size))
	portrait.add_child(stepper)
	_player_steppers[player_id] = stepper


## A line from every blocker to its attacker: those the engine has blocking, and those the
## Hero has paired so far.
func _show_block_lines() -> void:
	var lines: Array = []
	if _snapshot != null:
		for permanent: MmObjectView in _snapshot.view.battlefield:
			for attacker_id: int in permanent.blocking_ids:
				_add_block_line(lines, permanent.id, attacker_id, false)
		for pair: Array in _selection.pairs():
			_add_block_line(lines, pair[0], pair[1], true)
	_block_lines.show_lines(lines)


func _add_block_line(lines: Array, blocker_id: int, attacker_id: int, is_chosen: bool) -> void:
	if _faces.has(blocker_id) and _faces.has(attacker_id):
		lines.append([_block_line_end(blocker_id), _block_line_end(attacker_id), is_chosen])


## Where a block line meets Game Object [param object_id], in this screen's coordinates.
func _block_line_end(object_id: int) -> Vector2:
	var rect: Rect2 = _drawn_rect(object_id)
	for key: String in _lines:
		var ids: Array = _line_ids.get(key, [])
		if not ids.has(object_id):
			continue
		var line: ScrollRow = _lines[key]
		var hidden: int = _hidden_past(line, object_id)
		var arrow: Button = line.left_arrow() if hidden < 0 else line.right_arrow()
		return EncounterLayout.block_line_end(rect, key.begins_with("hero"), hidden,
				arrow.get_global_rect().get_center().x - global_position.x)
	return rect.get_center()


## Which end of [param line] the place of Game Object [param object_id] is scrolled past:
## -1 the left, 1 the right, 0 neither. Its place, not where it is drawn on the way there.
func _hidden_past(line: ScrollRow, object_id: int) -> int:
	var place: Vector2 = _rest.get(object_id, _faces[object_id].position)
	var middle: float = place.x + line.content().position.x + _face_sizes[object_id].x / 2.0
	return EncounterLayout.hidden_past(middle, line.size.x, ScrollRow.ARROW_WIDTH)


## Where the permanent [param object_id] is drawn right now, in this screen's coordinates.
func _drawn_rect(object_id: int) -> Rect2:
	var pose: FacePose = _motion.pose_of(object_id)
	var drawn: Vector2 = _face_sizes[object_id] * (pose.height / _motion.rest_of(object_id).height)
	return Rect2(pose.center - drawn / 2.0, drawn)


## The middle of [param face] at [param place] in its parent, in this screen's coordinates.
func _center_at(face: Control, place: Vector2) -> Vector2:
	return face.get_parent_control().global_position + place + face.size / 2.0 - global_position


## Tells Face Motion where each face's place is now, as soon as a line is scrolled: the
## scroll carried its faces with it, which is not a move.
func _carry_faces() -> void:
	for object_id: int in _rest:
		_motion.rebase(object_id, _center_at(_faces[object_id], _rest[object_id]))


## The permanents whose faces are scrolled out of sight, asked before a redraw: one of them
## that has left by the end of it gets no ghost, which would appear outside its line.
func _unseen_faces() -> Array[int]:
	var unseen: Array[int] = []
	for key: String in _lines:
		for object_id: int in _line_ids.get(key, []):
			if _rest.has(object_id) and _hidden_past(_lines[key], object_id) != 0:
				unseen.append(object_id)
	return unseen


## The board has just been rebuilt with every face at its place: hands those places to Face
## Motion and draws each face where it is on its way there (A356). [param unseen] are the
## permanents that were out of sight before the redraw.
func _move_faces(unseen: Array[int]) -> void:
	var targets: Dictionary[int, FacePose] = {}
	var looks: Dictionary[int, CardLook] = {}
	_rest.clear()
	for permanent: MmObjectView in _snapshot.view.battlefield:
		var face: BattlefieldFace = _faces.get(permanent.id, null) as BattlefieldFace
		if face == null:
			continue
		_rest[permanent.id] = face.position
		targets[permanent.id] = FacePose.of(_center_at(face, face.position), face.card().size.y, 1.0 if permanent.is_tapped else 0.0)
		looks[permanent.id] = _snapshot.look_of(permanent.id)
	_motion.show_faces(targets, looks, _is_snapping or size != _drawn_size)
	_is_snapping = false
	_drawn_size = size
	for object_id: int in unseen:
		if not targets.has(object_id):
			_motion.forget(object_id)
	_pose_faces()


## Draws each permanent's face where Face Motion has it right now, and each ghost as faint
## as it has become. A ghost is a face on its own layer that takes no clicks (A367).
func _pose_faces() -> void:
	for object_id: int in _rest:
		var face: BattlefieldFace = _faces[object_id] as BattlefieldFace
		var pose: FacePose = _motion.pose_of(object_id)
		var rest: FacePose = _motion.rest_of(object_id)
		face.pivot_offset = face.size / 2.0
		face.position = _rest[object_id] + pose.center - rest.center
		face.scale = Vector2.ONE * (pose.height / rest.height)
		face.modulate.a = 0.0 if _flights.is_flying(object_id) else pose.alpha
		face.show_turn(pose.turn)
	var fading: Array[int] = _motion.ghost_ids()
	for object_id: int in _ghosts.keys():
		if not fading.has(object_id):
			_ghosts[object_id].queue_free()
			_ghosts.erase(object_id)
	for object_id: int in fading:
		var pose: FacePose = _motion.ghost_pose(object_id)
		if not _ghosts.has(object_id):
			var ghost: BattlefieldFace = BattlefieldFace.new()
			ghost.setup(_motion.ghost_look(object_id), pose.height)
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ghost.position = pose.center - ghost.size / 2.0
			ghost.show_turn(pose.turn)
			_ghost_layer.add_child(ghost)
			_ghosts[object_id] = ghost
		_ghosts[object_id].modulate.a = pose.alpha


## Before the board is rebuilt for [param snapshot]: each card its events moved to another
## zone is put in the air where it is drawn now, going nowhere yet, so that what it lands
## on is drawn knowing it has not arrived. Returns the routes begun. Nothing flies for a
## rewind, which is not something that happened in the game, or through the pregame.
func _begin_flights(snapshot: EncounterSnapshot) -> Array[CardFlights.Route]:
	var begun: Array[CardFlights.Route] = []
	if _flights.seconds <= 0.0 or snapshot.is_rewind or _snapshot == null or _opening.is_open():
		return begun
	for route: CardFlights.Route in CardFlights.routes(snapshot.events):
		var kind: FlightCard.Kind = FlightCard.kind_in(route.from_zone_kind)
		var look: CardLook = _snapshot.look_of(route.first_object_id)
		var start: FacePose = _flights.pose_of(route.first_object_id)
		var is_carrying_on: bool = start != null
		if is_carrying_on:
			# Still in the air from its last move: it carries on from where it has got to.
			kind = _flight_cards[route.first_object_id].landing_kind
			look = _flight_cards[route.first_object_id].landing_look
			_end_flight(route.first_object_id)
		else:
			start = _flight_place(route.from_zone_kind, route.from_owner_id, route.first_object_id, route.card_id, false)
		if start == null:
			continue
		# A card appears from nothing only where it starts at the Stack Window, which shows an
		# entry and no card; one already in the air is there to be seen.
		_flights.launch(route.object_id, start, start, route.from_zone_kind == MmZone.Kind.STACK and not is_carrying_on,
				route.to_zone_kind == MmZone.Kind.STACK, route.drawn_after * _flights.gap_seconds)
		_flight_routes[route.object_id] = route
		if route.from_zone_kind == MmZone.Kind.LIBRARY and route.to_zone_kind == MmZone.Kind.HAND:
			_drawing.append(route.object_id)
		# The card is drawn once the board is, when the look it lands with is known.
		route.leaving_kind = kind
		route.leaving_look = look
		begun.append(route)
	return begun


## After the board is rebuilt: each card put in the air by [param begun] is aimed at where
## it now belongs and drawn. A permanent that flies away leaves no ghost.
func _aim_flights(begun: Array[CardFlights.Route]) -> void:
	for route: CardFlights.Route in begun:
		if not _flights.is_flying(route.object_id):
			continue
		var landing: FacePose = _flight_place(route.to_zone_kind, route.to_owner_id, route.object_id, route.card_id, true)
		if landing == null:
			_end_flight(route.object_id)
			continue
		_flights.aim(route.object_id, landing)
		var card: FlightCard = FlightCard.new(route.leaving_kind, route.leaving_look,
				FlightCard.kind_in(route.to_zone_kind), _snapshot.look_of(route.object_id))
		_flight_layer.add_child(card)
		_flight_cards[route.object_id] = card
		if route.from_zone_kind == MmZone.Kind.BATTLEFIELD:
			_motion.forget(route.first_object_id)
	if not begun.is_empty():
		_pose_faces()
		_hide_landing_places()
		_pose_flights()


## Draws each card in the air where Card Flights has it right now, aimed at where it lands
## now, and takes down each one that has arrived.
func _pose_flights() -> void:
	for object_id: int in _flights.ids():
		if not _flight_cards.has(object_id):
			continue
		var route: CardFlights.Route = _flight_routes[object_id]
		var landing: FacePose = _flight_place(route.to_zone_kind, route.to_owner_id, object_id, route.card_id, true)
		if landing != null:
			_flights.aim(object_id, landing)
		_flight_cards[object_id].show_pose(_flights.pose_of(object_id), _flights.along_of(object_id))
		if _flights.has_landed(object_id):
			_end_flight(object_id)


## Takes the card that lands as Game Object [param object_id] out of the air, and shows it
## where it landed.
func _end_flight(object_id: int) -> void:
	if _drawing.has(object_id):
		_drawing.erase(object_id)
		_has_draw_landed = not _is_redrawing
	_flights.land(object_id)
	_flight_routes.erase(object_id)
	if _flight_cards.has(object_id):
		_flight_cards[object_id].queue_free()
		_flight_cards.erase(object_id)
	if _faces.has(object_id) and is_instance_valid(_faces[object_id]):
		var pose: FacePose = _motion.pose_of(object_id)
		_faces[object_id].modulate.a = pose.alpha if pose != null else 1.0


func _clear_flights() -> void:
	for object_id: int in _flights.ids():
		_end_flight(object_id)


## What a card in the air lands on shows nothing of it until it arrives: its face in the
## hand, on a pile or in a row.
func _hide_landing_places() -> void:
	for object_id: int in _flights.ids():
		if _faces.has(object_id):
			_faces[object_id].modulate.a = 0.0


## Where a card in the zone of [param zone_kind] that [param owner_id] owns is drawn, read
## from what is on the screen right now, or null if nothing shows it: the Game Object
## [param object_id], or in the Hero's hand the card with Card Identity [param card_id].
## With [param is_landing] a permanent's place is where it belongs; otherwise it is where
## the permanent is drawn, on its way there.
func _flight_place(zone_kind: MmZone.Kind, owner_id: int, object_id: int, card_id: int, is_landing: bool) -> FacePose:
	match zone_kind:
		MmZone.Kind.BATTLEFIELD:
			return _field_flight_place(object_id, is_landing)
		MmZone.Kind.HAND:
			if owner_id != HERO:
				return FacePose.of(_regions["villain_hand"].get_center(), EncounterLayout.VILLAIN_CARD_HEIGHT, 0.0)
			if _drawing.has(object_id):
				return _draw_landing_place(object_id)
			var index: int = _hand_cards.find(card_id)
			# A card played by letting go of it flies from where it was let go.
			var face: Control = _hand_faces[index] if index >= 0 else _lifted_face
			if face == null or not is_instance_valid(face) or not face.is_inside_tree():
				return null
			return FacePose.of(face.get_global_transform() * (face.size / 2.0) - global_position, face.size.y, 0.0)
		MmZone.Kind.STACK:
			return FacePose.of(_stack_art_place(object_id), StackEntry.ART_SIZE, 0.0)
		MmZone.Kind.LIBRARY, MmZone.Kind.GRAVEYARD, MmZone.Kind.EXILE:
			var pile: Rect2 = _regions[EncounterLayout.pile_key(zone_kind, owner_id == HERO)]
			return FacePose.of(pile.position + Vector2(pile.size.x / 2.0, EncounterLayout.PILE_HEIGHT / 2.0), EncounterLayout.PILE_HEIGHT, 0.0)
	return null


## The middle of the art at the left of the Stack Window's entry for [param object_id], in
## this screen's coordinates: where a card put on the stack flies to, and a card leaving it
## flies from. Read from the entry once it has found its place, and otherwise where it was
## last seen, or the middle of the window for an entry never yet placed.
func _stack_art_place(object_id: int) -> Vector2:
	var entry: StackEntry = stack_entry_of(object_id)
	if _are_stack_entries_placed and entry != null and is_instance_valid(entry) and entry.is_inside_tree():
		_stack_art_places[object_id] = entry.art().get_global_rect().get_center() - global_position
	return _stack_art_places.get(object_id, _stack_window.get_global_rect().get_center() - global_position)


## Where the permanent [param object_id] flies to or from. One scrolled out of sight leaves
## small, from under the arrow at that end of its line.
func _field_flight_place(object_id: int, is_landing: bool) -> FacePose:
	if is_landing:
		var rest: FacePose = _motion.rest_of(object_id)
		return FacePose.of(rest.center, rest.height, rest.turn) if rest != null else null
	if not _rest.has(object_id):
		return null
	var pose: FacePose = _motion.pose_of(object_id)
	for key: String in _lines:
		var ids: Array = _line_ids.get(key, [])
		var hidden: int = _hidden_past(_lines[key], object_id) if ids.has(object_id) else 0
		if hidden != 0:
			var arrow: Button = _lines[key].left_arrow() if hidden < 0 else _lines[key].right_arrow()
			return FacePose.of(arrow.get_global_rect().get_center() - global_position, pose.height * EncounterLayout.UNSEEN_FLIGHT_SCALE, pose.turn)
	return FacePose.of(pose.center, pose.height, pose.turn)


## A glowing permanent scrolled off the end of its line colors that line's arrow, so a
## legal choice is never out of sight without a sign (A292).
func _tint_arrows() -> void:
	for key: String in _lines:
		var line: ScrollRow = _lines[key]
		var left: Variant = null
		var right: Variant = null
		var ids: Array = _line_ids.get(key, [])
		for object_id: int in ids:
			var color: Variant = BorderEffects.glow_color(_faces[object_id])
			if color == null:
				continue
			var side: int = _hidden_past(line, object_id)
			if side < 0:
				left = color
			elif side > 0:
				right = color
		line.tint_arrows(left, right)


func _draw_villain_hand(count: int, hand_rect: Rect2) -> void:
	var card: Vector2 = Vector2(EncounterLayout.VILLAIN_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.VILLAIN_CARD_HEIGHT)
	var places: Array[Vector2] = EncounterLayout.villain_hand(count, hand_rect, card)
	for index: int in count:
		var back: Panel = CardBack.make(card.y)
		back.position = places[index]
		back.pivot_offset = Vector2(card.x / 2.0, 0)
		back.rotation = -EncounterLayout.fan_angle(index, count)
		_board.add_child(back)
		_card_backs.append(back)


func _draw_hand(view: MmPlayerView, hand_rect: Rect2, glow: DecisionClicks) -> void:
	var card: Vector2 = Vector2(EncounterLayout.HAND_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.HAND_CARD_HEIGHT)
	var seen: Dictionary[int, MmObjectView] = {}
	for in_hand: MmObjectView in view.hand:
		seen[in_hand.card_id] = in_hand
	for card_id: int in _hand_row_cards(0):
		_hand_cards.append(card_id)
	var gap: int = _drag.gap() if _drag.has_gap() else DragCard.NONE
	_hand_rest = EncounterLayout.hand_row(_hand_cards.size(), gap, hand_rect, card)
	_hand_turns = EncounterLayout.hand_row_angles(_hand_cards.size(), gap)
	for index: int in _hand_cards.size():
		# _spread_hand() places and turns it once the whole board is drawn.
		var face: CardFace = _hand_face(seen[_hand_cards[index]], card)
		_board.add_child(face)
		_hand_faces.append(face)
		_remember_face(seen[_hand_cards[index]].id, face, card, glow)
	# The card being held is drawn again where it is held, on its own layer (A380).
	for child: Node in _drag_layer.get_children():
		_drag_layer.remove_child(child)
		child.queue_free()
	_lifted_face = null
	if not _drag.is_lifted():
		return
	var lifted: MmObjectView = seen[_drag.card_id()]
	_lifted_face = _hand_face(lifted, card)
	_lifted_face.position = _drag.place()
	_drag_layer.add_child(_lifted_face)
	_remember_face(lifted.id, _lifted_face, card, glow)
	_glow_lifted_face()


## The Card Identities of the hand's row, in order, without the card being held and without
## the drawn cards still in the air from the one at [param first_out] of _drawing on.
func _hand_row_cards(first_out: int) -> Array[int]:
	var out: Array[int] = []
	for index: int in range(first_out, _drawing.size()):
		if _flight_routes[_drawing[index]].to_owner_id == HERO:
			out.append(_flight_routes[_drawing[index]].card_id)
	var row: Array[int] = []
	for card_id: int in _hand_order.cards():
		if not out.has(card_id) and not (_drag.is_lifted() and card_id == _drag.card_id()):
			row.append(card_id)
	return row


## How many drawn cards are still on their way to the hand of [param player_id].
func _drawing_count(player_id: int) -> int:
	var count: int = 0
	for object_id: int in _drawing:
		if _flight_routes[object_id].to_owner_id == player_id:
			count += 1
	return count


## Where the drawn card that is Game Object [param object_id] lands in the Hero's hand: its
## place in the row as the row will be when it arrives, with every card drawn before it
## already there.
func _draw_landing_place(object_id: int) -> FacePose:
	var row: Array[int] = _hand_row_cards(_drawing.find(object_id) + 1)
	var index: int = row.find(_flight_routes[object_id].card_id)
	if index < 0:
		return null
	var card: Vector2 = Vector2(EncounterLayout.HAND_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.HAND_CARD_HEIGHT)
	var corner: Vector2 = EncounterLayout.hand_row(row.size(), DragCard.NONE, _regions["hero_hand"], card)[index]
	var turn: float = EncounterLayout.hand_row_angles(row.size(), DragCard.NONE)[index]
	# The card turns about the middle of its bottom edge.
	var middle: Vector2 = corner + Vector2(card.x / 2.0, card.y) + Vector2(0.0, -card.y / 2.0).rotated(turn)
	return FacePose.of(middle, card.y, 0.0)


## A card of the Hero's hand, turning about the middle of its bottom edge.
func _hand_face(seen: MmObjectView, card: Vector2) -> CardFace:
	var face: CardFace = CardFace.new()
	face.setup(_snapshot.look_of(seen.id), card.y)
	face.pivot_offset = Vector2(card.x / 2.0, card.y)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return face


## The Hero's view of the card in hand with Card Identity [param card_id], or null.
func _hand_view(card_id: int) -> MmObjectView:
	for in_hand: MmObjectView in _snapshot.view.hand:
		if in_hand.card_id == card_id:
			return in_hand
	return null


## The ways the card in hand with Card Identity [param card_id] can be played right now.
func _hand_options(card_id: int) -> Array[ClickOption]:
	var in_hand: MmObjectView = _hand_view(card_id)
	return _clicks.hand_options_of(in_hand.id) if in_hand != null else ([] as Array[ClickOption])


## What the Info Panel says while a card is held where letting go would play it, or "".
func _release_text() -> String:
	if not _drag.is_holding() or not _drag.is_above():
		return ""
	var options: Array[ClickOption] = _hand_options(_drag.card_id())
	return InfoPrompt.release_text(options[0].text) if not options.is_empty() else ""


## A lifted card that can be played or has an ability to use glows in the colors of what
## letting go offers, brighter where letting go would do it (A375).
func _glow_lifted_face() -> void:
	if _hand_options(_drag.card_id()).is_empty():
		return
	var object_id: int = _hand_view(_drag.card_id()).id
	var colors: Array[Color] = _clicks.colors_of(object_id, _drag.is_waiting() or _drag.is_above())
	BorderEffects.set_glow_of(_lifted_face, _lifted_face.size, colors, _glow_seconds_for(object_id, colors))


## Takes the pressed card out of the hand's row and holds it. Nothing is rebuilt: its own
## face is lifted to the layer above the windows, upright.
func _lift() -> void:
	var index: int = _hand_cards.find(_drag.card_id())
	_lifted_face = _hand_faces[index]
	# Where the rest go is worked out again as soon as the card hovers (_lay_out_hand).
	_hand_faces.remove_at(index)
	_hand_cards.remove_at(index)
	_board.remove_child(_lifted_face)
	_drag_layer.add_child(_lifted_face)
	_lifted_face.rotation = 0.0
	_lifted_face.z_index = 0


## Tells the hand's row where its cards go now, for where the held card is, and shows on
## the held card and in the Info Panel whether letting go would play it. Nothing is
## rebuilt: the cards ease to their places.
func _lay_out_hand() -> void:
	var gap: int = _drag.gap() if _drag.has_gap() else DragCard.NONE
	if not _hand_faces.is_empty():
		_hand_rest = EncounterLayout.hand_row(_hand_faces.size(), gap, _regions["hero_hand"], _hand_faces[0].size)
		_hand_turns = EncounterLayout.hand_row_angles(_hand_faces.size(), gap)
	if _lifted_face != null:
		_glow_lifted_face()
	_info.show_option(_release_text())


## Puts the lifted card into the hand's row at [param index] among the other cards, and
## into the Hand Order there. Nothing is rebuilt: its face goes back into the row.
func _put_down(index: int) -> void:
	var card_id: int = _drag.card_id()
	var face: CardFace = _lifted_face
	var at: int = clampi(index, 0, _hand_faces.size())
	_drag.drop()
	_lifted_face = null
	_hand_order.place(card_id, at)
	_drag_layer.remove_child(face)
	_board.add_child(face)
	if not _hand_faces.is_empty():
		var is_last: bool = at == _hand_faces.size()
		_board.move_child(face, _hand_faces[at - 1].get_index() + 1 if is_last else _hand_faces[at].get_index())
	_hand_faces.insert(at, face)
	_hand_cards.insert(at, card_id)
	# Only a card that can be played glowed brighter while held; any other keeps its glow.
	if BorderEffects.glow_color(face) != null and not _hand_options(card_id).is_empty():
		BorderEffects.set_glow_of(face, face.size, _clicks.colors_of(_hand_view(card_id).id), _ease_seconds)
	_lay_out_hand()


## Puts the lifted card back where it was in the hand.
func _put_back() -> void:
	_put_down(_hand_order.place_of(_drag.card_id()))


## The Option Menu closed. A card that was waiting on it goes back to the hand; if a way to
## play it was chosen, the answer takes it from there.
func _on_menu_closed() -> void:
	if _drag.is_waiting():
		_put_back()


## Where the hand's cards go with the cursor at [param cursor]: parted around the card under
## it, and never past the hand's bounds. While a card is held they keep to their places.
func hand_places(cursor: Vector2) -> Array[Vector2]:
	if _hand_faces.is_empty():
		return []
	var rest: Array[Vector2] = _hand_rest_now()
	if _drag.is_lifted():
		return rest
	return EncounterLayout.hand_spread_within(rest, _hand_faces[0].size, cursor, _regions["hero_hand"])


## Moves the hand's cards [param weight] of the way to where they belong, in place and in
## turn.
func _spread_hand(weight: float) -> void:
	if _hand_faces.is_empty():
		return
	var card: Vector2 = _hand_faces[0].size
	var cursor: Vector2 = get_local_mouse_position()
	var places: Array[Vector2] = hand_places(cursor)
	var nearest: int = -1
	var rest: Array[Vector2] = _hand_rest_now()
	if not _drag.is_lifted() and EncounterLayout.is_cursor_over_hand(rest, card, cursor):
		nearest = roundi(EncounterLayout.hand_cursor_place(rest, card, cursor))
	for index: int in _hand_faces.size():
		_hand_faces[index].position = _hand_faces[index].position.lerp(places[index], weight)
		_hand_faces[index].rotation = lerpf(_hand_faces[index].rotation, _hand_turns[index], weight)
		_hand_faces[index].z_index = 1 if index == nearest else 0


## Moves each card of the hand [param weight] of the way to how light it belongs: a little
## lighter while it is the one drawn under the cursor, unless it is pressed or held.
func _light_hand(weight: float) -> void:
	var lit: int = DragCard.NONE
	if not _drag.is_lifted():
		lit = hand_card_under(get_local_mouse_position())
	if _drag.is_pressed() and lit == _drag.card_id():
		lit = DragCard.NONE
	for index: int in _hand_faces.size():
		var is_lit: bool = _hand_cards[index] == lit
		_ease_light(_hand_faces[index], HAND_HOVER_LIGHT if is_lit else Color.WHITE, weight)
	if _lifted_face != null:
		_ease_light(_lifted_face, Color.WHITE, weight)


static func _ease_light(face: CardFace, light: Color, weight: float) -> void:
	var alpha: float = face.modulate.a
	face.modulate = face.modulate.lerp(light, weight)
	face.modulate.a = alpha


## Where each card of the hand's row rests right now: where the row puts it, and a card
## chosen to be discarded a quarter of its height above that (A401).
func _hand_rest_now() -> Array[Vector2]:
	var rest: Array[Vector2] = _hand_rest.duplicate()
	if not _picks.is_discarding() or _hand_faces.is_empty():
		return rest
	for index: int in mini(rest.size(), _hand_cards.size()):
		var in_hand: MmObjectView = _hand_view(_hand_cards[index])
		if in_hand != null and _picks.is_picked(in_hand.id):
			rest[index].y -= _hand_faces[0].size.y * EncounterLayout.PICKED_RISE
	return rest


## The card of the hand with Card Identity [param card_id] was clicked: pressed and let go
## in place. While cards are being chosen to discard that chooses it, or lets it go again;
## otherwise one click does nothing (A371).
func _click_hand(card_id: int) -> void:
	var in_hand: MmObjectView = _hand_view(card_id)
	if _is_paused or in_hand == null or not _picks.is_discarding():
		return
	if _picks.toggle(in_hand.id):
		_show_picks()


## Draws the opening-hand overlay through the pregame, and takes it away once the first
## turn begins: over a quarter of a second when the game is paced, at once otherwise.
func _show_overlay() -> void:
	if not _opening.is_open():
		if _overlay.is_open():
			_overlay.close(_motion.seconds, _hand_poses())
		_show_landed_hand()
		return
	var area: Rect2 = Rect2(_regions["sidebar"].end.x, 0, size.x - _regions["sidebar"].end.x, size.y)
	var pile: Vector2 = Vector2(EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT, EncounterLayout.PILE_HEIGHT)
	var library: Rect2 = _regions["hero_library"]
	_overlay.show_frame(_opening, _snapshot, _picks, _hand_order.cards(), area,
			Rect2(library.position + Vector2((library.size.x - pile.x) / 2.0, 0), pile))
	_opening.forget_new_hand()


## Where each card of the hand's strip rests, by Game Object ID, as a pose whose center is
## the middle of the card's bottom edge: where the overlay's cards fly to when it goes.
func _hand_poses() -> Dictionary[int, FacePose]:
	var poses: Dictionary[int, FacePose] = {}
	for index: int in mini(_hand_cards.size(), _hand_rest.size()):
		var in_hand: MmObjectView = _hand_view(_hand_cards[index])
		if in_hand != null and index < _hand_faces.size():
			var card: Vector2 = _hand_faces[index].size
			poses[in_hand.id] = FacePose.of(_hand_rest[index] + Vector2(card.x / 2.0, card.y), card.y, _hand_turns[index])
	return poses


## Shows each card of the hand's strip unless the overlay is still flying it there.
func _show_landed_hand() -> void:
	for index: int in mini(_hand_cards.size(), _hand_faces.size()):
		var in_hand: MmObjectView = _hand_view(_hand_cards[index])
		_hand_faces[index].visible = in_hand == null or not _overlay.is_landing(in_hand.id)


## Shows how far the choice of cards has come, on what is already drawn: a card chosen to
## be discarded glows white and the rest that can be chosen green, the pass button confirms
## the discard, and undo is open while there is a click to take back. Nothing is rebuilt
## for a click in the hand, so a chosen card eases up to its place.
func _show_picks() -> void:
	if not _picks.is_active() or _snapshot.is_over():
		return
	if not _picks.is_discarding():
		# Keeping is final (A406): undo takes back cards put down and nothing before them.
		_panels[HERO].show_undo(_picks.can_undo())
		return
	_panels[HERO].show_undo(_picks.can_undo() or (_snapshot.can_undo and not _snapshot.is_villain_thinking))
	_show_confirm("Confirm discard", _picks.is_complete(), _picks.can_undo())
	_info.show_prompt(_picks.prompt())
	for index: int in _hand_faces.size():
		var in_hand: MmObjectView = _hand_view(_hand_cards[index])
		if in_hand == null:
			continue
		var face: Control = _hand_faces[index]
		if _picks.is_picked(in_hand.id):
			BorderEffects.set_glow(face, face.size, PICKED_GLOW, _glow_seconds_for(in_hand.id, PICKED_GLOW))
		elif _picks.can_pick(in_hand.id):
			var color: Color = DecisionClicks.color_of(DecisionClicks.Kind.OTHER)
			BorderEffects.set_glow(face, face.size, color, _glow_seconds_for(in_hand.id, color))
		else:
			BorderEffects.remove_glow(face, _glow_seconds_for(in_hand.id, null))


## The choice of cards changed by a click or an undo. Cards put on the bottom leave the
## overlay's row, which is drawn again; in the hand's strip nothing is rebuilt.
func _show_picks_changed() -> void:
	if _picks.is_bottoming():
		_redraw()
	else:
		_show_picks()


## A button of the overlay that answers outright was pressed.
func _answer_overlay(overlay_answer: int) -> void:
	if not _is_paused and OpeningHand.covers(_snapshot.decision) and not _picks.is_active():
		_answer(overlay_answer)


## A card of the overlay's row was clicked to be put on the bottom.
func _put_on_bottom(object_id: int) -> void:
	if not _is_paused and _picks.is_bottoming() and _picks.pick(object_id):
		_redraw()


## Answers with the cards chosen, once there are as many as asked for.
func _confirm_picks() -> void:
	if not _is_paused and _picks.is_complete():
		_answer(_picks.answer())


func _draw_library(count: int, key: String, pile_rect: Rect2) -> void:
	var card: Vector2 = Vector2(EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT, EncounterLayout.PILE_HEIGHT)
	var at: Vector2 = pile_rect.position + Vector2((pile_rect.size.x - card.x) / 2.0, 0)
	if count > 0:
		var back: Panel = CardBack.make(card.y)
		back.position = at
		_board.add_child(back)
	else:
		_draw_empty_pile(at, card)
	_draw_pile_label("Library (%d)" % count, key, pile_rect)


## A graveyard or exile pile: its top card and how many cards it holds. While its top card
## is still in the air, the last card that has landed is drawn under it, and the top card
## shows nothing until it lands (Card Flights).
func _draw_pile(zone_name: String, cards: Array, key: String, pile_rect: Rect2) -> void:
	var card: Vector2 = Vector2(EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT, EncounterLayout.PILE_HEIGHT)
	var at: Vector2 = pile_rect.position + Vector2((pile_rect.size.x - card.x) / 2.0, 0)
	var top: MmObjectView = cards.back() as MmObjectView if not cards.is_empty() else null
	var landed: MmObjectView = null
	for index: int in range(cards.size() - 1, -1, -1):
		if not _flights.is_flying((cards[index] as MmObjectView).id):
			landed = cards[index] as MmObjectView
			break
	if landed == null:
		_draw_empty_pile(at, card)
	for shown: MmObjectView in [landed, top]:
		if shown == null or _faces.has(shown.id):
			continue
		var face: CardFace = CardFace.new()
		face.setup(_snapshot.look_of(shown.id), card.y)
		face.position = at
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(face)
		_faces[shown.id] = face
		_face_sizes[shown.id] = card
	_draw_pile_label("%s (%d)" % [zone_name, cards.size()], key, pile_rect)


func _draw_empty_pile(at: Vector2, card: Vector2) -> void:
	var empty: Panel = CardShapes.outline(card, 6, 2, Color(1, 1, 1, 0.25))
	empty.position = at
	_board.add_child(empty)


func _draw_pile_label(text: String, key: String, pile_rect: Rect2) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = Vector2(pile_rect.position.x, pile_rect.position.y + EncounterLayout.PILE_HEIGHT)
	label.size = Vector2(pile_rect.size.x, EncounterLayout.PILE_LABEL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	_board.add_child(label)
	_pile_labels[key] = label


func _button(text: String, on_press: Callable, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	button.pressed.connect(on_press)
	return button


## The Stack Window is there while something is on the stack, or while triggers are being
## put in order. The top of the stack, which resolves first, is listed first.
func _fill_stack_window(view: MmPlayerView) -> void:
	var ids: Array[int] = []
	for seen: MmObjectView in view.stack:
		ids.append(seen.id)
	_stack_colors.update(ids)
	for object_id: int in _stack_items:
		_stack_art_place(object_id)
	for object_id: int in _stack_art_places.keys():
		if not ids.has(object_id):
			_stack_art_places.erase(object_id)
	_are_stack_entries_placed = false
	_stack_window.set_open(not view.stack.is_empty() or _trigger_order.is_active())
	_stack_window.show_count(view.stack.size())
	_stack_window.clear()
	_stack_entries.clear()
	_stack_items.clear()
	_trigger_list = null
	_stack_arrows = null
	if _trigger_order.is_active():
		_add_trigger_entries(view)
	if view.stack.is_empty():
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack_window.body().add_child(row)
	_stack_arrows = StackArrows.new()
	row.add_child(_stack_arrows)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	row.add_child(list)
	for index: int in range(view.stack.size() - 1, -1, -1):
		var seen: MmObjectView = view.stack[index]
		var item: StackItem = StackItem.of(seen, view, _snapshot.names)
		var entry: StackEntry = StackEntry.new(_snapshot.look_of(seen.id).art_key, item.first_line, item.second_line,
			_stack_colors.color_of(seen.id))
		if not _clicks.options_of(seen.id).is_empty():
			# A spell that can be chosen as a target is clicked here (A354).
			entry.make_targetable().clicked.connect(_on_object_clicked.bind(seen.id))
		entry.hovered.connect(_on_stack_entry_hovered.bind(seen.id))
		list.add_child(entry)
		_stack_entries.append(entry)
		_stack_items[seen.id] = item
	var arrows: Array = []
	for object_id: int in _stack_items:
		for target_id: int in _stack_items[object_id].target_stack_ids:
			if _stack_items.has(target_id):
				arrows.append([stack_entry_of(object_id), stack_entry_of(target_id), _stack_colors.color_of(object_id)])
	_stack_arrows.show_arrows(arrows)
	# The entries find their places a frame later.
	list.sort_children.connect(_stack_arrows.queue_redraw)
	list.sort_children.connect(func() -> void: _are_stack_entries_placed = true)
	var side: VBoxContainer = VBoxContainer.new()
	row.add_child(side)
	side.add_child(_small_label("resolves\nfirst"))
	var arrow: StackArrow = StackArrow.new()
	arrow.custom_minimum_size = Vector2(54, 30)
	arrow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(arrow)
	side.add_child(_small_label("resolves\nlast"))


## The triggers being put in order, above the stack: plain and dashed, since they are not
## on the stack yet, in a list they are dragged in (A339, A345, A393).
func _add_trigger_entries(view: MmPlayerView) -> void:
	var decision: OrderTriggersDecision = _snapshot.decision as OrderTriggersDecision
	_stack_window.body().add_child(_small_label("Triggers to order: drag them, the top one resolves first"))
	var entries: Array[StackEntry] = []
	for number: int in decision.abilities.size():
		var entry: StackEntry = StackEntry.new(_trigger_art(decision, number), _trigger_text(decision, number),
			_snapshot.names.of(decision.player_id), StackColors.PLAIN, true)
		entry.hovered.connect(_on_trigger_hovered.bind(number))
		entries.append(entry)
	_trigger_list = TriggerList.new(entries, _trigger_order.order())
	_trigger_list.moved.connect(_move_trigger)
	_stack_window.body().add_child(_trigger_list)
	if not view.stack.is_empty():
		_stack_window.body().add_child(_small_label("On the stack"))


## Trigger [param number]'s whole ability, in its source's words.
func _trigger_text(decision: OrderTriggersDecision, number: int) -> String:
	var source: MmObjectView = _seen(decision.source_object_ids[number])
	var noun: String = AbilityText.self_noun(source.card_types, source.name) if source != null else "it"
	return AbilityText.of_ability(decision.abilities[number], noun)


func _trigger_art(decision: OrderTriggersDecision, number: int) -> String:
	var look: CardLook = _snapshot.look_of(decision.source_object_ids[number])
	return look.art_key if look != null else ""


## A drag put the trigger at place [param from] down at place [param to].
func _move_trigger(from: int, to: int) -> void:
	if not _is_paused:
		_trigger_order.move_to(from, to)
	_show_trigger_order()


## Shows the order the triggers are in now, on what is already drawn: the entries ease to
## their places, and undo is open while there is a move to take back.
func _show_trigger_order() -> void:
	if trigger_list() == null:
		return
	_trigger_list.set_order(_trigger_order.order())
	_panels[HERO].show_undo(_trigger_order.can_undo() or (_snapshot.can_undo and not _snapshot.is_villain_thinking))


## The cursor came over a Stack Window entry, or left it: its source is marked with a solid
## border and its targets with a dashed one, in its color, and the Info Panel shows it in
## full (A336, A337, A342).
func _on_stack_entry_hovered(is_over: bool, object_id: int) -> void:
	_clear_marks()
	_info.show_option("")
	if not is_over or not _stack_items.has(object_id):
		return
	var item: StackItem = _stack_items[object_id]
	var color: Color = _stack_colors.color_of(object_id)
	_info.show_option(item.full_text)
	_mark_face(item.source_object_id, color, false)
	for target_id: int in item.target_object_ids:
		_mark_face(target_id, color, true)
	for player_id: int in item.target_player_ids:
		var portrait: Control = _panels[player_id].portrait()
		BorderEffects.add_mark(portrait, portrait.size, color, true, _ease_seconds)
		_marked.append(portrait)


func _on_trigger_hovered(is_over: bool, number: int) -> void:
	_clear_marks()
	_info.show_option("")
	var decision: OrderTriggersDecision = _snapshot.decision as OrderTriggersDecision
	if not is_over or decision == null:
		return
	_info.show_option(_trigger_text(decision, number))
	_mark_face(decision.source_object_ids[number], Color.WHITE, false)


func _mark_face(object_id: int, color: Color, is_dashed: bool) -> void:
	if _faces.has(object_id):
		BorderEffects.add_mark(_faces[object_id], _face_sizes[object_id], color, is_dashed, _ease_seconds)
		_marked.append(_faces[object_id])


func _clear_marks() -> void:
	for host: Control in _marked:
		if is_instance_valid(host):
			BorderEffects.remove_mark(host, _ease_seconds)
	_marked.clear()


## The window that asks which replacement effect applies first (A340): there exactly while
## the Hero is asked, with an entry for each effect, clicked to choose it.
func _fill_choice_window(view: MmPlayerView) -> void:
	var decision: ChooseReplacementEffectDecision = _snapshot.decision as ChooseReplacementEffectDecision
	_choice_window.clear()
	_choice_entries.clear()
	_choice_window.set_open(decision != null)
	if decision == null:
		return
	_choice_window.show_title(ReplacementText.title(decision, view, _snapshot.names))
	_choice_window.move_to_front()
	for index: int in decision.options.size():
		var active: ActiveReplacementEffect = decision.options[index]
		var source: MmObjectView = ReplacementText.source_of(active, view)
		var look: CardLook = _snapshot.look_of(source.id) if source != null else null
		var entry: ZoneEntry = ZoneEntry.new(look.art_key if look != null else "", ReplacementText.source_name(active, view),
			ReplacementText.effect_text(active, view, _snapshot.names), StackColors.PLAIN)
		_choice_window.body().add_child(entry)
		var catcher: ClickCatcher = ClickCatcher.add(entry, entry.size)
		catcher.clicked.connect(_choose_replacement.bind(index))
		catcher.mouse_entered.connect(_on_choice_hovered.bind(true, index))
		catcher.mouse_exited.connect(_on_choice_hovered.bind(false, index))
		_choice_entries.append(entry)


func _choose_replacement(index: int) -> void:
	if not _is_paused:
		_answer(index)


## The cursor came over one of the choice window's entries, or left it: the card it came
## from is marked if it is on the battlefield, and the Info Panel shows the entry in full.
func _on_choice_hovered(is_over: bool, index: int) -> void:
	_clear_marks()
	_info.show_option("")
	var decision: ChooseReplacementEffectDecision = _snapshot.decision as ChooseReplacementEffectDecision
	if not is_over or decision == null:
		return
	var active: ActiveReplacementEffect = decision.options[index]
	_info.show_option("%s — %s" % [ReplacementText.source_name(active, _snapshot.view), ReplacementText.effect_text(active, _snapshot.view, _snapshot.names)])
	var source: MmObjectView = ReplacementText.source_of(active, _snapshot.view)
	if source != null:
		_mark_face(source.id, Color.WHITE, false)


## What the view shows of Game Object [param object_id], or null.
func _seen(object_id: int) -> MmObjectView:
	for seen: MmObjectView in _snapshot.visible_objects():
		if seen.id == object_id:
			return seen
	return null


func _small_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(1, 1, 1, 0.7)
	return label


func _fill_emblems_window(view: MmPlayerView, player_id: int) -> void:
	var window: ZoneWindow = _emblem_windows[player_id]
	var view_names: PlayerNames = _snapshot.names
	window.clear()
	var count: int = 0
	for emblem: MmObjectView in view.command:
		if emblem.controller_id != player_id:
			continue
		count += 1
		# Its rules text on one line, cut where the window ends; widening the window shows more.
		var text: String = AbilityText.of_card(emblem.abilities, emblem.card_types, emblem.supertypes, emblem.name)
		var entry: ZoneEntry = ZoneEntry.new("", emblem.name, text.replace("\n", " · "), PlayerPanel.GOLD)
		entry.cut_detail()
		window.body().add_child(entry)
	window.show_title("%s Emblems (%d)" % [view_names.possessive(player_id), count])


func _draw_banner(view: MmPlayerView) -> void:
	var text: String = "Draw"
	if not _snapshot.is_draw():
		var loser: int = VILLAIN if view.winner_id == HERO else HERO
		var reason: String = LOSS_REASONS.get(view.loss_reasons.get(loser, MmPlayer.LossReason.NONE), "lost")
		text = "%s\n%s %s." % ["Victory" if view.winner_id == HERO else "Defeat", _snapshot.names.starting(loser), reason]
	var box: Panel = CardShapes.rounded(Vector2(620, 240), 12, Color(0.05, 0.05, 0.07, 0.95))
	box.position = (size - box.size) / 2.0
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.set_meta("text", text)
	# Over the block lines, which lie over the board, and under the panels and every window.
	add_child(box)
	move_child(box, _block_lines.get_index() + 1)
	_banner = box
	var label: Label = Label.new()
	label.text = text
	label.size = Vector2(620, 150)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42)
	box.add_child(label)
	var again: Button = _button("Replay this seed", func() -> void: leave(scene_file_path), 18)
	again.position = Vector2(90, 170)
	again.size = Vector2(200, 44)
	box.add_child(again)
	var form: Button = _button("Start form", func() -> void: leave(START_FORM), 18)
	form.position = Vector2(330, 170)
	form.size = Vector2(200, 44)
	box.add_child(form)
