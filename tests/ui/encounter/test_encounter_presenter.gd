extends GutTest
## The Encounter Presenter owns the engine: it runs the Villain's Agent on a worker thread,
## takes the Hero's answers, and hands the screen a snapshot after every change (ADR 0021).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SlowAgent := preload("res://tests/ui/encounter/support/slow_agent.gd")
const RespondingAgent := preload("res://tests/ui/encounter/support/responding_agent.gd")
const Rule := MmEncounterSetup.StartingPlayerRule
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID

var _snapshots: Array[EncounterSnapshot] = []


func before_each() -> void:
	_snapshots.clear()


func test_starting_does_not_block_and_the_villain_thinks_on_a_worker_thread() -> void:
	var agent: MmAgent = SlowAgent.new()
	var presenter: EncounterPresenter = EncounterPresenter.new(Scenario.setup(Rule.VILLAIN_CHOOSES), agent)
	var began: int = Time.get_ticks_msec()

	presenter.start()

	assert_lt(Time.get_ticks_msec() - began, 150, "start() returns while the Villain is still thinking.")
	assert_true(presenter.is_villain_thinking())
	assert_true(presenter.snapshot().is_villain_thinking)
	assert_null(presenter.snapshot().decision, "The Hero is not being asked anything yet.")
	presenter.wait_until_idle()
	assert_ne(agent.get("thread_id"), OS.get_main_thread_id(), "The Agent answered off the main thread.")
	assert_false(presenter.is_villain_thinking())
	assert_false(presenter.snapshot().is_villain_thinking)
	assert_not_null(presenter.snapshot().decision)


func test_the_screen_is_told_after_every_villain_answer() -> void:
	var agent: MmAgent = DefaultAnswerAgent.new()
	var presenter: EncounterPresenter = EncounterPresenter.new(Scenario.setup(Rule.VILLAIN_CHOOSES), agent)
	presenter.changed.connect(_remember)

	presenter.start()
	presenter.wait_until_idle()

	var thinking: int = 0
	for snapshot: EncounterSnapshot in _snapshots:
		if snapshot.is_villain_thinking:
			thinking += 1
	assert_eq(thinking, agent.get("answers_given"), "One snapshot as each Villain decision begins (A238).")
	assert_gt(thinking, 0)


func test_commands_are_refused_while_the_villain_is_thinking() -> void:
	var presenter: EncounterPresenter = EncounterPresenter.new(Scenario.setup(Rule.VILLAIN_CHOOSES), SlowAgent.new())
	presenter.start()
	var during: EncounterSnapshot = presenter.snapshot()

	assert_eq(presenter.answer(0), EncounterPresenter.BUSY)
	assert_eq(presenter.pass_priority(), EncounterPresenter.BUSY)
	assert_eq(presenter.undo(), EncounterPresenter.BUSY)
	assert_eq(presenter.cancel_cast(), EncounterPresenter.BUSY)
	presenter.set_auto_passing(false)
	presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	assert_eq(presenter.snapshot(), during, "Nothing read the engine or made a new snapshot mid-thought.")
	presenter.wait_until_idle()


func test_the_first_snapshot_is_the_heros_view_and_decision() -> void:
	var presenter: EncounterPresenter = _started(Scenario.setup())

	var snapshot: EncounterSnapshot = presenter.snapshot()

	assert_eq(snapshot.view.viewer_id, HERO)
	assert_eq(snapshot.view.hand.size(), 7)
	assert_true(snapshot.decision is KeepOrMulliganDecision)
	assert_eq(snapshot.decision.player_id, HERO)
	assert_false(snapshot.is_over())
	assert_false(snapshot.is_draw())


func test_a_rejected_answer_gives_its_reason_and_changes_nothing() -> void:
	var presenter: EncounterPresenter = _started(Scenario.setup())
	var before: EncounterSnapshot = presenter.snapshot()

	var reason: String = presenter.answer(99)

	assert_ne(reason, "")
	assert_eq(presenter.snapshot(), before)
	assert_true(presenter.snapshot().decision is KeepOrMulliganDecision)


func test_every_card_the_hero_sees_has_a_look_with_its_own_art() -> void:
	var presenter: EncounterPresenter = _started(_request(7).setup())

	var snapshot: EncounterSnapshot = presenter.snapshot()

	assert_eq(snapshot.looks.size(), snapshot.view.hand.size())
	for card: MmObjectView in snapshot.view.hand:
		var look: CardLook = snapshot.look_of(card.id)
		var definition: MmCardDefinition = load("res://content/cards/alpha/%s.tres" % look.art_key) as MmCardDefinition
		assert_not_null(definition, "The art key names a Card Definition's file.")
		assert_eq(definition.name, card.name)
		assert_eq(look.name, card.name)
	assert_null(snapshot.look_of(-5))


func test_a_card_the_hero_cannot_see_never_reaches_the_screen() -> void:
	var setup: MmEncounterSetup = _request(7).setup()
	var presenter: EncounterPresenter = _started(setup)
	# The same seed deals the same cards, so a second engine says what is hidden.
	var twin: MmEngine = MmEngine.start(setup)
	if twin.pending_decision() is ChoosePlayOrDrawDecision:
		twin.submit(ChoosePlayOrDrawDecision.Choice.PLAY)
	var hidden: Array[int] = Scenario.card_ids(twin.villain().hand)
	hidden.append_array(Scenario.card_ids(twin.villain().library))
	hidden.append_array(Scenario.card_ids(twin.hero().library))

	var snapshot: EncounterSnapshot = presenter.snapshot()

	assert_gt(hidden.size(), 60)
	for seen: MmObjectView in snapshot.visible_objects():
		assert_false(hidden.has(seen.card_id), "%s is hidden from the Hero." % seen.name)
	assert_eq(snapshot.view.hand_sizes[VILLAIN], 7, "A hidden zone is only a count.")


func test_a_spell_on_the_stack_has_a_look() -> void:
	var presenter: EncounterPresenter = _started(_shock_setup(), false)
	presenter.is_hold_key_down = true
	_cast_first_spell_at_the_villain(presenter)

	var spell: MmObjectView = presenter.snapshot().view.stack[0]

	assert_not_null(presenter.snapshot().look_of(spell.id), "Something on the stack has a look too.")
	assert_eq(presenter.snapshot().look_of(spell.id).name, "Zap")


func test_an_ability_on_the_stack_takes_its_sources_art() -> void:
	# Howling Mine: "At the beginning of each player's draw step, ... that player draws an
	# additional card." Its trigger is not a card, so its art is the Mine's.
	var cards: Array[MmCardDefinition] = []
	for index: int in 20:
		cards.append(load("res://content/cards/alpha/forest.tres") as MmCardDefinition)
		cards.append(load("res://content/cards/alpha/howling_mine.tres") as MmCardDefinition)
	var presenter: EncounterPresenter = _started(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)), false)
	presenter.is_hold_key_down = true
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()
	var ability: MmObjectView = null
	for attempt: int in 300:
		var snapshot: EncounterSnapshot = presenter.snapshot()
		if not snapshot.view.stack.is_empty() and snapshot.view.stack.back().card_id == MmGameObject.NO_CARD:
			ability = snapshot.view.stack.back()
			break
		if snapshot.decision is PayManaDecision:
			presenter.answer(0)
		elif _index_of(snapshot.decision as PriorityDecision, PlayLandAction) != -1:
			presenter.answer(_index_of(snapshot.decision as PriorityDecision, PlayLandAction))
		elif snapshot.view.stack.is_empty() and _index_of(snapshot.decision as PriorityDecision, CastSpellAction) != -1:
			presenter.answer(_index_of(snapshot.decision as PriorityDecision, CastSpellAction))
		else:
			presenter.pass_priority()
		presenter.wait_until_idle()

	assert_not_null(ability, "A Howling Mine trigger reached the stack.")
	if ability != null:
		assert_eq(presenter.snapshot().look_of(ability.id).art_key, "howling_mine")


func test_undo_takes_back_an_answer_and_hands_out_no_events() -> void:
	var presenter: EncounterPresenter = _started(_land_setup(), false)
	_pass_until_a_land_can_be_played(presenter)
	assert_eq(presenter.answer(_index_of(presenter.snapshot().decision as PriorityDecision, PlayLandAction)), "")
	assert_eq(presenter.snapshot().view.battlefield.size(), 1)
	assert_true(presenter.snapshot().can_undo)

	assert_eq(presenter.undo(), "")

	assert_eq(presenter.snapshot().view.battlefield.size(), 0)
	assert_eq(presenter.snapshot().view.hand.size(), 7)
	assert_eq(presenter.snapshot().events.size(), 0, "ADR 0015: a rewind is never animated.")

	assert_eq(presenter.answer(_index_of(presenter.snapshot().decision as PriorityDecision, PlayLandAction)), "")
	assert_eq(presenter.snapshot().events.size(), 1, "What happens after an undo is handed out as usual.")


func test_undo_is_refused_with_a_reason_when_nothing_can_be_undone() -> void:
	var presenter: EncounterPresenter = _started(Scenario.setup())
	var before: EncounterSnapshot = presenter.snapshot()

	assert_false(before.can_undo)
	assert_ne(presenter.undo(), "")
	assert_eq(presenter.snapshot(), before)


func test_canceling_a_cast_puts_the_card_back_and_is_refused_when_nothing_is_being_cast() -> void:
	var presenter: EncounterPresenter = _started(_shock_setup(), false)
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()
	assert_ne(presenter.cancel_cast(), "", "Nothing is being cast yet.")
	assert_eq(presenter.answer(_index_of(presenter.snapshot().decision as PriorityDecision, CastSpellAction)), "")
	assert_true(presenter.snapshot().decision is ChooseTargetDecision)
	assert_eq(presenter.snapshot().view.hand.size(), 6)

	assert_eq(presenter.cancel_cast(), "")

	assert_true(presenter.snapshot().decision is PriorityDecision)
	assert_eq(presenter.snapshot().view.hand.size(), 7)
	assert_eq(presenter.snapshot().view.stack.size(), 0)
	assert_eq(presenter.snapshot().events.size(), 0)


func test_conceding_ends_the_encounter_and_cannot_be_done_twice() -> void:
	var presenter: EncounterPresenter = _started(Scenario.setup())

	assert_eq(presenter.concede(), "")

	var snapshot: EncounterSnapshot = presenter.snapshot()
	assert_true(snapshot.is_over())
	assert_eq(snapshot.view.winner_id, VILLAIN)
	assert_false(snapshot.is_draw())
	assert_null(snapshot.decision)
	assert_eq(snapshot.view.loss_reasons[HERO], MmPlayer.LossReason.CONCEDED)
	assert_false(snapshot.can_undo)
	assert_ne(presenter.concede(), "")
	assert_eq(presenter.answer(0), EncounterPresenter.NOT_PRIORITY)
	assert_eq(presenter.pass_priority(), EncounterPresenter.NOT_PRIORITY)


func test_conceding_while_the_villain_thinks_waits_for_that_thought_and_plays_nothing_more() -> void:
	var agent: SlowAgent = SlowAgent.new()
	var presenter: EncounterPresenter = EncounterPresenter.new(Scenario.setup(Rule.VILLAIN_CHOOSES), agent)
	presenter.start()
	assert_true(presenter.is_villain_thinking())

	assert_eq(presenter.concede(), "")

	assert_false(presenter.is_villain_thinking(), "No second thought was begun.")
	assert_true(presenter.snapshot().is_over())
	assert_eq(presenter.snapshot().view.winner_id, VILLAIN)
	assert_ne(agent.thread_id, -1, "The thought it was in the middle of finished first.")


func test_while_paused_nothing_is_collected_from_the_villain_until_it_resumes() -> void:
	var agent: SlowAgent = SlowAgent.new()
	agent.delay_msec = 50
	var presenter: EncounterPresenter = EncounterPresenter.new(Scenario.setup(Rule.VILLAIN_CHOOSES), agent)
	presenter.start()
	var during: EncounterSnapshot = presenter.snapshot()

	presenter.set_paused(true)
	OS.delay_msec(200)
	presenter.poll()

	assert_true(presenter.is_paused())
	assert_eq(presenter.snapshot(), during, "The thought finished, but the screen was told nothing.")
	assert_true(presenter.is_villain_thinking())

	presenter.set_paused(false)
	presenter.poll()

	assert_ne(presenter.snapshot(), during, "Resuming carries on from where it was.")
	presenter.wait_until_idle()


func test_the_heros_answers_are_refused_while_paused_but_conceding_is_not() -> void:
	var presenter: EncounterPresenter = _started(_land_setup(), false)
	var before: EncounterSnapshot = presenter.snapshot()
	presenter.set_paused(true)

	assert_eq(presenter.answer(KeepOrMulliganDecision.Choice.KEEP), EncounterPresenter.PAUSED)
	assert_eq(presenter.pass_priority(), EncounterPresenter.PAUSED)
	assert_eq(presenter.undo(), EncounterPresenter.PAUSED)
	assert_eq(presenter.cancel_cast(), EncounterPresenter.PAUSED)
	assert_eq(presenter.snapshot(), before)

	assert_eq(presenter.concede(), "")
	assert_true(presenter.snapshot().is_over())


func test_each_snapshot_carries_exactly_the_events_since_the_one_before() -> void:
	var presenter: EncounterPresenter = EncounterPresenter.new(_land_setup(), DefaultAnswerAgent.new())
	presenter.set_auto_passing(false)
	presenter.changed.connect(_remember)
	presenter.start()
	presenter.wait_until_idle()
	_pass_until_a_land_can_be_played(presenter)
	var before: int = _snapshots.size()

	assert_eq(presenter.answer(_index_of(presenter.snapshot().decision as PriorityDecision, PlayLandAction)), "")

	var played: Array[MmEvent] = presenter.snapshot().events
	assert_eq(_snapshots.size(), before + 1)
	assert_eq(played.size(), 1, "Playing a land is one event.")
	assert_true(played[0] is ZoneChangeEvent)
	var seen: Dictionary[MmEvent, bool] = {}
	var total: int = 0
	for snapshot: EncounterSnapshot in _snapshots:
		for event: MmEvent in snapshot.events:
			assert_false(seen.has(event), "No event is handed out twice.")
			seen[event] = true
			total += 1
	assert_gt(_snapshots[0].events.size(), 0, "The first snapshot has the opening hands being drawn.")
	assert_gt(total, played.size())


func test_auto_pass_carries_on_to_the_next_stop_with_something_to_do() -> void:
	# Lands only: the Hero can play one in a main phase, and otherwise only tap for mana.
	var presenter: EncounterPresenter = _started(_land_setup())

	assert_eq(presenter.answer(KeepOrMulliganDecision.Choice.KEEP), "")
	presenter.wait_until_idle()

	var view: MmPlayerView = presenter.snapshot().view
	assert_true(presenter.is_auto_passing(), "On unless turned off.")
	assert_eq(view.step, MmTurn.Step.PRECOMBAT_MAIN, "Upkeep had no stop.")
	assert_eq(view.game_turn, 1)
	assert_true(presenter.snapshot().decision is PriorityDecision)


func test_auto_pass_goes_through_whole_turns_when_only_mana_abilities_are_left() -> void:
	var presenter: EncounterPresenter = _started(_land_setup())
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()

	assert_eq(presenter.answer(_index_of(presenter.snapshot().decision as PriorityDecision, PlayLandAction)), "")
	presenter.wait_until_idle()

	var view: MmPlayerView = presenter.snapshot().view
	assert_eq(view.game_turn, 3, "The rest of this turn and the Villain's went by.")
	assert_eq(view.active_player_id, HERO)
	assert_eq(view.step, MmTurn.Step.PRECOMBAT_MAIN)


func test_clearing_the_stop_the_hero_is_waiting_at_lets_auto_pass_carry_on() -> void:
	var presenter: EncounterPresenter = _started(_land_setup())
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()

	presenter.toggle_stop(HERO, MmTurn.Step.PRECOMBAT_MAIN)
	presenter.wait_until_idle()

	assert_eq(presenter.snapshot().view.step, MmTurn.Step.POSTCOMBAT_MAIN, "The next stop with a land to play.")
	assert_eq(presenter.snapshot().view.game_turn, 1)


func test_with_auto_pass_off_the_hero_is_asked_at_every_step() -> void:
	var presenter: EncounterPresenter = _started(_land_setup(), false)

	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()

	assert_false(presenter.is_auto_passing())
	assert_eq(presenter.snapshot().view.step, MmTurn.Step.UPKEEP)


func test_turning_auto_pass_on_passes_at_once() -> void:
	var presenter: EncounterPresenter = _started(_land_setup(), false)
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()

	presenter.set_auto_passing(true)
	presenter.wait_until_idle()

	assert_eq(presenter.snapshot().view.step, MmTurn.Step.PRECOMBAT_MAIN)


func test_the_heros_own_spell_on_the_stack_is_passed_for_them() -> void:
	var presenter: EncounterPresenter = _started(_shock_setup(), false)

	_cast_first_spell_at_the_villain(presenter)
	presenter.wait_until_idle()

	var snapshot: EncounterSnapshot = presenter.snapshot()
	assert_eq(snapshot.view.stack.size(), 0, "It resolved without the Hero being asked again.")
	assert_eq(snapshot.view.life_totals[VILLAIN], 18)
	assert_false(snapshot.is_holding_priority)
	assert_true(snapshot.decision is PriorityDecision)


func test_holding_the_key_as_a_spell_goes_on_the_stack_keeps_priority() -> void:
	var presenter: EncounterPresenter = _started(_shock_setup(), false)
	presenter.is_hold_key_down = true

	_cast_first_spell_at_the_villain(presenter)

	var snapshot: EncounterSnapshot = presenter.snapshot()
	assert_true(snapshot.is_holding_priority)
	assert_eq(snapshot.view.stack.size(), 1)
	assert_true(snapshot.decision is PriorityDecision)
	assert_eq(snapshot.view.life_totals[VILLAIN], 20)


func test_letting_go_of_the_key_afterwards_does_not_pass() -> void:
	var presenter: EncounterPresenter = _started(_shock_setup(), false)
	presenter.is_hold_key_down = true
	_cast_first_spell_at_the_villain(presenter)

	presenter.is_hold_key_down = false
	presenter.set_auto_passing(true)
	presenter.wait_until_idle()

	assert_true(presenter.snapshot().is_holding_priority, "Even auto-pass leaves a held spell alone.")
	assert_eq(presenter.snapshot().view.stack.size(), 1)

	assert_eq(presenter.pass_priority(), "")
	presenter.wait_until_idle()
	assert_false(presenter.snapshot().is_holding_priority, "The Hero's next answer ends the hold.")
	assert_eq(presenter.snapshot().view.life_totals[VILLAIN], 18)


func test_a_second_spell_cast_without_the_key_is_passed_while_the_first_was_held() -> void:
	var presenter: EncounterPresenter = _started(_shock_setup(), false)
	presenter.is_hold_key_down = true
	_cast_first_spell_at_the_villain(presenter)
	presenter.is_hold_key_down = false

	_cast_first_spell_at_the_villain(presenter)
	presenter.wait_until_idle()

	assert_eq(presenter.snapshot().view.life_totals[VILLAIN], 16, "Both resolved: the hold is decided for each spell.")
	assert_eq(presenter.snapshot().view.stack.size(), 0)


func test_the_hold_is_decided_again_when_the_heros_spell_is_back_on_top() -> void:
	# The Villain answers the Hero's Zap with one of its own. Once that has resolved, the
	# Hero's Zap is on top again, and with the key up it is passed for them as before.
	var zap: Array[MmCardDefinition] = Scenario.copies(Scenario.free_shock("Zap", 2), 40)
	var presenter: EncounterPresenter = EncounterPresenter.new(Scenario.setup_with(zap, zap.duplicate()), RespondingAgent.new())
	presenter.set_auto_passing(false)
	presenter.start()
	presenter.wait_until_idle()

	_cast_first_spell_at_the_villain(presenter)
	presenter.wait_until_idle()
	assert_eq(presenter.snapshot().view.stack.size(), 2, "The Villain's answer is on top, so the Hero is asked.")
	assert_eq(presenter.snapshot().view.stack.back().controller_id, VILLAIN)

	assert_eq(presenter.pass_priority(), "")
	presenter.wait_until_idle()

	assert_eq(presenter.snapshot().view.stack.size(), 0, "Both resolved without the Hero being asked about their own.")
	assert_eq(presenter.snapshot().view.life_totals[VILLAIN], 18)


func test_an_encounter_asked_for_by_arguments_is_the_one_the_form_starts() -> void:
	var from_arguments: EncounterRequest = EncounterRequest.from_arguments(
		PackedStringArray(["--hero=blue_red", "--villain=red_green", "--seed=11"]))
	var from_form: EncounterRequest = EncounterRequest.new()
	from_form.hero_deck = "blue_red"
	from_form.villain_deck = "red_green"
	from_form.encounter_seed = 11
	var other_seed: EncounterRequest = EncounterRequest.new()
	other_seed.hero_deck = "blue_red"
	other_seed.villain_deck = "red_green"
	other_seed.encounter_seed = 12

	var first: Array[String] = _hand_names(_started(from_arguments.setup()))
	var second: Array[String] = _hand_names(_started(from_form.setup()))

	assert_eq(first, second)
	assert_ne(first, _hand_names(_started(other_seed.setup())), "Another seed deals another hand.")


func test_a_whole_encounter_can_be_played_through_the_clicks_and_the_panels_forms() -> void:
	# An Easy AI decides for the Hero on a twin engine kept in step, and every answer it
	# gives is put through what the Hero would use for it before it is submitted: a click
	# on a permanent, a player or a mana button, the pass button, or the panel's form.
	var request: EncounterRequest = _request(3)
	var presenter: EncounterPresenter = EncounterPresenter.new(request.setup(), request.villain_agent())
	presenter.set_auto_passing(false)
	presenter.is_hold_key_down = true
	presenter.start()
	presenter.wait_until_idle()
	var twin: MmEngine = MmEngine.start(request.setup())
	var twin_driver: MmEncounterDriver = MmEncounterDriver.new(twin, {VILLAIN: request.villain_agent()} as Dictionary[int, MmAgent])
	var hero: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
	var kinds: Dictionary[DebugDecisionForm.Kind, bool] = {}
	var clicked: Dictionary[Script, bool] = {}
	var answers: int = 0

	while not presenter.snapshot().is_over() and answers < 3000:
		twin_driver.run()
		var decision: MmPendingDecision = presenter.snapshot().decision
		if decision.describe() != twin.pending_decision().describe():
			fail_test("The twin fell out of step at answer %d: %s" % [answers, decision.describe()])
			break
		var wanted: Variant = hero.answer(twin.pending_decision(), null, twin.simulation_source_for(HERO))
		var form: DebugDecisionForm = DebugDecisionForm.of(decision, presenter.snapshot().view)
		var through: Variant = _click(decision, presenter.snapshot().view, wanted)
		if through != null:
			clicked[decision.get_script()] = true
		elif form != null:
			kinds[form.kind] = true
			through = _fill_in(form, wanted)
		var error: String = presenter.answer(through)
		if error != "":
			fail_test("The answer %s to %s was rejected: %s" % [through, decision.describe(), error])
			break
		# A click on a mana button spends the first unit of that color, which may be another
		# unit than the AI named, so the twin is given what was really answered.
		twin.submit(through)
		presenter.wait_until_idle()
		answers += 1

	twin_driver.run()
	assert_true(presenter.snapshot().is_over(), "The encounter reached its end.")
	assert_eq(presenter.snapshot().view.winner_id, twin.game_state().winner_id)
	assert_true(kinds.has(DebugDecisionForm.Kind.PICK_ONE))
	assert_true(kinds.has(DebugDecisionForm.Kind.PICK_SOME), "Attackers were declared through the form.")
	assert_true(clicked.has(PayManaDecision), "Mana was paid by clicking.")
	assert_true(clicked.has(ChooseTargetDecision), "Targets were clicked.")
	assert_true(clicked.has(PriorityDecision), "A permanent was clicked at priority, or the pass button pressed.")


## The answer the Hero's own input gives for [param wanted], or null when the decision, or
## that choice of it, is still answered in the panel.
func _click(decision: MmPendingDecision, view: MmPlayerView, wanted: Variant) -> Variant:
	var clicks: DecisionClicks = DecisionClicks.of(decision, view)
	if decision is PriorityDecision:
		var action: MmAction = (decision as PriorityDecision).actions[wanted]
		if action is PassAction:
			return AutoPass.pass_index(decision as PriorityDecision)
		return _option_answering(clicks, DecisionClicks.object_of(action), wanted) if action is ActivateAbilityAction else null
	if decision is PayManaDecision:
		var action: MmAction = (decision as PayManaDecision).actions[wanted]
		if action is PayWithManaAction:
			var pool: Array = view.mana_pools[HERO]
			return clicks.pool_answers[(pool[(action as PayWithManaAction).unit_index] as MmMana).type]
		return _option_answering(clicks, DecisionClicks.object_of(action), wanted)
	if decision is ChooseTargetDecision:
		var candidate: MmReference = (decision as ChooseTargetDecision).candidates[wanted]
		if candidate.is_player():
			return clicks.player_answers[candidate.id]
		return _option_answering(clicks, candidate.id, wanted)
	return null


func _option_answering(clicks: DecisionClicks, object_id: int, wanted: int) -> Variant:
	for option: ClickOption in clicks.options_of(object_id):
		if option.answer == wanted:
			return option.answer
	fail_test("Clicking object %d does not offer answer %d." % [object_id, wanted])
	return null


## What [param form] gives when it is filled in to say [param wanted].
func _fill_in(form: DebugDecisionForm, wanted: Variant) -> Variant:
	match form.kind:
		DebugDecisionForm.Kind.PICK_ONE:
			for option: int in form.options.size():
				if form.answer_for_pick(option) == wanted:
					return form.answer_for_pick(option)
			return null
		DebugDecisionForm.Kind.PICK_SOME:
			var picks: Array[int] = []
			var ids: Array = wanted
			for id: int in ids:
				picks.append(form.option_object_ids.find(id))
			return form.answer_for_picks(picks)
		DebugDecisionForm.Kind.ORDER:
			var order: Array[int] = []
			var places: Array = wanted
			for place: int in places:
				order.append(place)
			return form.answer_for_picks(order)
		DebugDecisionForm.Kind.PAIR_UP:
			var by_option: Array = []
			for option: int in form.options.size():
				by_option.append([])
			var pairs: Array = wanted
			for pair: Array in pairs:
				by_option[form.option_object_ids.find(pair[0])].append(pair[1])
			return form.answer_for_pairs(by_option)
	var shares: Array[int] = []
	var amounts: Array = wanted
	for share: int in amounts:
		shares.append(share)
	return form.answer_for_split(shares)


func _remember(snapshot: EncounterSnapshot) -> void:
	_snapshots.append(snapshot)


## A presenter that has started and is waiting for the Hero, with the opening hands dealt.
func _started(setup: MmEncounterSetup, is_auto_passing: bool = true) -> EncounterPresenter:
	var presenter: EncounterPresenter = EncounterPresenter.new(setup, DefaultAnswerAgent.new())
	presenter.set_auto_passing(is_auto_passing)
	presenter.start()
	presenter.wait_until_idle()
	if presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		# A coin flip let the Hero choose, which comes before the hands are drawn.
		presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		presenter.wait_until_idle()
	return presenter


func _request(encounter_seed: int) -> EncounterRequest:
	var request: EncounterRequest = EncounterRequest.new()
	request.encounter_seed = encounter_seed
	return request


## Both decks are forty basic lands.
func _land_setup() -> MmEncounterSetup:
	var forest: MmCardDefinition = Scenario.basic_land("Forest")
	return Scenario.setup_with(Scenario.copies(forest, 40), Scenario.copies(forest, 40))


## The Hero's deck is forty free instants, "Zap": 2 damage to any target.
func _shock_setup() -> MmEncounterSetup:
	return Scenario.setup_with(Scenario.copies(Scenario.free_shock("Zap", 2), 40), Scenario.copies(Scenario.vanilla("Card"), 40))


func _index_of(decision: PriorityDecision, action_kind: Script) -> int:
	for index: int in decision.actions.size():
		if is_instance_of(decision.actions[index], action_kind):
			return index
	return -1


func _pass_until_a_land_can_be_played(presenter: EncounterPresenter) -> void:
	if presenter.snapshot().decision is KeepOrMulliganDecision:
		presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
		presenter.wait_until_idle()
	for attempt: int in 20:
		if _index_of(presenter.snapshot().decision as PriorityDecision, PlayLandAction) != -1:
			return
		presenter.pass_priority()
		presenter.wait_until_idle()


## Keeps if still to keep, then casts the first spell offered, aimed at the Villain.
func _cast_first_spell_at_the_villain(presenter: EncounterPresenter) -> void:
	if presenter.snapshot().decision is KeepOrMulliganDecision:
		presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
		presenter.wait_until_idle()
	assert_eq(presenter.answer(_index_of(presenter.snapshot().decision as PriorityDecision, CastSpellAction)), "")
	var target: ChooseTargetDecision = presenter.snapshot().decision as ChooseTargetDecision
	for index: int in target.candidates.size():
		if target.candidates[index].is_player() and target.candidates[index].id == VILLAIN:
			assert_eq(presenter.answer(index), "")
			return


func _hand_names(presenter: EncounterPresenter) -> Array[String]:
	var names: Array[String] = []
	for card: MmObjectView in presenter.snapshot().view.hand:
		names.append(card.name)
	return names
