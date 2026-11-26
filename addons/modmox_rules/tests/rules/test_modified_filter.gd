extends GutTest
## "Modified" (CR 700.9): a permanent with one or more counters on it, an Equipment attached,
## or an Aura its controller controls attached, as Akki Ember-Keeper's "Whenever a nontoken
## modified creature you control dies" reads it. A creature that dies is seen as it last
## existed (CR 603.10a), with the Equipment and Auras that were on it then, though an Aura
## destroyed with it has left too, and one that left before has nothing to do with it.
## Keeper is a 1/1 costing {0} with "Whenever a nontoken modified creature you control dies,
## you gain 1 life"; Charm an Aura costing {0} with "Enchant creature"; Sword an Equipment
## costing {0} with equip {0}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_with_a_counter_is_modified() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.free_counters("Grow", MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1)])
	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [_bear_ref(engine)]), "")

	assert_true(_is_modified(engine, _bear(engine)))
	assert_eq(_life_from_bear_dying(engine), 1)


func test_a_creature_with_a_minus_counter_is_modified_too() -> void:
	# CR 700.9: counters of any kind.
	var engine: MmEngine = _hero_main([], [Scenario.free_counters("Wither", MmCounter.Kind.MINUS_ONE_MINUS_ONE, 1)])
	assert_eq(Scenario.cast_and_resolve(engine, "Wither", [_bear_ref(engine)]), "")

	assert_true(_is_modified(engine, _bear(engine)))


func test_an_equipped_creature_is_modified() -> void:
	var engine: MmEngine = _hero_main([Scenario.sword("Sword")], [])
	assert_eq(Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), _bear(engine)), "")

	assert_true(_is_modified(engine, _bear(engine)))
	assert_eq(_life_from_bear_dying(engine), 1, "The Sword was still attached as it died.")


func test_a_creature_enchanted_by_its_controllers_aura_is_modified() -> void:
	var engine: MmEngine = _hero_main([], [_charm()])
	assert_eq(Scenario.cast_and_resolve(engine, "Charm", [_bear_ref(engine)]), "")

	assert_true(_is_modified(engine, _bear(engine)))
	assert_eq(_life_from_bear_dying(engine), 1)


func test_a_creature_enchanted_by_another_players_aura_is_not_modified() -> void:
	# CR 700.9: only an Aura controlled by the enchanted permanent's controller.
	var engine: MmEngine = _hero_main([], [_charm()])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(Scenario.cast_and_resolve(engine, "Charm", [MmReference.to_object(ogre)]), "")

	assert_false(_is_modified(engine, ogre), "The Hero's Charm on the Villain's Ogre.")


func test_a_creature_with_nothing_on_it_is_not_modified() -> void:
	var engine: MmEngine = _hero_main([], [])

	assert_false(_is_modified(engine, _bear(engine)))
	assert_eq(_life_from_bear_dying(engine), 0)


func test_a_creature_destroyed_together_with_its_aura_was_modified() -> void:
	# CR 603.10a: it is seen as it last existed, with the Aura that left in the same batch.
	var wrath: MmCardDefinition = Scenario.instant("Wrath", Scenario.mana_cost(0), [],
		[Scenario.destroy(Scenario.each(Scenario.any_of([Scenario.of_type(MmCardTypes.CardType.CREATURE), Scenario.has_subtype("Aura")])))])
	var engine: MmEngine = _hero_main([], [_charm(), wrath])
	assert_eq(Scenario.cast_and_resolve(engine, "Charm", [_bear_ref(engine)]), "")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Wrath"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Charm"), -1, "The Charm was destroyed too.")
	assert_eq(engine.hero().life, life + 1, "The Bear was modified; the Keeper, dying with it, was not.")


func test_an_aura_that_left_earlier_does_not_make_it_modified() -> void:
	var engine: MmEngine = _hero_main([], [_charm(), Scenario.free_disenchant("Disenchant")])
	assert_eq(Scenario.cast_and_resolve(engine, "Charm", [_bear_ref(engine)]), "")
	var charm: int = Scenario.permanent_named(engine, engine.hero().id, "Charm")
	assert_eq(Scenario.cast_and_resolve(engine, "Disenchant", [MmReference.to_object(charm)]), "")

	assert_false(_is_modified(engine, _bear(engine)))
	assert_eq(_life_from_bear_dying(engine), 0)


func test_a_card_off_the_battlefield_is_not_modified() -> void:
	var engine: MmEngine = _hero_main([], [])
	var card: int = engine.hero().hand.object_ids()[0]

	assert_false(_is_modified(engine, card))


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_modified_filter.tres"
	assert_eq(ResourceSaver.save(_keeper(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var trigger: ZoneChangeTrigger = (loaded.abilities[0] as TriggeredAbility).trigger as ZoneChangeTrigger
	assert_true((trigger.filter as AllOfFilter).filters[2] is ModifiedFilter)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## A 1/1 costing {0}: "Whenever a nontoken modified creature you control dies, you gain 1
## life."
func _keeper() -> MmCardDefinition:
	var dying: ZoneChangeTrigger = Scenario.dies(Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE),
		Scenario.is_not(IsTokenFilter.new()), ModifiedFilter.new()]))
	dying.whose = MmTrigger.Whose.YOU
	return Scenario.creature("Keeper", 1, 1, [Scenario.triggered(dying, [Scenario.gain_life(1, Scenario.you())])])


## An Aura costing {0}: "Enchant creature".
func _charm() -> MmCardDefinition:
	return Scenario.aura("Charm", Scenario.of_type(MmCardTypes.CardType.CREATURE))


## The Hero in their main phase of Game Turn 3 with the Keeper, a Bear and
## [param permanents] cast on Game Turn 1, holding [param hand] and a Doom, an instant costing
## {0} "Destroy target creature"; the Villain has an Ogre.
func _hero_main(permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var hero: Array[MmCardDefinition] = [_keeper(), Scenario.creature("Bear", 2, 2)]
	hero.append_array(permanents)
	var all_hand: Array[MmCardDefinition] = [Scenario.free_destroy("Doom")]
	all_hand.append_array(hand)
	var ogres: Array[MmCardDefinition] = [Scenario.creature("Ogre", 3, 3)]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(hero, ogres, all_hand),
		hero, ogres, all_hand, [] as Array[MmCardDefinition], 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _bear(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Bear")


func _bear_ref(engine: MmEngine) -> MmReference:
	return MmReference.to_object(_bear(engine))


func _is_modified(engine: MmEngine, object_id: int) -> bool:
	return ModifiedFilter.new().matches(engine.game_state(), MmReference.to_object(object_id),
		MmEffectContext.new(engine.hero().id, 0))


## The life the Hero gains as a Doom destroys the Bear.
func _life_from_bear_dying(engine: MmEngine) -> int:
	var life: int = engine.hero().life
	assert_eq(Scenario.cast_and_resolve(engine, "Doom", [_bear_ref(engine)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Bear"), -1, "The Bear died.")
	return engine.hero().life - life
