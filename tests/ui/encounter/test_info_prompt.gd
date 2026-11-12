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


func test_an_ability_whose_source_is_out_of_sight_keeps_its_own_name() -> void:
	var view: MmPlayerView = _view()
	var ability: MmObjectView = _object(21, "Boon ability", MmGameObject.NO_CARD)
	ability.source_object_id = 77
	view.stack = [ability]

	assert_eq(InfoPrompt.stack_name(view, 21), "Boon ability")
	assert_eq(InfoPrompt.stack_name(view, 99), "this")


func test_a_kind_the_panel_still_answers_is_prompted_with_its_forms_title() -> void:
	var discard: InfoPrompt = InfoPrompt.of(ChooseCardsToDiscardDecision.new(HERO, 2, [1] as Array[int]), _view())
	var keep: InfoPrompt = InfoPrompt.of(KeepOrMulliganDecision.new(HERO, 0, 0), _view())

	assert_eq(discard.text, "Discard 2")
	assert_false(discard.can_cancel)
	assert_false(discard.offers_all_attack)
	assert_eq(keep.text, "Keep this hand, or mulligan? (0 taken)")


func test_the_combat_decisions_have_prompts_of_their_own() -> void:
	var view: MmPlayerView = _view()
	var attackers: InfoPrompt = InfoPrompt.of(DeclareAttackersDecision.new(HERO, [1] as Array[int]), view)
	var blockers: InfoPrompt = InfoPrompt.of(DeclareBlockersDecision.new(HERO, [1] as Array[int], [7] as Array[int],
		{1: [7]} as Dictionary[int, Array], {1: 1} as Dictionary[int, int]), view)
	var damage: InfoPrompt = InfoPrompt.of(DivideCombatDamageDecision.new(HERO, 1, 5,
		[MmReference.to_object(8), MmReference.to_object(9)] as Array[MmReference], [2, 3] as Array[int]), view)

	assert_eq(attackers.text, "Declare attackers")
	assert_true(attackers.offers_all_attack, "Only this one offers All attack (A311).")
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


func _object(id: int, object_name: String, card_id: int) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.name = object_name
	seen.card_id = card_id
	return seen
