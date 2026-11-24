extends GutTest
## "You may pay {1}" on the Encounter Screen (ADR 0076's addendum), as Myrsmith asks it. The
## Hero's Smith (a 2/1 with "Whenever you cast an artifact spell, you may pay {1}. If you do,
## you gain 3 life") triggers as they cast Trinket, an artifact costing {0}. As the trigger
## resolves the Info Panel reads "Pay for Smith's ability:" with {1} after it, as any cost
## that is not ward's does (ADR 0062), and the Trinket, which it would not counter, carries
## no Stack Mark. The Hero's Mana Bird taps for {W}{W}{W}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const CombatAgent := preload("res://tests/ui/encounter/support/combat_agent.gd")
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_the_info_panel_asks_to_pay_for_the_ability_with_the_cost_after_it() -> void:
	_open_asked()
	var panel: InfoPanel = _screen.info_panel()

	assert_eq(panel.prompt_text(), "Pay for Smith's ability:")
	assert_eq(panel.owed_pip_names(), ["1"] as Array[String])
	assert_eq(panel.affirmative_text(), "Pay {1}")
	assert_eq(panel.no_button().text, "No")


func test_the_spell_that_triggered_it_carries_no_stack_mark() -> void:
	_open_asked()

	var entry: StackEntry = _screen.stack_entry_of(_trinket_id())
	assert_not_null(entry)
	assert_null(BorderEffects.mark_color(entry), "Only ward's question marks what it would counter.")


func test_paying_gains_the_life() -> void:
	_open_asked()
	var life: int = _presenter.snapshot().view.life_totals[MmEncounterSetup.HERO_PLAYER_ID]

	_screen.info_panel().affirmative_button().pressed.emit()
	_presenter.wait_until_idle()
	assert_eq(_presenter.answer(_bird_answer()), "")
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().view.life_totals[MmEncounterSetup.HERO_PLAYER_ID], life + 3)


# --- Helpers ---------------------------------------------------------------------------


func _trinket_id() -> int:
	for item: MmObjectView in _presenter.snapshot().view.stack:
		if item.name == "Trinket":
			return item.id
	return -1


## The answer that taps the Mana Bird for the cost.
func _bird_answer() -> int:
	var paying: PayManaDecision = _presenter.snapshot().decision as PayManaDecision
	for index: int in paying.actions.size():
		if paying.actions[index] is ActivateAbilityAction:
			return index
	return -1


## A 2/1 costing {0}: "Whenever you cast an artifact spell, you may pay {1}. If you do, you
## gain 3 life."
func _smith() -> MmCardDefinition:
	var paying: MayPayEffect = Scenario.may_pay_mana(Scenario.mana_cost(1), Scenario.gain_life(3, Scenario.you()))
	var trigger: SpellCastTrigger = Scenario.casts(Scenario.of_type(MmCardTypes.CardType.ARTIFACT), MmTrigger.Whose.YOU)
	return Scenario.creature("Smith", 2, 1, [Scenario.triggered(trigger, [paying])])


## Opens the screen, casts the Hero's Mana Bird and Smith on Game Turn 1, then in their main
## phase of Game Turn 3 casts Trinket and passes until the cost is asked.
func _open_asked() -> void:
	var hero_deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.mana_bird(), _smith(), Scenario.artifact("Trinket", []),
		Scenario.basic_land("Plains")])
	var villain_deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.basic_land("Forest")])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(hero_deck, villain_deck,
			MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		var hero_hand: Array = Scenario.names(engine, engine.hero().hand)
		if hero_hand.has("Mana Bird") and hero_hand.has("Smith") and hero_hand.has("Trinket"):
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(chosen, CombatAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	_answer_pregame()
	_play_to(1)
	_cast("Mana Bird")
	_cast("Smith")
	_play_to(3)
	_cast("Trinket")
	for attempt: int in 20:
		var asked: ChooseYesOrNoDecision = _presenter.snapshot().decision as ChooseYesOrNoDecision
		if asked != null and asked.cost != null:
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("The cost was never asked.")


func _answer_pregame() -> void:
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()


## Passes, declaring no attackers or blockers, until the Hero has priority with an empty
## stack in the main phase of Game Turn [param game_turn].
func _play_to(game_turn: int) -> void:
	for attempt: int in 200:
		var snapshot: EncounterSnapshot = _presenter.snapshot()
		var decision: MmPendingDecision = snapshot.decision
		if decision is PriorityDecision and snapshot.view.game_turn == game_turn \
				and snapshot.view.step == MmTurn.Step.PRECOMBAT_MAIN and snapshot.view.stack.is_empty():
			return
		if decision is DeclareAttackersDecision or decision is DeclareBlockersDecision:
			assert_eq(_presenter.answer([]), "")
		else:
			_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("Game Turn %d's main phase was never reached." % game_turn)


## Casts the Hero's card named [param card_name] from their hand, and lets it resolve.
func _cast(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("%s could not be cast." % card_name)
