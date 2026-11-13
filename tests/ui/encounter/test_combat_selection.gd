extends GutTest
## A CombatSelection holds the Hero's half-made answer to declaring attackers, declaring
## blockers or dividing combat damage, and gives the answer when it is confirmed.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID


func test_it_covers_the_three_combat_decisions_and_nothing_else() -> void:
	assert_true(CombatSelection.covers(_attack()))
	assert_true(CombatSelection.covers(_blocks()))
	assert_true(CombatSelection.covers(_divide()))
	assert_false(CombatSelection.covers(PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])))
	assert_false(CombatSelection.covers(null))


func test_a_selection_for_another_kind_of_decision_selects_nothing() -> void:
	var priority: PriorityDecision = PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])
	var selection: CombatSelection = CombatSelection.new(priority)

	assert_false(selection.is_active())
	assert_false(selection.is_complete())
	assert_false(selection.is_clickable(1))
	assert_false(selection.click(1))
	assert_eq(selection.confirm_text(), "")
	assert_eq(selection.hint(), "")
	assert_true(selection.is_for(null), "It stands for no decision at all.")
	assert_false(CombatSelection.new().is_active())


func test_clicking_candidates_chooses_attackers_and_clicking_again_puts_them_back() -> void:
	var decision: DeclareAttackersDecision = _attack()
	var selection: CombatSelection = CombatSelection.new(decision)
	assert_true(selection.is_active())
	assert_eq(selection.confirm_text(), "No attacks")

	assert_true(selection.click(3))
	assert_true(selection.click(1))

	assert_eq(selection.attacker_ids(), [3, 1] as Array[int])
	assert_true(selection.is_chosen(3))
	assert_false(selection.is_chosen(2))
	assert_eq(selection.confirm_text(), "Attack with 2")
	assert_eq(selection.answer(), [1, 3] as Array[int], "In ID order whatever order they were clicked in.")
	assert_eq(decision.validate(selection.answer()), "")

	assert_true(selection.click(3))

	assert_eq(selection.answer(), [1] as Array[int])
	assert_eq(selection.confirm_text(), "Attack with 1")
	assert_true(selection.is_complete(), "Any number may attack, none included.")


func test_a_creature_that_may_not_attack_is_not_clickable() -> void:
	var selection: CombatSelection = CombatSelection.new(_attack())

	assert_true(selection.is_clickable(2))
	assert_false(selection.is_clickable(9))
	assert_false(selection.click(9))
	assert_eq(selection.attacker_ids().size(), 0)
	assert_false(selection.can_undo(), "A click that did nothing is not something to take back.")


func test_all_attack_chooses_every_candidate_without_confirming() -> void:
	var decision: DeclareAttackersDecision = _attack()
	var selection: CombatSelection = CombatSelection.new(decision)
	selection.click(2)

	assert_true(selection.select_all())

	assert_eq(selection.answer(), [1, 2, 3] as Array[int])
	assert_eq(decision.validate(selection.answer()), "")
	assert_false(selection.select_all(), "They are all chosen already.")
	selection.undo()
	assert_eq(selection.answer(), [2] as Array[int], "One undo takes the whole of it back.")
	assert_false(CombatSelection.new(_blocks()).select_all(), "Only attackers have it.")


func test_a_blocker_is_picked_up_then_paired_with_the_attacker_clicked() -> void:
	var decision: DeclareBlockersDecision = _blocks()
	var selection: CombatSelection = CombatSelection.new(decision)
	assert_eq(selection.picked_ids(), [] as Array[int])
	assert_eq(selection.confirm_text(), "No blocks")
	assert_eq(selection.hint(), "Click one or more creatures, then the attacker they block.")
	assert_false(selection.is_clickable(20), "An attacker is clicked only for a blocker that is picked up.")

	assert_true(selection.click(1))

	assert_eq(selection.picked_ids(), [1] as Array[int])
	assert_eq(selection.target_ids(), [20, 22] as Array[int], "Only what this blocker can block.")
	assert_true(selection.is_clickable(22))
	assert_false(selection.is_clickable(21))
	assert_false(selection.is_chosen(1), "Picked up is not yet blocking.")

	assert_true(selection.click(22))

	assert_eq(selection.pairs(), [[1, 22]])
	assert_eq(selection.picked_ids(), [] as Array[int], "Paired, it is put down.")
	assert_true(selection.is_chosen(1))
	assert_eq(selection.blocks_of(1), [22] as Array[int])
	assert_eq(selection.confirm_text(), "Confirm blocks")
	assert_eq(selection.hint(), "", "The hint goes once a block is made (A326).")
	assert_eq(decision.validate(selection.answer()), "")


func test_a_blocker_cannot_be_paired_with_an_attacker_it_cannot_block() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())
	selection.click(1)

	assert_false(selection.click(21), "Only the Spider reaches the flyer.")

	assert_eq(selection.pairs().size(), 0)
	assert_eq(selection.picked_ids(), [1] as Array[int])


func test_one_click_on_a_blocking_creature_takes_it_off() -> void:
	var decision: DeclareBlockersDecision = _blocks()
	var selection: CombatSelection = CombatSelection.new(decision)
	selection.click(1)
	selection.click(22)

	assert_true(selection.click(1))

	assert_eq(selection.pairs().size(), 0, "It no longer blocks.")
	assert_eq(selection.picked_ids(), [] as Array[int], "And it is not picked up: the next click on it starts over.")
	assert_false(selection.is_chosen(1))
	assert_eq(decision.validate(selection.answer()), "")

	selection.click(1)
	selection.click(20)

	assert_eq(selection.pairs(), [[1, 20]], "Taken off, it can be given another attacker.")


func test_taking_one_blocker_off_leaves_the_one_picked_up_in_hand() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())
	selection.click(1)
	selection.click(22)
	selection.click(2)

	selection.click(1)

	assert_eq(selection.pairs().size(), 0)
	assert_eq(selection.picked_ids(), [2] as Array[int])


func test_blockers_clicked_one_after_another_are_picked_up_together_and_paired_with_one_click() -> void:
	var decision: DeclareBlockersDecision = _blocks()
	var selection: CombatSelection = CombatSelection.new(decision)

	selection.click(1)
	selection.click(3)

	assert_eq(selection.picked_ids(), [1, 3] as Array[int], "The second joins the first (A430).")
	assert_false(selection.is_chosen(1), "Picked up is not yet blocking.")
	assert_eq(selection.pairs().size(), 0)

	assert_true(selection.click(22))

	assert_eq(selection.pairs(), [[1, 22], [3, 22]])
	assert_eq(selection.picked_ids(), [] as Array[int], "Paired, they are all put down.")
	assert_eq(selection.refused().size(), 0)
	assert_eq(decision.validate(selection.answer()), "")


func test_a_blocker_can_join_one_that_already_blocks_an_attacker() -> void:
	var decision: DeclareBlockersDecision = _blocks()
	var selection: CombatSelection = CombatSelection.new(decision)
	selection.click(2)
	selection.click(22)

	selection.click(1)
	selection.click(22)

	assert_eq(selection.pairs(), [[2, 22], [1, 22]])
	assert_eq(decision.validate(selection.answer()), "")


func test_a_group_glows_every_attacker_any_of_it_can_block() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())

	selection.click(1)
	assert_eq(selection.target_ids(), [20, 22] as Array[int])
	selection.click(2)

	assert_eq(selection.target_ids(), [20, 21, 22] as Array[int], "The Spider reaches the flyer (A431).")
	assert_true(selection.is_clickable(21))


func test_a_group_with_a_blocker_that_cannot_block_the_attacker_is_refused_whole() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())
	selection.click(1)
	selection.click(2)
	selection.click(3)

	assert_false(selection.click(21), "Blockers 1 and 3 cannot block the flyer (A432).")

	assert_eq(selection.refused(), [[1, 21], [3, 21]], "It says which blocks were illegal.")
	assert_eq(selection.pairs().size(), 0, "Nothing is paired, not even the Spider.")
	assert_eq(selection.picked_ids(), [1, 2, 3] as Array[int], "The group stays picked up.")
	assert_eq(selection.confirm_text(), "No blocks")

	assert_true(selection.undo(), "The refused click was no change: undo takes back the last pick-up.")
	assert_eq(selection.picked_ids(), [1, 2] as Array[int])
	assert_eq(selection.refused().size(), 0)


func test_the_refusal_is_forgotten_at_the_next_click() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())
	selection.click(1)
	selection.click(2)
	selection.click(21)
	assert_eq(selection.refused().size(), 1)

	assert_true(selection.click(22))

	assert_eq(selection.refused().size(), 0)
	assert_eq(selection.pairs(), [[1, 22], [2, 22]])


func test_a_group_is_refused_when_one_of_it_has_no_block_to_spare() -> void:
	var decision: DeclareBlockersDecision = DeclareBlockersDecision.new(HERO, [1, 2] as Array[int], [20, 21, 22] as Array[int],
		{1: [20, 21, 22], 2: [20, 21, 22]} as Dictionary[int, Array], {1: 2, 2: 1} as Dictionary[int, int])
	var selection: CombatSelection = CombatSelection.new(decision)
	selection.click(1)
	selection.click(20)
	selection.click(21)
	selection.click(2)

	assert_false(selection.click(22), "Blocker 1 already blocks its two.")

	assert_eq(selection.refused(), [[1, 22]])
	assert_eq(selection.pairs(), [[1, 20], [1, 21]])

	assert_true(selection.click(21), "One it blocks already is left as it is.")

	assert_eq(selection.pairs(), [[1, 20], [1, 21], [2, 21]])
	assert_eq(decision.validate(selection.answer()), "")


func test_clicking_one_of_the_group_puts_only_that_one_down() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())
	selection.click(1)
	selection.click(2)
	selection.click(3)

	assert_true(selection.click(2))

	assert_eq(selection.picked_ids(), [1, 3] as Array[int], "The rest stay in hand (A433).")
	assert_eq(selection.target_ids(), [20, 22] as Array[int])


func test_a_click_on_empty_board_puts_the_whole_group_down() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())
	selection.click(1)
	selection.click(2)

	assert_true(selection.put_down())

	assert_eq(selection.picked_ids(), [] as Array[int], "A434.")
	assert_eq(selection.pairs().size(), 0)


func test_undo_takes_a_group_pairing_back_in_one_and_then_each_pick_up() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())
	selection.click(1)
	selection.click(2)
	selection.click(22)

	assert_true(selection.undo())

	assert_eq(selection.pairs().size(), 0, "The whole pairing is one click (A435).")
	assert_eq(selection.picked_ids(), [1, 2] as Array[int])

	assert_true(selection.undo())

	assert_eq(selection.picked_ids(), [1] as Array[int])


func test_a_click_on_empty_board_puts_the_blocker_down_unassigned() -> void:
	var twice: DeclareBlockersDecision = DeclareBlockersDecision.new(HERO, [1] as Array[int], [20, 22] as Array[int],
		{1: [20, 22]} as Dictionary[int, Array], {1: 2} as Dictionary[int, int])
	var selection: CombatSelection = CombatSelection.new(twice)
	assert_false(selection.put_down(), "Nothing is picked up.")
	selection.click(1)
	selection.click(22)
	assert_eq(selection.picked_ids(), [1] as Array[int], "One that may block two stays picked up.")

	assert_true(selection.put_down())

	assert_eq(selection.picked_ids(), [] as Array[int])
	assert_eq(selection.pairs().size(), 0)
	assert_false(CombatSelection.new(_attack()).put_down())


func test_a_blocker_that_may_block_two_switches_pairings_and_stops_at_its_limit() -> void:
	var decision: DeclareBlockersDecision = DeclareBlockersDecision.new(HERO, [1] as Array[int], [20, 21, 22] as Array[int],
		{1: [20, 21, 22]} as Dictionary[int, Array], {1: 2} as Dictionary[int, int])
	var selection: CombatSelection = CombatSelection.new(decision)

	selection.click(1)
	selection.click(20)
	assert_eq(selection.picked_ids(), [1] as Array[int], "It stays picked up for its second block (A323).")
	selection.click(22)

	assert_eq(selection.pairs(), [[1, 20], [1, 22]])
	assert_eq(selection.target_ids(), [20, 22] as Array[int], "At its limit, only those it blocks can be clicked.")
	assert_false(selection.click(21))
	assert_eq(decision.validate(selection.answer()), "")

	selection.click(20)

	assert_eq(selection.pairs(), [[1, 22]], "Clicking one it blocks takes that block off.")
	assert_eq(selection.target_ids(), [20, 21, 22] as Array[int])
	assert_true(selection.click(21))
	assert_eq(decision.validate(selection.answer()), "")


func test_the_default_division_kills_as_many_as_it_can_in_order() -> void:
	var selection: CombatSelection = CombatSelection.new(_divide())

	assert_eq(selection.amounts(), [1, 2, 3] as Array[int], "Six damage: lethal to all three, nothing over.")
	assert_eq(selection.left_to_assign(), 0)
	assert_true(selection.is_complete())
	assert_eq(selection.confirm_text(), "Assign damage")
	assert_eq(_divide().validate(selection.answer()), "")


func test_the_default_division_skips_what_it_cannot_kill_and_wastes_nothing() -> void:
	var short: DivideCombatDamageDecision = _divide_of(4, [2, 3, 2], false)
	var over: DivideCombatDamageDecision = _divide_of(9, [2, 3, 2], false)
	var none: DivideCombatDamageDecision = _divide_of(1, [2, 3], false)

	assert_eq(CombatSelection.default_split(short), [2, 0, 2] as Array[int],
		"Lethal to the first, not enough for the second, and still enough to kill the third.")
	assert_eq(CombatSelection.default_split(_divide_of(3, [2, 3, 2], false)), [2, 1, 0] as Array[int],
		"What cannot kill anything more goes on the first recipient still alive.")
	assert_eq(CombatSelection.default_split(over), [4, 3, 2] as Array[int], "All dead: the spare goes onto the first.")
	assert_eq(CombatSelection.default_split(none), [1, 0] as Array[int])
	for decision: DivideCombatDamageDecision in [short, over, none]:
		assert_eq(decision.validate(CombatSelection.default_split(decision)), "", decision.describe())


func test_with_trample_the_default_division_gives_the_player_what_is_left_over() -> void:
	var decision: DivideCombatDamageDecision = _divide_of(6, [1, 2], true)

	var selection: CombatSelection = CombatSelection.new(decision)

	assert_eq(selection.amounts(), [1, 2, 3] as Array[int])
	assert_eq(decision.validate(selection.answer()), "")


func test_amounts_go_up_and_down_within_the_damage_there_is() -> void:
	var decision: DivideCombatDamageDecision = _divide()
	var selection: CombatSelection = CombatSelection.new(decision)
	assert_false(selection.can_raise(0), "Everything is assigned.")
	assert_false(selection.change_amount(0, 1))

	assert_true(selection.change_amount(2, -1))

	assert_eq(selection.amounts(), [1, 2, 2] as Array[int])
	assert_eq(selection.left_to_assign(), 1)
	assert_false(selection.is_complete(), "One damage is unassigned (A318).")
	assert_ne(decision.validate(selection.answer()), "")
	assert_true(selection.can_raise(0))

	assert_true(selection.change_amount(0, 1))

	assert_eq(selection.amounts(), [2, 2, 2] as Array[int])
	assert_true(selection.is_complete())
	assert_eq(decision.validate(selection.answer()), "")


func test_an_amount_never_drops_below_zero_and_a_missing_recipient_is_refused() -> void:
	var selection: CombatSelection = CombatSelection.new(_divide_of(2, [2, 3], false))
	assert_eq(selection.amounts(), [2, 0] as Array[int])

	assert_false(selection.can_lower(1))
	assert_false(selection.change_amount(1, -1))
	assert_false(selection.change_amount(5, 1))
	assert_false(selection.change_amount(-1, -1))
	assert_false(selection.change_amount(0, 0))

	assert_eq(selection.amounts(), [2, 0] as Array[int])
	assert_false(selection.can_undo())


func test_an_amount_is_lethal_once_it_reaches_what_kills_its_recipient() -> void:
	var selection: CombatSelection = CombatSelection.new(_divide())

	assert_true(selection.is_lethal(0))
	assert_true(selection.is_lethal(2))
	selection.change_amount(2, -1)
	assert_false(selection.is_lethal(2), "Two of the three it takes.")
	selection.change_amount(0, 1)
	assert_true(selection.is_lethal(0), "More than lethal is lethal too.")
	assert_false(selection.is_lethal(7))


func test_with_trample_the_player_gets_damage_only_once_every_blocker_has_lethal() -> void:
	var decision: DivideCombatDamageDecision = _divide_of(6, [1, 2], true)
	var selection: CombatSelection = CombatSelection.new(decision)
	assert_false(selection.is_lethal(2), "A player has no lethal amount here.")

	assert_false(selection.can_lower(1), "The player has damage, so this blocker must keep lethal (CR 702.19b).")
	selection.change_amount(2, -1)
	selection.change_amount(2, -1)
	selection.change_amount(2, -1)
	assert_true(selection.can_lower(1), "With nothing on the player, a blocker may be given less.")
	selection.change_amount(1, -1)

	assert_eq(selection.amounts(), [1, 1, 0] as Array[int])
	assert_false(selection.can_raise(2), "A blocker is short of lethal.")
	assert_false(selection.change_amount(2, 1))
	assert_true(selection.can_raise(0), "A blocker can always take more.")

	selection.change_amount(1, 1)
	assert_true(selection.can_raise(2))
	for point: int in 3:
		selection.change_amount(2, 1)

	assert_eq(selection.amounts(), [1, 2, 3] as Array[int])
	assert_eq(decision.validate(selection.answer()), "")


func test_undo_takes_back_one_click_at_a_time_and_says_when_there_is_none() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())
	assert_false(selection.can_undo())
	assert_false(selection.undo(), "So Z can fall through to the previous answer (A320).")
	selection.click(1)
	selection.click(22)
	selection.click(2)

	assert_true(selection.undo())
	assert_eq(selection.picked_ids(), [] as Array[int])
	assert_eq(selection.pairs(), [[1, 22]])

	assert_true(selection.undo())
	assert_eq(selection.picked_ids(), [1] as Array[int])
	assert_eq(selection.pairs().size(), 0)

	assert_true(selection.undo())
	assert_eq(selection.picked_ids(), [] as Array[int])
	assert_false(selection.undo())


func test_undo_takes_back_a_point_of_damage() -> void:
	var selection: CombatSelection = CombatSelection.new(_divide())
	selection.change_amount(2, -1)
	selection.change_amount(0, 1)

	selection.undo()

	assert_eq(selection.amounts(), [1, 2, 2] as Array[int])
	selection.undo()
	assert_eq(selection.amounts(), [1, 2, 3] as Array[int])


func test_it_is_for_its_own_decision_and_no_other() -> void:
	var decision: DeclareAttackersDecision = _attack()
	var selection: CombatSelection = CombatSelection.new(decision)

	assert_true(selection.is_for(decision), "A redraw of the same decision keeps it.")
	assert_false(selection.is_for(_attack()), "The same question asked again is a new decision.")
	assert_false(selection.is_for(null))


func test_what_it_hands_out_cannot_change_it() -> void:
	var selection: CombatSelection = CombatSelection.new(_blocks())
	selection.click(1)
	selection.click(22)

	(selection.pairs()[0] as Array)[1] = 99
	selection.pairs().clear()

	assert_eq(selection.pairs(), [[1, 22]])
	var divide: CombatSelection = CombatSelection.new(_divide())
	divide.amounts()[0] = 50
	assert_eq(divide.amounts(), [1, 2, 3] as Array[int])


## Creatures 1, 2 and 3 may attack.
func _attack() -> DeclareAttackersDecision:
	return DeclareAttackersDecision.new(HERO, [1, 2, 3] as Array[int])


## Attackers 20, 21 (a flyer) and 22. Blockers 1 and 3 cannot block the flyer; 2 can.
func _blocks() -> DeclareBlockersDecision:
	return DeclareBlockersDecision.new(HERO, [1, 2, 3] as Array[int], [20, 21, 22] as Array[int],
		{1: [20, 22], 2: [20, 21, 22], 3: [20, 22]} as Dictionary[int, Array], {1: 1, 2: 1, 3: 1} as Dictionary[int, int])


## Six damage among three blockers that take 1, 2 and 3 to kill.
func _divide() -> DivideCombatDamageDecision:
	return _divide_of(6, [1, 2, 3], false)


func _divide_of(amount: int, lethal: Array, has_trample: bool) -> DivideCombatDamageDecision:
	var recipients: Array[MmReference] = []
	var lethal_amounts: Array[int] = []
	for index: int in lethal.size():
		recipients.append(MmReference.to_object(20 + index))
		lethal_amounts.append(lethal[index])
	if has_trample:
		recipients.append(MmReference.to_player(VILLAIN))
	return DivideCombatDamageDecision.new(HERO, 1, amount, recipients, lethal_amounts)
