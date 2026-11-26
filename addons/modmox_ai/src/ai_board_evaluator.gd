class_name AiBoardEvaluator
extends RefCounted
## Turns a game state into a number from one player's point of view (glossary "Board
## Evaluator"): their side's worth minus the other side's. The starting numbers follow
## Forge's published calibration (A162); every characteristic is read through
## characteristics_of(), so pumps, granted keywords and Modifications all count.

## The score of an encounter won; minus this for one lost.
const WIN: int = 1000000
const LAND_VALUE: int = 8
## A noncreature token used up by its own abilities, as a Treasure, a Clue or a Map is: one
## payoff and gone, and no card was spent on it, so it is worth what a card of mana value 1
## is in hand rather than the 50 a noncreature permanent card starts at. At 50 the Agent
## would not trade one for a +1/+1 counter and a card, as Selfcraft Mechan offers.
const ONE_SHOT_TOKEN_VALUE: int = 15


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
	if permanent.is_token and _is_used_up_by_its_abilities(characteristics):
		return ONE_SHOT_TOKEN_VALUE
	return 50 + 30 * characteristics.mana_value()


## Whether every ability of [param characteristics] sacrifices its permanent as it is used,
## and it has one: what it does, it does once.
static func _is_used_up_by_its_abilities(characteristics: MmCharacteristics) -> bool:
	if characteristics.abilities.is_empty():
		return false
	for ability: MmAbility in characteristics.abilities:
		var activated: ActivatedAbility = ability as ActivatedAbility
		if activated == null or not activated.costs.any(func(cost: MmCost) -> bool: return cost is SacrificeThisCost):
			return false
	return true


## A creature's worth as it is now, before summoning sickness.
static func creature_value(state: MmGameState, creature: MmGameObject) -> int:
	var characteristics: MmCharacteristics = state.characteristics_of(creature)
	# Its worth in a fight is the combat damage it assigns: its power, or its toughness when
	# an ability says so (CombatProcedure.combat_damage_amount()).
	var damage: int = CombatProcedure.combat_damage_amount(state, creature)
	var toughness: int = characteristics.toughness
	var value: int = 80 + 15 * damage + 10 * toughness + 5 * characteristics.mana_value()
	# A keyword a creature has twice does nothing more than one, so each counts once.
	var counted: Dictionary[Script, bool] = {}
	for ability: MmAbility in characteristics.abilities:
		var kind: Script = ability.get_script()
		if not ability is ActivatedAbility:
			if counted.has(kind):
				continue
			counted[kind] = true
		if ability is FlyingAbility:
			value += 10 * damage
		elif ability is DeathtouchAbility:
			value += 25
		elif ability is LifelinkAbility:
			value += 10 + 10 * damage
		elif ability is DoubleStrikeAbility:
			value += 10 + 15 * damage
		elif ability is FirstStrikeAbility:
			value += 10 + 5 * damage
		elif ability is VigilanceAbility:
			value += 5 * (damage + toughness)
		elif ability is TrampleAbility:
			value += 5 * (damage - 1)
		elif ability is MenaceAbility or ability is SkulkAbility:
			value += 5 * damage
		elif ability is CantBeBlockedAbility:
			value += 15 * damage
		elif ability is IndestructibleAbility:
			value += 70
		elif ability is ProtectionAbility:
			value += 20
		elif ability is DefenderAbility:
			value -= 9 * damage + 40
		elif ability is CantBlockAbility:
			value -= 5 * toughness  # It never stands in the way of an attack.
		elif ability is ActivatedAbility:
			value += 10
	return value


## Whether [param creature] would return to the battlefield as it died now, as one with
## undying and no +1/+1 counters would (CR 702.93a): it has a triggered ability of its own
## dying that returns the card it becomes (TriggeringCardSelection, engine ADR 0096), whose
## intervening "if" holds now. Read from its abilities, so a Modification that gives or
## takes undying changes the answer.
static func comes_back_when_it_dies(state: MmGameState, creature: MmGameObject) -> bool:
	for ability: MmAbility in state.characteristics_of(creature).abilities:
		var triggered: TriggeredAbility = ability as TriggeredAbility
		if triggered == null or not _is_own_dying(triggered.trigger) or not _returns_its_card(triggered.effects):
			continue
		var context: MmEffectContext = MmEffectContext.new(creature.controller_id, creature.id)
		context.triggering_object_id = creature.id
		if triggered.condition == null or triggered.condition.is_true(state, context):
			return true
	return false


static func _is_own_dying(trigger: MmTrigger) -> bool:
	var dies: ZoneChangeTrigger = trigger as ZoneChangeTrigger
	return dies != null and not dies.any_from_zone and dies.from_zone == MmZone.Kind.BATTLEFIELD \
		and not dies.any_to_zone and dies.to_zone == MmZone.Kind.GRAVEYARD and dies.filter is IsSourceFilter


static func _returns_its_card(effects: Array[MmEffect]) -> bool:
	for effect: MmEffect in effects:
		var back: ReturnToBattlefieldEffect = effect as ReturnToBattlefieldEffect
		if back != null and back.selection is TriggeringCardSelection:
			return true
	return false
