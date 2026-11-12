extends GutTest
## What clicking each thing answers for a Pending Decision, and the Glow drawn from the same
## map: targets orange-red, mana sources blue, everything else green.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const LAND_ID: int = 5


func test_no_decision_glows_nothing() -> void:
	var glow: DecisionClicks = DecisionClicks.of(null, _view())

	assert_eq(glow.objects.size(), 0)
	assert_eq(glow.players.size(), 0)
	assert_eq(glow.clickable_ids().size(), 0)
	assert_eq(glow.player_answers.size(), 0)


func test_priority_glows_what_can_be_played_green_and_mana_sources_blue() -> void:
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		PassAction.new(), PlayLandAction.new(7), CastSpellAction.new(8), ActivateAbilityAction.new(LAND_ID, 0),
	] as Array[MmAction])

	var glow: DecisionClicks = DecisionClicks.of(decision, _view())

	assert_eq(glow.objects, {7: DecisionClicks.Kind.OTHER, 8: DecisionClicks.Kind.OTHER, LAND_ID: DecisionClicks.Kind.MANA})
	assert_eq(glow.players.size(), 0)


func test_targets_glow_orange_red_on_objects_and_players_alike() -> void:
	var decision: ChooseTargetDecision = ChooseTargetDecision.new(HERO, 20, 0,
		[MmReference.to_player(VILLAIN), MmReference.to_object(11)] as Array[MmReference])

	var glow: DecisionClicks = DecisionClicks.of(decision, _view())

	assert_eq(glow.objects, {11: DecisionClicks.Kind.TARGET})
	assert_eq(glow.players, {VILLAIN: DecisionClicks.Kind.TARGET})


func test_paying_mana_glows_sources_blue_and_maps_each_pool_color_to_its_first_unit() -> void:
	var view: MmPlayerView = _view()
	view.mana_pools[HERO] = [MmMana.new(MmMana.Type.RED, 1), MmMana.new(MmMana.Type.GREEN, 1), MmMana.new(MmMana.Type.RED, 1)]
	var decision: PayManaDecision = PayManaDecision.new(HERO, [
		PayWithManaAction.new(0), PayWithManaAction.new(1), PayWithManaAction.new(2), ActivateAbilityAction.new(LAND_ID, 0),
	] as Array[MmAction], 1, [] as Array[MmMana.Type])

	var glow: DecisionClicks = DecisionClicks.of(decision, view)

	assert_eq(glow.objects, {LAND_ID: DecisionClicks.Kind.MANA})
	assert_eq(glow.pool_answers, {MmMana.Type.RED: 0, MmMana.Type.GREEN: 1}, "The answer that spends one unit of each color.")


func test_attackers_blockers_and_cards_to_choose_glow_green() -> void:
	var attackers: DecisionClicks = DecisionClicks.of(DeclareAttackersDecision.new(HERO, [3, 4] as Array[int]), _view())
	var blockers: DecisionClicks = DecisionClicks.of(DeclareBlockersDecision.new(HERO, [3] as Array[int], [9] as Array[int],
		{3: [9]} as Dictionary[int, Array], {3: 1} as Dictionary[int, int]), _view())
	var discard: DecisionClicks = DecisionClicks.of(ChooseCardsToDiscardDecision.new(HERO, 1, [1, 2] as Array[int]), _view())
	var bottom: DecisionClicks = DecisionClicks.of(ChooseCardsToBottomDecision.new(HERO, 1, [1, 2] as Array[int]), _view())

	assert_eq(attackers.objects, {3: DecisionClicks.Kind.OTHER, 4: DecisionClicks.Kind.OTHER})
	assert_eq(blockers.objects, {3: DecisionClicks.Kind.OTHER}, "The blockers to choose, not the attackers.")
	assert_eq(discard.objects.keys(), [1, 2])
	assert_eq(bottom.objects.keys(), [1, 2])


func test_dividing_damage_glows_its_recipients_as_targets() -> void:
	var decision: DivideCombatDamageDecision = DivideCombatDamageDecision.new(HERO, 3, 4,
		[MmReference.to_object(9), MmReference.to_player(VILLAIN)] as Array[MmReference], [2] as Array[int])

	var glow: DecisionClicks = DecisionClicks.of(decision, _view())

	assert_eq(glow.objects, {9: DecisionClicks.Kind.TARGET})
	assert_eq(glow.players, {VILLAIN: DecisionClicks.Kind.TARGET})


func test_each_kind_has_its_own_color() -> void:
	assert_eq(DecisionClicks.color_of(DecisionClicks.Kind.TARGET), Color("#ff5a2a"))
	assert_eq(DecisionClicks.color_of(DecisionClicks.Kind.MANA), Color("#3aa0ff"))
	assert_ne(DecisionClicks.color_of(DecisionClicks.Kind.OTHER), DecisionClicks.color_of(DecisionClicks.Kind.MANA))


func test_at_priority_a_land_answers_with_its_mana_ability_and_cards_in_hand_do_not_answer() -> void:
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		PassAction.new(), PlayLandAction.new(7), CastSpellAction.new(8), ActivateAbilityAction.new(LAND_ID, 0),
	] as Array[MmAction])

	var clicks: DecisionClicks = DecisionClicks.of(decision, _view())

	assert_eq(clicks.clickable_ids(), [LAND_ID] as Array[int], "One click on a card in hand answers nothing (A371).")
	var options: Array[ClickOption] = clicks.options_of(LAND_ID)
	assert_eq(options.size(), 1)
	assert_eq(options[0].answer, 3, "The index of the land's ability among the actions.")
	assert_true(options[0].is_mana)
	assert_eq(options[0].text, "{T}: Add {G}.", "As the ability is printed (A333).")
	assert_eq(clicks.options_of(7).size(), 0)
	assert_eq(clicks.options_of(99).size(), 0, "Something that is not offered has no answer.")


func test_a_card_in_hand_offers_to_be_cast_or_played_apart_from_what_a_click_answers() -> void:
	var view: MmPlayerView = _view()
	view.hand = [_card(7, "Forest"), _card(8, "Hill Giant"), _card(9, "Zap")]
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		PassAction.new(), PlayLandAction.new(7), CastSpellAction.new(8), ActivateAbilityAction.new(LAND_ID, 0),
	] as Array[MmAction])

	var clicks: DecisionClicks = DecisionClicks.of(decision, view)

	assert_eq(clicks.hand_options_of(7).size(), 1)
	assert_eq(clicks.hand_options_of(7)[0].answer, 1, "The index of playing the Forest among the actions.")
	assert_eq(clicks.hand_options_of(7)[0].text, "Play Forest")
	assert_false(clicks.hand_options_of(7)[0].is_mana)
	assert_eq(clicks.hand_options_of(8)[0].answer, 2)
	assert_eq(clicks.hand_options_of(8)[0].text, "Cast Hill Giant")
	assert_eq(clicks.objects[7], DecisionClicks.Kind.OTHER)
	assert_eq(clicks.objects[8], DecisionClicks.Kind.OTHER)
	assert_eq(clicks.hand_options_of(9).size(), 0, "A card that cannot be cast offers nothing")
	assert_false(clicks.objects.has(9), "and does not glow.")
	assert_eq(clicks.hand_options_of(LAND_ID).size(), 0, "A permanent's ability is not played from the hand.")
	assert_eq(clicks.options_of(7).size(), 0)
	assert_eq(clicks.options_of(8).size(), 0)


func test_a_card_with_two_ways_to_be_played_offers_both_in_answer_order() -> void:
	var view: MmPlayerView = _view()
	view.hand = [_card(8, "Dryad Arbor")]
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		CastSpellAction.new(8), PassAction.new(), PlayLandAction.new(8),
	] as Array[MmAction])

	var options: Array[ClickOption] = DecisionClicks.of(decision, view).hand_options_of(8)

	assert_eq(options.size(), 2)
	assert_eq([options[0].answer, options[1].answer], [0, 2])
	assert_eq([options[0].text, options[1].text], ["Cast Dryad Arbor", "Play Dryad Arbor"])


func test_nothing_is_played_from_the_hand_outside_priority() -> void:
	var view: MmPlayerView = _view()
	view.hand = [_card(7, "Forest")]

	assert_eq(DecisionClicks.of(ChooseCardsToDiscardDecision.new(HERO, 1, [7] as Array[int]), view).hand_options_of(7).size(), 0)
	assert_eq(DecisionClicks.of(null, view).hand_options_of(7).size(), 0)


func test_a_held_cards_glow_is_its_color_made_lighter() -> void:
	var plain: Color = DecisionClicks.color_of(DecisionClicks.Kind.OTHER)
	var bright: Color = DecisionClicks.bright_color_of(DecisionClicks.Kind.OTHER)

	assert_gt(bright.get_luminance(), plain.get_luminance() + 0.1)
	assert_almost_eq(bright.r, lerpf(plain.r, 1.0, 0.55), 0.001)
	assert_gt(bright.g, bright.r, "Still green.")
	assert_ne(DecisionClicks.bright_color_of(DecisionClicks.Kind.MANA), bright)


func test_a_permanent_whose_ability_is_not_offered_has_no_answer_and_no_glow() -> void:
	# A tapped land, or a creature that came in this turn: the engine does not offer it.
	var decision: PriorityDecision = PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])

	var clicks: DecisionClicks = DecisionClicks.of(decision, _view())

	assert_eq(clicks.options_of(LAND_ID).size(), 0)
	assert_false(clicks.objects.has(LAND_ID))


func test_an_ability_of_something_that_is_not_a_permanent_glows_but_is_not_clicked_here() -> void:
	# An Emblem's ability, or one that works from a graveyard: clicked in its own zone's
	# window when that is built (13f, milestone 14), never on the battlefield.
	var view: MmPlayerView = _view()
	var emblem: MmObjectView = _permanent(30, [_ping()])
	view.command = [emblem]
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		PassAction.new(), ActivateAbilityAction.new(30, 0),
	] as Array[MmAction])

	var clicks: DecisionClicks = DecisionClicks.of(decision, view)

	assert_eq(clicks.options_of(30).size(), 0)
	assert_eq(clicks.clickable_ids().size(), 0)
	assert_eq(clicks.objects, {30: DecisionClicks.Kind.OTHER}, "It still glows, as something that can be done.")


func test_an_ability_that_is_not_a_mana_ability_glows_green_and_says_what_it_does() -> void:
	var view: MmPlayerView = _view()
	view.battlefield.append(_permanent(6, [_ping()]))
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		PassAction.new(), ActivateAbilityAction.new(6, 0),
	] as Array[MmAction])

	var clicks: DecisionClicks = DecisionClicks.of(decision, view)

	assert_eq(clicks.objects, {6: DecisionClicks.Kind.OTHER})
	assert_eq(clicks.options_of(6)[0].answer, 1)
	assert_false(clicks.options_of(6)[0].is_mana)
	assert_eq(clicks.options_of(6)[0].text, "{T}: This creature deals 1 damage to any target.")


func test_a_permanent_with_two_abilities_has_two_answers_in_order_and_glows_green_if_either_is_not_mana() -> void:
	var view: MmPlayerView = _view()
	view.battlefield.append(_permanent(6, [Scenario.tap_for_mana(MmMana.Type.RED, 1), _ping()]))
	view.battlefield.append(_permanent(7, [_ping(), Scenario.tap_for_mana(MmMana.Type.RED, 1)]))
	view.battlefield.append(_permanent(8, [Scenario.tap_for_mana(MmMana.Type.RED, 1), Scenario.tap_for_mana(MmMana.Type.BLUE, 1)]))
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		PassAction.new(), ActivateAbilityAction.new(6, 0), ActivateAbilityAction.new(6, 1),
		ActivateAbilityAction.new(7, 0), ActivateAbilityAction.new(7, 1),
		ActivateAbilityAction.new(8, 0), ActivateAbilityAction.new(8, 1),
	] as Array[MmAction])

	var clicks: DecisionClicks = DecisionClicks.of(decision, view)

	assert_eq(clicks.options_of(6).size(), 2)
	assert_eq(clicks.options_of(6)[0].answer, 1)
	assert_eq(clicks.options_of(6)[1].answer, 2)
	assert_eq(clicks.options_of(6)[1].text, "{T}: This creature deals 1 damage to any target.")
	assert_eq(clicks.objects[6], DecisionClicks.Kind.OTHER, "Mana first, then another ability (A306).")
	assert_eq(clicks.objects[7], DecisionClicks.Kind.OTHER, "The other ability first, then mana.")
	assert_eq(clicks.objects[8], DecisionClicks.Kind.MANA, "Blue only when mana is all it offers.")


func test_while_paying_each_source_answers_with_its_own_step() -> void:
	var view: MmPlayerView = _view()
	view.battlefield.append(_permanent(6, [Scenario.tap_for_mana(MmMana.Type.RED, 1)]))
	view.mana_pools[HERO] = [MmMana.new(MmMana.Type.RED, 1)]
	var decision: PayManaDecision = PayManaDecision.new(HERO, [
		PayWithManaAction.new(0), ActivateAbilityAction.new(LAND_ID, 0), ActivateAbilityAction.new(6, 0),
	] as Array[MmAction], 2, [] as Array[MmMana.Type])

	var clicks: DecisionClicks = DecisionClicks.of(decision, view)

	assert_eq(clicks.options_of(LAND_ID)[0].answer, 1)
	assert_eq(clicks.options_of(6)[0].answer, 2)
	assert_eq(clicks.pool_answers, {MmMana.Type.RED: 0})
	assert_eq(decision.validate(clicks.options_of(6)[0].answer), "")


func test_while_targeting_each_candidate_answers_with_its_index_and_nothing_else_does() -> void:
	var decision: ChooseTargetDecision = ChooseTargetDecision.new(HERO, 20, 0,
		[MmReference.to_player(HERO), MmReference.to_player(VILLAIN), MmReference.to_object(11)] as Array[MmReference])

	var clicks: DecisionClicks = DecisionClicks.of(decision, _view())

	assert_eq(clicks.player_answers, {HERO: 0, VILLAIN: 1})
	assert_eq(clicks.clickable_ids(), [11] as Array[int])
	assert_eq(clicks.options_of(11)[0].answer, 2)
	assert_eq(clicks.options_of(LAND_ID).size(), 0, "A permanent that is not a candidate.")
	assert_eq(decision.validate(clicks.options_of(11)[0].answer), "")


func test_a_kind_with_no_input_of_its_own_glows_but_gives_no_click_answers() -> void:
	var attackers: DecisionClicks = DecisionClicks.of(DeclareAttackersDecision.new(HERO, [3, 4] as Array[int]), _view())
	var discard: DecisionClicks = DecisionClicks.of(ChooseCardsToDiscardDecision.new(HERO, 1, [1, 2] as Array[int]), _view())
	var divide: DecisionClicks = DecisionClicks.of(DivideCombatDamageDecision.new(HERO, 3, 4,
		[MmReference.to_object(9), MmReference.to_player(VILLAIN)] as Array[MmReference], [2] as Array[int]), _view())

	assert_eq(attackers.objects.size(), 2)
	assert_eq(attackers.clickable_ids().size(), 0)
	assert_eq(discard.clickable_ids().size(), 0)
	assert_eq(divide.clickable_ids().size(), 0)
	assert_eq(divide.player_answers.size(), 0)


func _ping() -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.targets = [Scenario.any_target()]
	ability.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]
	return ability


## A creature on the battlefield with [param abilities].
func _permanent(id: int, abilities: Array[MmAbility]) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.name = "Pinger"
	seen.card_types = [MmCardTypes.CardType.CREATURE]
	seen.abilities = abilities
	return seen


func _card(id: int, card_name: String) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.name = card_name
	return seen


func _view() -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var land: MmObjectView = MmObjectView.new()
	land.id = LAND_ID
	land.abilities = [Scenario.tap_for_mana(MmMana.Type.GREEN, 1)]
	view.battlefield = [land]
	return view
