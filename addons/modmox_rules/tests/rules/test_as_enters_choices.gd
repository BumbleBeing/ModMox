extends GutTest
## "As this enchantment enters, choose a creature type" (CR 614.1c, 614.12): the choice is
## asked as the permanent spell resolves, before it enters, and carried on its zone change,
## so it is on the permanent from the moment it arrives (ADR 0052). "Creatures you control
## of the chosen type get +1/+1" reads it through IsOfChosenTypeFilter.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_as_it_resolves_its_controller_is_asked_for_a_creature_type_before_it_enters() -> void:
	var engine: MmEngine = _main_with([Scenario.mouser()], [Scenario.rally()])
	var rally: int = Scenario.card_in_hand(engine, engine.hero(), "Rally")

	Scenario.cast_and_resolve(engine, "Rally")

	var decision: ChooseCreatureTypeDecision = engine.pending_decision() as ChooseCreatureTypeDecision
	assert_not_null(decision, "CR 614.12: the choice is made as it enters.")
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.creature_types, CreatureTypes.ALL, "Every creature type (CR 205.3m).")
	assert_eq(decision.creature_types.size(), 377)
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Rally"), [], "Not on the battlefield yet.")
	assert_eq(engine.game_state().stack.size(), 1, "Still on the stack.")
	assert_ne(decision.stack_object_id, rally, "The spell, a new object (ADR 0008).")
	assert_eq(engine.game_state().object(decision.stack_object_id).zone(), engine.game_state().stack)


func test_choosing_cat_gives_the_cats_you_control_plus_one_plus_one() -> void:
	var lion: MmCardDefinition = Scenario.typed_creature("Lion", 2, 1, ["Cat"])
	var engine: MmEngine = _main_with([lion, Scenario.elf()], [Scenario.rally()], [Scenario.typed_creature("Wild Cat", 1, 1, ["Cat"])])
	var hero_cat: int = Scenario.permanent_named(engine, engine.hero().id, "Lion")
	var elf: int = Scenario.permanent_named(engine, engine.hero().id, "Elf")
	var villain_cat: int = Scenario.permanent_named(engine, engine.villain().id, "Wild Cat")
	Scenario.cast_and_resolve(engine, "Rally")

	assert_eq(Scenario.choose_creature_type(engine, "Cat"), "")

	assert_eq(Scenario.pt(engine, hero_cat), [3, 2])
	assert_eq(Scenario.pt(engine, elf), [1, 1], "Not a Cat.")
	assert_eq(Scenario.pt(engine, villain_cat), [1, 1], "Only creatures you control.")


func test_cat_tokens_you_control_get_the_bonus_too() -> void:
	var engine: MmEngine = _main_with([], [Scenario.rally(), Scenario.free_tokens("Kittens", Scenario.cat(), 2)])
	Scenario.cast_and_resolve(engine, "Kittens")
	Scenario.cast_and_resolve(engine, "Rally")

	Scenario.choose_creature_type(engine, "Cat")

	for token: int in Scenario.tokens_on_battlefield(engine):
		assert_eq(Scenario.pt(engine, token), [2, 2])


func test_the_chosen_type_is_on_the_permanent_as_it_arrives() -> void:
	var engine: MmEngine = _main_with([Scenario.mouser()], [Scenario.rally()])
	Scenario.cast_and_resolve(engine, "Rally")

	Scenario.choose_creature_type(engine, "Cat")

	var moved: ZoneChangeEvent = _last_move_onto_battlefield(engine)
	assert_eq(moved.chosen_creature_type_on_arrival, "Cat", "Carried by the zone change (ADR 0052).")
	var rally: int = Scenario.permanent_named(engine, engine.hero().id, "Rally")
	assert_eq(moved.new_object_id, rally)
	assert_eq(engine.game_state().object(rally).chosen_creature_type, "Cat")


func test_an_enters_trigger_already_sees_the_bonus() -> void:
	# "Whenever an enchantment enters, you gain life equal to the number of 2/2 Cats you
	# control": the Mouser is 2/2 only once Rally's type is chosen.
	var watcher: MmCardDefinition = Scenario.enchantment("Watcher", [Scenario.triggered(
		Scenario.enters(Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT)), [_gain_life_per_big_cat()])])
	var engine: MmEngine = _main_with([Scenario.mouser(), watcher], [Scenario.rally()])
	var life: int = engine.hero().life
	Scenario.cast_and_resolve(engine, "Rally")

	Scenario.choose_creature_type(engine, "Cat")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 1)


func test_a_creature_made_a_cat_in_layer_four_gets_the_bonus() -> void:
	var yours: ControlledByFilter = ControlledByFilter.new()
	var catify: MmCardDefinition = Scenario.enchantment("Catify", [Scenario.continuous_static([
		Scenario.add_subtypes(["Cat"], Scenario.each(Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE), yours])))])])
	var engine: MmEngine = _main_with([Scenario.elf(), catify], [Scenario.rally()])
	var elf: int = Scenario.permanent_named(engine, engine.hero().id, "Elf")
	Scenario.cast_and_resolve(engine, "Rally")

	Scenario.choose_creature_type(engine, "Cat")

	assert_eq(Scenario.pt(engine, elf), [2, 2], "ADR 0018: the Filter sees layer 4.")


func test_two_rallies_naming_cat_and_warrior_give_a_cat_warrior_plus_two() -> void:
	var cat_warrior: MmCardDefinition = Scenario.typed_creature("Cat Warrior", 2, 2, ["Cat", "Warrior"])
	var engine: MmEngine = _main_with([cat_warrior, Scenario.mouser()], [Scenario.rally(), Scenario.rally("Second Rally")])
	var warrior: int = Scenario.permanent_named(engine, engine.hero().id, "Cat Warrior")
	var mouser: int = Scenario.permanent_named(engine, engine.hero().id, "Mouser")

	Scenario.cast_and_resolve(engine, "Rally")
	Scenario.choose_creature_type(engine, "Cat")
	Scenario.cast_and_resolve(engine, "Second Rally")
	Scenario.choose_creature_type(engine, "Warrior")

	assert_eq(Scenario.pt(engine, warrior), [4, 4])
	assert_eq(Scenario.pt(engine, mouser), [2, 2])


func test_bounced_and_recast_it_forgets_its_type_and_asks_again() -> void:
	var bounce: MmCardDefinition = Scenario.instant("Unsummon Enchantment", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT))], [Scenario.return_to_hand(Scenario.targeted(0))])
	var engine: MmEngine = _main_with([Scenario.mouser()], [Scenario.rally(), bounce])
	var mouser: int = Scenario.permanent_named(engine, engine.hero().id, "Mouser")
	Scenario.cast_and_resolve(engine, "Rally")
	Scenario.choose_creature_type(engine, "Cat")
	var rally: int = Scenario.permanent_named(engine, engine.hero().id, "Rally")

	Scenario.cast_and_resolve(engine, "Unsummon Enchantment", [MmReference.to_object(rally)])

	assert_eq(Scenario.pt(engine, mouser), [1, 1], "It left, so its bonus ended.")
	var in_hand: MmGameObject = engine.game_state().object(Scenario.card_in_hand(engine, engine.hero(), "Rally"))
	assert_eq(in_hand.chosen_creature_type, "", "ADR 0008: a new object remembers nothing.")
	Scenario.cast_and_resolve(engine, "Rally")
	assert_true(engine.pending_decision() is ChooseCreatureTypeDecision, "Asked again.")
	Scenario.choose_creature_type(engine, "Elf")
	assert_eq(Scenario.pt(engine, mouser), [1, 1])


func test_a_countered_rally_asks_nothing() -> void:
	var engine: MmEngine = _main_with([], [Scenario.rally(), Scenario.free_counter("Cancel")])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Rally"))
	var spell: int = Scenario.stack_ids(engine)[0]
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Cancel"), [MmReference.to_object(spell)])

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_true(engine.pending_decision() is PriorityDecision, "Countered, it never enters.")
	assert_true(Scenario.names(engine, engine.hero().graveyard).has("Rally"))


func test_an_answer_out_of_range_is_refused_and_changes_nothing() -> void:
	var engine: MmEngine = _main_with([], [Scenario.rally()])
	Scenario.cast_and_resolve(engine, "Rally")
	var before: String = engine.fingerprint()

	assert_ne(engine.submit(377), "")
	assert_ne(engine.submit(-1), "")
	assert_ne(engine.submit("Cat"), "")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is ChooseCreatureTypeDecision)


func test_the_chosen_type_is_part_of_the_fingerprint() -> void:
	var cat: MmEngine = _main_with([], [Scenario.rally()])
	var elf: MmEngine = _main_with([], [Scenario.rally()])
	Scenario.cast_and_resolve(cat, "Rally")
	Scenario.cast_and_resolve(elf, "Rally")

	Scenario.choose_creature_type(cat, "Cat")
	Scenario.choose_creature_type(elf, "Elf")

	assert_ne(cat.fingerprint(), elf.fingerprint())


func test_a_replay_of_the_decision_log_chooses_the_same_type() -> void:
	var setup: MmEncounterSetup = _setup([Scenario.mouser()], [Scenario.rally()])
	var original: MmEngine = _ready_from(setup, [Scenario.mouser()])
	Scenario.cast_and_resolve(original, "Rally")
	Scenario.choose_creature_type(original, "Cat")

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())
	var rally: int = Scenario.permanent_named(replayed, replayed.hero().id, "Rally")
	assert_eq(replayed.game_state().object(rally).chosen_creature_type, "Cat")


func test_a_simulation_copy_made_while_the_choice_is_pending_can_answer_it() -> void:
	var engine: MmEngine = _main_with([Scenario.mouser()], [Scenario.rally()])
	Scenario.cast_and_resolve(engine, "Rally")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(3), true)

	assert_true(copy.pending_decision() is ChooseCreatureTypeDecision)
	assert_eq(Scenario.choose_creature_type(copy, "Cat"), "")
	var rally: int = Scenario.permanent_named(copy, copy.hero().id, "Rally")
	assert_eq(copy.game_state().object(rally).chosen_creature_type, "Cat")
	assert_true(engine.pending_decision() is ChooseCreatureTypeDecision, "The real game is untouched.")
	assert_eq(Scenario.choose_creature_type(engine, "Elf"), "")
	var mouser: int = Scenario.permanent_named(engine, engine.hero().id, "Mouser")
	assert_eq(Scenario.pt(engine, mouser), [1, 1])


func test_a_copy_of_the_game_keeps_the_chosen_type() -> void:
	var engine: MmEngine = _main_with([Scenario.mouser()], [Scenario.rally()])
	Scenario.cast_and_resolve(engine, "Rally")
	Scenario.choose_creature_type(engine, "Cat")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(3), true)

	var mouser: int = Scenario.permanent_named(copy, copy.hero().id, "Mouser")
	assert_eq(Scenario.pt(copy, mouser), [2, 2])


func test_both_players_see_the_chosen_type() -> void:
	var engine: MmEngine = _main_with([], [Scenario.rally()])
	Scenario.cast_and_resolve(engine, "Rally")
	Scenario.choose_creature_type(engine, "Cat")
	var rally: int = Scenario.permanent_named(engine, engine.hero().id, "Rally")

	for player: MmPlayer in [engine.hero(), engine.villain()]:
		for seen: MmObjectView in engine.view_for(player).battlefield:
			if seen.id == rally:
				assert_eq(seen.chosen_creature_type, "Cat")


func test_an_object_with_no_chosen_type_matches_nothing() -> void:
	# A Rally that entered some other way, before any such way asks (ADR 0052).
	var engine: MmEngine = _main_with([Scenario.mouser(), Scenario.rally()], [])
	var mouser: int = Scenario.permanent_named(engine, engine.hero().id, "Mouser")
	var rally: int = Scenario.permanent_named(engine, engine.hero().id, "Rally")
	var filter: IsOfChosenTypeFilter = IsOfChosenTypeFilter.new()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, rally)

	# permanents_ready_with() answered with autoplay's default, the first type.
	assert_eq(engine.game_state().object(rally).chosen_creature_type, CreatureTypes.ALL[0])
	assert_false(filter.matches(engine.game_state(), MmReference.to_object(mouser), context))
	assert_false(filter.matches(engine.game_state(), MmReference.to_object(mouser), MmEffectContext.new(engine.hero().id, mouser)),
		"A source with no chosen type matches nothing.")


# --- Helpers ---------------------------------------------------------------------------


func _setup(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEncounterSetup:
	return Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)


func _ready_from(setup: MmEncounterSetup, hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition] = [],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


## The Hero's [param hero_permanents] and the Villain's [param villain_permanents] on the
## battlefield, with [param hero_extras] in the Hero's hand, in the Hero's main phase.
func _main_with(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	return _ready_from(_setup(hero_permanents, hero_extras, villain_permanents), hero_permanents, hero_extras, villain_permanents)


func _last_move_onto_battlefield(engine: MmEngine) -> ZoneChangeEvent:
	var found: ZoneChangeEvent = null
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved.to_zone_kind == MmZone.Kind.BATTLEFIELD:
			found = moved
	return found


## "You gain 1 life for each 2/2 Cat you control."
func _gain_life_per_big_cat() -> GainLifeEffect:
	var count: CountValue = CountValue.new()
	var yours: ControlledByFilter = ControlledByFilter.new()
	var big: PowerAtLeastFilterStandIn = PowerAtLeastFilterStandIn.new()
	count.selection = Scenario.each(Scenario.all_of([Scenario.has_subtype("Cat"), yours, big]))
	var effect: GainLifeEffect = Scenario.gain_life(1, Scenario.you())
	effect.amount = count
	return effect


## Matches a creature with power 2 or more, for one test only.
class PowerAtLeastFilterStandIn:
	extends MmFilter

	func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
		if not candidate.is_object():
			return false
		var game_object: MmGameObject = state.object(candidate.id)
		return game_object != null and state.characteristics_of(game_object).power >= 2
