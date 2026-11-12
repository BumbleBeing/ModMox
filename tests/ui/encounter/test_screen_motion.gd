extends GutTest
## Face Motion on the Encounter Screen: the board is rebuilt from every snapshot, and each
## permanent's face eases from where it was drawn to where it now belongs (A356, A360).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const CombatAgent := preload("res://tests/ui/encounter/support/combat_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const MOVE: float = 0.25
const NEAR: Vector2 = Vector2(0.05, 0.05)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced, and a ghost that has faded, are freed at the end of the frame.
	await wait_process_frames(2)


func test_a_screen_moves_nothing_until_it_is_told_to_play_at_the_games_pace() -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	var presenter: EncounterPresenter = EncounterPresenter.new(_bears(), DefaultAnswerAgent.new())
	assert_eq(_screen.face_motion().seconds, 0.0)

	_screen.use_game_pace(presenter)

	assert_eq(_screen.face_motion().seconds, Pacing.MOVE_SECONDS)
	assert_eq(presenter.action_wait_msec, Pacing.ACTION_MSEC)
	assert_eq(presenter.mana_wait_msec, Pacing.MANA_MSEC)


func test_a_screenshot_is_asked_for_with_its_path() -> void:
	assert_eq(EncounterScreen.screenshot_path(["--seed=7", "--screenshot=/tmp/a.png"] as PackedStringArray), "/tmp/a.png")
	assert_eq(EncounterScreen.screenshot_path(["--seed=7", "--hero=red_green"] as PackedStringArray), "")


func test_a_permanent_that_arrives_fades_in_at_its_place() -> void:
	_open(_bears())
	_cast("Bear")
	_resolve()
	var bear: int = _permanents("Bear")[0]
	var place: Vector2 = _screen.face_motion().rest_of(bear).center

	assert_eq(_screen.face_of(bear).modulate.a, 0.0)
	assert_almost_eq(_middle(_screen.face_of(bear)), place, NEAR)
	_advance(MOVE / 2.0)
	assert_almost_eq(_screen.face_of(bear).modulate.a, 0.5, 0.01)
	assert_almost_eq(_middle(_screen.face_of(bear)), place, NEAR)
	_advance(MOVE / 2.0)
	assert_eq(_screen.face_of(bear).modulate.a, 1.0)
	assert_false(_screen.face_motion().is_moving())


func test_a_permanent_whose_place_changes_slides_there() -> void:
	_open(_bears())
	_cast("Bear")
	_resolve()
	_settle()
	var first: int = _permanents("Bear")[0]
	var from: Vector2 = _middle(_screen.face_of(first))

	_cast("Bear")
	_resolve()

	var to: Vector2 = _screen.face_motion().rest_of(first).center
	assert_gt(from.x - to.x, 20.0, "A second creature moves the first one over.")
	assert_almost_eq(_middle(_screen.face_of(first)), from, NEAR, "The rebuilt board draws it where it was.")
	_advance(MOVE / 2.0)
	assert_almost_eq(_middle(_screen.face_of(first)), (from + to) / 2.0, NEAR)
	_advance(MOVE / 2.0)
	assert_almost_eq(_middle(_screen.face_of(first)), to, NEAR)
	assert_almost_eq(_screen.face_of(first).get_global_rect().get_center(), to + _screen.global_position, NEAR)


func test_a_redraw_of_the_same_board_mid_move_restarts_nothing() -> void:
	_open(_bears())
	_cast("Bear")
	_resolve()
	_settle()
	var first: int = _permanents("Bear")[0]
	_cast("Bear")
	_resolve()
	var to: Vector2 = _screen.face_motion().rest_of(first).center
	_advance(MOVE / 2.0)
	var before: Vector2 = _middle(_screen.face_of(first))
	var face: Control = _screen.face_of(first)

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	assert_ne(_screen.face_of(first), face, "The board was rebuilt.")
	assert_almost_eq(_middle(_screen.face_of(first)), before, NEAR)
	_advance(MOVE / 2.0)
	assert_almost_eq(_middle(_screen.face_of(first)), to, NEAR, "It arrived when it would have.")


func test_an_undo_puts_everything_at_its_place_at_once() -> void:
	_open(_bears())
	_cast("Bear")
	_resolve()
	_settle()
	_play("Forest")
	var forest: int = _permanents("Forest")[0]
	assert_eq(_screen.face_of(forest).modulate.a, 0.0, "The land is fading in.")

	_screen.undo()

	assert_null(_screen.face_of(forest))
	assert_null(_screen.ghost_of(forest), "A rewind leaves no ghost (A365).")
	assert_false(_screen.face_motion().is_moving())

	_play("Forest")
	assert_eq(_screen.face_of(_permanents("Forest")[0]).modulate.a, 0.0, "What happens after an undo moves as usual.")


func test_a_window_of_another_size_puts_everything_at_its_place_at_once() -> void:
	_open(_bears())
	_cast("Bear")
	_resolve()
	_settle()
	var first: int = _permanents("Bear")[0]
	_cast("Bear")
	_resolve()
	assert_true(_screen.face_motion().is_moving())

	_screen.size = Vector2(1600, 1000)

	assert_false(_screen.face_motion().is_moving())
	assert_almost_eq(_middle(_screen.face_of(first)), _screen.face_motion().rest_of(first).center, NEAR)
	assert_eq(_screen.face_of(_permanents("Bear")[1]).modulate.a, 1.0)
	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)
	assert_false(_screen.face_motion().is_moving(), "A redraw at the same size after that snaps nothing and moves nothing.")


func test_a_creature_clicked_to_attack_eases_into_the_lane_and_is_clicked_where_it_is_drawn() -> void:
	_open_combat([_bear()])
	_reach_attackers(2)
	_settle()
	var attacker: int = (_presenter.snapshot().decision as DeclareAttackersDecision).candidate_ids[0]
	var rest: Vector2 = _middle(_screen.face_of(attacker))

	_click(attacker)

	var lane: Vector2 = _screen.face_motion().rest_of(attacker).center
	assert_almost_eq(rest.y - lane.y, EncounterLayout.COMBAT_STEP, 0.5)
	assert_almost_eq(_middle(_screen.face_of(attacker)), rest, NEAR, "The Hero's own click moves it too (A365).")
	_advance(MOVE / 2.0)
	var catcher: ClickCatcher = _screen.click_catcher(attacker)
	assert_almost_eq(_middle(_screen.face_of(attacker)).y, (rest.y + lane.y) / 2.0, 0.05)
	assert_almost_eq(catcher.get_global_transform() * (catcher.size / 2.0), _middle(_screen.face_of(attacker)) + _screen.global_position,
			Vector2(1, 1), "What takes the click is where the face is drawn (A366).")
	_advance(MOVE / 2.0)
	assert_almost_eq(_middle(_screen.face_of(attacker)), lane, NEAR)


func test_an_attacker_turns_sideways_and_the_bystanders_shrink_over_the_move() -> void:
	_open_combat([_bear()])
	_reach_attackers(2)
	var ids: Array[int] = (_presenter.snapshot().decision as DeclareAttackersDecision).candidate_ids
	_click(ids[0])
	_settle()

	_screen.pass_priority()
	_presenter.wait_until_idle()

	var attacker: BattlefieldFace = _screen.face_of(ids[0]) as BattlefieldFace
	var bystander: BattlefieldFace = _screen.face_of(ids[1]) as BattlefieldFace
	assert_true(_seen(ids[0]).is_tapped)
	assert_eq(attacker.turn(), 0.0, "It starts upright")
	assert_false(attacker.is_darkened())
	assert_almost_eq(bystander.scale.x, 1.0 / EncounterLayout.BYSTANDER_SCALE, 0.01, "and the bystander at the size it was.")
	assert_eq(bystander.scale.x, bystander.scale.y)
	assert_eq(bystander.pivot_offset, bystander.size / 2.0, "It shrinks about its middle.")
	_advance(MOVE / 2.0)
	assert_almost_eq(attacker.turn(), 0.5, 0.01)
	assert_almost_eq(attacker.card().rotation_degrees, 45.0, 1.0)
	assert_almost_eq(bystander.scale.x, (1.0 + 1.0 / EncounterLayout.BYSTANDER_SCALE) / 2.0, 0.01)
	_advance(MOVE / 2.0)
	assert_eq(attacker.turn(), 1.0)
	assert_eq(bystander.scale, Vector2.ONE)


func test_a_move_in_flight_finishes_under_the_pause_menu() -> void:
	_open(_bears())
	_cast("Bear")
	_resolve()
	var bear: int = _permanents("Bear")[0]
	assert_eq(_screen.face_of(bear).modulate.a, 0.0)

	_screen.set_paused(true)
	for frame: int in 40:
		_screen._process(0.01)

	assert_eq(_screen.face_of(bear).modulate.a, 1.0, "A368.")
	_screen.set_paused(false)


func test_a_permanent_that_leaves_is_a_ghost_that_fades_and_takes_no_clicks() -> void:
	_open(_setup_of([_bear(), Scenario.free_shock("Zap", 2)]))
	_cast("Bear")
	_resolve()
	_settle()
	var bear: int = _permanents("Bear")[0]
	var place: Vector2 = _middle(_screen.face_of(bear))
	var height: float = (_screen.face_of(bear) as BattlefieldFace).card().size.y

	_cast("Zap")
	_target(bear)
	_resolve()

	var ghost: BattlefieldFace = _screen.ghost_of(bear)
	assert_null(_screen.face_of(bear), "The creature died.")
	assert_null(_screen.click_catcher(bear))
	assert_almost_eq(_middle(ghost), place, NEAR)
	assert_eq(ghost.card().size.y, height)
	assert_eq(ghost.name_text().shown_text(), "Bear")
	assert_eq(ghost.modulate.a, 1.0)
	assert_eq(ghost.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_null(ClickCatcher.of(ghost))
	assert_gt(ghost.get_parent().get_index(), 1, "Ghosts are on a layer over the board")
	assert_lt(ghost.get_parent().get_index(), _screen.block_lines().get_index(), "and under the block lines.")
	assert_eq((ghost.get_parent() as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_advance(MOVE / 2.0)
	assert_almost_eq(ghost.modulate.a, 0.5, 0.01)

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)
	assert_eq(_screen.ghost_of(bear), ghost, "A redraw leaves a ghost alone.")
	_advance(MOVE / 2.0)

	assert_null(_screen.ghost_of(bear))
	assert_true(ghost.is_queued_for_deletion())


func test_a_tapped_ghost_fades_sideways() -> void:
	_open_combat([_bear(), Scenario.free_shock("Zap", 2)])
	_reach_attackers(1)
	var bear: int = _permanents("Bear")[0]
	_presenter.answer([bear] as Array[int])
	_presenter.wait_until_idle()
	_settle()
	assert_true(_seen(bear).is_tapped)
	var place: Vector2 = _middle(_screen.face_of(bear))

	_cast("Zap")
	_target(bear)
	_resolve()

	var ghost: BattlefieldFace = _screen.ghost_of(bear)
	assert_eq(ghost.turn(), 1.0)
	assert_almost_eq(_middle(ghost), place, NEAR)


func test_a_creature_that_leaves_part_way_through_turning_leaves_its_ghost_turned_that_far() -> void:
	_open_combat([_bear(), Scenario.free_shock("Zap", 2)])
	_reach_attackers(1)
	var bear: int = _permanents("Bear")[0]
	_settle()
	_presenter.answer([bear] as Array[int])
	_presenter.wait_until_idle()
	_advance(MOVE / 2.0)

	_cast("Zap")
	_target(bear)
	_resolve()

	assert_almost_eq(_screen.ghost_of(bear).turn(), 0.5, 0.01)
	assert_almost_eq(_screen.ghost_of(bear).card().rotation_degrees, 45.0, 1.0)


func test_a_permanent_that_leaves_while_scrolled_out_of_sight_leaves_no_ghost() -> void:
	_open(_setup_of([_bear(), _bear(), Scenario.free_shock("Zap", 2)]))
	for bear: int in 4:
		_cast("Bear")
		_resolve()
	# Narrow enough that the last Bear is out of sight at the right end of its line.
	_screen.size = Vector2(1100, 1080)
	_screen.line("hero_creatures").scroll_to(0.0)
	assert_true(_screen.line("hero_creatures").right_arrow().visible)
	var bears: Array[int] = _permanents("Bear")

	_cast("Zap")
	_target(bears[3])
	_resolve()
	assert_null(_screen.face_of(bears[3]))
	assert_null(_screen.ghost_of(bears[3]), "It was past the end of its line.")

	_cast("Zap")
	_target(bears[0])
	_resolve()
	assert_not_null(_screen.ghost_of(bears[0]), "One that could be seen does.")


func test_scrolling_a_line_is_not_a_move() -> void:
	_open(_setup_of([_bear()]))
	for bear: int in 5:
		_cast("Bear")
		_resolve()
	_screen.size = Vector2(1100, 1080)
	var first: int = _permanents("Bear")[0]
	var before: Vector2 = _middle(_screen.face_of(first))

	_screen.line("hero_creatures").scroll_by(50.0)

	assert_almost_eq(_middle(_screen.face_of(first)), before - Vector2(50, 0), NEAR)
	assert_almost_eq(_screen.face_motion().rest_of(first).center, before - Vector2(50, 0), NEAR, "Face Motion was told at once.")
	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)
	assert_false(_screen.face_motion().is_moving())
	assert_almost_eq(_middle(_screen.face_of(first)), before - Vector2(50, 0), NEAR)


func test_a_block_line_follows_its_blocker_into_the_lane() -> void:
	_open_combat([_bear()])
	_reach_blockers(2)
	_settle()
	var bear: int = _permanents("Bear")[1]
	var lines: BlockLines = _screen.block_lines()

	_click(bear)
	_click(_permanents("Ogre")[0])

	var start: Vector2 = lines.line_from(0)
	assert_almost_eq(start.x, _middle(_screen.face_of(bear)).x, 0.5)
	_advance(MOVE / 2.0)
	var midway: Vector2 = lines.line_from(0)
	_advance(MOVE / 2.0)
	var end: Vector2 = lines.line_from(0)
	var full: float = _screen.face_of(bear).size.y
	var grown: float = full * (1.0 - EncounterLayout.BYSTANDER_SCALE) / 2.0
	assert_almost_eq(start.y - end.y, EncounterLayout.COMBAT_STEP + grown, 0.5,
			"It steps into the lane and grows from a bystander's size: the line starts at its top as it is drawn.")
	assert_almost_eq(midway.y, (start.y + end.y) / 2.0, 0.5, "Half-way at half-time.")
	assert_almost_eq(end.y, _screen.face_of(bear).get_global_rect().position.y - _screen.global_position.y - EncounterLayout.BLOCK_LINE_GAP, 0.5)


func test_a_line_to_a_blocker_that_has_left_is_dropped_at_once() -> void:
	_open_combat([_bear(), Scenario.free_shock("Zap", 2)])
	_cast_creatures(1)
	for attempt: int in 12:
		_pass_until(func() -> bool: return _presenter.snapshot().decision is DeclareAttackersDecision)
		if _permanents("Ogre").size() >= 2 and _permanents("Ogre").all(func(ogre: int) -> bool: return not _seen(ogre).is_tapped):
			break
		_presenter.answer([] as Array[int])
		_presenter.wait_until_idle()
	_presenter.answer((_presenter.snapshot().decision as DeclareAttackersDecision).candidate_ids.duplicate())
	_presenter.wait_until_idle()
	_pass_until(func() -> bool: return _presenter.snapshot().view.step == MmTurn.Step.DECLARE_BLOCKERS)
	_settle()
	var ogres: Array[int] = _permanents("Ogre")
	assert_eq(_screen.block_lines().line_count(), 2, "Both Ogres block the Bear.")

	_cast("Zap")
	_target(ogres[0])
	_resolve()

	assert_not_null(_screen.ghost_of(ogres[0]))
	assert_eq(_screen.block_lines().line_count(), 1, "A367: no line runs to a ghost.")


func test_marked_damage_shows_on_the_creature_until_it_wears_off() -> void:
	_open(_setup_of([_bear(), Scenario.free_shock("Zap", 1)]))
	_cast("Bear")
	_resolve()
	var bear: int = _permanents("Bear")[0]
	assert_null((_screen.face_of(bear) as BattlefieldFace).damage_chip())

	_cast("Zap")
	_target(bear)
	_resolve()

	assert_eq(_presenter.snapshot().look_of(bear).damage_marked, 1)
	assert_eq((_screen.face_of(bear) as BattlefieldFace).damage_chip().amount, 1)
	var turn: int = _presenter.snapshot().view.game_turn
	_pass_until(func() -> bool: return _presenter.snapshot().view.game_turn > turn)
	assert_null((_screen.face_of(bear) as BattlefieldFace).damage_chip(), "Damage wears off at cleanup.")


## Opens a screen whose faces take MOVE seconds to move, with the Hero in their first main
## phase, auto-pass off.
func _open(setup: MmEncounterSetup, agent: MmAgent = DefaultAnswerAgent.new()) -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	# Not at the corner of the window, so a place worked out from the wrong corner shows.
	_screen.position = Vector2(30, 20)
	_screen.face_motion().seconds = MOVE
	_presenter = EncounterPresenter.new(setup, agent)
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	_pass_until(func() -> bool:
		return _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN and _presenter.snapshot().view.active_player_id == HERO)


## The Hero's deck cycles through [param cards]; the Villain, who fights, has free Ogres.
func _open_combat(cards: Array[MmCardDefinition]) -> void:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	var ogre: MmCardDefinition = Scenario.creature("Ogre", 2, 2, [], Scenario.mana_cost(0))
	_open(Scenario.setup_with(deck, Scenario.copies(ogre, 40)), CombatAgent.new())


## The Hero's deck alternates Forests and free 2/2 Bears.
func _bears() -> MmEncounterSetup:
	return _setup_of([Scenario.basic_land("Forest"), _bear()])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))


func _setup_of(cards: Array[MmCardDefinition]) -> MmEncounterSetup:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	return Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40))


## Lets [param seconds] of Face Motion go by in short frames, and a hair more.
func _advance(seconds: float) -> void:
	var frames: int = ceili(seconds / 0.01)
	for frame: int in frames:
		_screen.advance_motion(seconds / frames)
	_screen.advance_motion(0.000001)


## Lets every move finish.
func _settle() -> void:
	_advance(MOVE * 1.5)


## Where the middle of [param face] is drawn, in the screen's coordinates.
func _middle(face: Control) -> Vector2:
	return face.get_global_transform() * (face.size / 2.0) - _screen.global_position


func _cast(card_name: String) -> void:
	_act(CastSpellAction, card_name)


func _play(card_name: String) -> void:
	_act(PlayLandAction, card_name)


func _act(kind: Script, card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if is_instance_of(action, kind) and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("No %s action for %s." % [kind.resource_path.get_file(), card_name])


## Aims the spell being cast at Game Object [param object_id].
func _target(object_id: int) -> void:
	var target: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	for index: int in target.candidates.size():
		if target.candidates[index].is_object() and target.candidates[index].id == object_id:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("Nothing can target %d." % object_id)


## Passes until the stack is empty.
func _resolve() -> void:
	for attempt: int in 10:
		if _presenter.snapshot().view.stack.is_empty():
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


func _click(object_id: int) -> void:
	_screen.click_catcher(object_id).clicked.emit()


func _seen(object_id: int) -> MmObjectView:
	for seen: MmObjectView in _presenter.snapshot().visible_objects():
		if seen.id == object_id:
			return seen
	return null


func _permanents(card_name: String) -> Array[int]:
	var found: Array[int] = []
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			found.append(permanent.id)
	return found


func _cast_creatures(count: int) -> void:
	for cast: int in count:
		_cast("Bear")
		_resolve()


## The Hero has [param count] creatures and is asked which of them attack.
func _reach_attackers(count: int) -> void:
	_cast_creatures(count)
	_pass_until(func() -> bool:
		var attackers: DeclareAttackersDecision = _presenter.snapshot().decision as DeclareAttackersDecision
		return attackers != null and attackers.candidate_ids.size() == count)


## The Hero has [param count] creatures and is asked how they block the Villain's Ogres.
func _reach_blockers(count: int) -> void:
	_cast_creatures(count)
	_pass_until(func() -> bool:
		var blocks: DeclareBlockersDecision = _presenter.snapshot().decision as DeclareBlockersDecision
		return blocks != null and blocks.candidate_blocker_ids.size() == count)


## Passes, declaring no attackers or blockers, until [param is_there] says to stop.
func _pass_until(is_there: Callable) -> void:
	for attempt: int in 200:
		if is_there.call():
			return
		var decision: MmPendingDecision = _presenter.snapshot().decision
		if decision is PriorityDecision:
			_presenter.pass_priority()
		elif decision is ChooseCardsToDiscardDecision:
			var discard: ChooseCardsToDiscardDecision = decision as ChooseCardsToDiscardDecision
			_presenter.answer(discard.candidate_ids.slice(0, discard.count))
		elif decision is DivideCombatDamageDecision:
			_presenter.answer(CombatSelection.default_split(decision as DivideCombatDamageDecision))
		else:
			_presenter.answer([])
		_presenter.wait_until_idle()
	fail_test("Never got there.")
