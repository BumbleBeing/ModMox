extends GutTest
## Ordering simultaneous triggers (A339): the Hero drags them into a list whose top
## resolves first, and the answer lists them in the order they go on the stack.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID


func test_it_covers_only_an_order_decision() -> void:
	assert_true(TriggerOrder.covers(_decision(2)))
	assert_false(TriggerOrder.covers(null))
	assert_false(TriggerOrder.covers(ChoosePlayOrDrawDecision.new(HERO)))
	assert_false(TriggerOrder.new().is_active())
	assert_true(TriggerOrder.new(_decision(2)).is_active())


func test_it_starts_in_the_order_given_and_answers_with_the_top_one_put_on_the_stack_last() -> void:
	var order: TriggerOrder = TriggerOrder.new(_decision(3))

	assert_eq(order.order(), [0, 1, 2] as Array[int])
	assert_eq(order.answer(), [2, 1, 0], "The first one listed in an answer resolves last (ADR 0016).")
	assert_eq(_decision(3).validate(order.answer()), "")


func test_a_trigger_moved_down_lets_the_ones_it_passes_close_up_behind_it() -> void:
	var order: TriggerOrder = TriggerOrder.new(_decision(4))

	assert_true(order.move_to(0, 2))

	assert_eq(order.order(), [1, 2, 0, 3] as Array[int])
	assert_eq(order.answer(), [3, 0, 2, 1])
	assert_eq(_decision(4).validate(order.answer()), "")


func test_a_trigger_moved_up_pushes_the_ones_it_passes_down() -> void:
	var order: TriggerOrder = TriggerOrder.new(_decision(4))

	assert_true(order.move_to(3, 1))

	assert_eq(order.order(), [0, 3, 1, 2] as Array[int])
	assert_true(order.move_to(1, 0))
	assert_eq(order.order(), [3, 0, 1, 2] as Array[int])
	assert_true(order.move_to(0, 3))
	assert_eq(order.order(), [0, 1, 2, 3] as Array[int])


func test_a_move_to_where_it_is_or_to_no_place_changes_nothing() -> void:
	var order: TriggerOrder = TriggerOrder.new(_decision(3))

	assert_false(order.move_to(1, 1))
	assert_false(order.move_to(0, 3), "There is no fourth place.")
	assert_false(order.move_to(3, 0), "Nor a fourth trigger.")
	assert_false(order.move_to(-1, 1))
	assert_false(order.move_to(1, -1))
	assert_false(TriggerOrder.new().move_to(0, 1), "Nothing is being ordered.")

	assert_eq(order.order(), [0, 1, 2] as Array[int])
	assert_false(order.can_undo(), "And is nothing to take back.")


func test_undo_takes_back_one_move_at_a_time_however_far_each_went() -> void:
	var order: TriggerOrder = TriggerOrder.new(_decision(3))
	assert_false(order.can_undo())
	assert_false(order.undo())
	order.move_to(0, 2)
	order.move_to(1, 0)

	assert_true(order.can_undo())
	assert_true(order.undo())

	assert_eq(order.order(), [1, 2, 0] as Array[int], "The first move, two places in one step (A394).")
	assert_true(order.undo())
	assert_eq(order.order(), [0, 1, 2] as Array[int])
	assert_false(order.can_undo())


func test_it_is_for_the_decision_it_was_made_for_and_no_other() -> void:
	var decision: OrderTriggersDecision = _decision(2)
	var order: TriggerOrder = TriggerOrder.new(decision)

	assert_true(order.is_for(decision))
	assert_false(order.is_for(_decision(2)))
	assert_false(order.is_for(null))
	assert_true(TriggerOrder.new().is_for(null))


func test_triggers_that_do_the_same_for_the_same_reason_are_alike() -> void:
	var alike: OrderTriggersDecision = _decision(2)
	alike.abilities = [_gain(1), _gain(1)]
	var different_effect: OrderTriggersDecision = _decision(2)
	different_effect.abilities = [_gain(1), _gain(2)]
	var different_player: OrderTriggersDecision = _decision(2)
	different_player.abilities = [_gain(1), _gain(1)]
	different_player.triggering_player_ids = [0, 1]
	var different_object: OrderTriggersDecision = _decision(2)
	different_object.abilities = [_gain(1), _gain(1)]
	different_object.triggering_object_ids = [4, 5]

	assert_true(TriggerOrder.are_alike(alike), "Two separate copies of the same ability.")
	assert_false(TriggerOrder.are_alike(different_effect))
	assert_false(TriggerOrder.are_alike(different_player))
	assert_false(TriggerOrder.are_alike(different_object))


## An order decision for [param count] triggers, each gaining a different amount of life.
func _decision(count: int) -> OrderTriggersDecision:
	var decision: OrderTriggersDecision = OrderTriggersDecision.new(HERO, [] as Array[PendingTrigger])
	for index: int in count:
		decision.source_object_ids.append(10 + index)
		decision.source_card_ids.append(100 + index)
		decision.descriptions.append("trigger %d" % index)
		decision.abilities.append(_gain(index + 1))
		decision.triggering_player_ids.append(HERO)
		decision.triggering_object_ids.append(0)
	return decision


func _gain(amount: int) -> TriggeredAbility:
	return Scenario.triggered(Scenario.at_step(MmTurn.Step.UPKEEP, MmTrigger.Whose.YOU), [Scenario.gain_life(amount, Scenario.you())])
