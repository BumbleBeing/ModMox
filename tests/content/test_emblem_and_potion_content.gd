extends GutTest
## The authored Emblems and Potions (ADR 0036, A516 and A517): what each one does when it
## is used in a game, so a changed default or a mis-saved file is caught.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const EMBLEMS: String = "res://content/emblems/"
const POTIONS: String = "res://content/potions/"


func test_electromancers_boon_costs_red_and_deals_three_damage_once_each_game() -> void:
	var engine: MmEngine = _engine_with(MmMana.Type.RED, [load(EMBLEMS + "electromancers_boon.tres")] as Array[MmCardDefinition], [])
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var boon: int = engine.view_for(engine.hero()).command[0].id
	assert_false(_offers(engine, boon), "It costs {R}.")
	Scenario.play_first_land(engine)

	assert_eq(Scenario.activate(engine, boon, [MmReference.to_player(engine.villain().id)]), "")
	Scenario.resolve_stack(engine)
	Scenario.play_until_step(engine, 3, Step.UPKEEP)

	assert_eq(engine.villain().life, 17)
	assert_eq(engine.view_for(engine.hero()).command[0].name, "Electromancer's Boon")
	assert_false(_offers(engine, boon), "Only once each game, though it could be paid for at instant speed.")


func test_diviners_boon_costs_two_and_blue_and_draws_two_as_a_sorcery_once_each_game() -> void:
	var engine: MmEngine = _engine_with(MmMana.Type.BLUE, [load(EMBLEMS + "diviners_boon.tres")] as Array[MmCardDefinition], [])
	Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN, true)
	var boon: int = engine.view_for(engine.hero()).command[0].id
	Scenario.play_first_land(engine)
	assert_false(_offers(engine, boon), "Two lands do not pay {2}{U}.")
	Scenario.play_until_step(engine, 5, Step.UPKEEP, true)
	assert_false(_offers(engine, boon), "Only as a sorcery.")
	Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN, true)
	Scenario.play_first_land(engine)
	var hand_size: int = engine.hero().hand.size()

	assert_eq(Scenario.activate(engine, boon), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().hand.size(), hand_size + 2)
	assert_eq(engine.view_for(engine.hero()).command[0].name, "Diviner's Boon")
	Scenario.play_until_step(engine, 7, Step.PRECOMBAT_MAIN, true)
	assert_false(_offers(engine, boon), "Only once each game.")


func test_big_gulp_is_a_common_potion_that_gives_plus_two_plus_two_and_is_used_up() -> void:
	var big_gulp: MmCardDefinition = load(POTIONS + "big_gulp.tres")
	var engine: MmEngine = _engine_with(MmMana.Type.GREEN, [], [big_gulp] as Array[MmCardDefinition])
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(engine, "Bear")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var potion: MmObjectView = engine.view_for(engine.hero()).potions[0]

	assert_eq(Scenario.activate(engine, potion.id, [MmReference.to_object(bear)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(potion.name, "Big Gulp")
	assert_null(potion.mana_cost, "A Potion has no mana cost.")
	assert_eq(big_gulp.rarity, MmCardDefinition.Rarity.COMMON)
	assert_eq(Scenario.pt(engine, bear), [4, 4] as Array[int])
	assert_eq(engine.used_potion_indexes(engine.hero()), [0] as Array[int])


func test_an_authored_emblem_has_abilities_and_nothing_else() -> void:
	for file_name: String in ["electromancers_boon", "diviners_boon"]:
		var emblem: MmCardDefinition = load(EMBLEMS + file_name + ".tres")

		assert_eq(emblem.card_types.size(), 0, "ADR 0011: \"Emblem\" is not a card type.")
		assert_null(emblem.mana_cost)
		assert_eq(emblem.abilities.size(), 1)


## A game whose Hero has a deck of lands for [param type] and free 2/2 Bears, in turn.
func _engine_with(type: MmMana.Type, emblems: Array[MmCardDefinition], potions: Array[MmCardDefinition]) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.setup_with(
		Scenario.cycled([Scenario.mana_land("Land", type, 1), Scenario.creature("Bear", 2, 2)]), Scenario.cycled([]))
	setup.hero.emblems = emblems
	setup.hero.potions = potions
	setup.hero.maximum_hand_size = MmPlayerSetup.NO_MAXIMUM_HAND_SIZE
	return Scenario.find_engine(setup, func(engine: MmEngine) -> bool:
		if Scenario.keep_all(engine) != "":
			return false
		var lands: int = 0
		var bears: int = 0
		for card: MmGameObject in engine.hero().hand.objects():
			if engine.game_state().characteristics_of(card).has_card_type(MmCardTypes.CardType.LAND):
				lands += 1
			else:
				bears += 1
		return lands >= 3 and bears >= 1)


func _offers(engine: MmEngine, object_id: int) -> bool:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	return decision != null and Scenario.activate_index(decision, object_id) != -1
