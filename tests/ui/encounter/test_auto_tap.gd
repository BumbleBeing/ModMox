extends GutTest
## Auto-tap (ADR 0031): the Encounter Presenter pays the Hero's mana costs, choosing sources
## as the Villain's Agent does, a tap at a time, and says beforehand what each cast would tap.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SlowAgent := preload("res://tests/ui/encounter/support/slow_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const MANA: int = 270

var _now: int = 0
var _snapshots: Array[EncounterSnapshot] = []


func before_each() -> void:
	_now = 1000
	_snapshots.clear()


func test_a_presenter_pays_nothing_until_auto_tap_is_turned_on() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(2), 2, false)

	assert_false(presenter.is_auto_tapping())
	assert_null(presenter.payment_plan(_cast(presenter)), "Nothing is planned for a Hero who pays by hand.")
	presenter.answer(_cast(presenter))

	assert_true(presenter.snapshot().decision is PayManaDecision, "The Hero pays as before.")
	assert_null(presenter.snapshot().paying)


func test_a_spell_is_paid_for_without_asking_the_hero() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(2), 2)
	presenter.changed.connect(_remember)

	assert_eq(presenter.answer(_cast(presenter)), "")
	presenter.wait_until_idle()

	for snapshot: EncounterSnapshot in _snapshots:
		assert_false(snapshot.decision is PayManaDecision, "The Hero is never asked to pay.")
	assert_eq(_tapped(presenter).size(), 2)
	assert_eq(_names_on_battlefield(presenter).count("Bear"), 1, "The spell was cast, and resolved.")


func test_mana_tapped_by_hand_beforehand_is_spent_first() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(2), 3)
	var priority: PriorityDecision = presenter.snapshot().decision as PriorityDecision
	var land: int = _untapped_lands(presenter)[0]
	presenter.answer(Scenario.activate_index(priority, land))
	var plan: PaymentPlan = presenter.payment_plan(_cast(presenter))
	assert_eq(plan.pool_types, [MmMana.Type.GREEN] as Array[MmMana.Type], "The plan spends what is in the pool.")
	assert_eq(plan.source_ids.size(), 1)

	presenter.answer(_cast(presenter))
	presenter.wait_until_idle()

	assert_eq(_tapped(presenter).size(), 2, "One more land, not two.")
	assert_true((presenter.snapshot().view.mana_pools.get(HERO, []) as Array).is_empty())


func test_generic_mana_comes_from_the_land_whose_color_the_hand_needs_least() -> void:
	var elf: MmCardDefinition = Scenario.creature("Elf", 1, 1, [], Scenario.mana_cost(0, [MmMana.Type.GREEN]))
	var scout: MmCardDefinition = Scenario.creature("Scout", 1, 1, [], Scenario.mana_cost(1))
	var cards: Array[MmCardDefinition] = []
	for index: int in 10:
		cards.append_array([Scenario.basic_land("Forest"), Scenario.basic_land("Mountain"), scout, elf])
	var presenter: EncounterPresenter = _started(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)))
	_play_until(presenter, func(snapshot: EncounterSnapshot) -> bool:
		var names: Array[String] = _names_on_battlefield(presenter)
		return names.has("Forest") and names.has("Mountain") and _cast_named(snapshot, "Scout") != -1 \
				and _hand_names(snapshot).has("Elf") and _tapped(presenter).is_empty())

	presenter.answer(_cast_named(presenter.snapshot(), "Scout"))
	presenter.wait_until_idle()

	var tapped: Array[String] = []
	for permanent: MmObjectView in presenter.snapshot().view.battlefield:
		if permanent.is_tapped:
			tapped.append(permanent.name)
	assert_eq(tapped, ["Mountain"] as Array[String], "The Elf in hand still needs green.")


func test_with_the_hold_key_down_as_the_cast_reaches_payment_the_hero_pays_all_of_it() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(2), 2)
	presenter.is_hold_key_down = true

	presenter.answer(_cast(presenter))
	assert_true(presenter.snapshot().decision is PayManaDecision, "Paid by hand.")
	presenter.is_hold_key_down = false
	presenter.answer(0)

	assert_true(presenter.snapshot().decision is PayManaDecision, "Letting go partway does not finish it.")
	assert_eq(_tapped(presenter).size(), 1)


func test_turning_auto_tap_on_partway_leaves_that_payment_to_the_hero() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(1), 2, false)
	presenter.answer(_cast(presenter))
	assert_true(presenter.snapshot().decision is PayManaDecision)

	presenter.set_auto_tapping(true)

	assert_true(presenter.snapshot().decision is PayManaDecision, "The payment under way stays by hand.")
	assert_eq(_tapped(presenter).size(), 0)
	presenter.answer(0)
	presenter.wait_until_idle()
	_play_until(presenter, func(snapshot: EncounterSnapshot) -> bool: return _cast(presenter) != -1)
	var before: int = _tapped(presenter).size()
	presenter.answer(_cast(presenter))
	assert_false(presenter.snapshot().decision is PayManaDecision, "The next cast pays itself.")
	assert_eq(_tapped(presenter).size(), before + 1)


func test_a_targeted_spell_asks_for_its_target_and_then_pays_itself() -> void:
	var zap: MmCardDefinition = Scenario.instant("Zap", Scenario.mana_cost(1), [Scenario.any_target()],
			[Scenario.deal_damage(2, Scenario.targeted(0))])
	var presenter: EncounterPresenter = _ready_to_cast(_land_and(zap), 1)

	presenter.answer(_cast(presenter))
	assert_true(presenter.snapshot().decision is ChooseTargetDecision)
	assert_eq(_tapped(presenter).size(), 0, "Nothing is tapped before the target is chosen.")
	presenter.answer(0)

	assert_false(presenter.snapshot().decision is PayManaDecision)
	assert_eq(_tapped(presenter).size(), 1)


func test_an_ability_with_a_mana_cost_pays_itself() -> void:
	var troll: MmCardDefinition = Scenario.creature("Troll", 2, 2, [Scenario.regenerate_ability(Scenario.mana_cost(1))])
	var presenter: EncounterPresenter = _ready_to_cast(_land_and(troll), 1)
	presenter.answer(_cast(presenter))
	presenter.wait_until_idle()
	_play_until(presenter, func(snapshot: EncounterSnapshot) -> bool:
		return _ability(snapshot) != -1 and not _untapped_lands(presenter).is_empty() and _tapped(presenter).is_empty())
	var ability: int = _ability(presenter.snapshot())
	assert_eq(presenter.payment_plan(ability).source_ids.size(), 1, "An ability has a plan as a spell has.")

	presenter.answer(ability)

	assert_false(presenter.snapshot().decision is PayManaDecision)
	assert_eq(_tapped(presenter).size(), 1)


func test_each_tap_is_shown_for_the_mana_wait_and_the_last_one_casts() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(3), 3)
	presenter.clock = _clock
	presenter.mana_wait_msec = MANA

	assert_eq(presenter.answer(_cast(presenter)), "")

	var first: EncounterSnapshot = presenter.snapshot()
	assert_eq(_tapped(presenter).size(), 1, "The first tap is made at once.")
	assert_true(presenter.is_paying_for_hero())
	assert_null(first.decision, "The Hero is asked nothing meanwhile.")
	assert_eq(first.paying.remaining_generic, 2, "What is still owed is handed over for the Info Panel.")
	assert_eq(first.payment_left.source_ids.size(), 2, "And what is still to be tapped.")
	assert_false(first.can_undo)
	assert_eq(presenter.answer(0), EncounterPresenter.PAYING)
	assert_eq(presenter.pass_priority(), EncounterPresenter.PAYING)
	assert_eq(presenter.undo(), EncounterPresenter.PAYING)
	_now += MANA - 1
	presenter.poll()
	assert_eq(presenter.snapshot(), first, "A millisecond short, the next tap is still held back.")
	_now += 1
	presenter.poll()
	assert_eq(_tapped(presenter).size(), 2)
	assert_eq(presenter.snapshot().payment_left.source_ids.size(), 1)
	_now += MANA
	presenter.poll()

	assert_eq(_tapped(presenter).size(), 3)
	assert_false(presenter.is_paying_for_hero(), "The last tap casts the spell, with no wait after it.")
	assert_null(presenter.snapshot().paying)
	presenter.wait_until_idle()
	assert_eq(_names_on_battlefield(presenter).count("Bear"), 1)


func test_a_presenter_that_is_not_paced_pays_everything_at_once() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(3), 3)
	presenter.clock = _clock

	presenter.answer(_cast(presenter))

	assert_false(presenter.is_paying_for_hero())
	assert_eq(_tapped(presenter).size(), 3)


func test_nothing_is_tapped_while_the_game_is_paused() -> void:
	var presenter: EncounterPresenter = _paying(3)
	var shown: EncounterSnapshot = presenter.snapshot()

	presenter.set_paused(true)
	_now += MANA * 3
	presenter.poll()
	assert_eq(presenter.snapshot(), shown)
	presenter.set_auto_passing(false)
	assert_eq(presenter.snapshot(), shown, "A setting changed under the Pause Menu taps nothing early.")
	presenter.set_paused(false)
	presenter.poll()

	assert_eq(_tapped(presenter).size(), 2, "Time spent paused counted toward the wait.")


func test_changing_a_setting_partway_does_not_hurry_the_next_tap() -> void:
	var presenter: EncounterPresenter = _paying(3)
	var shown: EncounterSnapshot = presenter.snapshot()

	presenter.set_auto_passing(true)
	presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)
	presenter.set_auto_tapping(false)

	assert_eq(presenter.snapshot(), shown, "Each tap still waits its turn.")
	_now += MANA
	presenter.poll()
	assert_eq(_tapped(presenter).size(), 2, "And the payment under way is still the game's to finish.")


func test_waiting_until_idle_finishes_a_payment_without_sitting_through_it() -> void:
	var presenter: EncounterPresenter = _paying(3)

	presenter.wait_until_idle()

	assert_false(presenter.is_paying_for_hero())
	assert_eq(_names_on_battlefield(presenter).count("Bear"), 1)


func test_canceling_partway_takes_the_whole_cast_back() -> void:
	var presenter: EncounterPresenter = _paying(3)
	var hand: int = presenter.snapshot().view.hand.size()

	assert_eq(presenter.cancel_cast(), "")

	assert_false(presenter.is_paying_for_hero())
	assert_true(presenter.snapshot().decision is PriorityDecision)
	assert_eq(presenter.snapshot().view.hand.size(), hand + 1, "The card is back in hand.")
	assert_eq(_tapped(presenter).size(), 0, "And the land is untapped.")
	_now += MANA
	presenter.poll()
	assert_eq(_tapped(presenter).size(), 0, "Nothing more is tapped for a cast that was canceled.")


func test_a_payment_that_undo_leads_back_to_is_left_to_the_hero() -> void:
	var presenter: EncounterPresenter = _paying(2)
	# Held from here on, so the Hero keeps priority once their spell is cast and can undo.
	presenter.is_hold_key_down = true
	_now += MANA
	presenter.poll()
	assert_true(presenter.snapshot().decision is PriorityDecision, "Cast, and the priority held.")
	presenter.is_hold_key_down = false

	assert_eq(presenter.undo(), "")

	assert_true(presenter.snapshot().decision is PayManaDecision, "The last tap is taken back, and is the Hero's to make.")
	assert_false(presenter.is_paying_for_hero())
	assert_eq(_tapped(presenter).size(), 1)
	presenter.answer(0)
	assert_eq(_tapped(presenter).size(), 2)


func test_the_plan_for_a_cast_is_exactly_what_it_then_taps() -> void:
	var casts: int = 0
	for encounter_seed: int in [3, 7, 11]:
		var request: EncounterRequest = EncounterRequest.new()
		request.encounter_seed = encounter_seed
		for deck: String in ["red_green", "blue_red"]:
			request.hero_deck = deck
			var presenter: EncounterPresenter = EncounterPresenter.new(request.setup(), DefaultAnswerAgent.new())
			presenter.set_auto_passing(false)
			presenter.set_auto_tapping(true)
			presenter.start()
			presenter.wait_until_idle()
			for step: int in 400:
				var snapshot: EncounterSnapshot = presenter.snapshot()
				if snapshot.is_over() or snapshot.view.game_turn > 14:
					break
				var planned_casts: Array[int] = _planned_answers(presenter)
				if planned_casts.is_empty() or not snapshot.view.stack.is_empty():
					presenter.answer(Scenario.default_answer(snapshot.decision, true))
					presenter.wait_until_idle()
					continue
				var cast: int = planned_casts[casts % planned_casts.size()]
				var planned: Array[int] = presenter.payment_plan(cast).source_ids.duplicate()
				var before: Array[int] = _tapped(presenter)
				presenter.answer(cast)
				if presenter.snapshot().decision is ChooseTargetDecision:
					presenter.answer(0)
				var tapped: Array[int] = []
				for id: int in _tapped(presenter):
					if not before.has(id):
						tapped.append(id)
				planned.sort()
				tapped.sort()
				assert_eq(tapped, planned, "%s, seed %d, turn %d" % [deck, encounter_seed, snapshot.view.game_turn])
				assert_false(planned.is_empty())
				casts += 1
				presenter.wait_until_idle()
	assert_gt(casts, 20, "Enough was cast to mean something.")


func test_nothing_is_planned_for_a_land_or_for_what_costs_no_mana() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(0), 1)
	var priority: PriorityDecision = presenter.snapshot().decision as PriorityDecision

	assert_ne(_cast(presenter), -1)
	assert_gt(priority.actions.size(), 2, "Passing, a land's mana and a spell at the least.")
	assert_true(_planned_answers(presenter).is_empty(), "A free spell has no plan, and nor has passing or a mana ability.")
	assert_null(presenter.payment_plan(-1))
	assert_null(presenter.payment_plan(priority.actions.size()), "Nor has an answer that is not one.")


func test_a_plan_is_kept_until_the_next_snapshot_and_none_is_made_while_the_villain_thinks() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(2), 2)
	var cast: int = _cast(presenter)

	var plan: PaymentPlan = presenter.payment_plan(cast)

	assert_same(presenter.payment_plan(cast), plan, "Asking again costs nothing.")
	presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)
	assert_not_same(presenter.payment_plan(cast), plan, "A new snapshot, a new plan.")
	assert_eq(presenter.payment_plan(cast).source_ids, plan.source_ids)
	var slow: EncounterPresenter = EncounterPresenter.new(
			Scenario.setup(MmEncounterSetup.StartingPlayerRule.VILLAIN_CHOOSES), SlowAgent.new())
	slow.set_auto_tapping(true)
	slow.start()
	assert_true(slow.is_villain_thinking())
	assert_null(slow.payment_plan(0), "The engine is the worker's.")
	slow.wait_until_idle()


func test_turning_auto_tap_on_and_off_at_priority_brings_and_takes_away_the_plans() -> void:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(2), 2, false)
	assert_null(presenter.payment_plan(_cast(presenter)))

	presenter.set_auto_tapping(true)
	assert_eq(presenter.payment_plan(_cast(presenter)).source_ids.size(), 2)

	presenter.set_auto_tapping(false)
	assert_null(presenter.payment_plan(_cast(presenter)))


func _clock() -> int:
	return _now


func _remember(snapshot: EncounterSnapshot) -> void:
	_snapshots.append(snapshot)


## The Hero's deck alternates Forests and 2/2 Bears costing [param generic].
func _bear_setup(generic: int) -> MmEncounterSetup:
	return _land_and(Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(generic)))


## The Hero's deck alternates Forests and [param card]; the Villain's cards do nothing.
func _land_and(card: MmCardDefinition) -> MmEncounterSetup:
	var cards: Array[MmCardDefinition] = []
	for index: int in 20:
		cards.append_array([Scenario.basic_land("Forest"), card])
	return Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40))


## A presenter that has started, with the Hero asked at every priority.
func _started(setup: MmEncounterSetup, is_auto_tapping: bool = true) -> EncounterPresenter:
	var presenter: EncounterPresenter = EncounterPresenter.new(setup, DefaultAnswerAgent.new())
	presenter.set_auto_passing(false)
	presenter.set_auto_tapping(is_auto_tapping)
	presenter.start()
	presenter.wait_until_idle()
	return presenter


## A presenter whose Hero has priority with at least [param lands] lands, all untapped, an
## empty stack and a spell to cast.
func _ready_to_cast(setup: MmEncounterSetup, lands: int, is_auto_tapping: bool = true) -> EncounterPresenter:
	var presenter: EncounterPresenter = _started(setup, is_auto_tapping)
	_play_until(presenter, func(snapshot: EncounterSnapshot) -> bool:
		return _untapped_lands(presenter).size() >= lands and _tapped(presenter).is_empty() and _cast(presenter) != -1 \
				and snapshot.view.stack.is_empty())
	return presenter


## A paced presenter one tap into paying for a Bear that costs [param generic].
func _paying(generic: int) -> EncounterPresenter:
	var presenter: EncounterPresenter = _ready_to_cast(_bear_setup(generic), generic)
	presenter.clock = _clock
	presenter.mana_wait_msec = MANA
	presenter.answer(_cast(presenter))
	assert_true(presenter.is_paying_for_hero())
	assert_eq(_tapped(presenter).size(), 1)
	return presenter


## The Hero plays a land when they can and otherwise passes, until [param is_there].
func _play_until(presenter: EncounterPresenter, is_there: Callable) -> void:
	for step: int in 600:
		var snapshot: EncounterSnapshot = presenter.snapshot()
		if snapshot.decision is PriorityDecision and is_there.call(snapshot):
			return
		if snapshot.is_over():
			break
		presenter.answer(Scenario.default_answer(snapshot.decision, true))
		presenter.wait_until_idle()
	fail_test("The game never got there.")


## Every answer to the Hero's priority that has a plan.
func _planned_answers(presenter: EncounterPresenter) -> Array[int]:
	var answers: Array[int] = []
	var priority: PriorityDecision = presenter.snapshot().decision as PriorityDecision
	if priority != null:
		for answer: int in priority.actions.size():
			if presenter.payment_plan(answer) != null:
				answers.append(answer)
	return answers


## The answer that casts the first spell offered, or -1.
func _cast(presenter: EncounterPresenter) -> int:
	var priority: PriorityDecision = presenter.snapshot().decision as PriorityDecision
	if priority == null:
		return -1
	return Scenario.action_index(priority, func(action: MmAction) -> bool: return action is CastSpellAction)


func _cast_named(snapshot: EncounterSnapshot, card_name: String) -> int:
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	if priority == null:
		return -1
	return Scenario.action_index(priority, func(action: MmAction) -> bool:
		return action is CastSpellAction and EncounterSnapshot.name_in(snapshot.view, (action as CastSpellAction).object_id) == card_name)


## The answer that activates the first ability offered that is not a mana ability, or -1.
func _ability(snapshot: EncounterSnapshot) -> int:
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	if priority == null:
		return -1
	return Scenario.action_index(priority, func(action: MmAction) -> bool:
		return action is ActivateAbilityAction and not AutoPass.is_mana_ability(action, snapshot.view))


func _tapped(presenter: EncounterPresenter) -> Array[int]:
	var ids: Array[int] = []
	for permanent: MmObjectView in presenter.snapshot().view.battlefield:
		if permanent.is_tapped and permanent.controller_id == HERO:
			ids.append(permanent.id)
	return ids


func _untapped_lands(presenter: EncounterPresenter) -> Array[int]:
	var ids: Array[int] = []
	for permanent: MmObjectView in presenter.snapshot().view.battlefield:
		if not permanent.is_tapped and permanent.controller_id == HERO and permanent.card_types.has(MmCardTypes.CardType.LAND):
			ids.append(permanent.id)
	return ids


func _names_on_battlefield(presenter: EncounterPresenter) -> Array[String]:
	var names: Array[String] = []
	for permanent: MmObjectView in presenter.snapshot().view.battlefield:
		if permanent.controller_id == HERO:
			names.append(permanent.name)
	return names


func _hand_names(snapshot: EncounterSnapshot) -> Array[String]:
	var names: Array[String] = []
	for card: MmObjectView in snapshot.view.hand:
		names.append(card.name)
	return names
