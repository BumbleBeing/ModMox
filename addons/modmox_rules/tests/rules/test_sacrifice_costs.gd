extends GutTest
## "Sacrifice this permanent" as a cost (CR 701.21a, 118.3): its controller moves it from the
## battlefield to its owner's graveyard as the ability is activated. It is not destruction,
## so indestructible and regeneration never stop it (CR 701.21a). The ability resolves with
## its source gone, from the source's last-known information (CR 608.2h).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_the_source_is_in_the_graveyard_while_its_ability_is_on_the_stack() -> void:
	var engine: MmEngine = _hero_main([Scenario.parcel()], [Scenario.creature("Ogre", 2, 4)])
	var parcel: int = Scenario.permanent_named(engine, engine.hero().id, "Parcel")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(Scenario.activate(engine, parcel, [MmReference.to_object(ogre)]), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Parcel"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Parcel"), -1, "CR 701.21a")
	assert_eq(Scenario.stack_ids(engine).size(), 1, "The ability waits on the stack.")
	var moved: ZoneChangeEvent = Scenario.events_of(engine, ZoneChangeEvent).back() as ZoneChangeEvent
	assert_eq(moved.reason, ZoneChangeEvent.Reason.SACRIFICE)


func test_the_ability_deals_its_damage_from_the_sacrificed_source() -> void:
	var engine: MmEngine = _hero_main([Scenario.parcel()], [Scenario.creature("Ogre", 2, 4)])
	var parcel: int = Scenario.permanent_named(engine, engine.hero().id, "Parcel")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.activate(engine, parcel, [MmReference.to_object(ogre)])

	Scenario.resolve_stack(engine)

	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Ogre"), -1)
	var dealt: DamageEvent = Scenario.events_of(engine, DamageEvent).back() as DamageEvent
	assert_eq(dealt.source_object_id, parcel, "CR 608.2h: the Parcel as it last existed.")


func test_a_countered_ability_leaves_its_source_sacrificed() -> void:
	var engine: MmEngine = _hero_main([Scenario.parcel()], [Scenario.creature("Ogre", 2, 4)], [Scenario.free_stifle("Stifle")])
	var parcel: int = Scenario.permanent_named(engine, engine.hero().id, "Parcel")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.activate(engine, parcel, [MmReference.to_object(ogre)])

	assert_eq(Scenario.cast_and_resolve(engine, "Stifle", [MmReference.to_object(Scenario.stack_ids(engine)[0])]), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Parcel"), -1, "Costs paid stay paid.")
	assert_eq(engine.game_state().object(ogre).damage_marked, 0)


func test_an_indestructible_permanent_is_still_sacrificed() -> void:
	var engine: MmEngine = _hero_main([Scenario.parcel("Parcel", [IndestructibleAbility.new()])], [Scenario.creature("Ogre", 2, 4)])
	var parcel: int = Scenario.permanent_named(engine, engine.hero().id, "Parcel")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	Scenario.activate(engine, parcel, [MmReference.to_object(ogre)])

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Parcel"), -1, "CR 701.21a: not destruction.")


func test_a_sacrificed_creature_dies() -> void:
	var offering: ActivatedAbility = Scenario.activated(Scenario.mana_cost(0), [SacrificeThisCost.new()],
		[Scenario.gain_life(1, Scenario.you())])
	var dying: TriggeredAbility = Scenario.triggered(Scenario.dies(IsSourceFilter.new()), [Scenario.gain_life(2, Scenario.you())])
	var engine: MmEngine = _hero_main([Scenario.creature("Martyr", 1, 1, [offering, dying])], [])

	assert_eq(Scenario.activate(engine, Scenario.permanent_named(engine, engine.hero().id, "Martyr")), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 23, "CR 700.4: put into a graveyard from the battlefield, so it dies.")


func test_a_creature_with_summoning_sickness_may_be_sacrificed() -> void:
	var offering: ActivatedAbility = Scenario.activated(Scenario.mana_cost(0), [SacrificeThisCost.new()],
		[Scenario.gain_life(1, Scenario.you())])
	var engine: MmEngine = _hero_main([], [], [Scenario.creature("Martyr", 1, 1, [offering])])
	Scenario.cast_and_resolve(engine, "Martyr")

	assert_eq(Scenario.activate(engine, Scenario.permanent_named(engine, engine.hero().id, "Martyr")), "",
		"CR 302.6: only {T} and {Q} wait for it.")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 21)


func test_it_cannot_be_paid_for_a_permanent_its_payer_does_not_control() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.parcel()])
	var theirs: MmGameObject = engine.game_state().object(Scenario.permanent_named(engine, engine.villain().id, "Parcel"))

	assert_false(SacrificeThisCost.new().can_pay(engine.game_state(), theirs, engine.hero().id), "CR 701.21a")
	assert_true(SacrificeThisCost.new().can_pay(engine.game_state(), theirs, engine.villain().id))


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
