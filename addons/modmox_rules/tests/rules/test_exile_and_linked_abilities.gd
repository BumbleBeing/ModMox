extends GutTest
## Exiling (CR 701.13a), returning from exile to the battlefield, "leaves the battlefield"
## triggers (CR 603.6c, 603.10a), and linked abilities (CR 607.2a): "the exiled card" is
## only the card that this object's own ability exiled. The Prison is Oblivion Ring's two
## abilities on an enchantment costing {0}. A card that changes zones is a new object
## (ADR 0008), so the link is to the Prison as it was on the battlefield.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const Reason := ZoneChangeEvent.Reason


func test_it_exiles_another_target_nonland_permanent_into_its_owners_exile() -> void:
	var engine: MmEngine = _hero_main([], [_ogre()], [Scenario.free_prison("Prison")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	_ring(engine, "Prison", ogre)

	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Ogre"), -1)
	var exiled: Array[int] = Scenario.exiled_by_owner(engine, engine.villain())
	assert_eq(exiled.size(), 1)
	assert_eq(Scenario.now(engine, exiled[0]).name, "Ogre")
	var moves: Array[ZoneChangeEvent] = _moves_with(engine, Reason.EXILE)
	assert_eq(moves.size(), 1)
	assert_eq([moves[0].object_id, moves[0].from_zone_kind, moves[0].to_zone_kind], [ogre, MmZone.Kind.BATTLEFIELD, MmZone.Kind.EXILE])
	assert_eq(engine.game_state().object(exiled[0]).exiled_with_object_id, Scenario.permanent_named(engine, engine.hero().id, "Prison"),
		"CR 607.2a: the card remembers what exiled it.")


func test_its_trigger_never_offers_itself_or_a_land() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre()], [Scenario.free_prison("Prison"), Scenario.basic_land("Plains")])
	var plains: int = Scenario.play_first_land(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Prison"), "")

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	var offered: Array[int] = []
	for candidate: MmReference in decision.candidates:
		assert_true(candidate.is_object(), "Never a player.")
		offered.append(candidate.id)
	var expected: Array[int] = [Scenario.permanent_named(engine, engine.hero().id, "Bear"),
		Scenario.permanent_named(engine, engine.villain().id, "Ogre")]
	expected.sort()
	assert_eq(offered, expected, "Not the Prison itself, and not the Plains.")
	assert_false(offered.has(plains))


func test_with_no_other_nonland_permanent_its_trigger_is_removed() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_prison("Prison")])

	assert_eq(Scenario.cast_and_resolve(engine, "Prison"), "")

	assert_true(engine.pending_decision() is PriorityDecision, "CR 603.3d: no target, so it never goes on the stack.")
	assert_eq(Scenario.events_of(engine, TriggerRemovedEvent).size(), 1)
	assert_true(engine.game_state().stack.is_empty())


func test_when_it_leaves_the_exiled_card_returns_under_its_owners_control() -> void:
	var engine: MmEngine = _hero_main([], [_ogre()], [Scenario.free_prison("Prison"), Scenario.free_disenchant("Disenchant")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	_ring(engine, "Prison", ogre)
	var exiled: int = Scenario.exiled_by_owner(engine, engine.villain())[0]
	var prison: int = Scenario.permanent_named(engine, engine.hero().id, "Prison")

	assert_eq(Scenario.cast_and_resolve(engine, "Disenchant", [MmReference.to_object(prison)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Prison"), -1)
	var returned: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_ne(returned, -1, "The Ogre is back.")
	assert_true(returned != ogre and returned != exiled, "ADR 0008: a new object each time it moves.")
	var back: MmGameObject = engine.game_state().object(returned)
	assert_eq(back.controller_id, engine.villain().id, "Under its owner's control.")
	assert_false(back.is_tapped)
	assert_eq(back.controlled_since_game_turn, engine.game_state().game_turn, "CR 302.6: it has summoning sickness.")
	assert_eq(back.exiled_with_object_id, 0, "The link is only for a card in exile.")
	assert_eq(Scenario.exiled_by_owner(engine, engine.villain()).size(), 0)
	var moves: Array[ZoneChangeEvent] = _moves_with(engine, Reason.RETURN_TO_BATTLEFIELD)
	assert_eq(moves.size(), 1)
	assert_eq([moves[0].object_id, moves[0].from_zone_kind, moves[0].to_zone_kind, moves[0].to_owner_id],
		[exiled, MmZone.Kind.EXILE, MmZone.Kind.BATTLEFIELD, MmZone.NO_OWNER])


func test_a_returned_creatures_enters_trigger_fires_again() -> void:
	var herald: MmCardDefinition = Scenario.creature("Herald", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.gain_life(2, Scenario.you())])])
	var engine: MmEngine = _hero_main([], [herald], [Scenario.free_prison("Prison"), Scenario.free_disenchant("Disenchant")])
	_ring(engine, "Prison", Scenario.permanent_named(engine, engine.villain().id, "Herald"))
	var life: int = engine.villain().life

	Scenario.cast_and_resolve(engine, "Disenchant", [MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Prison"))])
	Scenario.resolve_stack(engine)

	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Herald"), -1)
	assert_eq(engine.villain().life, life + 2, "It entered the battlefield, so its own trigger fired.")


func test_destroyed_before_its_enters_trigger_resolves_the_card_is_exiled_for_good() -> void:
	var engine: MmEngine = _hero_main([], [_ogre()], [Scenario.free_prison("Prison"), Scenario.free_disenchant("Disenchant")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(Scenario.cast_and_resolve(engine, "Prison"), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(ogre)), "")
	var prison: int = Scenario.permanent_named(engine, engine.hero().id, "Prison")

	var disenchant: int = Scenario.card_in_hand(engine, engine.hero(), "Disenchant")
	assert_eq(Scenario.cast(engine, disenchant, [MmReference.to_object(prison)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Prison"), -1)
	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Ogre"), -1)
	assert_eq(Scenario.exiled_by_owner(engine, engine.villain()).size(), 1,
		"CR 607.2a: the leaves trigger resolved first and found nothing; then the Ogre was exiled.")
	assert_eq(_moves_with(engine, Reason.RETURN_TO_BATTLEFIELD).size(), 0)


func test_two_prisons_each_return_only_the_card_they_exiled() -> void:
	var engine: MmEngine = _hero_main([], [_ogre(), _goblin()],
		[Scenario.free_prison("Prison"), Scenario.free_prison("Cage"), Scenario.free_disenchant("Disenchant")])
	_ring(engine, "Prison", Scenario.permanent_named(engine, engine.villain().id, "Ogre"))
	_ring(engine, "Cage", Scenario.permanent_named(engine, engine.villain().id, "Goblin"))

	Scenario.cast_and_resolve(engine, "Disenchant", [MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Prison"))])
	Scenario.resolve_stack(engine)

	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Ogre"), -1)
	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Goblin"), -1)
	var exiled: Array[int] = Scenario.exiled_by_owner(engine, engine.villain())
	assert_eq(exiled.size(), 1)
	assert_eq(Scenario.now(engine, exiled[0]).name, "Goblin", "The Cage still holds it.")


func test_leaving_the_battlefield_triggers_on_dying_and_on_being_exiled() -> void:
	var ghost: MmCardDefinition = _leaver("Ghost")
	var spirit: MmCardDefinition = _leaver("Spirit")
	var no_cards: Array[MmCardDefinition] = []
	var extras: Array[MmCardDefinition] = [Scenario.free_destroy("Doom"), Scenario.exile_spell("Banish")]
	var setup: MmEncounterSetup = Scenario.combat_setup([ghost, spirit], no_cards, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, [ghost, spirit], no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	var ghost_id: int = Scenario.permanent_named(engine, engine.hero().id, "Ghost")
	var spirit_id: int = Scenario.permanent_named(engine, engine.hero().id, "Spirit")
	var life: int = engine.hero().life

	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(ghost_id)])
	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_eq(stacked[0].triggering_object_id, ghost_id, "CR 603.10a: it looked back at itself on the battlefield.")
	Scenario.resolve_stack(engine)
	Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(spirit_id)])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 4, "Two for going to the graveyard, two for going into exile.")


func test_an_activated_ability_never_offers_its_source_as_another_target() -> void:
	var engine: MmEngine = _hero_main([_mentor(), _bear()], [_ogre()], [])
	var mentor: int = Scenario.permanent_named(engine, engine.hero().id, "Mentor")

	assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, mentor)), "")

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	var offered: Array[int] = []
	for candidate: MmReference in decision.candidates:
		offered.append(candidate.id)
	var expected: Array[int] = [Scenario.permanent_named(engine, engine.hero().id, "Bear"),
		Scenario.permanent_named(engine, engine.villain().id, "Ogre")]
	expected.sort()
	assert_eq(offered, expected, "Targets are chosen with the Mentor as \"this\", as they are checked on resolution.")


func test_an_activated_ability_aimed_at_abilities_never_offers_itself() -> void:
	var muzzle: MmCardDefinition = Scenario.artifact("Muzzle", [_ability_with([Scenario.target_ability()],
		[Scenario.counter(Scenario.targeted(0))])])
	var engine: MmEngine = _hero_main([_mentor(), muzzle], [_ogre()], [])
	var mentor_ability: int = _activate_mentor_at_the_ogre(engine)

	var muzzle_id: int = Scenario.permanent_named(engine, engine.hero().id, "Muzzle")
	assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, muzzle_id)), "")

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	assert_eq(decision.candidates.size(), 1, "CR 115.5: not itself.")
	assert_eq(decision.candidates[0].id, mentor_ability)


func test_a_triggered_ability_aimed_at_abilities_never_offers_itself() -> void:
	var stifler: MmCardDefinition = Scenario.artifact("Stifler", [Scenario.triggered(
		Scenario.casts(null, MmTrigger.Whose.ANY), [Scenario.counter(Scenario.targeted(0))], [Scenario.target_ability()])])
	var engine: MmEngine = _hero_main([_mentor(), stifler], [_ogre()], [Scenario.free_shock("Shock", 1)])
	var mentor_ability: int = _activate_mentor_at_the_ogre(engine)

	var shock: int = Scenario.card_in_hand(engine, engine.hero(), "Shock")
	assert_eq(Scenario.cast(engine, shock, [MmReference.to_player(engine.villain().id)]), "")

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision, "The Stifler's trigger chooses its target.")
	assert_eq(decision.candidates.size(), 1, "CR 115.5: not itself, and never the Shock, which is a spell.")
	assert_eq(decision.candidates[0].id, mentor_ability)


func test_a_copy_and_a_replay_keep_the_link() -> void:
	var no_cards: Array[MmCardDefinition] = []
	var villain_cards: Array[MmCardDefinition] = [_ogre()]
	var extras: Array[MmCardDefinition] = [Scenario.free_prison("Prison"), Scenario.free_disenchant("Disenchant")]
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, villain_cards, extras)
	var original: MmEngine = Scenario.permanents_ready_with(setup, no_cards, villain_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(original, "No seed gave the needed hands.")
	_ring(original, "Prison", Scenario.permanent_named(original, original.villain().id, "Ogre"))
	var exiled: int = Scenario.exiled_by_owner(original, original.villain())[0]

	var copy: MmGameState = original.game_state().duplicate_state()

	assert_eq(copy.fingerprint(), original.game_state().fingerprint())
	assert_eq(copy.object(exiled).exiled_with_object_id, original.game_state().object(exiled).exiled_with_object_id)
	Scenario.cast_and_resolve(original, "Disenchant",
		[MmReference.to_object(Scenario.permanent_named(original, original.hero().id, "Prison"))])
	Scenario.resolve_stack(original)
	assert_ne(Scenario.permanent_named(original, original.villain().id, "Ogre"), -1)
	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())
	assert_eq(replayed.fingerprint(), original.fingerprint())


# --- Helpers -------------------------------------------------------------------------


## Casts the Prison named [param card_name], aims its trigger at [param target_id] and lets
## everything resolve.
func _ring(engine: MmEngine, card_name: String, target_id: int) -> void:
	assert_eq(Scenario.cast_and_resolve(engine, card_name), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(target_id)), "")
	assert_eq(Scenario.resolve_stack(engine), "")


## Activates the Mentor's ability at the Ogre and returns the ability's object ID; the Hero
## then holds priority with it on the stack (CR 117.3c).
func _activate_mentor_at_the_ogre(engine: MmEngine) -> int:
	var mentor: int = Scenario.permanent_named(engine, engine.hero().id, "Mentor")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(Scenario.activate(engine, mentor, [MmReference.to_object(ogre)]), "")
	return Scenario.stack_ids(engine)[0]


func _moves_with(engine: MmEngine, reason: Reason) -> Array[ZoneChangeEvent]:
	var moves: Array[ZoneChangeEvent] = []
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		if (event as ZoneChangeEvent).reason == reason:
			moves.append(event as ZoneChangeEvent)
	return moves


## "{0}: [effects]", with no cost at all.
func _ability_with(targets: Array[TargetRequirement], effects: Array[MmEffect]) -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.targets = targets
	ability.effects = effects
	return ability


## "{0}: This creature deals 1 damage to another target creature."
func _mentor() -> MmCardDefinition:
	var another_creature: TargetRequirement = Scenario.target(Scenario.all_of([Scenario.is_not(IsSourceFilter.new()),
		Scenario.of_type(CardType.CREATURE)]))
	return Scenario.creature("Mentor", 1, 3, [_ability_with([another_creature], [Scenario.deal_damage(1, Scenario.targeted(0))])])


## "When this creature leaves the battlefield, you gain 2 life."
func _leaver(card_name: String) -> MmCardDefinition:
	return Scenario.creature(card_name, 1, 1, [Scenario.triggered(Scenario.leaves(IsSourceFilter.new()),
		[Scenario.gain_life(2, Scenario.you())])])


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 3, 3)


func _goblin() -> MmCardDefinition:
	return Scenario.creature("Goblin", 1, 1)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
