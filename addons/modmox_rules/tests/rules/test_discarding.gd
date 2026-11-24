extends GutTest
## "[players] discard(s) [amount] cards" (CR 701.9a): the player chooses that many cards from
## their own hand and puts them into their graveyard, all at once. They are asked the
## ChooseCardsToDiscardDecision that discarding down to maximum hand size asks (CR 514.1),
## only when there is a choice: holding that many cards or fewer, they discard them all.
## "[effect] unless [condition]" (CR 608.2c) is an IfEffect with is_unless, as Splitskin
## Doll's "Then discard a card unless you control another creature with power 2 or less."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_player_chooses_the_card_and_it_goes_to_their_graveyard() -> void:
	var engine: MmEngine = _hero_main([], [_rummage(), _keepsake()])
	var hand: int = engine.hero().hand.size()
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Rummage")), "")
	assert_eq(Scenario.pass_priority(engine), "")
	var asked: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	if asked == null:
		assert_eq(Scenario.pass_priority(engine), "")  # The Villain passes too.
		asked = engine.pending_decision() as ChooseCardsToDiscardDecision
	assert_not_null(asked, "Asked as it resolves.")
	assert_eq(asked.player_id, engine.hero().id)
	assert_eq(asked.count, 1)
	assert_eq(asked.candidate_ids.size(), hand - 1, "Every card in hand but the Rummage on the stack.")
	var keepsake: int = Scenario.card_in_hand(engine, engine.hero(), "Keepsake")

	assert_eq(engine.submit([keepsake] as Array[int]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Keepsake"), -1)
	assert_eq(engine.hero().hand.size(), hand - 2)
	var moved: Array[MmEvent] = Scenario.events_of(engine, ZoneChangeEvent).filter(func(event: MmEvent) -> bool:
		return (event as ZoneChangeEvent).object_id == keepsake)
	assert_eq(moved.size(), 1)
	assert_eq((moved[0] as ZoneChangeEvent).reason, ZoneChangeEvent.Reason.DISCARD)


func test_holding_no_more_than_it_discards_they_discard_them_all_without_being_asked() -> void:
	var purge: MmCardDefinition = Scenario.instant("Purge", Scenario.mana_cost(0), [], [Scenario.discard(10)])
	var engine: MmEngine = _hero_main([], [purge])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Purge")), "")
	while not engine.game_state().stack.is_empty():
		assert_false(engine.pending_decision() is ChooseCardsToDiscardDecision, "No choice to make.")
		assert_eq(Scenario.pass_priority(engine), "")

	assert_eq(engine.hero().hand.size(), 0)


func test_with_an_empty_hand_nothing_happens() -> void:
	var purge: MmCardDefinition = Scenario.instant("Purge", Scenario.mana_cost(0), [], [Scenario.discard(10), Scenario.discard(1)])
	var engine: MmEngine = _hero_main([], [purge])
	var graveyard: int = engine.hero().graveyard.size()
	var hand: int = engine.hero().hand.size()

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Purge")), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().graveyard.size(), graveyard + hand, "The rest of the hand, then the Purge; nothing more.")


func test_each_opponent_discards_from_their_own_hand() -> void:
	var taunt: MmCardDefinition = Scenario.instant("Taunt", Scenario.mana_cost(0), [], [Scenario.discard(1, EachOpponentSelection.new())])
	var engine: MmEngine = _hero_main([], [taunt])
	var theirs: int = engine.villain().hand.size()
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Taunt")), "")
	for attempt: int in 4:
		if engine.pending_decision() is ChooseCardsToDiscardDecision:
			break
		assert_eq(Scenario.pass_priority(engine), "")
	var asked: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	assert_not_null(asked)
	assert_eq(asked.player_id, engine.villain().id, "The opponent chooses.")

	assert_eq(engine.submit([asked.candidate_ids[0]] as Array[int]), "")

	assert_eq(engine.villain().hand.size(), theirs - 1)


func test_unless_another_creature_with_power_2_or_less_is_yours_nothing_is_discarded() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [Scenario.doll()])
	var hand: int = engine.hero().hand.size()

	assert_eq(Scenario.cast_and_resolve(engine, "Doll"), "")
	while not engine.game_state().stack.is_empty():
		assert_false(engine.pending_decision() is ChooseCardsToDiscardDecision, "The Bear is another creature with power 2.")
		assert_eq(Scenario.pass_priority(engine), "")

	assert_eq(engine.hero().hand.size(), hand, "The Doll left the hand and a card was drawn.")


func test_with_only_bigger_creatures_besides_it_a_card_is_discarded() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Ogre", 3, 3)], [Scenario.doll()])
	var hand: int = engine.hero().hand.size()

	assert_eq(Scenario.cast_and_resolve(engine, "Doll"), "")
	assert_eq(_pass_to_discard(engine), "")
	assert_eq(engine.submit([(engine.pending_decision() as ChooseCardsToDiscardDecision).candidate_ids[0]] as Array[int]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().hand.size(), hand - 1)


func test_the_doll_itself_is_not_another_creature() -> void:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main(no_cards, [Scenario.doll()])

	assert_eq(Scenario.cast_and_resolve(engine, "Doll"), "")

	assert_eq(_pass_to_discard(engine), "", "The Doll has power 2, but it is not another creature.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_discarding.tres"
	assert_eq(ResourceSaver.save(Scenario.doll(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var unless: IfEffect = (loaded.abilities[0] as TriggeredAbility).effects[1] as IfEffect
	assert_true(unless.is_unless)
	assert_true(unless.effect is DiscardEffect)
	assert_eq(((unless.effect as DiscardEffect).amount as ConstantValue).value, 1)
	assert_true((unless.effect as DiscardEffect).players is YouSelection)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## An instant costing {0}: "Discard a card."
func _rummage() -> MmCardDefinition:
	return Scenario.instant("Rummage", Scenario.mana_cost(0), [], [Scenario.discard()])


func _keepsake() -> MmCardDefinition:
	return Scenario.artifact("Keepsake", [])


## Passes priority until a discard is asked, or says why not.
func _pass_to_discard(engine: MmEngine) -> String:
	for attempt: int in 6:
		if engine.pending_decision() is ChooseCardsToDiscardDecision:
			return ""
		if not engine.pending_decision() is PriorityDecision or engine.game_state().stack.is_empty():
			return "No discard was asked."
		var error: String = Scenario.pass_priority(engine)
		if error != "":
			return error
	return "No discard was asked."


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand].
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(hero_permanents, no_cards, hand), hero_permanents,
		no_cards, hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
