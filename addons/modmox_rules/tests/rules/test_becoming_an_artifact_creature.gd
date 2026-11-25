extends GutTest
## "Target noncreature artifact you control becomes a 0/0 artifact creature. Put four +1/+1
## counters on it.", as Bring to Life says (engine ADR 0091): a card type added in layer 4,
## keeping its other types (CR 205.1b), and a base power and toughness, each from a resolved
## spell with no duration, so they last for the rest of the encounter (CR 611.2a), on that
## object only. Trinkets are artifacts costing {0} that tap for {W}; Animate is Bring to Life
## as a sorcery costing {0}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_it_becomes_a_four_four_artifact_creature_keeping_its_types_and_abilities() -> void:
	var engine: MmEngine = _hero_main([_trinket()], [Scenario.free_animate()])
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")

	assert_eq(Scenario.cast_and_resolve(engine, "Animate", [_object(trinket)]), "")

	var now: MmCharacteristics = Scenario.now(engine, trinket)
	assert_eq(now.card_types, [CardType.ARTIFACT, CardType.CREATURE] as Array[CardType])
	assert_eq(Scenario.pt(engine, trinket), [4, 4], "Base 0/0 with four +1/+1 counters.")
	assert_eq(now.abilities.size(), 1, "It keeps its mana ability.")


func test_it_lasts_beyond_the_turn() -> void:
	var engine: MmEngine = _hero_main([_trinket()], [Scenario.free_animate()])
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")
	assert_eq(Scenario.cast_and_resolve(engine, "Animate", [_object(trinket)]), "")

	Scenario.play_until_game_turn(engine, 5)

	assert_true(Scenario.now(engine, trinket).has_card_type(CardType.CREATURE), "CR 611.2a: no duration, no end.")
	assert_eq(Scenario.pt(engine, trinket), [4, 4])


func test_controlled_since_the_turn_began_it_can_attack_the_turn_it_becomes_a_creature() -> void:
	# CR 302.6: what matters is how long it has been under its controller's control.
	var engine: MmEngine = _hero_main([_trinket()], [Scenario.free_animate()])
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")
	assert_eq(Scenario.cast_and_resolve(engine, "Animate", [_object(trinket)]), "")

	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)

	var attackers: DeclareAttackersDecision = engine.pending_decision() as DeclareAttackersDecision
	assert_not_null(attackers)
	assert_true(attackers.candidate_ids.has(trinket))


func test_once_it_leaves_and_comes_back_it_is_a_new_object_and_no_creature() -> void:
	var engine: MmEngine = _hero_main([_trinket()], [Scenario.free_animate(), Scenario.free_bounce("Bounce")])
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")
	assert_eq(Scenario.cast_and_resolve(engine, "Animate", [_object(trinket)]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [_object(trinket)]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Trinket"), "")

	var again: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")
	assert_ne(again, trinket, "ADR 0008.")
	assert_false(Scenario.now(engine, again).has_card_type(CardType.CREATURE))


func test_an_equipment_that_becomes_a_creature_becomes_unattached() -> void:
	# CR 301.5c, 704.5n: an Equipment that is also a creature can't equip a creature.
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword")], [Scenario.free_animate()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	assert_eq(Scenario.equip_and_resolve(engine, sword, bear), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Animate", [_object(sword)]), "")

	assert_eq(Scenario.attached_to(engine, sword), 0)
	assert_eq(Scenario.pt(engine, sword), [4, 4])
	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_a_creature_already_is_no_target() -> void:
	var engine: MmEngine = _hero_main([_trinket(), _bear()], [Scenario.free_animate()])
	var card: int = Scenario.card_in_hand(engine, engine.hero(), "Animate")

	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, card)), "")

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_eq(decision.candidates.size(), 1, "Only the Trinket: the Bear is a creature already.")
	assert_eq(decision.candidates[0].id, Scenario.permanent_named(engine, engine.hero().id, "Trinket"))


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_becoming_an_artifact_creature.tres"
	assert_eq(ResourceSaver.save(Scenario.free_animate(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var becomes: CreateContinuousEffect = (loaded.abilities[0] as SpellAbility).effects[0] as CreateContinuousEffect
	assert_eq(becomes.duration, CreateContinuousEffect.Duration.INDEFINITELY)
	assert_eq((becomes.continuous as AddCardTypesContinuousEffect).card_types,
		[CardType.ARTIFACT, CardType.CREATURE] as Array[CardType])
	DirAccess.remove_absolute(path)


func _trinket() -> MmCardDefinition:
	return Scenario.artifact("Trinket", [Scenario.tap_for_mana(MmMana.Type.WHITE, 1)])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var none: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, none, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, none, hand, none, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
