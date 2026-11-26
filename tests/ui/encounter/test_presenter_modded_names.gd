extends GutTest
## A card with Mods is called by its Modded Name inside an encounter too (ADR 0029): in
## hand, on the stack and in the graveyard, and so is an ability it puts on the stack. The
## engine knows only the Original's name, so the presenter is told each Run Card's.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const DAYDREAM: String = "res://content/cards/secrets_of_strixhaven/daydream.tres"
const PLAINS: String = "res://content/cards/alpha/plains.tres"
const GRIZZLY_BEARS: String = "res://content/cards/alpha/grizzly_bears.tres"
const VIOLENT: String = "res://content/mods/violent.tres"


func test_an_overloaded_daydream_keeps_its_modded_name_in_hand_on_the_stack_and_in_the_graveyard() -> void:
	var setup: MmEncounterSetup = _daydream_setup()
	var presenter: EncounterPresenter = _started(setup, _modded_names(setup), false)
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()

	var daydream: MmObjectView = _named(presenter.snapshot().view.hand, "Overloaded Daydream")
	assert_not_null(daydream, "In hand: %s" % [_names(presenter.snapshot().view.hand)])
	assert_eq(presenter.snapshot().look_of(daydream.id).name, "Overloaded Daydream")
	assert_eq(presenter.snapshot().original_of(daydream.id).name, "Daydream", "The Original goes by its own name.")
	assert_not_null(_named(presenter.snapshot().view.hand, "Plains"), "A card with no Mod keeps its own name.")

	_pass_until(presenter, func() -> bool: return _index_of(presenter, PlayLandAction) != -1)
	assert_eq(presenter.answer(_index_of(presenter, PlayLandAction)), "")
	presenter.wait_until_idle()
	# Held, so the Hero pays by hand and keeps priority with it on the stack.
	presenter.is_hold_key_down = true
	assert_eq(presenter.answer(_cast_index(presenter, daydream.card_id)), "")
	presenter.wait_until_idle()
	assert_true(presenter.snapshot().decision is PayManaDecision)
	assert_eq(presenter.answer(0), "", "The Plains pays its {W}.")
	presenter.wait_until_idle()

	var on_stack: MmObjectView = _of_card(presenter.snapshot().view.stack, daydream.card_id)
	assert_not_null(on_stack, "It is on the stack.")
	assert_eq(on_stack.name, "Overloaded Daydream")
	assert_eq(presenter.snapshot().look_of(on_stack.id).name, "Overloaded Daydream")

	presenter.is_hold_key_down = false
	_pass_until(presenter, func() -> bool: return presenter.snapshot().view.stack.is_empty())
	var graveyard: Array[MmObjectView] = presenter.snapshot().view.graveyards[MmEncounterSetup.HERO_PLAYER_ID]
	var buried: MmObjectView = _of_card(graveyard, daydream.card_id)
	assert_not_null(buried, "It is in the graveyard, where flashback casts it from.")
	assert_eq(buried.name, "Overloaded Daydream")
	assert_eq(presenter.snapshot().look_of(buried.id).name, "Overloaded Daydream")


func test_a_violent_grizzly_bears_keeps_its_modded_name_in_hand() -> void:
	var setup: MmEncounterSetup = _daydream_setup()
	var presenter: EncounterPresenter = _started(setup, _modded_names(setup))

	var bears: MmObjectView = _named(presenter.snapshot().view.hand, "Violent Grizzly Bears")
	assert_not_null(bears, "In hand: %s" % [_names(presenter.snapshot().view.hand)])
	assert_eq(presenter.snapshot().look_of(bears.id).name, "Violent Grizzly Bears")


func test_an_ability_on_the_stack_goes_by_its_sources_modded_name() -> void:
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled([Scenario.life_land()]), Scenario.cycled([]))
	var names: Dictionary[MmRunCard, String] = {}
	for run_card: MmRunCard in setup.hero.deck:
		names[run_card] = ModdedName.of(run_card.base.name, [_named_mod("Shiny")] as Array[Mod])
	var presenter: EncounterPresenter = _started(setup, names, false)
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()
	_pass_until(presenter, func() -> bool: return _index_of(presenter, PlayLandAction) != -1)
	assert_eq(presenter.answer(_index_of(presenter, PlayLandAction)), "")
	presenter.wait_until_idle()
	assert_eq(presenter.answer(_index_of(presenter, ActivateAbilityAction)), "")
	presenter.wait_until_idle()

	var ability: MmObjectView = presenter.snapshot().view.stack[0]
	assert_eq(ability.name, "Shiny Life Land ability")
	assert_eq(presenter.snapshot().look_of(ability.id).name, "Shiny Life Land ability")


func test_a_copy_of_a_modded_spell_and_the_token_it_becomes_go_by_its_modded_name() -> void:
	var echo: MmCardDefinition = Scenario.creature("Echo", 1, 1, [Scenario.triggered(Scenario.cast_this_spell(), [Scenario.copy_spell()])])
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled([echo]), Scenario.cycled([]))
	var names: Dictionary[MmRunCard, String] = {}
	for run_card: MmRunCard in setup.hero.deck:
		names[run_card] = ModdedName.of(run_card.base.name, [_named_mod("Shiny")] as Array[Mod])
	var presenter: EncounterPresenter = _started(setup, names, false)
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()
	_pass_until(presenter, func() -> bool: return _cast_index(presenter, presenter.snapshot().view.hand[0].card_id) != -1)
	presenter.is_hold_key_down = true
	assert_eq(presenter.answer(_cast_index(presenter, presenter.snapshot().view.hand[0].card_id)), "")
	presenter.wait_until_idle()
	presenter.pass_priority()
	presenter.wait_until_idle()

	var copy: MmObjectView = presenter.snapshot().view.stack.back()
	assert_true(copy.is_copy, "The cast trigger has made the copy, on top: %s" % [_names(presenter.snapshot().view.stack)])
	assert_eq(copy.name, "Shiny Echo")
	assert_eq(presenter.snapshot().look_of(copy.id).name, "Shiny Echo")

	presenter.is_hold_key_down = false
	_pass_until(presenter, func() -> bool: return presenter.snapshot().view.stack.is_empty())
	var token: MmObjectView = null
	for permanent: MmObjectView in presenter.snapshot().view.battlefield:
		if permanent.is_token:
			token = permanent
	assert_not_null(token, "The copy resolved into a token.")
	assert_eq(token.name, "Shiny Echo")
	assert_eq(presenter.snapshot().look_of(token.id).name, "Shiny Echo")


## The Hero's deck is Plains, an Overloaded Daydream and a Violent Grizzly Bears, over
## and over, each Mod applied as the deckbuilder applies it; the Villain's cards do nothing.
## The Overloaded Mod is the real one's Augmentation without its Mod Cost, so a Plains
## casts it.
func _daydream_setup() -> MmEncounterSetup:
	var cards: Array[MmCardDefinition] = [load(PLAINS), load(DAYDREAM), load(GRIZZLY_BEARS)]
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(cards), Scenario.cycled([]))
	var overloaded: Mod = _named_mod("Overloaded")
	overloaded.augmentation = [OverloadModification.new()] as Array[MmModification]
	for run_card: MmRunCard in setup.hero.deck:
		if run_card.base.name == "Daydream":
			run_card.set_meta(&"mod", overloaded)
		elif run_card.base.name == "Grizzly Bears":
			run_card.set_meta(&"mod", load(VIOLENT))
	return setup


## Applies each Run Card's Mod as the deckbuilder does and gives the Modded Names.
func _modded_names(setup: MmEncounterSetup) -> Dictionary[MmRunCard, String]:
	var names: Dictionary[MmRunCard, String] = {}
	for run_card: MmRunCard in setup.hero.deck:
		if not run_card.has_meta(&"mod"):
			continue
		var card: DeckbuilderCard = DeckbuilderCard.new(0, run_card)
		card.attach(run_card.get_meta(&"mod") as Mod)
		names[run_card] = card.card_name()
	return names


static func _named_mod(mod_name: String) -> Mod:
	var mod: Mod = Mod.new()
	mod.name = mod_name
	return mod


func _started(setup: MmEncounterSetup, card_names: Dictionary[MmRunCard, String], is_auto_passing: bool = true) -> EncounterPresenter:
	var presenter: EncounterPresenter = EncounterPresenter.new(setup, DefaultAnswerAgent.new())
	presenter.card_names = card_names
	presenter.set_auto_passing(is_auto_passing)
	presenter.set_auto_tapping(true)
	presenter.start()
	presenter.wait_until_idle()
	if presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		presenter.wait_until_idle()
	return presenter


func _named(seen: Array[MmObjectView], card_name: String) -> MmObjectView:
	for card: MmObjectView in seen:
		if card.name == card_name:
			return card
	return null


func _of_card(seen: Array[MmObjectView], card_id: int) -> MmObjectView:
	for card: MmObjectView in seen:
		if card.card_id == card_id:
			return card
	return null


func _names(seen: Array[MmObjectView]) -> Array[String]:
	var names: Array[String] = []
	for card: MmObjectView in seen:
		names.append(card.name)
	return names


## The index of the Action that casts the card with Card Identity [param card_id].
func _cast_index(presenter: EncounterPresenter, card_id: int) -> int:
	var decision: PriorityDecision = presenter.snapshot().decision as PriorityDecision
	if decision == null:
		return -1
	for index: int in decision.actions.size():
		var cast: CastSpellAction = decision.actions[index] as CastSpellAction
		if cast != null and presenter.snapshot().view.hand.any(
				func(card: MmObjectView) -> bool: return card.id == cast.object_id and card.card_id == card_id):
			return index
	return -1


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
