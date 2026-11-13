extends GutTest
## A window that closed for something used from it comes back only if that is taken back
## (ADR 0032, A528). An ability is on the stack from the moment it is announced, so being
## on the stack covers choosing its target and paying for it too.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const BOON: int = 30
const OTHER: int = 31
const Kind := HeldWindows.Kind


func test_nothing_reopens_when_nothing_was_used() -> void:
	var windows: HeldWindows = HeldWindows.new()

	windows.follow(_snapshot(true))

	assert_eq(windows.to_reopen.size(), 0)


func test_a_canceled_activation_reopens_its_window_once() -> void:
	var windows: HeldWindows = HeldWindows.new()
	windows.started(Kind.EMBLEMS, BOON)
	var choosing: EncounterSnapshot = _snapshot(false, [BOON])
	choosing.decision = ChooseTargetDecision.new(HERO, 40, 0, [] as Array[MmReference])
	windows.follow(choosing)
	assert_eq(windows.to_reopen.size(), 0, "Still choosing its target.")
	assert_true(windows.is_waiting(Kind.EMBLEMS))

	windows.follow(_snapshot(true))

	assert_eq(windows.to_reopen, [Kind.EMBLEMS] as Array[Kind])
	windows.follow(_snapshot(true))
	assert_eq(windows.to_reopen.size(), 0, "Only once.")


func test_it_stays_closed_while_the_mana_is_paid_even_through_an_undone_payment_step() -> void:
	var windows: HeldWindows = HeldWindows.new()
	windows.started(Kind.EMBLEMS, BOON)
	var paying: EncounterSnapshot = _snapshot(true, [BOON])
	paying.decision = PayManaDecision.new(HERO, [] as Array[MmAction], 0, [] as Array[MmMana.Type])

	windows.follow(paying)

	assert_eq(windows.to_reopen.size(), 0, "A payment step undone is not the activation undone.")
	assert_true(windows.is_waiting(Kind.EMBLEMS))


func test_undoing_it_off_the_stack_reopens_the_window() -> void:
	var windows: HeldWindows = HeldWindows.new()
	windows.started(Kind.POTIONS, BOON)
	windows.follow(_snapshot(false, [BOON]))

	windows.follow(_snapshot(true))

	assert_eq(windows.to_reopen, [Kind.POTIONS] as Array[Kind])


func test_once_it_has_resolved_a_later_undo_reopens_nothing() -> void:
	var windows: HeldWindows = HeldWindows.new()
	windows.started(Kind.EMBLEMS, BOON)
	windows.follow(_snapshot(false, [BOON]))
	windows.follow(_snapshot(false))
	assert_false(windows.is_waiting(Kind.EMBLEMS), "It resolved or was countered.")

	windows.follow(_snapshot(true))

	assert_eq(windows.to_reopen.size(), 0)


func test_a_target_asked_for_after_it_resolved_does_not_keep_it_waiting() -> void:
	# A trigger of something else asks the Hero for a target once the Boon is gone: the
	# Boon has still ended, and undoing that later choice must not reopen the window.
	var windows: HeldWindows = HeldWindows.new()
	windows.started(Kind.EMBLEMS, BOON)
	windows.follow(_snapshot(false, [BOON]))
	var later: EncounterSnapshot = _snapshot(false, [OTHER])
	later.decision = ChooseTargetDecision.new(HERO, 41, 0, [] as Array[MmReference])

	windows.follow(later)
	assert_false(windows.is_waiting(Kind.EMBLEMS))
	windows.follow(_snapshot(true))

	assert_eq(windows.to_reopen.size(), 0)


func test_two_things_used_from_one_window_are_each_remembered() -> void:
	var windows: HeldWindows = HeldWindows.new()
	windows.started(Kind.EMBLEMS, BOON)
	windows.follow(_snapshot(false, [BOON]))
	windows.started(Kind.EMBLEMS, OTHER)
	windows.follow(_snapshot(false, [BOON, OTHER]))

	windows.follow(_snapshot(true, [BOON]))
	assert_eq(windows.to_reopen, [Kind.EMBLEMS] as Array[Kind], "The second was undone.")
	assert_true(windows.is_waiting(Kind.EMBLEMS), "The first is still on the stack.")
	windows.follow(_snapshot(true))

	assert_eq(windows.to_reopen, [Kind.EMBLEMS] as Array[Kind], "And now the first.")
	assert_false(windows.is_waiting(Kind.EMBLEMS))


func test_each_window_is_followed_apart() -> void:
	var windows: HeldWindows = HeldWindows.new()
	windows.started(Kind.EMBLEMS, BOON)
	windows.started(Kind.POTIONS, OTHER)
	windows.follow(_snapshot(false, [BOON, OTHER]))

	windows.follow(_snapshot(true, [BOON]))

	assert_eq(windows.to_reopen, [Kind.POTIONS] as Array[Kind])
	assert_true(windows.is_waiting(Kind.EMBLEMS))


func test_a_refused_answer_is_forgotten() -> void:
	var windows: HeldWindows = HeldWindows.new()
	windows.started(Kind.EMBLEMS, BOON)

	windows.forget(Kind.EMBLEMS, BOON)
	windows.follow(_snapshot(true))

	assert_eq(windows.to_reopen.size(), 0)
	assert_false(windows.is_waiting(Kind.EMBLEMS))


## A snapshot with the Hero asked nothing, and on the stack an ability from each Game
## Object in [param stacked_from].
func _snapshot(is_rewind: bool, stacked_from: Array[int] = []) -> EncounterSnapshot:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = MmPlayerView.new()
	snapshot.is_rewind = is_rewind
	for source_id: int in stacked_from:
		var item: MmObjectView = MmObjectView.new()
		item.ability = ActivatedAbility.new()
		item.source_object_id = source_id
		snapshot.view.stack.append(item)
	return snapshot
