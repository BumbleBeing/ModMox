extends GutTest
## "Create [token] that's attacking" (CR 508.4): the token is put onto the battlefield
## attacking the player its controller is attacking. It was never declared as an attacker,
## so it isn't tapped, summoning sickness doesn't stop it, and it never "attacked": attack
## triggers don't see it. Under the control of a player who isn't attacking, or outside a
## combat with attackers, it just enters (CR 506.3b).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose


func test_a_token_created_attacking_attacks_the_defending_player_though_summoning_sick() -> void:
	var engine: MmEngine = _combat_ready([Scenario.brimaz()], [])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Brimaz")])

	assert_eq(Scenario.resolve_stack(engine), "")

	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 1)
	var cat: int = tokens[0]
	var state: MmGameState = engine.game_state()
	assert_true(state.is_summoning_sick(state.object(cat)))
	assert_true(state.combat.is_attacking(cat), "CR 508.4")
	assert_true(IsAttackingFilter.new().matches(state, MmReference.to_object(cat), MmEffectContext.new(engine.hero().id, cat)))
	assert_eq(state.combat.defending_player_id, engine.villain().id)
	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		assert_true(_object(engine.view_for(viewer), cat).is_attacking)
	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)
	assert_eq(engine.villain().life, 16, "Brimaz's 3 and the Cat's 1.")
	assert_false(engine.game_state().combat.is_attacking(cat), "CR 511.3: combat has ended.")


func test_a_token_created_attacking_is_not_tapped() -> void:
	var engine: MmEngine = _combat_ready([Scenario.brimaz()], [])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Brimaz")])

	Scenario.resolve_stack(engine)

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_false(engine.game_state().object(cat).is_tapped, "CR 508.1f taps only declared attackers.")
	for event: MmEvent in Scenario.events_of(engine, TapEvent):
		assert_ne((event as TapEvent).object_id, cat)


func test_a_token_created_attacking_triggers_no_attack_trigger() -> void:
	var raiding_cat: MmCardDefinition = Scenario.token(1, 1, [MmCardTypes.CardColor.WHITE], ["Cat"],
		[Scenario.triggered(Scenario.attacks(), [Scenario.gain_life(1, Scenario.you())])])
	var any_attack: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()  # "one or more creatures you control"
	var banner: MmCardDefinition = Scenario.artifact("Banner", [Scenario.triggered(any_attack, [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _combat_ready([banner, Scenario.brimaz(raiding_cat)], [])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Brimaz")])

	Scenario.resolve_stack(engine)

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 1)
	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 2, "Brimaz's and the Banner's, for the declaration only.")
	assert_eq(engine.hero().life, 21, "CR 508.4: the Cat never attacked, so neither its own trigger nor the Banner's again.")


func test_a_token_created_attacking_can_be_blocked() -> void:
	var engine: MmEngine = _combat_ready([Scenario.brimaz()], [Scenario.creature("Wolf", 2, 2)])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Brimaz")])
	Scenario.pass_to_blockers(engine)
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	var wolf: int = Scenario.permanent_named(engine, engine.villain().id, "Wolf")
	assert_true((engine.pending_decision() as DeclareBlockersDecision).attacker_ids.has(cat))

	assert_eq(Scenario.declare_blockers(engine, [[wolf, cat]]), "")
	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)

	assert_true(Scenario.tokens_on_battlefield(engine).is_empty(), "The Wolf killed the Cat.")
	assert_eq(engine.villain().life, 17, "Only Brimaz got through.")


func test_a_token_created_attacking_after_blockers_are_declared_is_unblocked() -> void:
	var engine: MmEngine = _combat_ready([Scenario.creature("Ant", 2, 2)], [Scenario.creature("Wolf", 2, 2)], [Scenario.free_ambush()])
	var ant: int = Scenario.permanent_named(engine, engine.hero().id, "Ant")
	Scenario.declare_attackers(engine, [ant])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[Scenario.permanent_named(engine, engine.villain().id, "Wolf"), ant]])

	assert_eq(Scenario.cast_and_resolve(engine, "Ambush"), "")

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_true(engine.game_state().combat.is_attacking(cat))
	assert_false(engine.game_state().combat.is_blocked(cat))
	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)
	assert_eq(engine.villain().life, 19, "The Cat's 1; the Wolf stopped the Ant.")


func test_a_token_created_attacking_outside_combat_just_enters() -> void:
	var no_cards: Array[MmCardDefinition] = []
	var hero_extras: Array[MmCardDefinition] = [Scenario.free_ambush()]
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, hero_extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")

	assert_eq(Scenario.cast_and_resolve(engine, "Ambush"), "")

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_false(engine.game_state().combat.is_attacking(cat), "CR 506.2: outside combat no player is attacking.")
	assert_false(engine.game_state().combat.has_declared_attackers())


func test_a_token_the_defending_player_creates_attacking_just_enters_and_may_block() -> void:
	var engine: MmEngine = _combat_ready([], [Scenario.creature("Wolf", 2, 2)], [Scenario.free_ambush()])
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	Scenario.play_until_step(engine, 4, Step.DECLARE_ATTACKERS)
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.villain().id, "Wolf")])
	Scenario.pass_priority(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Ambush"), "")

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_false(engine.game_state().combat.is_attacking(cat), "CR 506.3b: the Hero isn't the attacking player.")
	assert_eq(Scenario.pass_to_blockers(engine), "")
	assert_true((engine.pending_decision() as DeclareBlockersDecision).candidate_blocker_ids.has(cat))


func _combat_ready(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var engine: MmEngine = Scenario.combat_ready(hero_permanents, villain_permanents, hero_extras)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _object(view: MmPlayerView, object_id: int) -> MmObjectView:
	for permanent: MmObjectView in view.battlefield:
		if permanent.id == object_id:
			return permanent
	return null
