extends GutTest
## "As long as you've drawn two or more cards this turn", as Spinehorn Minotaur says: a
## CardsDrawnThisTurnValue under a ValueAtLeastCondition. It reads the count each player keeps
## of the cards they drew this turn (MmPlayer.cards_drawn_this_turn), the draw step's card
## among them, which starts again as each turn begins.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_it_has_double_strike_once_its_controller_has_drawn_a_second_card_this_turn() -> void:
	var engine: MmEngine = _hero_main([Scenario.minotaur()], [Scenario.free_draw("Peek", 1)], [])
	assert_eq(engine.hero().cards_drawn_this_turn, 1, "CR 504.1: the card of the Hero's draw step.")
	assert_false(_has_double_strike(engine, engine.hero().id), "One card drawn so far.")

	_cast_at_hero(engine, "Peek")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(_has_double_strike(engine, engine.hero().id), "The second card this turn.")


func test_it_loses_double_strike_as_the_next_turn_begins() -> void:
	var engine: MmEngine = _hero_main([Scenario.minotaur()], [Scenario.free_draw("Peek", 1)], [])
	_cast_at_hero(engine, "Peek")
	assert_eq(Scenario.resolve_stack(engine), "")

	Scenario.play_until_step(engine, 4, Step.UPKEEP)

	assert_eq(engine.hero().cards_drawn_this_turn, 0)
	assert_false(_has_double_strike(engine, engine.hero().id))


func test_it_counts_only_the_cards_its_players_drew() -> void:
	var engine: MmEngine = _hero_main([Scenario.minotaur()], [Scenario.free_draw("Peek", 1)], [Scenario.minotaur()])

	_cast_at_hero(engine, "Peek")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(_has_double_strike(engine, engine.hero().id))
	assert_false(_has_double_strike(engine, engine.villain().id), "The Villain drew no card on the Hero's turn.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_cards_drawn_this_turn.tres"
	assert_eq(ResourceSaver.save(Scenario.minotaur(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var condition: ValueAtLeastCondition = (loaded.abilities[0] as ContinuousStaticAbility).condition as ValueAtLeastCondition
	assert_eq(condition.amount, 2)
	assert_true((condition.value as CardsDrawnThisTurnValue).players is YouSelection)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## Whether [param player_id]'s Minotaur has double strike right now.
func _has_double_strike(engine: MmEngine, player_id: int) -> bool:
	var minotaur: MmGameObject = engine.game_state().object(Scenario.permanent_named(engine, player_id, "Minotaur"))
	return engine.game_state().characteristics_of(minotaur).has_ability(DoubleStrikeAbility)


## Casts the Hero's [param card_name] at the Hero, while the Hero has priority.
func _cast_at_hero(engine: MmEngine, card_name: String) -> void:
	var card: int = Scenario.card_in_hand(engine, engine.hero(), card_name)
	assert_eq(Scenario.cast(engine, card, [MmReference.to_player(engine.hero().id)]), "")


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand]; the Villain cast [param villain_permanents] on Game Turn 2.
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
