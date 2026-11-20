extends GutTest
## "This land enters tapped." (CR 614.1c): a static ability whose replacement effect
## modifies how its own permanent enters, generated from the entering object's own
## characteristics (CR 614.12, ADR 0019). It applies however the permanent enters: played,
## resolved, found by a search or returned from a graveyard. It is on the zone change as
## "tapped" (ADR 0008), so the permanent is never tapped afterward and its "enters"
## abilities see it tapped.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Reason := ZoneChangeEvent.Reason
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_a_land_with_it_that_is_played_enters_tapped_and_untaps_as_usual() -> void:
	var engine: MmEngine = _hero_main([Scenario.tapped_dual_land("Swamp", "Forest")])
	var hero: MmPlayer = engine.hero()
	var in_hand: int = Scenario.card_in_hand(engine, hero, "Tapped Swamp Forest")

	assert_eq(engine.submit(Scenario.play_land_index(engine.pending_decision() as PriorityDecision, in_hand)), "")

	var land: int = Scenario.permanent_named(engine, hero.id, "Tapped Swamp Forest")
	assert_true(engine.game_state().object(land).is_tapped, "CR 614.1c")
	var plays: Array[ZoneChangeEvent] = _moves_with(engine, Reason.PLAY_LAND)
	assert_true(plays.back().tapped_on_arrival, "Tapped as it arrives.")
	assert_eq(_taps_of(engine, land), 0, "Never tapped afterward.")
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, land), -1,
		"Its mana abilities cost {T}, so it makes no mana this turn.")
	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")
	assert_false(engine.game_state().object(land).is_tapped, "CR 502.3: it untaps in its controller's untap step.")
	assert_eq(_mana_types_of(engine, land), [MmMana.Type.BLACK, MmMana.Type.GREEN] as Array[MmMana.Type],
		"CR 305.6: it taps for the mana of each of its basic land types.")


func test_a_land_with_it_found_by_a_search_enters_tapped_and_the_others_do_not() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_land_fetch()])
	var hero: MmPlayer = engine.hero()

	assert_eq(Scenario.fetch_lands(engine, ["Tapped Swamp Forest", "Forest"]), "")

	assert_true(engine.game_state().object(Scenario.permanent_named(engine, hero.id, "Tapped Swamp Forest")).is_tapped)
	assert_false(engine.game_state().object(Scenario.permanent_named(engine, hero.id, "Forest")).is_tapped,
		"It applies only to its own permanent.")


func test_a_land_with_it_on_the_battlefield_does_not_make_other_lands_enter_tapped() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_land_fetch(), Scenario.free_land_fetch("Late Fetch")])
	var hero: MmPlayer = engine.hero()
	assert_eq(Scenario.fetch_lands(engine, ["Tapped Swamp Forest"]), "")

	assert_eq(Scenario.fetch_lands(engine, ["Forest"], "Late Fetch"), "")

	assert_false(engine.game_state().object(Scenario.permanent_named(engine, hero.id, "Forest")).is_tapped)


func test_a_search_that_already_puts_it_onto_the_battlefield_tapped_taps_it_once_and_asks_nothing() -> void:
	var tapped_fetch: MmCardDefinition = Scenario.free_seek("Tapped Fetch",
		Scenario.search(Scenario.of_type(MmCardTypes.CardType.LAND), 6, MmZone.Kind.BATTLEFIELD, true, true))
	var engine: MmEngine = _hero_main([tapped_fetch])
	var hero: MmPlayer = engine.hero()

	assert_eq(Scenario.fetch_lands(engine, ["Tapped Swamp Forest", "Twice Tapped"], "Tapped Fetch"), "")

	for land_name: String in ["Tapped Swamp Forest", "Twice Tapped"]:
		var land: int = Scenario.permanent_named(engine, hero.id, land_name)
		assert_true(engine.game_state().object(land).is_tapped, land_name)
		assert_eq(_taps_of(engine, land), 0, land_name)


func test_two_of_the_ability_on_one_land_ask_nothing() -> void:
	# CR 616.1: it doesn't matter which applies first, so no choice is asked (A146).
	var engine: MmEngine = _hero_main([Scenario.free_land_fetch()])
	var hero: MmPlayer = engine.hero()

	assert_eq(Scenario.fetch_lands(engine, ["Twice Tapped"]), "")

	assert_true(engine.game_state().object(Scenario.permanent_named(engine, hero.id, "Twice Tapped")).is_tapped)


func test_a_creature_spell_with_it_resolves_tapped_and_its_enters_ability_sees_it_tapped() -> void:
	# CR 614.12: the replacement applies before the permanent is on the battlefield, so the
	# trigger's condition sees it tapped (CR 603.4).
	var sleeper: MmCardDefinition = Scenario.creature("Sleeper", 1, 1, [EntersTappedAbility.new(),
		Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.gain_life(3, Scenario.you())], [],
			Scenario.condition(SourceSelection.new(), IsTappedFilter.new()))])
	var engine: MmEngine = _hero_main([sleeper])
	var hero: MmPlayer = engine.hero()
	var life: int = hero.life

	assert_eq(Scenario.cast_and_resolve(engine, "Sleeper"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var creature: int = Scenario.permanent_named(engine, hero.id, "Sleeper")
	assert_true(engine.game_state().object(creature).is_tapped)
	assert_true(_moves_with(engine, Reason.RESOLVED).back().tapped_on_arrival)
	assert_eq(hero.life, life + 3)


func test_returned_from_a_graveyard_with_counters_it_enters_tapped_with_them() -> void:
	# ADR 0008: a new object, so it enters tapped again; the replaced zone change keeps
	# everything else it carried.
	var sleeper: MmCardDefinition = Scenario.creature("Sleeper", 1, 1, [EntersTappedAbility.new()])
	var back: ReturnToBattlefieldEffect = Scenario.return_to_battlefield(Scenario.targeted(0))
	back.counters = Scenario.constant(2)
	var reanimate: MmCardDefinition = Scenario.instant("Reanimate", Scenario.mana_cost(0), [Scenario.your_dead_creature()], [back])
	var engine: MmEngine = _hero_main([sleeper, Scenario.free_shock("Shock", 1), reanimate])
	var hero: MmPlayer = engine.hero()
	assert_eq(Scenario.cast_and_resolve(engine, "Sleeper"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(Scenario.permanent_named(engine, hero.id, "Sleeper"))]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Reanimate", [MmReference.to_object(Scenario.card_in_graveyard(engine, hero, "Sleeper"))]), "")

	var returned: int = Scenario.permanent_named(engine, hero.id, "Sleeper")
	assert_true(engine.game_state().object(returned).is_tapped)
	assert_eq(Scenario.counters_on(engine, returned, PLUS), 2)
	assert_true(_moves_with(engine, Reason.RETURN_TO_BATTLEFIELD).back().tapped_on_arrival)


func test_a_creature_type_chosen_as_it_enters_is_kept_when_it_enters_tapped() -> void:
	# ADR 0052: the choice is carried on the zone change that entering tapped replaces.
	var rally: MmCardDefinition = Scenario.rally("Sleepy Rally")
	rally.abilities.append(EntersTappedAbility.new())
	var engine: MmEngine = _hero_main([rally])
	var hero: MmPlayer = engine.hero()
	Scenario.cast_and_resolve(engine, "Sleepy Rally")

	assert_eq(Scenario.choose_creature_type(engine, "Cat"), "")

	var permanent: MmGameObject = engine.game_state().object(Scenario.permanent_named(engine, hero.id, "Sleepy Rally"))
	assert_true(permanent.is_tapped)
	assert_eq(permanent.chosen_creature_type, "Cat")


func test_a_copied_zone_change_keeps_everything_it_carries() -> void:
	# What entering tapped replaces must otherwise be the same move. Only what applying it
	# sets (the new object, its last known look and its batch) is left out.
	var engine: MmEngine = _hero_main([])
	var state: MmGameState = engine.game_state()
	var card: MmGameObject = engine.hero().hand.objects()[0]
	var move: ZoneChangeEvent = ZoneChangeEvent.new(card, state.battlefield, 0, Reason.RETURN_TO_BATTLEFIELD, false)
	move.exiled_with_object_id = 7
	move.cast_with_flashback = true
	move.counters_on_arrival = {PLUS: 2}
	move.tapped_on_arrival = true
	move.chosen_creature_type_on_arrival = "Cat"
	move.revealed = true

	var copy: ZoneChangeEvent = move.copy(state)

	assert_ne(copy, move)
	for property: Dictionary in move.get_property_list():
		var property_name: String = property["name"]
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not ["new_object_id", "last_known", "batch"].has(property_name):
			assert_eq(copy.get(property_name), move.get(property_name), property_name)


func _moves_with(engine: MmEngine, reason: Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == reason and moved.to_zone_kind == MmZone.Kind.BATTLEFIELD:
			found.append(moved)
	return found


func _taps_of(engine: MmEngine, object_id: int) -> int:
	return Scenario.events_of(engine, TapEvent).filter(func(event: MmEvent) -> bool:
		return (event as TapEvent).object_id == object_id).size()


## The mana each of [param object_id]'s mana abilities adds, in order.
func _mana_types_of(engine: MmEngine, object_id: int) -> Array[MmMana.Type]:
	var made: Array[MmMana.Type] = []
	for ability: MmAbility in engine.game_state().characteristics_of(engine.game_state().object(object_id)).abilities:
		var activated: ActivatedAbility = ability as ActivatedAbility
		if activated != null and activated.is_mana_ability():
			made.append((activated.effects[0] as AddManaEffect).mana_type)
	return made


## Stops in the Hero's precombat main phase of Game Turn 3, with no land played this turn
## and [param hero_extras] in hand. The Hero's library holds a Tapped Swamp Forest, a
## Forest, and Twice Tapped: a Swamp Forest with the ability twice.
func _hero_main(hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var twice: MmCardDefinition = Scenario.tapped_dual_land("Swamp", "Forest")
	twice.name = "Twice Tapped"
	twice.abilities.append(EntersTappedAbility.new())
	var lands: Array[MmCardDefinition] = [Scenario.tapped_dual_land("Swamp", "Forest"), Scenario.basic_land("Forest"), twice]
	var none: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(none, none, hero_extras + lands)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, none, none, hero_extras, none, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
