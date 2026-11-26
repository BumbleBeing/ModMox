extends GutTest
## Goblin Dark-Dwellers' "When this creature enters, you may cast target instant or sorcery
## card with mana value 3 or less from your graveyard without paying its mana cost. If that
## spell would be put into your graveyard, exile it instead." (CastWithoutPayingEffect,
## engine ADR 0104). On yes the spell is cast at once (CR 601.2a-i), its choices asked as any
## cast's, paying no mana (CR 118.9), and the ability carries on with no one receiving
## priority; the spell then waits on the stack. Dweller is a 1/1 costing {0} with that
## ability; Zap a {1}{R} instant, "Zap deals 2 damage to any target."; Nix a {0} instant,
## "Counter target spell."; Pit a 0/1 costing {0} with "{0}: Discard a card.", which puts a
## spell into the graveyard first.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Choice := ChooseYesOrNoDecision.Choice


func test_yes_casts_the_card_without_paying_its_mana_cost() -> void:
	var engine: MmEngine = _dweller_asks([_zap()])
	var zap: int = Scenario.card_in_graveyard(engine, engine.hero(), "Zap")

	assert_eq(engine.submit(Choice.YES), "")
	assert_true(engine.is_casting(), "Cast as any spell is, its target asked.")
	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.villain().id)), "")

	assert_true(engine.pending_decision() is PriorityDecision, "No mana to pay.")
	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Zap"), -1)
	assert_eq(Scenario.stack_ids(engine).size(), 1, "Zap alone: the ability has finished resolving.")
	var cast: SpellCastEvent = Scenario.events_of(engine, SpellCastEvent).back() as SpellCastEvent
	assert_eq(engine.game_state().characteristics_of(engine.game_state().object(cast.spell_id)).name, "Zap",
		"CR 601.2i: it was cast.")
	assert_eq(engine.hero().mana_pool().size(), 0)
	assert_ne(zap, Scenario.stack_ids(engine)[0], "A new object on the stack (ADR 0008).")


func test_no_player_receives_priority_while_the_ability_finishes() -> void:
	var engine: MmEngine = _dweller_asks([_zap()])
	var decisions: int = engine.decision_count()

	assert_eq(engine.submit(Choice.YES), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.villain().id)), "")

	assert_eq(engine.decision_count(), decisions + 2, "The yes and the target, and nothing between.")
	var priority: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(priority.player_id, engine.hero().id, "CR 117.3b: the active player, after the ability resolved.")
	assert_gt(Scenario.events_of(engine, AbilityLeftStackEvent).size(), 0, "The ability left the stack.")


func test_the_spell_resolves_and_is_exiled_instead_of_going_to_the_graveyard() -> void:
	var engine: MmEngine = _dweller_asks([_zap()])
	var life: int = engine.villain().life
	assert_eq(engine.submit(Choice.YES), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.villain().id)), "")

	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.villain().life, life - 2)
	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Zap"), -1)
	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Zap"), -1, "Exiled instead.")


func test_countered_it_is_exiled_too() -> void:
	var engine: MmEngine = _dweller_asks([_zap(), _nix()])
	assert_eq(engine.submit(Choice.YES), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.villain().id)), "")
	var zap: int = Scenario.stack_ids(engine)[0]

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Nix"), [MmReference.to_object(zap)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Zap"), -1)
	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Zap"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Nix"), -1, "Nix was cast from the hand: no mark.")


func test_no_leaves_the_card_where_it_is() -> void:
	var engine: MmEngine = _dweller_asks([_zap()])
	var zap: int = Scenario.card_in_graveyard(engine, engine.hero(), "Zap")

	assert_eq(engine.submit(Choice.NO), "")

	assert_false(engine.is_casting())
	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Zap"), zap)
	assert_eq(Scenario.stack_ids(engine), [] as Array[int])


func test_canceling_the_cast_goes_back_to_the_question() -> void:
	var engine: MmEngine = _dweller_asks([_zap()])
	var before: String = engine.fingerprint()
	assert_eq(engine.submit(Choice.YES), "")

	assert_eq(engine.cancel_cast(), "")

	assert_true(engine.pending_decision() is ChooseYesOrNoDecision, "CR 728: as before the yes.")
	assert_eq(engine.fingerprint(), before)
	assert_eq(engine.submit(Choice.NO), "", "And no may be said then.")


func test_a_sorcery_is_cast_though_the_stack_is_not_empty() -> void:
	var engine: MmEngine = _dweller_asks([_scorch()])

	assert_eq(engine.submit(Choice.YES), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.villain().id)), "")

	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Scorch"), -1, "Its type's timing is not checked.")
	assert_eq(Scenario.stack_ids(engine).size(), 1)


func test_a_card_with_flashback_pays_neither_its_mana_nor_its_flashback_cost() -> void:
	var engine: MmEngine = _dweller_asks([_insight()])
	var life: int = engine.hero().life
	var hand: int = engine.hero().hand.size()

	assert_eq(engine.submit(Choice.YES), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life, "CR 118.9a: one alternative cost, so no flashback cost.")
	assert_eq(engine.hero().hand.size(), hand + 1, "It drew a card.")
	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Insight"), -1)


func test_a_card_that_cannot_be_cast_now_is_not() -> void:
	var engine: MmEngine = _dweller_asks([_shatter()])

	assert_eq(engine.submit(Choice.YES), "")

	assert_false(engine.is_casting(), "No artifact to target, so it cannot be cast.")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Shatter"), -1)
	assert_true(engine.pending_decision() is PriorityDecision)


func test_a_replay_casts_it_the_same() -> void:
	var spells: Array[MmCardDefinition] = [_zap()]
	var setup: MmEncounterSetup = _setup(spells)
	var engine: MmEngine = _dweller_asks_from(setup, spells)
	assert_eq(engine.submit(Choice.YES), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.villain().id)), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


static func _zap() -> MmCardDefinition:
	return Scenario.instant("Zap", Scenario.mana_cost(1, [MmMana.Type.RED]), [Scenario.any_target()],
		[Scenario.deal_damage(2, Scenario.targeted(0))])


## The same as Zap, a sorcery costing {0}.
static func _scorch() -> MmCardDefinition:
	return Scenario.sorcery("Scorch", Scenario.mana_cost(0), [Scenario.any_target()],
		[Scenario.deal_damage(2, Scenario.targeted(0))])


static func _nix() -> MmCardDefinition:
	var spell: TargetRequirement = Scenario.target(null)
	spell.among = TargetRequirement.Among.SPELLS
	return Scenario.instant("Nix", Scenario.mana_cost(0), [spell], [Scenario.counter(Scenario.targeted(0))])


## A {0} sorcery: "Draw a card. Flashback—Pay 3 life."
static func _insight() -> MmCardDefinition:
	var costs: Array[MmCost] = [Scenario.pay_life(3)]
	return Scenario.flashback_sorcery("Insight", [], [Scenario.draw_cards(1, Scenario.you())], Scenario.flashback(null, costs))


## A {0} instant: "Destroy target artifact."
static func _shatter() -> MmCardDefinition:
	var destroy: DestroyEffect = DestroyEffect.new()
	destroy.selection = Scenario.targeted(0)
	return Scenario.instant("Shatter", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(MmCardTypes.CardType.ARTIFACT))],
		[destroy])


func _setup(spells: Array[MmCardDefinition]) -> MmEncounterSetup:
	var extras: Array[MmCardDefinition] = [Scenario.dweller()]
	extras.append_array(spells)
	return Scenario.combat_setup([_pit()], [] as Array[MmCardDefinition], extras)


static func _pit() -> MmCardDefinition:
	var discarding: ActivatedAbility = ActivatedAbility.new()
	discarding.effects = [Scenario.discard(1, Scenario.you())]
	return Scenario.creature("Pit", 0, 1, [discarding])


## The Hero's main phase of Game Turn 3, where the first of [param spells] (each of which
## the Hero also holds) has been put into the Hero's graveyard and the Dweller cast, its
## ability now asking whether to cast it.
func _dweller_asks(spells: Array[MmCardDefinition]) -> MmEngine:
	return _dweller_asks_from(_setup(spells), spells)


func _dweller_asks_from(setup: MmEncounterSetup, spells: Array[MmCardDefinition]) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.dweller()]
	extras.append_array(spells)
	var no_cards: Array[MmCardDefinition] = []
	var pits: Array[MmCardDefinition] = [_pit()]
	var engine: MmEngine = Scenario.permanents_ready_with(setup, pits, no_cards, extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	var first: int = Scenario.card_in_hand(engine, engine.hero(), spells[0].name)
	_put_into_graveyard(engine, first)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Dweller")), "")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")
	return engine


## Discards [param card_id] from the Hero's hand with the Pit.
func _put_into_graveyard(engine: MmEngine, card_id: int) -> void:
	assert_eq(Scenario.activate(engine, Scenario.permanent_named(engine, engine.hero().id, "Pit")), "")
	assert_eq(Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.pending_decision() is ChooseCardsToDiscardDecision), "")
	assert_eq(engine.submit([card_id]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
