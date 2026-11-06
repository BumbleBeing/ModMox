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
## the first candidates offered. Returns the first rejection reason, or "" if none.
static func keep_all(engine: MmEngine) -> String:
	var decision: MmPendingDecision = engine.pending_decision()
	while decision != null:
		var answer: Variant
		if decision is KeepOrMulliganDecision:
			answer = KeepOrMulliganDecision.Choice.KEEP
		elif decision is ChooseCardsToBottomDecision:
			var bottom: ChooseCardsToBottomDecision = decision as ChooseCardsToBottomDecision
			answer = bottom.candidate_ids.slice(0, bottom.count)
		elif decision is ChoosePlayOrDrawDecision:
			answer = ChoosePlayOrDrawDecision.Choice.PLAY
		else:
			return "Unexpected decision: %s" % decision.describe()
		var error: String = engine.submit(answer)
		if error != "":
			return error
		decision = engine.pending_decision()
	return ""


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
