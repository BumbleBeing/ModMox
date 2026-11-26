extends GutTest
## An Activation Restriction that is a condition, "Activate only if [condition]" (CR 602.5b,
## engine ADR 0095), and the condition "a [filter] died under your control this turn", read
## from the creatures that died this turn as each last existed (CR 700.4, 608.2h). Conscript
## is Cult Conscript on a 2/1 Skeleton costing {0}: "This creature enters tapped." and "{0}:
## Return this card from your graveyard to the battlefield. Activate only if a non-Skeleton
## creature died under your control this turn." Shock, an instant costing {0} that deals 2
## damage to any target, kills what it is aimed at.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_with_no_creature_dead_this_turn_it_is_not_offered() -> void:
	var engine: MmEngine = _hero_main([Scenario.conscript()], _shocks(1))
	_shock(engine, _permanent(engine, engine.hero(), "Conscript"))

	var dead: int = Scenario.card_in_graveyard(engine, engine.hero(), "Conscript")

	assert_ne(dead, -1)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, dead), -1,
		"Conscript is a Skeleton, so its own death does not count.")


func test_once_a_non_skeleton_creature_of_yours_has_died_it_returns_its_card_tapped() -> void:
	var engine: MmEngine = _hero_main([Scenario.conscript(), Scenario.creature("Bear", 2, 2)], _shocks(2))
	_shock(engine, _permanent(engine, engine.hero(), "Conscript"))
	_shock(engine, _permanent(engine, engine.hero(), "Bear"))

	assert_eq(Scenario.activate(engine, Scenario.card_in_graveyard(engine, engine.hero(), "Conscript")), "")
	Scenario.resolve_stack(engine)

	var returned: int = _permanent(engine, engine.hero(), "Conscript")
	assert_ne(returned, -1, "Back on the battlefield.")
	assert_true(engine.game_state().object(returned).is_tapped, "It enters tapped (CR 614.12).")


func test_another_skeleton_dying_does_not_count() -> void:
	var bones: MmCardDefinition = Scenario.typed_creature("Bones", 2, 2, ["Skeleton"])
	var engine: MmEngine = _hero_main([Scenario.conscript(), bones], _shocks(2))
	_shock(engine, _permanent(engine, engine.hero(), "Conscript"))

	_shock(engine, _permanent(engine, engine.hero(), "Bones"))

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_graveyard(engine, engine.hero(), "Conscript")), -1)


func test_the_other_players_creature_dying_does_not_count() -> void:
	var bear: MmCardDefinition = Scenario.creature("Their Bear", 2, 2)
	var engine: MmEngine = _ready_with([Scenario.conscript()], [bear], _shocks(2))
	_shock(engine, _permanent(engine, engine.hero(), "Conscript"))

	_shock(engine, _permanent(engine, engine.villain(), "Their Bear"))

	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Their Bear"), -1)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_graveyard(engine, engine.hero(), "Conscript")), -1, "It died under the Villain's control.")


func test_a_creature_exiled_did_not_die() -> void:
	var held: Array[MmCardDefinition] = _shocks(1)
	held.append(Scenario.exile_spell("Exile"))
	var engine: MmEngine = _hero_main([Scenario.conscript(), Scenario.creature("Bear", 2, 2)], held)
	_shock(engine, _permanent(engine, engine.hero(), "Conscript"))

	assert_eq(Scenario.cast_and_resolve(engine, "Exile", [MmReference.to_object(_permanent(engine, engine.hero(), "Bear"))]), "")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_graveyard(engine, engine.hero(), "Conscript")), -1, "CR 700.4: dying is going to a graveyard.")


func test_a_token_dying_counts() -> void:
	var held: Array[MmCardDefinition] = _shocks(2)
	held.append(Scenario.free_tokens("Kittens", Scenario.cat()))
	var engine: MmEngine = _hero_main([Scenario.conscript()], held)
	_shock(engine, _permanent(engine, engine.hero(), "Conscript"))
	assert_eq(Scenario.cast_and_resolve(engine, "Kittens"), "")

	_shock(engine, Scenario.tokens_on_battlefield(engine)[0])

	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_graveyard(engine, engine.hero(), "Conscript")), -1, "CR 700.4: a token dies too.")


func test_the_next_turn_forgets_what_died() -> void:
	var engine: MmEngine = _hero_main([Scenario.conscript(), Scenario.creature("Bear", 2, 2)], _shocks(2))
	_shock(engine, _permanent(engine, engine.hero(), "Conscript"))
	_shock(engine, _permanent(engine, engine.hero(), "Bear"))

	assert_eq(Scenario.play_until_step(engine, 4, Step.END), "")
	assert_eq(Scenario.pass_priority(engine), "", "The Villain has priority first in their own turn.")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_graveyard(engine, engine.hero(), "Conscript")), -1, "Bear died last turn.")


func test_a_mana_ability_with_an_unmet_condition_pays_for_nothing() -> void:
	var grim: ActivatedAbility = Scenario.tap_for_mana(MmMana.Type.WHITE, 1)
	grim.condition = Scenario.died_this_turn(Scenario.of_type(MmCardTypes.CardType.CREATURE))
	var ogre: MmCardDefinition = Scenario.creature("Ogre", 1, 1)
	ogre.mana_cost = Scenario.mana_cost(1)
	var engine: MmEngine = _hero_main([Scenario.creature("Grim Elf", 1, 1, [grim])], [ogre])
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_eq(Scenario.activate_index(decision, _permanent(engine, engine.hero(), "Grim Elf")), -1, "CR 602.5b")
	assert_eq(Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), "Ogre")), -1,
		"So it does not count toward paying {1}.")


func test_copies_and_replays_remember_what_died() -> void:
	var engine: MmEngine = _hero_main([Scenario.conscript(), Scenario.creature("Bear", 2, 2)], _shocks(2))
	_shock(engine, _permanent(engine, engine.hero(), "Conscript"))
	_shock(engine, _permanent(engine, engine.hero(), "Bear"))

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_ne(Scenario.activate_index(copy.pending_decision() as PriorityDecision,
		Scenario.card_in_graveyard(copy, copy.hero(), "Conscript")), -1)


## The Hero in their main phase of Game Turn 3, having cast [param hero_permanents] on
## Game Turn 1 and holding [param hero_extras].
func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	return _ready_with(hero_permanents, NO_CARDS, hero_extras)


## Like _hero_main(), with [param villain_permanents] cast by the Villain on Game Turn 2.
func _ready_with(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, NO_CARDS,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## [param count] Shocks, each its own card so that the Hero holds that many.
func _shocks(count: int) -> Array[MmCardDefinition]:
	var shocks: Array[MmCardDefinition] = []
	for index: int in count:
		shocks.append(Scenario.free_shock("Shock %d" % (index + 1), 2))
	return shocks


## Casts one of the Hero's Shocks at [param object_id] and lets it resolve.
func _shock(engine: MmEngine, object_id: int) -> void:
	for card: MmGameObject in engine.hero().hand.objects():
		var card_name: String = engine.game_state().characteristics_of(card).name
		if card_name.begins_with("Shock"):
			assert_eq(Scenario.cast(engine, card.id, [MmReference.to_object(object_id)]), "")
			assert_eq(Scenario.resolve_stack(engine), "")
			return
	fail_test("No Shock in hand.")


## The first permanent named [param card_name] that [param player] controls, or -1.
func _permanent(engine: MmEngine, player: MmPlayer, card_name: String) -> int:
	var ids: Array[int] = Scenario.permanents_named(engine, player.id, card_name)
	return ids[0] if not ids.is_empty() else -1
