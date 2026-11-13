extends GutTest
## What a snapshot carries for the Inspector (13h, ADR 0033): each card's Original and
## Rarity, and each permanent's State List.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID


func test_a_card_in_hand_has_its_card_definition_as_its_original() -> void:
	var snapshot: EncounterSnapshot = _started(_bear_setup()).snapshot()
	var bear: MmObjectView = _in_hand(snapshot, "Bear")

	assert_eq(snapshot.original_of(bear.id).name, "Bear")
	assert_eq(snapshot.original_of(bear.id).power, 2)
	assert_eq(snapshot.original_of(bear.id).art_key, snapshot.look_of(bear.id).art_key)


func test_the_original_has_none_of_a_run_cards_modifications() -> void:
	var setup: MmEncounterSetup = _bear_setup()
	for run_card: MmRunCard in setup.hero.deck:
		var renamed: ChangeNameModification = ChangeNameModification.new()
		renamed.new_name = "Renamed"
		run_card.modifications = [renamed] as Array[MmModification]

	var snapshot: EncounterSnapshot = _started(setup).snapshot()
	var card: MmObjectView = snapshot.view.hand[0]

	assert_eq(snapshot.look_of(card.id).name, "Renamed")
	assert_ne(snapshot.original_of(card.id).name, "Renamed", "The Original is the Card Definition (A465).")


func test_a_card_has_the_rarity_of_its_card_definition() -> void:
	var dragon: MmCardDefinition = load("res://content/cards/alpha/shivan_dragon.tres") as MmCardDefinition
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.copies(dragon, 40), Scenario.copies(Scenario.vanilla("Card"), 40))

	var snapshot: EncounterSnapshot = _started(setup).snapshot()
	var card: MmObjectView = snapshot.view.hand[0]

	assert_true(snapshot.has_rarity(card.id))
	assert_eq(snapshot.rarity_of(card.id), MmCardDefinition.Rarity.RARE)


func test_an_emblem_has_no_original_and_no_rarity() -> void:
	var setup: MmEncounterSetup = _bear_setup()
	setup.hero.emblems = [Scenario.emblem("Boon", [] as Array[MmAbility])] as Array[MmCardDefinition]

	var snapshot: EncounterSnapshot = _started(setup).snapshot()
	var emblem: MmObjectView = snapshot.view.command[0]

	assert_null(snapshot.original_of(emblem.id))
	assert_false(snapshot.has_rarity(emblem.id))


func test_a_permanent_has_a_state_list_and_a_card_in_hand_has_none() -> void:
	var presenter: EncounterPresenter = _started(_bear_setup(), false)
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()
	_pass_until(presenter, func() -> bool: return _cast_index(presenter) != -1)
	assert_eq(presenter.answer(_cast_index(presenter)), "")
	presenter.wait_until_idle()
	_pass_until(presenter, func() -> bool: return not presenter.snapshot().view.battlefield.is_empty())

	var snapshot: EncounterSnapshot = presenter.snapshot()
	var bear: MmObjectView = snapshot.view.battlefield[0]
	assert_eq(snapshot.state_list_of(bear.id).size(), 1)
	assert_eq(snapshot.state_list_of(bear.id)[0].title, "Summoning sick")
	assert_eq(snapshot.state_list_of(snapshot.view.hand[0].id).size(), 0)


func test_an_ability_on_the_stack_has_the_original_and_rarity_of_its_source() -> void:
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled([Scenario.life_land()]), Scenario.cycled([]))
	var presenter: EncounterPresenter = _started(setup, false)
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()
	_pass_until(presenter, func() -> bool: return _index_of(presenter, PlayLandAction) != -1)
	assert_eq(presenter.answer(_index_of(presenter, PlayLandAction)), "")
	presenter.wait_until_idle()
	assert_eq(presenter.answer(_index_of(presenter, ActivateAbilityAction)), "")
	presenter.wait_until_idle()

	var snapshot: EncounterSnapshot = presenter.snapshot()
	assert_eq(snapshot.view.stack.size(), 1)
	var ability: MmObjectView = snapshot.view.stack[0]
	assert_not_null(ability.ability)
	assert_eq(snapshot.original_of(ability.id).name, "Life Land")
	assert_true(snapshot.has_rarity(ability.id))


func _started(setup: MmEncounterSetup, is_auto_passing: bool = true) -> EncounterPresenter:
	var presenter: EncounterPresenter = EncounterPresenter.new(setup, DefaultAnswerAgent.new())
	presenter.set_auto_passing(is_auto_passing)
	presenter.start()
	presenter.wait_until_idle()
	if presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		presenter.wait_until_idle()
	return presenter


## The Hero's deck alternates Forests and free 2/2 Bears; the Villain's cards do nothing.
func _bear_setup() -> MmEncounterSetup:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))
	var cards: Array[MmCardDefinition] = []
	for index: int in 20:
		cards.append_array([Scenario.basic_land("Forest"), bear])
	return Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40))


func _in_hand(snapshot: EncounterSnapshot, card_name: String) -> MmObjectView:
	for card: MmObjectView in snapshot.view.hand:
		if card.name == card_name:
			return card
	return null


func _cast_index(presenter: EncounterPresenter) -> int:
	return _index_of(presenter, CastSpellAction)


func _index_of(presenter: EncounterPresenter, action_kind: Script) -> int:
	var decision: PriorityDecision = presenter.snapshot().decision as PriorityDecision
	if decision == null:
		return -1
	for index: int in decision.actions.size():
		if is_instance_of(decision.actions[index], action_kind):
			return index
	return -1


func _pass_until(presenter: EncounterPresenter, is_there: Callable) -> void:
	for attempt: int in 40:
		if is_there.call():
			return
		presenter.pass_priority()
		presenter.wait_until_idle()
