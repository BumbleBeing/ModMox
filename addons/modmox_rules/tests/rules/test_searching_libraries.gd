extends GutTest
## "Search your library for a [quality] card, reveal it, put it into your hand, then
## shuffle." (CR 701.23, ADR 0057): a choice made from the whole library as the effect
## begins, the found cards moved, then the library shuffled. A card revealed into a hand is
## a Known Card there for the other player.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_a_found_card_goes_to_the_hand_and_then_the_library_is_shuffled() -> void:
	var engine: MmEngine = _hero_main()
	var library_before: int = engine.hero().library.size()
	assert_eq(Scenario.cast_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	var found_card: int = engine.game_state().object(search.candidate_ids[0]).card_id
	var log_before: int = engine.game_state().event_log.size()

	assert_eq(engine.submit([search.candidate_ids[0]]), "")

	assert_eq(engine.hero().library.size(), library_before - 1)
	assert_true(_hand_card_ids(engine, engine.hero()).has(found_card), "The Forest found is in the hand.")
	var moved_at: int = -1
	var shuffled_at: int = -1
	var events: Array[MmEvent] = engine.game_state().event_log
	for index: int in range(log_before, events.size()):
		var moved: ZoneChangeEvent = events[index] as ZoneChangeEvent
		if moved != null and moved.reason == ZoneChangeEvent.Reason.SEARCH:
			moved_at = index
		var shuffle: ShuffleEvent = events[index] as ShuffleEvent
		if shuffle != null and shuffle.zone_kind == MmZone.Kind.LIBRARY and shuffle.owner_id == engine.hero().id:
			shuffled_at = index
	assert_gt(moved_at, -1, "Moved by a search.")
	assert_gt(shuffled_at, moved_at, "CR 701.23: then shuffle.")


func test_only_the_cards_that_match_are_offered_and_at_most_the_amount() -> void:
	var engine: MmEngine = _hero_main()

	assert_eq(Scenario.cast_to_search(engine), "")

	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	var forests: int = 0
	for card: MmGameObject in engine.hero().library.objects():
		if engine.game_state().characteristics_of(card).name == "Forest":
			forests += 1
	assert_eq(search.candidate_ids.size(), forests, "Every basic land, and nothing else.")
	assert_eq(search.most, 1)
	assert_ne(engine.submit(search.candidate_ids.slice(0, 2)), "", "No more than one.")


func test_the_searcher_may_find_nothing_even_when_a_card_matches() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.cast_to_search(engine), "")
	var hand_before: int = engine.hero().hand.size()
	var library_before: int = engine.hero().library.size()
	var shuffles_before: int = _shuffles_of(engine, engine.hero().id)

	assert_eq(engine.submit([]), "", "CR 701.23b: a search for a stated quality may fail.")

	assert_eq(engine.hero().hand.size(), hand_before)
	assert_eq(engine.hero().library.size(), library_before)
	assert_eq(_shuffles_of(engine, engine.hero().id), shuffles_before + 1, "Shuffled all the same.")


func test_with_nothing_to_find_it_is_still_asked_and_the_library_shuffled() -> void:
	var plains_search: SearchLibraryEffect = Scenario.search(Scenario.all_of([Scenario.basic_land_card(), _subtype("Plains")]))
	var engine: MmEngine = _hero_main(Scenario.free_seek("Seek", plains_search))

	assert_eq(Scenario.cast_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	assert_eq(search.candidate_ids.size(), 0, "No Plains in this library.")
	var shuffles_before: int = _shuffles_of(engine, engine.hero().id)

	assert_eq(engine.submit([]), "")

	assert_eq(_shuffles_of(engine, engine.hero().id), shuffles_before + 1)


func test_up_to_two_finds_two_but_never_three() -> void:
	var engine: MmEngine = _hero_main(Scenario.free_seek("Seek", Scenario.search(Scenario.basic_land_card(), 2)))
	assert_eq(Scenario.cast_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	var hand_before: int = engine.hero().hand.size()

	assert_ne(engine.submit(search.candidate_ids.slice(0, 3)), "")
	assert_eq(engine.submit(search.candidate_ids.slice(0, 2)), "")

	assert_eq(engine.hero().hand.size(), hand_before + 2)


func test_while_searching_only_the_searcher_sees_their_whole_library() -> void:
	var engine: MmEngine = _hero_main()

	assert_eq(Scenario.cast_to_search(engine), "")

	var hero_sees: Array = engine.view_for(engine.hero()).libraries[engine.hero().id]
	var villain_sees: Array = engine.view_for(engine.villain()).libraries[engine.hero().id]
	assert_eq(hero_sees.size(), engine.hero().library.size())
	assert_false(hero_sees.has(null), "Every card face up to the searcher.")
	assert_eq(villain_sees.filter(func(seen: Variant) -> bool: return seen != null).size(), 0, "Nothing to the other player.")


func test_after_the_search_the_library_is_hidden_again() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.cast_to_search(engine), "")

	assert_eq(engine.submit([]), "")

	var hero_sees: Array = engine.view_for(engine.hero()).libraries[engine.hero().id]
	assert_eq(hero_sees.filter(func(seen: Variant) -> bool: return seen != null).size(), 0)


func test_a_revealed_card_found_into_the_hand_is_known_to_the_other_player() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.cast_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision

	assert_eq(engine.submit([search.candidate_ids[0]]), "")

	var known: Array = engine.view_for(engine.villain()).known_in_hands[engine.hero().id]
	assert_eq(known.size(), 1)
	assert_eq((known[0] as MmObjectView).name, "Forest")
	assert_eq(engine.view_for(engine.hero()).known_in_hands[engine.villain().id].size(), 0)


func test_a_card_found_without_revealing_is_not_known() -> void:
	var engine: MmEngine = _hero_main(Scenario.free_seek("Seek", Scenario.search(Scenario.basic_land_card(), 1, MmZone.Kind.HAND, false)))
	assert_eq(Scenario.cast_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision

	assert_eq(engine.submit([search.candidate_ids[0]]), "")

	assert_eq(engine.view_for(engine.villain()).known_in_hands[engine.hero().id].size(), 0)


func test_a_simulation_copy_for_the_other_player_keeps_the_known_card_in_the_hand() -> void:
	var engine: MmEngine = _found_and_revealed()
	var known_id: int = (engine.view_for(engine.villain()).known_in_hands[engine.hero().id][0] as MmObjectView).id
	var known_card: int = engine.game_state().object(known_id).card_id

	for rng_seed: int in [1, 2, 3, 4, 5]:
		var copy: MmEngine = engine.simulation_copy(engine.villain().id, MmRng.new(rng_seed))
		assert_eq(copy.game_state().object(known_id).card_id, known_card, "Never re-dealt.")


func test_a_known_card_stops_being_known_when_it_leaves_the_hand() -> void:
	var engine: MmEngine = _found_and_revealed()
	assert_eq(Scenario.play_until_step(engine, 3, MmTurn.Step.PRECOMBAT_MAIN), "", "A land play to spare on the next turn.")
	var known_id: int = (engine.view_for(engine.villain()).known_in_hands[engine.hero().id][0] as MmObjectView).id
	var priority: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_eq(engine.submit(Scenario.play_land_index(priority, known_id)), "", "The known Forest is played.")

	assert_eq(engine.view_for(engine.villain()).known_in_hands[engine.hero().id].size(), 0, "ADR 0008: played, it is a new object.")


func test_a_card_put_unseen_from_a_hand_of_two_or_more_into_the_library_forgets_the_known_card() -> void:
	var engine: MmEngine = _found_and_revealed()
	assert_gt(engine.hero().hand.size(), 2, "Put Back and another card besides the Forest.")
	var known_id: int = (engine.view_for(engine.villain()).known_in_hands[engine.hero().id][0] as MmObjectView).id

	assert_eq(Scenario.cast_and_resolve(engine, "Put Back"), "")

	assert_not_null(engine.game_state().object(known_id), "The Forest is still in the hand: another card went back.")
	assert_eq(engine.view_for(engine.villain()).known_in_hands[engine.hero().id].size(), 0,
		"Which card went back is hidden, so the Forest might have.")


func test_casting_another_card_from_the_hand_keeps_the_known_card_known() -> void:
	var engine: MmEngine = _found_and_revealed()

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_eq(engine.view_for(engine.villain()).known_in_hands[engine.hero().id].size(), 1, "The card cast was seen as it went.")


func test_a_found_card_can_go_onto_the_battlefield_tapped() -> void:
	var engine: MmEngine = _hero_main(Scenario.free_seek("Seek", Scenario.search(Scenario.basic_land_card(), 1, MmZone.Kind.BATTLEFIELD, true, true)))
	assert_eq(Scenario.cast_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	var found_card: int = engine.game_state().object(search.candidate_ids[0]).card_id

	assert_eq(engine.submit([search.candidate_ids[0]]), "")

	var arrived: MmGameObject = _on_battlefield(engine, found_card)
	assert_not_null(arrived)
	assert_eq(arrived.controller_id, engine.hero().id)
	assert_true(arrived.is_tapped, "Put onto the battlefield tapped.")


func test_a_found_card_can_go_onto_the_battlefield_untapped() -> void:
	var engine: MmEngine = _hero_main(Scenario.free_seek("Seek", Scenario.search(Scenario.basic_land_card(), 1, MmZone.Kind.BATTLEFIELD)))
	assert_eq(Scenario.cast_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	var found_card: int = engine.game_state().object(search.candidate_ids[0]).card_id

	assert_eq(engine.submit([search.candidate_ids[0]]), "")

	assert_false(_on_battlefield(engine, found_card).is_tapped)


func test_a_found_card_can_go_into_the_graveyard_or_exile() -> void:
	for destination: MmZone.Kind in [MmZone.Kind.GRAVEYARD, MmZone.Kind.EXILE]:
		var engine: MmEngine = _hero_main(Scenario.free_seek("Seek", Scenario.search(Scenario.basic_land_card(), 1, destination)))
		assert_eq(Scenario.cast_to_search(engine), "")
		var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
		var found_card: int = engine.game_state().object(search.candidate_ids[0]).card_id

		assert_eq(engine.submit([search.candidate_ids[0]]), "")

		var zone: MmZone = engine.hero().graveyard if destination == MmZone.Kind.GRAVEYARD else engine.game_state().exile
		var card_ids: Array[int] = []
		for card: MmGameObject in zone.objects():
			card_ids.append(card.card_id)
		assert_true(card_ids.has(found_card), "Found into %s." % MmZone.Kind.find_key(destination))


func test_asking_the_search_is_an_undo_barrier() -> void:
	var engine: MmEngine = _hero_main()

	assert_eq(Scenario.cast_to_search(engine), "")

	assert_false(engine.can_undo(), "ADR 0015: the searcher has seen their library.")


func test_a_simulation_copy_made_while_searching_keeps_the_searchers_library() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.cast_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	var order: Array[int] = _library_card_ids(engine)

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(9))

	assert_eq(_library_card_ids(copy), order, "Not re-dealt while the search names its cards.")
	assert_eq(copy.submit([search.candidate_ids[0]]), "")
	assert_eq(copy.game_state().object(search.candidate_ids[0]), null, "The copy found the card the decision named.")


func test_a_basic_filter_matches_basic_lands_only() -> void:
	var engine: MmEngine = _hero_main()
	var basic: HasSupertypeFilter = HasSupertypeFilter.new()
	basic.supertype = MmCardTypes.Supertype.BASIC
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var matched: Array[String] = []

	for card: MmGameObject in engine.hero().library.objects():
		if basic.matches(engine.game_state(), MmReference.to_object(card.id), context):
			matched.append(engine.game_state().characteristics_of(card).name)

	assert_false(matched.is_empty())
	for card_name: String in matched:
		assert_eq(card_name, "Forest")


## The Hero in their first main phase holding [param seek] (by default "Search your
## library for a basic land card, reveal it, put it into your hand, then shuffle." for
## {0}), Put Back and Gift, with Forests and Grove (a nonbasic land) in their library.
func _hero_main(seek: MmCardDefinition = null) -> MmEngine:
	var seeking: MmCardDefinition = seek if seek != null else Scenario.free_seek()
	var gift: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var grove: MmCardDefinition = Scenario.mana_land("Grove", MmMana.Type.GREEN, 1)
	var cards: Array[MmCardDefinition] = Scenario.cycled([seeking, Scenario.basic_land("Forest"), Scenario.free_put_back(),
		grove, gift, Scenario.basic_land("Forest")])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.cycled([])), func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 1, 0, "Seek"):
			return false
		var held: Array[String] = Scenario.names(running, running.hero().hand)
		return held.has("Put Back") and held.has("Gift") and held.size() >= 4)
	assert_not_null(engine)
	return engine


## _hero_main() with a Forest found and revealed into the Hero's hand.
func _found_and_revealed() -> MmEngine:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.cast_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	assert_eq(engine.submit([search.candidate_ids[0]]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	return engine


func _subtype(subtype: String) -> HasSubtypeFilter:
	var filter: HasSubtypeFilter = HasSubtypeFilter.new()
	filter.subtype = subtype
	return filter


func _hand_card_ids(engine: MmEngine, player: MmPlayer) -> Array[int]:
	var ids: Array[int] = []
	for card: MmGameObject in player.hand.objects():
		ids.append(card.card_id)
	return ids


func _library_card_ids(engine: MmEngine) -> Array[int]:
	var ids: Array[int] = []
	for card: MmGameObject in engine.hero().library.objects():
		ids.append(card.card_id)
	return ids


func _on_battlefield(engine: MmEngine, card_id: int) -> MmGameObject:
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.card_id == card_id:
			return permanent
	return null


func _shuffles_of(engine: MmEngine, player_id: int) -> int:
	var count: int = 0
	for event: MmEvent in engine.game_state().event_log:
		var shuffle: ShuffleEvent = event as ShuffleEvent
		if shuffle != null and shuffle.zone_kind == MmZone.Kind.LIBRARY and shuffle.owner_id == player_id:
			count += 1
	return count
