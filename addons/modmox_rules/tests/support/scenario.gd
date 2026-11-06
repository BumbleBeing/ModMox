extends RefCounted
## Builders and shortcuts for encounter scenarios shared by tests.

const Rule := MmEncounterSetup.StartingPlayerRule


## A deck of [param size] vanilla cards named "<prefix> 1", "<prefix> 2", ...
static func deck(size: int, prefix: String) -> Array[MmRunCard]:
	var cards: Array[MmRunCard] = []
	for index: int in size:
		var definition: MmCardDefinition = MmCardDefinition.new()
		definition.name = "%s %d" % [prefix, index + 1]
		var run_card: MmRunCard = MmRunCard.new()
		run_card.base = definition
		cards.append(run_card)
	return cards


## An Encounter Setup with default 40-card decks, 20 life and 7-card opening hands.
static func setup(
		rule: MmEncounterSetup.StartingPlayerRule = Rule.HERO_STARTS,
		encounter_seed: int = 1,
		hero_deck_size: int = 40,
		villain_deck_size: int = 40) -> MmEncounterSetup:
	var result: MmEncounterSetup = MmEncounterSetup.new()
	result.hero = player_setup(deck(hero_deck_size, "Hero Card"))
	result.villain = player_setup(deck(villain_deck_size, "Villain Card"))
	result.starting_player_rule = rule
	result.encounter_seed = encounter_seed
	return result


static func player_setup(cards: Array[MmRunCard]) -> MmPlayerSetup:
	var result: MmPlayerSetup = MmPlayerSetup.new()
	result.deck = cards
	return result


## An Encounter Setup whose decks are built from the given Card Definitions, in order.
static func setup_with(
		hero_cards: Array[MmCardDefinition],
		villain_cards: Array[MmCardDefinition],
		rule: MmEncounterSetup.StartingPlayerRule = Rule.HERO_STARTS,
		encounter_seed: int = 1) -> MmEncounterSetup:
	var result: MmEncounterSetup = setup(rule, encounter_seed, 0, 0)
	result.hero.deck = run_cards(hero_cards)
	result.villain.deck = run_cards(villain_cards)
	return result


static func run_cards(definitions: Array[MmCardDefinition]) -> Array[MmRunCard]:
	var cards: Array[MmRunCard] = []
	for definition: MmCardDefinition in definitions:
		var run_card: MmRunCard = MmRunCard.new()
		run_card.base = definition
		cards.append(run_card)
	return cards


## [param count] references to [param definition], for building decks.
static func copies(definition: MmCardDefinition, count: int) -> Array[MmCardDefinition]:
	var result: Array[MmCardDefinition] = []
	for _index: int in count:
		result.append(definition)
	return result


## A card with no types or abilities.
static func vanilla(card_name: String) -> MmCardDefinition:
	var definition: MmCardDefinition = MmCardDefinition.new()
	definition.name = card_name
	return definition


## A basic land with no written abilities: its mana ability comes from its subtype.
static func basic_land(land_type: String) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla(land_type)
	definition.card_types = [MmCardTypes.CardType.LAND]
	definition.supertypes = [MmCardTypes.Supertype.BASIC]
	definition.subtypes = [land_type]
	return definition


## A non-basic land with the written ability "{T}: Add [param amount] mana of [param type]".
static func mana_land(card_name: String, type: MmMana.Type, amount: int) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla(card_name)
	definition.card_types = [MmCardTypes.CardType.LAND]
	definition.abilities = [tap_for_mana(type, amount)]
	return definition


## The ability "{T}: Add [param amount] mana of [param type]".
static func tap_for_mana(type: MmMana.Type, amount: int) -> ActivatedAbility:
	var value: ConstantValue = ConstantValue.new()
	value.value = amount
	var effect: AddManaEffect = AddManaEffect.new()
	effect.mana_type = type
	effect.amount = value
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.effects = [effect]
	return ability


## The first action in a priority decision for which [param matches] returns true, as an
## index, or -1.
static func action_index(decision: PriorityDecision, matches: Callable) -> int:
	for index: int in decision.actions.size():
		if matches.call(decision.actions[index]):
			return index
	return -1


## The index of the action that plays the land [param object_id], or -1.
static func play_land_index(decision: PriorityDecision, object_id: int) -> int:
	return action_index(decision, func(action: MmAction) -> bool:
		return action is PlayLandAction and (action as PlayLandAction).object_id == object_id)


## The index of the first action that activates an ability of [param object_id], or -1.
static func activate_index(decision: PriorityDecision, object_id: int) -> int:
	return action_index(decision, func(action: MmAction) -> bool:
		return action is ActivateAbilityAction and (action as ActivateAbilityAction).object_id == object_id)


## Plays the first land the priority holder may play. Returns the new object's ID, or -1.
static func play_first_land(engine: MmEngine) -> int:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	var index: int = action_index(decision, func(action: MmAction) -> bool: return action is PlayLandAction)
	if index == -1 or engine.submit(index) != "":
		return -1
	return engine.game_state().battlefield.object_ids().back()


## Answers every remaining pregame decision: choose to play, keep every hand, and bottom
## the first candidates offered. Stops at the first priority decision of the game.
## Returns the first rejection reason, or "" if none.
static func keep_all(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is PriorityDecision)


## Answers decisions with simple defaults until [param stop] returns true for the engine:
## play first, keep, pass priority, and bottom or discard the first candidates offered.
## With [param play_lands], plays the first land offered instead of passing.
## Returns the first rejection reason, or "" once stopped. Gives up after [param limit].
static func autoplay(engine: MmEngine, stop: Callable, play_lands: bool = false, limit: int = 2000) -> String:
	for _index: int in limit:
		if stop.call(engine):
			return ""
		var decision: MmPendingDecision = engine.pending_decision()
		var answer: Variant
		if decision is PriorityDecision:
			var priority: PriorityDecision = decision as PriorityDecision
			answer = pass_index(priority)
			if play_lands:
				var land: int = action_index(priority, func(action: MmAction) -> bool: return action is PlayLandAction)
				if land != -1:
					answer = land
		elif decision is KeepOrMulliganDecision:
			answer = KeepOrMulliganDecision.Choice.KEEP
		elif decision is ChooseCardsToBottomDecision:
			var bottom: ChooseCardsToBottomDecision = decision as ChooseCardsToBottomDecision
			answer = bottom.candidate_ids.slice(0, bottom.count)
		elif decision is ChooseCardsToDiscardDecision:
			var discard: ChooseCardsToDiscardDecision = decision as ChooseCardsToDiscardDecision
			answer = discard.candidate_ids.slice(0, discard.count)
		elif decision is ChoosePlayOrDrawDecision:
			answer = ChoosePlayOrDrawDecision.Choice.PLAY
		else:
			return "Unexpected decision: %s" % ("none" if decision == null else decision.describe())
		var error: String = engine.submit(answer)
		if error != "":
			return error
	return "Gave up after %d decisions." % limit


## Plays until the given Game Turn has begun and its first priority decision is pending.
static func play_until_game_turn(engine: MmEngine, game_turn: int, play_lands: bool = false) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool:
		return running.game_state().game_turn >= game_turn and running.pending_decision() is PriorityDecision,
		play_lands)


## Plays until [param step] of the given Game Turn has begun and the first decision in it
## is pending.
static func play_until_step(engine: MmEngine, game_turn: int, step: MmTurn.Step, play_lands: bool = false) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool:
		var state: MmGameState = running.game_state()
		return state.game_turn == game_turn and state.step == step,
		play_lands)


## The index of the Pass action in a priority decision.
static func pass_index(decision: PriorityDecision) -> int:
	for index: int in decision.actions.size():
		if decision.actions[index] is PassAction:
			return index
	return -1


## Every step begun so far, grouped by Game Turn: { game_turn: [steps in order] }.
static func steps_by_game_turn(engine: MmEngine) -> Dictionary[int, Array]:
	var result: Dictionary[int, Array] = {}
	var game_turn: int = 0
	for event: MmEvent in engine.event_log():
		if event is TurnStartedEvent:
			game_turn = (event as TurnStartedEvent).game_turn
			result[game_turn] = []
		elif event is StepStartedEvent:
			result[game_turn].append((event as StepStartedEvent).step)
	return result


## Card names in a zone, first object first, read through the characteristics query.
static func names(engine: MmEngine, zone: MmZone) -> Array[String]:
	var result: Array[String] = []
	for object: MmGameObject in zone.objects():
		result.append(engine.game_state().characteristics_of(object).name)
	return result


## Card identities in a zone, first object first.
static func card_ids(zone: MmZone) -> Array[int]:
	var result: Array[int] = []
	for object: MmGameObject in zone.objects():
		result.append(object.card_id)
	return result
