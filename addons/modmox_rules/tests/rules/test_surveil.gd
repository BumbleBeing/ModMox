extends GutTest
## "Surveil N" (CR 701.25a, ADR 0068): look at the top N cards of your library, then put any
## number of them into your graveyard and the rest on top of your library in any order.
## One decision as the effect begins, answered with the cards graveyarded and the order of
## the rest; the cards kept on top are Known Cards to their owner.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")

## The setup _hero_surveilling() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_surveil_names_the_top_cards_of_its_controllers_library_top_first() -> void:
	var engine: MmEngine = _hero_surveilling(2)

	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision

	assert_not_null(asked)
	assert_eq(asked.player_id, engine.hero().id)
	assert_eq(asked.card_ids, engine.hero().library.object_ids().slice(0, 2))


func test_a_card_graveyarded_goes_to_its_owners_graveyard() -> void:
	var engine: MmEngine = _hero_surveilling(1)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	var top_card: int = engine.game_state().object(asked.card_ids[0]).card_id
	var library_before: int = engine.hero().library.size()

	assert_eq(engine.submit([[asked.card_ids[0]], []]), "")

	assert_eq(engine.hero().library.size(), library_before - 1)
	assert_eq(_graveyard_card_ids(engine).back(), top_card, "The newest card in the graveyard.")


func test_a_card_kept_stays_on_top_and_is_known_to_its_owner_alone() -> void:
	var engine: MmEngine = _hero_surveilling(1)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	var top_id: int = asked.card_ids[0]

	assert_eq(engine.submit([[], [top_id]]), "")

	assert_eq(engine.hero().library.top().id, top_id, "Not a zone change: the same object.")
	assert_true(engine.game_state().object(top_id).is_known_to(engine.hero().id))
	assert_false(engine.game_state().object(top_id).is_known_to(engine.villain().id))


func test_the_cards_kept_go_back_on_top_in_the_order_given() -> void:
	var engine: MmEngine = _hero_surveilling(2)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	var first: int = asked.card_ids[0]
	var second: int = asked.card_ids[1]

	assert_eq(engine.submit([[], [second, first]]), "")

	assert_eq(engine.hero().library.object_ids().slice(0, 2), [second, first], "CR 701.25a: in any order.")


func test_some_may_be_graveyarded_and_the_rest_kept() -> void:
	var engine: MmEngine = _hero_surveilling(3)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	var cards: Array[int] = asked.card_ids
	var graveyarded: Array[int] = [engine.game_state().object(cards[2]).card_id, engine.game_state().object(cards[0]).card_id]
	var library_before: int = engine.hero().library.size()

	assert_eq(engine.submit([[cards[2], cards[0]], [cards[1]]]), "")

	assert_eq(engine.hero().library.size(), library_before - 2)
	assert_eq(engine.hero().library.top().id, cards[1])
	assert_eq(_graveyard_card_ids(engine).slice(-2), graveyarded, "In the order given: the last is the newest.")


func test_the_cards_graveyarded_move_together_as_a_surveil() -> void:
	var engine: MmEngine = _hero_surveilling(2)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	var log_before: int = engine.game_state().event_log.size()

	assert_eq(engine.submit([asked.card_ids.duplicate(), []]), "")

	var batches: Array[int] = []
	for index: int in range(log_before, engine.game_state().event_log.size()):
		var moved: ZoneChangeEvent = engine.game_state().event_log[index] as ZoneChangeEvent
		if moved != null and moved.reason == ZoneChangeEvent.Reason.SURVEIL:
			batches.append(moved.batch)
	assert_eq(batches.size(), 2)
	assert_eq(batches[0], batches[1], "CR 701.25a: one action, one batch.")


func test_a_library_smaller_than_the_amount_shows_every_card_in_it() -> void:
	var engine: MmEngine = _hero_surveilling(60)

	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision

	assert_eq(asked.card_ids, engine.hero().library.object_ids())


func test_an_empty_library_asks_nothing() -> void:
	var thespian: MmCardDefinition = Scenario.thespian()
	var deck: Array[MmCardDefinition] = Scenario.copies(thespian, 7)
	var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([]))
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		return Scenario.ready_in_main(running, 1, 0, "Thespian"))
	assert_not_null(engine)
	assert_eq(engine.hero().library.size(), 0)

	assert_eq(Scenario.cast_and_resolve(engine, "Thespian"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_false(engine.pending_decision() is SurveilDecision)
	assert_eq(engine.game_state().stack.size(), 0, "The trigger resolved and did nothing.")


func test_an_answer_must_place_every_card_once_and_nothing_else() -> void:
	var engine: MmEngine = _hero_surveilling(2)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	var first: int = asked.card_ids[0]
	var second: int = asked.card_ids[1]
	var other: int = engine.hero().library.object_ids()[2]

	assert_ne(engine.submit([[first], []]), "", "The second card is placed nowhere.")
	assert_ne(engine.submit([[first], [first, second]]), "", "The first card is placed twice.")
	assert_ne(engine.submit([[], [first, second, other]]), "", "Only the cards looked at.")
	assert_ne(engine.submit([first, second]), "", "Two lists.")
	assert_ne(engine.submit(1), "")
	assert_true(engine.pending_decision() is SurveilDecision, "Nothing changed.")
	assert_eq(engine.submit([[second], [first]]), "")


func test_while_surveilling_only_the_surveilling_player_sees_the_cards() -> void:
	var engine: MmEngine = _hero_surveilling(2)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision

	var hero_sees: Array = engine.view_for(engine.hero()).libraries[engine.hero().id]
	var villain_sees: Array = engine.view_for(engine.villain()).libraries[engine.hero().id]

	assert_eq(_seen_ids(hero_sees), asked.card_ids, "The top two, and nothing under them.")
	assert_eq(_seen_ids(villain_sees).size(), 0)


func test_after_surveilling_the_owner_still_sees_the_cards_kept_and_the_other_player_does_not() -> void:
	var engine: MmEngine = _hero_surveilling(2)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision

	assert_eq(engine.submit([[asked.card_ids[0]], [asked.card_ids[1]]]), "")

	assert_eq(_seen_ids(engine.view_for(engine.hero()).libraries[engine.hero().id]), [asked.card_ids[1]] as Array[int])
	assert_eq(_seen_ids(engine.view_for(engine.villain()).libraries[engine.hero().id]).size(), 0)


func test_a_shuffle_forgets_the_cards_kept() -> void:
	var engine: MmEngine = _hero_surveilling(1)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	assert_eq(engine.submit([[], [asked.card_ids[0]]]), "")

	engine.game_state().perform(ShuffleEvent.new(engine.hero().library))

	assert_eq(_seen_ids(engine.view_for(engine.hero()).libraries[engine.hero().id]).size(), 0)


func test_asking_the_surveil_is_an_undo_barrier() -> void:
	var engine: MmEngine = _hero_surveilling(1)

	assert_false(engine.can_undo(), "ADR 0015: the player has seen the cards.")


func test_a_simulation_copy_made_while_surveilling_keeps_the_cards_looked_at() -> void:
	var engine: MmEngine = _hero_surveilling(2)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	var looked_at: Array[int] = _card_ids_of(engine, asked.card_ids)

	for rng_seed: int in [1, 2, 3, 4, 5]:
		var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(rng_seed))
		assert_eq(_card_ids_of(copy, asked.card_ids), looked_at, "Not re-dealt while the decision names them.")
		assert_eq(copy.submit([[asked.card_ids[0]], [asked.card_ids[1]]]), "")


func test_a_simulation_copy_after_surveilling_keeps_the_cards_kept_on_top() -> void:
	var engine: MmEngine = _hero_surveilling(2)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	assert_eq(engine.submit([[], [asked.card_ids[1], asked.card_ids[0]]]), "")
	var kept: Array[int] = _card_ids_of(engine, engine.hero().library.object_ids().slice(0, 2))

	for rng_seed: int in [1, 2, 3, 4, 5]:
		var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(rng_seed))
		assert_eq(_card_ids_of(copy, copy.hero().library.object_ids().slice(0, 2)), kept)


func test_a_replay_of_a_surveil_gives_the_same_game() -> void:
	var engine: MmEngine = _hero_surveilling(3)
	var asked: SurveilDecision = engine.pending_decision() as SurveilDecision
	assert_eq(engine.submit([[asked.card_ids[1]], [asked.card_ids[2], asked.card_ids[0]]]), "")

	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_enters_or_dies_surveils_both_times() -> void:
	var engine: MmEngine = _hero_surveilling(1, true)
	assert_eq(engine.submit(Scenario.default_answer(engine.pending_decision())), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var thespian: int = Scenario.permanent_named(engine, engine.hero().id, "Thespian")

	assert_eq(Scenario.cast_and_resolve(engine, "Kill", [MmReference.to_object(thespian)]), "")
	assert_eq(Scenario.pass_to_surveil(engine), "")

	assert_true(engine.pending_decision() is SurveilDecision, "When this creature dies, surveil 1.")


## The Hero in their first main phase, having cast a Thespian ("When this creature enters
## or dies, surveil [param amount].") for {0}, its trigger resolving and the surveil asked.
## With [param with_kill], they hold a free "Destroy target creature." too.
func _hero_surveilling(amount: int, with_kill: bool = false) -> MmEngine:
	var cards: Array[MmCardDefinition] = [Scenario.thespian("Thespian", amount), Scenario.basic_land("Forest"),
		Scenario.creature("Bear", 2, 2), Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])]
	if with_kill:
		cards.append(Scenario.free_destroy("Kill"))
	_setup = Scenario.setup_with(Scenario.cycled(cards), Scenario.cycled([]))
	var engine: MmEngine = Scenario.find_engine(_setup, func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 1, 0, "Thespian"):
			return false
		return not with_kill or Scenario.card_in_hand(running, running.hero(), "Kill") != -1)
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(Scenario.cast_and_resolve(engine, "Thespian"), "")
	assert_eq(Scenario.pass_to_surveil(engine), "")
	return engine


func _graveyard_card_ids(engine: MmEngine) -> Array[int]:
	var ids: Array[int] = []
	for card: MmGameObject in engine.hero().graveyard.objects():
		ids.append(card.card_id)
	return ids


func _card_ids_of(engine: MmEngine, object_ids: Array[int]) -> Array[int]:
	var ids: Array[int] = []
	for id: int in object_ids:
		ids.append(engine.game_state().object(id).card_id)
	return ids


func _seen_ids(library: Array) -> Array[int]:
	var ids: Array[int] = []
	for seen: Variant in library:
		if seen != null:
			ids.append((seen as MmObjectView).id)
	return ids
