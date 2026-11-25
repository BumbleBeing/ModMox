extends GutTest
## "Look at the top four cards of your library. You may reveal a creature card with power 2
## or less from among them and put it into your hand. Put the rest on the bottom of your
## library in a random order.", as Militia Bugler says. Its controller looks at the cards
## (CR 701.20e) and chooses up to one that matches from among them; the one taken is revealed
## (CR 701.20a) into their hand, and the rest go to the bottom in an order from the Game RNG.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step

## The setup _bugler_ready() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_it_names_the_top_four_and_only_those_that_match_may_be_taken() -> void:
	var engine: MmEngine = _bugler_ready()
	var top: Array[int] = _top(engine, 4)

	var decision: ChooseLookedAtCardsDecision = _look(engine)

	assert_not_null(decision)
	assert_eq(decision.card_ids, top, "The top four, top first.")
	assert_eq(decision.most, 1)
	for id: int in top:
		assert_eq(decision.candidate_ids.has(id), _name_of(engine, id) != "Ogre",
			"A creature card with power 2 or less: the Pups and Buglers, never the 3/3 Ogre.")


func test_the_card_taken_is_revealed_into_the_hand_and_the_rest_go_to_the_bottom() -> void:
	var engine: MmEngine = _bugler_ready()
	var top: Array[int] = _top(engine, 4)
	var decision: ChooseLookedAtCardsDecision = _look(engine)
	var taken: int = decision.candidate_ids[0]
	var hand_size: int = engine.hero().hand.size()
	var library_size: int = engine.hero().library.size()

	assert_eq(engine.submit([taken]), "")

	assert_eq(engine.hero().hand.size(), hand_size + 1)
	assert_eq(engine.hero().library.size(), library_size - 1)
	var bottom: Array[int] = _bottom(engine, 3)
	var rest: Array[int] = top.duplicate()
	rest.erase(taken)
	bottom.sort()
	rest.sort()
	assert_eq(bottom, rest, "The other three, in some order, at the bottom.")
	var villain_knows: Array[MmObjectView] = engine.view_for(engine.villain()).known_in_hands[engine.hero().id]
	assert_eq(villain_knows.size(), 1, "CR 701.20a: the Villain saw the card taken.")
	assert_eq(villain_knows[0].name, _name_of_view(engine, taken))


func test_taking_nothing_puts_all_four_on_the_bottom() -> void:
	var engine: MmEngine = _bugler_ready()
	var top: Array[int] = _top(engine, 4)
	assert_not_null(_look(engine))
	var hand_size: int = engine.hero().hand.size()

	assert_eq(engine.submit([]), "")

	assert_eq(engine.hero().hand.size(), hand_size)
	var bottom: Array[int] = _bottom(engine, 4)
	bottom.sort()
	top.sort()
	assert_eq(bottom, top)
	assert_eq(engine.view_for(engine.villain()).known_in_hands[engine.hero().id], [] as Array[MmObjectView])


func test_a_card_that_does_not_match_cannot_be_taken_nor_two_at_once() -> void:
	var engine: MmEngine = _bugler_ready()
	var decision: ChooseLookedAtCardsDecision = _look(engine)
	var ogre: int = -1
	for id: int in decision.card_ids:
		if not decision.candidate_ids.has(id):
			ogre = id

	assert_ne(engine.submit([ogre]), "")
	if decision.candidate_ids.size() >= 2:
		assert_ne(engine.submit([decision.candidate_ids[0], decision.candidate_ids[1]]), "", "Up to one.")
	assert_eq(engine.pending_decision(), decision, "Still asked.")


func test_only_its_controller_sees_the_cards_looked_at() -> void:
	var engine: MmEngine = _bugler_ready()
	var top: Array[int] = _top(engine, 4)
	assert_not_null(_look(engine))

	var hers: Array[MmObjectView] = engine.view_for(engine.hero()).libraries[engine.hero().id]
	var theirs: Array[MmObjectView] = engine.view_for(engine.villain()).libraries[engine.hero().id]

	for index: int in 4:
		assert_not_null(hers[index], "CR 701.20e: the Hero looks at it.")
		assert_eq(hers[index].id, top[index])
		assert_null(theirs[index], "The Villain does not.")
	assert_null(hers[4], "Only the top four.")


func test_with_fewer_cards_in_the_library_it_looks_at_all_of_them() -> void:
	# Nine cards: seven in the opening hand and one drawn on Game Turn 3 leave one.
	var deck: Array[MmCardDefinition] = [Scenario.bugler()]
	deck.append_array(Scenario.copies(Scenario.creature("Pup", 1, 1), 8))
	var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([] as Array[MmCardDefinition]))
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		return Scenario.play_until_step(running, 3, Step.PRECOMBAT_MAIN) == "" \
			and Scenario.card_in_hand(running, running.hero(), "Bugler") != -1)
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(engine.hero().library.size(), 1)

	var decision: ChooseLookedAtCardsDecision = _look(engine)

	assert_eq(decision.card_ids.size(), 1)


func test_the_order_on_the_bottom_comes_from_the_game_rng_and_replays_exactly() -> void:
	var engine: MmEngine = _bugler_ready()
	assert_not_null(_look(engine))
	assert_eq(engine.submit([]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	Scenario.play_until_game_turn(engine, 5)

	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())
	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_eq(Scenario.events_of(engine, LibraryBottomRandomizedEvent).size(), 1)


# --- Helpers ---------------------------------------------------------------------------


## The Hero in their main phase on Game Turn 3 holding a Bugler, a 2/3 costing {0}
## (Scenario.bugler()), with Pups (1/1), Buglers and Ogres (3/3) in their library, and among
## its top four at least one card that may be taken and one that may not.
func _bugler_ready() -> MmEngine:
	var deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.bugler(), Scenario.creature("Pup", 1, 1),
		Scenario.creature("Ogre", 3, 3), Scenario.creature("Ogre", 3, 3)] as Array[MmCardDefinition])
	_setup = Scenario.setup_with(deck, Scenario.cycled([] as Array[MmCardDefinition]))
	var engine: MmEngine = Scenario.find_engine(_setup, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 3, Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.card_in_hand(running, running.hero(), "Bugler") == -1:
			return false
		var names: Array[String] = []
		for id: int in _top(running, 4):
			names.append(_name_of(running, id))
		return names.has("Ogre") and (names.has("Pup") or names.has("Bugler")))
	assert_not_null(engine, "No seed gave the needed hand and library.")
	return engine


## Casts the Bugler in hand and resolves it until its look is asked.
func _look(engine: MmEngine) -> ChooseLookedAtCardsDecision:
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bugler")), "")
	Scenario.autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is ChooseLookedAtCardsDecision)
	return engine.pending_decision() as ChooseLookedAtCardsDecision


func _top(engine: MmEngine, count: int) -> Array[int]:
	return engine.hero().library.object_ids().slice(0, count)


func _bottom(engine: MmEngine, count: int) -> Array[int]:
	var ids: Array[int] = engine.hero().library.object_ids()
	return ids.slice(ids.size() - count)


func _name_of(engine: MmEngine, id: int) -> String:
	return engine.game_state().characteristics_of(engine.game_state().object(id)).name


## The name of the card [param id] was, now in the Hero's hand as a new object.
func _name_of_view(engine: MmEngine, id: int) -> String:
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved.object_id == id:
			return _name_of(engine, moved.new_object_id)
	return ""
