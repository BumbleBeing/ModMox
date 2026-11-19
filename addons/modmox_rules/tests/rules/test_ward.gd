extends GutTest
## "Ward [cost]" (CR 702.21a, ADR 0062): whenever this permanent becomes the target of a
## spell or ability an opponent controls, counter it unless that player pays [cost]. The
## trigger refers to the spell or ability, never targets it; as it resolves, the payer is
## asked a ChooseYesOrNoDecision with the cost, only if they could pay it, and a yes is paid
## one PayManaDecision at a time, as a cast's mana is.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_an_opponents_spell_aimed_at_it_triggers_ward_above_that_spell() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])

	var zap: int = _zap_warden(engine)

	var stack: Array[int] = Scenario.stack_ids(engine)
	assert_eq(stack.size(), 2, "CR 603.3: the trigger goes on the stack once the spell is cast.")
	var trigger: MmGameObject = engine.game_state().object(stack[0])
	assert_true(trigger.ability is WardAbility)
	assert_eq(trigger.controller_id, engine.villain().id, "The Warden's controller controls it.")
	assert_eq(trigger.triggering_object_id, zap, "\"It\" is the spell.")
	assert_eq(trigger.triggering_player_id, engine.hero().id, "\"That player\" is its controller.")
	assert_true(trigger.targets.is_empty(), "Ward refers to the spell; it does not target it.")


func test_its_controllers_own_spell_does_not_trigger_it() -> void:
	var no_hand: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main([Scenario.mana_bird(), Scenario.warden()], no_hand, [Scenario.creature("Ogre", 3, 3)])
	var warden: int = Scenario.permanent_named(engine, engine.hero().id, "Warden")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Zap"), [MmReference.to_object(warden)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1, "Only an opponent's spell or ability triggers ward.")


func test_a_spell_aimed_at_something_else_does_not_trigger_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])

	assert_eq(Scenario.cast(engine, _zap(engine), [MmReference.to_player(engine.villain().id)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1)


func test_the_payer_is_asked_to_pay_the_ward_cost_as_it_resolves() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	_zap_warden(engine)
	var trigger: int = Scenario.stack_ids(engine)[0]

	assert_eq(Scenario.pass_to_pay_or_not(engine), "")

	var asked: ChooseYesOrNoDecision = engine.pending_decision() as ChooseYesOrNoDecision
	assert_eq(asked.player_id, engine.hero().id, "The spell's controller answers, not ward's.")
	assert_eq(asked.stack_object_id, trigger)
	assert_eq(asked.cost.generic, 2)
	assert_true(asked.effect is CounterEffect, "What the question is about.")


func test_declining_counters_the_spell() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	var warden: int = _warden(engine)
	var zap: int = _zap_warden(engine)
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")

	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.NO), "")

	assert_true(_was_countered(engine, zap))
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.game_state().object(warden).damage_marked, 0)


func test_paying_lets_the_spell_resolve() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	var warden: int = _warden(engine)
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")
	var zap: int = _zap_warden(engine)
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")

	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(paying, "Paid as a cast's mana is.")
	assert_eq(paying.player_id, engine.hero().id)
	assert_eq(paying.remaining_generic, 2)
	assert_eq(Scenario.auto_pay(engine), "")
	assert_true(engine.game_state().object(bird).is_tapped, "CR 605.3a: a mana ability pays mid-resolution.")
	assert_eq(engine.hero().mana_pool().size(), 1, "The third mana was not needed and stays.")
	assert_false(_was_countered(engine, zap))
	assert_eq(Scenario.stack_ids(engine), [zap] as Array[int], "Ward has resolved.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.game_state().object(warden).damage_marked, 1)


func test_a_payer_who_cannot_pay_is_not_asked_and_the_spell_is_countered() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main(no_creatures)
	var zap: int = _zap_warden(engine)

	assert_eq(Scenario.pass_priority(engine), "")
	assert_eq(Scenario.pass_priority(engine), "")

	assert_false(engine.pending_decision() is ChooseYesOrNoDecision, "CR 118.3: a cost that cannot be paid is not.")
	assert_true(_was_countered(engine, zap))


func test_the_mana_in_the_pool_counts_toward_paying() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main(no_creatures, [_zap_card(), _ritual()])
	assert_eq(Scenario.cast_and_resolve(engine, "Ritual"), "")
	_zap_warden(engine)

	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
	assert_eq(Scenario.auto_pay(engine), "")

	assert_eq(engine.hero().mana_pool().size(), 0)


func test_an_opponents_activated_ability_aimed_at_it_is_countered_unless_paid() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird(), Scenario.healer("Healer")])
	var healer: int = Scenario.permanent_named(engine, engine.hero().id, "Healer")

	assert_eq(Scenario.activate(engine, healer, [MmReference.to_object(_warden(engine))]), "")
	var ability: int = Scenario.stack_ids(engine)[1]
	assert_eq(engine.game_state().object(Scenario.stack_ids(engine)[0]).triggering_object_id, ability)
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.NO), "")

	var left: AbilityLeftStackEvent = _left_stack(engine, ability)
	assert_not_null(left)
	assert_true(left.was_countered, "CR 701.6a: a countered ability is removed from the stack.")


func test_an_opponents_triggered_ability_aimed_at_it_triggers_ward() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], [Scenario.snarer()])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Snarer")), "")
	assert_eq(Scenario.pass_priority(engine), "")
	assert_eq(Scenario.pass_priority(engine), "")
	assert_true(engine.pending_decision() is ChooseTargetDecision, "The Snarer's trigger asks for its target.")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(_warden(engine))), "")

	var stack: Array[int] = Scenario.stack_ids(engine)
	assert_eq(stack.size(), 2)
	assert_true(engine.game_state().object(stack[0]).ability is WardAbility)
	assert_eq(engine.game_state().object(stack[0]).triggering_object_id, stack[1])


func test_a_spell_with_several_targets_is_countered_whole() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], [_fork()])
	var warden: int = _warden(engine)
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")
	var fork: int = Scenario.card_in_hand(engine, engine.hero(), "Fork")
	assert_eq(Scenario.cast_up_to(engine, fork, [MmReference.to_object(warden), MmReference.to_object(bird)]), "")
	assert_eq(Scenario.stack_ids(engine).size(), 2, "Only the Warden has ward.")
	var spell: int = Scenario.stack_ids(engine).back()

	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.NO), "")

	assert_true(_was_countered(engine, spell))
	assert_eq(engine.game_state().object(bird).damage_marked, 0, "Its other target is not dealt damage either.")


func test_two_warded_targets_each_trigger_and_one_unpaid_counters_the_spell() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird("Mana Bird", 4)], [_fork()], [Scenario.warden(), Scenario.warden("Keeper")])
	var fork: int = Scenario.card_in_hand(engine, engine.hero(), "Fork")
	var keeper: int = Scenario.permanent_named(engine, engine.villain().id, "Keeper")
	assert_eq(Scenario.cast_up_to(engine, fork, [MmReference.to_object(_warden(engine)), MmReference.to_object(keeper)]), "")
	var order: OrderTriggersDecision = engine.pending_decision() as OrderTriggersDecision
	assert_not_null(order, "CR 603.3b: the Villain orders their two triggers.")
	assert_eq(engine.submit([0, 1]), "")
	assert_eq(Scenario.stack_ids(engine).size(), 3, "One ward trigger for each.")
	var spell: int = Scenario.stack_ids(engine).back()

	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_false(_was_countered(engine, spell), "Paid for the first.")
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.NO), "")

	assert_true(_was_countered(engine, spell))


func test_nothing_is_asked_once_the_spell_has_left_the_stack() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], [_zap_card(), Scenario.free_counter("Nix")])
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")
	var zap: int = _zap_warden(engine)
	var trigger: int = Scenario.stack_ids(engine)[0]
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Nix"), [MmReference.to_object(zap)]), "")

	assert_eq(Scenario.pass_priority(engine), "")
	assert_eq(Scenario.pass_priority(engine), "")
	assert_true(_was_countered(engine, zap), "Nix countered the Zap.")
	assert_eq(Scenario.pass_priority(engine), "")
	assert_eq(Scenario.pass_priority(engine), "")

	assert_false(engine.pending_decision() is ChooseYesOrNoDecision, "There is nothing left to pay for.")
	assert_not_null(_left_stack(engine, trigger), "Ward resolved, doing nothing.")
	assert_false(engine.game_state().object(bird).is_tapped)


func test_a_cast_taken_back_leaves_no_ward_trigger() -> void:
	var dear_zap: MmCardDefinition = Scenario.instant("Dear Zap", Scenario.mana_cost(1), [Scenario.any_target()],
		[Scenario.deal_damage(1, Scenario.targeted(0))])
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], [dear_zap])
	var priority: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(engine.submit(Scenario.cast_index(priority, Scenario.card_in_hand(engine, engine.hero(), "Dear Zap"))), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(_warden(engine))), "")
	assert_true(engine.pending_decision() is PayManaDecision)

	assert_eq(engine.cancel_cast(), "")

	assert_true(engine.game_state().stack.is_empty())
	assert_true(engine.game_state().pending_triggers.is_empty())


func test_a_copy_made_while_ward_is_asked_carries_on_alike() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	var zap: int = _zap_warden(engine)
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1), true)

	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.NO), "")
	assert_eq(copy.submit(ChooseYesOrNoDecision.Choice.NO), "")

	assert_true(_was_countered(engine, zap))
	assert_true(_was_countered(copy, zap))


func test_a_copy_made_while_ward_is_being_paid_carries_on_alike() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	var warden: int = _warden(engine)
	_zap_warden(engine)
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1), true)

	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.auto_pay(copy), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.resolve_stack(copy), "")

	assert_eq(copy.game_state().object(warden).damage_marked, 1)
	assert_eq(engine.game_state().object(warden).damage_marked, 1)
	assert_eq(copy.hero().mana_pool().size(), engine.hero().mana_pool().size())


func test_replaying_the_decision_log_gives_the_same_game() -> void:
	# ADR 0010: yes and each payment are plain ints in the decision log.
	var setup: MmEncounterSetup = _setup([Scenario.mana_bird()], [Scenario.warden()], [_zap_card()])
	var engine: MmEngine = _ready_from(setup, [Scenario.mana_bird()], [Scenario.warden()], [_zap_card()])
	_zap_warden(engine)
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
	assert_eq(Scenario.auto_pay(engine), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_an_answer_that_is_not_yes_or_no_is_refused() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	_zap_warden(engine)
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	var asked: MmPendingDecision = engine.pending_decision()

	assert_ne(engine.submit(2), "")
	assert_ne(engine.submit([0]), "")

	assert_eq(engine.pending_decision(), asked, "Still asked.")


func test_ward_is_made_from_its_cost_alone() -> void:
	var ward: WardAbility = Scenario.ward(Scenario.mana_cost(3))

	var trigger: BecomesTargetTrigger = ward.trigger as BecomesTargetTrigger
	assert_not_null(trigger)
	assert_true(trigger.filter is IsSourceFilter, "\"This permanent\".")
	assert_eq(trigger.whose, MmTrigger.Whose.OPPONENT)
	assert_eq(ward.effects.size(), 1)
	var countering: CounterEffect = ward.effects[0] as CounterEffect
	assert_true(countering.selection is TriggeringObjectSelection, "\"It\": the spell or ability.")
	assert_eq(countering.unless_paid.generic, 3)
	ward.mana_cost = Scenario.mana_cost(1)
	assert_eq(countering.unless_paid.generic, 1, "A new ward cost changes what is asked.")


func test_a_counter_with_no_cost_asks_nothing() -> void:
	var countering: CounterEffect = Scenario.counter(Scenario.targeted(0))

	assert_null(countering.decision_as_it_begins(null, null, 0))


## An instant costing {0}: "Deal 1 damage to each of up to two target creatures."
func _fork() -> MmCardDefinition:
	return Scenario.instant("Fork", Scenario.mana_cost(0), [Scenario.up_to_targets(Scenario.of_type(MmCardTypes.CardType.CREATURE), 2)],
		[Scenario.deal_damage(1, Scenario.targeted(0))])


## An instant costing {0}: "Add {W}{W}."
func _ritual() -> MmCardDefinition:
	return Scenario.instant("Ritual", Scenario.mana_cost(0), [], [Scenario.add_mana(MmMana.Type.WHITE, 2)])


## The Warden, the Villain's.
func _warden(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.villain().id, "Warden")


## The Hero's Zap in hand.
func _zap(engine: MmEngine) -> int:
	return Scenario.card_in_hand(engine, engine.hero(), "Zap")


## Casts the Hero's Zap at the Villain's Warden, and returns the spell.
func _zap_warden(engine: MmEngine) -> int:
	var zap: int = _zap(engine)
	assert_eq(Scenario.cast(engine, zap, [MmReference.to_object(_warden(engine))]), "")
	return Scenario.stack_ids(engine).back()


func _was_countered(engine: MmEngine, spell_id: int) -> bool:
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved.object_id == spell_id and moved.reason == ZoneChangeEvent.Reason.COUNTER:
			return true
	return false


func _left_stack(engine: MmEngine, object_id: int) -> AbilityLeftStackEvent:
	for event: MmEvent in Scenario.events_of(engine, AbilityLeftStackEvent):
		if (event as AbilityLeftStackEvent).object_id == object_id:
			return event as AbilityLeftStackEvent
	return null


## An instant costing {0}: 1 damage to any target.
func _zap_card() -> MmCardDefinition:
	return Scenario.free_shock("Zap", 1)


## The Hero's [param hero_creatures] and the Villain's [param villain_creatures] (a Warden
## unless given) on the battlefield, in the Hero's main phase of Game Turn 3 with
## [param hand] (a Zap unless given) in hand.
func _hero_main(hero_creatures: Array[MmCardDefinition], hand: Array[MmCardDefinition] = [],
		villain_creatures: Array[MmCardDefinition] = []) -> MmEngine:
	var villains: Array[MmCardDefinition] = villain_creatures.duplicate()
	if villains.is_empty():
		villains.append(Scenario.warden())
	var held: Array[MmCardDefinition] = hand.duplicate()
	if held.is_empty():
		held.append(_zap_card())
	return _ready_from(_setup(hero_creatures, villains, held), hero_creatures, villains, held)


func _setup(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		hand: Array[MmCardDefinition]) -> MmEncounterSetup:
	var hero_cards: Array[MmCardDefinition] = hero_creatures.duplicate()
	if hero_cards.is_empty():
		hero_cards.append(Scenario.creature("Bear", 2, 2))  # Never cast: the deck is not only spells.
	var villain_cards: Array[MmCardDefinition] = villain_creatures.duplicate()
	if villain_cards.is_empty():
		villain_cards.append(Scenario.creature("Ogre", 3, 3))
	return Scenario.combat_setup(hero_cards, villain_cards, hand)


func _ready_from(setup: MmEncounterSetup, hero_creatures: Array[MmCardDefinition],
		villain_creatures: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, villain_creatures, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
