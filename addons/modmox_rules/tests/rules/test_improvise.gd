extends GutTest
## The keyword improvise (CR 702.126a, engine ADR 0099): "Your artifacts can help cast this
## spell. Each artifact you tap after you're done activating mana abilities pays for {1}."
## While its spell's mana is paid, each untapped artifact its caster controls may be tapped
## to pay one generic mana.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_two_untapped_artifacts_pay_for_a_two_generic_spell_and_become_tapped() -> void:
	var engine: MmEngine = _artifacts_ready([Scenario.artifact("Trinket", []), Scenario.artifact("Bauble", [])],
		[Scenario.improviser("Scrap Prayer", Scenario.mana_cost(2))])
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")
	var bauble: int = Scenario.permanent_named(engine, engine.hero().id, "Bauble")
	var prayer: int = Scenario.card_in_hand(engine, engine.hero(), "Scrap Prayer")
	var life: int = engine.hero().life

	assert_true(Scenario.offers_cast(engine, prayer), "No lands, but two artifacts.")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, prayer)), "")
	assert_eq(Scenario.improvisers_offered(engine), [trinket, bauble])
	assert_eq(Scenario.improvise_with(engine, bauble), "")
	assert_eq(Scenario.improvisers_offered(engine), [trinket], "A tapped artifact improvises no more.")
	assert_eq(Scenario.improvise_with(engine, trinket), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(engine.game_state().object(trinket).is_tapped)
	assert_true(engine.game_state().object(bauble).is_tapped)
	assert_eq(engine.hero().life, life + 1)


func test_improvise_pays_no_colored_symbol() -> void:
	var engine: MmEngine = _artifacts_ready([Scenario.artifact("Trinket", []), Scenario.artifact("Bauble", [])],
		[Scenario.improviser("White Prayer", Scenario.mana_cost(1, [MmMana.Type.WHITE]))])

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "White Prayer")),
		"Two artifacts pay {2}, never {W}.")


func test_an_artifact_pays_a_colored_symbol_with_its_mana_and_another_improvises_the_rest() -> void:
	var prism: MmCardDefinition = Scenario.artifact("Prism", [Scenario.tap_for_mana(MmMana.Type.WHITE, 1)])
	var engine: MmEngine = _artifacts_ready([prism, Scenario.artifact("Trinket", [])],
		[Scenario.improviser("White Prayer", Scenario.mana_cost(1, [MmMana.Type.WHITE]))])
	var prism_id: int = Scenario.permanent_named(engine, engine.hero().id, "Prism")
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")
	var prayer: int = Scenario.card_in_hand(engine, engine.hero(), "White Prayer")
	var life: int = engine.hero().life

	assert_true(Scenario.offers_cast(engine, prayer))
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, prayer)), "")
	assert_eq(Scenario.pay_by_tapping(engine, prism_id), "")
	assert_eq(Scenario.improvisers_offered(engine), [trinket])
	assert_eq(Scenario.improvise_with(engine, trinket), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 1)


func test_a_tapped_artifact_cannot_improvise() -> void:
	var tapper: MmCardDefinition = Scenario.instant("Tapper", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(CardType.ARTIFACT))], [Scenario.tap(Scenario.targeted(0))])
	var engine: MmEngine = _artifacts_ready([Scenario.artifact("Trinket", []), Scenario.artifact("Bauble", [])],
		[Scenario.improviser("Scrap Prayer", Scenario.mana_cost(2)), tapper])
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")

	assert_eq(Scenario.cast_and_resolve(engine, "Tapper", [MmReference.to_object(trinket)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(engine.game_state().object(trinket).is_tapped)
	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Scrap Prayer")),
		"One untapped artifact pays only {1}.")


func test_an_artifact_creature_with_summoning_sickness_may_improvise() -> void:
	# Improvise is not the {T} of the artifact (CR 302.6 restricts only that).
	var golem: MmCardDefinition = Scenario.creature("Golem", 1, 1)
	golem.card_types = [CardType.ARTIFACT, CardType.CREATURE]
	var engine: MmEngine = _artifacts_ready([] as Array[MmCardDefinition],
		[Scenario.improviser("Small Prayer", Scenario.mana_cost(1)), golem])

	assert_eq(Scenario.cast_and_resolve(engine, "Golem"), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var golem_id: int = Scenario.permanent_named(engine, engine.hero().id, "Golem")
	var prayer: int = Scenario.card_in_hand(engine, engine.hero(), "Small Prayer")

	assert_true(Scenario.offers_cast(engine, prayer))
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, prayer)), "")
	assert_eq(Scenario.improvise_with(engine, golem_id), "")
	assert_true(engine.game_state().object(golem_id).is_tapped)


func test_a_spell_without_improvise_is_not_paid_by_artifacts() -> void:
	var plain: MmCardDefinition = Scenario.instant("Plain Prayer", Scenario.mana_cost(1), [], [Scenario.gain_life(1, Scenario.you())])
	var engine: MmEngine = _artifacts_ready([Scenario.artifact("Trinket", [])], [plain])

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Plain Prayer")))


func test_a_cost_reduction_comes_off_before_improvise_pays_the_rest() -> void:
	# CR 601.2f: the total cost is fixed, reductions taken off, before any of it is paid.
	var prayer: MmCardDefinition = Scenario.improviser("Cheap Prayer", Scenario.mana_cost(3))
	prayer.abilities.push_front(Scenario.cost_reduction(Scenario.constant(2)))
	var engine: MmEngine = _artifacts_ready([Scenario.artifact("Trinket", [])], [prayer])
	var prayer_id: int = Scenario.card_in_hand(engine, engine.hero(), "Cheap Prayer")

	assert_true(Scenario.offers_cast(engine, prayer_id))
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, prayer_id)), "")
	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_eq(paying.remaining_generic, 1)
	assert_eq(Scenario.improvise_with(engine, Scenario.permanent_named(engine, engine.hero().id, "Trinket")), "")
	assert_eq(engine.game_state().characteristics_of(engine.game_state().stack.objects()[0]).mana_value(), 3,
		"Its mana value is its mana cost's (CR 202.3).")


func test_the_spell_on_the_stack_or_any_payment_but_a_cast_offers_no_improvise() -> void:
	# Only the spell's own cost: a "you may pay {1}" as an ability resolves is paid as mana.
	var engine: MmEngine = _artifacts_ready([Scenario.artifact("Trinket", [])],
		[Scenario.improviser("Scrap Prayer", Scenario.mana_cost(1))])
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")
	var progress: ManaPaymentProgress = ManaPaymentProgress.of_cost(engine.hero().id, Scenario.mana_cost(1))

	assert_null(progress.decision(engine.game_state()), "Nothing but improvise could pay it, and this is no cast.")
	progress.improvises = true
	var offered: PayManaDecision = progress.decision(engine.game_state())
	assert_not_null(offered)
	assert_true(offered.actions[0] is ImproviseAction and (offered.actions[0] as ImproviseAction).object_id == trinket)


## The Hero in their main phase on Game Turn 3, with [param permanents] cast on the first
## turns, no lands, and holding [param held].
func _artifacts_ready(permanents: Array[MmCardDefinition], held: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(permanents, no_cards, held), permanents,
		no_cards, held, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
