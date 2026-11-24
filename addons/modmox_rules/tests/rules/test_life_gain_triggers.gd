extends GutTest
## "Whenever [whose] gain(s) life" (CR 119.9, 603.2, ADR 0082), as Unflinching Hortimancer's
## "Whenever you gain life, put a +1/+1 counter on this creature." Each source a player gains
## life from is its own life gain (CR 119.9), so a GainLifeEffect is one and so is each source
## with lifelink dealing damage (CR 120.3f): two lifelink creatures dealing combat damage at
## once trigger it twice, but one dealing damage to several recipients at once triggers it
## once. Gaining no life is no life gain.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const Whose := MmTrigger.Whose
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_gaining_life_from_an_effect_triggers_it_once_and_that_player_is_the_gainer() -> void:
	var engine: MmEngine = _hero_main([Scenario.life_watcher()], [_gift("Gift", 3)])

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	var stack: Array[int] = Scenario.stack_ids(engine)
	assert_eq(stack.size(), 1)
	assert_eq(engine.game_state().object(stack[0]).triggering_player_id, engine.hero().id)
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.counters_on(engine, _watcher(engine), PLUS), 1)


func test_gaining_no_life_triggers_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.life_watcher()], [_gift("Nothing", 0)])

	assert_eq(Scenario.cast_and_resolve(engine, "Nothing"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Life Watcher"), 0, "CR 119.9: no life gain event.")


func test_an_opponent_gaining_life_does_not_trigger_you_and_does_trigger_an_opponent() -> void:
	var theirs: MmCardDefinition = Scenario.enchantment("Envy", [Scenario.triggered(Scenario.life_gained(Whose.OPPONENT),
		[Scenario.draw_cards(1, Scenario.you())])])
	var gift: MmCardDefinition = Scenario.instant("Their Gift", Scenario.mana_cost(0), [],
		[Scenario.gain_life(2, EachOpponentSelection.new())])
	var engine: MmEngine = _hero_main([Scenario.life_watcher(), theirs], [gift])

	assert_eq(Scenario.cast_and_resolve(engine, "Their Gift"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.villain().life, 22)
	assert_eq(_triggers_of(engine, "Life Watcher"), 0, "The Villain gained it, not the Hero.")
	assert_eq(_triggers_of(engine, "Envy"), 1)


func test_lifelink_combat_damage_triggers_it() -> void:
	var engine: MmEngine = Scenario.combat_ready([_cleric("Cleric"), Scenario.life_watcher()], [])
	assert_eq(Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Cleric")]), "")

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 23)
	assert_eq(_triggers_of(engine, "Life Watcher"), 1)
	assert_eq(Scenario.counters_on(engine, _watcher(engine), PLUS), 1)


func test_two_lifelink_creatures_dealing_combat_damage_at_once_trigger_it_twice() -> void:
	# CR 119.9: each source is a life gain of its own.
	var engine: MmEngine = Scenario.combat_ready([_cleric("Cleric"), _cleric("Acolyte"), Scenario.life_watcher()], [])
	var attackers: Array[int] = [Scenario.permanent_named(engine, engine.hero().id, "Cleric"),
		Scenario.permanent_named(engine, engine.hero().id, "Acolyte")]
	assert_eq(Scenario.declare_attackers(engine, attackers), "")

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 26)
	assert_eq(_triggers_of(engine, "Life Watcher"), 2)
	assert_eq(Scenario.counters_on(engine, _watcher(engine), PLUS), 2)


func test_one_lifelink_source_dealing_damage_to_two_recipients_at_once_triggers_it_once() -> void:
	# "When this creature enters, it deals 1 damage to each creature an opponent controls."
	var theirs: ControlledByFilter = ControlledByFilter.new()
	theirs.whose = Whose.OPPONENT
	var enters: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.deal_damage(1, Scenario.each_creature(theirs))])
	var zealot: MmCardDefinition = Scenario.creature("Zealot", 1, 1, [LifelinkAbility.new(), enters])
	var engine: MmEngine = _hero_main([Scenario.life_watcher()], [zealot], [Scenario.creature("Ogre", 3, 3), Scenario.creature("Troll", 3, 3)])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Zealot"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 2, "1 from each damage.")
	assert_eq(_triggers_of(engine, "Life Watcher"), 1, "CR 119.9: one source, at once, is one life gain.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_life_gain_triggers.tres"
	var card: MmCardDefinition = Scenario.enchantment("Envy", [Scenario.triggered(Scenario.life_gained(Whose.ANY), [Scenario.draw_cards(1, Scenario.you())])])
	assert_eq(ResourceSaver.save(card, path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var trigger: LifeGainedTrigger = (loaded.abilities[0] as TriggeredAbility).trigger as LifeGainedTrigger
	assert_not_null(trigger)
	assert_eq(trigger.whose, Whose.ANY)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


func _cleric(card_name: String) -> MmCardDefinition:
	return Scenario.creature(card_name, 3, 3, [LifelinkAbility.new()])


## An instant costing {0}: "You gain [param amount] life."
func _gift(card_name: String, amount: int) -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(0), [], [Scenario.gain_life(amount, Scenario.you())])


func _watcher(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Life Watcher")


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
