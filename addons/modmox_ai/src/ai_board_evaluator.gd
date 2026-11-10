class_name AiBoardEvaluator
extends RefCounted
## Turns a game state into a number from one player's point of view (glossary "Board
## Evaluator"): their side's worth minus the other side's. The starting numbers follow
## Forge's published calibration (A162); every characteristic is read through
## characteristics_of(), so pumps, granted keywords and Modifications all count.

## The score of an encounter won; minus this for one lost.
const WIN: int = 1000000
const LAND_VALUE: int = 8


## [param player_id]'s score of [param state].
static func score(state: MmGameState, player_id: int, profile: AiProfile) -> int:
	if state.is_over:
		if state.winner_id == MmGameState.NO_PLAYER:
			return 0
		return WIN if state.winner_id == player_id else -WIN
	return side_value(state, player_id, profile) - side_value(state, state.opponent_of(player_id).id, profile)


## The worth of everything [param player_id] has: life, cards in hand and permanents.
static func side_value(state: MmGameState, player_id: int, profile: AiProfile) -> int:
	var owner: MmPlayer = state.player(player_id)
	var value: int = owner.life * 2
	for card: MmGameObject in owner.hand.objects():
		value += hand_card_value(state, card, profile)
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.controller_id == player_id:
			value += permanent_value(state, permanent, profile)
	return value


## What a card in hand is worth (A179): a nonland card is worth more the more it costs.
static func hand_card_value(state: MmGameState, card: MmGameObject, profile: AiProfile) -> int:
	var characteristics: MmCharacteristics = state.characteristics_of(card)
	if characteristics.has_card_type(MmCardTypes.CardType.LAND):
		return profile.hand_card_value
	return profile.hand_card_value + profile.hand_mana_value_bonus * characteristics.mana_value()


static func permanent_value(state: MmGameState, permanent: MmGameObject, profile: AiProfile) -> int:
	var characteristics: MmCharacteristics = state.characteristics_of(permanent)
	if characteristics.has_card_type(MmCardTypes.CardType.CREATURE):
		var value: int = creature_value(state, permanent)
		if state.is_summoning_sick(permanent):
			value = value * profile.summoning_sick_percent / 100
		return value
	if characteristics.has_card_type(MmCardTypes.CardType.LAND):
		return LAND_VALUE
	return 50 + 30 * characteristics.mana_value()


## A creature's worth as it is now, before summoning sickness.
static func creature_value(state: MmGameState, creature: MmGameObject) -> int:
	var characteristics: MmCharacteristics = state.characteristics_of(creature)
	var power: int = characteristics.power
	var toughness: int = characteristics.toughness
	var value: int = 80 + 15 * power + 10 * toughness + 5 * characteristics.mana_value()
	for ability: MmAbility in characteristics.abilities:
		if ability is FlyingAbility:
			value += 10 * power
		elif ability is DeathtouchAbility:
			value += 25
		elif ability is DoubleStrikeAbility:
			value += 10 + 15 * power
		elif ability is FirstStrikeAbility:
			value += 10 + 5 * power
		elif ability is VigilanceAbility:
			value += 5 * (power + toughness)
		elif ability is TrampleAbility:
			value += 5 * (power - 1)
		elif ability is IndestructibleAbility:
			value += 70
		elif ability is ProtectionAbility:
			value += 20
		elif ability is DefenderAbility:
			value -= 9 * power + 40
		elif ability is ActivatedAbility:
			value += 10
	return value
