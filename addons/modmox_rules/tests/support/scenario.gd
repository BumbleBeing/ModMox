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


## Answers every remaining pregame decision: choose to play, keep every hand, and bottom
## the first candidates offered. Stops at the first priority decision of the game.
## Returns the first rejection reason, or "" if none.
static func keep_all(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is PriorityDecision)


## Answers decisions with simple defaults until [param stop] returns true for the engine:
## play first, keep, pass priority, and bottom or discard the first candidates offered.
## Returns the first rejection reason, or "" once stopped. Gives up after [param limit].
static func autoplay(engine: MmEngine, stop: Callable, limit: int = 2000) -> String:
	for _index: int in limit:
		if stop.call(engine):
			return ""
		var decision: MmPendingDecision = engine.pending_decision()
		var answer: Variant
		if decision is PriorityDecision:
			answer = pass_index(decision as PriorityDecision)
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
static func play_until_game_turn(engine: MmEngine, game_turn: int) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool:
		return running.game_state().game_turn >= game_turn and running.pending_decision() is PriorityDecision)


## Plays until [param step] of the given Game Turn has begun and the first decision in it
## is pending.
static func play_until_step(engine: MmEngine, game_turn: int, step: MmTurn.Step) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool:
		var state: MmGameState = running.game_state()
		return state.game_turn == game_turn and state.step == step)


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
