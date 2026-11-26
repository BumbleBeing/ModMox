extends GutTest
## "Exile the top card of your library. You may play it until the end of your next turn."
## (Clockwork Percussionist, engine ADR 0100): ExileTopOfLibraryEffect, then a
## MayPlayExiledEffect of the card it exiled. The card is marked with its player and the
## last Game Turn they may play it: a spell is cast with its usual timing and mana cost, and
## a land is played with a land play (CR 305.2).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Duration := MayPlayExiledEffect.Duration


func test_the_exiled_card_may_be_cast_now() -> void:
	var engine: MmEngine = _hero_main([_impulse(), _spark()], ["Spark"])

	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")

	var spark: int = Scenario.card_in_exile(engine, engine.hero(), "Spark")
	assert_ne(spark, -1, "The top card is exiled.")
	assert_eq(engine.game_state().object(spark).playable_through_game_turn, 5, "Cast in its own turn: through Game Turn 5.")
	var life: int = engine.hero().life
	assert_eq(Scenario.cast(engine, spark), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, life + 1)
	assert_eq(Scenario.card_in_exile(engine, engine.hero(), "Spark"), -1, "It left exile as it was cast.")


func test_it_may_be_cast_in_the_players_next_turn_but_not_the_turn_after() -> void:
	var engine: MmEngine = _hero_main([_impulse(), _spark()], ["Spark"])
	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")
	var spark: int = Scenario.card_in_exile(engine, engine.hero(), "Spark")

	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")
	assert_ne(Scenario.cast_index(engine.pending_decision() as PriorityDecision, spark), -1, "Game Turn 5 is their next turn.")
	assert_eq(Scenario.play_until_step(engine, 7, Step.PRECOMBAT_MAIN), "")
	assert_eq(Scenario.cast_index(engine.pending_decision() as PriorityDecision, spark), -1, "That turn has ended.")
	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Spark"), -1, "It stays in exile.")


func test_the_opponent_may_not_cast_it() -> void:
	var engine: MmEngine = _hero_main([_impulse(), _spark()], ["Spark"])
	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")
	var spark: int = Scenario.card_in_exile(engine, engine.hero(), "Spark")

	assert_eq(Scenario.play_until_step(engine, 4, Step.PRECOMBAT_MAIN), "")

	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(decision.player_id, engine.villain().id, "The Villain's main phase, at sorcery timing.")
	assert_eq(Scenario.cast_index(decision, spark), -1)


func test_a_sorcery_keeps_its_timing() -> void:
	var engine: MmEngine = _hero_main([_impulse(), _spark()], ["Spark"])
	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")
	var spark: int = Scenario.card_in_exile(engine, engine.hero(), "Spark")

	assert_eq(Scenario.play_until_step(engine, 3, Step.END), "")

	assert_eq(Scenario.cast_index(engine.pending_decision() as PriorityDecision, spark), -1, "Not in the end step.")


func test_a_land_is_played_with_a_land_play() -> void:
	var engine: MmEngine = _hero_main([_impulse(), _spark(), Scenario.basic_land("Mountain")], ["Mountain"])
	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")
	var mountain: int = Scenario.card_in_exile(engine, engine.hero(), "Mountain")
	var play: int = _land_play_index(engine.pending_decision() as PriorityDecision, mountain)
	assert_ne(play, -1, "A land in exile may be played.")
	assert_eq(Scenario.cast_index(engine.pending_decision() as PriorityDecision, mountain), -1, "A land is never cast.")

	assert_eq(engine.submit(play), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Mountain"), -1)
	assert_eq(engine.hero().lands_played_this_turn, 1)


func test_a_land_is_not_offered_once_the_land_play_is_used() -> void:
	var engine: MmEngine = _hero_main([_impulse(), _spark(), Scenario.basic_land("Mountain")], ["Mountain"],
		[Scenario.basic_land("Mountain")])
	var in_hand: int = Scenario.card_in_hand(engine, engine.hero(), "Mountain")
	assert_eq(engine.submit(_land_play_index(engine.pending_decision() as PriorityDecision, in_hand)), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")

	var mountain: int = Scenario.card_in_exile(engine, engine.hero(), "Mountain")
	assert_ne(mountain, -1)
	assert_eq(_land_play_index(engine.pending_decision() as PriorityDecision, mountain), -1)


func test_exiled_in_the_opponents_turn_it_lasts_through_the_players_next_turn() -> void:
	var engine: MmEngine = _hero_main([_impulse(), _spark()], ["Spark"])
	assert_eq(Scenario.play_until_step(engine, 4, Step.UPKEEP), "")
	assert_eq(engine.submit(0), "", "The Villain passes first in their own turn.")

	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")

	var spark: int = Scenario.card_in_exile(engine, engine.hero(), "Spark")
	assert_eq(engine.game_state().object(spark).playable_through_game_turn, 5)
	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")
	assert_ne(Scenario.cast_index(engine.pending_decision() as PriorityDecision, spark), -1)


func test_this_turn_only_ends_with_the_turn() -> void:
	var engine: MmEngine = _hero_main([_impulse(Duration.THIS_TURN), _spark()], ["Spark"])
	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")
	var spark: int = Scenario.card_in_exile(engine, engine.hero(), "Spark")
	assert_ne(Scenario.cast_index(engine.pending_decision() as PriorityDecision, spark), -1)

	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")

	assert_eq(Scenario.cast_index(engine.pending_decision() as PriorityDecision, spark), -1)


func test_the_views_show_who_may_play_it() -> void:
	var engine: MmEngine = _hero_main([_impulse(), _spark()], ["Spark"])

	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")

	var spark: int = Scenario.card_in_exile(engine, engine.hero(), "Spark")
	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var seen: MmObjectView = null
		for card: MmObjectView in engine.view_for(viewer).exiles.get(engine.hero().id, []):
			if card.id == spark:
				seen = card
		assert_not_null(seen, "Exile is public.")
		if seen != null:
			assert_eq(seen.playable_by_player_id, engine.hero().id)
			assert_eq(seen.playable_through_game_turn, 5)


# --- Helpers ---------------------------------------------------------------------------


## An instant costing {0}: "Exile the top card of your library. You may play it until the
## end of your next turn." (or "this turn").
func _impulse(how_long: Duration = Duration.YOUR_NEXT_TURN) -> MmCardDefinition:
	var exile: ExileTopOfLibraryEffect = ExileTopOfLibraryEffect.new()
	exile.amount = Scenario.constant(1)
	exile.players = YouSelection.new()
	var may_play: MayPlayExiledEffect = MayPlayExiledEffect.new()
	may_play.selection = MovedCardsSelection.new()
	may_play.duration = how_long
	return Scenario.instant("Impulse", Scenario.mana_cost(0), [], [exile, may_play])


## A sorcery costing {0}: "You gain 1 life."
func _spark() -> MmCardDefinition:
	return Scenario.sorcery("Spark", Scenario.mana_cost(0), [], [Scenario.gain_life(1, YouSelection.new())])


func _land_play_index(decision: PriorityDecision, object_id: int) -> int:
	for index: int in decision.actions.size():
		var play: PlayLandAction = decision.actions[index] as PlayLandAction
		if play != null and play.object_id == object_id:
			return index
	return -1


## The Hero's first main phase of Game Turn 3 holding an Impulse and [param hand], the top
## of their library holding [param tops]. Their deck cycles through [param deck].
func _hero_main(deck: Array[MmCardDefinition], tops: Array[String], hand: Array[MmCardDefinition] = []) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(deck), Scenario.cycled([]))
	var needed: Array[MmCardDefinition] = [deck[0]]
	needed.append_array(hand)
	var none: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.top_ready(setup, none, needed, tops)
	assert_not_null(engine, "No seed gave the needed cards.")
	return engine
