extends GutTest
## The Debug Decision Panel can answer every kind of Pending Decision: each kind becomes one
## of five generic forms, and what is filled in becomes an answer the decision accepts.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID


func test_priority_lists_each_action_by_what_it_does() -> void:
	var view: MmPlayerView = _view()
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		PassAction.new(), PlayLandAction.new(2), CastSpellAction.new(3), ActivateAbilityAction.new(1, 0),
	] as Array[MmAction])

	var form: DebugDecisionForm = DebugDecisionForm.of(decision, view)

	assert_eq(form.kind, DebugDecisionForm.Kind.PICK_ONE)
	assert_eq(form.options, ["Pass", "Play Mountain", "Cast Zap", "Tap Forest for mana (#1)"] as Array[String])
	assert_eq(form.option_object_ids, [DebugDecisionForm.NONE, 2, 3, 1] as Array[int])
	assert_false(form.can_cancel)
	assert_eq(decision.validate(form.answer_for_pick(2)), "")
	assert_eq(form.answer_for_pick(2), 2)


func test_paying_mana_says_what_is_owed_and_can_be_canceled() -> void:
	var view: MmPlayerView = _view()
	view.mana_pools[HERO] = [MmMana.new(MmMana.Type.RED, 1)]
	var decision: PayManaDecision = PayManaDecision.new(HERO,
		[PayWithManaAction.new(0), ActivateAbilityAction.new(1, 0)] as Array[MmAction], 2, [MmMana.Type.RED] as Array[MmMana.Type])

	var form: DebugDecisionForm = DebugDecisionForm.of(decision, view)

	assert_eq(form.title, "Pay mana: {2}{R} still owed")
	assert_eq(form.options, ["Spend {R} from the pool", "Tap Forest for mana (#1)"] as Array[String])
	assert_true(form.can_cancel, "Paying is a step of a cast in progress.")
	assert_eq(decision.validate(form.answer_for_pick(1)), "")


func test_choosing_a_target_names_players_and_objects_and_can_be_canceled() -> void:
	var decision: ChooseTargetDecision = ChooseTargetDecision.new(HERO, 3, 0,
		[MmReference.to_player(HERO), MmReference.to_player(VILLAIN), MmReference.to_object(1)] as Array[MmReference])

	var form: DebugDecisionForm = DebugDecisionForm.of(decision, _view())

	assert_eq(form.title, "Choose a target for Zap")
	assert_eq(form.options, ["You", "The other player", "Forest"] as Array[String])
	assert_eq(form.option_object_ids, [DebugDecisionForm.NONE, DebugDecisionForm.NONE, 1] as Array[int])
	assert_true(form.can_cancel)
	assert_eq(decision.validate(form.answer_for_pick(1)), "")


func test_keep_or_mulligan_and_play_or_draw_are_two_choices_each() -> void:
	var keep: KeepOrMulliganDecision = KeepOrMulliganDecision.new(HERO, 1, 1)
	var play: ChoosePlayOrDrawDecision = ChoosePlayOrDrawDecision.new(HERO)

	var keep_form: DebugDecisionForm = DebugDecisionForm.of(keep, _view())
	var play_form: DebugDecisionForm = DebugDecisionForm.of(play, _view())

	assert_eq(keep_form.options, ["Keep 1", "Mulligan"] as Array[String], "Two cards in hand, one to the bottom.")
	assert_eq(keep_form.answer_for_pick(1), KeepOrMulliganDecision.Choice.MULLIGAN)
	assert_eq(keep.validate(keep_form.answer_for_pick(0)), "")
	assert_eq(play_form.options, ["Play first", "Draw"] as Array[String])
	assert_eq(play_form.answer_for_pick(1), ChoosePlayOrDrawDecision.Choice.DRAW)
	assert_eq(play.validate(play_form.answer_for_pick(1)), "")


func test_a_replacement_choice_lists_each_effect() -> void:
	var options: Array[ActiveReplacementEffect] = [
		ActiveReplacementEffect.new(PreventDamageReplacementEffect.new(), 1, HERO, 1, 1),
		ActiveReplacementEffect.new(RegenerationReplacementEffect.new(), 2, HERO, 1, 1),
	]
	var decision: ChooseReplacementEffectDecision = ChooseReplacementEffectDecision.new(HERO, null, options)

	var form: DebugDecisionForm = DebugDecisionForm.of(decision, _view())

	assert_eq(form.kind, DebugDecisionForm.Kind.PICK_ONE)
	assert_eq(form.options.size(), 2)
	assert_eq(decision.validate(form.answer_for_pick(1)), "")


func test_attackers_are_picked_in_any_number() -> void:
	var decision: DeclareAttackersDecision = DeclareAttackersDecision.new(HERO, [1, 2, 3] as Array[int])

	var form: DebugDecisionForm = DebugDecisionForm.of(decision, _view())

	assert_eq(form.kind, DebugDecisionForm.Kind.PICK_SOME)
	assert_eq(form.count, DebugDecisionForm.NONE, "Any number may attack.")
	assert_eq(form.options, ["Forest (#1)", "Mountain (#2)", "Zap (#3)"] as Array[String])
	assert_eq(form.answer_for_picks([2, 0] as Array[int]), [3, 1] as Array[int])
	assert_eq(decision.validate(form.answer_for_picks([2, 0] as Array[int])), "")
	assert_eq(decision.validate(form.answer_for_picks([] as Array[int])), "")


func test_cards_to_discard_and_to_bottom_keep_the_order_picked() -> void:
	var discard: ChooseCardsToDiscardDecision = ChooseCardsToDiscardDecision.new(HERO, 2, [1, 2, 3] as Array[int])
	var bottom: ChooseCardsToBottomDecision = ChooseCardsToBottomDecision.new(HERO, 2, [1, 2, 3] as Array[int])

	var discard_form: DebugDecisionForm = DebugDecisionForm.of(discard, _view())
	var bottom_form: DebugDecisionForm = DebugDecisionForm.of(bottom, _view())

	assert_eq(discard_form.count, 2)
	assert_eq(discard.validate(discard_form.answer_for_picks([0, 2] as Array[int])), "")
	assert_ne(discard.validate(discard_form.answer_for_picks([0] as Array[int])), "", "One short is rejected with a reason.")
	assert_eq(bottom_form.answer_for_picks([2, 1] as Array[int]), [3, 2] as Array[int], "The last one picked ends up lowest.")
	assert_eq(bottom.validate(bottom_form.answer_for_picks([2, 1] as Array[int])), "")


func test_triggers_are_put_in_order() -> void:
	var decision: OrderTriggersDecision = OrderTriggersDecision.new(HERO, [] as Array[PendingTrigger])
	decision.source_object_ids = [1, 2]
	decision.source_card_ids = [1, 2]
	decision.descriptions = ["Forest's trigger", "Mountain's trigger"]

	var form: DebugDecisionForm = DebugDecisionForm.of(decision, _view())

	assert_eq(form.kind, DebugDecisionForm.Kind.ORDER)
	assert_eq(form.options, ["Forest's trigger", "Mountain's trigger"] as Array[String])
	assert_eq(form.option_object_ids, [1, 2] as Array[int])
	assert_eq(form.answer_for_picks([1, 0] as Array[int]), [1, 0])
	assert_eq(decision.validate(form.answer_for_picks([1, 0] as Array[int])), "")


func test_blockers_are_paired_with_the_attackers_each_may_block() -> void:
	var decision: DeclareBlockersDecision = DeclareBlockersDecision.new(HERO, [1, 2] as Array[int], [3] as Array[int],
		{1: [3], 2: []} as Dictionary[int, Array], {1: 1, 2: 1} as Dictionary[int, int])

	var form: DebugDecisionForm = DebugDecisionForm.of(decision, _view())

	assert_eq(form.kind, DebugDecisionForm.Kind.PAIR_UP)
	assert_eq(form.options, ["Forest", "Mountain"] as Array[String])
	assert_eq(form.pair_choice_ids, [[3], []])
	assert_eq(form.pair_choice_labels, [["Zap (#3)"], []])
	assert_eq(form.answer_for_pairs([[3], []]), [[1, 3]])
	assert_eq(decision.validate(form.answer_for_pairs([[3], []])), "")
	assert_eq(decision.validate(form.answer_for_pairs([[], []])), "", "Blocking with nothing is an answer too.")


func test_combat_damage_is_split_among_its_recipients() -> void:
	var decision: DivideCombatDamageDecision = DivideCombatDamageDecision.new(HERO, 3, 4,
		[MmReference.to_object(1), MmReference.to_object(2)] as Array[MmReference], [2, 3] as Array[int])

	var form: DebugDecisionForm = DebugDecisionForm.of(decision, _view())

	assert_eq(form.kind, DebugDecisionForm.Kind.SPLIT)
	assert_eq(form.amount, 4)
	assert_eq(form.options, ["Forest", "Mountain"] as Array[String])
	assert_eq(form.lethal_amounts, [2, 3] as Array[int])
	assert_eq(decision.validate(form.answer_for_split([2, 2] as Array[int])), "")
	assert_ne(decision.validate(form.answer_for_split([1, 1] as Array[int])), "", "Shares must add up.")


func test_a_name_is_found_in_any_zone_the_view_shows() -> void:
	var view: MmPlayerView = _view()
	var buried: MmObjectView = MmObjectView.new()
	buried.id = 40
	buried.name = "Bear"
	view.graveyards[VILLAIN] = [buried]

	assert_eq(DebugDecisionForm.name_of(view, 40), "Bear")
	assert_eq(DebugDecisionForm.name_of(view, 3), "Zap")
	assert_eq(DebugDecisionForm.name_of(view, 99), "object 99", "Something the view does not show has no name.")


## A view with a Forest (1) that taps for mana on the battlefield, and a Mountain (2) and a
## Zap (3) in hand.
func _view() -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var forest: MmObjectView = _object(1, "Forest")
	forest.abilities = [Scenario.tap_for_mana(MmMana.Type.GREEN, 1)]
	view.battlefield = [forest]
	view.hand = [_object(2, "Mountain"), _object(3, "Zap")]
	return view


func _object(id: int, object_name: String) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.name = object_name
	return seen
