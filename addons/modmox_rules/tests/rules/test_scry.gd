extends GutTest
## "Scry N" (CR 701.22a, ADR 0087): look at the top N cards of your library, then put any
## number of them on the bottom of your library in any order and the rest on top in any
## order. One decision as the effect begins, a ScryDecision, answered as a surveil's is with
## the cards put on the bottom, the last sent the deepest, and the order of the rest. No card
## leaves the library, and every card it looked at is a Known Card to its owner.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")

## The setup _hero_scrying() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_scry_names_the_top_cards_of_its_controllers_library_top_first() -> void:
	var engine: MmEngine = _hero_scrying(2)

	var asked: ScryDecision = engine.pending_decision() as ScryDecision

	assert_not_null(asked)
	assert_eq(asked.player_id, engine.hero().id)
	assert_eq(asked.card_ids, engine.hero().library.object_ids().slice(0, 2))


func test_a_card_put_on_the_bottom_goes_under_every_other_card_and_stays_the_same_object() -> void:
	var engine: MmEngine = _hero_scrying(1)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision
	var top_id: int = asked.card_ids[0]
	var library_before: int = engine.hero().library.size()

	assert_eq(engine.submit([[top_id], []]), "")

	assert_eq(engine.hero().library.size(), library_before, "It never left the library.")
	assert_eq(engine.hero().library.objects().back().id, top_id, "Not a zone change: the same object, at the bottom.")
	assert_true(engine.game_state().object(top_id).is_known_to(engine.hero().id))
	assert_false(engine.game_state().object(top_id).is_known_to(engine.villain().id))


func test_a_card_kept_stays_on_top_and_is_known_to_its_owner_alone() -> void:
	var engine: MmEngine = _hero_scrying(1)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision
	var top_id: int = asked.card_ids[0]

	assert_eq(engine.submit([[], [top_id]]), "")

	assert_eq(engine.hero().library.top().id, top_id)
	assert_true(engine.game_state().object(top_id).is_known_to(engine.hero().id))
	assert_false(engine.game_state().object(top_id).is_known_to(engine.villain().id))


func test_the_cards_kept_go_back_on_top_in_the_order_given() -> void:
	var engine: MmEngine = _hero_scrying(2)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision
	var first: int = asked.card_ids[0]
	var second: int = asked.card_ids[1]

	assert_eq(engine.submit([[], [second, first]]), "")

	assert_eq(engine.hero().library.object_ids().slice(0, 2), [second, first], "CR 701.22a: in any order.")


func test_the_last_card_put_on_the_bottom_is_the_deepest() -> void:
	var engine: MmEngine = _hero_scrying(3)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision
	var cards: Array[int] = asked.card_ids

	assert_eq(engine.submit([[cards[2], cards[0]], [cards[1]]]), "")

	assert_eq(engine.hero().library.top().id, cards[1])
	assert_eq(engine.hero().library.object_ids().slice(-2), [cards[2], cards[0]], "Each sent under everything.")


func test_the_cards_kept_and_put_on_the_bottom_are_placed_in_one_batch() -> void:
	var engine: MmEngine = _hero_scrying(2)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision
	var log_before: int = engine.game_state().event_log.size()

	assert_eq(engine.submit([[asked.card_ids[0]], [asked.card_ids[1]]]), "")

	var batches: Array[int] = []
	for index: int in range(log_before, engine.game_state().event_log.size()):
		var event: MmEvent = engine.game_state().event_log[index]
		if event is LibraryTopOrderedEvent or event is LibraryBottomOrderedEvent:
			batches.append(event.batch)
	assert_eq(batches.size(), 2)
	assert_eq(batches[0], batches[1], "CR 701.22a: one action, one batch.")


func test_a_library_smaller_than_the_amount_shows_every_card_in_it() -> void:
	var engine: MmEngine = _hero_scrying(60)

	var asked: ScryDecision = engine.pending_decision() as ScryDecision

	assert_eq(asked.card_ids, engine.hero().library.object_ids())


func test_an_empty_library_asks_nothing() -> void:
	var seer: MmCardDefinition = Scenario.seer()
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.copies(seer, 7), Scenario.cycled([]))
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		return Scenario.ready_in_main(running, 1, 0, "Seer"))
	assert_not_null(engine)
	assert_eq(engine.hero().library.size(), 0)

	assert_eq(Scenario.cast_and_resolve(engine, "Seer"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_false(engine.pending_decision() is ScryDecision)
	assert_eq(engine.game_state().stack.size(), 0, "CR 701.22b: the trigger resolved and did nothing.")


func test_an_answer_must_place_every_card_once_and_nothing_else() -> void:
	var engine: MmEngine = _hero_scrying(2)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision
	var first: int = asked.card_ids[0]
	var second: int = asked.card_ids[1]
	var other: int = engine.hero().library.object_ids()[2]

	assert_ne(engine.submit([[first], []]), "", "The second card is placed nowhere.")
	assert_ne(engine.submit([[first], [first, second]]), "", "The first card is placed twice.")
	assert_ne(engine.submit([[], [first, second, other]]), "", "Only the cards looked at.")
	assert_ne(engine.submit([first, second]), "", "Two lists.")
	assert_true(engine.pending_decision() is ScryDecision, "Nothing changed.")
	assert_eq(engine.submit([[second], [first]]), "")


func test_while_scrying_only_the_scrying_player_sees_the_cards() -> void:
	var engine: MmEngine = _hero_scrying(2)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision

	var hero_sees: Array = engine.view_for(engine.hero()).libraries[engine.hero().id]
	var villain_sees: Array = engine.view_for(engine.villain()).libraries[engine.hero().id]

	assert_eq(_seen_ids(hero_sees), asked.card_ids, "The top two, and nothing under them.")
	assert_eq(_seen_ids(villain_sees).size(), 0)


func test_after_scrying_the_owner_still_sees_every_card_and_the_other_player_none() -> void:
	var engine: MmEngine = _hero_scrying(2)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision

	assert_eq(engine.submit([[asked.card_ids[0]], [asked.card_ids[1]]]), "")

	assert_eq(_seen_ids(engine.view_for(engine.hero()).libraries[engine.hero().id]), [asked.card_ids[1], asked.card_ids[0]] as Array[int],
		"The one kept on top, and the one put on the bottom.")
	assert_eq(_seen_ids(engine.view_for(engine.villain()).libraries[engine.hero().id]).size(), 0)


func test_asking_the_scry_is_an_undo_barrier() -> void:
	var engine: MmEngine = _hero_scrying(1)

	assert_false(engine.can_undo(), "ADR 0015: the player has seen the cards.")


func test_a_simulation_copy_after_scrying_keeps_the_cards_on_top_and_on_the_bottom() -> void:
	var engine: MmEngine = _hero_scrying(2)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision
	assert_eq(engine.submit([[asked.card_ids[0]], [asked.card_ids[1]]]), "")
	var top: int = engine.game_state().object(asked.card_ids[1]).card_id
	var bottom: int = engine.game_state().object(asked.card_ids[0]).card_id

	for rng_seed: int in [1, 2, 3, 4, 5]:
		var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(rng_seed))
		assert_eq(copy.hero().library.top().card_id, top)
		assert_eq(copy.hero().library.objects().back().card_id, bottom)


func test_a_replay_of_a_scry_gives_the_same_game() -> void:
	var engine: MmEngine = _hero_scrying(3)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision
	assert_eq(engine.submit([[asked.card_ids[1]], [asked.card_ids[2], asked.card_ids[0]]]), "")

	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_a_scry_and_a_surveil_of_the_same_cards_are_told_apart() -> void:
	var engine: MmEngine = _hero_scrying(1)
	var asked: ScryDecision = engine.pending_decision() as ScryDecision

	var surveil: SurveilDecision = SurveilDecision.new(asked.player_id, asked.stack_object_id, asked.card_ids)

	assert_ne(asked.describe(), surveil.describe(), "The fingerprint names the decision.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_scry.tres"
	assert_eq(ResourceSaver.save(Scenario.seer("Seer", 2), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var scry: ScryEffect = (loaded.abilities[0] as TriggeredAbility).effects[0] as ScryEffect
	assert_eq((scry.amount as ConstantValue).value, 2)
	DirAccess.remove_absolute(path)


## The Hero in their first main phase, having cast a Seer ("When this creature enters, scry
## [param amount].") for {0}, its trigger resolving and the scry asked.
func _hero_scrying(amount: int) -> MmEngine:
	var cards: Array[MmCardDefinition] = [Scenario.seer("Seer", amount), Scenario.basic_land("Forest"),
		Scenario.creature("Bear", 2, 2), Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])]
	_setup = Scenario.setup_with(Scenario.cycled(cards), Scenario.cycled([]))
	var engine: MmEngine = Scenario.find_engine(_setup, func(running: MmEngine) -> bool:
		return Scenario.ready_in_main(running, 1, 0, "Seer"))
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(Scenario.cast_and_resolve(engine, "Seer"), "")
	assert_eq(Scenario.pass_to_scry(engine), "")
	return engine


func _seen_ids(library: Array) -> Array[int]:
	var ids: Array[int] = []
	for seen: Variant in library:
		if seen != null:
			ids.append((seen as MmObjectView).id)
	return ids
