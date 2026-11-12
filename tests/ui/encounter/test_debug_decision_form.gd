extends GutTest
## The Debug Decision Panel answers every kind of Pending Decision that has no input of its
## own yet: each becomes one of three generic forms, and what is filled in becomes an answer
## the decision accepts.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID


func test_priority_has_no_form_since_the_hand_took_casting_and_playing_a_land() -> void:
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		PassAction.new(), ActivateAbilityAction.new(1, 0), PlayLandAction.new(2), CastSpellAction.new(3),
	] as Array[MmAction])

	assert_false(DebugDecisionForm.covers(decision))
	assert_null(DebugDecisionForm.of(decision, _view()))


func test_paying_mana_and_choosing_a_target_have_no_form() -> void:
	var view: MmPlayerView = _view()
	var pay: PayManaDecision = PayManaDecision.new(HERO,
		[ActivateAbilityAction.new(1, 0)] as Array[MmAction], 2, [MmMana.Type.RED] as Array[MmMana.Type])
	var target: ChooseTargetDecision = ChooseTargetDecision.new(HERO, 3, 0,
		[MmReference.to_player(HERO), MmReference.to_object(1)] as Array[MmReference])

	assert_null(DebugDecisionForm.of(pay, view), "Mana is paid by clicking sources (A253).")
	assert_null(DebugDecisionForm.of(target, view), "A target is clicked.")
	assert_null(DebugDecisionForm.of(null, view))
	assert_false(DebugDecisionForm.covers(pay))
	assert_false(DebugDecisionForm.covers(target))
	assert_false(DebugDecisionForm.covers(null))
	assert_true(DebugDecisionForm.covers(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int])))


func test_the_combat_decisions_have_no_form() -> void:
	var view: MmPlayerView = _view()
	var attackers: DeclareAttackersDecision = DeclareAttackersDecision.new(HERO, [1, 2] as Array[int])
	var blockers: DeclareBlockersDecision = DeclareBlockersDecision.new(HERO, [1] as Array[int], [3] as Array[int],
		{1: [3]} as Dictionary[int, Array], {1: 1} as Dictionary[int, int])
	var damage: DivideCombatDamageDecision = DivideCombatDamageDecision.new(HERO, 3, 4,
		[MmReference.to_object(1), MmReference.to_object(2)] as Array[MmReference], [2, 3] as Array[int])

	for decision: MmPendingDecision in [attackers, blockers, damage]:
		assert_false(DebugDecisionForm.covers(decision), decision.describe())
		assert_null(DebugDecisionForm.of(decision, view), "Combat is answered on the creatures themselves (A328).")
	assert_eq(DebugDecisionForm.Kind.size(), 2, "Pair up and split went with them, and put in order with the stack (13d).")


func test_cards_to_discard_are_picked_by_number_and_named_with_their_ids() -> void:
	var discard: ChooseCardsToDiscardDecision = ChooseCardsToDiscardDecision.new(HERO, 1, [2, 3] as Array[int])

	var form: DebugDecisionForm = DebugDecisionForm.of(discard, _view())

	assert_eq(form.kind, DebugDecisionForm.Kind.PICK_SOME)
	assert_eq(form.title, "Discard 1")
	assert_eq(form.options, ["Mountain (#2)", "Zap (#3)"] as Array[String])
	assert_eq(form.answer_for_picks([1] as Array[int]), [3] as Array[int])


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


func test_ordering_triggers_and_choosing_a_replacement_effect_have_no_form() -> void:
	var order: OrderTriggersDecision = OrderTriggersDecision.new(HERO, [] as Array[PendingTrigger])
	var choice: ChooseReplacementEffectDecision = ChooseReplacementEffectDecision.new(HERO, null, [] as Array[ActiveReplacementEffect])

	assert_false(DebugDecisionForm.covers(order), "Triggers are ordered in the Stack Window (13d).")
	assert_null(DebugDecisionForm.of(order, _view()))
	assert_false(DebugDecisionForm.covers(choice), "A replacement effect is chosen in its own window (13d).")
	assert_null(DebugDecisionForm.of(choice, _view()))


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
