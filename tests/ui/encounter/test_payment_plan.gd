extends GutTest
## What Auto-tap would use to pay for one spell or ability.


func test_a_new_plan_is_empty() -> void:
	var plan: PaymentPlan = PaymentPlan.new()

	assert_true(plan.is_empty())
	assert_eq(plan.size(), 0)
	assert_false(plan.taps(4))
	assert_false(plan.spends(MmMana.Type.GREEN))


func test_it_holds_the_sources_tapped_in_order_and_the_pool_mana_spent() -> void:
	var plan: PaymentPlan = PaymentPlan.new()
	plan.add_pool(MmMana.Type.GREEN)
	plan.add_pool(MmMana.Type.GREEN)
	plan.add_source(9)
	plan.add_source(4)

	assert_false(plan.is_empty())
	assert_eq(plan.size(), 4)
	assert_eq(plan.source_ids, [9, 4] as Array[int])
	assert_true(plan.taps(4))
	assert_false(plan.taps(5))
	assert_true(plan.spends(MmMana.Type.GREEN))
	assert_false(plan.spends(MmMana.Type.RED))


func test_each_payment_made_is_taken_out_one_at_a_time() -> void:
	var plan: PaymentPlan = PaymentPlan.new()
	plan.add_pool(MmMana.Type.GREEN)
	plan.add_pool(MmMana.Type.GREEN)
	plan.add_source(9)

	plan.take_pool(MmMana.Type.GREEN)
	assert_true(plan.spends(MmMana.Type.GREEN), "One green unit is still to be spent.")
	plan.take_pool(MmMana.Type.GREEN)
	assert_false(plan.spends(MmMana.Type.GREEN))
	plan.take_source(9)
	plan.take_source(9)

	assert_true(plan.is_empty())


func test_a_copy_does_not_change_with_the_plan_it_was_made_from() -> void:
	var plan: PaymentPlan = PaymentPlan.new()
	plan.add_source(9)
	plan.add_pool(MmMana.Type.RED)

	var copy: PaymentPlan = plan.copy()
	plan.take_source(9)
	plan.take_pool(MmMana.Type.RED)

	assert_true(copy.taps(9))
	assert_true(copy.spends(MmMana.Type.RED))
