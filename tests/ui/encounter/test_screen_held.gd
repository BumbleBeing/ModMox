extends GutTest
## An Emblem and a Potion are used from their windows on the Encounter Screen (ADR 0032):
## an entry that can be used glows green and takes a click, its window closes at that click
## and comes back if the activation is taken back, a Spent ability is gray, and the panel's
## buttons say what could be done.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const GREEN: Color = Color("#7be36a")

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func test_an_emblem_that_can_be_activated_glows_green_and_the_others_take_no_click() -> void:
	_open()
	_play_land()

	var boon: ZoneEntry = _screen.held_entry(_emblem("Electromancer's Boon"))
	assert_true(boon.is_usable(), "A Mountain pays {R}.")
	assert_eq(boon.border_color(), GREEN)
	assert_false(_screen.held_entry(_emblem("Diviner's Boon")).is_usable(), "One land does not pay {2}{U}.")
	assert_false(_screen.held_entry(_emblem("Winds")).is_usable(), "A static ability is not activated.")
	assert_eq(_screen.held_entry(_emblem("Winds")).border_color(), PlayerPanel.GOLD)
	assert_true(_screen.player_panel(HERO).is_glowing(_screen.player_panel(HERO).emblems_button()))


func test_the_villains_emblems_never_take_a_click() -> void:
	_open()
	_play_land()

	var theirs: MmObjectView = _presenter.snapshot().emblems_of(VILLAIN)[0]

	assert_eq(theirs.name, "Electromancer's Boon")
	assert_false(_screen.held_entry(theirs.id).is_usable())
	assert_false(_screen.player_panel(VILLAIN).is_glowing(_screen.player_panel(VILLAIN).emblems_button()))


func test_an_emblem_without_art_shows_the_gray_square_and_its_text() -> void:
	_open()

	var boon: ZoneEntry = _screen.held_entry(_emblem("Electromancer's Boon"))

	assert_eq((boon.picture() as ColorRect).color, ZoneEntry.NO_ART_COLOR)
	assert_eq(boon.line_texts(), ["{R}: This emblem deals 3 damage to any target. Activate only once each game."] as Array[String])
	assert_eq(_screen.emblems_window(HERO).title_text(), "Hero's Emblems (3)")


func test_clicking_an_emblem_closes_its_window_and_canceling_brings_it_back() -> void:
	_open()
	_play_land()
	var window: ZoneWindow = _screen.emblems_window(HERO)
	window.open()

	_click(_emblem("Electromancer's Boon"))

	assert_false(window.is_open(), "So the board is clear to choose a target on (A528).")
	assert_true(_presenter.snapshot().decision is ChooseTargetDecision)
	_presenter.cancel_cast()
	_presenter.wait_until_idle()
	assert_true(window.is_open(), "Taken back, so it is where it was.")
	assert_true(_screen.held_entry(_emblem("Electromancer's Boon")).is_usable())


func test_an_emblem_ability_that_resolves_is_spent_and_its_window_stays_closed() -> void:
	_open()
	_play_land()
	var window: ZoneWindow = _screen.emblems_window(HERO)
	window.open()

	_click(_emblem("Electromancer's Boon"))
	_target_player(VILLAIN)

	assert_eq(_presenter.snapshot().view.life_totals[VILLAIN], 17)
	assert_false(window.is_open())
	var boon: ZoneEntry = _screen.held_entry(_emblem("Electromancer's Boon"))
	assert_false(boon.is_usable())
	assert_true(boon.is_line_spent(0))
	assert_true(boon.line_texts()[0].ends_with("(used)"))
	assert_eq(boon.border_color(), PlayerPanel.GOLD)
	assert_false(_screen.player_panel(HERO).is_glowing(_screen.player_panel(HERO).emblems_button()))
	assert_eq((_screen.player_panel(HERO).emblems_button().get_theme_stylebox("normal") as StyleBoxFlat).border_color, PlayerPanel.GOLD,
		"The other two Emblems are not used up.")


func test_auto_tap_pays_an_emblems_cost_as_it_pays_a_permanents() -> void:
	_open()
	_play_land()
	_presenter.set_auto_tapping(true)

	_click(_emblem("Electromancer's Boon"))
	var asked: MmPendingDecision = _presenter.snapshot().decision
	_target_player(VILLAIN)

	assert_true(asked is ChooseTargetDecision)
	assert_eq(_presenter.snapshot().view.life_totals[VILLAIN], 17, "The Hero was never asked to pay.")
	assert_true(_presenter.snapshot().view.battlefield[0].is_tapped, "The Mountain paid for it.")


func test_undoing_an_emblem_ability_off_the_stack_reopens_its_window() -> void:
	_open()
	_play_land()
	_presenter.is_hold_key_down = true
	var window: ZoneWindow = _screen.emblems_window(HERO)
	window.open()
	_click(_emblem("Electromancer's Boon"))
	_target_player(VILLAIN)
	assert_eq(_presenter.snapshot().view.stack.size(), 1)
	assert_false(window.is_open())

	while _presenter.snapshot().can_undo and not _presenter.snapshot().view.stack.is_empty():
		_presenter.undo()
		_presenter.wait_until_idle()

	assert_true(window.is_open())
	assert_false(_screen.held_entry(_emblem("Electromancer's Boon")).is_line_spent(0))


func test_a_window_that_was_closed_is_not_opened_by_using_nothing() -> void:
	_open()
	_play_land()

	_cast("Bear")

	assert_false(_screen.emblems_window(HERO).is_open())
	assert_false(_screen.potions_window().is_open())


func test_an_emblem_with_several_usable_abilities_opens_the_option_menu_and_closes_on_a_choice() -> void:
	var life: ActivatedAbility = Scenario.regenerate_ability(Scenario.mana_cost(0))
	life.effects = [Scenario.gain_life(1, Scenario.you())]
	var more: ActivatedAbility = Scenario.regenerate_ability(Scenario.mana_cost(0))
	more.effects = [Scenario.gain_life(2, Scenario.you())]
	_open([Scenario.emblem("Font", [life, more])])
	var window: ZoneWindow = _screen.emblems_window(HERO)
	window.open()

	_screen.held_entry(_emblem("Font")).click_catcher().clicked.emit()

	assert_true(_screen.option_menu().is_open(), "As a permanent with several abilities does.")
	assert_true(window.is_open(), "Nothing has been started yet.")
	_screen.option_menu().chosen.emit(_presenter.snapshot().decision.actions.size() - 1)
	_presenter.wait_until_idle()
	assert_false(window.is_open())
	assert_eq(_presenter.snapshot().view.life_totals[HERO], 22, "The second ability.")


func test_a_menu_dismissed_for_an_emblem_does_not_claim_a_permanents_choice_later() -> void:
	var life: ActivatedAbility = Scenario.regenerate_ability(Scenario.mana_cost(0))
	life.effects = [Scenario.gain_life(1, Scenario.you())]
	var more: ActivatedAbility = Scenario.regenerate_ability(Scenario.mana_cost(0))
	more.effects = [Scenario.gain_life(2, Scenario.you())]
	_open([Scenario.emblem("Font", [life, more])])
	_play_land()
	var window: ZoneWindow = _screen.emblems_window(HERO)
	window.open()
	_screen.held_entry(_emblem("Font")).click_catcher().clicked.emit()
	_screen.option_menu().close()
	assert_true(window.is_open(), "Clicked away: nothing was used.")
	var tap: int = -1
	var decision: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	for index: int in decision.actions.size():
		if DecisionClicks.object_of(decision.actions[index]) == _permanent("Mountain"):
			tap = index

	_screen.option_menu().chosen.emit(tap)
	_presenter.wait_until_idle()

	assert_true(window.is_open(), "Tapping the Mountain is not using the Emblem.")
	assert_true(_presenter.snapshot().view.battlefield[0].is_tapped)


func test_the_potions_button_opens_a_window_that_shows_each_potion() -> void:
	_open()
	var panel: PlayerPanel = _screen.player_panel(HERO)
	assert_eq(panel.potions_button().text, "⚗  Potions (1)")
	assert_false(_screen.potions_window().is_open())

	panel.potions_button().pressed.emit()

	assert_true(_screen.potions_window().is_open())
	assert_eq(_screen.potions_window().title_text(), "Hero's Potions (1)")
	var entry: ZoneEntry = _screen.held_entry(_potion())
	assert_eq(entry.name_text(), "Big Gulp")
	assert_eq(entry.line_texts(), ["Potion · Common", "Target creature gets +2/+2 until end of turn."] as Array[String])
	assert_true(entry.picture() is PotionArt)
	assert_eq((entry.picture() as PotionArt).key(), "big_gulp")
	assert_true((entry.picture() as PotionArt).is_small())
	panel.potions_button().pressed.emit()
	assert_false(_screen.potions_window().is_open())


func test_a_potion_is_usable_only_with_a_creature_to_target() -> void:
	_open()
	_play_land()
	var panel: PlayerPanel = _screen.player_panel(HERO)
	assert_false(_screen.held_entry(_potion()).is_usable())
	assert_false(panel.is_glowing(panel.potions_button()))

	_cast("Bear")

	assert_true(_screen.held_entry(_potion()).is_usable())
	assert_eq(_screen.held_entry(_potion()).border_color(), GREEN)
	assert_true(panel.is_glowing(panel.potions_button()))


func test_using_a_potion_closes_its_window_uses_it_up_and_grays_the_button() -> void:
	_open()
	_play_land()
	_cast("Bear")
	var panel: PlayerPanel = _screen.player_panel(HERO)
	_screen.potions_window().open()

	_click(_potion())
	assert_false(_screen.potions_window().is_open())
	_target_object(_permanent("Bear"))

	assert_eq(_presenter.snapshot().look_of(_permanent("Bear")).power, 4)
	assert_eq(_presenter.snapshot().potions_of(HERO).size(), 0)
	assert_eq(panel.potions_button().text, "⚗  Potions (0)")
	assert_true(panel.potions_button().disabled)
	assert_false(_screen.potions_window().is_open())
	assert_eq(_screen.potions_window().title_text(), "Hero's Potions (0)")


func test_canceling_a_potion_brings_its_window_and_the_potion_back() -> void:
	_open()
	_play_land()
	_cast("Bear")
	_screen.potions_window().open()
	_click(_potion())

	_presenter.cancel_cast()
	_presenter.wait_until_idle()

	assert_true(_screen.potions_window().is_open())
	assert_eq(_presenter.snapshot().potions_of(HERO).size(), 1)
	assert_true(_screen.held_entry(_potion()).is_usable())


func test_a_potions_ability_on_the_stack_shows_the_potions_art() -> void:
	_open()
	_play_land()
	_cast("Bear")
	_presenter.is_hold_key_down = true

	_click(_potion())
	_target_object(_permanent("Bear"))

	var stacked: MmObjectView = _presenter.snapshot().view.stack[0]
	var entry: StackEntry = _screen.stack_entry_of(stacked.id)
	assert_eq(_presenter.snapshot().potions_of(HERO).size(), 0, "Used up as it went on the stack.")
	assert_not_null(entry.potion_art())
	assert_eq(entry.potion_art().key(), "big_gulp")
	assert_true(entry.potion_art().is_small())
	assert_eq(entry.name_text(), "Target creature gets +2/+2 until end of turn.")


func test_a_potions_ability_on_the_stack_is_read_in_the_inspector_as_its_potion() -> void:
	_open()
	_play_land()
	_cast("Bear")
	_presenter.is_hold_key_down = true
	_click(_potion())
	_target_object(_permanent("Bear"))
	await wait_process_frames(2)
	var entry: StackEntry = _screen.stack_entry_of(_presenter.snapshot().view.stack[0].id)

	_screen.right_click_at(entry.get_global_rect().get_center() - _screen.global_position)

	var readout: PotionReadout = _screen.inspector().potion_readout()
	assert_eq(readout.name_text(), "Big Gulp", "Not \"Big Gulp ability\": the Potion it came from.")
	assert_eq(readout.rules_text(), "Target creature gets +2/+2 until end of turn.")
	assert_eq(readout.glow_color(), Inspector.glow_of(MmCardDefinition.Rarity.COMMON))


func test_a_potion_and_an_emblem_are_read_in_the_inspector_from_their_windows() -> void:
	_open()
	_screen.potions_window().open()
	_screen.emblems_window(HERO).open()
	await wait_process_frames(2)
	var inspector: Inspector = _screen.inspector()

	_screen.right_click_at(_screen.held_entry(_potion()).get_global_rect().get_center() - _screen.global_position)

	assert_eq(inspector.potion_readout().name_text(), "Big Gulp")
	assert_eq(inspector.potion_readout().type_line_text(), "Potion")
	assert_eq(inspector.potion_readout().glow_color(), Inspector.glow_of(MmCardDefinition.Rarity.COMMON))
	_screen.right_click_at(_screen.held_entry(_emblem("Diviner's Boon")).get_global_rect().get_center() - _screen.global_position)
	assert_null(inspector.potion_readout())
	assert_eq(inspector.emblem_face().name_text(), "Diviner's Boon")
	assert_false(inspector.emblem_face().has_art())
	assert_eq(inspector.emblem_face().credit_text(), "")


# --- helpers ---------------------------------------------------------------------------


## The Hero's deck cycles Mountains and free 2/2 Bears and holds three Emblems (a static
## one and both Boons) and a Big Gulp; the Villain holds Electromancer's Boon. Stops in the
## Hero's first main phase, with a seed that deals a Mountain and a Bear. With
## [param hero_emblems], the Hero holds those Emblems instead.
func _open(hero_emblems: Array[MmCardDefinition] = []) -> void:
	var cards: Array[MmCardDefinition] = Scenario.cycled([Scenario.mana_land("Mountain", MmMana.Type.RED, 1), Scenario.creature("Bear", 2, 2)])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 40):
		chosen = Scenario.setup_with(cards, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var held: Array[String] = Scenario.names(MmEngine.start(chosen), MmEngine.start(chosen).hero().hand)
		if held.has("Bear") and held.has("Mountain"):
			break
	chosen.hero.emblems = [Scenario.emblem("Winds", [FlyingAbility.new()] as Array[MmAbility]),
		load("res://content/emblems/diviners_boon.tres"), load("res://content/emblems/electromancers_boon.tres")] as Array[MmCardDefinition]
	if not hero_emblems.is_empty():
		chosen.hero.emblems = hero_emblems
	chosen.hero.potions = [load("res://content/potions/big_gulp.tres")] as Array[MmCardDefinition]
	chosen.villain.emblems = [load("res://content/emblems/electromancers_boon.tres")] as Array[MmCardDefinition]
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(chosen, DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	for attempt: int in 10:
		if _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN:
			break
		_presenter.pass_priority()
		_presenter.wait_until_idle()


func _play_land() -> void:
	_do(func(action: MmAction) -> bool: return action is PlayLandAction)


func _cast(card_name: String) -> void:
	var view: MmPlayerView = _presenter.snapshot().view
	_do(func(action: MmAction) -> bool:
		return action is CastSpellAction and EncounterSnapshot.name_in(view, (action as CastSpellAction).object_id) == card_name)


## Answers the Hero's priority with the first action [param matches] accepts.
func _do(matches: Callable) -> void:
	var decision: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	for index: int in decision.actions.size():
		if matches.call(decision.actions[index]):
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("Nothing to do that with.")


## A left-click on the entry of the Emblem or Potion [param object_id].
func _click(object_id: int) -> void:
	_screen.held_entry(object_id).click_catcher().clicked.emit()
	_presenter.wait_until_idle()


func _target_player(player_id: int) -> void:
	_target(func(candidate: MmReference) -> bool: return candidate.is_player() and candidate.id == player_id)


func _target_object(object_id: int) -> void:
	_target(func(candidate: MmReference) -> bool: return candidate.is_object() and candidate.id == object_id)


func _target(matches: Callable) -> void:
	var decision: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	for index: int in decision.candidates.size():
		if matches.call(decision.candidates[index]):
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			# Auto-tap is off unless a test turns it on, so the Hero pays by hand; with it
			# on, it pays a tap at a time, each on a poll.
			for payment: int in 10:
				if _presenter.is_paying_for_hero():
					_presenter.poll()
				elif _presenter.snapshot().decision is PayManaDecision:
					_presenter.answer(0)
				else:
					break
				_presenter.wait_until_idle()
			return
	fail_test("No such target.")


func _emblem(emblem_name: String) -> int:
	for emblem: MmObjectView in _presenter.snapshot().emblems_of(HERO):
		if emblem.name == emblem_name:
			return emblem.id
	return -1


func _potion() -> int:
	return _presenter.snapshot().potions_of(HERO)[0].id


func _permanent(card_name: String) -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			return permanent.id
	return -1
