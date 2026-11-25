extends GutTest
## "Whenever one or more other creatures you control leave the battlefield without dying"
## (CR 603.2, 603.6c, 700.4), as Dour Port-Mage's: a ZoneChangeTrigger from the battlefield
## to any zone but the graveyard (is_except_to_zone), triggering once for every move of one
## batch that matches (is_one_or_more, an occasion as ADR 0082 has them). It looks back, so
## the creatures are seen as they were on the battlefield.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_returned_to_its_owners_hand_triggers_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.port_mage(), _bear()], [_unsummon()])

	_cast_at(engine, "Unsummon", Scenario.permanent_named(engine, engine.hero().id, "Bear"))
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Port-Mage"), 1)


func test_two_creatures_leaving_at_once_trigger_it_once() -> void:
	var evacuate: MmCardDefinition = Scenario.instant("Evacuate", Scenario.mana_cost(0), [],
		[Scenario.return_to_hand(Scenario.each(Scenario.other_creature_you_control()))])
	var engine: MmEngine = _hero_main([Scenario.port_mage(), _bear(), _bear("Second Bear")], [evacuate])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Evacuate")), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Bear"), [] as Array[int])
	assert_eq(_triggers_of(engine, "Port-Mage"), 1, "One or more: both left in one batch.")


func test_two_creatures_leaving_apart_trigger_it_twice() -> void:
	var engine: MmEngine = _hero_main([Scenario.port_mage(), _bear(), _bear("Second Bear")], [_unsummon(), _unsummon("Second Unsummon")])

	_cast_at(engine, "Unsummon", Scenario.permanent_named(engine, engine.hero().id, "Bear"))
	assert_eq(Scenario.resolve_stack(engine), "")
	_cast_at(engine, "Second Unsummon", Scenario.permanent_named(engine, engine.hero().id, "Second Bear"))
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Port-Mage"), 2)


func test_an_exiled_token_triggers_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.port_mage()], [Scenario.free_tokens("Kittens", Scenario.cat()), Scenario.exile_spell("Banish")])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Kittens")), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]

	_cast_at(engine, "Banish", cat)
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Port-Mage"), 1, "Exiled, not died.")


func test_a_creature_that_dies_triggers_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.port_mage(), _bear()], [Scenario.free_shock("Zap", 2)])

	_cast_at(engine, "Zap", Scenario.permanent_named(engine, engine.hero().id, "Bear"))
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Bear"), -1, "CR 700.4: it died.")
	assert_eq(_triggers_of(engine, "Port-Mage"), 0)


func test_it_leaving_itself_triggers_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.port_mage(), _bear()], [_unsummon()])

	_cast_at(engine, "Unsummon", Scenario.permanent_named(engine, engine.hero().id, "Port-Mage"))
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Port-Mage"), 0, "Other creatures only.")


func test_an_opponents_creature_leaving_triggers_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.port_mage()], [_unsummon()], [Scenario.creature("Ogre", 3, 3)])

	_cast_at(engine, "Unsummon", Scenario.permanent_named(engine, engine.villain().id, "Ogre"))
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Port-Mage"), 0, "Creatures you control only.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_leave_without_dying.tres"
	assert_eq(ResourceSaver.save(Scenario.port_mage(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var trigger: ZoneChangeTrigger = (loaded.abilities[0] as TriggeredAbility).trigger as ZoneChangeTrigger
	assert_true(trigger.is_one_or_more)
	assert_true(trigger.is_except_to_zone)
	assert_eq(trigger.to_zone, MmZone.Kind.GRAVEYARD)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


func _bear(card_name: String = "Bear") -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 2)


## An instant costing {0}: "Return target creature to its owner's hand."
func _unsummon(card_name: String = "Unsummon") -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.return_to_hand(Scenario.targeted(0))])


## Casts the Hero's [param card_name] at the object [param target_id].
func _cast_at(engine: MmEngine, card_name: String, target_id: int) -> void:
	var card: int = Scenario.card_in_hand(engine, engine.hero(), card_name)
	assert_eq(Scenario.cast(engine, card, [MmReference.to_object(target_id)]), "")


## How many times an ability of a permanent named [param card_name] has triggered.
func _triggers_of(engine: MmEngine, card_name: String) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if (event as AbilityTriggeredEvent).pending.source_name == card_name:
			count += 1
	return count


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand]; the Villain cast [param villain_permanents] on Game Turn 2.
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
