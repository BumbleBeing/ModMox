extends EncounterScreen
## DEMO, throwaway: a real encounter with a made-up Hero deck that brings out every Glow.
##
## godot --path . res://prototypes/glow_demo/glow_demo.tscn
## Add -- --seed=7 for another shuffle, or -- --shots=/absolute/folder to play a scripted
## game, save a picture of each Glow and quit.
##
## Made-up cards, all costing {0}:
##   Ember Staff      artifact, a mana ability and a damage ability: purple and blue
##   Spark Wand       artifact, a damage ability: purple
##   Wild Channeler   creature with a mana ability
##   Storm Cycler     creature with a damage ability
##   Deep Study       sorcery, draw four: fills the hand, so cleanup asks for a discard
##
## SIMULATED: the engine offers no ability from the hand yet. While a Wild Channeler or a
## Storm Cycler in hand can be cast, this screen adds its printed ability to what the card
## offers, so it glows green and blue or green and purple and a drop opens the Option Menu.
## The ability's row casts the card: there is nothing real for it to answer.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const CARDS: String = "res://content/cards/alpha/%s.tres"
const SIMULATED: Array[String] = ["Wild Channeler", "Storm Cycler"]

var _shots: String = ""
var _taken: Array[String] = []


func _init() -> void:
	starts_itself = false


func _ready() -> void:
	super._ready()
	var encounter: EncounterRequest = EncounterRequest.new()
	encounter.encounter_seed = 7
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			encounter.encounter_seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=")
	var setup: MmEncounterSetup = encounter.setup()
	setup.hero = setup.hero.duplicate() as MmPlayerSetup
	setup.hero.deck = Scenario.run_cards(_deck())
	var presenter: EncounterPresenter = EncounterPresenter.new(setup, encounter.villain_agent())
	if _shots == "":
		settings_path = GameSettings.PATH
		load_settings()
		use_settings(presenter)
		use_game_pace(presenter)
		begin(presenter)
	else:
		presenter.set_auto_passing(false)
		begin(presenter)
		await _play_for_pictures()
		get_tree().quit()


func _redraw() -> void:
	super._redraw()
	if _snapshot == null or _clicks == null:
		return
	for card: MmObjectView in _snapshot.view.hand:
		var plays: Array[ClickOption] = _clicks.hand_options_of(card.id)
		if not SIMULATED.has(card.name) or plays.is_empty() or _clicks._hand_abilities.has(card.id):
			continue
		var ability: ActivatedAbility = card.abilities[0] as ActivatedAbility
		var text: String = AbilityText.of_ability(ability, AbilityText.self_noun(card.card_types, card.name))
		_clicks._hand_abilities[card.id] = [ClickOption.new(plays[0].answer, text + " (demo: casts it)", ability.is_mana_ability())]
		_clicks._add_kind(card.id, DecisionClicks.Kind.MANA if ability.is_mana_ability() else DecisionClicks.Kind.ABILITY)
		var face: Control = face_of(card.id)
		if face != null and face != _lifted_face:
			BorderEffects.set_glow_of(face, _face_sizes[card.id], _clicks.colors_of(card.id))
	if _lifted_face != null:
		_glow_lifted_face()


func _deck() -> Array[MmCardDefinition]:
	var ping: Callable = func() -> ActivatedAbility:
		var ability: ActivatedAbility = ActivatedAbility.new()
		ability.costs = [TapCost.new()]
		ability.targets = [Scenario.any_target()]
		ability.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]
		return ability
	var staff: MmCardDefinition = Scenario.artifact("Ember Staff", [Scenario.tap_for_mana(MmMana.Type.RED, 1), ping.call()])
	var wand: MmCardDefinition = Scenario.artifact("Spark Wand", [ping.call()])
	var channeler: MmCardDefinition = Scenario.creature("Wild Channeler", 1, 1, [Scenario.tap_for_mana(MmMana.Type.GREEN, 1)], Scenario.mana_cost(0))
	var cycler: MmCardDefinition = Scenario.creature("Storm Cycler", 1, 1, [ping.call()], Scenario.mana_cost(0))
	var study: MmCardDefinition = Scenario.sorcery("Deep Study", Scenario.mana_cost(0), [], [Scenario.draw_cards(4, Scenario.you())])
	# Made-up cards borrow the art of real ones, which is found by a card's file name.
	var art: Dictionary[MmCardDefinition, String] = {staff: "ivory_tower", wand: "howling_mine", channeler: "llanowar_elves",
		cycler: "prodigal_sorcerer", study: "ancestral_recall"}
	for card: MmCardDefinition in art:
		card.resource_path = "res://prototypes/glow_demo/art/%s/%s.tres" % [card.name.to_snake_case(), art[card]]
	var deck: Array[MmCardDefinition] = []
	var counts: Array = [["forest", 7], ["mountain", 5], ["grizzly_bears", 5], ["lightning_bolt", 4],
		[staff, 4], [wand, 4], [channeler, 4], [cycler, 4], [study, 3]]
	for entry: Array in counts:
		var card: MmCardDefinition = entry[0] as MmCardDefinition if entry[0] is MmCardDefinition else load(CARDS % entry[0]) as MmCardDefinition
		deck.append_array(Scenario.copies(card, entry[1]))
	return deck


## Plays a scripted game and saves a picture the first time each kind of Glow is on screen.
func _play_for_pictures() -> void:
	_presenter.wait_until_idle()
	for attempt: int in 600:
		if _taken.size() == 7 or _snapshot.is_over():
			return
		var decision: MmPendingDecision = _snapshot.decision
		if decision is ChoosePlayOrDrawDecision:
			_give(ChoosePlayOrDrawDecision.Choice.PLAY)
		elif decision is KeepOrMulliganDecision:
			_give(KeepOrMulliganDecision.Choice.KEEP)
		elif decision is DeclareAttackersDecision:
			await _picture("7_attackers")
			_step()
		elif decision is ChooseCardsToDiscardDecision:
			await _picture("6_discard")
			_step()
		elif decision is ChooseTargetDecision:
			await _picture("5_targets")
			var candidates: Array[MmReference] = (decision as ChooseTargetDecision).candidates
			var choice: int = 0
			for index: int in candidates.size():
				if candidates[index].is_player() and candidates[index].id == VILLAIN:
					choice = index
			_give(choice)
		elif decision is PayManaDecision:
			await _picture("4_paying")
			_give(0)
		elif decision is PriorityDecision and _snapshot.view.stack.is_empty() and _snapshot.view.active_player_id == HERO \
				and _snapshot.view.step == MmTurn.Step.PRECOMBAT_MAIN:
			if not await _act():
				_step()
		else:
			_step()


## Does the next useful thing in the Hero's main phase, and says whether there was one.
func _act() -> bool:
	if _take(PlayLandAction, "Forest") or _take(PlayLandAction, ""):
		return true
	for card: String in ["Ember Staff", "Spark Wand", "Wild Channeler"]:
		if _take(CastSpellAction, card):
			return true
	var held: int = _hand_id("Storm Cycler")
	if not _taken.has("1_priority") and _on_battlefield("Ember Staff") and held != -1:
		await _picture("1_priority")
		var at: Vector2 = face_of(held).position + Vector2(40, 60)
		press_hand(at, false)
		drag_to(at + Vector2(0, -420))
		await _picture("2_held")
		release_hand(at + Vector2(0, -420))
		await _picture("3_option_menu")
		cancel_drag()
		return true
	if not _taken.has("4_paying") and _take(CastSpellAction, "Grizzly Bears"):
		return true
	if not _taken.has("5_targets") and (_take(ActivateAbilityAction, "Spark Wand") or _take(CastSpellAction, "Lightning Bolt")):
		return true
	if not _taken.has("6_discard") and _take(CastSpellAction, "Deep Study"):
		return true
	return false


func _on_battlefield(card_name: String) -> bool:
	for permanent: MmObjectView in _snapshot.view.battlefield:
		if permanent.name == card_name:
			return true
	return false


func _picture(file: String) -> void:
	if _taken.has(file):
		return
	_taken.append(file)
	for frame: int in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join(file + ".png"))
	print("saved ", file, ": ", _snapshot.decision.get_script().resource_path.get_file())


func _give(hero_answer: Variant) -> void:
	var refusal: String = _presenter.answer(hero_answer)
	if refusal != "":
		print("refused: ", refusal)
	_presenter.wait_until_idle()


## Takes the first action of [param kind] about a card named [param card_name] (any card
## when it is ""), and says whether there was one.
func _take(kind: Script, card_name: String) -> bool:
	var actions: Array[MmAction] = []
	if _snapshot.decision is PriorityDecision:
		actions = (_snapshot.decision as PriorityDecision).actions
	for index: int in actions.size():
		var name_now: String = EncounterSnapshot.name_in(_snapshot.view, DecisionClicks.object_of(actions[index]))
		if is_instance_of(actions[index], kind) and (card_name == "" or name_now == card_name):
			_give(index)
			return true
	return false


func _step_until(is_there: Callable) -> void:
	for attempt: int in 300:
		if is_there.call() or _snapshot.is_over():
			return
		_step()


## Answers whatever is asked in the plainest way: pass, the first choice, nothing declared.
func _step() -> void:
	var decision: MmPendingDecision = _snapshot.decision
	if decision is PriorityDecision:
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	elif decision is ChooseCardsToDiscardDecision:
		var discard: ChooseCardsToDiscardDecision = decision as ChooseCardsToDiscardDecision
		_give(discard.candidate_ids.slice(0, discard.count))
	elif decision is DivideCombatDamageDecision:
		_give(CombatSelection.default_split(decision as DivideCombatDamageDecision))
	elif decision is ChooseTargetDecision or decision is PayManaDecision:
		_give(0)
	else:
		_give([])


func _hand_id(card_name: String) -> int:
	for card: MmObjectView in _snapshot.view.hand:
		if card.name == card_name and not _clicks.hand_options_of(card.id).is_empty():
			return card.id
	return -1
