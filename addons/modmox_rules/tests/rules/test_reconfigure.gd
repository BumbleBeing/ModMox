extends GutTest
## Reconfigure (CR 702.151): "[Cost]: Attach this permanent to another target creature you
## control. Activate only as a sorcery" and "[Cost]: Unattach this permanent. Activate only
## if this permanent is attached to a creature and only as a sorcery." While attached, an
## Equipment with reconfigure isn't a creature (CR 702.151b), and only one with reconfigure
## may be attached while it is a creature (CR 301.5c).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType

## The Sash's abilities: its bonus, then reconfigure's two.
const ATTACH: int = 1
const UNATTACH: int = 2


func test_reconfigure_attaches_it_and_it_is_no_longer_a_creature_or_a_cat() -> void:
	# CR 702.151b, CR 205.1b.
	var engine: MmEngine = _hero_main([_bear(), Scenario.sash()], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")
	assert_true(_types(engine, sash).has_card_type(CardType.CREATURE), "Unattached, it is a creature.")

	assert_eq(Scenario.equip_and_resolve(engine, sash, bear), "")

	assert_eq(Scenario.attached_to(engine, sash), bear)
	assert_false(_types(engine, sash).has_card_type(CardType.CREATURE))
	assert_true(_types(engine, sash).has_card_type(CardType.ARTIFACT))
	assert_eq(_types(engine, sash).subtypes, ["Equipment"] as Array[String], "It loses its creature type, Cat.")
	assert_eq(Scenario.pt(engine, bear), [3, 3])
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sash"), [sash], "It stays the same object.")


func test_an_attached_one_still_makes_its_creature_equipped() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.kemba(), Scenario.sash()], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")

	Scenario.equip_and_resolve(engine, sash, bear)

	assert_eq(Scenario.pt(engine, bear), [4, 4], "+1/+1 from the Sash and +1/+1 from Kemba for being equipped.")


func test_reconfigure_targets_only_another_creature_its_controller_controls() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.sash()], [_wolf()], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")

	assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sash)), "")

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	assert_eq(decision.candidates.map(func(found: MmReference) -> int: return found.id), [bear])


func test_with_no_other_creature_reconfigure_is_not_offered() -> void:
	var engine: MmEngine = _hero_main([Scenario.sash()], [_wolf()], [])
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sash), -1)


func test_reconfigure_is_only_a_sorcery_even_with_instant_speed_equip() -> void:
	# Reconfigure is not an equip ability, so Leonin Shikari does not lift its restriction.
	var engine: MmEngine = Scenario.combat_ready([_bear(), _shikari(), Scenario.sash()], [])
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")
	Scenario.declare_attackers(engine, [])

	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		var decision: PriorityDecision = running.pending_decision() as PriorityDecision
		return decision != null and decision.player_id == running.hero().id \
			and not running.game_state().step in [Step.PRECOMBAT_MAIN, Step.POSTCOMBAT_MAIN])

	assert_ne(engine.game_state().step, Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sash), -1)


func test_unattach_is_offered_only_while_it_is_attached() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.sash()], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")
	assert_ne(Scenario.activate_ability(engine, sash, UNATTACH), "", "Unattached, there is nothing to unattach.")

	Scenario.equip_and_resolve(engine, sash, bear)

	assert_eq(Scenario.activate_ability(engine, sash, UNATTACH), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.attached_to(engine, sash), 0)
	assert_true(_types(engine, sash).has_card_type(CardType.CREATURE), "Unattached, it is a creature again.")
	assert_eq(_types(engine, sash).subtypes, ["Equipment", "Cat"] as Array[String])
	assert_eq(Scenario.pt(engine, sash), [1, 1])
	assert_eq(Scenario.pt(engine, bear), [2, 2])
	assert_eq(Scenario.events_of(engine, UnattachedEvent).size(), 1)


func test_an_attached_one_can_reconfigure_onto_another_creature() -> void:
	var engine: MmEngine = _hero_main([_bear(), _ogre(), Scenario.sash()], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.hero().id, "Ogre")
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")
	Scenario.equip_and_resolve(engine, sash, bear)

	assert_eq(Scenario.equip_and_resolve(engine, sash, ogre), "")

	assert_eq(Scenario.attached_to(engine, sash), ogre)
	assert_eq(Scenario.pt(engine, bear), [2, 2])
	assert_eq(Scenario.pt(engine, ogre), [5, 5])


func test_when_its_creature_dies_it_is_unattached_and_a_creature_again() -> void:
	# CR 704.5n.
	var engine: MmEngine = _hero_main([_bear(), Scenario.sash()], [], [Scenario.free_destroy("Murder")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")
	Scenario.equip_and_resolve(engine, sash, bear)

	Scenario.cast_and_resolve(engine, "Murder", [_object(bear)])

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sash"), [sash])
	assert_eq(Scenario.attached_to(engine, sash), 0)
	assert_true(_types(engine, sash).has_card_type(CardType.CREATURE))


func test_an_equipment_creature_without_reconfigure_is_not_attached() -> void:
	# CR 301.5c: an Equipment that's also a creature can't equip a creature unless it has
	# reconfigure.
	var engine: MmEngine = _hero_main([_bear(), Scenario.equipment_creature("Golem", 1, 1)], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var golem: int = Scenario.permanent_named(engine, engine.hero().id, "Golem")

	assert_eq(Scenario.equip_and_resolve(engine, golem, bear), "")

	assert_eq(Scenario.attached_to(engine, golem), 0)


func test_an_equipment_on_it_falls_off_once_it_is_attached_and_no_longer_a_creature() -> void:
	# CR 704.5n: an Equipment attached to a permanent that is not a creature.
	var engine: MmEngine = _hero_main([_bear(), Scenario.sash(), Scenario.sword("Sword")], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, sash)
	assert_eq(Scenario.pt(engine, sash), [2, 2])

	Scenario.equip_and_resolve(engine, sash, bear)

	assert_eq(Scenario.attached_to(engine, sash), bear)
	assert_eq(Scenario.attached_to(engine, sword), 0)


func test_reconfigure_is_saved_with_its_card() -> void:
	var definition: MmCardDefinition = Scenario.sash()
	var path: String = "user://test_reconfigure_sash.tres"

	assert_eq(ResourceSaver.save(definition, path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition
	var attach: ReconfigureAbility = loaded.abilities[ATTACH] as ReconfigureAbility
	var unattach: ReconfigureAbility = loaded.abilities[UNATTACH] as ReconfigureAbility
	assert_false(attach.unattaches)
	assert_true(attach.effects[0] is AttachEffect)
	assert_eq(attach.targets.size(), 1)
	assert_true(unattach.unattaches)
	assert_true(unattach.effects[0] is UnattachEffect)
	assert_true(unattach.is_only_while_attached)
	assert_true(unattach.targets.is_empty())
	DirAccess.remove_absolute(path)


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _types(engine: MmEngine, object_id: int) -> MmCharacteristics:
	return engine.game_state().characteristics_of(engine.game_state().object(object_id))


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _wolf() -> MmCardDefinition:
	return Scenario.creature("Wolf", 3, 3)


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 4, 4)


func _shikari() -> MmCardDefinition:
	return Scenario.creature("Shikari", 2, 2, [Scenario.instant_speed_equip()])


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
