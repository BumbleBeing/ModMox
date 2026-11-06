extends GutTest
## CR 608.3: a permanent spell resolves by entering the battlefield. CR 307.1 and 702.8a:
## it is cast at sorcery speed unless it is an instant or has flash.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_spell_resolves_onto_the_battlefield_as_a_new_object() -> void:
	var engine: MmEngine = _hero_in_first_main([Scenario.creature("Bear", 2, 2)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear"))
	var on_stack: int = engine.game_state().stack.object_ids()[0]

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_ne(bear, -1, "The creature is on the battlefield.")
	assert_ne(bear, on_stack, "ADR 0008: it is a new object.")
	assert_eq(engine.game_state().object(bear).controller_id, engine.hero().id)
	assert_eq(engine.hero().graveyard.size(), 0, "A permanent spell does not go to the graveyard.")
	assert_eq(engine.game_state().stack.size(), 0)
	var moved: ZoneChangeEvent = _last_zone_change(engine)
	assert_eq(moved.to_zone_kind, MmZone.Kind.BATTLEFIELD)
	assert_eq(moved.reason, ZoneChangeEvent.Reason.RESOLVED)


func test_any_permanent_spell_resolves_onto_the_battlefield() -> void:
	var trinket: MmCardDefinition = Scenario.vanilla("Trinket")
	trinket.card_types = [MmCardTypes.CardType.ARTIFACT]
	trinket.mana_cost = Scenario.mana_cost(0)
	var engine: MmEngine = _hero_in_first_main([trinket])

	assert_eq(Scenario.cast_and_resolve(engine, "Trinket"), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Trinket"), -1)


func test_a_creature_spell_is_not_offered_while_the_stack_is_not_empty() -> void:
	var engine: MmEngine = _hero_in_first_main([Scenario.creature("Bear", 2, 2)])

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear"))

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")))


func test_a_creature_spell_is_not_offered_outside_your_main_phase() -> void:
	var engine: MmEngine = _hero_in_first_main([Scenario.creature("Bear", 2, 2)])

	Scenario.pass_until_step(engine, Step.END)

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")))


func test_a_creature_with_flash_can_be_cast_in_the_opponents_end_step() -> void:
	var sprite: MmCardDefinition = Scenario.creature("Sprite", 1, 1, [FlashAbility.new()])
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.creature("Bear", 2, 2), 40), Scenario.copies(sprite, 40)))
	Scenario.play_until_step(engine, 1, Step.END)
	Scenario.pass_priority(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Sprite"), "")

	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Sprite"), -1)


func test_a_creature_without_flash_is_not_offered_on_the_opponents_turn() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.vanilla("Card"), 40), Scenario.copies(Scenario.creature("Bear", 2, 2), 40)))
	Scenario.play_until_step(engine, 1, Step.END)

	Scenario.pass_priority(engine)

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Bear")))


func test_a_sorcery_given_flash_can_be_cast_at_instant_speed() -> void:
	var quick: MmCardDefinition = Scenario.sorcery("Quick Bolt", Scenario.mana_cost(0),
		[Scenario.target_player()], [Scenario.deal_damage(1, Scenario.targeted(0))])
	quick.abilities.append(FlashAbility.new())
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.vanilla("Card"), 40), Scenario.copies(quick, 40)))
	Scenario.play_until_step(engine, 1, Step.UPKEEP)
	Scenario.pass_priority(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Quick Bolt", [MmReference.to_player(engine.hero().id)]), "")

	assert_eq(engine.hero().life, 19)


## The Hero in the first main phase of Game Turn 1, with a deck cycling [param cards].
func _hero_in_first_main(cards: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.cycled(cards), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	return engine


func _last_zone_change(engine: MmEngine) -> ZoneChangeEvent:
	var found: ZoneChangeEvent = null
	for event: MmEvent in engine.event_log():
		if event is ZoneChangeEvent:
			found = event as ZoneChangeEvent
	return found
