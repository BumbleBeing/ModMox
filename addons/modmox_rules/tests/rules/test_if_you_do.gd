extends GutTest
## "You may [effect]. If you do, [effect]." (CR 603.5, 608.2c, 608.2d), as Riddlesmith's
## "you may draw a card. If you do, discard a card.": a MayEffect, then an IfEffect with a
## YouDidCondition, which is true once the latest "you may" of the same spell or ability was
## answered yes. The second effect's own decision, which card to discard, is asked only then.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Choice := ChooseYesOrNoDecision.Choice

## The setup _looter_asked() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_yes_draws_then_asks_which_card_to_discard() -> void:
	var engine: MmEngine = _looter_asked()
	var hand_before: int = engine.hero().hand.size()

	assert_eq(engine.submit(Choice.YES), "")

	var asked: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	assert_not_null(asked, "If you do: the discard asks which card.")
	assert_eq(engine.hero().hand.size(), hand_before + 1, "The card was drawn first.")
	var discarded: int = engine.hero().hand.objects()[0].card_id
	assert_eq(engine.submit([engine.hero().hand.objects()[0].id]), "")
	assert_eq(engine.hero().hand.size(), hand_before)
	assert_eq(engine.hero().graveyard.objects().back().card_id, discarded)


func test_no_draws_nothing_and_asks_nothing() -> void:
	var engine: MmEngine = _looter_asked()
	var hand_before: int = engine.hero().hand.size()
	var graveyard_before: int = engine.hero().graveyard.size()

	assert_eq(engine.submit(Choice.NO), "")

	assert_true(engine.pending_decision() is PriorityDecision, "Nothing to discard is asked.")
	assert_eq(engine.hero().hand.size(), hand_before)
	assert_eq(engine.hero().graveyard.size(), graveyard_before)


func test_replaying_the_decision_log_gives_the_same_game() -> void:
	var engine: MmEngine = _looter_asked()
	assert_eq(engine.submit(Choice.YES), "")
	assert_eq(engine.submit([engine.hero().hand.objects()[0].id]), "")

	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_is_false_until_a_you_may_is_answered_yes() -> void:
	var context: MmEffectContext = MmEffectContext.new(1, 0)
	var condition: YouDidCondition = YouDidCondition.new()

	assert_false(condition.is_true(null, context), "Nothing was asked.")
	assert_true(condition.is_true(null, context.with_answered_yes(true)))
	assert_false(condition.is_true(null, context.with_answered_yes(true).with_answered_yes(false)), "The latest answer counts.")


func test_a_context_made_from_it_keeps_the_answer() -> void:
	var context: MmEffectContext = MmEffectContext.new(1, 0).with_answered_yes(true)

	assert_true(context.with_choice(0, null).answered_yes)
	assert_true(context.with_moved([]).with_paid_x(2).answered_yes)


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_if_you_do.tres"
	assert_eq(ResourceSaver.save(Scenario.looter(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var effects: Array[MmEffect] = (loaded.abilities[0] as TriggeredAbility).effects
	assert_true(effects[0] is MayEffect)
	assert_true((effects[1] as IfEffect).condition is YouDidCondition)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## The Hero in their first main phase of Game Turn 3, having cast a Looter, asked whether to
## draw a card as its trigger resolves.
func _looter_asked() -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var hand: Array[MmCardDefinition] = [Scenario.looter()]
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, hand)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(Scenario.cast_and_resolve(engine, "Looter"), "")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")
	return engine
