extends GutTest
## An activated ability that works from the graveyard (CR 113.6k, engine ADR 0094):
## Sanitarium Skeleton's "{2}{B}: Return this card from your graveyard to your hand."
## works only while its card is in its owner's graveyard, and its owner activates it there
## whenever they have priority. Skeleton is a 1/2 costing {0} with it at {0}, unless another
## cost is given; Shock, an instant costing {0} that deals 2 damage to any target, puts it
## into the graveyard.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_it_returns_its_card_from_the_graveyard_to_its_owners_hand() -> void:
	var engine: MmEngine = _hero_main([Scenario.skeleton()], [Scenario.free_shock("Shock", 2)])
	_shock(engine, Scenario.permanents_named(engine, engine.hero().id, "Skeleton")[0])
	var dead: int = Scenario.card_in_graveyard(engine, engine.hero(), "Skeleton")

	assert_eq(Scenario.activate(engine, dead), "")
	assert_eq(Scenario.stack_ids(engine).size(), 1, "CR 602.2a: the ability uses the stack.")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Skeleton"), -1)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Skeleton"), -1)


func test_it_is_not_offered_on_the_battlefield_or_in_the_hand() -> void:
	var engine: MmEngine = _hero_main([Scenario.skeleton()], [Scenario.skeleton("Held Skeleton")])
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	var permanent: int = Scenario.permanents_named(engine, engine.hero().id, "Skeleton")[0]
	var held: int = Scenario.card_in_hand(engine, engine.hero(), "Held Skeleton")

	assert_eq(Scenario.activate_index(decision, permanent), -1, "CR 113.6k: it works only in the graveyard.")
	assert_eq(Scenario.activate_index(decision, held), -1)


func test_it_is_not_offered_without_the_mana_for_its_cost() -> void:
	var engine: MmEngine = _hero_main([Scenario.skeleton("Skeleton", Scenario.mana_cost(2))], [Scenario.free_shock("Shock", 2)])
	_shock(engine, Scenario.permanents_named(engine, engine.hero().id, "Skeleton")[0])

	var dead: int = Scenario.card_in_graveyard(engine, engine.hero(), "Skeleton")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, dead), -1, "No lands pay {2}.")


func test_another_ability_of_a_card_in_a_graveyard_is_not_offered() -> void:
	var giver: MmCardDefinition = Scenario.creature("Giver", 1, 1,
		[Scenario.activated(Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([giver], [Scenario.free_shock("Shock", 2)])
	_shock(engine, Scenario.permanents_named(engine, engine.hero().id, "Giver")[0])

	var dead: int = Scenario.card_in_graveyard(engine, engine.hero(), "Giver")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, dead), -1,
		"CR 113.6: a creature's ability works on the battlefield only.")


func test_it_is_not_offered_from_the_other_players_graveyard() -> void:
	var no_cards: Array[MmCardDefinition] = []
	var skeleton: MmCardDefinition = Scenario.skeleton("Their Skeleton")
	var shock: MmCardDefinition = Scenario.free_shock("Shock", 2)
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(no_cards, [skeleton], [shock]),
		no_cards, [skeleton], [shock], no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	_shock(engine, Scenario.permanents_named(engine, engine.villain().id, "Their Skeleton")[0])

	var dead: int = Scenario.card_in_graveyard(engine, engine.villain(), "Their Skeleton")

	assert_ne(dead, -1)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, dead), -1,
		"Only a card's owner may activate its ability in their graveyard.")


func test_it_may_be_activated_in_the_other_players_turn() -> void:
	var engine: MmEngine = _hero_main([Scenario.skeleton()], [Scenario.free_shock("Shock", 2)])
	_shock(engine, Scenario.permanents_named(engine, engine.hero().id, "Skeleton")[0])

	assert_eq(Scenario.play_until_step(engine, 4, Step.END), "")
	assert_eq(Scenario.pass_priority(engine), "", "The Villain has priority first in their own turn.")

	assert_eq(Scenario.activate(engine, Scenario.card_in_graveyard(engine, engine.hero(), "Skeleton")), "",
		"It has no timing restriction.")


func test_abilities_of_cards_in_a_graveyard_come_after_those_in_hand() -> void:
	var engine: MmEngine = _hero_main([Scenario.skeleton()],
		[Scenario.free_shock("Shock", 2), Scenario.cycler("Free Cycler", Scenario.mana_cost(0))])
	_shock(engine, Scenario.permanents_named(engine, engine.hero().id, "Skeleton")[0])
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	var last: ActivateAbilityAction = decision.actions.back() as ActivateAbilityAction
	var before: ActivateAbilityAction = decision.actions[decision.actions.size() - 2] as ActivateAbilityAction

	assert_not_null(last, "ADR 0012: every action offered before keeps its index.")
	assert_eq(engine.game_state().object(last.object_id).zone(), engine.hero().graveyard)
	assert_not_null(before)
	assert_eq(engine.game_state().object(before.object_id).zone(), engine.hero().hand)


func test_once_its_card_has_left_the_graveyard_a_second_activation_does_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.skeleton()], [Scenario.free_shock("Shock", 2)])
	_shock(engine, Scenario.permanents_named(engine, engine.hero().id, "Skeleton")[0])
	var dead: int = Scenario.card_in_graveyard(engine, engine.hero(), "Skeleton")
	assert_eq(Scenario.activate(engine, dead), "")
	var hand: int = engine.hero().hand.size()

	assert_eq(Scenario.activate(engine, dead), "", "It may be activated again while the first waits.")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().hand.size(), hand + 1, "ADR 0008: the card in hand is a new object, which the second finds nothing of.")


func test_copies_and_replays_activate_it_the_same() -> void:
	var engine: MmEngine = _hero_main([Scenario.skeleton()], [Scenario.free_shock("Shock", 2)])
	_shock(engine, Scenario.permanents_named(engine, engine.hero().id, "Skeleton")[0])
	Scenario.activate(engine, Scenario.card_in_graveyard(engine, engine.hero(), "Skeleton"))

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_eq(Scenario.stack_ids(copy).size(), 1)


func test_the_ability_keeps_where_it_works_through_saving_and_duplicating() -> void:
	var ability: ActivatedAbility = Scenario.back_from_the_graveyard(Scenario.mana_cost(0))
	var path: String = "user://test_graveyard_ability.tres"

	assert_eq(ResourceSaver.save(ability, path), OK)
	var loaded: ActivatedAbility = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ActivatedAbility
	DirAccess.remove_absolute(path)

	assert_true(loaded.is_activated_from_graveyard)
	assert_true((ability.duplicate_deep() as ActivatedAbility).is_activated_from_graveyard)


## The Hero in their main phase of Game Turn 3, having cast [param hero_permanents] on
## Game Turn 1 and holding [param hero_extras].
func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hero_extras)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hero_extras, no_cards,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## Casts the Hero's Shock at [param permanent] and lets it resolve.
func _shock(engine: MmEngine, permanent: int) -> void:
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [MmReference.to_object(permanent)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
