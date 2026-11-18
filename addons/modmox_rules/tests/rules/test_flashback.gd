extends GutTest
## Flashback (CR 702.34a): a card with flashback may be cast from its owner's graveyard by
## paying its flashback cost instead of its mana cost (an alternative cost, CR 118.9), with
## its card type's usual timing; cast that way, it is exiled instead of going anywhere else
## whenever it would leave the stack. Echo is a sorcery costing {0}, "You gain 1 life", with
## flashback {1}{W}; two Elves, "{T}: Add {W}", pay for it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Reason := ZoneChangeEvent.Reason

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_a_card_with_flashback_in_your_graveyard_is_cast_for_its_flashback_cost() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [_echo()])
	var echo: int = _echo_in_graveyard(engine)
	assert_eq(engine.hero().life, 21, "Cast from the hand for {0}, it gains 1 life.")
	assert_eq(_tapped_elves(engine), 0, "From the hand it cost its mana cost, {0}.")

	assert_true(Scenario.offers_cast(engine, echo))
	assert_eq(Scenario.cast(engine, echo), "")

	assert_eq(_tapped_elves(engine), 2, "CR 118.9: it cost its flashback cost, {1}{W}.")
	assert_true(engine.game_state().object(Scenario.stack_ids(engine)[0]).cast_with_flashback)
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().life, 22)


func test_cast_with_flashback_it_is_exiled_as_it_resolves() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [_echo()])
	Scenario.cast(engine, _echo_in_graveyard(engine))

	Scenario.resolve_stack(engine)

	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Echo"), -1)
	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Echo"), -1, "CR 702.34a")
	var last: ZoneChangeEvent = _last_move(engine)
	assert_eq([last.from_zone_kind, last.to_zone_kind, last.reason], [MmZone.Kind.STACK, MmZone.Kind.EXILE, Reason.RESOLVED])


func test_cast_from_the_hand_it_goes_to_the_graveyard_as_ever() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [_echo()])

	_echo_in_graveyard(engine)

	assert_eq(Scenario.card_in_exile(engine, engine.hero(), "Echo"), -1)
	assert_eq(_last_move(engine).to_zone_kind, MmZone.Kind.GRAVEYARD)


func test_countered_it_is_exiled() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [_echo(), Scenario.free_counter("Negate")])
	Scenario.cast(engine, _echo_in_graveyard(engine))
	var spell: int = Scenario.stack_ids(engine)[0]

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Negate"), [MmReference.to_object(spell)])
	Scenario.resolve_stack(engine)

	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Echo"), -1, "CR 702.34a: anywhere it would go from the stack.")
	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Echo"), -1)


func test_with_its_only_target_gone_it_does_not_resolve_and_is_exiled() -> void:
	var zap: MmCardDefinition = Scenario.flashback_sorcery("Zap", [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.deal_damage(1, Scenario.targeted(0))], Scenario.flashback(Scenario.mana_cost(1, [MmMana.Type.WHITE])))
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [zap, Scenario.free_shock("Shock", 2)],
		[Scenario.creature("Wolf", 2, 2)])
	var wolf: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.villain().id, "Wolf"))
	Scenario.cast_and_resolve(engine, "Zap", [wolf])
	assert_eq(Scenario.cast(engine, Scenario.card_in_graveyard(engine, engine.hero(), "Zap"), [wolf]), "")

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [wolf])
	Scenario.resolve_stack(engine)

	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Zap"), -1)
	assert_eq(_last_move(engine).reason, Reason.DID_NOT_RESOLVE)


func test_canceling_the_cast_puts_it_back_in_the_graveyard() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [_echo()])
	var echo: int = _echo_in_graveyard(engine)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, echo))
	assert_true(engine.is_casting())

	assert_eq(engine.cancel_cast(), "")

	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Echo"), echo, "CR 728: as it was.")
	assert_true(engine.game_state().stack.is_empty())
	assert_eq(_tapped_elves(engine), 0)


func test_it_is_not_offered_without_the_mana_for_its_flashback_cost() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf()], [_echo()])

	var echo: int = _echo_in_graveyard(engine)

	assert_false(Scenario.offers_cast(engine, echo), "One Elf cannot pay {1}{W}.")


func test_a_card_without_flashback_is_never_cast_from_a_graveyard() -> void:
	var plain: MmCardDefinition = Scenario.sorcery("Plain", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [plain])

	Scenario.cast_and_resolve(engine, "Plain")

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_graveyard(engine, engine.hero(), "Plain")))


func test_it_keeps_its_card_types_timing() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [_echo()])
	var echo: int = _echo_in_graveyard(engine)

	Scenario.pass_until_step(engine, Step.END)

	assert_false(Scenario.offers_cast(engine, echo), "CR 702.34a, 307.1: a sorcery only in a main phase with an empty stack.")


func test_a_card_in_an_opponents_graveyard_is_not_offered() -> void:
	var hero_permanents: Array[MmCardDefinition] = [Scenario.elf(), Scenario.elf()]
	var villain_echo: MmCardDefinition = _echo()
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, [], [], [villain_echo])
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 1, Step.PRECOMBAT_MAIN) != "":
			return false
		for definition: MmCardDefinition in hero_permanents:
			if Scenario.cast_and_resolve(running, definition.name) != "":
				return false
		if Scenario.play_until_step(running, 2, Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.cast_and_resolve(running, "Echo") != "":
			return false
		return Scenario.play_until_step(running, 3, Step.PRECOMBAT_MAIN) == "")
	assert_not_null(engine, "No seed gave the needed hands.")
	var theirs: int = Scenario.card_in_graveyard(engine, engine.villain(), "Echo")
	assert_ne(theirs, -1)

	assert_false(Scenario.offers_cast(engine, theirs), "CR 702.34a: its owner's graveyard only.")


func test_whenever_you_cast_sees_a_spell_cast_with_flashback() -> void:
	var watcher: MmCardDefinition = Scenario.artifact("Watcher",
		[Scenario.triggered(Scenario.casts(null, MmTrigger.Whose.YOU), [Scenario.gain_life(5, Scenario.you())])])
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf(), watcher], [_echo()])
	var echo: int = _echo_in_graveyard(engine)
	var cast_events: int = Scenario.events_of(engine, SpellCastEvent).size()

	Scenario.cast(engine, echo)

	assert_eq(Scenario.events_of(engine, SpellCastEvent).size(), cast_events + 1, "CR 601.2i")
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().life, 21 + 5 + 5 + 1)


func test_views_copies_and_replays_know_it_was_cast_with_flashback() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [_echo()])
	Scenario.cast(engine, _echo_in_graveyard(engine))
	var spell: int = Scenario.stack_ids(engine)[0]

	var view: MmPlayerView = engine.view_for(engine.villain())
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	assert_true(_stack_view(view, spell).cast_with_flashback, "Both players see it.")
	assert_true(copy.game_state().object(spell).cast_with_flashback)
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())
	assert_eq(replayed.fingerprint(), engine.fingerprint())
	Scenario.resolve_stack(copy)
	assert_ne(Scenario.card_in_exile(copy, copy.hero(), "Echo"), -1)


## A sorcery costing {0}: "You gain 1 life. Flashback {1}{W}".
func _echo() -> MmCardDefinition:
	return Scenario.flashback_sorcery("Echo", [], [Scenario.gain_life(1, Scenario.you())],
		Scenario.flashback(Scenario.mana_cost(1, [MmMana.Type.WHITE])))


## Casts Echo from the hand and lets it resolve; returns it in the graveyard.
func _echo_in_graveyard(engine: MmEngine) -> int:
	assert_eq(Scenario.cast_and_resolve(engine, "Echo"), "")
	Scenario.resolve_stack(engine)
	return Scenario.card_in_graveyard(engine, engine.hero(), "Echo")


func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _tapped_elves(engine: MmEngine) -> int:
	var tapped: int = 0
	for id: int in Scenario.permanents_named(engine, engine.hero().id, "Elf"):
		if engine.game_state().object(id).is_tapped:
			tapped += 1
	return tapped


func _last_move(engine: MmEngine) -> ZoneChangeEvent:
	var moves: Array[MmEvent] = Scenario.events_of(engine, ZoneChangeEvent)
	return moves.back() as ZoneChangeEvent


func _stack_view(view: MmPlayerView, object_id: int) -> MmObjectView:
	for seen: MmObjectView in view.stack:
		if seen.id == object_id:
			return seen
	return null
