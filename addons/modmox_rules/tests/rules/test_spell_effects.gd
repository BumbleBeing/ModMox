extends GutTest
## CR 120: damage to a player causes that much life loss. CR 121: drawing.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Type := MmMana.Type


func test_damage_to_a_player_is_life_loss_from_the_spell() -> void:
	var engine: MmEngine = _hero_holding(Scenario.bolt(), "Bolt", "Mountain")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bolt"), [MmReference.to_player(engine.villain().id)])
	var bolt_on_stack: int = engine.game_state().stack.object_ids()[0]

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.villain().life, 17)
	var damage: DamageEvent = null
	for event: MmEvent in engine.event_log():
		if event is DamageEvent:
			damage = event as DamageEvent
	assert_not_null(damage)
	assert_eq(damage.source_object_id, bolt_on_stack, "The spell is the source of the damage.")
	assert_eq(damage.amount, 3)


func test_target_player_draws_cards() -> void:
	var recall: MmCardDefinition = Scenario.instant("Recall", Scenario.mana_cost(0, [Type.BLUE]),
		[Scenario.target_player()], [Scenario.draw_cards(3, Scenario.targeted(0))])
	var engine: MmEngine = _hero_holding(recall, "Recall", "Island")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Recall"), [MmReference.to_player(engine.hero().id)])
	var hand_before: int = engine.hero().hand.size()

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.hero().hand.size(), hand_before + 3)


func test_gaining_life() -> void:
	var salve: MmCardDefinition = Scenario.instant("Salve", Scenario.mana_cost(0, [Type.WHITE]),
		[Scenario.target_player()], [Scenario.gain_life(3, Scenario.targeted(0))])
	var engine: MmEngine = _hero_holding(salve, "Salve", "Plains")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Salve"), [MmReference.to_player(engine.villain().id)])

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.villain().life, 23)


func test_a_sum_adds_every_addend() -> void:
	var sum: SumValue = Scenario.sum([Scenario.constant(1), Scenario.constant(2), Scenario.constant(4)])
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.vanilla("Card"), 40), Scenario.copies(Scenario.vanilla("Card"), 40)))

	assert_eq(sum.evaluate(engine.game_state(), MmEffectContext.new(engine.hero().id, 0)), 7)


func test_slash_deals_damage_equal_to_creatures_plus_equipment_its_caster_controls() -> void:
	var engine: MmEngine = _slash_ready([_bear(), _bear(), Scenario.sword("Sword")], [_giant()])
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Giant")

	assert_eq(Scenario.cast_and_resolve(engine, "Slash", [MmReference.to_object(giant)]), "")

	assert_eq(Scenario.damage_on(engine, giant), 3, "Two Bears plus one Sword.")


func test_an_equipment_creature_is_counted_once_as_each() -> void:
	var engine: MmEngine = _slash_ready([_bear(), Scenario.equipment_creature("Sash", 1, 1)], [_giant()])
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Giant")

	assert_eq(Scenario.cast_and_resolve(engine, "Slash", [MmReference.to_object(giant)]), "")

	assert_eq(Scenario.damage_on(engine, giant), 3, "Two creatures plus one Equipment.")


func test_the_sum_is_worked_out_as_the_spell_resolves() -> void:
	var engine: MmEngine = _slash_ready([_bear(), _bear(), Scenario.sword("Sword")], [_giant()],
		[Scenario.free_shock("Shock", 2)])
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Giant")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Slash"), [MmReference.to_object(giant)]), "")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.damage_on(engine, giant), 2, "One Bear is left, plus the Sword.")


func test_only_the_casters_creatures_and_equipment_are_counted() -> void:
	var engine: MmEngine = _slash_ready([_bear()], [_giant(), _bear(), Scenario.sword("Sword")])
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Giant")

	assert_eq(Scenario.cast_and_resolve(engine, "Slash", [MmReference.to_object(giant)]), "")

	assert_eq(Scenario.damage_on(engine, giant), 1)


func test_a_sum_of_nothing_deals_no_damage() -> void:
	var engine: MmEngine = _slash_ready([], [_giant()])
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Giant")

	assert_eq(Scenario.cast_and_resolve(engine, "Slash", [MmReference.to_object(giant)]), "")

	assert_eq(Scenario.damage_on(engine, giant), 0)


## The Hero's [param hero_permanents] and the Villain's [param villain_permanents] on the
## battlefield, in the Hero's main phase on Game Turn 3, the Hero holding a free Slash of
## Light and [param hero_extras].
func _slash_ready(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.free_slash("Slash")]
	extras.append_array(hero_extras)
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, extras, [],
		3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _giant() -> MmCardDefinition:
	return Scenario.creature("Giant", 5, 5)


func _hero_holding(card: MmCardDefinition, card_name: String, land_type: String) -> MmEngine:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land(land_type), 20, card, 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, card_name))
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
