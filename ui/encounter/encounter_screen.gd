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
## Run with a request: godot --path . -- --hero=red_green --villain=white_black --seed=7
## Add --screenshot=/absolute/path.png to save a picture and quit.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const MENU: String = "res://ui/menu/main_menu.tscn"
const START_FORM: String = "res://ui/encounter/start_form.tscn"
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
var _stack_entries: Array[ZoneEntry] = []
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
	_stack_window.size = Vector2(340, 400)
	_stack_window.hide()
	add_child(_stack_window)
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
	_option_menu = OptionMenu.new()
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
	begin(EncounterPresenter.new(request.setup(), request.villain_agent()))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			for frame: int in 4:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--screenshot="))
			get_tree().quit()


## Shows the encounter [param presenter] runs, and starts it.
func begin(presenter: EncounterPresenter) -> void:
	_presenter = presenter
	_presenter.changed.connect(_show)
	_presenter.start()


func _process(_delta: float) -> void:
	if _presenter == null or _is_paused:
		return
	set_hold_key_down(Input.is_key_pressed(KEY_CTRL))
	_presenter.poll()
	_spread_hand(0.3)


func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		click_empty_board()
		return
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
## being answered it confirms the selection instead, once that is complete.
func pass_priority() -> void:
	if not _selection.is_active():
		_command(_presenter.pass_priority)
	elif _selection.is_complete() and not _is_paused:
		_answer(_selection.answer())


## Undoes the Hero's last click of a half-made selection, and otherwise their last answer,
## as the undo button and Z do (A320).
func undo() -> void:
	if not _is_paused and _selection.undo():
		_redraw()
	else:
		_command(_presenter.undo)


## Leaves for [param scene], once a thinking Villain has finished.
func leave(scene: String) -> void:
	_presenter.wait_until_idle()
	navigate.call(scene)


## The Control that draws Game Object [param object_id], or null if none is on screen.
func face_of(object_id: int) -> Control:
	return _faces.get(object_id, null) as Control


func player_panel(player_id: int) -> PlayerPanel:
	return _panels[player_id]


func stack_window() -> ZoneWindow:
	return _stack_window


## What the Stack Window lists, from the top of the stack down.
func stack_entries() -> Array[ZoneEntry]:
	return _stack_entries


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
	_snapshot = snapshot
	_error = ""
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
	for child: Node in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	_faces.clear()
	_face_sizes.clear()
	_hand_faces.clear()
	_hand_rest.clear()
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
	_debug.show_snapshot(_snapshot)
	_info.show_snapshot(_snapshot, _error, regions["info"], _selection.hint())
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
		_stack_window.position = Vector2(battlefield.end.x - 350, battlefield.position.y + 170)
		_emblem_windows[HERO].position = Vector2(battlefield.position.x + 400, battlefield.end.y - 240)
		_emblem_windows[VILLAIN].position = Vector2(battlefield.position.x + 400, battlefield.position.y + 10)
		_debug.position = Vector2(battlefield.position.x + 6, battlefield.position.y + 110)
	for window: ZoneWindow in [_stack_window, _emblem_windows[HERO], _emblem_windows[VILLAIN]]:
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
	var face: Control = _faces[object_id]
	var rect: Rect2 = Rect2(face.get_global_rect().position - global_position, _face_sizes[object_id])
	for key: String in _lines:
		var ids: Array = _line_ids.get(key, [])
		if not ids.has(object_id):
			continue
		var line: ScrollRow = _lines[key]
		var middle: float = face.position.x + line.content().position.x + _face_sizes[object_id].x / 2.0
		var hidden: int = EncounterLayout.hidden_past(middle, line.size.x, ScrollRow.ARROW_WIDTH)
		var arrow: Button = line.left_arrow() if hidden < 0 else line.right_arrow()
		return EncounterLayout.block_line_end(rect, key.begins_with("hero"), hidden,
				arrow.get_global_rect().get_center().x - global_position.x)
	return rect.get_center()


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
			var middle: float = _faces[object_id].position.x + line.content().position.x + _face_sizes[object_id].x / 2.0
			var side: int = EncounterLayout.hidden_past(middle, line.size.x, ScrollRow.ARROW_WIDTH)
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
	_hand_rest = EncounterLayout.hand_rest(view.hand.size(), hand_rect, card)
	for index: int in view.hand.size():
		var face: CardFace = CardFace.new()
		face.setup(_snapshot.look_of(view.hand[index].id), card.y)
		face.position = _hand_rest[index]
		face.pivot_offset = Vector2(card.x / 2.0, card.y)
		face.rotation = EncounterLayout.fan_angle(index, view.hand.size())
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(face)
		_hand_faces.append(face)
		_remember_face(view.hand[index].id, face, card, glow)


## Where the hand's cards go with the cursor at [param cursor]: parted around the card under
## it, and never past the hand's bounds.
func hand_places(cursor: Vector2) -> Array[Vector2]:
	if _hand_faces.is_empty():
		return []
	return EncounterLayout.hand_spread_within(_hand_rest, _hand_faces[0].size, cursor, _regions["hero_hand"])


## Moves the hand's cards [param weight] of the way to where the cursor parts them.
func _spread_hand(weight: float) -> void:
	if _hand_faces.is_empty():
		return
	var card: Vector2 = _hand_faces[0].size
	var cursor: Vector2 = get_local_mouse_position()
	var places: Array[Vector2] = hand_places(cursor)
	var nearest: int = -1
	if EncounterLayout.is_cursor_over_hand(_hand_rest, card, cursor):
		nearest = roundi(EncounterLayout.hand_cursor_place(_hand_rest, card, cursor))
	for index: int in _hand_faces.size():
		_hand_faces[index].position = _hand_faces[index].position.lerp(places[index], weight)
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


## The Stack Window is there exactly while something is on the stack. The top of the stack,
## which resolves first, is listed first.
func _fill_stack_window(view: MmPlayerView) -> void:
	_stack_window.visible = not view.stack.is_empty()
	_stack_window.show_count(view.stack.size())
	_stack_window.clear()
	_stack_entries.clear()
	if view.stack.is_empty():
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack_window.body().add_child(row)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	row.add_child(list)
	for index: int in range(view.stack.size() - 1, -1, -1):
		var item: MmObjectView = view.stack[index]
		var is_spell: bool = item.card_id != MmGameObject.NO_CARD
		var whose: String = "Hero" if item.controller_id == HERO else "Villain"
		var entry_name: String = item.name
		var detail: String = whose
		if not is_spell:
			# An ability is named for its source. Its effect text arrives with 13d.
			entry_name = DebugDecisionForm.name_of(view, item.source_object_id) if _is_visible_object(item.source_object_id) else item.name
			detail = "%s · ability" % whose
		var entry: ZoneEntry = ZoneEntry.new(_snapshot.look_of(item.id).art_key, entry_name, detail, Color("#8a93a6"))
		list.add_child(entry)
		_stack_entries.append(entry)
	var side: VBoxContainer = VBoxContainer.new()
	row.add_child(side)
	side.add_child(_small_label("resolves\nfirst"))
	var arrow: StackArrow = StackArrow.new()
	arrow.custom_minimum_size = Vector2(54, 30)
	arrow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(arrow)
	side.add_child(_small_label("resolves\nlast"))


func _is_visible_object(object_id: int) -> bool:
	for seen: MmObjectView in _snapshot.visible_objects():
		if seen.id == object_id:
			return true
	return false


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
