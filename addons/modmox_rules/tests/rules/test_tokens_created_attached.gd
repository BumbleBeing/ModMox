extends GutTest
## "Create [token] attached to [selection]" (CR 111.2, 303.4), as Price of Beauty's "Create
## a Wicked Role token attached to target creature you control": the Aura token enters the
## battlefield already attached, so it is never there unattached. One that could not legally
## be attached is never created (CR 303.4g). Price is an instant costing {0} with that
## ability; its Wicked Role, made in code, has "Enchant creature", "Enchanted creature gets
## +1/+1" and "When this Aura is put into a graveyard, each opponent loses 1 life."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_the_token_enters_attached_to_the_target_and_gives_its_bonus() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [Scenario.free_role()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Price", [MmReference.to_object(bear)]), "")

	var made: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(made.size(), 1)
	var role: MmGameObject = engine.game_state().object(made[0])
	assert_eq(role.attached_to_object_id, bear)
	assert_eq(role.controller_id, engine.hero().id)
	assert_true(engine.game_state().characteristics_of(role).subtypes.has("Role"))
	assert_eq(Scenario.pt(engine, bear), [3, 3])
	var created: Array[MmEvent] = Scenario.events_of(engine, TokenCreatedEvent)
	assert_eq((created.back() as TokenCreatedEvent).attached_to_on_arrival, bear)


func test_it_stays_attached_through_state_based_actions() -> void:
	# CR 704.5m: it is attached as it arrives, so it is never an Aura attached to nothing.
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [Scenario.free_role()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Price", [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 1)
	assert_eq(engine.villain().life, 20, "Never put into a graveyard.")


func test_an_enters_ability_sees_the_token_arrive() -> void:
	var watcher: MmCardDefinition = Scenario.enchantment("Watcher",
		[Scenario.triggered(Scenario.enters(Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT)), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2), watcher], [Scenario.free_role()])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Price",
		[MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Bear"))]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 1)


func test_a_token_that_could_not_be_attached_is_never_created() -> void:
	# CR 303.4g: an Aura with nothing it may legally enchant stays where it is; a token being
	# created has nowhere else to be, so it is never made, and nothing sees it go.
	var land_role: MmCardDefinition = Scenario.role("Land Role", Scenario.of_type(MmCardTypes.CardType.LAND))
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [Scenario.free_role("Price", land_role)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Price", [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 0)
	assert_eq(Scenario.pt(engine, bear), [2, 2])
	assert_eq(engine.villain().life, 20, "It was never put into a graveyard.")


func test_with_its_target_gone_the_spell_does_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [Scenario.free_role(), Scenario.free_destroy("Doom")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Price"), [MmReference.to_object(bear)]), "")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Doom"), [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 0)


func test_when_its_creature_dies_the_role_goes_to_the_graveyard_and_its_ability_triggers() -> void:
	# CR 704.5m puts the Aura into its owner's graveyard; it looks back (CR 603.10a), so the
	# token that then ceases to exist (CR 704.5d) still triggers.
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [Scenario.free_role(), Scenario.free_destroy("Doom")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_and_resolve(engine, "Price", [MmReference.to_object(bear)]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 0)
	assert_eq(engine.villain().life, 19, "Each opponent loses 1 life.")


## The Hero in their main phase of Game Turn 3, with [param hero_permanents] cast on Game
## Turn 1 and [param hero_extras] in hand.
func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, NO_CARDS, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, NO_CARDS, hero_extras, NO_CARDS,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
