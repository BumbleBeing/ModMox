extends GutTest
## "As an additional cost to cast this spell, [costs] or [other costs]" (CR 601.2b, 601.2f,
## engine ADR 0086's second addendum), as Bayou Groff's "sacrifice a creature or pay {3}": the
## card is offered two casts from the hand, one for each choice, each only while its own costs
## can be paid, and a cast pays only the choice it was offered for. The mana of the other
## choice is added to the mana cost (CR 601.2f), and the spell's mana value is still its mana
## cost's (CR 202.3). Groff is a 5/4 costing {0} with that ability; the Mana Rock is an
## artifact that taps for {W}{W}{W}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_with_only_a_creature_to_sacrifice_only_that_cast_is_offered() -> void:
	var engine: MmEngine = _hero_main([_bear()])
	var groff: int = Scenario.card_in_hand(engine, engine.hero(), "Groff")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_ne(Scenario.cast_index_other_additional(decision, groff, false), -1)
	assert_eq(Scenario.cast_index_other_additional(decision, groff), -1, "No mana to pay {3}.")


func test_with_only_the_mana_only_the_paying_cast_is_offered() -> void:
	var engine: MmEngine = _hero_main([_mana_rock()])
	var groff: int = Scenario.card_in_hand(engine, engine.hero(), "Groff")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_eq(Scenario.cast_index_other_additional(decision, groff, false), -1, "No creature to sacrifice.")
	assert_ne(Scenario.cast_index_other_additional(decision, groff), -1)


func test_with_both_both_casts_are_offered_the_first_before_the_other() -> void:
	var engine: MmEngine = _hero_main([_bear(), _mana_rock()])
	var groff: int = Scenario.card_in_hand(engine, engine.hero(), "Groff")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	var first: int = Scenario.cast_index_other_additional(decision, groff, false)
	var other: int = Scenario.cast_index_other_additional(decision, groff)

	assert_ne(first, -1)
	assert_eq(other, first + 1, "Offered after it, as an alternative cost's cast is.")


func test_the_sacrificing_cast_sacrifices_and_pays_no_mana() -> void:
	var engine: MmEngine = _hero_main([_bear(), _mana_rock()])
	var groff: int = Scenario.card_in_hand(engine, engine.hero(), "Groff")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var rock: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Rock")

	assert_eq(engine.submit(Scenario.cast_index_other_additional(engine.pending_decision() as PriorityDecision, groff, false)), "")
	var asked: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(asked, "The sacrifice is asked.")
	assert_eq(asked.purpose, ChoosePermanentsDecision.Purpose.SACRIFICE)
	assert_eq(engine.submit([bear]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Groff"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Bear"), -1)
	assert_false(engine.game_state().object(rock).is_tapped, "No {3} was paid.")


func test_the_paying_cast_pays_three_and_sacrifices_nothing() -> void:
	var engine: MmEngine = _hero_main([_bear(), _mana_rock()])
	var groff: int = Scenario.card_in_hand(engine, engine.hero(), "Groff")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(engine.submit(Scenario.cast_index_other_additional(engine.pending_decision() as PriorityDecision, groff)), "")
	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(paying, "The {3} is paid as the mana cost is (CR 601.2f).")
	assert_eq(paying.remaining_generic, 3)
	assert_eq(Scenario.auto_pay(engine), "")
	assert_false(engine.pending_decision() is ChoosePermanentsDecision, "Nothing to sacrifice.")
	var on_stack: MmGameObject = engine.game_state().stack.objects().back()
	assert_eq(engine.game_state().characteristics_of(on_stack).mana_value(), 0, "CR 202.3: still its mana cost's.")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Groff"), -1)
	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Bear"), bear, "The Bear stays.")


func test_the_other_choice_adds_its_mana_to_the_mana_cost() -> void:
	var dear: MmCardDefinition = Scenario.groff("Dear Groff", Scenario.mana_cost(1, [MmMana.Type.WHITE]))
	var engine: MmEngine = _hero_main([_mana_rock(), _mana_rock("Second Rock")], [dear])
	var groff: int = Scenario.card_in_hand(engine, engine.hero(), "Dear Groff")

	var mana: MmManaCost = CastProcedure.mana_to_pay(engine.game_state(), engine.hero().id,
		engine.game_state().object(groff), false, false, false, true)

	assert_eq(mana.generic, 4)
	assert_eq(mana.symbols, [MmMana.Type.WHITE] as Array[MmMana.Type])
	assert_eq(CastProcedure.mana_to_pay(engine.game_state(), engine.hero().id, engine.game_state().object(groff)).generic, 1,
		"The first choice adds no mana.")


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


## An artifact costing {0}: "{T}: Add {W}{W}{W}."
func _mana_rock(card_name: String = "Mana Rock") -> MmCardDefinition:
	return Scenario.artifact(card_name, [Scenario.tap_for_mana(MmMana.Type.WHITE, 3)])


## The Hero in their main phase of Game Turn 3 with [param permanents] on the battlefield,
## holding a Groff, or [param hand].
func _hero_main(permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition] = []) -> MmEngine:
	var held: Array[MmCardDefinition] = hand.duplicate()
	if held.is_empty():
		held.append(Scenario.groff())
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(permanents, NO_CARDS, held), permanents,
		NO_CARDS, held, NO_CARDS, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
