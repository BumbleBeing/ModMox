extends GutTest
## Pacing: how long the Villain's next answer is held back, worked out from what the last
## snapshot showed (A358, A363).

const ACTION: int = 500
const MANA: int = 270


func test_a_snapshot_that_showed_nothing_waits_for_nothing() -> void:
	assert_eq(Pacing.wait_for([], ACTION, MANA), 0)


func test_quiet_events_alone_wait_for_nothing() -> void:
	for event: MmEvent in _quiet():
		assert_eq(Pacing.wait_for([event], ACTION, MANA), 0, event.get_script().resource_path.get_file())


func test_each_mana_event_alone_takes_the_mana_wait() -> void:
	for event: MmEvent in _mana():
		assert_eq(Pacing.wait_for([event], ACTION, MANA), MANA, event.get_script().resource_path.get_file())


func test_tapping_for_mana_among_quiet_events_takes_the_mana_wait() -> void:
	var events: Array[MmEvent] = _quiet()
	events.append_array(_mana())
	events.append_array(_quiet())

	assert_eq(Pacing.wait_for(events, ACTION, MANA), MANA)


func test_anything_else_takes_the_action_wait() -> void:
	assert_eq(Pacing.wait_for([SpellCastEvent.new(9, 1)], ACTION, MANA), ACTION)
	assert_eq(Pacing.wait_for([LifeLostEvent.new(0, 2)], ACTION, MANA), ACTION)


func test_an_action_among_mana_and_quiet_events_takes_the_action_wait_wherever_it_comes() -> void:
	var first: Array[MmEvent] = [SpellCastEvent.new(9, 1)]
	first.append_array(_mana())
	var last: Array[MmEvent] = _mana()
	last.append_array(_quiet())
	last.append(SpellCastEvent.new(9, 1))

	assert_eq(Pacing.wait_for(first, ACTION, MANA), ACTION)
	assert_eq(Pacing.wait_for(last, ACTION, MANA), ACTION)


func test_the_waits_are_whatever_is_handed_in() -> void:
	assert_eq(Pacing.wait_for([SpellCastEvent.new(9, 1)], 0, 0), 0)
	assert_eq(Pacing.wait_for(_mana(), 0, 0), 0)
	assert_eq(Pacing.wait_for(_mana(), 90, 30), 30)
	assert_eq(Pacing.wait_for(_mana(), 30, 90), 90, "Each kind takes its own wait, whichever is longer.")


func test_a_move_ends_before_the_next_land_is_tapped() -> void:
	assert_lt(Pacing.MOVE_SECONDS * 1000.0, float(Pacing.MANA_MSEC))
	assert_lt(Pacing.MANA_MSEC, Pacing.ACTION_MSEC)


func _quiet() -> Array[MmEvent]:
	return [
		StepStartedEvent.new(MmTurn.Step.UPKEEP), TurnStartedEvent.new(1), ManaEmptiedEvent.new(1),
		UntapEvent.new(4), CombatEndedEvent.new(),
		ContinuousEffectsEndedEvent.new(CreateContinuousEffect.Duration.UNTIL_END_OF_TURN),
		DamageRemovedEvent.new(4), DeathtouchDamageClearedEvent.new(4), RemovedFromCombatEvent.new(4),
	]


func _mana() -> Array[MmEvent]:
	return [TapEvent.new(4), ManaAddedEvent.new(1, MmMana.Type.RED, 1, 4), ManaSpentEvent.new(1, 0)]


func test_a_snapshot_starts_a_step_when_any_of_its_events_does() -> void:
	assert_false(Pacing.starts_step([]))
	assert_false(Pacing.starts_step([SpellCastEvent.new(9, 1), TurnStartedEvent.new(0)]))
	assert_true(Pacing.starts_step([StepStartedEvent.new(MmTurn.Step.UPKEEP)]))
	assert_true(Pacing.starts_step([SpellCastEvent.new(9, 1), StepStartedEvent.new(MmTurn.Step.DRAW), LifeLostEvent.new(0, 2)]))
