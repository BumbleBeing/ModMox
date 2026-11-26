extends GutTest
## The Role rule (CR 303.7, a state-based action): when a permanent has more than one Role
## controlled by the same player attached to it, each but the newest is put into its owner's
## graveyard. Roles of different players, and other Auras, stay. Price is an instant costing
## {0}, "Create a Wicked Role token attached to target creature you control."; its Wicked
## Role, made in code, has "Enchanted creature gets +1/+1" and "When this Aura is put into a
## graveyard, each opponent loses 1 life."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_a_second_role_of_the_same_player_puts_the_first_into_the_graveyard() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_role("Price"), Scenario.free_role("Second Price")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_and_resolve(engine, "Price", [MmReference.to_object(bear)]), "")
	var first: int = Scenario.tokens_on_battlefield(engine)[0]

	assert_eq(Scenario.cast_and_resolve(engine, "Second Price", [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var roles: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(roles.size(), 1)
	assert_gt(roles[0], first, "The newest stays.")
	assert_eq(Scenario.pt(engine, bear), [3, 3], "One +1/+1, not two.")
	assert_eq(engine.villain().life, 19, "The first Role's ability triggered as it went.")
	var moved: Array[MmEvent] = Scenario.events_of(engine, ZoneChangeEvent).filter(func(event: MmEvent) -> bool:
		return (event as ZoneChangeEvent).object_id == first)
	assert_eq((moved[0] as ZoneChangeEvent).reason, ZoneChangeEvent.Reason.ROLE_RULE)


func test_roles_of_different_players_on_one_creature_both_stay() -> void:
	var anyones: MmCardDefinition = Scenario.instant("Gift Role", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))], [Scenario.created_attached(Scenario.role(), Scenario.targeted(0))])
	var engine: MmEngine = _hero_main([Scenario.free_role()], [anyones])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_and_resolve(engine, "Price", [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.play_until_step(engine, 4, Step.PRECOMBAT_MAIN), "")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Gift Role"), [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 2)
	assert_eq(Scenario.pt(engine, bear), [4, 4])


func test_another_aura_beside_a_role_stays() -> void:
	var halo: MmCardDefinition = Scenario.aura("Halo", Scenario.of_type(MmCardTypes.CardType.CREATURE))
	var engine: MmEngine = _hero_main([Scenario.free_role(), halo])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_and_resolve(engine, "Halo", [MmReference.to_object(bear)]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Price", [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Halo"), -1)
	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 1)


## The Hero in their main phase of Game Turn 3 with a 2/2 Bear cast on Game Turn 1, holding
## [param hero_extras]; the Villain holds [param villain_extras].
func _hero_main(hero_extras: Array[MmCardDefinition], villain_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var bears: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2)]
	var setup: MmEncounterSetup = Scenario.combat_setup(bears, NO_CARDS, hero_extras, villain_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, bears, NO_CARDS, hero_extras, villain_extras,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
