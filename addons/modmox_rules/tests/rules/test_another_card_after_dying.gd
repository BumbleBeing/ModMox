extends GutTest
## "Another" in a "dies" ability (engine ADR 0096's addendum): "this creature" is the card
## the dying creature became, as well as the creature it was, so Gixian Puppeteer's "return
## another target creature card ... from your graveyard" can never choose its own card,
## whatever its mana value has been made. Puppeteer is a 2/2 costing {0}: "When this creature
## dies, return another target creature card from your graveyard to the battlefield."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_its_own_card_is_not_another_target() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(_shock(engine, "Shock A", "Bear"), "")
	var bear: int = Scenario.card_in_graveyard(engine, engine.hero(), "Bear")

	assert_eq(_shock(engine, "Shock B", "Puppeteer"), "")

	var asked: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(asked, "The dies ability asks for its target.")
	var candidate_ids: Array[int] = []
	for candidate: MmReference in asked.candidates:
		candidate_ids.append(candidate.id)
	assert_eq(candidate_ids, [bear] as Array[int], "The Bear's card, not the Puppeteer's.")


func test_with_no_other_creature_card_it_is_removed_and_its_card_stays() -> void:
	# CR 603.3d: a triggered ability with no legal target is removed from the stack.
	var engine: MmEngine = _hero_main()

	assert_eq(_shock(engine, "Shock B", "Puppeteer"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_false(engine.pending_decision() is ChooseTargetDecision)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Puppeteer"), -1)
	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Puppeteer"), -1)


func test_another_still_means_another_on_the_battlefield() -> void:
	# A permanent that never moved became nothing, so "another" leaves out only itself.
	var engine: MmEngine = _hero_main()
	var puppeteer: int = Scenario.permanent_named(engine, engine.hero().id, "Puppeteer")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var another: NotFilter = Scenario.is_not(IsSourceFilter.new())
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, puppeteer)

	assert_false(another.matches(engine.game_state(), MmReference.to_object(puppeteer), context))
	assert_true(another.matches(engine.game_state(), MmReference.to_object(bear), context))


## Casts [param shock_name] at the Hero's permanent named [param card_name] and resolves it.
func _shock(engine: MmEngine, shock_name: String, card_name: String) -> String:
	var target: int = Scenario.permanent_named(engine, engine.hero().id, card_name)
	return Scenario.cast_and_resolve(engine, shock_name, [MmReference.to_object(target)])


## "When this creature dies, return another target creature card from your graveyard to the
## battlefield."
func _puppeteer() -> MmCardDefinition:
	var another_dead_creature: TargetRequirement = Scenario.target_graveyard_card(Scenario.all_of([
		Scenario.of_type(MmCardTypes.CardType.CREATURE), Scenario.owned_by(MmTrigger.Whose.YOU),
		Scenario.is_not(IsSourceFilter.new())]))
	return Scenario.creature("Puppeteer", 2, 2, [Scenario.triggered(Scenario.dies(IsSourceFilter.new()),
		[Scenario.return_to_battlefield(Scenario.targeted(0))], [another_dead_creature])])


## The Hero in their main phase of Game Turn 3 with a Puppeteer and a 2/2 Bear cast on Game
## Turn 1, holding two Shocks of 2.
func _hero_main() -> MmEngine:
	var creatures: Array[MmCardDefinition] = [_puppeteer(), Scenario.creature("Bear", 2, 2)]
	var extras: Array[MmCardDefinition] = [Scenario.free_shock("Shock A", 2), Scenario.free_shock("Shock B", 2)]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(creatures, NO_CARDS, extras), creatures,
		NO_CARDS, extras, NO_CARDS, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
