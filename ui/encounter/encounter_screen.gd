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
## Once declared, a creature attacking or blocking glows gold until combat ends, split
## with the color of anything a decision offers on it.
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
## The Glow of a card of the hand chosen to be discarded (A401).
const PICKED_GLOW: Color = Color.WHITE
## The Glow round the Hero's library while its top card shows, in the pile host's own
## coordinates, as where it starts and how much bigger than a card it is.
const SEEN_PILE_BOX: Rect2 = Rect2(Vector2(-2, -4), Vector2(7, 4))
## What the Tap Preview shows when the cursor asks for nothing.
const NO_PREVIEW: int = -1
## What the Pass Button reads while a question's affirmative is the Selected Answer: "Yes"
## for a "you may" (game ADR 0060), and for a cost "Pay {2}", as the Info Panel's own
## answer reads (ADR 0062), or the X the stepper shows (game ADR 0063).
const YES: String = "Yes"
const PAY_X_FORMAT: String = "Pay {%d}"
## The Pass Button while X is chosen as a spell is cast (engine ADR 0076).
const CAST_X_FORMAT: String = "Cast with {%d}"
## What it reads, and cannot be pressed, while a question that spends mana has no Selected
## Answer yet (game ADR 0066).
const CHOOSE_AN_ANSWER: String = "Choose an answer"
## What the Pass Button reads while the Hero surveils (game ADR 0069).
const DONE: String = "Done"
## The size of the window that asks which replacement effect applies first.
const REPLACEMENT_WINDOW_SIZE: Vector2 = Vector2(470, 260)
## The mode window's width, the room each mode's entry takes, and the room round them.
const MODE_WINDOW_WIDTH: float = 520.0
const MODE_ENTRY_HEIGHT: float = 82.0
const MODE_WINDOW_PAD: float = 20.0
## How a mode that cannot be chosen is dimmed (CR 700.2a).
const UNCHOOSABLE_MODE: Color = Color(1, 1, 1, 0.45)
const LOSS_REASONS: Dictionary[MmPlayer.LossReason, String] = {
	MmPlayer.LossReason.ZERO_LIFE: "ran out of life",
	MmPlayer.LossReason.EMPTY_LIBRARY: "drew from an empty library",
	MmPlayer.LossReason.CONCEDED: "conceded",
}

## The encounter to play next, set by whoever opens this screen: the start form, or the
## command line. Temporary, until runs hand the encounter its setup (A246).
static var request: EncounterRequest = null
## Whether this encounter is part of a run, so that its end goes back into the run.
var is_in_run: bool = false
## What the Pause Menu's Open Run Logs folder does. Tests replace it.
var open_folder: Callable = func() -> void: RunLogShare.open_folder()

## Whether _ready() starts the requested encounter. Tests turn it off and call begin().
var starts_itself: bool = true
## Where the player's settings are kept, or "" to read and save none. A screen that starts
## itself uses the game's own file; one made in a test uses none unless it is given one.
var settings_path: String = ""
## How this screen leaves for another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: SceneFade.change_scene(get_tree(), scene)

var _presenter: EncounterPresenter = null
var _snapshot: EncounterSnapshot = null
var _error: String = ""
## While how much X to pay is asked: what is asked, and the X the stepper shows, which the
## Pass Button pays (game ADR 0063).
## The X being chosen with the stepper: a ChooseXToPayDecision (game ADR 0063), or a
## ChooseXDecision as a spell is cast (engine ADR 0076), or null.
var _x_asked: MmPendingDecision = null
var _x_to_pay: int = 0
## The Selected Answer (game glossary) of the "you may", ward cost or X being asked, as the
## Info Panel numbers them, and the question it is of (game ADR 0066).
var _selected_answer: int = InfoPanel.NOTHING
var _answer_asked: MmPendingDecision = null
var _board: Control
var _panels: Dictionary[int, PlayerPanel] = {}
var _stack_window: ZoneWindow
var _emblem_windows: Dictionary[int, ZoneWindow] = {}
## The Hero's Potions window (ADR 0032); only the Hero is given Potions.
var _potions_window: ZoneWindow
## The entry of each Emblem and Potion in its window, by Game Object ID.
var _held_entries: Dictionary[int, ZoneEntry] = {}
## Which of the Hero's Emblems and Potions windows closed for something used from them.
var _held_windows: HeldWindows = HeldWindows.new()
## While the Option Menu is open for an Emblem with several abilities: its Game Object ID
## and the window it is in. Inspection.NOTHING otherwise.
var _menu_held_id: int = Inspection.NOTHING
var _menu_held_window: HeldWindows.Kind = HeldWindows.Kind.EMBLEMS
## The Hero's library's top card face up on its pile while they may look at it (game ADR
## 0055), or null.
var _library_top_face: CardFace = null
## The Zone Window of each graveyard, exile and library, by its pile's Region, which of
## them have been given a place, and which are open only to answer a target (13f).
var _pile_windows: Dictionary[String, PileWindow] = {}
var _placed_piles: Array[String] = []
var _pile_state: PileWindows = PileWindows.new()
## What takes a click on each pile, by its Region.
var _pile_hosts: Dictionary[String, Control] = {}
var _faces: Dictionary[int, Control] = {}
var _face_sizes: Dictionary[int, Vector2] = {}
## The part of each face that shows and takes the mouse, in the face's own coordinates:
## all of it, or only the name strip of an attachment lying behind another permanent.
var _face_shown: Dictionary[int, Rect2] = {}
## The Tucked Cards (game ADR 0043) as last drawn: the permanents a card can be tucked
## behind, the cards behind each by its ID, the player whose exile each card is in, and
## whether each is in that exile's open Pile Window or behind its permanent. A card that
## was in its window when its permanent went is kept in the last two, though behind
## nothing, until the window closes.
var _tuck_hosts: Array[int] = []
var _tucks: Dictionary[int, Array] = {}
var _tuck_owners: Dictionary[int, int] = {}
var _tuck_in_window: Dictionary[int, bool] = {}
## The player whose exile pile each card in exile is in, by the card's object ID, as last
## drawn. The engine's exile is one zone, so a zone change does not say whose pile it is.
var _exile_owners: Dictionary[int, int] = {}
## The Tuck Outline of each Tucked Card that is in its window, and the ones with a dashed
## border, for the cursor last asked about.
var _tuck_outlines: Dictionary[int, Control] = {}
var _tuck_marked: Array[int] = []
var _tuck_cursor: Vector2 = Vector2.ZERO
## Where each Tucked Card was drawn before a click opened or closed its window, read
## before the window changed; a redraw reads it for itself otherwise.
var _tuck_before: Dictionary[int, FacePose] = {}
var _has_tuck_before: bool = false
## The Villain's hand of card backs, kept outside the redrawn board like the Hand Strip.
var _villain_hand: VillainHand
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
## Where the Hero chooses a creature type (game ADR 0053), kept through redraws.
var _creature_type_window: CreatureTypeWindow
## The Hero's half-made answer to a surveil, and the window it is made in (game ADR 0069),
## kept through redraws; the decision the window was placed for; the cards sent that have
## landed on the Graveyard pile, which counts them; and the cards sent when Done answered,
## which never fly a second time.
var _surveil: SurveilChoice = SurveilChoice.new()
var _surveil_window: SurveilWindow
var _surveil_placed_for: MmPendingDecision = null
var _surveil_landed: Array[int] = []
var _sent_at_done: Array[int] = []
## The Hero's half-made answer to a look at the top of their library, and the window it is
## made in (game ADR 0085), kept through redraws; the decision the window was placed for; the
## cards taken that have landed in the hand, which shows them; and the cards taken when Done
## answered, which never fly a second time.
var _look: LookChoice = LookChoice.new()
var _look_window: LookWindow
var _look_placed_for: MmPendingDecision = null
var _look_landed: Array[int] = []
var _taken_at_done: Array[int] = []
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
## The cards in the air between two zones (13d-2, 13k), over every window.
var _flight_layer: FlightLayer
## A card was put in the air by the snapshot being shown, so the board's faces are posed again.
var _has_taken_off: bool = false
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
## The Hero's hand (13e-1, 13j), kept outside the redrawn board, and the layer above the
## windows where a card of it that is held is drawn.
var _hand_strip: HandStrip
var _drag_layer: Control
## What the pregame has said so far, and the overlay that shows it (13e-2).
var _opening: OpeningHand = OpeningHand.new()
var _overlay: OpeningHandOverlay
## The Hero's half-made choice of cards to put on the bottom or to discard, if one is asked.
var _picks: CardPicks = CardPicks.new()
## Whether the Hero's Library window was last opened for a search, at a search's size.
var _searched_window: bool = false
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
## The sidebar's backing, Dither Shaded as the Inspector is, under the player panels.
var _sidebar: Panel
## Holds the art of the encounter's cards loaded for as long as the screen shows it.
var _warmup: CardWarmup = CardWarmup.new()


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
	_villain_hand = VillainHand.new()
	_villain_hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_villain_hand)
	_hand_strip = HandStrip.new()
	_hand_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand_strip.answered.connect(_answer)
	_hand_strip.menu_wanted.connect(func(options: Array[ClickOption], at: Vector2) -> void:
		_option_menu.open(options, at, _regions["battlefield"]))
	_hand_strip.clicked.connect(_click_hand)
	_hand_strip.offer_changed.connect(func(_option: ClickOption) -> void: _info.show_option(_release_text()))
	add_child(_hand_strip)
	_ghost_layer = Control.new()
	_ghost_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost_layer)
	_block_lines = BlockLines.new()
	add_child(_block_lines)
	# Built once, and painted again only for a new height: painting it takes milliseconds.
	_sidebar = Panel.new()
	_sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sidebar)
	InspectorParts.shade_background(_sidebar, null, Inspector.BACKGROUND, Inspector.BACKGROUND, 0, 0)
	for player_id: int in [VILLAIN, HERO]:
		var panel: PlayerPanel = PlayerPanel.new(player_id, "Hero" if player_id == HERO else "Villain")
		panel.mana_pressed.connect(_answer)
		panel.player_clicked.connect(_answer)
		panel.emblems_pressed.connect(_toggle_emblems.bind(player_id))
		panel.potions_pressed.connect(_toggle_potions)
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
	_choice_window.size = REPLACEMENT_WINDOW_SIZE
	_choice_window.hide()
	add_child(_choice_window)
	_creature_type_window = CreatureTypeWindow.new()
	_creature_type_window.hide()
	_creature_type_window.chosen.connect(_choose_creature_type)
	_creature_type_window.pointed.connect(_on_creature_type_pointed)
	_creature_type_window.escaped.connect(press_key.bind(KEY_ESCAPE))
	add_child(_creature_type_window)
	_surveil_window = SurveilWindow.new()
	_surveil_window.hide()
	_surveil_window.card_clicked.connect(_pick_surveilled)
	_surveil_window.moved.connect(_move_surveilled)
	_surveil_window.graveyard_pressed.connect(_send_surveilled)
	add_child(_surveil_window)
	_look_window = LookWindow.new()
	_look_window.hide()
	_look_window.card_clicked.connect(_pick_looked_at)
	_look_window.moved.connect(_move_looked_at)
	_look_window.hand_pressed.connect(_take_looked_at)
	add_child(_look_window)
	for player_id: int in [HERO, VILLAIN]:
		var emblems: ZoneWindow = ZoneWindow.new("Emblems", true, PlayerPanel.GOLD)
		emblems.size = Vector2(300, 220)
		emblems.hide()
		add_child(emblems)
		_emblem_windows[player_id] = emblems
	_potions_window = ZoneWindow.new("Potions", true, PlayerPanel.POTION_COLOR)
	_potions_window.size = Vector2(300, 160)
	_potions_window.hide()
	add_child(_potions_window)
	for key: String in EncounterLayout.pile_keys():
		var is_row: bool = key.ends_with("library")
		var pile_window: PileWindow = PileWindow.new(PileWindow.Arrangement.ROW if is_row else PileWindow.Arrangement.GRID,
			Color("#6f7f9a") if key.begins_with("hero") else Color("#9a6f6f"), key.ends_with("graveyard"))
		pile_window.card_clicked.connect(_on_object_clicked)
		pile_window.card_hovered.connect(_on_pile_card_hovered)
		# Its Tucked Cards fly back behind their permanents (ADR 0043).
		pile_window.close_button().pressed.connect(_on_pile_closed.bind(key))
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
	# Game ADR 0066: a press of an answer only selects it; the Pass Button gives it.
	_info.answer_pressed.connect(_on_answer_pressed)
	_info.x_lowered.connect(_step_x.bind(-1))
	_info.x_raised.connect(_step_x.bind(1))
	add_child(_info)
	_pass_button = PassButton.new()
	_pass_button.pressed.connect(_on_pass_button_pressed)
	add_child(_pass_button)
	_hold_panel = HoldPanel.new()
	add_child(_hold_panel)
	# Over the board, its windows and the Info Panel; the Emblems windows open over it, so
	# a Status can be read while deciding whether to keep (A392).
	_overlay = OpeningHandOverlay.new()
	_overlay.answered.connect(_answer_overlay)
	_overlay.card_clicked.connect(_put_on_bottom)
	_overlay.confirmed.connect(_confirm_picks)
	_overlay.closed.connect(_show_hand)
	add_child(_overlay)
	for player_id: int in [HERO, VILLAIN]:
		move_child(_emblem_windows[player_id], _overlay.get_index())
	move_child(_potions_window, _overlay.get_index())
	_drag_layer = Control.new()
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_layer)
	_hand_strip.setup(_drag_layer)
	# Over every window, wherever a click has brought one to the front, and over the card
	# of the hand that is raised.
	_flight_layer = FlightLayer.new()
	_flight_layer.z_index = 2
	_flight_layer.setup(_flight_place, _flight_kind)
	_flight_layer.took_off.connect(_on_took_off)
	_flight_layer.landed.connect(_on_landed)
	add_child(_flight_layer)
	_option_menu = OptionMenu.new()
	_option_menu.closed.connect(_on_menu_closed)
	_option_menu.chosen.connect(_on_menu_chosen)
	_option_menu.pointed.connect(func(text: String) -> void: _info.show_option(text))
	add_child(_option_menu)
	_pause_menu = PauseMenu.new()
	_pause_menu.show_share_logs(_settings.is_sharing_run_logs)
	_pause_menu.resume_pressed.connect(set_paused.bind(false))
	_pause_menu.concede_confirmed.connect(_concede)
	_pause_menu.quit_confirmed.connect(_quit)
	_pause_menu.abandon_confirmed.connect(_abandon_run)
	_pause_menu.share_logs_chosen.connect(_set_sharing)
	_pause_menu.open_logs_pressed.connect(func() -> void: open_folder.call())
	_pause_menu.has_share_box = OS.has_feature(MainMenu.PLAYTEST_FEATURE)
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
	is_in_run = request.run != null
	if is_in_run:
		_pause_menu.show_run(request.run.run_seed)
	_panels[VILLAIN].portrait_override = request.villain_portrait
	_panels[VILLAIN].pain_override = request.villain_pain_portrait
	show_backdrop(request.backdrop)
	var setup: MmEncounterSetup = request.setup()
	# Behind the Scene Fade's black, so the first card drawn costs no more than any other.
	_warmup.warm(setup)
	var picture: String = screenshot_path(OS.get_cmdline_user_args())
	# A real encounter keeps an AI Log of the Villain's answers; a screenshot does not.
	var presenter: EncounterPresenter = EncounterPresenter.new(setup,
		request.villain_agent(AiLoggingAgent.FOLDER if picture == "" else ""))
	presenter.names = request.names()
	presenter.card_names = request.card_names
	if picture == "":
		settings_path = GameSettings.PATH
		load_settings()
		use_settings(presenter)
		use_game_pace(presenter)
		for panel: PlayerPanel in _panels.values():
			panel.start_breathing(request.encounter_seed)
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
	_pause_menu.show_share_logs(_settings.is_sharing_run_logs)
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
	_paced_presenter.hang_wait_msec = GameSpeed.msec(Pacing.HANG_MSEC, _speed)
	_motion.seconds = GameSpeed.seconds(Pacing.MOVE_SECONDS, _speed)
	_flight_layer.seconds = GameSpeed.seconds(Pacing.FLIGHT_SECONDS, _speed)
	_flight_layer.gap_seconds = GameSpeed.seconds(Pacing.DRAW_GAP_SECONDS, _speed)
	_overlay.motion().seconds = GameSpeed.seconds(Pacing.DEAL_SECONDS, _speed)
	_overlay.motion().gap_seconds = GameSpeed.seconds(Pacing.DEAL_GAP_SECONDS, _speed)
	set_ease_seconds(GameSpeed.seconds(Pacing.EASE_SECONDS, _speed))


## Lets Glows, marks and windows ease in and out over [param seconds] (Pacing.EASE_SECONDS
## in a real encounter). Tests and screenshots leave it at none.
func set_ease_seconds(seconds: float) -> void:
	_ease_seconds = seconds
	for window: ZoneWindow in [_stack_window, _choice_window, _creature_type_window, _surveil_window, _look_window, _emblem_windows[HERO], _emblem_windows[VILLAIN], _potions_window]:
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
	_hand_strip.frame(delta, get_local_mouse_position())
	_villain_hand.frame(delta)
	follow_preview(_ease_seconds)
	follow_tuck_marks(get_local_mouse_position(), _ease_seconds)


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
	if not _hand_strip.is_pressing() and not _hand_strip.is_holding():
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
	elif click.button_index == MOUSE_BUTTON_RIGHT and click.pressed and _hand_strip.is_holding():
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
		_presenter.stop()


## Does what pressing [param keycode] does. While a row of the Controls Page waits for a key,
## the key is that row's, Escape only stopping the wait. Otherwise Escape lets the Pinned
## card go if there is one, and if not opens and closes the Pause Menu; and while the menu
## is closed any other key does what the Key Bindings say: it passes, undoes, or cancels
## as the Info Panel's Cancel button does when that is showing (ADR 0034). Cancel closes an
## open Option Menu before it cancels anything (ADR 0073).
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
				# An open Option Menu closes first; the next press cancels the cast (ADR 0073).
				if _option_menu.is_open():
					_option_menu.close()
				elif _info.cancel_button() != null:
					_command(_presenter.cancel_cast)
			KeyBindings.Action.PREVIOUS_ANSWER:
				_select_answer(InfoPanel.AFFIRMATIVE)
			KeyBindings.Action.NEXT_ANSWER:
				_select_answer(InfoPanel.NO_ANSWER)
			KeyBindings.Action.RAISE_X:
				_step_x(1)
			KeyBindings.Action.LOWER_X:
				_step_x(-1)


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
	elif _surveil.is_active():
		# Game ADR 0069: Done gives the cards sent and the row's order, and can always be.
		if not _is_paused:
			_sent_at_done = _surveil.sent()
			_answer(_surveil.answer())
	elif _look.is_active():
		# Game ADR 0085: Done gives the cards taken, and can always be; the rest fly face down
		# onto the Library pile.
		if not _is_paused:
			_taken_at_done = _look.taken()
			_fly_rest_to_library()
			_answer(_look.answer())
	elif _answer_asked != null:
		# Game ADR 0066: it gives the Selected Answer, and nothing while there is none.
		if not _is_paused and _selected_answer != InfoPanel.NOTHING:
			_answer(_selected_answer_value())
	elif not _selection.is_active():
		_command(_presenter.pass_priority)
	elif _selection.is_complete() and not _is_paused:
		_answer(_selection.answer())


## The Pass Button was clicked: it does what the pass key does (game ADR 0066).
func _on_pass_button_pressed() -> void:
	pass_priority()


## Answer [param index] of the Answer Row was clicked, InfoPanel.AFFIRMATIVE or NO_ANSWER.
## It is given at once, one click and no confirming (game ADR 0066's addendum). While an X
## is asked the click only selects, the stepper too: the X is still being set, and the Pass
## Button gives it.
func _on_answer_pressed(index: int) -> void:
	if _is_paused or _answer_asked == null:
		return
	if _x_asked != null:
		_select_answer(index)
		return
	_selected_answer = index
	_answer(_selected_answer_value())


## Selects answer [param index] of the question being asked, InfoPanel.AFFIRMATIVE or
## NO_ANSWER, and answers nothing: the Pass Button gives it (game ADR 0066). Left and Right
## do this, and so does a click while an X is asked. X chosen as a spell is cast has no
## "No" to select: Cancel stands in its place (engine ADR 0076).
func _select_answer(index: int) -> void:
	if _is_paused or _answer_asked == null or index == _selected_answer:
		return
	if index == InfoPanel.NO_ANSWER and _answer_asked is ChooseXDecision:
		return
	_selected_answer = index
	_redraw()


## What the engine is answered for the Selected Answer.
func _selected_answer_value() -> Variant:
	var is_yes: bool = _selected_answer == InfoPanel.AFFIRMATIVE
	if _x_asked is ChooseXDecision:
		return _x_to_pay
	if _x_asked != null:
		return ChooseXToPayDecision.answer_for(_x_to_pay) if is_yes else ChooseXToPayDecision.DECLINE
	return ChooseYesOrNoDecision.Choice.YES if is_yes else ChooseYesOrNoDecision.Choice.NO


## What the Pass Button reads for the Selected Answer: "Yes", "No", "Pay {2}".
func _selected_answer_text() -> String:
	if _selected_answer == InfoPanel.NO_ANSWER:
		return InfoPanel.NO
	if _x_asked is ChooseXDecision:
		return CAST_X_FORMAT % _x_to_pay
	if _x_asked != null:
		return PAY_X_FORMAT % _x_to_pay
	return _info.affirmative_text() if _is_asked_to_pay() else YES


## Raises or lowers the X the stepper shows by [param by], from 0 to the most the Hero can
## pay (game ADR 0063), and selects paying it (game ADR 0066).
func _step_x(by: int) -> void:
	if _is_paused or _x_asked == null:
		return
	var x: int = clampi(_x_to_pay + by, 0, EncounterPresenter.most_x_of(_x_asked))
	if x != _x_to_pay or _selected_answer != InfoPanel.AFFIRMATIVE:
		_x_to_pay = x
		_selected_answer = InfoPanel.AFFIRMATIVE
		_redraw()


## Whether the Hero is asked whether to pay a cost, as ward's (ADR 0062) or a land's to
## enter untapped (game ADR 0067).
func _is_asked_to_pay() -> bool:
	var asked: ChooseYesOrNoDecision = _snapshot.decision as ChooseYesOrNoDecision if _snapshot != null else null
	return asked != null and (asked.cost != null or asked.entry_cost != null)


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
	elif not _is_paused and _surveil.is_active() and _surveil.can_undo():
		_undo_surveilled()
	elif not _is_paused and _look.is_active() and _look.can_undo():
		_undo_looked_at()
	elif not _is_paused and _selection.undo():
		_error = ""
		_redraw()
	else:
		_command(_presenter.undo)


## Leaves for [param scene], once a thinking Villain has finished.
func leave(scene: String) -> void:
	_presenter.stop()
	navigate.call(scene)


## Whether something drawn over the hand is under [param cursor]: an open window, the
## Option Menu, or the opening-hand overlay. A press there is theirs, never the card's
## beneath.
func _is_covered(cursor: Vector2) -> bool:
	if _option_menu.is_open():
		return true
	var windows: Array[Control] = [_stack_window, _choice_window, _creature_type_window, _surveil_window, _look_window]
	if _overlay.is_open():
		windows.append(_overlay)
	windows.append_array(_emblem_windows.values())
	windows.append(_potions_window)
	windows.append_array(_pile_windows.values())
	for window: Control in windows:
		# A window fading out is already closed: the cursor is not over it.
		if Easing.is_shown(window) and Rect2(window.position, window.size).has_point(cursor):
			return true
	return false


## The left button went down at [param cursor], a double-click when [param is_double], with
## nothing drawn over the hand there: the Hand Strip takes it if a card of the hand is under
## it, unless the game is paused. Returns whether it did.
func press_hand(cursor: Vector2, is_double: bool) -> bool:
	if _is_paused or _snapshot == null:
		return false
	return _hand_strip.press(cursor, is_double)


## The mouse moved to [param cursor] with a card of the hand pressed or held.
func drag_to(cursor: Vector2) -> void:
	_hand_strip.drag_to(cursor)


## The left button came up at [param cursor] with a card of the hand pressed or held.
func release_hand(cursor: Vector2) -> void:
	_hand_strip.release(cursor)


## Lets go of a card of the hand that is pressed, held or waiting on the Option Menu, back
## to its place: a right-click, or the Pause Menu opening.
func cancel_drag() -> void:
	_hand_strip.cancel()


## The Hero's hand (ADR 0027).
func hand_strip() -> HandStrip:
	return _hand_strip


## The sidebar's Dither Shaded backing, under the player panels.
func sidebar_backing() -> Panel:
	return _sidebar


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
	var in_hand: MmObjectView = _hand_view(_hand_strip.card_under(cursor))
	if in_hand != null:
		return in_hand.id
	for object_id: int in _faces:
		var face: Control = _faces[object_id]
		if _snapshot.looks.has(object_id) and is_instance_valid(face) and face.is_visible_in_tree() \
				and _face_shown[object_id].has_point(face.get_global_transform().affine_inverse() * at):
			return object_id
	return Inspection.NOTHING


## The card of the opening hand drawn at [param cursor], or Inspection.NOTHING: none while
## cards are in the air, when they may be face down, and none under an Emblems window.
func _opening_card_at(cursor: Vector2) -> int:
	if _overlay.motion().is_moving():
		return Inspection.NOTHING
	for window: ZoneWindow in _held_window_list():
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
	for object_id: int in _held_entries:
		var held: ZoneEntry = _held_entries[object_id]
		if is_instance_valid(held) and held.is_visible_in_tree() and Easing.is_shown(_window_of(held)):
			entries[object_id] = held
	for key: String in _pile_windows:
		var pile: PileWindow = _pile_windows[key]
		if not Easing.is_shown(pile):
			continue
		for object_id: int in pile.entries():
			if object_id != PileWindow.UNKNOWN and pile.face_of(object_id) != null:
				entries[object_id] = pile.face_of(object_id)
	if Easing.is_shown(_surveil_window):
		for object_id: int in _surveil_window.entries():
			if _surveil_window.face_of(object_id) != null:
				entries[object_id] = _surveil_window.face_of(object_id)
	if Easing.is_shown(_look_window):
		for object_id: int in _look_window.entries():
			if _look_window.face_of(object_id) != null:
				entries[object_id] = _look_window.face_of(object_id)
	var top: MmObjectView = _seen_library_top(HERO) if _snapshot != null else null
	if top != null and is_instance_valid(_library_top_face) and not entries.has(top.id):
		entries[top.id] = _library_top_face
	return entries


## Both Emblems windows and the Potions window.
func _held_window_list() -> Array[ZoneWindow]:
	return [_emblem_windows[HERO], _emblem_windows[VILLAIN], _potions_window]


## The Emblems or Potions window [param entry] is in.
func _window_of(entry: ZoneEntry) -> ZoneWindow:
	for window: ZoneWindow in _held_window_list():
		if window.is_ancestor_of(entry):
			return window
	return null


## Whether a card of the hand or a trigger being ordered is held.
func _is_dragging() -> bool:
	return _hand_strip.is_holding() or (_is_trigger_pressed() and _trigger_list.is_holding())


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
		_inspector.let_go()
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
	var rarity: Variant = _snapshot.rarity_of(shown) if _snapshot.has_rarity(shown) else null
	_inspector.show_card(shown, look, _snapshot.original_of(shown), rarity, _snapshot.state_information_of(subject),
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
	if seen != null and _snapshot.view.hand.has(seen) and _hand_strip.face_of(seen.card_id) != null:
		return _hand_strip.face_of(seen.card_id)
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
	_flight_layer.frame(delta)
	# The hand takes a drawn card in with a redraw, which closes the Option Menu, so that
	# waits for a menu that is open: the board it was opened on is still the one drawn.
	if _has_draw_landed and not _option_menu.is_open():
		_has_draw_landed = false
		_is_hand_easing = true
		_redraw()
		_is_hand_easing = false


func face_motion() -> FaceMotion:
	return _motion


## The layer where cards fly between zones (ADR 0027).
func flight_layer() -> FlightLayer:
	return _flight_layer


## The card drawn in the air on its way to being Game Object [param object_id], or null
## once it has landed.
func flight_card_of(object_id: int) -> FlightCard:
	return _flight_layer.flight_card_of(object_id)


## The fading face of Game Object [param object_id], which has left the battlefield, or
## null once it has gone.
func ghost_of(object_id: int) -> BattlefieldFace:
	return _ghosts.get(object_id, null) as BattlefieldFace


## The Control that draws Game Object [param object_id], or null if none is on screen: a
## card of the Hero's hand is drawn by the Hand Strip.
func face_of(object_id: int) -> Control:
	var face: Control = _faces.get(object_id, null) as Control
	if face != null or _snapshot == null:
		return face
	for in_hand: MmObjectView in _snapshot.view.hand:
		if in_hand.id == object_id:
			return _hand_strip.face_of(in_hand.card_id)
	return null


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


## The window where the Hero chooses a creature type (game ADR 0053).
func creature_type_window() -> CreatureTypeWindow:
	return _creature_type_window


## Where the Hero surveils (game ADR 0069), kept through redraws.
func surveil_window() -> SurveilWindow:
	return _surveil_window


## Where the Hero looks at the top of their library (game ADR 0085), kept through redraws.
func look_window() -> LookWindow:
	return _look_window


## What takes a click on the choice window's entry number [param index].
func choice_catcher(index: int) -> ClickCatcher:
	return ClickCatcher.of(_choice_entries[index])


## The Zone Window of the pile in Region [param key], such as "hero_graveyard".
func pile_window(key: String) -> PileWindow:
	return _pile_windows[key]


## The Tuck Outline of the Tucked Card [param object_id], or null while it is not in its
## Pile Window.
func tuck_outline_of(object_id: int) -> Control:
	return _tuck_outlines.get(object_id, null) as Control


## What takes a click on the pile in Region [param key].
func pile_catcher(key: String) -> ClickCatcher:
	return ClickCatcher.of(_pile_hosts[key])


## Whether the permanent [param object_id] is drawn turned: tapped, or picked to be tapped.
func is_drawn_tapped(object_id: int) -> bool:
	for permanent: MmObjectView in _snapshot.view.battlefield:
		if permanent.id == object_id:
			return _is_drawn_tapped(permanent)
	return false


## The colors the pile in Region [param key] glows in: a target's, while a card in it can
## be chosen, and green while one can be cast from it.
func pile_glow(key: String) -> Array[Color]:
	var host: Control = _pile_hosts[key]
	var colors: Array[Color] = BorderEffects.glow_colors(host)
	if colors.is_empty() and host.get_child_count() > 0:
		# The Hero's library while its top card shows glows round the backs too.
		colors = BorderEffects.glow_colors(host.get_child(0) as Control)
	return colors


## The top card of the Hero's library drawn face up on its pile, or null (game ADR 0055).
func library_top_face() -> CardFace:
	return _library_top_face if is_instance_valid(_library_top_face) else null


func emblems_window(player_id: int) -> ZoneWindow:
	return _emblem_windows[player_id]


## The Hero's Potions window.
func potions_window() -> ZoneWindow:
	return _potions_window


## The entry of the Emblem or Potion with Game Object ID [param object_id] in its window,
## or null.
func held_entry(object_id: int) -> ZoneEntry:
	var entry: ZoneEntry = _held_entries.get(object_id, null) as ZoneEntry
	return entry if entry != null and is_instance_valid(entry) else null


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
	return _villain_hand.count()


## The Villain's hand of card backs.
func villain_hand() -> VillainHand:
	return _villain_hand


## The scrolling line named [param key] ("hero_creatures", "hero_others",
## "villain_creatures" or "villain_others"), or null if that player has none there.
func line(key: String) -> ScrollRow:
	return _lines.get(key, null) as ScrollRow


## What is written under the pile in Region [param key], such as "Exile (0)".
func pile_text(key: String) -> String:
	return _pile_labels[key].text


## The Hero's controls live in their player panel, under the Emblems button.
func pass_button() -> PassButton:
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
	if not _surveil.is_for(snapshot.decision if SurveilChoice.covers(snapshot.decision) else null):
		_surveil = SurveilChoice.new(snapshot.decision if SurveilChoice.covers(snapshot.decision) else null)
		_surveil_landed.clear()
	if not _look.is_for(snapshot.decision if LookChoice.covers(snapshot.decision) else null):
		_look = LookChoice.new(snapshot.decision if LookChoice.covers(snapshot.decision) else null)
		_look_landed.clear()
	var asked_x: MmPendingDecision = snapshot.decision \
		if snapshot.decision is ChooseXToPayDecision or snapshot.decision is ChooseXDecision else null
	if asked_x != _x_asked:
		_x_asked = asked_x
		_x_to_pay = _presenter.starting_x() if asked_x != null else 0
	# Game ADR 0066: a "you may" starts on Yes; a question that spends mana, on nothing.
	var asked_answer: MmPendingDecision = snapshot.decision \
		if snapshot.decision is ChooseYesOrNoDecision or asked_x != null else null
	if asked_answer != _answer_asked:
		_answer_asked = asked_answer
		var is_free: bool = asked_answer is ChooseYesOrNoDecision and (asked_answer as ChooseYesOrNoDecision).cost == null \
			and (asked_answer as ChooseYesOrNoDecision).entry_cost == null
		_selected_answer = InfoPanel.AFFIRMATIVE if is_free else InfoPanel.NOTHING
	var previous: EncounterSnapshot = _snapshot
	# Nothing flies through the pregame, whose cards the overlay holds.
	var may_fly: bool = not _opening.is_open()
	_opening.read(snapshot)
	_snapshot = snapshot
	_error = ""
	_is_snapping = _is_snapping or snapshot.is_rewind
	_wince_the_hurt(previous, snapshot)
	# An answer means something else in a new snapshot, so the preview is asked for afresh,
	# and shown at once: the cursor may not have moved.
	_previewed = NO_PREVIEW
	var redraw: Callable = func() -> void:
		_redraw()
		follow_preview(0.0)
	if not may_fly:
		redraw.call()
		return
	# Where each card that changed zones was is read from what is still drawn, before the
	# redraw, and where it lands from what the redraw draws.
	_has_taken_off = false
	_flight_layer.show_snapshot(previous, snapshot, redraw)
	_sent_at_done.clear()
	_taken_at_done.clear()
	if _has_taken_off:
		_pose_faces()
		_hide_landing_places()


## Each player who lost life since [param previous] shows their Pain Portrait for as long as
## what they lost asks, and one who lost the encounter by it keeps showing it.
func _wince_the_hurt(previous: EncounterSnapshot, snapshot: EncounterSnapshot) -> void:
	var losses: Dictionary[int, int] = PainHold.losses(previous, snapshot)
	for player_id: int in losses:
		if not _panels.has(player_id):
			continue
		var has_lost: bool = snapshot.view.is_over and snapshot.view.winner_id != player_id \
			and snapshot.view.life_totals.has(snapshot.view.winner_id)
		_panels[player_id].wince(PainHold.seconds(losses[player_id], _speed), has_lost)


## A pile was clicked: its window opens, or closes if it was open.
func _toggle_pile(key: String) -> void:
	if _is_paused:
		return
	var window: PileWindow = _pile_windows[key]
	# Its Tucked Cards fly to the window or back (ADR 0043), from where they are drawn now.
	var has_tucks: bool = _has_tucks_in(key)
	if has_tucks:
		_tuck_before = _tuck_poses()
		_has_tuck_before = true
	if window.is_open():
		window.close()
	else:
		_open_pile(key)
	_pile_state.toggled(key, window.is_open(), _clicks)
	if has_tucks:
		_redraw()


## The window of the pile in Region [param key] was closed with its own button.
func _on_pile_closed(key: String) -> void:
	if _has_tucks_in(key):
		_redraw()


## Whether the pile in Region [param key] is an exile with a Tucked Card in it.
func _has_tucks_in(key: String) -> bool:
	for object_id: int in _tuck_owners:
		if _exile_key(_tuck_owners[object_id]) == key:
			return true
	return false


## The Region of the exile pile of [param player_id].
func _exile_key(player_id: int) -> String:
	return EncounterLayout.pile_key(MmZone.Kind.EXILE, player_id == HERO)


## The permanents a card can be tucked behind: the ones that stand in a line of nonland
## permanents, which leaves out an attachment lying behind its creature or its land.
func _standing_ids(view: MmPlayerView) -> Array[int]:
	var standing: Array[int] = []
	var land_ids: Array[int] = _land_ids(view)
	for player_id: int in [VILLAIN, HERO]:
		var nonlands: Array[MmObjectView] = _permanents(view, player_id, false)
		var creature_ids: Array[int] = []
		for permanent: MmObjectView in nonlands:
			if permanent.is_creature:
				creature_ids.append(permanent.id)
		for permanent: MmObjectView in nonlands:
			if permanent.is_creature or not (Attachments.is_drawn_attached(permanent, creature_ids)
					or Attachments.is_drawn_attached(permanent, land_ids)):
				standing.append(permanent.id)
	return standing


## Reads from the snapshot which cards are tucked behind which permanents, and from the
## Pile Windows which of them are in a window now (ADR 0043).
func _read_tucks() -> void:
	_exile_owners.clear()
	for player_id: int in _snapshot.view.exiles:
		for card: MmObjectView in _snapshot.view.exiles[player_id]:
			_exile_owners[card.id] = player_id
	_tuck_hosts = _standing_ids(_snapshot.view)
	_tucks = Tucks.by_host(_snapshot.view, _tuck_hosts)
	var owners: Dictionary[int, int] = Tucks.owners(_snapshot.view, _tuck_hosts)
	# A card that was in its window when its permanent went stays there while the window is
	# open, and leaves exile from there.
	for object_id: int in _tuck_in_window:
		var owner_id: int = _tuck_owners[object_id]
		if _tuck_in_window[object_id] and not owners.has(object_id) and _is_in_exile(object_id, owner_id):
			owners[object_id] = owner_id
	_tuck_owners = owners
	_tuck_in_window.clear()
	for object_id: int in _tuck_owners:
		_tuck_in_window[object_id] = _pile_windows[_exile_key(_tuck_owners[object_id])].is_open()
	for object_id: int in _tuck_owners.keys():
		if not _tuck_in_window[object_id] and not Tucks.owners(_snapshot.view, _tuck_hosts).has(object_id):
			_tuck_owners.erase(object_id)
			_tuck_in_window.erase(object_id)


## Where each Tucked Card is drawn right now: in the air, in its window, or behind its
## permanent.
func _tuck_poses() -> Dictionary[int, FacePose]:
	var poses: Dictionary[int, FacePose] = {}
	for object_id: int in _tuck_in_window:
		var flying: FacePose = _flight_layer.pose_of(object_id)
		if flying != null:
			poses[object_id] = flying
		elif _tuck_in_window[object_id]:
			poses[object_id] = _window_place(_exile_key(_tuck_owners[object_id]), object_id)
		elif _rest.has(object_id):
			poses[object_id] = _field_flight_place(object_id, false)
	return poses


## Puts in the air each Tucked Card that is drawn somewhere else now than at
## [param before], though it changed no zone: into its window as that opened, back behind
## its permanent as it closed, or onto its pile because its permanent has gone and it is
## exiled for good (ADR 0043). [param was_in_window] and [param owners] are how they were
## drawn then. Called before the board is rebuilt.
func _fly_tucks(before: Dictionary[int, FacePose], was_in_window: Dictionary[int, bool], owners: Dictionary[int, int]) -> void:
	for object_id: int in before:
		var was_there: bool = was_in_window[object_id]
		var is_still_tucked: bool = _tuck_in_window.has(object_id)
		if is_still_tucked and _tuck_in_window[object_id] == was_there:
			continue
		# One that left exile has a Card Flight of its own, and one in the window stays there.
		if not is_still_tucked and (was_there or not _is_in_exile(object_id, owners[object_id])):
			continue
		if not was_there:
			_motion.forget(object_id)
		if _is_snapping:
			continue
		var route: CardFlights.Route = CardFlights.Route.new()
		route.first_object_id = object_id
		route.object_id = object_id
		route.from_zone_kind = MmZone.Kind.EXILE
		route.to_zone_kind = MmZone.Kind.EXILE
		route.from_owner_id = owners[object_id]
		route.to_owner_id = owners[object_id]
		_flight_layer.put_in_air(route, before[object_id], FlightCard.Kind.CARD if was_there else FlightCard.Kind.FIELD,
				_snapshot.look_of(object_id))


func _is_in_exile(object_id: int, player_id: int) -> bool:
	for card: MmObjectView in _snapshot.view.exiles.get(player_id, []):
		if card.id == object_id:
			return true
	return false


## Where a card flying to or from the card [param object_id] in the window of the pile in
## Region [param key] is drawn: on the card, or small and unseen at the nearest edge of
## what the window shows for a card scrolled out of sight, where it fades.
func _window_place(key: String, object_id: int) -> FacePose:
	var window: PileWindow = _pile_windows[key]
	var place: Rect2 = window.flight_place(object_id)
	return FacePose.of(window.global_position + place.position - global_position, place.size.y, 0.0,
			0.0 if window.hidden_past(object_id) != 0 else 1.0)


## Gives the Tuck Outline of the card under [param cursor] in a Pile Window, and that of
## the Pinned card, a white dashed border, easing over [param seconds], and takes it off
## any other (ADR 0043). Called every frame.
func follow_tuck_marks(cursor: Vector2, seconds: float) -> void:
	_tuck_cursor = cursor
	if _snapshot == null:
		return
	var wanted: Array[int] = []
	if not _tuck_outlines.is_empty():
		for object_id: int in [inspectable_at(cursor), _inspection.shown()]:
			if _tuck_outlines.has(object_id) and not wanted.has(object_id):
				wanted.append(object_id)
	for object_id: int in _tuck_marked.duplicate():
		if not wanted.has(object_id):
			BorderEffects.remove_mark(_tuck_outlines[object_id], seconds)
			_tuck_marked.erase(object_id)
	for object_id: int in wanted:
		if not _tuck_marked.has(object_id):
			BorderEffects.add_mark(_tuck_outlines[object_id], _tuck_outlines[object_id].size, Color.WHITE, true, seconds)
			_tuck_marked.append(object_id)


## The Villain's Known Cards, face up in their hand (game ADR 0058).
func _show_known_villain_cards(view: MmPlayerView) -> void:
	var ids: Array[int] = []
	var looks: Array[CardLook] = []
	for known: MmObjectView in view.known_in_hands.get(VILLAIN, []):
		ids.append(known.id)
		looks.append(_snapshot.look_of(known.id))
	_villain_hand.show_known(ids, looks)


## Opens the window of the pile in Region [param key], with what the zone holds now: beside
## its pile the first time, and where it was left after that.
func _open_pile(key: String) -> void:
	var window: PileWindow = _pile_windows[key]
	if key == "hero_library" and _picks.is_searching():
		# Game ADR 0058: a search's grid is as wide as the board left of the piles, over
		# the Hero's side, and three cards high.
		var battlefield: Rect2 = _regions["battlefield"]
		var left: float = battlefield.position.x + 8.0
		var card_height: float = PileWindow.CARD_HEIGHT + PileWindow.GAP
		window.size = Vector2(_regions[key].position.x - 16.0 - left,
			3.0 * card_height + 2.0 * PileWindow.GLOW_ROOM + ZoneWindow.BAR_HEIGHT + 36.0)
		window.position = Vector2(left, battlefield.end.y - window.size.y - 8.0)
		_searched_window = true
	elif key == "hero_library" and _searched_window:
		# Back to its usual size and place once a search is done.
		window.size = PileWindow.OPENING_SIZE
		window.position = EncounterLayout.pile_window_position(_regions[key], window.size, 0)
		_searched_window = false
	elif not _placed_piles.has(key):
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
	var cards: Array = _graveyard_shown(player_id)
	var zone_name: String = "Graveyard"
	if key.ends_with("exile"):
		cards = view.exiles.get(player_id, [])
		zone_name = "Exile"
	elif key.ends_with("library"):
		cards = view.libraries.get(player_id, [])
		zone_name = "Library"
	var picks: CardPicks = _picks if key == "hero_library" and _picks.is_searching() else null
	_pile_windows[key].show_cards("%s %s" % [_snapshot.names.possessive(player_id), zone_name], cards, _snapshot, _clicks, picks)


## The top card of [param player_id]'s library while the Hero may look at it (game ADR
## 0055): only ever the Hero's own, or null.
func _seen_library_top(player_id: int) -> MmObjectView:
	var view: MmPlayerView = _snapshot.view
	if player_id != view.viewer_id or not view.looks_at_library_top:
		return null
	var library: Array = view.libraries.get(player_id, [])
	return null if library.is_empty() else library[0] as MmObjectView


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
	var glow_box: Rect2 = Rect2(Vector2.ZERO, card)
	if key == "hero_library" and _seen_library_top(HERO) != null:
		# Round the top card and the backs peeking out above and to the right of it.
		glow_box = SEEN_PILE_BOX
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(host)
	_pile_hosts[key] = host
	if _clicks.piles().has(key):
		var glow: Control = host
		if glow_box.size != card:
			glow = Control.new()
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glow.position = glow_box.position
			glow.size = card + glow_box.size
			host.add_child(glow)
		BorderEffects.add_glow(glow, glow.size, DecisionClicks.color_of(_clicks.pile_kind_of(key)), _ease_seconds)
	ClickCatcher.add(host, card + Vector2(0, EncounterLayout.PILE_LABEL)).clicked.connect(_toggle_pile.bind(key))


func _toggle_emblems(player_id: int) -> void:
	var window: ZoneWindow = _emblem_windows[player_id]
	window.set_open(not window.is_open())
	window.move_to_front()


func _toggle_potions() -> void:
	_potions_window.set_open(not _potions_window.is_open())
	_potions_window.move_to_front()


## An Emblem or a Potion that can be used was clicked in the window [param key]: one
## ability is activated at once, and several open the Option Menu (ADR 0032).
func _on_held_clicked(object_id: int, window: HeldWindows.Kind) -> void:
	if _is_paused:
		return
	var options: Array[ClickOption] = _clicks.options_of(object_id)
	if options.size() == 1:
		_use_held(window, options[0].answer, object_id)
	elif options.size() > 1:
		_option_menu.open(options, get_local_mouse_position(), _regions["battlefield"])
		# After opening: the menu closes any it had open first, which forgets the last one.
		_menu_held_id = object_id
		_menu_held_window = window


## A row of the Option Menu was chosen. If the menu was opened for an Emblem and the row is
## one of that Emblem's abilities, its window closes first. The menu says it has closed
## before it says what was chosen, so the Emblem is forgotten here and not on closing; an
## answer that is not the Emblem's, from a menu opened since for something else, is given
## as any other is.
func _on_menu_chosen(hero_answer: Variant) -> void:
	var held_id: int = _menu_held_id
	_menu_held_id = Inspection.NOTHING
	for option: ClickOption in _clicks.options_of(held_id) if held_id != Inspection.NOTHING else ([] as Array[ClickOption]):
		if option.answer == hero_answer:
			_use_held(_menu_held_window, hero_answer, held_id)
			return
	_answer(hero_answer)


## Gives [param hero_answer], which uses the Emblem or Potion [param object_id]. Its window
## closes at once, with a target to choose or without, so the board is clear, and comes
## back if the activation is canceled or undone (A528). An answer that is refused changes
## nothing, so the window is put back.
func _use_held(held_window: HeldWindows.Kind, hero_answer: Variant, object_id: int) -> void:
	var window: ZoneWindow = _held_window(held_window)
	_held_windows.started(held_window, object_id)
	window.close()
	var reason: String = _presenter.answer(hero_answer)
	if reason != "":
		_held_windows.forget(held_window, object_id)
		window.open()
		_error = reason
		_redraw()


func _held_window(held_window: HeldWindows.Kind) -> ZoneWindow:
	return _potions_window if held_window == HeldWindows.Kind.POTIONS else _emblem_windows[HERO]


## Reopens a window that closed for something used from it, once that is taken back.
func _show_held_windows() -> void:
	_held_windows.follow(_snapshot)
	for held_window: HeldWindows.Kind in _held_windows.to_reopen:
		_held_window(held_window).open()


## Quit to main menu, confirmed. In a run, the run stays saved and the encounter starts over
## on Continue; its answers so far go to the Run Log (milestone 21).
func _quit() -> void:
	if not is_in_run:
		leave(MENU)
		return
	_presenter.stop()
	leave(Screens.scene(RunFlow.quit(_presenter.record())))


## Abandon Run, confirmed: the run ends, its save is deleted, and the main menu opens.
func _abandon_run() -> void:
	_presenter.stop()
	leave(Screens.scene(RunFlow.abandon(_presenter.record())))


## The Share Run Logs box was pressed: the choice is kept with the other settings.
func _set_sharing(is_on: bool) -> void:
	_settings.has_answered_sharing = true
	_settings.is_sharing_run_logs = is_on
	_settings.save_to(settings_path)


func _concede() -> void:
	_command(_presenter.concede)
	set_paused(false)


## A permanent that a click answers something on was clicked: one answer is given at once,
## and several open the Option Menu where the cursor is (A285, A286).
func _on_object_clicked(object_id: int) -> void:
	if _is_paused:
		return
	if _picks.is_searching():
		# Game ADR 0058: a click selects a card or lets it go; only the pass button finds.
		if _picks.toggle(object_id):
			_redraw()
		return
	if _picks.is_targeting():
		# "Up to" targets: a click picks a target or lets it go. The pick that leaves
		# nothing more to pick answers; fewer are answered with the pass button (game
		# ADR 0022).
		var was_picked: bool = _picks.is_picked(object_id)
		if _picks.toggle(object_id):
			if not was_picked and _picks.has_nothing_left_to_pick():
				_confirm_picks()
			else:
				_redraw()
		return
	if _picks.is_picking_permanents():
		# The click that makes the last pick answers at once: nothing is left to decide
		# (game ADR 0049).
		if _picks.toggle(object_id):
			if _picks.is_complete():
				_confirm_picks()
			else:
				_redraw()
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
	_menu_held_id = Inspection.NOTHING
	_clear_marks()
	_glowed_before.clear()
	for object_id: int in _faces:
		if is_instance_valid(_faces[object_id]) and BorderEffects.glow_color(_faces[object_id]) != null:
			_glowed_before[object_id] = BorderEffects.glow_colors(_faces[object_id])
	_is_redrawing = true
	# Where each Tucked Card is drawn, before anything moves (ADR 0043).
	var tucks_before: Dictionary[int, FacePose] = _tuck_before if _has_tuck_before else _tuck_poses()
	var tucks_were_in_window: Dictionary[int, bool] = _tuck_in_window.duplicate()
	var tuck_owners_before: Dictionary[int, int] = _tuck_owners.duplicate()
	_has_tuck_before = false
	_tuck_before = {}
	if _is_snapping or size != _drawn_size:
		# A rewind or a window of another size: every card in the air is where it lands.
		_flight_layer.land_all()
	_overlay.glow_seconds = _ease_seconds
	for panel: PlayerPanel in _panels.values():
		panel.glow_seconds = _ease_seconds
	var unseen: Array[int] = _unseen_faces()
	for child: Node in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	_faces.clear()
	_face_sizes.clear()
	_face_shown.clear()
	_tuck_outlines.clear()
	_tuck_marked.clear()
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
	elif _x_asked != null and _presenter.x_payment_plan(_x_to_pay) != null:
		# Game ADR 0063: what Auto-tap would tap for the X the stepper shows glows.
		glow = DecisionClicks.of_payment(_presenter.x_payment_plan(_x_to_pay))
	# While blockers are picked up, the attackers any of them can block glow as targets (A313, A431).
	for attacker_id: int in _selection.target_ids():
		glow.glow_as(attacker_id, DecisionClicks.Kind.TARGET)
	# A creature the engine has attacking or blocking glows gold until combat ends, after
	# whatever else it glows as (game ADR 0022). It takes no click for that.
	if not _snapshot.is_over():
		for permanent: MmObjectView in view.battlefield:
			if _is_fighting(permanent):
				glow.glow_in_combat(permanent.id)
	_clicks = glow
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(size)
	_regions = regions
	_place_windows(regions["battlefield"])
	# The Pile Windows first: a Tucked Card is drawn in its exile's window while that is
	# open and behind its permanent otherwise, and flies from one to the other (ADR 0043).
	_show_pile_windows()
	_read_tucks()
	_fly_tucks(tucks_before, tucks_were_in_window, tuck_owners_before)
	var plates: Array[Rect2] = []
	plates.assign(EncounterLayout.zone_plates(regions).values())
	_zone_plates.place(plates)

	_sidebar.position = regions["sidebar"].position
	_sidebar.size = regions["sidebar"].size
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
	elif _surveil.is_active():
		_panels[HERO].show_undo(_surveil.can_undo() or (_snapshot.can_undo and not _snapshot.is_villain_thinking))
		_show_confirm(DONE, true, _surveil.can_undo())
	elif _look.is_active():
		_panels[HERO].show_undo(_look.can_undo() or (_snapshot.can_undo and not _snapshot.is_villain_thinking))
		_show_confirm(DONE, true, _look.can_undo())
	_add_player_stepper()
	# Like the Hero's, the Villain's hand eases aside for a drawn card that has landed.
	_villain_hand.show_hand(view.hand_sizes.get(VILLAIN, 0) - _flight_layer.drawn_in_air(VILLAIN).size(),
			regions["villain_hand"], _is_hand_easing)
	_show_known_villain_cards(view)
	# An Aura on a land lies behind it in that land's row, whoever controls it (ADR 0042).
	var on_lands: Dictionary[int, Array] = Attachments.by_host(_all_nonlands(view), _land_ids(view))
	_draw_row(_permanents(view, VILLAIN, true), regions["villain_lands"], glow, on_lands)
	_draw_nonlands(view, VILLAIN, regions["villain_nonlands"], glow)
	_draw_nonlands(view, HERO, regions["hero_nonlands"], glow)
	_draw_row(_permanents(view, HERO, true), regions["hero_lands"], glow, on_lands)
	for player_id: int in [VILLAIN, HERO]:
		var who: String = "hero" if player_id == HERO else "villain"
		# Game ADR 0069's addendum: a card a scry sends to the bottom is still in the library.
		var graveyarded: int = 0 if _surveil.is_scry() else _surveil_landed.size()
		var landed: int = graveyarded + _look_landed.size() if player_id == HERO else 0
		_draw_library(view.library_sizes.get(player_id, 0) - landed, who + "_library", regions[who + "_library"])
		var graveyard: Array = _graveyard_shown(player_id)
		var exile: Array = view.exiles.get(player_id, [])
		_draw_pile("Graveyard", graveyard, graveyard, who + "_graveyard", regions[who + "_graveyard"])
		# The pile counts its Tucked Cards and does not show them (ADR 0043).
		_draw_pile("Exile", exile, Tucks.loose(exile, _tuck_hosts), who + "_exile", regions[who + "_exile"])
		for zone: String in ["library", "graveyard", "exile"]:
			_add_pile_host("%s_%s" % [who, zone], regions["%s_%s" % [who, zone]])
	_held_entries.clear()
	for player_id: int in [VILLAIN, HERO]:
		_fill_emblems_window(player_id)
	_fill_potions_window()
	_show_held_windows()
	_fill_stack_window(view)
	_mark_asked_targets()
	_fill_choice_window(view)
	_fill_creature_type_window(view, regions)
	_fill_surveil_window(regions)
	_fill_look_window(regions)
	_info.show_snapshot(_snapshot, _error, regions["info"], _selection.hint())
	_info.show_x(_x_to_pay)
	_info.show_selected(_selected_answer)
	if _answer_asked != null:
		# After the panel: a ward cost's answer reads as the panel's own does.
		var has_answer: bool = _selected_answer != InfoPanel.NOTHING
		_pass_button.show_confirm(_selected_answer_text() if has_answer else CHOOSE_AN_ANSWER, has_answer, has_answer)
	_info.show_undeclare(not _selection.attacker_ids().is_empty())
	_hold_panel.place(regions["hold"])
	_show_hand()
	_info.show_option(_release_text())
	if _snapshot.decision is ChooseCreatureTypeDecision:
		_on_creature_type_pointed(_creature_type_window.pointing())
	_move_faces(unseen)
	_flight_layer.aim_put(_snapshot)
	_tint_arrows()
	_show_block_lines()
	if _snapshot.is_over():
		_draw_banner(view)
	_show_overlay()
	_show_picks()
	_hide_landing_places()
	if _preview_plan() != null:
		_panels[HERO].mark_pool(_preview_plan().pool_types)
	_is_redrawing = false
	_glowed_before.clear()
	_redraw_inspector()
	follow_tuck_marks(_tuck_cursor, 0.0)


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
		_potions_window.position = Vector2(battlefield.position.x + 720, battlefield.end.y - 180)
	for window: ZoneWindow in [_stack_window, _choice_window, _creature_type_window, _surveil_window, _look_window, _emblem_windows[HERO], _emblem_windows[VILLAIN], _potions_window]:
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


## Draws a row of lands. The permanents in [param attached], by the ID of the land each is
## attached to, lie behind it sideways at its height, and the row gives each land the room
## of their name strips (ADR 0042).
func _draw_row(permanents: Array[MmObjectView], row_rect: Rect2, glow: DecisionClicks,
		attached: Dictionary[int, Array] = {}) -> void:
	var is_tapped: Array[bool] = _tapped(permanents)
	var counts: Array[int] = []
	for permanent: MmObjectView in permanents:
		counts.append((attached.get(permanent.id, []) as Array).size())
	var footprints: Array[Rect2] = EncounterLayout.row(is_tapped, row_rect, counts)
	var height: float = EncounterLayout.row_face_height(is_tapped, row_rect, counts)
	for index: int in permanents.size():
		var permanent: MmObjectView = permanents[index]
		var face: BattlefieldFace = BattlefieldFace.new()
		face.setup(_board_look(permanent), height)
		face.position = footprints[index].position
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The outermost attachment is drawn first and the land last, over them all.
		var behind: Array = attached.get(permanent.id, [])
		for place: int in range(behind.size() - 1, -1, -1):
			var attachment: MmObjectView = behind[place]
			var lying: Rect2 = EncounterLayout.attached_place(footprints[index], height, place)
			var attached_face: BattlefieldFace = BattlefieldFace.new()
			attached_face.setup(_board_look(attachment), height, true)
			attached_face.position = lying.position
			attached_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_board.add_child(attached_face)
			_remember_face(attachment.id, attached_face, lying.size, glow,
					EncounterLayout.attached_shown(lying.size, EncounterLayout.attached_strip(height)))
		_board.add_child(face)
		_remember_face(permanent.id, face, footprints[index].size, glow)


## Every land on the battlefield, either player's.
func _land_ids(view: MmPlayerView) -> Array[int]:
	var ids: Array[int] = []
	for player_id: int in [VILLAIN, HERO]:
		for land: MmObjectView in _permanents(view, player_id, true):
			ids.append(land.id)
	return ids


## Every nonland permanent on the battlefield, either player's.
func _all_nonlands(view: MmPlayerView) -> Array[MmObjectView]:
	return _permanents(view, VILLAIN, false) + _permanents(view, HERO, false)


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
	var nonlands: Array[MmObjectView] = _permanents(view, player_id, false)
	var creature_ids: Array[int] = []
	for permanent: MmObjectView in nonlands:
		if permanent.is_creature:
			creatures.append(permanent)
			creature_ids.append(permanent.id)
	# An attachment lies behind its creature, or its land in the lands row, and leaves the
	# other permanents (ADR 0042).
	var attached: Dictionary[int, Array] = Attachments.by_host(nonlands, creature_ids)
	var land_ids: Array[int] = _land_ids(view)
	for permanent: MmObjectView in nonlands:
		if not permanent.is_creature and not Attachments.is_drawn_attached(permanent, creature_ids) \
				and not Attachments.is_drawn_attached(permanent, land_ids):
			others.append(permanent)
	# A Tucked Card lies behind the permanent that exiled it, past its attachments (ADR 0043).
	for host_id: int in _tucks:
		var behind: Array = (attached.get(host_id, []) as Array).duplicate()
		behind.append_array(_tucks[host_id])
		attached[host_id] = behind
	creatures = _fighting_first(creatures)
	var other_heights: Array[float] = []
	var other_extras: Array[float] = []
	for other: MmObjectView in others:
		other_heights.append(EncounterLayout.others_height(row_rect))
		other_extras.append(EncounterLayout.attached_room(EncounterLayout.others_height(row_rect), (attached.get(other.id, []) as Array).size()))
	var groups: Dictionary[String, Rect2] = EncounterLayout.nonland_groups(row_rect, _tapped(others), is_hero, other_extras)
	var creature_heights: Array[float] = []
	var attachment_heights: Array[float] = []
	for creature: MmObjectView in creatures:
		var scale_now: float = EncounterLayout.bystander_scale(is_combat_on, _is_in_combat(creature))
		creature_heights.append(roundf(EncounterLayout.creature_height(row_rect) * scale_now))
		attachment_heights.append(roundf(EncounterLayout.others_height(row_rect) * scale_now))
	# The creatures' line reaches COMBAT_STEP past its Region toward the middle, so a
	# creature that steps forward is not cut off.
	var creature_rect: Rect2 = groups["creatures"]
	if is_hero:
		creature_rect.position.y -= EncounterLayout.COMBAT_STEP
	creature_rect.size.y += EncounterLayout.COMBAT_STEP
	var creature_top: float = EncounterLayout.COMBAT_STEP if is_hero else 0.0
	_draw_line(who + "_creatures", creatures, creature_heights, creature_rect, groups["creatures"].size.y, creature_top, glow, is_hero,
			attached, attachment_heights)
	if not others.is_empty():
		_draw_line(who + "_others", others, other_heights, groups["others"], groups["others"].size.y, 0.0, glow, is_hero,
				attached, other_heights)


## Draws one scrolling line. Its faces are centered in a band [param band_height] tall that
## starts [param band_top] below the line's top. The permanents in [param attached], by the
## ID of the one each lies behind, its attachments and then its Tucked Cards, lie behind
## it, each [param attachment_heights] tall for that permanent's place in the line, and the
## line gives it the room of their name strips (ADR 0042). A Tucked Card that is in its
## Pile Window leaves a Tuck Outline in its place (ADR 0043).
func _draw_line(key: String, permanents: Array[MmObjectView], heights: Array[float], line_rect: Rect2,
		band_height: float, band_top: float, glow: DecisionClicks, is_hero: bool,
		attached: Dictionary[int, Array] = {}, attachment_heights: Array[float] = []) -> void:
	var is_tapped: Array[bool] = _tapped(permanents)
	var extras: Array[float] = []
	for index: int in permanents.size():
		var count: int = (attached.get(permanents[index].id, []) as Array).size()
		extras.append(EncounterLayout.attached_room(attachment_heights[index], count) if count > 0 else 0.0)
	var line: ScrollRow = ScrollRow.new(line_rect, EncounterLayout.line_width(is_tapped, heights, extras), _line_offsets.get(key, 0.0))
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
	var footprints: Array[Rect2] = EncounterLayout.line(is_tapped, heights, band_height, extras)
	for index: int in permanents.size():
		var permanent: MmObjectView = permanents[index]
		var face: BattlefieldFace = BattlefieldFace.new()
		face.setup(_board_look(permanent), heights[index])
		face.position = footprints[index].position + Vector2(0, band_top)
		if _is_in_combat(permanent):
			face.position.y += EncounterLayout.combat_step(is_hero)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The outermost attachment is drawn first and the permanent last, over them all.
		var behind: Array = attached.get(permanent.id, [])
		for place: int in range(behind.size() - 1, -1, -1):
			var attachment: MmObjectView = behind[place]
			var lying: Rect2 = EncounterLayout.attached_place(Rect2(face.position, footprints[index].size), attachment_heights[index], place)
			var is_tucked: bool = _tuck_owners.has(attachment.id)
			if is_tucked and _tuck_in_window[attachment.id]:
				var outline: Panel = CardShapes.outline(lying.size, 6, 2, Color(1, 1, 1, 0.25))
				outline.position = lying.position
				outline.size = lying.size
				outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
				line.content().add_child(outline)
				_tuck_outlines[attachment.id] = outline
				continue
			var attached_face: BattlefieldFace = BattlefieldFace.new()
			attached_face.setup(_snapshot.look_of(attachment.id), attachment_heights[index], true, is_tucked)
			attached_face.position = lying.position
			attached_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.content().add_child(attached_face)
			ids.append(attachment.id)
			_remember_face(attachment.id, attached_face, lying.size, glow,
					EncounterLayout.attached_shown(lying.size, EncounterLayout.attached_strip(attachment_heights[index])))
		line.content().add_child(face)
		_remember_face(permanent.id, face, footprints[index].size, glow)


func _tapped(permanents: Array[MmObjectView]) -> Array[bool]:
	var is_tapped: Array[bool] = []
	for permanent: MmObjectView in permanents:
		is_tapped.append(_is_drawn_tapped(permanent))
	return is_tapped


## Whether [param permanent] is drawn turned: tapped, or picked to be tapped for a cost, as
## it will be once the pick is confirmed (game ADR 0049).
func _is_drawn_tapped(permanent: MmObjectView) -> bool:
	return permanent.is_tapped or (_picks.is_picking_permanents() and _picks.is_picked(permanent.id))


## The look [param permanent]'s face is drawn from: the snapshot's, tapped for one picked to
## be tapped, so the face turns and sizes itself as its place in the row does, and its Glow
## stays on it.
func _board_look(permanent: MmObjectView) -> CardLook:
	var look: CardLook = _snapshot.look_of(permanent.id)
	if look == null or look.is_tapped or not _is_drawn_tapped(permanent):
		return look
	var turned: CardLook = look.copy()
	turned.is_tapped = true
	return turned


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


## Keeps [param face] as the face of [param object_id], with its Glow and, if it answers
## anything, its ClickCatcher. Only [param shown] of it takes the mouse, when that is given:
## the rest lies behind another face.
func _remember_face(object_id: int, face: Control, face_size: Vector2, glow: DecisionClicks,
		shown: Rect2 = Rect2()) -> void:
	_faces[object_id] = face
	_face_sizes[object_id] = face_size
	_face_shown[object_id] = shown if shown.has_area() else Rect2(Vector2.ZERO, face_size)
	var colors: Array[Color] = _glow_colors(object_id, glow)
	var is_pickable: bool = _picks.is_picking_on_battlefield() and _picks.is_candidate(object_id)
	if is_pickable:
		# Picked glows white; the rest green, or as targets for targets, while more can be
		# picked, and not at all once every pick is made (game ADR 0049, 0022). A creature
		# in combat keeps its gold after any of them.
		colors = []
		if _picks.is_picked(object_id):
			colors.append(PICKED_GLOW)
		elif _picks.can_pick(object_id):
			var kind: DecisionClicks.Kind = DecisionClicks.Kind.TARGET if _picks.is_targeting() else DecisionClicks.Kind.OTHER
			colors.append(DecisionClicks.color_of(kind))
		if glow.kinds_of(object_id).has(DecisionClicks.Kind.COMBAT):
			colors.append(DecisionClicks.color_of(DecisionClicks.Kind.COMBAT))
	if not colors.is_empty():
		BorderEffects.add_glow_of(face, face_size, colors, _glow_seconds_for(object_id, colors))
	if not glow.options_of(object_id).is_empty() or _selection.is_clickable(object_id) or is_pickable:
		var catcher: ClickCatcher = ClickCatcher.add(face, _face_shown[object_id].size)
		catcher.position = _face_shown[object_id].position
		catcher.clicked.connect(_on_object_clicked.bind(object_id))
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
		if face == null or not is_instance_valid(face):
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
## the card held, the Emblem's entry under it, the card of the hand under it, or the
## permanent under it. Outside the
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
	elif _hand_strip.held() != DragCard.NONE:
		answer = _only_answer(_hand_options(_hand_strip.held()))
	else:
		var cursor: Vector2 = get_local_mouse_position()
		var held_id: int = _held_under(cursor)
		var pile_card: int = _pile_card_under(cursor)
		if held_id != Inspection.NOTHING:
			# An Emblem's ability is paid for like a permanent's (ADR 0031).
			answer = _only_answer(_clicks.options_of(held_id))
		elif pile_card != Inspection.NOTHING:
			# A card cast from a pile's window is paid for like one in hand (game ADR 0055).
			answer = _only_answer(_clicks.options_of(pile_card))
		elif _is_covered(cursor):
			return NO_PREVIEW
		else:
			var card_id: int = _hand_strip.card_under(cursor)
			if card_id != DragCard.NONE:
				answer = _only_answer(_hand_options(card_id))
			else:
				answer = _only_answer(_clicks.options_of(_permanent_under(cursor)))
	return answer if _presenter.payment_plan(answer) != null else NO_PREVIEW


## The Emblem or Potion whose entry in an open window is under [param cursor], or
## Inspection.NOTHING.
func _held_under(cursor: Vector2) -> int:
	for object_id: int in _held_entries:
		var entry: ZoneEntry = held_entry(object_id)
		if entry != null and entry.is_visible_in_tree() and Easing.is_shown(_window_of(entry)) \
				and Rect2(entry.global_position - global_position, entry.size).has_point(cursor):
			return object_id
	return Inspection.NOTHING


## The card of an open pile window under [param cursor] that a click answers on, or
## Inspection.NOTHING.
func _pile_card_under(cursor: Vector2) -> int:
	var at: Vector2 = get_global_transform() * cursor
	for key: String in _pile_windows:
		var pile: PileWindow = _pile_windows[key]
		if not Easing.is_shown(pile):
			continue
		for object_id: int in pile.entries():
			var face: CardFace = pile.face_of(object_id) if object_id != PileWindow.UNKNOWN else null
			if face != null and face.is_visible_in_tree() and pile.catcher_of(object_id) != null \
					and face.get_global_rect().has_point(at):
				return object_id
	return Inspection.NOTHING


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
				and _face_shown[object_id].has_point(face.get_global_transform().affine_inverse() * at):
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
	var lines: Array[BlockLines.Line] = []
	if _snapshot != null:
		for permanent: MmObjectView in _snapshot.view.battlefield:
			for attacker_id: int in permanent.blocking_ids:
				_add_block_line(lines, permanent.id, attacker_id, false)
		for pair: Array in _selection.pairs():
			_add_block_line(lines, pair[0], pair[1], true)
	_block_lines.show_lines(lines)


func _add_block_line(lines: Array[BlockLines.Line], blocker_id: int, attacker_id: int,
		is_chosen: bool) -> void:
	if _faces.has(blocker_id) and _faces.has(attacker_id):
		var blocker_end: Vector2 = _block_line_end(blocker_id)
		lines.append(BlockLines.Line.new(blocker_end, _block_line_end(attacker_id), is_chosen))


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
	# Nothing is out of sight in a line that shows all of itself, however near its end: the
	# name strip of what lies behind the last permanent is.
	if not line.can_scroll():
		return 0
	var place: Vector2 = _rest.get(object_id, _faces[object_id].position)
	var middle: float = place.x + line.content().position.x + _face_shown[object_id].get_center().x
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
	# A Tucked Card's face moves as a permanent's does (ADR 0043).
	var moving: Array[MmObjectView] = _snapshot.view.battlefield.duplicate()
	for host_id: int in _tucks:
		moving.append_array(_tucks[host_id])
	for permanent: MmObjectView in moving:
		var face: BattlefieldFace = _faces.get(permanent.id, null) as BattlefieldFace
		if face == null:
			continue
		_rest[permanent.id] = face.position
		targets[permanent.id] = FacePose.of(_center_at(face, face.position), face.card().size.y, 1.0 if _is_drawn_tapped(permanent) else 0.0,
				1.0, 1.0 if face.is_attached() else 0.0)
		looks[permanent.id] = _board_look(permanent)
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
		face.modulate.a = 0.0 if _flight_layer.is_flying(object_id) else pose.alpha
		face.show_turn(pose.turn, pose.lean)
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
			ghost.show_turn(pose.turn, pose.lean)
			_ghost_layer.add_child(ghost)
			_ghosts[object_id] = ghost
		_ghosts[object_id].modulate.a = pose.alpha


## A card put in the air: a permanent that flies away leaves no ghost, and the board's faces
## are posed again once the snapshot is shown.
func _on_took_off(route: CardFlights.Route) -> void:
	_has_taken_off = true
	# A Tucked Card that leaves exile was a face behind its permanent too (ADR 0043).
	var was_tucked: bool = route.from_zone_kind == MmZone.Kind.EXILE and route.first_object_id != route.object_id
	if route.from_zone_kind == MmZone.Kind.BATTLEFIELD or was_tucked:
		_motion.forget(route.first_object_id)


## A card in the air has landed. What it landed on shows it now. A drawn card joins its
## hand with a redraw, made from the next frame so that an open Option Menu can wait for
## it; a card that lands in the Hero's hand some other way shows there at once.
func _on_landed(route: CardFlights.Route) -> void:
	if route.first_object_id == route.object_id and _surveil.sent().has(route.object_id) \
			and not _surveil_landed.has(route.object_id):
		# Game ADR 0069: a card sent from the Surveil window counts on the pile once it lands.
		_surveil_landed.append(route.object_id)
		if not _is_redrawing:
			_redraw()
		return
	if route.first_object_id == route.object_id and _look.taken().has(route.object_id) \
			and not _look_landed.has(route.object_id):
		# Game ADR 0085: a card taken from the Look window shows in the hand once it lands.
		_look_landed.append(route.object_id)
		if not _is_redrawing:
			_redraw()
		return
	var is_drawn: bool = route.from_zone_kind == MmZone.Kind.LIBRARY and route.to_zone_kind == MmZone.Kind.HAND
	if is_drawn:
		_has_draw_landed = not _is_redrawing
	if _faces.has(route.object_id) and is_instance_valid(_faces[route.object_id]):
		var pose: FacePose = _motion.pose_of(route.object_id)
		_faces[route.object_id].modulate.a = pose.alpha if pose != null else 1.0
	if route.to_zone_kind == MmZone.Kind.EXILE and _exile_owners.has(route.object_id):
		_pile_windows[_exile_key(_exile_owners[route.object_id])].show_face(route.object_id, true)
	if not is_drawn and route.to_zone_kind == MmZone.Kind.HAND and route.to_owner_id == HERO and not _is_redrawing:
		_show_hand()


## What a card in the air lands on shows nothing of it until it arrives: its face on a pile
## or in a row. A card landing in a hand is held back or hidden by that hand.
func _hide_landing_places() -> void:
	for object_id: int in _faces:
		if _flight_layer.is_flying(object_id) and is_instance_valid(_faces[object_id]):
			_faces[object_id].modulate.a = 0.0
	# A Tucked Card that lands in its window shows nothing there either.
	for object_id: int in _tuck_owners:
		if _flight_layer.is_flying(object_id):
			_pile_windows[_exile_key(_tuck_owners[object_id])].show_face(object_id, false)


## Where the zone of [param route] is drawn, read from what is on the screen right now, or
## null if nothing shows it: the Flight Layer's one question (ADR 0027). Leaving, it is
## where the Game Object that left is drawn; with [param is_landing], where the one it
## became belongs. A permanent's place leaving is where it is drawn, on its way there.
func _flight_place(route: CardFlights.Route, is_landing: bool) -> FacePose:
	var zone_kind: MmZone.Kind = route.to_zone_kind if is_landing else route.from_zone_kind
	var owner_id: int = route.to_owner_id if is_landing else route.from_owner_id
	var object_id: int = route.object_id if is_landing else route.first_object_id
	var is_drawn: bool = is_landing and route.from_zone_kind == MmZone.Kind.LIBRARY and route.to_zone_kind == MmZone.Kind.HAND
	if not is_landing and _sent_at_done.has(object_id):
		return null  # Game ADR 0069: it flew from the Surveil window already.
	if not is_landing and _taken_at_done.has(object_id):
		return null  # Game ADR 0085: it flew from the Look window already.
	if zone_kind == MmZone.Kind.EXILE:
		# The one exile is drawn as a pile for each player, the card's owner's.
		owner_id = _exile_owners.get(object_id, owner_id)
	if zone_kind == MmZone.Kind.EXILE and _tuck_in_window.has(object_id):
		# A Tucked Card is in its window or behind its permanent, not on its pile (ADR 0043).
		if _tuck_in_window[object_id]:
			return _window_place(_exile_key(owner_id), object_id)
		var tucked: FacePose = _field_flight_place(object_id, is_landing)
		if tucked != null:
			return tucked
	match zone_kind:
		MmZone.Kind.BATTLEFIELD:
			return _field_flight_place(object_id, is_landing)
		MmZone.Kind.HAND:
			if owner_id != HERO:
				if is_drawn:
					# A drawn card lands where its back will be, at the right end.
					return _villain_hand.landing_place(_flight_layer.drawn_in_air(owner_id).find(route.card_id))
				return FacePose.of(_regions["villain_hand"].get_center(), EncounterLayout.VILLAIN_CARD_HEIGHT, 0.0)
			if is_drawn:
				return _hand_strip.rest_of(route.card_id)
			# A card played by letting go of it flies from where it was let go.
			return _hand_strip.place_of(route.card_id)
		MmZone.Kind.STACK:
			return FacePose.of(_stack_art_place(object_id), StackEntry.ART_SIZE, 0.0)
		MmZone.Kind.LIBRARY, MmZone.Kind.GRAVEYARD, MmZone.Kind.EXILE:
			var pile: Rect2 = _regions[EncounterLayout.pile_key(zone_kind, owner_id == HERO)]
			return FacePose.of(pile.position + Vector2(pile.size.x / 2.0, EncounterLayout.PILE_HEIGHT / 2.0), EncounterLayout.PILE_HEIGHT, 0.0)
	return null


## How the card of [param route] is drawn where it leaves, or where it lands with
## [param is_landing]: as its zone says, but a Tucked Card behind its permanent is a
## Battlefield Face though it is in exile (ADR 0043).
func _flight_kind(route: CardFlights.Route, is_landing: bool) -> FlightCard.Kind:
	var zone_kind: MmZone.Kind = route.to_zone_kind if is_landing else route.from_zone_kind
	var object_id: int = route.object_id if is_landing else route.first_object_id
	if zone_kind == MmZone.Kind.EXILE and _tuck_in_window.get(object_id, true) == false:
		return FlightCard.Kind.FIELD
	return FlightCard.kind_in(zone_kind)


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
		return FacePose.of(rest.center, rest.height, rest.turn, 1.0, rest.lean) if rest != null else null
	if not _rest.has(object_id):
		return null
	var pose: FacePose = _motion.pose_of(object_id)
	for key: String in _lines:
		var ids: Array = _line_ids.get(key, [])
		var hidden: int = _hidden_past(_lines[key], object_id) if ids.has(object_id) else 0
		if hidden != 0:
			var arrow: Button = _lines[key].left_arrow() if hidden < 0 else _lines[key].right_arrow()
			return FacePose.of(arrow.get_global_rect().get_center() - global_position, pose.height * EncounterLayout.UNSEEN_FLIGHT_SCALE,
					pose.turn, 1.0, pose.lean)
	# An attachment takes off lying as it lay, and stands up on the way (ADR 0042).
	return FacePose.of(pose.center, pose.height, pose.turn, 1.0, pose.lean)


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
	var offer: ClickOption = _hand_strip.offer()
	return InfoPrompt.release_text(offer.text) if offer != null else ""


## The Option Menu closed. A card of the hand that was waiting on it goes back to the hand;
## if a way to play it was chosen, the answer takes it from there.
func _on_menu_closed() -> void:
	_hand_strip.menu_closed()


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
		_show_hand()
		return
	var area: Rect2 = Rect2(_regions["sidebar"].end.x, 0, size.x - _regions["sidebar"].end.x, size.y)
	var pile: Vector2 = Vector2(EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT, EncounterLayout.PILE_HEIGHT)
	var library: Rect2 = _regions["hero_library"]
	_overlay.show_frame(_opening, _snapshot, _picks, _hand_strip.order(), area,
			Rect2(library.position + Vector2((library.size.x - pile.x) / 2.0, 0), pile))
	_opening.forget_new_hand()


## Where each card of the hand's strip rests, by Game Object ID, as a pose whose center is
## the middle of the card's bottom edge, turned as it is in the row: where the overlay's
## cards fly to when it goes.
func _hand_poses() -> Dictionary[int, FacePose]:
	var poses: Dictionary[int, FacePose] = {}
	for in_hand: MmObjectView in _snapshot.view.hand:
		var rest: FacePose = _hand_strip.rest_of(in_hand.card_id)
		if rest != null:
			var turn: float = _hand_strip.fan_turn_of(in_hand.card_id)
			poses[in_hand.id] = FacePose.of(rest.center + Vector2(0.0, rest.height / 2.0).rotated(turn), rest.height, turn)
	return poses


## Shows the Hero's hand in the Hand Strip as the snapshot has it: what a click on each card
## would do and how it glows, the cards chosen to be discarded, and which are not shown yet.
## Cards drawn and still in the air are left out until they land; a card flying in some
## other way, and through the pregame the whole hand, which the overlay holds (A384), keep
## their places and are not shown. Nothing is rebuilt for a card already drawn.
func _show_hand() -> void:
	if _snapshot == null:
		return
	var hand: HandShow = HandShow.new()
	hand.regions = _regions
	hand.glow_seconds = _ease_seconds
	hand.is_rewind = _snapshot.is_rewind
	# A redraw puts every card at its place at once, unless a drawn card has landed and the
	# rest make room for it; anything else, such as a click choosing a card to discard,
	# rebuilds nothing, and the cards ease.
	hand.is_easing = _is_hand_easing or not _is_redrawing
	hand.cursor = get_local_mouse_position()
	var flying_in: Array[int] = _flight_layer.flying_into_hand(HERO)
	hand.arriving = _flight_layer.drawn_in_air(HERO)
	var is_discarding: bool = _picks.is_active() and _picks.is_discarding() and not _snapshot.is_over()
	# Game ADR 0067: a land asked whether to pay to enter untapped waits here, glowing white.
	var entering: ChooseYesOrNoDecision = _snapshot.decision as ChooseYesOrNoDecision
	var entering_id: int = entering.entering_object_id if entering != null and entering.player_id == HERO else 0
	for in_hand: MmObjectView in _snapshot.view.hand:
		var glow: Array[Color] = _glow_colors(in_hand.id, _clicks)
		if entering_id != 0 and in_hand.id == entering_id:
			glow = [PICKED_GLOW]
		if is_discarding:
			glow = []
			if _picks.is_picked(in_hand.id):
				glow = [PICKED_GLOW]
			elif _picks.can_pick(in_hand.id):
				glow = [DecisionClicks.color_of(DecisionClicks.Kind.OTHER)]
		hand.add(in_hand.card_id, _snapshot.look_of(in_hand.id), _clicks.hand_options_of(in_hand.id), glow,
				_clicks.colors_of(in_hand.id, true))
		if _opening.is_open() or _overlay.is_landing(in_hand.id) or flying_in.has(in_hand.card_id):
			hand.hidden.append(in_hand.card_id)
		if is_discarding and _picks.is_picked(in_hand.id):
			hand.raised.append(in_hand.card_id)
	# Game ADR 0085: a card taken from the Look window is in the hand already, waiting for
	# Done to put it there, hidden while it flies in.
	for object_id: int in _look.taken() if _look.is_active() else []:
		var taken: MmObjectView = _seen(object_id)
		if taken == null:
			continue
		hand.add(taken.card_id, _snapshot.look_of(object_id))
		if not _look_landed.has(object_id) or flying_in.has(taken.card_id):
			hand.hidden.append(taken.card_id)
	_hand_strip.show_hand(hand)


## Shows how far the choice of cards has come, on what is already drawn: a card chosen to
## be discarded glows white and the rest that can be chosen green, the pass button confirms
## the discard, and undo is open while there is a click to take back. Nothing is rebuilt
## for a click in the hand, so a chosen card eases up to its place.
func _show_picks() -> void:
	if not _picks.is_active() or _snapshot.is_over():
		return
	if _picks.is_searching():
		_panels[HERO].show_undo(_picks.can_undo())
		_show_confirm(_picks.search_confirm_text(_snapshot.view), true, _picks.can_undo())
		_info.show_prompt(InfoPrompt.of(_snapshot.decision, _snapshot.view).text)
		return
	if _picks.is_targeting():
		_panels[HERO].show_undo(_picks.can_undo() or (_snapshot.can_undo and not _snapshot.is_villain_thinking))
		_show_confirm(_picks.targets_confirm_text(), true, _picks.can_undo())
		_info.show_prompt("%s (%d of %d)" % [InfoPrompt.of(_snapshot.decision, _snapshot.view).text, _picks.picked().size(),
			_picks.count()])
		return
	if _picks.is_picking_permanents():
		_panels[HERO].show_undo(_picks.can_undo() or (_snapshot.can_undo and not _snapshot.is_villain_thinking))
		_show_confirm("Tap %d" % _picks.count(), _picks.is_complete(), _picks.can_undo())
		_info.show_prompt("%s (%d of %d)" % [InfoPrompt.of(_snapshot.decision, _snapshot.view).text, _picks.picked().size(),
			_picks.count()])
		return
	if not _picks.is_discarding():
		# Keeping is final (A406): undo takes back cards put down and nothing before them.
		_panels[HERO].show_undo(_picks.can_undo())
		return
	_panels[HERO].show_undo(_picks.can_undo() or (_snapshot.can_undo and not _snapshot.is_villain_thinking))
	_show_confirm("Confirm discard", _picks.is_complete(), _picks.can_undo())
	_info.show_prompt(_picks.prompt())
	# A chosen card glows white and rises; the rest that can be chosen glow green.
	_show_hand()


## The choice of cards changed by a click or an undo. Cards put on the bottom leave the
## overlay's row, which is drawn again; in the hand's strip nothing is rebuilt.
func _show_picks_changed() -> void:
	if _picks.is_bottoming() or _picks.is_picking_on_battlefield() or _picks.is_searching():
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
	var top: MmObjectView = _seen_library_top(HERO) if key == "hero_library" else null
	if key == "hero_library":
		_library_top_face = null
	if top != null:
		# Game ADR 0055: the top card face up on the face-down pile, a little down and to the
		# left so the backs show above it, with an eye: only the Hero sees it.
		for offset: Vector2 in [Vector2(5, -4), Vector2(2, -2)]:
			var peeking: Panel = CardBack.make(card.y)
			peeking.position = at + offset
			_board.add_child(peeking)
		var face: CardFace = CardFace.new()
		face.setup(_snapshot.look_of(top.id), card.y)
		face.position = at + Vector2(-2, 0)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(face)
		var eye: SeenEye = SeenEye.new()
		eye.position = Vector2(-10, card.y - 28)
		face.add_child(eye)
		_library_top_face = face
	elif count > 0:
		var back: Panel = CardBack.make(card.y)
		back.position = at
		_board.add_child(back)
	else:
		_draw_empty_pile(at, card)
	_draw_pile_label("Library (%d)" % count, key, pile_rect)


## A graveyard or exile pile: its top card and how many cards it holds. While its top card
## is still in the air, the last card that has landed is drawn under it, and the top card
## shows nothing until it lands (Card Flights). It counts every card in [param cards] and
## shows only [param loose], the ones not drawn somewhere else.
func _draw_pile(zone_name: String, cards: Array, loose: Array, key: String, pile_rect: Rect2) -> void:
	var card: Vector2 = Vector2(EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT, EncounterLayout.PILE_HEIGHT)
	var at: Vector2 = pile_rect.position + Vector2((pile_rect.size.x - card.x) / 2.0, 0)
	var top: MmObjectView = loose.back() as MmObjectView if not loose.is_empty() else null
	var landed: MmObjectView = null
	for index: int in range(loose.size() - 1, -1, -1):
		if not _flight_layer.is_flying((loose[index] as MmObjectView).id):
			landed = loose[index] as MmObjectView
			break
	if landed == null:
		_draw_empty_pile(at, card)
	for shown: MmObjectView in [landed, top]:
		if shown == null or _faces.has(shown.id):
			continue
		var face: CardFace = CardFace.new()
		face.setup(_snapshot.look_of(shown.id), card.y)
		if key.ends_with("graveyard"):
			face.show_graveyard_chips()
		face.position = at
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(face)
		_faces[shown.id] = face
		_face_sizes[shown.id] = card
		_face_shown[shown.id] = Rect2(Vector2.ZERO, card)
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
		var stack_look: CardLook = _snapshot.look_of(seen.id)
		var is_from_potion: bool = stack_look.kind == CardLook.Kind.POTION
		var entry: StackEntry = StackEntry.new("" if is_from_potion else stack_look.art_key, item.first_line, item.second_line,
			_stack_colors.color_of(seen.id))
		if is_from_potion:
			# Its Potion is gone, but its ability still shows which it was (A531).
			entry.show_potion(stack_look.art_key, _snapshot.rarity_of(seen.id) if _snapshot.has_rarity(seen.id) else null)
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
	var noun: String = AbilityText.self_noun(source.card_types, source.name, source.abilities) if source != null else "it"
	var look: CardLook = _snapshot.look_of(source.id) if source != null else null
	if look != null and look.kind != CardLook.Kind.CARD:
		noun = CardLook.noun_of(look.kind)
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
## The cursor came onto or left a card of a pile window that answers: the Info Panel says
## what a click on it does, "Cast Savannah Lions from the top of your library" (game ADR
## 0055), for as long as it is there.
func _on_pile_card_hovered(object_id: int, is_over: bool) -> void:
	if _picks.is_searching() and _picks.is_candidate(object_id):
		# Game ADR 0058: "Select Forest" or "Unselect Forest".
		var verb: String = "Unselect" if _picks.is_picked(object_id) else "Select"
		_info.show_option("%s %s" % [verb, EncounterSnapshot.name_in(_snapshot.view, object_id)] if is_over else "")
		return
	var options: Array[ClickOption] = _clicks.options_of(object_id) if _clicks != null else [] as Array[ClickOption]
	_info.show_option(options[0].text if is_over and not options.is_empty() else "")


func _on_stack_entry_hovered(is_over: bool, object_id: int) -> void:
	_clear_marks()
	_info.show_option("")
	if not is_over or not _stack_items.has(object_id):
		_mark_asked_targets()
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


## While a "you may" is asked, what the asking spell or ability targets carries its
## dashed Stack Mark, so the Hero sees what "target creature" is (game ADR 0060). While a
## ward cost is asked, the Stack Window entry of what it would counter carries it
## (ADR 0062); a "you may pay {1}" counters nothing, so it marks its targets as a "you may"
## does (ADR 0076's addendum).
func _mark_asked_targets() -> void:
	var asked: ChooseYesOrNoDecision = _snapshot.decision as ChooseYesOrNoDecision if _snapshot != null else null
	if asked == null or not _stack_items.has(asked.stack_object_id):
		return
	var item: StackItem = _stack_items[asked.stack_object_id]
	var color: Color = _stack_colors.color_of(asked.stack_object_id)
	if asked.cost != null and _is_ward(asked.stack_object_id):
		var countered: StackEntry = stack_entry_of(_triggering_object_of(asked.stack_object_id))
		if countered != null and is_instance_valid(countered):
			BorderEffects.add_mark(countered, countered.size, color, true, _ease_seconds)
			_marked.append(countered)
		return
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


## The object the stack object [param stack_object_id] triggered on, or 0.
## Whether the stack object [param stack_object_id] is a ward trigger (ADR 0062).
func _is_ward(stack_object_id: int) -> bool:
	for seen: MmObjectView in _snapshot.view.stack:
		if seen.id == stack_object_id:
			return seen.ability is WardAbility
	return false


func _triggering_object_of(stack_object_id: int) -> int:
	for seen: MmObjectView in _snapshot.view.stack:
		if seen.id == stack_object_id:
			return seen.triggering_object_id
	return 0


func _mark_face(object_id: int, color: Color, is_dashed: bool) -> void:
	if _faces.has(object_id):
		BorderEffects.add_mark(_faces[object_id], _face_sizes[object_id], color, is_dashed, _ease_seconds)
		_marked.append(_faces[object_id])


func _clear_marks() -> void:
	for host: Control in _marked:
		if is_instance_valid(host):
			BorderEffects.remove_mark(host, _ease_seconds)
	_marked.clear()


## The window that asks which replacement effect applies first (A340), or which mode of a
## modal spell or triggered ability is chosen (ADR 0046): there exactly while the Hero is
## asked, with an entry for each, clicked to choose it.
func _fill_choice_window(view: MmPlayerView) -> void:
	var decision: ChooseReplacementEffectDecision = _snapshot.decision as ChooseReplacementEffectDecision
	var modes: ChooseModeDecision = _snapshot.decision as ChooseModeDecision
	_choice_window.clear()
	_choice_entries.clear()
	_choice_window.set_open(decision != null or modes != null)
	if modes != null:
		_fill_mode_window(modes, view)
		return
	if decision == null:
		return
	_choice_window.size = REPLACEMENT_WINDOW_SIZE
	_choice_window.fit()
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


## The Creature Type Window is open exactly while the Hero is asked for a creature type. It
## is filled only for a new decision, so a redraw keeps what is typed, and opens with the
## keyboard in its search box (game ADR 0053).
func _fill_creature_type_window(view: MmPlayerView, regions: Dictionary) -> void:
	var decision: ChooseCreatureTypeDecision = _snapshot.decision as ChooseCreatureTypeDecision
	if decision == null or _snapshot.is_over():
		_creature_type_window.forget()
		_creature_type_window.set_open(false)
		return
	var choice: CreatureTypeChoice = _creature_type_window.choice()
	if choice != null and choice.is_for(decision):
		_creature_type_window.move_to_front()
		return
	var battlefield: Rect2 = regions["battlefield"]
	var top: float = battlefield.position.y + 14.0
	var bottom: float = (regions["hero_nonlands"] as Rect2).position.y - 12.0
	_creature_type_window.size = Vector2(CreatureTypeWindow.WIDTH, maxf(ZoneWindow.SMALLEST.y, bottom - top))
	_creature_type_window.position = Vector2(battlefield.get_center().x - CreatureTypeWindow.WIDTH / 2.0, top)
	_creature_type_window.bounds = battlefield
	_creature_type_window.fit()
	_creature_type_window.show_choice(CreatureTypeChoice.new(decision, view, _snapshot.names))
	_creature_type_window.move_to_front()
	_creature_type_window.open_for_typing()


## The Surveil window is open exactly while the Hero surveils (game ADR 0069). It opens
## left of the piles over the Hero's side, as the Library window does, for each new surveil,
## and keeps its place and size while that is asked.
func _fill_surveil_window(regions: Dictionary) -> void:
	if not _surveil.is_active() or _snapshot.is_over():
		_surveil_window.forget()
		_surveil_window.set_open(false)
		_surveil_placed_for = null
		return
	var battlefield: Rect2 = regions["battlefield"]
	_surveil_window.bounds = battlefield
	if _surveil_placed_for != _snapshot.decision:
		_surveil_placed_for = _snapshot.decision
		_surveil_window.forget()
		_surveil_window.size = SurveilWindow.opening_size()
		_surveil_window.position = Vector2((regions["piles"] as Rect2).position.x - _surveil_window.size.x - 5.0 * SurveilWindow.UNIT,
			battlefield.end.y - _surveil_window.size.y - 2.0 * SurveilWindow.UNIT)
		_surveil_window.fit()
		_surveil_window.open()
	var looks: Dictionary[int, CardLook] = {}
	for object_id: int in _surveil.row():
		looks[object_id] = _snapshot.look_of(object_id)
	_surveil_window.show_choice(_surveil, looks)
	_surveil_window.move_to_front()


## A card of the Surveil window was clicked: it is selected, or let go.
func _pick_surveilled(object_id: int) -> void:
	if _is_paused or not _surveil.is_active():
		return
	_surveil.pick(object_id)
	_redraw()


## A card of the Surveil window was dragged to another place in its row. A drag that moves
## nothing, or one while paused, is drawn back where the choice has it.
func _move_surveilled(from: int, to: int) -> void:
	if not _is_paused and _surveil.is_active():
		_surveil.move_to(from, to)
	_redraw()


## "Graveyard" was pressed: the selected card flies out of the Surveil window straight onto
## the Hero's Graveyard pile, which counts it once it lands. For a scry, "Bottom" flies it
## onto the Library pile, whose count stays as it was, since the card never leaves the
## library (game ADR 0069's addendum). Nothing is answered (game ADR 0069).
func _send_surveilled() -> void:
	if _is_paused or not _surveil.is_active():
		return
	var start: FacePose = _face_pose_in(_surveil_window.face_of(_surveil.picked()))
	var sent: int = _surveil.send_picked()
	if sent == SurveilChoice.NONE:
		return
	var to_zone_kind: MmZone.Kind = MmZone.Kind.LIBRARY if _surveil.is_scry() else MmZone.Kind.GRAVEYARD
	if not _put_in_air_from_library(sent, start, to_zone_kind):
		_surveil_landed.append(sent)
	_redraw()


## Takes back the last card sent or move made in the Surveil window; a card taken back while
## it flies comes down at once, and leaves the Graveyard pile.
func _undo_surveilled() -> void:
	var sent_before: Array[int] = _surveil.sent()
	_surveil.undo()
	for object_id: int in sent_before:
		if not _surveil.sent().has(object_id):
			_flight_layer.cancel(object_id)
			_surveil_landed.erase(object_id)
	_redraw()


## The Look window is open exactly while the Hero looks at the top of their library (game
## ADR 0085). It opens left of the piles over the Hero's side, as the Surveil window does,
## for each new look, and keeps its place and size while that is asked.
func _fill_look_window(regions: Dictionary) -> void:
	if not _look.is_active() or _snapshot.is_over():
		_look_window.forget()
		_look_window.set_open(false)
		_look_placed_for = null
		return
	var battlefield: Rect2 = regions["battlefield"]
	_look_window.bounds = battlefield
	if _look_placed_for != _snapshot.decision:
		_look_placed_for = _snapshot.decision
		_look_window.forget()
		_look_window.size = LookWindow.opening_size()
		_look_window.position = Vector2((regions["piles"] as Rect2).position.x - _look_window.size.x - 5.0 * LookWindow.UNIT,
			battlefield.end.y - _look_window.size.y - 2.0 * LookWindow.UNIT)
		_look_window.fit()
		_look_window.open()
	var looks: Dictionary[int, CardLook] = {}
	for object_id: int in _look.row():
		looks[object_id] = _snapshot.look_of(object_id)
	_look_window.show_choice(_look, looks)
	_look_window.move_to_front()


## A card of the Look window was clicked: it is selected, or let go.
func _pick_looked_at(object_id: int) -> void:
	if _is_paused or not _look.is_active():
		return
	_look.pick(object_id)
	_redraw()


## A card of the Look window was dragged to another place in its row, as the rest go to the
## bottom in any order (engine ADR 0084's addendum). Nothing is answered.
func _move_looked_at(from: int, to: int) -> void:
	if not _is_paused and _look.is_active():
		_look.move_to(from, to)
	_redraw()


## "Hand" was pressed: the selected card flies out of the Look window into the Hero's hand,
## which shows it once it lands. Nothing is answered (game ADR 0085).
func _take_looked_at() -> void:
	if _is_paused or not _look.is_active():
		return
	var start: FacePose = _face_pose_in(_look_window.face_of(_look.picked()))
	var taken: int = _look.take_picked()
	if taken == LookChoice.NONE:
		return
	if not _put_in_air_from_library(taken, start, MmZone.Kind.HAND):
		_look_landed.append(taken)
	_redraw()


## Done: the cards left in the Look window fly from where they are, turning face down, onto
## the Hero's Library pile (game ADR 0085). They never leave the library, so nothing the
## engine does flies them.
func _fly_rest_to_library() -> void:
	for object_id: int in _look.row():
		_put_in_air_from_library(object_id, _face_pose_in(_look_window.face_of(object_id)), MmZone.Kind.LIBRARY)


## Puts the Hero's library card [param object_id] in the air from [param start] to their
## [param to_zone_kind]. Returns whether it flies: not with flights off or no place to start.
func _put_in_air_from_library(object_id: int, start: FacePose, to_zone_kind: MmZone.Kind) -> bool:
	if _flight_layer.seconds <= 0.0 or start == null:
		return false
	var route: CardFlights.Route = CardFlights.Route.new()
	route.first_object_id = object_id
	route.object_id = object_id
	route.card_id = _seen(object_id).card_id if _seen(object_id) != null else 0
	route.from_zone_kind = MmZone.Kind.LIBRARY
	route.from_owner_id = HERO
	route.to_zone_kind = to_zone_kind
	route.to_owner_id = HERO
	_flight_layer.put_in_air(route, start, FlightCard.Kind.CARD, _snapshot.look_of(object_id))
	return true


## Where [param face], a card drawn in a window, is on this screen, or null for none.
func _face_pose_in(face: CardFace) -> FacePose:
	if face == null:
		return null
	var rect: Rect2 = face.get_global_rect()
	return FacePose.of(rect.get_center() - global_position, rect.size.y, 0.0)


## Takes back the card taken in the Look window; one taken back while it flies comes down at
## once, and leaves the hand.
func _undo_looked_at() -> void:
	var taken_before: Array[int] = _look.taken()
	_look.undo()
	for object_id: int in taken_before:
		if not _look.taken().has(object_id):
			_flight_layer.cancel(object_id)
			_look_landed.erase(object_id)
	_redraw()


## What [param player_id]'s Graveyard pile shows: their graveyard, and while the Hero
## surveils, the cards they sent there that have landed, the last on top (game ADR 0069).
func _graveyard_shown(player_id: int) -> Array:
	var cards: Array = _snapshot.view.graveyards.get(player_id, []).duplicate()
	if player_id == HERO and not _surveil.is_scry():
		for object_id: int in _surveil_landed:
			var seen: MmObjectView = _seen(object_id)
			if seen != null:
				cards.append(seen)
	return cards


func _choose_creature_type(answer: int) -> void:
	if not _is_paused and _snapshot.decision is ChooseCreatureTypeDecision:
		_answer(answer)


## The cursor or the keyboard came to a creature type in the Creature Type Window, or left
## them: the Hero's creatures of that type are marked as targets are. The Info Panel keeps
## asking "Choose a creature type for [card]" and never says what the type would do.
func _on_creature_type_pointed(creature_type: String) -> void:
	_clear_marks()
	_info.show_option("")
	var choice: CreatureTypeChoice = _creature_type_window.choice()
	if creature_type == "" or choice == null or not (_snapshot.decision is ChooseCreatureTypeDecision):
		return
	var color: Color = DecisionClicks.color_of(DecisionClicks.Kind.TARGET)
	for id: int in choice.controlled_of(creature_type):
		_mark_face(id, color, false)


func _choose_replacement(index: int) -> void:
	if not _is_paused:
		_answer(index)


## The mode window: an entry for every mode of the spell being cast, or of the triggered
## ability being put on the stack, each only its art and its words. A mode that cannot be
## chosen is dimmed and takes no click (CR 700.2a). A trigger's is titled with its source's
## name and drawn with its source's art (game ADR 0047).
func _fill_mode_window(decision: ChooseModeDecision, view: MmPlayerView) -> void:
	var seen: MmObjectView = _seen(decision.stack_object_id)
	var modal: MmAbility = StackItem.modal_of(seen)
	var mode_count: int = modal.modes_or_none().size()
	var look: CardLook = _snapshot.look_of(seen.id)
	_choice_window.show_title("%s: choose one" % StackItem.name_of(seen))
	_choice_window.size = Vector2(MODE_WINDOW_WIDTH, ZoneWindow.BAR_HEIGHT + MODE_WINDOW_PAD + MODE_ENTRY_HEIGHT * mode_count)
	_choice_window.fit()
	_choice_window.move_to_front()
	for mode_index: int in mode_count:
		var entry: ZoneEntry = ZoneEntry.new(look.art_key if look != null else "", "",
			AbilityText.mode_text(modal, mode_index, StackItem.noun_of(seen, view)), StackColors.PLAIN)
		_choice_window.body().add_child(entry)
		_choice_entries.append(entry)
		var answer: int = decision.modes.find(mode_index)
		if answer == -1:
			entry.modulate = UNCHOOSABLE_MODE
			continue
		var catcher: ClickCatcher = entry.make_usable()
		catcher.clicked.connect(_choose_replacement.bind(answer))
		catcher.mouse_entered.connect(_on_mode_hovered.bind(true, answer, mode_index))
		catcher.mouse_exited.connect(_on_mode_hovered.bind(false, answer, mode_index))


## The cursor came over a mode in the mode window, or left it: everything the mode could
## target is marked, and the Info Panel shows the mode in full.
func _on_mode_hovered(is_over: bool, answer: int, mode_index: int) -> void:
	_clear_marks()
	_info.show_option("")
	var decision: ChooseModeDecision = _snapshot.decision as ChooseModeDecision
	if not is_over or decision == null:
		return
	var seen: MmObjectView = _seen(decision.stack_object_id)
	_info.show_option(AbilityText.mode_text(StackItem.modal_of(seen), mode_index, StackItem.noun_of(seen, _snapshot.view)))
	var color: Color = DecisionClicks.color_of(DecisionClicks.Kind.TARGET)
	for reached: MmReference in decision.mode_targets[answer]:
		if reached.is_player():
			var portrait: Control = _panels[reached.id].portrait()
			BorderEffects.add_mark(portrait, portrait.size, color, false, _ease_seconds)
			_marked.append(portrait)
		else:
			_mark_face(reached.id, color, false)


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


func _fill_emblems_window(player_id: int) -> void:
	var window: ZoneWindow = _emblem_windows[player_id]
	window.clear()
	var emblems: Array[MmObjectView] = _snapshot.emblems_of(player_id)
	for emblem: MmObjectView in emblems:
		var look: CardLook = _snapshot.look_of(emblem.id)
		var has_art: bool = ArtLibrary.shared().texture(look.art_key) != null
		var entry: ZoneEntry = ZoneEntry.new(look.art_key if has_art else "", emblem.name, "", PlayerPanel.GOLD)
		if not has_art:
			entry.show_no_art()
		# Each ability on one line, cut where the window ends; widening the window shows more.
		entry.show_lines(look.rules_lines, look.spent_ability_indexes)
		window.body().add_child(entry)
		_add_held_entry(emblem, entry, HeldWindows.Kind.EMBLEMS, player_id)
	window.show_title("%s Emblems (%d)" % [_snapshot.names.possessive(player_id), emblems.size()])


## The Hero's Potions, each with its Potion Icon, its Rarity and what it does (ADR 0032).
func _fill_potions_window() -> void:
	_potions_window.clear()
	var potions: Array[MmObjectView] = _snapshot.potions_of(HERO)
	for potion: MmObjectView in potions:
		var look: CardLook = _snapshot.look_of(potion.id)
		var entry: ZoneEntry = ZoneEntry.new("", potion.name, "", PlayerPanel.POTION_COLOR)
		entry.show_picture(PotionArt.new(look.art_key, ZoneEntry.ART_SIZE, true, _snapshot.rarity_of(potion.id)))
		var lines: Array[String] = ["%s · %s" % [look.held_type_line(), Inspector.RARITY_NAMES[_snapshot.rarity_of(potion.id)]]]
		lines.append_array(look.rules_lines)
		entry.show_lines(lines)
		_potions_window.body().add_child(entry)
		_add_held_entry(potion, entry, HeldWindows.Kind.POTIONS, HERO)
	_potions_window.show_title("%s Potions (%d)" % [_snapshot.names.possessive(HERO), potions.size()])


## Remembers [param entry] as what [param held] is drawn as, and makes it usable if a click
## on it answers: only the Hero's, since only they are asked.
func _add_held_entry(held: MmObjectView, entry: ZoneEntry, held_window: HeldWindows.Kind, player_id: int) -> void:
	_held_entries[held.id] = entry
	if player_id == HERO and HeldState.is_usable(held, _clicks):
		entry.make_usable().clicked.connect(_on_held_clicked.bind(held.id, held_window))


func _draw_banner(view: MmPlayerView) -> void:
	var text: String = "Draw"
	if not _snapshot.is_draw():
		var loser: int = VILLAIN if view.winner_id == HERO else HERO
		var reason: String = LOSS_REASONS.get(view.loss_reasons.get(loser, MmPlayer.LossReason.NONE), "lost")
		text = "%s\n%s %s." % ["Victory" if view.winner_id == HERO else "Defeat", _snapshot.names.starting(loser), reason]
	# Drawn as the Spoils screen's window is, its buttons as its Continue.
	var box: Panel = Panel.new()
	box.size = Vector2(620, 240)
	box.add_theme_stylebox_override("panel", WindowLook.plate(int(box.size.y)))
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if is_in_run:
		# The run counts the ending and says where to go: the Deckbox, or with no Hearts
		# left the main menu (milestone 16).
		var won: bool = not _snapshot.is_draw() and view.winner_id == HERO
		var onward: Button = _button("Continue", func() -> void:
			_presenter.stop()
			leave(Screens.scene(RunFlow.finish_encounter(won, _presenter.record()))), 18)
		onward.position = Vector2(210, 170)
		onward.size = Vector2(200, 44)
		_shade_as_window(onward)
		box.add_child(onward)
		return
	var again: Button = _button("Replay this seed", func() -> void: leave(scene_file_path), 18)
	again.position = Vector2(90, 170)
	again.size = Vector2(200, 44)
	_shade_as_window(again)
	box.add_child(again)
	var form: Button = _button("Start form", func() -> void: leave(START_FORM), 18)
	form.position = Vector2(330, 170)
	form.size = Vector2(200, 44)
	_shade_as_window(form)
	box.add_child(form)


## Dither Shades [param button], its size already set, as a WindowLook button.
static func _shade_as_window(button: Button) -> void:
	ButtonShading.shade(button, WindowLook.BUTTON, ButtonShading.DISABLED)
