extends GutTest
## "You may pay {X}. When you do, [ability]" (CR 603.12, 107.3, engine ADR 0088's third
## addendum), as Wildborn Preserver's "Whenever another non-Human creature you control
## enters, you may pay {X}. When you do, put X +1/+1 counters on this creature.": the
## reflexive triggered ability goes on the stack on its own once X is paid, and carries the X
## paid, so its "X" reads what was paid for the ability that held it. Preserver is a 2/2
## costing {0} with that ability; the Mana Bird taps for {W}{W}{W}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []
const PLUS: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_paying_x_puts_a_reflexive_trigger_on_the_stack_that_puts_x_counters() -> void:
	var engine: MmEngine = _hero_main()
	var preserver: int = Scenario.permanent_named(engine, engine.hero().id, "Preserver")
	assert_eq(_asked_after(engine, "Bear"), "")

	assert_eq(Scenario.choose_x(engine, 2), "")
	assert_eq(Scenario.auto_pay(engine), "")

	assert_eq(Scenario.counters_on(engine, preserver, PLUS), 0, "CR 603.12: the counters wait on the stack.")
	assert_eq(_stack_abilities(engine), 1, "The reflexive trigger is on the stack, on its own.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.counters_on(engine, preserver, PLUS), 2, "It read the X paid.")


func test_declining_triggers_nothing() -> void:
	var engine: MmEngine = _hero_main()
	var preserver: int = Scenario.permanent_named(engine, engine.hero().id, "Preserver")
	assert_eq(_asked_after(engine, "Bear"), "")
	var triggered: int = Scenario.events_of(engine, AbilityTriggeredEvent).size()

	assert_eq(engine.submit(ChooseXToPayDecision.DECLINE), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), triggered)
	assert_eq(Scenario.counters_on(engine, preserver, PLUS), 0)


func test_paying_zero_triggers_it_and_puts_no_counters() -> void:
	var engine: MmEngine = _hero_main()
	var preserver: int = Scenario.permanent_named(engine, engine.hero().id, "Preserver")
	assert_eq(_asked_after(engine, "Bear"), "")
	var triggered: int = Scenario.events_of(engine, AbilityTriggeredEvent).size()

	assert_eq(Scenario.choose_x(engine, 0), "")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), triggered + 1, "Paying 0 is paying.")
	assert_eq(Scenario.counters_on(engine, preserver, PLUS), 0)


func test_a_human_entering_does_not_trigger_it() -> void:
	var engine: MmEngine = _hero_main()
	var triggered: int = Scenario.events_of(engine, AbilityTriggeredEvent).size()

	assert_eq(Scenario.cast_and_resolve(engine, "Villager"), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), triggered)


func test_another_preserver_entering_triggers_only_the_first() -> void:
	var engine: MmEngine = _hero_main()
	var triggered: int = Scenario.events_of(engine, AbilityTriggeredEvent).size()

	assert_eq(Scenario.cast_and_resolve(engine, "Preserver"), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), triggered + 1, "Not for itself: \"another\".")


func test_a_preserver_gone_before_its_reflexive_trigger_resolves_gets_no_counters() -> void:
	var engine: MmEngine = _hero_main()
	var preserver: int = Scenario.permanent_named(engine, engine.hero().id, "Preserver")
	assert_eq(_asked_after(engine, "Bear"), "")
	assert_eq(Scenario.choose_x(engine, 2), "")
	assert_eq(Scenario.auto_pay(engine), "")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Destroy"),
		[MmReference.to_object(preserver)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Preserver"), -1)
	assert_true(engine.game_state().stack.is_empty())


func test_the_x_paid_is_kept_by_a_copy_of_the_game_state() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(_asked_after(engine, "Bear"), "")
	assert_eq(Scenario.choose_x(engine, 3), "")
	assert_eq(Scenario.auto_pay(engine), "")
	var reflexive: MmGameObject = engine.game_state().stack.objects().back()

	var copy: MmGameState = engine.game_state().duplicate_state()

	assert_eq(copy.object(reflexive.id).paid_x, 3)


## Casts the card named [param card_name] and plays on until the Preserver asks how much X
## to pay.
func _asked_after(engine: MmEngine, card_name: String) -> String:
	var error: String = Scenario.cast_and_resolve(engine, card_name)
	return error if error != "" else Scenario.pass_to_x_choice(engine)


## How many abilities are on the stack.
func _stack_abilities(engine: MmEngine) -> int:
	var count: int = 0
	for item: MmGameObject in engine.game_state().stack.objects():
		if not item.is_card_or_copy():
			count += 1
	return count


## The Hero in their main phase of Game Turn 3 with a Preserver and a Mana Bird on the
## battlefield, holding a Bear (a 2/2), a Villager (a 1/1 Human), another Preserver and a
## Destroy ("Destroy target creature"), all costing {0}.
func _hero_main() -> MmEngine:
	var permanents: Array[MmCardDefinition] = [Scenario.preserver(), Scenario.mana_bird()]
	var destroy: DestroyEffect = DestroyEffect.new()
	destroy.selection = Scenario.targeted(0)
	var extras: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2), Scenario.typed_creature("Villager", 1, 1, ["Human"]),
		Scenario.preserver(), Scenario.instant("Destroy", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))], [destroy])]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(permanents, NO_CARDS, extras), permanents,
		NO_CARDS, extras, NO_CARDS, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
