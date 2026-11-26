extends GutTest
## The Info Panel's prompt says, in one line, what the Hero is being asked.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID


func test_no_decision_has_no_prompt() -> void:
	var prompt: InfoPrompt = InfoPrompt.of(null, _view())

	assert_eq(prompt.text, "")
	assert_null(prompt.owed)
	assert_false(prompt.can_cancel)


func test_a_held_card_that_letting_go_would_play_says_so() -> void:
	assert_eq(InfoPrompt.release_text("Cast Hill Giant"), "Release to cast Hill Giant")
	assert_eq(InfoPrompt.release_text("Play Forest"), "Release to play Forest")


func test_priority_names_the_step_and_whose_turn_it_is() -> void:
	var view: MmPlayerView = _view()
	var decision: PriorityDecision = PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])
	view.step = MmTurn.Step.PRECOMBAT_MAIN
	view.active_player_id = HERO
	assert_eq(InfoPrompt.of(decision, view).text, "Your priority\nMain 1, your turn")

	view.step = MmTurn.Step.DECLARE_BLOCKERS
	view.active_player_id = VILLAIN
	assert_eq(InfoPrompt.of(decision, view).text, "Your priority\nBlockers, the Villain's turn")
	assert_false(InfoPrompt.of(decision, view).can_cancel)

	view.step = MmTurn.Step.NONE
	assert_eq(InfoPrompt.of(decision, view).text, "Your priority", "Before the first step there is none to name.")


func test_paying_names_what_is_paid_for_and_what_is_still_owed_and_can_be_canceled() -> void:
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Zap", 5)]
	var decision: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 2,
		[MmMana.Type.RED] as Array[MmMana.Type])

	var prompt: InfoPrompt = InfoPrompt.of(decision, view)

	assert_eq(prompt.text, "Pay for Zap")
	assert_eq(prompt.owed.generic, 2)
	assert_eq(prompt.owed.symbols, [MmMana.Type.RED] as Array[MmMana.Type])
	assert_true(prompt.can_cancel, "Paying is a step of a cast in progress (A255).")

	view.stack = []
	assert_eq(InfoPrompt.of(decision, view).text, "Pay for this", "Whatever the stack shows, it still prompts.")


func test_while_auto_tap_pays_it_says_what_for_and_what_is_owed_and_can_be_canceled() -> void:
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Zap", 5)]
	var paying: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 2,
		[MmMana.Type.RED] as Array[MmMana.Type])

	var prompt: InfoPrompt = InfoPrompt.of(null, view, paying)

	assert_eq(prompt.text, "Paying for Zap")
	assert_eq(prompt.owed.generic, 2)
	assert_eq(prompt.owed.symbols, [MmMana.Type.RED] as Array[MmMana.Type])
	assert_true(prompt.can_cancel, "Canceling is the one thing the Hero can do meanwhile.")
	assert_eq(InfoPrompt.of(null, view).text, "", "With nothing being paid, nothing is said.")


func test_targeting_names_the_spell_or_the_abilitys_source() -> void:
	var view: MmPlayerView = _view()
	var ability: MmObjectView = _object(21, "ability", MmGameObject.NO_CARD)
	ability.source_object_id = 1
	view.stack = [_object(20, "Zap", 5), ability]
	var candidates: Array[MmReference] = [MmReference.to_player(VILLAIN)]

	var spell: InfoPrompt = InfoPrompt.of(ChooseTargetDecision.new(HERO, 20, 0, candidates), view)
	var activated: InfoPrompt = InfoPrompt.of(ChooseTargetDecision.new(HERO, 21, 0, candidates), view)

	assert_eq(spell.text, "Choose a target for Zap")
	assert_true(spell.can_cancel)
	assert_null(spell.owed)
	assert_eq(activated.text, "Choose a target for Wand's ability")


func test_up_to_targets_say_how_many_and_for_what() -> void:
	var view: MmPlayerView = _view()
	var ability: MmObjectView = _object(21, "ability", MmGameObject.NO_CARD)
	ability.source_object_id = 1
	ability.ability = TriggeredAbility.new()
	view.stack = [_object(20, "Gird for Battle", 5), ability]
	var candidates: Array[MmReference] = [MmReference.to_object(3)]

	var spell: InfoPrompt = InfoPrompt.of(ChooseTargetsDecision.new(HERO, 20, 0, candidates, 2), view)
	var triggered: InfoPrompt = InfoPrompt.of(ChooseTargetsDecision.new(HERO, 21, 0, candidates, 2), view)
	var one: InfoPrompt = InfoPrompt.of(ChooseTargetsDecision.new(HERO, 20, 0, candidates, 1), view)

	assert_eq(spell.text, "Choose up to two targets for Gird for Battle")
	assert_true(spell.can_cancel, "A step of the cast.")
	assert_eq(triggered.text, "Choose up to two targets for Wand's ability")
	assert_false(triggered.can_cancel, "CR 603.3: a trigger on the stack can't be taken back.")
	assert_eq(one.text, "Choose up to one target for Gird for Battle")


func test_a_choice_made_on_resolution_says_what_to_choose_and_for_what_and_cannot_be_canceled() -> void:
	var view: MmPlayerView = _view()
	var ability: MmObjectView = _object(21, "ability", MmGameObject.NO_CARD)
	ability.source_object_id = 1
	view.stack = [ability]
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	var creature: HasCardTypeFilter = HasCardTypeFilter.new()
	var filter: AllOfFilter = AllOfFilter.new()
	filter.filters = [creature, yours]

	var prompt: InfoPrompt = InfoPrompt.of(ChooseObjectDecision.new(HERO, 21, 0, filter, [MmReference.to_object(1)] as Array[MmReference]), view)

	assert_eq(prompt.text, "Choose a creature you control for Wand's ability")
	assert_false(prompt.can_cancel, "It is chosen as the ability resolves: there is no cast to take back.")
	assert_null(prompt.owed)


func test_a_card_to_exile_for_a_cost_said_yes_to_is_asked_for_in_the_costs_words() -> void:
	# Kishla Trawlers's "you may exile a creature card from your graveyard" (engine ADR 0088).
	var view: MmPlayerView = _view()
	var ability: MmObjectView = _object(21, "ability", MmGameObject.NO_CARD)
	ability.source_object_id = 1
	ability.ability = TriggeredAbility.new()
	view.stack = [ability]
	var exiling: ChooseObjectDecision = ChooseObjectDecision.new(HERO, 21, ChooseObjectDecision.NO_CHOICE_INDEX,
		HasCardTypeFilter.new(), [MmReference.to_object(5)] as Array[MmReference])
	exiling.purpose = ChooseObjectDecision.Purpose.EXILE_FROM_GRAVEYARD

	var prompt: InfoPrompt = InfoPrompt.of(exiling, view)

	assert_eq(prompt.text, "Exile a creature card from your graveyard for Wand")
	assert_false(prompt.can_cancel, "It is paid as the ability resolves: there is no cast to take back.")


func test_a_card_to_exile_for_a_spells_additional_cost_can_be_canceled() -> void:
	# Makeshift Mauler's "As an additional cost to cast this spell, exile a creature card from
	# your graveyard" (engine ADR 0086): asked as the spell is cast, which can be taken back.
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Makeshift Mauler", 7)]
	var exiling: ChooseObjectDecision = ChooseObjectDecision.new(HERO, 20, ChooseObjectDecision.NO_CHOICE_INDEX,
		HasCardTypeFilter.new(), [MmReference.to_object(5)] as Array[MmReference])
	exiling.purpose = ChooseObjectDecision.Purpose.EXILE_FROM_GRAVEYARD

	var prompt: InfoPrompt = InfoPrompt.of(exiling, view)

	assert_eq(prompt.text, "Exile a creature card from your graveyard for Makeshift Mauler")
	assert_true(prompt.can_cancel)


func test_cards_to_exile_for_a_cost_of_three_count_down_as_they_are_picked() -> void:
	# Kessig Wolfrider's "Exile three cards from your graveyard", asked once for each card
	# (engine ADR 0088's second addendum), in the user's words.
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Kessig Wolfrider", 7)]
	var texts: Array[String] = []
	for exiled: int in 3:
		var exiling: ChooseObjectDecision = ChooseObjectDecision.new(HERO, 20, ChooseObjectDecision.NO_CHOICE_INDEX,
			null, [MmReference.to_object(5)] as Array[MmReference])
		exiling.purpose = ChooseObjectDecision.Purpose.EXILE_FROM_GRAVEYARD
		exiling.exile_count = 3
		exiling.exiled_before = exiled

		texts.append(InfoPrompt.of(exiling, view).text)

	assert_eq(texts, [
		"Exile three cards from your graveyard for Kessig Wolfrider",
		"Exile two more cards from your graveyard for Kessig Wolfrider",
		"Exile one more card from your graveyard for Kessig Wolfrider",
	] as Array[String])


func test_an_artifact_to_sacrifice_for_a_cost_said_yes_to_is_asked_for_in_the_costs_words() -> void:
	# Selfcraft Mechan's "you may sacrifice an artifact", paid as its trigger resolves.
	var view: MmPlayerView = _view()
	var ability: MmObjectView = _object(21, "ability", MmGameObject.NO_CARD)
	ability.source_object_id = 1
	ability.ability = TriggeredAbility.new()
	view.stack = [ability]
	var artifacts: HasCardTypeFilter = HasCardTypeFilter.new()
	artifacts.card_type = MmCardTypes.CardType.ARTIFACT
	var sacrificing: ChoosePermanentsDecision = ChoosePermanentsDecision.new(HERO, 21, 1, [1, 6] as Array[int], artifacts)
	sacrificing.purpose = ChoosePermanentsDecision.Purpose.SACRIFICE

	var prompt: InfoPrompt = InfoPrompt.of(sacrificing, view)

	assert_eq(prompt.text, "Sacrifice an artifact for Wand")
	assert_false(prompt.can_cancel, "It is paid as the ability resolves: there is no cast to take back.")


func test_a_creature_to_sacrifice_for_an_effect_names_its_source_and_cannot_be_canceled() -> void:
	# Agent of the Fates's "each opponent sacrifices a creature" (CR 701.21a), asked of the
	# Hero as the Villain's trigger resolves.
	var view: MmPlayerView = _view()
	var ability: MmObjectView = _object(21, "ability", MmGameObject.NO_CARD)
	ability.source_object_id = 1
	ability.ability = TriggeredAbility.new()
	view.stack = [ability]
	var sacrificing: ChoosePermanentsDecision = ChoosePermanentsDecision.new(HERO, 21, 1, [1, 6] as Array[int],
		HasCardTypeFilter.new())
	sacrificing.purpose = ChoosePermanentsDecision.Purpose.SACRIFICE
	sacrificing.is_for_effect = true

	var prompt: InfoPrompt = InfoPrompt.of(sacrificing, view)

	assert_eq(prompt.text, "Wand: sacrifice a creature")
	assert_false(prompt.can_cancel, "An effect resolving: there is nothing to take back.")


func test_a_creature_to_sacrifice_for_a_spells_effect_names_the_spell_and_cannot_be_canceled() -> void:
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Edict", 7)]
	var sacrificing: ChoosePermanentsDecision = ChoosePermanentsDecision.new(HERO, 20, 1, [1, 6] as Array[int],
		HasCardTypeFilter.new())
	sacrificing.purpose = ChoosePermanentsDecision.Purpose.SACRIFICE
	sacrificing.is_for_effect = true

	var prompt: InfoPrompt = InfoPrompt.of(sacrificing, view)

	assert_eq(prompt.text, "Edict: sacrifice a creature")
	assert_false(prompt.can_cancel, "A spell resolving, not one being cast.")


func test_the_legend_rule_asks_which_legend_to_keep_and_cannot_be_canceled() -> void:
	var prompt: InfoPrompt = InfoPrompt.of(ChooseLegendToKeepDecision.new(HERO, "Arahbo, the First Fang", [1, 2] as Array[int]), _view())

	assert_eq(prompt.text, "Choose which Arahbo, the First Fang to keep")
	assert_false(prompt.can_cancel, "A state-based action: there is no cast to take back.")


func test_choosing_a_mode_names_the_spell_and_can_be_canceled() -> void:
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Charm", 5)]
	var reach: Array[Array] = [[MmReference.to_object(1)], [MmReference.to_object(1)]]

	var prompt: InfoPrompt = InfoPrompt.of(ChooseModeDecision.new(HERO, 20, [0, 1] as Array[int], reach), view)

	assert_eq(prompt.text, "Choose one for Charm")
	assert_true(prompt.can_cancel, "The mode is a step of the cast (CR 601.2b).")


func test_a_triggers_mode_and_targets_name_its_source_and_cannot_be_canceled() -> void:
	var view: MmPlayerView = _view()
	var trigger: MmObjectView = _object(21, "Wand ability", MmGameObject.NO_CARD)
	trigger.source_object_id = 1
	trigger.ability = TriggeredAbility.new()
	var activated: MmObjectView = _object(22, "Wand ability", MmGameObject.NO_CARD)
	activated.source_object_id = 1
	activated.ability = ActivatedAbility.new()
	view.stack = [trigger, activated]
	var reach: Array[Array] = [[], []]
	var candidates: Array[MmReference] = [MmReference.to_player(VILLAIN)]

	var mode: InfoPrompt = InfoPrompt.of(ChooseModeDecision.new(HERO, 21, [0, 1] as Array[int], reach), view)
	var target: InfoPrompt = InfoPrompt.of(ChooseTargetDecision.new(HERO, 21, 0, candidates), view)
	var activated_target: InfoPrompt = InfoPrompt.of(ChooseTargetDecision.new(HERO, 22, 0, candidates), view)

	assert_eq(mode.text, "Choose one for Wand's ability")
	assert_false(mode.can_cancel, "CR 603.3c: there is no cast to take back, only a trigger going on the stack.")
	assert_eq(target.text, "Choose a target for Wand's ability")
	assert_false(target.can_cancel)
	assert_true(activated_target.can_cancel, "An activation is a cast to take back (CR 602.2).")


func test_choosing_a_creature_type_names_the_spell_and_cannot_be_canceled() -> void:
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Rally the Ranks", 5)]

	var prompt: InfoPrompt = InfoPrompt.of(ChooseCreatureTypeDecision.new(HERO, 20), view)

	assert_eq(prompt.text, "Choose a creature type for Rally the Ranks")
	assert_false(prompt.can_cancel, "It is chosen as the spell resolves, after the cast.")


func test_an_ability_whose_source_is_out_of_sight_keeps_its_own_name() -> void:
	var view: MmPlayerView = _view()
	var ability: MmObjectView = _object(21, "Boon ability", MmGameObject.NO_CARD)
	ability.source_object_id = 77
	view.stack = [ability]

	assert_eq(InfoPrompt.stack_name(view, 21), "Boon ability")
	assert_eq(InfoPrompt.stack_name(view, 99), "this")


func test_discarding_says_how_many_cards_and_how_many_are_chosen() -> void:
	var discard: InfoPrompt = InfoPrompt.of(ChooseCardsToDiscardDecision.new(HERO, 2, [1, 2, 3] as Array[int]), _view())

	assert_eq(discard.text, "Discard 2 cards (0 chosen)")
	assert_false(discard.can_cancel)
	assert_false(discard.offers_all_attack)


func test_what_the_opening_hand_overlay_answers_has_no_prompt_under_it() -> void:
	for decision: MmPendingDecision in [ChoosePlayOrDrawDecision.new(HERO), KeepOrMulliganDecision.new(HERO, 0, 0),
			ChooseCardsToBottomDecision.new(HERO, 1, [1, 2] as Array[int])]:
		assert_eq(InfoPrompt.of(decision, _view()).text, "", decision.describe())


func test_a_decision_with_no_input_says_what_the_engine_asks_and_is_an_error() -> void:
	var unknown: MmPendingDecision = MmPendingDecision.new(HERO)

	var prompt: InfoPrompt = InfoPrompt.of(unknown, _view())

	assert_eq(prompt.text, unknown.describe())
	assert_push_error("No input answers")


func test_the_combat_decisions_have_prompts_of_their_own() -> void:
	var view: MmPlayerView = _view()
	var attackers: InfoPrompt = InfoPrompt.of(DeclareAttackersDecision.new(HERO, [1] as Array[int]), view)
	var blockers: InfoPrompt = InfoPrompt.of(DeclareBlockersDecision.new(HERO, [1] as Array[int], [7] as Array[int],
		{1: [7]} as Dictionary[int, Array], {1: 1} as Dictionary[int, int]), view)
	var damage: InfoPrompt = InfoPrompt.of(DivideCombatDamageDecision.new(HERO, 1, 5,
		[MmReference.to_object(8), MmReference.to_object(9)] as Array[MmReference], [2, 3] as Array[int]), view)

	assert_eq(attackers.text, "Declare attackers")
	assert_true(attackers.offers_all_attack, "Only this one offers Declare All (A311).")
	assert_eq(blockers.text, "Declare blockers")
	assert_false(blockers.offers_all_attack)
	assert_eq(damage.text, "Divide 5 damage from Wand", "It names the creature whose damage it is (A325).")
	assert_false(damage.can_cancel)
	assert_false(damage.offers_all_attack)


## A view with a Wand (1) on the battlefield.
func _view() -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	view.battlefield = [_object(1, "Wand", 3)]
	return view


func test_priority_names_a_villain_who_has_a_name() -> void:
	var view: MmPlayerView = _view()
	var decision: PriorityDecision = PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])
	view.step = MmTurn.Step.DECLARE_BLOCKERS
	view.active_player_id = VILLAIN

	assert_eq(InfoPrompt.of(decision, view, null, PlayerNames.new("", "Mishra")).text, "Your priority\nBlockers, Mishra's turn")


func _object(id: int, object_name: String, card_id: int) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.name = object_name
	seen.card_id = card_id
	return seen


func test_creatures_to_tap_for_a_cost_are_asked_for_by_the_cost_and_can_be_canceled() -> void:
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Group Project", 5)]
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var untapped: NotFilter = NotFilter.new()
	untapped.filter = IsTappedFilter.new()
	var creature: HasCardTypeFilter = HasCardTypeFilter.new()
	creature.card_type = MmCardTypes.CardType.CREATURE
	var all: AllOfFilter = AllOfFilter.new()
	all.filters = [creature, untapped, mine]

	var prompt: InfoPrompt = InfoPrompt.of(ChoosePermanentsDecision.new(HERO, 20, 3, [3, 4, 6] as Array[int], all), view)

	assert_eq(prompt.text, "Tap three untapped creatures you control for Group Project")
	assert_true(prompt.can_cancel, "A step of the cast.")


func test_a_creature_to_tap_for_a_mana_ability_names_its_source_and_can_be_canceled() -> void:
	# Engine ADR 0105: Jaspera Sentinel's cost, with nothing on the stack.
	var view: MmPlayerView = _view()
	view.battlefield.append(_object(7, "Jaspera Sentinel", 8))
	var tapping: ChoosePermanentsDecision = ChoosePermanentsDecision.new(HERO, 7, 1, [1] as Array[int],
		Scenario.tap_creatures(1).filter)
	tapping.is_for_mana_ability = true

	var prompt: InfoPrompt = InfoPrompt.of(tapping, view)

	assert_eq(prompt.text, "Tap an untapped creature you control for Jaspera Sentinel")
	assert_true(prompt.can_cancel, "It is taken back as a cast is.")


func test_artifacts_and_or_creatures_to_tap_are_asked_for_in_the_costs_words() -> void:
	# Adaptive Gemguard's "Tap two untapped artifacts and/or creatures you control".
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Adaptive Gemguard", 5)]
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var untapped: NotFilter = NotFilter.new()
	untapped.filter = IsTappedFilter.new()
	var artifact: HasCardTypeFilter = HasCardTypeFilter.new()
	artifact.card_type = MmCardTypes.CardType.ARTIFACT
	var creature: HasCardTypeFilter = HasCardTypeFilter.new()
	creature.card_type = MmCardTypes.CardType.CREATURE
	var either: AnyOfFilter = AnyOfFilter.new()
	either.filters = [artifact, creature]
	var all: AllOfFilter = AllOfFilter.new()
	all.filters = [either, untapped, mine]

	var prompt: InfoPrompt = InfoPrompt.of(ChoosePermanentsDecision.new(HERO, 20, 2, [3, 4, 6] as Array[int], all), view)

	assert_eq(prompt.text, "Tap two untapped artifacts and/or creatures you control for Adaptive Gemguard")


func test_a_permanent_to_return_for_a_cost_is_asked_for_in_the_costs_words_and_can_be_canceled() -> void:
	# Fear of Isolation's "return a permanent you control to its owner's hand".
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Fear of Isolation", 5)]
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var pick: ChoosePermanentsDecision = ChoosePermanentsDecision.new(HERO, 20, 1, [3, 4, 6] as Array[int], mine)
	pick.purpose = ChoosePermanentsDecision.Purpose.RETURN_TO_HAND

	var prompt: InfoPrompt = InfoPrompt.of(pick, view)

	assert_eq(prompt.text, "Return a permanent you control to its owner's hand for Fear of Isolation")
	assert_true(prompt.can_cancel, "A step of the cast.")


func test_a_you_may_asks_with_its_words_and_offers_no() -> void:
	# Game ADR 0060: "[stack name]: [what yes does]?", with no "you may".
	var view: MmPlayerView = _view()
	var tap: TapEffect = Scenario.tap(Scenario.targeted(0))
	var snare: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.may(tap)],
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))])
	var ability: MmObjectView = _object(21, "Wand ability", MmGameObject.NO_CARD)
	ability.source_object_id = 1
	ability.ability = snare
	view.stack = [ability]

	var prompt: InfoPrompt = InfoPrompt.of(ChooseYesOrNoDecision.new(HERO, 21, tap), view)

	assert_eq(prompt.text, "Wand's ability: tap target creature?")
	assert_true(prompt.offers_no)
	assert_false(prompt.can_cancel, "The ability is resolving: nothing is being cast.")
	assert_false(InfoPrompt.of(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int]), view).offers_no)



func test_a_you_may_with_a_cost_asks_with_the_cost_in_its_words() -> void:
	# Engine ADR 0076: "Wand's ability: remove a +1/+1 counter from this creature?"
	var view: MmPlayerView = _view()
	view.battlefield[0].card_types = [MmCardTypes.CardType.CREATURE]
	var spread: PutCountersEffect = Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, Scenario.each_creature())
	var paying: MayPayEffect = Scenario.may_pay(Scenario.remove_counters(), spread)
	var ability: MmObjectView = _object(21, "Wand ability", MmGameObject.NO_CARD)
	ability.source_object_id = 1
	ability.ability = Scenario.triggered(Scenario.at_step(MmTurn.Step.BEGINNING_OF_COMBAT, MmTrigger.Whose.YOU), [paying])
	view.stack = [ability]
	var asked: ChooseYesOrNoDecision = ChooseYesOrNoDecision.new(HERO, 21, spread)
	asked.resolution_cost = paying.cost

	var prompt: InfoPrompt = InfoPrompt.of(asked, view)

	assert_eq(prompt.text, "Wand's ability: remove a +1/+1 counter from this creature?")
	assert_true(prompt.offers_no)
	assert_false(prompt.can_cancel)


func test_x_chosen_as_a_spell_is_cast_asks_with_the_stepper_and_can_be_canceled() -> void:
	# Engine ADR 0076: "Choose {X} for Bounty", the stepper and Cancel, no No.
	var view: MmPlayerView = _view()
	view.stack = [_object(20, "Bounty", 5)]

	var prompt: InfoPrompt = InfoPrompt.of(ChooseXDecision.new(HERO, 20, 4), view)

	assert_eq(prompt.text, "Choose {X} for Bounty")
	assert_true(prompt.chooses_x)
	assert_eq(prompt.most_x, 4)
	assert_false(prompt.offers_no)
	assert_true(prompt.can_cancel, "A step of the cast.")


func test_a_ward_cost_asks_to_pay_ward_for_the_warded_permanent_with_its_cost_after() -> void:
	# ADR 0062: "Pay ward for Wand: {2}", No in the panel and Pay on the Pass Button.
	var view: MmPlayerView = _ward_on_top()
	var countering: CounterEffect = (view.stack.back().ability as WardAbility).effects[0] as CounterEffect

	var prompt: InfoPrompt = InfoPrompt.of(ChooseYesOrNoDecision.new(HERO, 21, countering, Scenario.mana_cost(2)), view)

	assert_eq(prompt.text, "Pay ward for Wand:")
	assert_eq(prompt.owed.generic, 2)
	assert_true(prompt.is_owed_inline, "The cost follows the words on their line.")
	assert_true(prompt.offers_no)
	assert_false(prompt.can_cancel)


func test_paying_a_ward_cost_reads_the_same_line_with_what_is_left_and_cannot_be_canceled() -> void:
	var view: MmPlayerView = _ward_on_top()
	var paying: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 1,
		[] as Array[MmMana.Type])

	var by_hand: InfoPrompt = InfoPrompt.of(paying, view)
	var by_auto_tap: InfoPrompt = InfoPrompt.of(null, view, paying)

	for prompt: InfoPrompt in [by_hand, by_auto_tap]:
		assert_eq(prompt.text, "Pay ward for Wand:")
		assert_eq(prompt.owed.generic, 1, "What is left to pay.")
		assert_true(prompt.is_owed_inline)
		assert_false(prompt.can_cancel, "Nothing is being cast: the ward trigger is resolving.")


func test_choosing_x_asks_to_pay_x_for_the_source_and_offers_no() -> void:
	# Game ADR 0063: "Pay {X} for Wand?", a stepper and No in the panel, Pay on the Pass Button.
	var view: MmPlayerView = _x_trigger_on_top()
	var paying_x: MayPayXEffect = (view.stack.back().ability as TriggeredAbility).effects[0] as MayPayXEffect

	var prompt: InfoPrompt = InfoPrompt.of(ChooseXToPayDecision.new(HERO, 21, paying_x.effect, 3), view)

	assert_eq(prompt.text, "Pay {X} for Wand?")
	assert_true(prompt.chooses_x)
	assert_eq(prompt.most_x, 3)
	assert_true(prompt.offers_no)
	assert_false(prompt.can_cancel, "The ability is resolving: nothing is being cast.")
	assert_false(InfoPrompt.of(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int]), view).chooses_x)


func test_paying_x_on_resolution_says_what_for_with_what_is_left_after_it_and_cannot_be_canceled() -> void:
	var view: MmPlayerView = _x_trigger_on_top()
	var paying: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 2,
		[] as Array[MmMana.Type])

	var by_hand: InfoPrompt = InfoPrompt.of(paying, view)
	var by_auto_tap: InfoPrompt = InfoPrompt.of(null, view, paying)

	for prompt: InfoPrompt in [by_hand, by_auto_tap]:
		assert_eq(prompt.text, "Pay for Wand:")
		assert_eq(prompt.owed.generic, 2, "What is left to pay.")
		assert_true(prompt.is_owed_inline)
		assert_false(prompt.can_cancel, "Nothing is being cast: the trigger is resolving.")


## The Hero's "you may pay {X}" trigger from the Wand on top of the stack.
func _x_trigger_on_top() -> MmPlayerView:
	var view: MmPlayerView = _view()
	var trigger: MmObjectView = _object(21, "Wand ability", MmGameObject.NO_CARD)
	trigger.source_object_id = 1
	trigger.ability = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.pay_x(Scenario.gain_x_life())])
	view.stack = [trigger]
	return view


## The Villain's ward trigger from the Wand on top of the stack, above the Hero's Zap.
func _ward_on_top() -> MmPlayerView:
	var view: MmPlayerView = _view()
	var ward: MmObjectView = _object(21, "Wand ability", MmGameObject.NO_CARD)
	ward.source_object_id = 1
	ward.ability = Scenario.ward()
	ward.triggering_object_id = 20
	view.stack = [_object(20, "Zap", 5), ward]
	return view


func test_a_surveil_asks_in_the_words_the_user_approved() -> void:
	var view: MmPlayerView = _view()
	var one: SurveilDecision = SurveilDecision.new(HERO, 21, [31] as Array[int])
	var two: SurveilDecision = SurveilDecision.new(HERO, 21, [31, 32] as Array[int])

	assert_eq(InfoPrompt.of(one, view).text, "Surveil: graveyard any of these.", "Game ADR 0069.")
	assert_eq(InfoPrompt.of(two, view).text, "Surveil: graveyard any of these, and order the rest. The leftmost will be on top.")
	assert_false(InfoPrompt.of(two, view).can_cancel, "A resolving trigger cannot be canceled.")


func test_a_scry_asks_in_the_words_the_user_approved() -> void:
	var view: MmPlayerView = _view()
	var one: ScryDecision = ScryDecision.new(HERO, 21, [31] as Array[int])
	var two: ScryDecision = ScryDecision.new(HERO, 21, [31, 32] as Array[int])

	assert_eq(InfoPrompt.of(one, view).text, "Scry: put any of these on the bottom.", "Game ADR 0069's addendum.")
	assert_eq(InfoPrompt.of(two, view).text, "Scry: put any of these on the bottom, and order the rest. The leftmost will be on top.")
	assert_false(InfoPrompt.of(two, view).can_cancel, "A resolving trigger cannot be canceled.")
