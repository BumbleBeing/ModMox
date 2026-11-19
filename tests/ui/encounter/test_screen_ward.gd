extends GutTest
## Ward on the Encounter Screen (ADR 0062). The Hero's Zap (an instant costing {0}, 2 damage
## to any target) is aimed at the Villain's Warden (a 2/2 with ward {2}); as the ward
## trigger resolves, the Info Panel reads "Pay ward for Warden:" with the cost after it and a
## "No" button, the Pass Button reads "Pay" and no key presses it, and the Zap's Stack Window
## entry carries the ward's dashed Stack Mark. Paying reads the same line, with what is left,
## and has no Cancel. The Hero's Mana Bird taps for {W}{W}{W}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const CombatAgent := preload("res://tests/ui/encounter/support/combat_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_the_info_panel_asks_to_pay_ward_with_the_cost_after_it_and_offers_no() -> void:
	_open_asked()

	assert_eq(_screen.info_panel().prompt_text(), "Pay ward for Warden:")
	assert_eq(_screen.info_panel().owed_pip_names(), ["2"] as Array[String])
	assert_lt(_screen.info_panel().first_pip_position().y, 40.0, "On the prompt's line, not under it.")
	assert_gt(_screen.info_panel().first_pip_position().x, 100.0, "After the words.")
	assert_eq(_screen.info_panel().no_button().text, "No")
	assert_null(_screen.info_panel().cancel_button())
	assert_eq(_screen.pass_button().text, "Pay", "No key pays.")
	assert_false(_screen.pass_button().disabled)


func test_the_pass_key_does_not_pay() -> void:
	_open_asked()
	var asked: MmPendingDecision = _presenter.snapshot().decision

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().decision, asked, "Still asked: only a click pays.")


func test_the_spell_it_would_counter_carries_its_dashed_stack_mark() -> void:
	_open_asked()

	var entry: StackEntry = _screen.stack_entry_of(_zap_id())
	assert_not_null(entry)
	assert_not_null(BorderEffects.mark_color(entry), "Marked without the cursor on the Stack Window.")
	assert_true(BorderEffects.is_mark_dashed(entry))


func test_pay_asks_for_the_cost_on_the_same_line_with_no_cancel_and_the_spell_resolves() -> void:
	_open_asked()
	var zap: int = _zap_id()

	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().decision is PayManaDecision, "Paid by hand: Auto-tap is off in a test.")
	assert_eq(_screen.info_panel().prompt_text(), "Pay ward for Warden:")
	assert_eq(_screen.info_panel().owed_pip_names(), ["2"] as Array[String])
	assert_null(_screen.info_panel().cancel_button(), "Nothing is being cast.")
	assert_eq(_presenter.answer(_bird_answer()), "")
	_presenter.wait_until_idle()
	assert_false(_stack_ids().has(zap), "Ward resolved, and the Hero's own Zap, on top again, was passed for them.")
	assert_null(_warden(), "The Zap resolved and the Warden died.")


func test_auto_tap_pays_the_ward_cost() -> void:
	_open_asked()
	var zap: int = _zap_id()
	_presenter.set_auto_tapping(true)

	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is PayManaDecision)
	assert_false(_stack_ids().has(zap))
	assert_null(_warden(), "Paid, so the Zap resolved.")


func test_undo_after_pay_asks_again() -> void:
	_open_asked()
	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()
	assert_true(_presenter.snapshot().decision is PayManaDecision)

	assert_eq(_presenter.undo(), "")
	_presenter.wait_until_idle()

	var asked: ChooseYesOrNoDecision = _presenter.snapshot().decision as ChooseYesOrNoDecision
	assert_not_null(asked)
	assert_not_null(asked.cost)


func test_no_counters_the_spell() -> void:
	_open_asked()
	var zap: int = _zap_id()

	_screen.info_panel().no_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_false(_stack_ids().has(zap))
	assert_not_null(_warden(), "The Zap was countered.")


func _zap_id() -> int:
	return _stack_ids().front()


## The stack, bottom first.
func _stack_ids() -> Array[int]:
	var ids: Array[int] = []
	for item: MmObjectView in _presenter.snapshot().view.stack:
		ids.append(item.id)
	return ids


func _warden() -> MmObjectView:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == "Warden":
			return permanent
	return null


## The answer that taps the Mana Bird for the ward cost.
func _bird_answer() -> int:
	var paying: PayManaDecision = _presenter.snapshot().decision as PayManaDecision
	for index: int in paying.actions.size():
		if paying.actions[index] is ActivateAbilityAction:
			return index
	return -1


## Opens the screen, casts the Hero's Mana Bird on Game Turn 1 while the Villain casts its
## Warden on Game Turn 2, then in the Hero's main phase of Game Turn 3 aims Zap at the
## Warden and passes until the ward cost is asked.
func _open_asked() -> void:
	var hero_deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.mana_bird(), Scenario.free_shock("Zap", 2),
		Scenario.basic_land("Plains")])
	var villain_deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.warden(), Scenario.basic_land("Forest")])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(hero_deck, villain_deck,
			MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		var hero_hand: Array = Scenario.names(engine, engine.hero().hand)
		if hero_hand.has("Mana Bird") and hero_hand.has("Zap") and Scenario.names(engine, engine.villain().hand).has("Warden"):
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	var villain: CombatAgent = CombatAgent.new()
	villain.casts_left = 1
	_presenter = EncounterPresenter.new(chosen, villain)
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	_answer_pregame()
	_play_to(1)
	_cast("Mana Bird")
	_play_to(3)
	_cast("Zap")
	for attempt: int in 20:
		var decision: MmPendingDecision = _presenter.snapshot().decision
		var asked: ChooseYesOrNoDecision = decision as ChooseYesOrNoDecision
		if asked != null and asked.cost != null:
			return
		var target: ChooseTargetDecision = decision as ChooseTargetDecision
		if target != null:
			assert_eq(_presenter.answer(_index_of_warden(target)), "")
		else:
			_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("The ward cost was never asked.")


func _answer_pregame() -> void:
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()


## Passes, declaring no attackers or blockers, until the Hero has priority with an empty
## stack in the main phase of Game Turn [param game_turn].
func _play_to(game_turn: int) -> void:
	for attempt: int in 200:
		var snapshot: EncounterSnapshot = _presenter.snapshot()
		var decision: MmPendingDecision = snapshot.decision
		if decision is PriorityDecision and snapshot.view.game_turn == game_turn \
				and snapshot.view.step == MmTurn.Step.PRECOMBAT_MAIN and snapshot.view.stack.is_empty():
			return
		if decision is DeclareAttackersDecision or decision is DeclareBlockersDecision:
			assert_eq(_presenter.answer([]), "")
		else:
			_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("Game Turn %d's main phase was never reached." % game_turn)


## Casts the Hero's card named [param card_name] from their hand.
func _cast(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("%s could not be cast." % card_name)


func _index_of_warden(target: ChooseTargetDecision) -> int:
	var view: MmPlayerView = _presenter.snapshot().view
	for index: int in target.candidates.size():
		var candidate: MmReference = target.candidates[index]
		if candidate.is_object() and EncounterSnapshot.name_in(view, candidate.id) == "Warden":
			return index
	return 0
