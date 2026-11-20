extends GutTest
## "Create [token] that's blocking that creature" (CR 509.7): the token is put onto the
## battlefield blocking the attacker its ability names. It was never declared as a blocker,
## so it never "blocked": block triggers don't see it, and no block restriction applies to
## it. The attacker's controller divides its damage among all its blockers (CR 510.1c).
## Under the control of a player who isn't defending, blocking a creature that is no longer
## attacking, or before blockers are declared, it just enters (CR 506.3c). Brimaz here is a
## 3/4 costing {0} with "Whenever this creature blocks a creature, create a 1/1 white Cat
## creature token that's blocking that creature", and the Hero's 2/4 Ox attacks it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_token_created_blocking_blocks_that_creature() -> void:
	var engine: MmEngine = _blockers_ready([_ox()], [Scenario.blocking_brimaz()])
	var ox: int = _attacker(engine)
	var brimaz: int = Scenario.permanent_named(engine, engine.villain().id, "Brimaz")
	Scenario.declare_blockers(engine, [[brimaz, ox]])

	assert_eq(Scenario.resolve_stack(engine), "")

	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 1)
	var cat: int = tokens[0]
	var state: MmGameState = engine.game_state()
	assert_eq(state.step, Step.DECLARE_BLOCKERS, "The trigger resolves in the declare blockers step.")
	assert_eq(state.object(cat).controller_id, engine.villain().id)
	assert_false(state.object(cat).is_tapped)
	assert_true(state.combat.is_blocking(cat), "CR 509.7")
	assert_true(IsBlockingFilter.new().matches(state, MmReference.to_object(cat), MmEffectContext.new(engine.villain().id, cat)))
	assert_eq(state.combat.attackers_blocked_by(state, cat), [ox])
	assert_eq(state.combat.blockers_of(state, ox), [brimaz, cat])
	assert_eq((Scenario.events_of(engine, TokenCreatedEvent).back() as TokenCreatedEvent).blocking_on_arrival, ox)
	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		assert_eq(_object(engine.view_for(viewer), cat).blocking_ids, [ox])


func test_the_attackers_controller_divides_its_damage_among_this_creature_and_the_token() -> void:
	var engine: MmEngine = _blockers_ready([_ox()], [Scenario.blocking_brimaz()])
	var ox: int = _attacker(engine)
	var brimaz: int = Scenario.permanent_named(engine, engine.villain().id, "Brimaz")
	Scenario.declare_blockers(engine, [[brimaz, ox]])
	Scenario.resolve_stack(engine)
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]

	assert_eq(Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE), "")

	var division: DivideCombatDamageDecision = engine.pending_decision() as DivideCombatDamageDecision
	assert_not_null(division, "CR 510.1c: two creatures block the Ox, and there is no damage assignment order.")
	assert_eq(division.player_id, engine.hero().id)
	assert_eq(_recipient_ids(division), [brimaz, cat])
	assert_eq(engine.submit([1, 1]), "")
	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)
	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Ox"), -1, "Brimaz's 3 and the Cat's 1 killed the 2/4 Ox.")
	assert_true(Scenario.tokens_on_battlefield(engine).is_empty(), "The Ox's 1 killed the Cat.")
	assert_eq(Scenario.damage_on(engine, brimaz), 1)


func test_a_token_created_blocking_triggers_no_block_trigger() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	var watchtower: MmCardDefinition = Scenario.artifact("Watchtower",
		[Scenario.triggered(Scenario.blocks_a_creature(Scenario.creature_you_control()), gain)])
	var engine: MmEngine = _blockers_ready([_ox()], [watchtower, Scenario.blocking_brimaz()])
	var brimaz: int = Scenario.permanent_named(engine, engine.villain().id, "Brimaz")
	var life: int = engine.villain().life
	Scenario.declare_blockers(engine, [[brimaz, _attacker(engine)]])

	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 1, "Brimaz triggered once.")
	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 2, "Brimaz's and the Watchtower's, for the declaration only.")
	assert_eq(engine.villain().life, life + 1, "CR 509.7: the Cat never blocked, so the Watchtower saw only Brimaz.")


func test_a_token_created_blocking_blocks_a_flyer_it_could_not_have_been_declared_blocking() -> void:
	var roc: MmCardDefinition = Scenario.creature("Roc", 2, 4, [FlyingAbility.new()])
	var engine: MmEngine = _blockers_ready([roc], [Scenario.blocking_brimaz(null, [ReachAbility.new()])])
	var flyer: int = _attacker(engine)
	var brimaz: int = Scenario.permanent_named(engine, engine.villain().id, "Brimaz")
	Scenario.declare_blockers(engine, [[brimaz, flyer]])

	assert_eq(Scenario.resolve_stack(engine), "")

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_eq(engine.game_state().combat.blockers_of(engine.game_state(), flyer), [brimaz, cat],
		"CR 509.1b-c: block restrictions are checked as blockers are declared, and the Cat never was.")


func test_a_token_created_blocking_a_creature_that_has_left_just_enters() -> void:
	var engine: MmEngine = _blockers_ready([_ox()], [Scenario.blocking_brimaz()], [Scenario.free_destroy("Banish")])
	var ox: int = _attacker(engine)
	var brimaz: int = Scenario.permanent_named(engine, engine.villain().id, "Brimaz")
	Scenario.declare_blockers(engine, [[brimaz, ox]])

	assert_eq(Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(ox)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 1, "The token is still created.")
	assert_false(engine.game_state().combat.is_blocking(tokens[0]), "CR 506.4: the Ox left combat as it died.")
	assert_eq((Scenario.events_of(engine, TokenCreatedEvent).back() as TokenCreatedEvent).blocking_on_arrival, 0)


func test_a_token_created_blocking_after_this_creature_has_left_still_blocks_that_creature() -> void:
	var engine: MmEngine = _blockers_ready([_ox()], [Scenario.blocking_brimaz()], [Scenario.free_destroy("Banish")])
	var ox: int = _attacker(engine)
	var brimaz: int = Scenario.permanent_named(engine, engine.villain().id, "Brimaz")
	var life: int = engine.villain().life
	Scenario.declare_blockers(engine, [[brimaz, ox]])

	assert_eq(Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(brimaz)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_eq(engine.game_state().combat.blockers_of(engine.game_state(), ox), [cat], "CR 113.7a: the ability exists apart from Brimaz.")
	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)
	assert_eq(Scenario.damage_on(engine, ox), 1, "The Cat's 1.")
	assert_eq(engine.villain().life, life, "CR 509.1h: the Ox stayed blocked.")


func test_a_token_the_defending_player_creates_blocking_an_unblocked_attacker_blocks_it() -> void:
	var engine: MmEngine = _villain_attacking_with_wolf()
	var wolf: int = Scenario.permanent_named(engine, engine.villain().id, "Wolf")
	assert_eq(Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS), "")
	assert_eq(Scenario.pass_priority(engine), "", "The Villain, the active player, passes.")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Foliage", [MmReference.to_object(wolf)]), "")

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_true(engine.game_state().combat.is_blocking(cat))
	assert_true(engine.game_state().combat.is_blocked(wolf), "The Wolf is blocked from then on (CR 509.1h).")
	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)
	assert_eq(engine.hero().life, life, "The Cat stopped the Wolf.")


func test_a_token_created_blocking_before_blockers_are_declared_just_enters_and_may_block() -> void:
	var engine: MmEngine = _villain_attacking_with_wolf()
	var wolf: int = Scenario.permanent_named(engine, engine.villain().id, "Wolf")
	assert_eq(Scenario.pass_priority(engine), "", "The Villain, the active player, passes.")

	assert_eq(Scenario.cast_and_resolve(engine, "Foliage", [MmReference.to_object(wolf)]), "")

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_false(engine.game_state().combat.is_blocking(cat), "Left out until a card needs it: it just enters (ADR 0044).")
	assert_eq(Scenario.pass_to_blockers(engine), "")
	assert_true((engine.pending_decision() as DeclareBlockersDecision).candidate_blocker_ids.has(cat))


func test_a_token_the_attacking_player_creates_blocking_just_enters() -> void:
	var engine: MmEngine = _combat_ready([_ox()], [], [Scenario.free_foliage()])
	var ox: int = Scenario.permanent_named(engine, engine.hero().id, "Ox")
	var life: int = engine.villain().life
	Scenario.declare_attackers(engine, [ox])
	assert_eq(Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Foliage", [MmReference.to_object(ox)]), "")

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_false(engine.game_state().combat.is_blocking(cat), "CR 506.3c: the Hero isn't the defending player.")
	assert_false(engine.game_state().combat.is_blocked(ox))
	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)
	assert_eq(engine.villain().life, life - 2, "The Ox got through.")


func _ox() -> MmCardDefinition:
	return Scenario.creature("Ox", 2, 4)


func _combat_ready(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var engine: MmEngine = Scenario.combat_ready(hero_permanents, villain_permanents, hero_extras)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## [param hero_permanents] and [param villain_permanents] on the battlefield, the Hero's one
## creature attacking, and the Villain's blockers decision pending.
func _blockers_ready(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var engine: MmEngine = _combat_ready(hero_permanents, villain_permanents, hero_extras)
	assert_eq(Scenario.declare_attackers(engine, (engine.pending_decision() as DeclareAttackersDecision).candidate_ids.duplicate()), "")
	assert_eq(Scenario.pass_to_blockers(engine), "")
	return engine


## The Villain's 2/2 Wolf attacking the Hero, who has no creatures and holds a Foliage, with
## the Villain holding priority in the declare attackers step.
func _villain_attacking_with_wolf() -> MmEngine:
	var engine: MmEngine = _combat_ready([], [Scenario.creature("Wolf", 2, 2)], [Scenario.free_foliage()])
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	Scenario.play_until_step(engine, 4, Step.DECLARE_ATTACKERS)
	assert_eq(Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.villain().id, "Wolf")]), "")
	return engine


func _attacker(engine: MmEngine) -> int:
	return engine.game_state().combat.attackers(engine.game_state())[0]


func _recipient_ids(division: DivideCombatDamageDecision) -> Array[int]:
	var ids: Array[int] = []
	for recipient: MmReference in division.recipients:
		ids.append(recipient.id)
	return ids


func _object(view: MmPlayerView, object_id: int) -> MmObjectView:
	for permanent: MmObjectView in view.battlefield:
		if permanent.id == object_id:
			return permanent
	return null
