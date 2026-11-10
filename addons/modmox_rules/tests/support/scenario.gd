extends RefCounted
## Builders and shortcuts for encounter scenarios shared by tests.

const ExileTestEffect := preload("res://addons/modmox_rules/tests/support/exile_test_effect.gd")

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
## play first, keep, pass priority, bottom or discard the first candidates offered, attack
## and block with nothing, put all combat damage on the first recipient, stack triggers in
## the order offered, and choose the first target and replacement effect offered.
## With [param play_lands], plays the first land offered instead of passing.
## Returns the first rejection reason, or "" once stopped. Gives up after [param limit].
static func autoplay(engine: MmEngine, stop: Callable, play_lands: bool = false, limit: int = 2000) -> String:
	for _index: int in limit:
		if stop.call(engine):
			return ""
		var decision: MmPendingDecision = engine.pending_decision()
		var answer: Variant = default_answer(decision, play_lands)
		if answer == null:
			return "Unexpected decision: %s" % ("none" if decision == null else decision.describe())
		var error: String = engine.submit(answer)
		if error != "":
			return error
	return "Gave up after %d decisions." % limit


## autoplay()'s answer to [param decision], or null for a decision it does not know. The
## answer is a Variant because each decision kind takes a different shape.
static func default_answer(decision: MmPendingDecision, play_lands: bool = false) -> Variant:
	if decision is PriorityDecision:
		var priority: PriorityDecision = decision as PriorityDecision
		if play_lands:
			var land: int = action_index(priority, func(action: MmAction) -> bool: return action is PlayLandAction)
			if land != -1:
				return land
		return pass_index(priority)
	if decision is KeepOrMulliganDecision:
		return KeepOrMulliganDecision.Choice.KEEP
	if decision is ChooseCardsToBottomDecision:
		var bottom: ChooseCardsToBottomDecision = decision as ChooseCardsToBottomDecision
		return bottom.candidate_ids.slice(0, bottom.count)
	if decision is ChooseCardsToDiscardDecision:
		var discard: ChooseCardsToDiscardDecision = decision as ChooseCardsToDiscardDecision
		return discard.candidate_ids.slice(0, discard.count)
	if decision is ChoosePlayOrDrawDecision:
		return ChoosePlayOrDrawDecision.Choice.PLAY
	if decision is DeclareAttackersDecision or decision is DeclareBlockersDecision:
		return []
	if decision is DivideCombatDamageDecision:
		return all_to_first(decision as DivideCombatDamageDecision)
	if decision is OrderTriggersDecision:
		return range((decision as OrderTriggersDecision).source_object_ids.size())
	if decision is ChooseTargetDecision or decision is ChooseReplacementEffectDecision:
		return 0
	return null


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


# --- Milestone 5: spells, targets and payment ---------------------------------------


static func mana_cost(generic: int, symbols: Array[MmMana.Type] = []) -> MmManaCost:
	var cost: MmManaCost = MmManaCost.new()
	cost.generic = generic
	cost.symbols = symbols
	return cost


static func constant(number: int) -> ConstantValue:
	var value: ConstantValue = ConstantValue.new()
	value.value = number
	return value


static func target(filter: MmFilter) -> TargetSpec:
	var spec: TargetSpec = TargetSpec.new()
	spec.filter = filter
	return spec


## "Any target": a creature or a player (there are no planeswalkers, ADR 0001).
static func any_target() -> TargetSpec:
	var creature: HasCardTypeFilter = HasCardTypeFilter.new()
	creature.card_type = MmCardTypes.CardType.CREATURE
	var either: AnyOfFilter = AnyOfFilter.new()
	either.filters = [IsPlayerFilter.new(), creature]
	return target(either)


static func target_player() -> TargetSpec:
	return target(IsPlayerFilter.new())


## "Untapped land": AllOf(land, Not(tapped)).
static func untapped_land() -> MmFilter:
	var land: HasCardTypeFilter = HasCardTypeFilter.new()
	land.card_type = MmCardTypes.CardType.LAND
	var untapped: NotFilter = NotFilter.new()
	untapped.filter = IsTappedFilter.new()
	var both: AllOfFilter = AllOfFilter.new()
	both.filters = [land, untapped]
	return both


static func targeted(index: int) -> TargetSelection:
	var selection: TargetSelection = TargetSelection.new()
	selection.target_index = index
	return selection


static func each(filter: MmFilter) -> EachSelection:
	var selection: EachSelection = EachSelection.new()
	selection.filter = filter
	return selection


static func deal_damage(amount: int, recipients: MmSelection) -> DealDamageEffect:
	var effect: DealDamageEffect = DealDamageEffect.new()
	effect.amount = constant(amount)
	effect.recipients = recipients
	return effect


static func draw_cards(amount: int, players: MmSelection) -> DrawCardsEffect:
	var effect: DrawCardsEffect = DrawCardsEffect.new()
	effect.amount = constant(amount)
	effect.players = players
	return effect


static func gain_life(amount: int, players: MmSelection) -> GainLifeEffect:
	var effect: GainLifeEffect = GainLifeEffect.new()
	effect.amount = constant(amount)
	effect.players = players
	return effect


static func add_mana(type: MmMana.Type, amount: int) -> AddManaEffect:
	var effect: AddManaEffect = AddManaEffect.new()
	effect.mana_type = type
	effect.amount = constant(amount)
	return effect


static func spell(card_name: String, card_type: MmCardTypes.CardType, cost: MmManaCost,
		targets: Array[TargetSpec], effects: Array[MmEffect]) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla(card_name)
	definition.card_types = [card_type]
	definition.mana_cost = cost
	var ability: SpellAbility = SpellAbility.new()
	ability.targets = targets
	ability.effects = effects
	definition.abilities = [ability]
	return definition


static func instant(card_name: String, cost: MmManaCost, targets: Array[TargetSpec], effects: Array[MmEffect]) -> MmCardDefinition:
	return spell(card_name, MmCardTypes.CardType.INSTANT, cost, targets, effects)


static func sorcery(card_name: String, cost: MmManaCost, targets: Array[TargetSpec], effects: Array[MmEffect]) -> MmCardDefinition:
	return spell(card_name, MmCardTypes.CardType.SORCERY, cost, targets, effects)


## {R} instant: 3 damage to any target.
static func bolt() -> MmCardDefinition:
	return instant("Bolt", mana_cost(0, [MmMana.Type.RED]), [any_target()], [deal_damage(3, targeted(0))])


## A land with an ability that uses the stack: "{T}: Target player gains 1 life."
static func life_land() -> MmCardDefinition:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.targets = [target_player()]
	ability.effects = [gain_life(1, targeted(0))]
	var definition: MmCardDefinition = vanilla("Life Land")
	definition.card_types = [MmCardTypes.CardType.LAND]
	definition.abilities = [ability]
	return definition


## A deck of [param land_count] copies of [param land] followed by [param spell_count]
## copies of [param spell_card].
static func deck_of(land: MmCardDefinition, land_count: int, spell_card: MmCardDefinition, spell_count: int) -> Array[MmCardDefinition]:
	var cards: Array[MmCardDefinition] = copies(land, land_count)
	cards.append_array(copies(spell_card, spell_count))
	return cards


## Tries Encounter Seeds from 1 upward until [param ready] returns true for the started
## engine, and returns that engine (or null). Keeps scenarios that need particular cards in
## hand deterministic without bypassing the shuffle.
static func find_engine(setup: MmEncounterSetup, ready: Callable, attempts: int = 300) -> MmEngine:
	for encounter_seed: int in range(1, attempts + 1):
		setup.encounter_seed = encounter_seed
		var engine: MmEngine = MmEngine.start(setup)
		if ready.call(engine):
			return engine
	return null


## Plays to the active player's main phase of [param game_turn], playing a land each turn
## including this one, and reports whether that player then controls at least
## [param lands] lands and holds a card named [param card_name].
static func ready_in_main(engine: MmEngine, game_turn: int, lands: int, card_name: String) -> bool:
	if play_until_step(engine, game_turn, MmTurn.Step.PRECOMBAT_MAIN, true) != "":
		return false
	play_first_land(engine)
	var active_id: int = engine.game_state().active_player_id
	var controlled: int = 0
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == active_id:
			controlled += 1
	return controlled >= lands and card_in_hand(engine, engine.game_state().player(active_id), card_name) != -1


## The object ID of the first card named [param card_name] in [param player]'s hand, or -1.
static func card_in_hand(engine: MmEngine, player: MmPlayer, card_name: String) -> int:
	for card: MmGameObject in player.hand.objects():
		if engine.game_state().characteristics_of(card).name == card_name:
			return card.id
	return -1


## The object ID of the first permanent [param player_id] controls, or -1.
static func first_permanent_of(engine: MmEngine, player_id: int) -> int:
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == player_id:
			return permanent.id
	return -1


static func cast_index(decision: PriorityDecision, object_id: int) -> int:
	return action_index(decision, func(action: MmAction) -> bool:
		return action is CastSpellAction and (action as CastSpellAction).object_id == object_id)


static func offers_cast(engine: MmEngine, object_id: int) -> bool:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	return decision != null and cast_index(decision, object_id) != -1


static func pass_priority(engine: MmEngine) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	return engine.submit(pass_index(decision))


## Chooses [param chosen] in the pending target decision.
static func choose_target(engine: MmEngine, chosen: MmReference) -> String:
	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	if decision == null:
		return "Not a target decision."
	for index: int in decision.candidates.size():
		if decision.candidates[index].equals(chosen):
			return engine.submit(index)
	return "%s is not a candidate." % chosen.describe()


## Pays one step of the pending payment with the first pool unit of [param type].
static func pay_with(engine: MmEngine, type: MmMana.Type) -> String:
	var decision: PayManaDecision = engine.pending_decision() as PayManaDecision
	if decision == null:
		return "Not a payment decision."
	var pool: Array[MmMana] = engine.game_state().player(decision.player_id).mana_pool()
	var index: int = action_index(decision_as_actions(decision), func(action: MmAction) -> bool:
		return action is PayWithManaAction and pool[(action as PayWithManaAction).unit_index].type == type)
	return "No %s unit can pay." % MmMana.Type.find_key(type) if index == -1 else engine.submit(index)


## Pays one step of the pending payment by activating a mana ability of [param object_id]
## (its ability number [param ability_index] among those offered for that object).
static func pay_by_tapping(engine: MmEngine, object_id: int, ability_index: int = -1) -> String:
	var decision: PayManaDecision = engine.pending_decision() as PayManaDecision
	if decision == null:
		return "Not a payment decision."
	var index: int = action_index(decision_as_actions(decision), func(action: MmAction) -> bool:
		var activate: ActivateAbilityAction = action as ActivateAbilityAction
		return activate != null and activate.object_id == object_id and (ability_index == -1 or activate.ability_index == ability_index))
	return "Object %d cannot pay." % object_id if index == -1 else engine.submit(index)


## Answers payment decisions until the cost is paid, using the first option each time.
static func auto_pay(engine: MmEngine) -> String:
	while engine.pending_decision() is PayManaDecision:
		var error: String = engine.submit(0)
		if error != "":
			return error
	return ""


## Casts [param object_id], choosing [param targets] in order, and pays automatically.
static func cast(engine: MmEngine, object_id: int, targets: Array[MmReference] = []) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = cast_index(decision, object_id)
	if index == -1:
		return "Object %d cannot be cast." % object_id
	var error: String = engine.submit(index)
	for chosen: MmReference in targets:
		if error != "":
			return error
		error = choose_target(engine, chosen)
	return error if error != "" else auto_pay(engine)


## A payment decision viewed as a priority-like list of actions, for action_index().
static func decision_as_actions(decision: PayManaDecision) -> PriorityDecision:
	return PriorityDecision.new(decision.player_id, decision.actions)


# --- Milestone 6: creatures and combat ----------------------------------------------


## A creature card costing [param cost] ({0} by default), with [param abilities].
static func creature(card_name: String, power: int, toughness: int, abilities: Array[MmAbility] = [],
		cost: MmManaCost = null) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla(card_name)
	definition.card_types = [MmCardTypes.CardType.CREATURE]
	definition.mana_cost = mana_cost(0) if cost == null else cost
	definition.power = power
	definition.toughness = toughness
	definition.abilities = abilities
	return definition


## A copy of [param definition] that costs {0}, so a scenario can cast it without lands.
static func free_copy(definition: MmCardDefinition) -> MmCardDefinition:
	var copy: MmCardDefinition = definition.duplicate(true) as MmCardDefinition
	copy.mana_cost = mana_cost(0)
	return copy


## Casts the card named [param card_name] from the priority holder's hand and lets it
## resolve. Returns the first rejection reason, or "".
static func cast_and_resolve(engine: MmEngine, card_name: String, targets: Array[MmReference] = []) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var card: int = card_in_hand(engine, engine.game_state().player(decision.player_id), card_name)
	if card == -1:
		return "No %s in hand." % card_name
	var error: String = cast(engine, card, targets)
	if error == "":
		error = pass_priority(engine)
	if error == "":
		error = pass_priority(engine)
	return error


## An Encounter Setup for combat_ready_with(): decks cycling through each player's creatures
## and extra cards.
static func combat_setup(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = [], villain_extras: Array[MmCardDefinition] = []) -> MmEncounterSetup:
	return setup_with(cycled(hero_creatures + hero_extras), cycled(villain_creatures + villain_extras))


## Finds a seed for [param combat] (from combat_setup()) where the Hero casts one of each of
## [param hero_creatures] on Game Turn 1 and the Villain one of each of
## [param villain_creatures] on Game Turn 2, then plays on to the first decision in the
## Hero's declare attackers step on Game Turn 3 with each player still holding their extra
## cards. Every card must cost {0}. Returns null if no seed deals the needed hands.
static func combat_ready_with(combat: MmEncounterSetup, hero_creatures: Array[MmCardDefinition],
		villain_creatures: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition] = [],
		villain_extras: Array[MmCardDefinition] = []) -> MmEngine:
	return permanents_ready_with(combat, hero_creatures, villain_creatures, hero_extras, villain_extras,
		3, MmTurn.Step.DECLARE_ATTACKERS)


## Like combat_ready_with(), but stops at the first decision of [param step] in
## [param game_turn] instead, which must come after the Villain's first main phase.
static func permanents_ready_with(combat: MmEncounterSetup, hero_creatures: Array[MmCardDefinition],
		villain_creatures: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_extras: Array[MmCardDefinition], game_turn: int, step: MmTurn.Step) -> MmEngine:
	return find_engine(combat, func(engine: MmEngine) -> bool:
		if play_until_step(engine, 1, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		for definition: MmCardDefinition in hero_creatures:
			if cast_and_resolve(engine, definition.name) != "":
				return false
		if play_until_step(engine, 2, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		for definition: MmCardDefinition in villain_creatures:
			if cast_and_resolve(engine, definition.name) != "":
				return false
		if play_until_step(engine, game_turn, step) != "":
			return false
		for definition: MmCardDefinition in hero_extras:
			if card_in_hand(engine, engine.hero(), definition.name) == -1:
				return false
		for definition: MmCardDefinition in villain_extras:
			if card_in_hand(engine, engine.villain(), definition.name) == -1:
				return false
		return true)


## combat_ready_with() on a fresh combat_setup().
static func combat_ready(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = [], villain_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var combat: MmEncounterSetup = combat_setup(hero_creatures, villain_creatures, hero_extras, villain_extras)
	return combat_ready_with(combat, hero_creatures, villain_creatures, hero_extras, villain_extras)


## Passes priority until the defending player must declare blockers. Returns "" once there.
static func pass_to_blockers(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is DeclareBlockersDecision)


## An instant costing {0}: "Exile target creature." Test-only (see exile_test_effect.gd).
static func exile_spell(card_name: String) -> MmCardDefinition:
	var creature_filter: HasCardTypeFilter = HasCardTypeFilter.new()
	creature_filter.card_type = MmCardTypes.CardType.CREATURE
	var effect: ExileTestEffect = ExileTestEffect.new()
	effect.recipients = targeted(0)
	return instant(card_name, mana_cost(0), [target(creature_filter)], [effect])


## An instant costing {0}: "[param amount] damage to any target."
static func free_shock(card_name: String, amount: int) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [any_target()], [deal_damage(amount, targeted(0))])


## The IDs of the permanents named [param card_name] that [param player_id] controls, in ID
## order.
static func permanents_named(engine: MmEngine, player_id: int, card_name: String) -> Array[int]:
	var result: Array[int] = []
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == player_id and engine.game_state().characteristics_of(permanent).name == card_name:
			result.append(permanent.id)
	result.sort()
	return result


## The ID of the first permanent named [param card_name] that [param player_id] controls,
## or -1.
static func permanent_named(engine: MmEngine, player_id: int, card_name: String) -> int:
	var found: Array[int] = permanents_named(engine, player_id, card_name)
	return -1 if found.is_empty() else found[0]


static func declare_attackers(engine: MmEngine, attacker_ids: Array[int]) -> String:
	if not engine.pending_decision() is DeclareAttackersDecision:
		return "Not an attackers decision."
	return engine.submit(attacker_ids)


## Declares blocks given as [blocker ID, attacker ID] pairs.
static func declare_blockers(engine: MmEngine, pairs: Array) -> String:
	if not engine.pending_decision() is DeclareBlockersDecision:
		return "Not a blockers decision."
	return engine.submit(pairs)


## Passes priority (and answers combat decisions with nothing) until [param step] of the
## current Game Turn has begun and its first decision is pending.
static func pass_until_step(engine: MmEngine, step: MmTurn.Step) -> String:
	return play_until_step(engine, engine.game_state().game_turn, step)


## A legal division of combat damage: everything on the first recipient.
static func all_to_first(decision: DivideCombatDamageDecision) -> Array[int]:
	var amounts: Array[int] = []
	for index: int in decision.recipients.size():
		amounts.append(decision.amount if index == 0 else 0)
	return amounts


static func damage_on(engine: MmEngine, object_id: int) -> int:
	return engine.game_state().object(object_id).damage_marked


## Every combat DamageEvent in the log, in order.
static func combat_damage_events(engine: MmEngine) -> Array[DamageEvent]:
	var result: Array[DamageEvent] = []
	for event: MmEvent in engine.event_log():
		var damage: DamageEvent = event as DamageEvent
		if damage != null and damage.is_combat:
			result.append(damage)
	return result


## A 40-card deck cycling through [param definitions], or 40 vanilla cards if it is empty.
static func cycled(definitions: Array[MmCardDefinition]) -> Array[MmCardDefinition]:
	var deck_cards: Array[MmCardDefinition] = []
	if definitions.is_empty():
		return copies(vanilla("Card"), 40)
	for index: int in 40:
		deck_cards.append(definitions[index % definitions.size()])
	return deck_cards


# --- Milestone 7: state-based actions and the end of an encounter ------------------


## An instant costing {0}: "[param amount] damage to each player."
static func damage_each_player(card_name: String, amount: int) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [], [deal_damage(amount, each(IsPlayerFilter.new()))])


## An instant costing {0}: "Target player draws [param amount] cards."
static func free_draw(card_name: String, amount: int) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target_player()], [draw_cards(amount, targeted(0))])


## Plays on with autoplay() defaults until the encounter is over.
static func play_until_over(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.is_over())


## The zone-change reason of the last card to enter [param zone].
static func last_reason_into(engine: MmEngine, zone_kind: MmZone.Kind) -> ZoneChangeEvent.Reason:
	var reason: ZoneChangeEvent.Reason = ZoneChangeEvent.Reason.DRAW
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.to_zone_kind == zone_kind:
			reason = moved.reason
	return reason


## Every event of [param kind] in the log, in order.
static func events_of(engine: MmEngine, kind: Script) -> Array[MmEvent]:
	var result: Array[MmEvent] = []
	for event: MmEvent in engine.event_log():
		if is_instance_of(event, kind):
			result.append(event)
	return result


# --- Milestone 8: triggered abilities -------------------------------------------------


## An artifact costing {0} with [param abilities].
static func artifact(card_name: String, abilities: Array[MmAbility]) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla(card_name)
	definition.card_types = [MmCardTypes.CardType.ARTIFACT]
	definition.mana_cost = mana_cost(0)
	definition.abilities = abilities
	return definition


## An Emblem: abilities and nothing else.
static func emblem(emblem_name: String, abilities: Array[MmAbility]) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla(emblem_name)
	definition.abilities = abilities
	return definition


static func triggered(trigger: MmTrigger, effects: Array[MmEffect], targets: Array[TargetSpec] = [],
		condition: MmCondition = null) -> TriggeredAbility:
	var ability: TriggeredAbility = TriggeredAbility.new()
	ability.trigger = trigger
	ability.effects = effects
	ability.targets = targets
	ability.condition = condition
	return ability


## "At the beginning of [whose] [step]".
static func at_step(step: MmTurn.Step, whose: MmTrigger.Whose) -> StepBeganTrigger:
	var trigger: StepBeganTrigger = StepBeganTrigger.new()
	trigger.step = step
	trigger.whose = whose
	return trigger


## "Whenever a [filter] [whose] enters the battlefield".
static func enters(filter: MmFilter, whose: MmTrigger.Whose = MmTrigger.Whose.ANY) -> ZoneChangeTrigger:
	var trigger: ZoneChangeTrigger = ZoneChangeTrigger.new()
	trigger.to_zone = MmZone.Kind.BATTLEFIELD
	trigger.filter = filter
	trigger.whose = whose
	return trigger


## "Whenever a [filter] dies": from the battlefield to a graveyard (CR 700.4).
static func dies(filter: MmFilter) -> ZoneChangeTrigger:
	var trigger: ZoneChangeTrigger = ZoneChangeTrigger.new()
	trigger.any_from_zone = false
	trigger.from_zone = MmZone.Kind.BATTLEFIELD
	trigger.to_zone = MmZone.Kind.GRAVEYARD
	trigger.filter = filter
	return trigger


## "Whenever [whose] casts a [filter] spell".
static func casts(filter: MmFilter, whose: MmTrigger.Whose) -> SpellCastTrigger:
	var trigger: SpellCastTrigger = SpellCastTrigger.new()
	trigger.filter = filter
	trigger.whose = whose
	return trigger


static func of_type(card_type: MmCardTypes.CardType) -> HasCardTypeFilter:
	var filter: HasCardTypeFilter = HasCardTypeFilter.new()
	filter.card_type = card_type
	return filter


static func you() -> YouSelection:
	return YouSelection.new()


static func lose_life(amount: int, players: MmSelection) -> LoseLifeEffect:
	var effect: LoseLifeEffect = LoseLifeEffect.new()
	effect.amount = constant(amount)
	effect.players = players
	return effect


static func controller_of(selection: MmSelection) -> ControllerOfSelection:
	var controller: ControllerOfSelection = ControllerOfSelection.new()
	controller.selection = selection
	return controller


## "if [selection] is [filter]", as an intervening "if" clause (CR 603.4).
static func condition(selection: MmSelection, filter: MmFilter) -> SelectionMatchesCondition:
	var result: SelectionMatchesCondition = SelectionMatchesCondition.new()
	result.selection = selection
	result.filter = filter
	return result


static func untapped() -> NotFilter:
	var filter: NotFilter = NotFilter.new()
	filter.filter = IsTappedFilter.new()
	return filter


## The triggered abilities on the stack, bottom first.
static func stacked_abilities(engine: MmEngine) -> Array[MmGameObject]:
	var result: Array[MmGameObject] = []
	for item: MmGameObject in engine.game_state().stack.objects():
		if item.ability is TriggeredAbility:
			result.append(item)
	return result


## Passes priority until the stack is empty, answering any other decision with autoplay()
## defaults.
static func resolve_stack(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool:
		return running.game_state().stack.is_empty() and running.pending_decision() is PriorityDecision \
			and running.game_state().pending_triggers.is_empty())


# --- Milestone 9: static abilities and layers ----------------------------------------


static func continuous_static(effects: Array[MmContinuousEffect]) -> ContinuousStaticAbility:
	var ability: ContinuousStaticAbility = ContinuousStaticAbility.new()
	ability.effects = effects
	return ability


## Layer 7c: "[affected] get(s) +[power]/+[toughness]".
static func modify_pt(power: int, toughness: int, affected: MmSelection) -> ModifyPowerToughnessContinuousEffect:
	var effect: ModifyPowerToughnessContinuousEffect = ModifyPowerToughnessContinuousEffect.new()
	effect.power = constant(power)
	effect.toughness = constant(toughness)
	effect.affected = affected
	return effect


## Layer 7b: "[affected] has base power and toughness [power]/[toughness]".
static func set_pt(power: int, toughness: int, affected: MmSelection) -> SetPowerToughnessContinuousEffect:
	var effect: SetPowerToughnessContinuousEffect = SetPowerToughnessContinuousEffect.new()
	effect.power = constant(power)
	effect.toughness = constant(toughness)
	effect.affected = affected
	return effect


## Layer 6: "[affected] gain(s) [abilities]".
static func gain_abilities(abilities: Array[MmAbility], affected: MmSelection) -> GainAbilitiesContinuousEffect:
	var effect: GainAbilitiesContinuousEffect = GainAbilitiesContinuousEffect.new()
	effect.abilities = abilities
	effect.affected = affected
	return effect


## Layer 6: "[affected] lose(s) all abilities".
static func lose_all_abilities(affected: MmSelection) -> LoseAllAbilitiesContinuousEffect:
	var effect: LoseAllAbilitiesContinuousEffect = LoseAllAbilitiesContinuousEffect.new()
	effect.affected = affected
	return effect


## "[continuous] until end of turn", as a one-shot effect.
static func until_end_of_turn(continuous: MmContinuousEffect) -> CreateContinuousEffect:
	var effect: CreateContinuousEffect = CreateContinuousEffect.new()
	effect.continuous = continuous
	effect.duration = CreateContinuousEffect.Duration.UNTIL_END_OF_TURN
	return effect


## An instant costing {0}: "Target creature [continuous] until end of turn", where
## [param continuous] affects targeted(0).
static func creature_spell_until_end_of_turn(card_name: String, continuous: MmContinuousEffect) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))], [until_end_of_turn(continuous)])


## An instant costing {0}: "Target creature gets +[power]/+[toughness] until end of turn."
static func pump_spell(card_name: String, power: int, toughness: int) -> MmCardDefinition:
	return creature_spell_until_end_of_turn(card_name, modify_pt(power, toughness, targeted(0)))


static func has_subtype(subtype: String) -> HasSubtypeFilter:
	var filter: HasSubtypeFilter = HasSubtypeFilter.new()
	filter.subtype = subtype
	return filter


static func all_of(filters: Array[MmFilter]) -> AllOfFilter:
	var filter: AllOfFilter = AllOfFilter.new()
	filter.filters = filters
	return filter


static func is_not(filter: MmFilter) -> NotFilter:
	var negated: NotFilter = NotFilter.new()
	negated.filter = filter
	return negated


## Every creature matching [param filter], or every creature.
static func each_creature(filter: MmFilter = null) -> EachSelection:
	var creature: MmFilter = of_type(MmCardTypes.CardType.CREATURE)
	return each(creature if filter == null else all_of([creature, filter]))


## The current characteristics of [param object_id].
static func now(engine: MmEngine, object_id: int) -> MmCharacteristics:
	return engine.game_state().characteristics_of(engine.game_state().object(object_id))


## [power, toughness] of [param object_id] right now.
static func pt(engine: MmEngine, object_id: int) -> Array[int]:
	var characteristics: MmCharacteristics = now(engine, object_id)
	return [characteristics.power, characteristics.toughness]


# --- Milestone 10: replacement and prevention effects ---------------------------------


## "Prevent the next [param amount] damage that would be dealt to [param recipients] this
## turn."
static func prevent_next(amount: int, recipients: MmSelection) -> PreventDamageEffect:
	var effect: PreventDamageEffect = PreventDamageEffect.new()
	effect.uses = PreventDamageEffect.Uses.NEXT_AMOUNT
	effect.amount = constant(amount)
	effect.recipients = recipients
	return effect


## "Prevent all [combat] damage that would be dealt [to recipients] [by sources] this
## turn." A null [param recipients] or [param sources] means any.
static func prevent_all(recipients: MmSelection, combat_only: bool, sources: MmFilter = null) -> PreventDamageEffect:
	var effect: PreventDamageEffect = PreventDamageEffect.new()
	effect.uses = PreventDamageEffect.Uses.ALL_THIS_TURN
	effect.recipients = recipients
	effect.combat_only = combat_only
	effect.sources = sources
	return effect


## An instant costing {0}: "Prevent all combat damage that would be dealt this turn."
static func free_fog(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [], [prevent_all(null, true)])


## An instant costing {0}: "Prevent the next [param amount] damage that would be dealt to
## any target this turn."
static func free_shield(card_name: String, amount: int) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [any_target()], [prevent_next(amount, targeted(0))])


## A 1/1 creature costing {0}: "{T}: Prevent the next 1 damage that would be dealt to any
## target this turn."
static func healer(card_name: String) -> MmCardDefinition:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.targets = [any_target()]
	ability.effects = [prevent_next(1, targeted(0))]
	return creature(card_name, 1, 1, [ability])


## Protection from whatever [param filter] matches (CR 702.16).
static func protection_from(filter: MmFilter) -> ProtectionAbility:
	var ability: ProtectionAbility = ProtectionAbility.new()
	ability.from = filter
	return ability


static func of_color(color: MmCardTypes.CardColor) -> HasColorFilter:
	var filter: HasColorFilter = HasColorFilter.new()
	filter.color = color
	return filter


static func regenerate(selection: MmSelection) -> RegenerateEffect:
	var effect: RegenerateEffect = RegenerateEffect.new()
	effect.selection = selection
	return effect


## "[param cost]: Regenerate this creature."
static func regenerate_ability(cost: MmManaCost) -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = cost
	ability.effects = [regenerate(SourceSelection.new())]
	return ability


## An instant costing {0}: "Regenerate target creature."
static func free_regenerate(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))], [regenerate(targeted(0))])


static func destroy(selection: MmSelection, can_be_regenerated: bool = true) -> DestroyEffect:
	var effect: DestroyEffect = DestroyEffect.new()
	effect.selection = selection
	effect.can_be_regenerated = can_be_regenerated
	return effect


## An instant costing {0}: "Destroy target creature.", with "It can't be regenerated." when
## [param can_be_regenerated] is false.
static func free_destroy(card_name: String, can_be_regenerated: bool = true) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))],
		[destroy(targeted(0), can_be_regenerated)])


## Activates the first ability of [param object_id] offered, choosing [param targets] in
## order, and pays automatically.
static func activate(engine: MmEngine, object_id: int, targets: Array[MmReference] = []) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = activate_index(decision, object_id)
	if index == -1:
		return "Object %d has no ability to activate." % object_id
	var error: String = engine.submit(index)
	for chosen: MmReference in targets:
		if error != "":
			return error
		error = choose_target(engine, chosen)
	return error if error != "" else auto_pay(engine)


## Chooses the option of the pending replacement decision whose source has Card Identity
## [param source_card_id].
static func choose_replacement_from(engine: MmEngine, source_card_id: int) -> String:
	var decision: ChooseReplacementEffectDecision = engine.pending_decision() as ChooseReplacementEffectDecision
	if decision == null:
		return "Not a replacement decision."
	for index: int in decision.options.size():
		if decision.options[index].source_card_id == source_card_id:
			return engine.submit(index)
	return "No option comes from card %d." % source_card_id


## Passes priority until [param step] of the current Game Turn begins, like
## pass_until_step(), but stops early at any replacement decision. Returns whether it
## reached the step without one being asked.
static func pass_until_step_without_replacement_choice(engine: MmEngine, step: MmTurn.Step) -> bool:
	var game_turn: int = engine.game_state().game_turn
	autoplay(engine, func(running: MmEngine) -> bool:
		if running.pending_decision() is ChooseReplacementEffectDecision:
			return true
		return running.game_state().game_turn == game_turn and running.game_state().step == step)
	return not engine.pending_decision() is ChooseReplacementEffectDecision


## Passes priority until a replacement decision is pending. Returns "" once there.
static func pass_to_replacement_choice(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is ChooseReplacementEffectDecision)


## Every DamagePreventedEvent in the log, in order.
static func prevented(engine: MmEngine) -> Array[MmEvent]:
	return events_of(engine, DamagePreventedEvent)


## The Card Identity of the permanent [param object_id].
static func card_of(engine: MmEngine, object_id: int) -> int:
	return engine.game_state().object(object_id).card_id
