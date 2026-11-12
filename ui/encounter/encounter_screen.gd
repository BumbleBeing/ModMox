class_name EncounterScreen
extends Control
## The Encounter Screen (game glossary): shows an encounter to the human and takes their
## answers. It draws only from the snapshots its Encounter Presenter hands it (ADR 0021):
## the Regions from EncounterLayout, the Stack Window and Emblems windows over them, and the
## Debug Decision Panel for every decision kind that has no input of its own yet.
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
## to be put in order appear above the stack and are moved with buttons (a TriggerOrder,
## kept here like the CombatSelection), and a choice between replacement effects is made
## in a window of its own.
##
## Permanents do not jump from one redraw to the next: a FaceMotion, kept here as well,
## remembers where each one's face was drawn, and every frame the screen places each face
## part-way to where the last redraw put it. A permanent that has left is drawn for a
## moment longer as a ghost, on a layer of its own that a redraw leaves alone.
##
## The Hero's hand is kept in their own order (a HandOrder) and its cards are dragged: a
## card held above the hand's strip is played when it is let go, and one let go over the
## strip is put down where the others made room. The card being held is a DragCard, kept
## here as well. Nothing is rebuilt between picking a card up and letting it go: the card's
## own face is lifted to a layer above the windows, and the rest of the hand is only told
## where to go. A double-click plays a card too, and one click does nothing.
##
## Run with a request: godot --path . -- --hero=red_green --villain=white_black --seed=7
## Add --screenshot=/absolute/path.png to save a picture and quit.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const MENU: String = "res://ui/menu/main_menu.tscn"
const START_FORM: String = "res://ui/encounter/start_form.tscn"
## How much of the way to its place a card of the hand goes in a sixtieth of a second.
const HAND_EASE: float = 0.3
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
## How this screen leaves for another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: get_tree().change_scene_to_file(scene)

var _presenter: EncounterPresenter = null
var _snapshot: EncounterSnapshot = null
var _error: String = ""
var _board: Control
var _panels: Dictionary[int, PlayerPanel] = {}
var _stack_window: ZoneWindow
var _emblem_windows: Dictionary[int, ZoneWindow] = {}
var _debug: DebugDecisionPanel
var _faces: Dictionary[int, Control] = {}
var _face_sizes: Dictionary[int, Vector2] = {}
var _pointed_id: int = DebugDecisionForm.NONE
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
var _trigger_entries: Array[StackEntry] = []
var _choice_window: ZoneWindow
var _choice_entries: Array[ZoneEntry] = []
## What the entry under the cursor has marked on the board.
var _marked: Array[Control] = []
var _banner: Control = null
var _info: InfoPanel
var _option_menu: OptionMenu
var _pause_menu: PauseMenu
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


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("#1a1d22")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
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
		panel.pass_pressed.connect(pass_priority)
		panel.undo_pressed.connect(undo)
		panel.auto_pass_toggled.connect(func() -> void:
			_presenter.set_auto_passing(not _presenter.is_auto_passing())
			_redraw())
		add_child(panel)
		_panels[player_id] = panel
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
	_debug = DebugDecisionPanel.new()
	_debug.size = Vector2(380, 520)
	_debug.answered.connect(_answer)
	_debug.option_pointed.connect(_point_at)
	add_child(_debug)
	_info = InfoPanel.new()
	_info.cancel_pressed.connect(func() -> void: _command(_presenter.cancel_cast))
	_info.all_attack_pressed.connect(func() -> void:
		if not _is_paused and _selection.select_all():
			_redraw())
	add_child(_info)
	_drag_layer = Control.new()
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_layer)
	_option_menu = OptionMenu.new()
	_option_menu.closed.connect(_on_menu_closed)
	_option_menu.chosen.connect(_answer)
	_option_menu.pointed.connect(func(text: String) -> void: _info.show_option(text))
	add_child(_option_menu)
	_pause_menu = PauseMenu.new()
	_pause_menu.resume_pressed.connect(set_paused.bind(false))
	_pause_menu.concede_confirmed.connect(_concede)
	_pause_menu.quit_confirmed.connect(leave.bind(MENU))
	add_child(_pause_menu)
	resized.connect(_redraw)
	if not starts_itself:
		return
	if request == null:
		request = EncounterRequest.from_arguments(OS.get_cmdline_user_args())
	if request == null:
		request = EncounterRequest.new()
	var presenter: EncounterPresenter = EncounterPresenter.new(request.setup(), request.villain_agent())
	var picture: String = screenshot_path(OS.get_cmdline_user_args())
	if picture == "":
		use_game_pace(presenter)
	begin(presenter)
	if picture != "":
		for frame: int in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## Where [param arguments] ask for a picture to be saved, or "" if they do not.
static func screenshot_path(arguments: PackedStringArray) -> String:
	for argument: String in arguments:
		if argument.begins_with("--screenshot="):
			return argument.trim_prefix("--screenshot=")
	return ""


## Plays at the game's pace: [param presenter] holds the Villain's answers back and faces
## take time to move (Pacing). Without this nothing waits or moves, which is what tests and
## screenshots want (A369). Call it before begin().
func use_game_pace(presenter: EncounterPresenter) -> void:
	presenter.action_wait_msec = Pacing.ACTION_MSEC
	presenter.mana_wait_msec = Pacing.MANA_MSEC
	_motion.seconds = Pacing.MOVE_SECONDS


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
	set_hold_key_down(Input.is_key_pressed(KEY_CTRL))
	_presenter.poll()
	_spread_hand(EncounterLayout.ease_weight(HAND_EASE, delta))


## A press on a card of the hand is taken here, before anything under the card can have it:
## a card that has risen under the cursor lies over the Hero's lands, and a land that can be
## tapped would otherwise take a press on the card's top edge. Only what is drawn over the
## hand comes first (_is_covered). While a card is pressed or held, the mouse is followed
## wherever it goes, over windows and buttons too.
func _input(event: InputEvent) -> void:
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


## Does what pressing [param keycode] does: Escape opens and closes the Pause Menu, and
## while it is closed Space passes and Z undoes. Later: these keys become rebindable (13g).
func press_key(keycode: Key) -> void:
	if keycode == KEY_ESCAPE:
		set_paused(not _is_paused)
	elif _is_paused:
		return
	elif keycode == KEY_SPACE:
		pass_priority()
	elif keycode == KEY_Z:
		undo()


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
		_pause_menu.open(_regions["battlefield"], not _snapshot.is_over())
	else:
		_pause_menu.close()


func is_paused() -> bool:
	return _is_paused


## Whether the hold key (Ctrl) is down: the Hero's next spell or ability keeps priority, and
## the Info Panel says so.
func set_hold_key_down(is_down: bool) -> void:
	_presenter.is_hold_key_down = is_down
	_info.set_hold_key_down(is_down)


## What a click on nothing does: a blocker that was picked up is put down, unassigned (A314).
func click_empty_board() -> void:
	if not _is_paused and _selection.put_down():
		_redraw()


## Passes priority, as the pass button and the space bar do. While a combat decision is
## being answered it confirms the selection instead, once that is complete, and while
## triggers are being ordered it confirms their order.
func pass_priority() -> void:
	if _trigger_order.is_active():
		if not _is_paused:
			_answer(_trigger_order.answer())
	elif not _selection.is_active():
		_command(_presenter.pass_priority)
	elif _selection.is_complete() and not _is_paused:
		_answer(_selection.answer())


## Undoes the Hero's last click of a half-made selection or their last move of a trigger,
## and otherwise their last answer, as the undo button and Z do (A320, A339).
func undo() -> void:
	if not _is_paused and (_selection.undo() or _trigger_order.undo()):
		_redraw()
	else:
		_command(_presenter.undo)


## Leaves for [param scene], once a thinking Villain has finished.
func leave(scene: String) -> void:
	_presenter.wait_until_idle()
	navigate.call(scene)


## Whether something drawn over the hand is under [param cursor]: an open window, or the
## Option Menu. A press there is theirs, never the card's beneath.
func _is_covered(cursor: Vector2) -> bool:
	if _option_menu.is_open():
		return true
	var windows: Array[Control] = [_stack_window, _choice_window, _debug]
	windows.append_array(_emblem_windows.values())
	for window: Control in windows:
		if window.visible and Rect2(window.position, window.size).has_point(cursor):
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
	if not EncounterLayout.is_cursor_over_hand(_hand_rest, card, cursor):
		return DragCard.NONE
	var index: int = roundi(EncounterLayout.hand_cursor_place(_hand_rest, card, cursor))
	var is_on_it: bool = Rect2(_hand_faces[index].position, card).grow(8.0).has_point(cursor) \
			or Rect2(hand_places(cursor)[index], card).grow(8.0).has_point(cursor)
	return _hand_cards[index] if is_on_it else DragCard.NONE


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


## The left button came up at [param cursor]. A held card let go above the hand's strip is
## played: at once with one way to play it, from the Option Menu with several, the card
## waiting where it was let go (A372). One that cannot be played right now goes back to its
## place without a word (A380). Over the strip it is put down where the hand made room.
func release_hand(cursor: Vector2) -> void:
	drag_to(cursor)
	if not _drag.is_holding():
		if _drag.is_pressed():
			_drag.drop()
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


## Lets [param delta] seconds of Face Motion go by, as every frame does: faces on their way
## are drawn further along, ghosts fade, and block lines follow their creatures.
func advance_motion(delta: float) -> void:
	var was_moving: bool = _motion.is_moving()
	_motion.advance(delta)
	if was_moving:
		_pose_faces()
		_show_block_lines()


func face_motion() -> FaceMotion:
	return _motion


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
	return _trigger_entries


## The window that asks which replacement effect applies first.
func choice_window() -> ZoneWindow:
	return _choice_window


func choice_entries() -> Array[ZoneEntry]:
	return _choice_entries


## What takes a click on the choice window's entry number [param index].
func choice_catcher(index: int) -> ClickCatcher:
	return ClickCatcher.of(_choice_entries[index])


func emblems_window(player_id: int) -> ZoneWindow:
	return _emblem_windows[player_id]


func debug_panel() -> DebugDecisionPanel:
	return _debug


func info_panel() -> InfoPanel:
	return _info


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
	return _panels[HERO].pass_button()


func undo_button() -> Button:
	return _panels[HERO].undo_button()


func auto_pass_button() -> Button:
	return _panels[HERO].auto_pass_button()


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
	_redraw()


func _toggle_emblems(player_id: int) -> void:
	var window: ZoneWindow = _emblem_windows[player_id]
	window.visible = not window.visible
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
			_redraw()
		return
	var options: Array[ClickOption] = _clicks.options_of(object_id)
	if options.size() == 1:
		_answer(options[0].answer)
	elif options.size() > 1:
		_option_menu.open(options, get_local_mouse_position(), _regions["battlefield"])


func _point_at(object_id: int) -> void:
	if _faces.has(_pointed_id):
		BorderEffects.remove_pointer(_faces[_pointed_id])
	_pointed_id = object_id
	if _faces.has(object_id):
		BorderEffects.add_pointer(_faces[object_id], _face_sizes[object_id])


## Draws everything from the latest snapshot. Reads nothing else, so it is safe while the
## Villain is thinking.
func _redraw() -> void:
	if _snapshot == null:
		return
	_option_menu.close()
	_clear_marks()
	var unseen: Array[int] = _unseen_faces()
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
	_banner = null
	var view: MmPlayerView = _snapshot.view
	# While the Villain thinks the Hero is asked nothing, so nothing glows or takes a click.
	var glow: DecisionClicks = DecisionClicks.of(null if _snapshot.is_over() else _snapshot.decision, view)
	# While a blocker is picked up, the attackers it can block glow as targets (A313).
	for attacker_id: int in _selection.target_ids():
		glow.objects[attacker_id] = DecisionClicks.Kind.TARGET
	_clicks = glow
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(size)
	_regions = regions
	_place_windows(regions["battlefield"])

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
	_panels[HERO].show_snapshot(_snapshot, glow, _presenter.stops, regions["hero_panel"], true, _presenter.is_auto_passing())
	if _selection.is_active():
		_panels[HERO].show_confirm(_selection.confirm_text(), _selection.is_complete(), _selection.can_undo())
	elif _trigger_order.is_active():
		_panels[HERO].show_confirm("Confirm order", true, _trigger_order.can_undo())
	_add_player_stepper()
	_draw_villain_hand(view.hand_sizes.get(VILLAIN, 0), regions["villain_hand"])
	_draw_row(_permanents(view, VILLAIN, true), regions["villain_lands"], glow)
	_draw_nonlands(view, VILLAIN, regions["villain_nonlands"], glow)
	_draw_nonlands(view, HERO, regions["hero_nonlands"], glow)
	_draw_row(_permanents(view, HERO, true), regions["hero_lands"], glow)
	_draw_hand(view, regions["hero_hand"], glow)
	for player_id: int in [VILLAIN, HERO]:
		var who: String = "hero" if player_id == HERO else "villain"
		_draw_library(view.library_sizes.get(player_id, 0), who + "_library", regions[who + "_library"])
		_draw_pile("Graveyard", view.graveyards.get(player_id, []), who + "_graveyard", regions[who + "_graveyard"])
		_draw_pile("Exile", view.exiles.get(player_id, []), who + "_exile", regions[who + "_exile"])
		_fill_emblems_window(view, player_id)
	_fill_stack_window(view)
	_fill_choice_window(view)
	_debug.show_snapshot(_snapshot)
	_info.show_snapshot(_snapshot, _error, regions["info"], _selection.hint())
	_info.show_option(_release_text())
	_move_faces(unseen)
	_tint_arrows()
	_show_block_lines()
	if _snapshot.is_over():
		_draw_banner(view)
	_spread_hand(1.0)


## The Stack Window and Emblems windows stay inside the battlefield; each opens at its own
## place the first time and afterwards stays where it was left.
func _place_windows(battlefield: Rect2) -> void:
	if not _are_windows_placed:
		_are_windows_placed = true
		_stack_window.position = Vector2(battlefield.end.x - 410, battlefield.position.y + 170)
		_choice_window.position = battlefield.get_center() - _choice_window.size / 2.0
		_emblem_windows[HERO].position = Vector2(battlefield.position.x + 400, battlefield.end.y - 240)
		_emblem_windows[VILLAIN].position = Vector2(battlefield.position.x + 400, battlefield.position.y + 10)
		_debug.position = Vector2(battlefield.position.x + 6, battlefield.position.y + 110)
	for window: ZoneWindow in [_stack_window, _choice_window, _emblem_windows[HERO], _emblem_windows[VILLAIN]]:
		window.bounds = battlefield
		window.fit()
	_debug.bounds = Rect2(Vector2.ZERO, size)
	_debug.fit()


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


## Creatures in combat stand to the left of the rest, in object ID order. Only those the
## engine has in combat: while the Hero is choosing, nothing changes places under the cursor.
func _fighting_first(creatures: Array[MmObjectView]) -> Array[MmObjectView]:
	var ids: Array[int] = []
	var is_fighting: Array[bool] = []
	for creature: MmObjectView in creatures:
		ids.append(creature.id)
		is_fighting.append(_is_fighting(creature))
	var ordered: Array[MmObjectView] = []
	for index: int in EncounterLayout.combat_order(ids, is_fighting):
		ordered.append(creatures[index])
	return ordered


func _remember_face(object_id: int, face: Control, face_size: Vector2, glow: DecisionClicks) -> void:
	_faces[object_id] = face
	_face_sizes[object_id] = face_size
	if glow.objects.has(object_id):
		BorderEffects.add_glow(face, face_size, DecisionClicks.color_of(glow.objects[object_id]))
	if object_id == _pointed_id:
		BorderEffects.add_pointer(face, face_size)
	if not glow.options_of(object_id).is_empty() or _selection.is_clickable(object_id):
		ClickCatcher.add(face, face_size).clicked.connect(_on_object_clicked.bind(object_id))
	_add_combat_marks(object_id, face, face_size)


## What combat input draws on a face: a white outline on the blocker picked up and on the
## creature whose damage is being divided (A313, A325), how much that creature has left to
## give, and a stepper on each creature it can give damage to.
func _add_combat_marks(object_id: int, face: Control, face_size: Vector2) -> void:
	var divide: DivideCombatDamageDecision = _snapshot.decision as DivideCombatDamageDecision
	var is_source: bool = divide != null and _selection.is_active() and divide.source_id == object_id
	if is_source or (object_id == _selection.picked_id() and _selection.is_active()):
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
		face.modulate.a = pose.alpha
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
	for card_id: int in _hand_order.cards():
		if not (_drag.is_lifted() and card_id == _drag.card_id()):
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


## A lifted card that can be played glows, brighter where letting go would play it (A375).
func _glow_lifted_face() -> void:
	if _hand_options(_drag.card_id()).is_empty():
		return
	var is_bright: bool = _drag.is_waiting() or _drag.is_above()
	var kind: DecisionClicks.Kind = DecisionClicks.Kind.OTHER
	BorderEffects.set_glow(_lifted_face, _lifted_face.size,
			DecisionClicks.bright_color_of(kind) if is_bright else DecisionClicks.color_of(kind))


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
	if BorderEffects.glow_color(face) != null:
		BorderEffects.set_glow(face, face.size, DecisionClicks.color_of(DecisionClicks.Kind.OTHER))
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
	if _drag.is_lifted():
		return _hand_rest.duplicate()
	return EncounterLayout.hand_spread_within(_hand_rest, _hand_faces[0].size, cursor, _regions["hero_hand"])


## Moves the hand's cards [param weight] of the way to where they belong, in place and in
## turn.
func _spread_hand(weight: float) -> void:
	if _hand_faces.is_empty():
		return
	var card: Vector2 = _hand_faces[0].size
	var cursor: Vector2 = get_local_mouse_position()
	var places: Array[Vector2] = hand_places(cursor)
	var nearest: int = -1
	if not _drag.is_lifted() and EncounterLayout.is_cursor_over_hand(_hand_rest, card, cursor):
		nearest = roundi(EncounterLayout.hand_cursor_place(_hand_rest, card, cursor))
	for index: int in _hand_faces.size():
		_hand_faces[index].position = _hand_faces[index].position.lerp(places[index], weight)
		_hand_faces[index].rotation = lerpf(_hand_faces[index].rotation, _hand_turns[index], weight)
		_hand_faces[index].z_index = 1 if index == nearest else 0


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


## A graveyard or exile pile: its top card and how many cards it holds.
func _draw_pile(zone_name: String, cards: Array, key: String, pile_rect: Rect2) -> void:
	var card: Vector2 = Vector2(EncounterLayout.PILE_HEIGHT * CardGeometry.ASPECT, EncounterLayout.PILE_HEIGHT)
	var at: Vector2 = pile_rect.position + Vector2((pile_rect.size.x - card.x) / 2.0, 0)
	if cards.is_empty():
		_draw_empty_pile(at, card)
	else:
		var top: MmObjectView = cards.back() as MmObjectView
		var face: CardFace = CardFace.new()
		face.setup(_snapshot.look_of(top.id), card.y)
		face.position = at
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(face)
		_faces[top.id] = face
		_face_sizes[top.id] = card
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
	label.add_theme_font_size_override("font_size", 14)
	_board.add_child(label)
	_pile_labels[key] = label


func _button(text: String, on_press: Callable, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(on_press)
	return button


## The Stack Window is there while something is on the stack, or while triggers are being
## put in order. The top of the stack, which resolves first, is listed first.
func _fill_stack_window(view: MmPlayerView) -> void:
	var ids: Array[int] = []
	for seen: MmObjectView in view.stack:
		ids.append(seen.id)
	_stack_colors.update(ids)
	_stack_window.visible = not view.stack.is_empty() or _trigger_order.is_active()
	_stack_window.show_count(view.stack.size())
	_stack_window.clear()
	_stack_entries.clear()
	_stack_items.clear()
	_trigger_entries.clear()
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
		var item: StackItem = StackItem.of(seen, view)
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
	var side: VBoxContainer = VBoxContainer.new()
	row.add_child(side)
	side.add_child(_small_label("resolves\nfirst"))
	var arrow: StackArrow = StackArrow.new()
	arrow.custom_minimum_size = Vector2(54, 30)
	arrow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(arrow)
	side.add_child(_small_label("resolves\nlast"))


## The triggers being put in order, above the stack: plain and dashed, since they are not
## on the stack yet, each with buttons to move it (A339, A345).
func _add_trigger_entries(view: MmPlayerView) -> void:
	var decision: OrderTriggersDecision = _snapshot.decision as OrderTriggersDecision
	_stack_window.body().add_child(_small_label("Triggers to order: the top one resolves first"))
	var order: Array[int] = _trigger_order.order()
	for place: int in order.size():
		var number: int = order[place]
		var entry: StackEntry = StackEntry.new(_trigger_art(decision, number), _trigger_text(decision, number),
			StackItem.player_name(decision.player_id), StackColors.PLAIN, true)
		entry.add_move_buttons(_trigger_order.can_move(place, -1), _trigger_order.can_move(place, 1))
		entry.moved.connect(_move_trigger.bind(place))
		entry.hovered.connect(_on_trigger_hovered.bind(number))
		_stack_window.body().add_child(entry)
		_trigger_entries.append(entry)
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


func _move_trigger(step: int, place: int) -> void:
	if not _is_paused and _trigger_order.move(place, step):
		_redraw()


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
		BorderEffects.add_mark(portrait, portrait.size, color, true)
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
		BorderEffects.add_mark(_faces[object_id], _face_sizes[object_id], color, is_dashed)
		_marked.append(_faces[object_id])


func _clear_marks() -> void:
	for host: Control in _marked:
		if is_instance_valid(host):
			BorderEffects.remove_mark(host)
	_marked.clear()


## The window that asks which replacement effect applies first (A340): there exactly while
## the Hero is asked, with an entry for each effect, clicked to choose it.
func _fill_choice_window(view: MmPlayerView) -> void:
	var decision: ChooseReplacementEffectDecision = _snapshot.decision as ChooseReplacementEffectDecision
	_choice_window.clear()
	_choice_entries.clear()
	_choice_window.visible = decision != null
	if decision == null:
		return
	_choice_window.show_title(ReplacementText.title(decision, view))
	_choice_window.move_to_front()
	for index: int in decision.options.size():
		var active: ActiveReplacementEffect = decision.options[index]
		var source: MmObjectView = ReplacementText.source_of(active, view)
		var look: CardLook = _snapshot.look_of(source.id) if source != null else null
		var entry: ZoneEntry = ZoneEntry.new(look.art_key if look != null else "", ReplacementText.source_name(active, view),
			ReplacementText.effect_text(active, view), StackColors.PLAIN)
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
	_info.show_option("%s — %s" % [ReplacementText.source_name(active, _snapshot.view), ReplacementText.effect_text(active, _snapshot.view)])
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
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1, 1, 1, 0.7)
	return label


func _fill_emblems_window(view: MmPlayerView, player_id: int) -> void:
	var window: ZoneWindow = _emblem_windows[player_id]
	window.clear()
	var count: int = 0
	for emblem: MmObjectView in view.command:
		if emblem.controller_id != player_id:
			continue
		count += 1
		var kinds: Array[String] = []
		for ability: MmAbility in emblem.abilities:
			kinds.append("Triggered ability" if ability is TriggeredAbility else ("Activated ability" if ability is ActivatedAbility else "Static ability"))
		window.body().add_child(ZoneEntry.new("", emblem.name, ", ".join(kinds), PlayerPanel.GOLD))
	window.show_count(count)


func _draw_banner(view: MmPlayerView) -> void:
	var text: String = "Draw"
	if not _snapshot.is_draw():
		var loser: int = VILLAIN if view.winner_id == HERO else HERO
		var reason: String = LOSS_REASONS.get(view.loss_reasons.get(loser, MmPlayer.LossReason.NONE), "lost")
		text = "%s\nThe %s %s." % ["Victory" if view.winner_id == HERO else "Defeat", "Villain" if loser == VILLAIN else "Hero", reason]
	var box: Panel = CardShapes.rounded(Vector2(620, 240), 12, Color(0.05, 0.05, 0.07, 0.95))
	box.position = (size - box.size) / 2.0
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.set_meta("text", text)
	_board.add_child(box)
	_banner = box
	var label: Label = Label.new()
	label.text = text
	label.size = Vector2(620, 150)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	box.add_child(label)
	var again: Button = _button("Replay this seed", func() -> void: leave(scene_file_path), 18)
	again.position = Vector2(90, 170)
	again.size = Vector2(200, 44)
	box.add_child(again)
	var form: Button = _button("Start form", func() -> void: leave(START_FORM), 18)
	form.position = Vector2(330, 170)
	form.size = Vector2(200, 44)
	box.add_child(form)
