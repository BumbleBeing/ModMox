extends GutTest
## The Info Panel's prompt says, in one line, what the Hero is being asked.

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
