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
## play first, keep, pass priority, bottom or discard the first candidates offered, attack
## and block with nothing, put all combat damage on the first recipient, stack triggers in
## the order offered, choose the first target and replacement effect offered, and as many
## of the first targets offered as an "up to" requirement allows.
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
	if decision is ChooseCardsInLibraryDecision:
		var search: ChooseCardsInLibraryDecision = decision as ChooseCardsInLibraryDecision
		return search.candidate_ids.slice(0, search.most)
	if decision is ChoosePermanentsDecision:
		var pick: ChoosePermanentsDecision = decision as ChoosePermanentsDecision
		return pick.candidate_ids.slice(0, pick.count)
	if decision is ChooseTargetsDecision:
		var targeting: ChooseTargetsDecision = decision as ChooseTargetsDecision
		return range(mini(targeting.most, targeting.candidates.size()))
	if decision is ChoosePlayOrDrawDecision:
		return ChoosePlayOrDrawDecision.Choice.PLAY
	if decision is ChooseYesOrNoDecision:
		# A cost asked for, as ward's or as a land enters, is declined, as an X is: autoplay
		# pays nothing.
		var paying: bool = (decision as ChooseYesOrNoDecision).cost != null or (decision as ChooseYesOrNoDecision).entry_cost != null
		return ChooseYesOrNoDecision.Choice.NO if paying else ChooseYesOrNoDecision.Choice.YES
	if decision is ChooseXToPayDecision:
		return ChooseXToPayDecision.DECLINE
	if decision is SurveilDecision:
		return [[], (decision as SurveilDecision).card_ids.duplicate()]  # Every card kept, in order.
	if decision is DeclareAttackersDecision or decision is DeclareBlockersDecision:
		return []
	if decision is DivideCombatDamageDecision:
		return all_to_first(decision as DivideCombatDamageDecision)
	if decision is OrderTriggersDecision:
		return range((decision as OrderTriggersDecision).source_object_ids.size())
	if decision is ChooseTargetDecision or decision is ChooseReplacementEffectDecision or decision is ChooseObjectDecision \
			or decision is ChooseModeDecision or decision is ChooseLegendToKeepDecision \
			or decision is ChooseCreatureTypeDecision:
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


static func target(filter: MmFilter) -> TargetRequirement:
	var requirement: TargetRequirement = TargetRequirement.new()
	requirement.filter = filter
	return requirement


## "Any target": a creature or a player (there are no planeswalkers, ADR 0001).
static func any_target() -> TargetRequirement:
	var creature: HasCardTypeFilter = HasCardTypeFilter.new()
	creature.card_type = MmCardTypes.CardType.CREATURE
	var either: AnyOfFilter = AnyOfFilter.new()
	either.filters = [IsPlayerFilter.new(), creature]
	return target(either)


static func target_player() -> TargetRequirement:
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


## "[players] may play [amount] additional lands this turn."
static func additional_land_plays(amount: int, players: MmSelection) -> AdditionalLandPlaysEffect:
	var effect: AdditionalLandPlaysEffect = AdditionalLandPlaysEffect.new()
	effect.count = constant(amount)
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
		targets: Array[TargetRequirement], effects: Array[MmEffect]) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla(card_name)
	definition.card_types = [card_type]
	definition.mana_cost = cost
	var ability: SpellAbility = SpellAbility.new()
	ability.targets = targets
	ability.effects = effects
	definition.abilities = [ability]
	return definition


static func instant(card_name: String, cost: MmManaCost, targets: Array[TargetRequirement], effects: Array[MmEffect]) -> MmCardDefinition:
	return spell(card_name, MmCardTypes.CardType.INSTANT, cost, targets, effects)


static func sorcery(card_name: String, cost: MmManaCost, targets: Array[TargetRequirement], effects: Array[MmEffect]) -> MmCardDefinition:
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
## cards. Every card must cost {0}, and an ability that triggers as a creature arrives
## resolves before the next is cast. Returns null if no seed deals the needed hands.
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
			if cast_and_resolve(engine, definition.name) != "" or resolve_stack(engine) != "":
				return false
		if play_until_step(engine, 2, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		for definition: MmCardDefinition in villain_creatures:
			if cast_and_resolve(engine, definition.name) != "" or resolve_stack(engine) != "":
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


## An instant costing {0}: "Exile target creature."
static func exile_spell(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))], [exile(targeted(0))])


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


static func triggered(trigger: MmTrigger, effects: Array[MmEffect], targets: Array[TargetRequirement] = [],
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


## "[effects]", or "As long as [condition], [effects]".
static func continuous_static(effects: Array[MmContinuousEffect], condition: MmCondition = null) -> ContinuousStaticAbility:
	var ability: ContinuousStaticAbility = ContinuousStaticAbility.new()
	ability.effects = effects
	ability.condition = condition
	return ability


## Layer 4: "[affected] is a [subtypes] in addition to its other types".
static func add_subtypes(subtypes: Array[String], affected: MmSelection) -> AddSubtypesContinuousEffect:
	var effect: AddSubtypesContinuousEffect = AddSubtypesContinuousEffect.new()
	effect.subtypes = subtypes
	effect.affected = affected
	return effect


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


static func any_of(filters: Array[MmFilter]) -> AnyOfFilter:
	var filter: AnyOfFilter = AnyOfFilter.new()
	filter.filters = filters
	return filter


## "Attacking or blocking creature": AllOf(creature, AnyOf(attacking, blocking)).
static func attacking_or_blocking_creature() -> AllOfFilter:
	return all_of([of_type(MmCardTypes.CardType.CREATURE), any_of([IsAttackingFilter.new(), IsBlockingFilter.new()])])


## Outflank as an instant costing {0}: "[param card_name] deals damage to target attacking
## or blocking creature equal to the number of creatures you control."
static func free_outflank(card_name: String) -> MmCardDefinition:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var count: CountValue = CountValue.new()
	count.selection = each_creature(mine)
	var damage: DealDamageEffect = deal_damage(0, targeted(0))
	damage.amount = count
	return instant(card_name, mana_cost(0), [target(attacking_or_blocking_creature())], [damage])


## "[addends[0]] plus [addends[1]] plus ...".
static func sum(addends: Array[MmValue]) -> SumValue:
	var value: SumValue = SumValue.new()
	value.addends = addends
	return value


## "The number of [filter] you control".
static func count_yours(filter: MmFilter) -> CountValue:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var count: CountValue = CountValue.new()
	count.selection = each(all_of([filter, mine]))
	return count


## Slash of Light as an instant costing {0}: "[param card_name] deals damage to target
## creature equal to the number of creatures you control plus the number of Equipment you
## control."
static func free_slash(card_name: String = "Slash") -> MmCardDefinition:
	var damage: DealDamageEffect = deal_damage(0, targeted(0))
	damage.amount = sum([count_yours(of_type(MmCardTypes.CardType.CREATURE)), count_yours(has_subtype("Equipment"))])
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))], [damage])


## An artifact creature Equipment costing {0}, such as Lion Sash: counted both as a creature
## and as an Equipment.
static func equipment_creature(card_name: String, power: int, toughness: int) -> MmCardDefinition:
	var definition: MmCardDefinition = creature(card_name, power, toughness, [equip(mana_cost(0))])
	definition.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	definition.subtypes = ["Equipment"]
	return definition


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


# --- Milestone 13d: countering spells -------------------------------------------------


## "Target spell", or "target [filter] spell".
static func target_spell(filter: MmFilter = null) -> TargetRequirement:
	var requirement: TargetRequirement = target(filter)
	requirement.among = TargetRequirement.Among.SPELLS
	return requirement


static func counter(selection: MmSelection) -> CounterEffect:
	var effect: CounterEffect = CounterEffect.new()
	effect.selection = selection
	return effect


## An instant costing {0}: "Counter target spell."
static func free_counter(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target_spell()], [counter(targeted(0))])


## The IDs of everything on the stack, top first.
static func stack_ids(engine: MmEngine) -> Array[int]:
	var ids: Array[int] = []
	for item: MmGameObject in engine.game_state().stack.objects():
		ids.push_front(item.id)
	return ids


# --- Milestone 13f: graveyard targets and countering abilities -------------------------


## "Target card in a graveyard", or "target [filter] card in a graveyard".
static func target_graveyard_card(filter: MmFilter = null) -> TargetRequirement:
	var requirement: TargetRequirement = target(filter)
	requirement.among = TargetRequirement.Among.GRAVEYARD_CARDS
	return requirement


## "Target activated or triggered ability".
static func target_ability() -> TargetRequirement:
	var requirement: TargetRequirement = target(null)
	requirement.among = TargetRequirement.Among.ABILITIES
	return requirement


static func owned_by(whose: MmTrigger.Whose) -> OwnedByFilter:
	var filter: OwnedByFilter = OwnedByFilter.new()
	filter.whose = whose
	return filter


static func return_to_hand(selection: MmSelection) -> ReturnToHandEffect:
	var effect: ReturnToHandEffect = ReturnToHandEffect.new()
	effect.selection = selection
	return effect


## An instant costing {0}: "Return target creature to its owner's hand."
static func free_bounce(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))], [return_to_hand(targeted(0))])


## "Tap [param selection]."
static func tap(selection: MmSelection) -> TapEffect:
	var effect: TapEffect = TapEffect.new()
	effect.selection = selection
	return effect


## An instant costing {0}: "Tap target creature."
static func free_tap(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))], [tap(targeted(0))])


## "A [param filter]", chosen as the effect resolves (CR 608.2d), as choice [param index].
static func chosen(filter: MmFilter, index: int = 0) -> ChosenSelection:
	var selection: ChosenSelection = ChosenSelection.new()
	selection.filter = filter
	selection.choice_index = index
	return selection


## Passes priority and answers everything else as autoplay() does, until a choice made on
## resolution is asked.
static func pass_to_choice(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is ChooseObjectDecision)


## "Target creature card in your graveyard."
static func your_dead_creature() -> TargetRequirement:
	return target_graveyard_card(all_of([of_type(MmCardTypes.CardType.CREATURE), owned_by(MmTrigger.Whose.YOU)]))


## An instant costing {0}: "Return target creature card from your graveyard to your hand."
## An instant, unlike Raise Dead, so that a test can answer one with another.
static func free_raise(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [your_dead_creature()], [return_to_hand(targeted(0))])


## "With mana value [param amount] or less", or "or greater" (CR 202.3).
static func mana_value(amount: int, comparison: ManaValueFilter.Comparison = ManaValueFilter.Comparison.OR_LESS) -> ManaValueFilter:
	var filter: ManaValueFilter = ManaValueFilter.new()
	filter.amount = amount
	filter.comparison = comparison
	return filter


## "With mana value X or less", or "or greater", X being [param value] as the Filter is
## asked, such as the X paid (CR 202.3).
static func mana_value_from(value: MmValue, comparison: ManaValueFilter.Comparison = ManaValueFilter.Comparison.OR_LESS) -> ManaValueFilter:
	var filter: ManaValueFilter = ManaValueFilter.new()
	filter.amount_value = value
	filter.comparison = comparison
	return filter


## An instant costing {0}: "Return target creature card from your graveyard to the
## battlefield", "tapped" with [param tapped]. Helping Hand is this with a mana value filter.
static func free_reanimate(card_name: String, tapped: bool = false) -> MmCardDefinition:
	var back: ReturnToBattlefieldEffect = return_to_battlefield(targeted(0))
	back.tapped = tapped
	return instant(card_name, mana_cost(0), [your_dead_creature()], [back])


## An instant costing {0}: "Counter target activated or triggered ability."
static func free_stifle(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target_ability()], [counter(targeted(0))])


## "Permanent card" (CR 110.4a).
static func permanent_card() -> IsPermanentFilter:
	return IsPermanentFilter.new()


## "If [param condition], [param effect]."
static func if_then(condition: MmCondition, effect: MmEffect) -> IfEffect:
	var conditional: IfEffect = IfEffect.new()
	conditional.condition = condition
	conditional.effect = effect
	return conditional


## A 1/1 creature costing {0}, after Lion Sash's first ability at {0}: "{0}: Exile target
## card from a graveyard. If it is a permanent card, put a +1/+1 counter on this creature."
## What it exiles is not linked to it.
static func scavenger(card_name: String = "Scavenger") -> MmCardDefinition:
	var exiling: ExileEffect = exile(targeted(0))
	exiling.links_to_source = false
	var was_permanent: SelectionMatchesCondition = SelectionMatchesCondition.new()
	was_permanent.selection = targeted(0)
	was_permanent.filter = permanent_card()
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = mana_cost(0)
	ability.targets = [target_graveyard_card()]
	ability.effects = [exiling, if_then(was_permanent, put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, SourceSelection.new()))]
	return creature(card_name, 1, 1, [ability])


## The object ID of the first card named [param card_name] in [param player]'s graveyard,
## or -1.
static func card_in_graveyard(engine: MmEngine, player: MmPlayer, card_name: String) -> int:
	for card: MmGameObject in player.graveyard.objects():
		if engine.game_state().characteristics_of(card).name == card_name:
			return card.id
	return -1


# --- Counters -------------------------------------------------------------------------


## "Put [param amount] [param kind] counters on [param recipients]."
static func put_counters(kind: MmCounter.Kind, amount: int, recipients: MmSelection) -> PutCountersEffect:
	var effect: PutCountersEffect = PutCountersEffect.new()
	effect.kind = kind
	effect.amount = constant(amount)
	effect.recipients = recipients
	return effect


## An instant costing {0}: "Put [param amount] [param kind] counters on target creature."
static func free_counters(card_name: String, kind: MmCounter.Kind, amount: int) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))],
		[put_counters(kind, amount, targeted(0))])


## "The number of [param kind] counters on [param selection]".
static func counters_of(kind: MmCounter.Kind, selection: MmSelection) -> CounterCountValue:
	var value: CounterCountValue = CounterCountValue.new()
	value.kind = kind
	value.selection = selection
	return value


## How many [param kind] counters are on the permanent [param object_id].
static func counters_on(engine: MmEngine, object_id: int, kind: MmCounter.Kind) -> int:
	return engine.game_state().object(object_id).counters_of(kind)


## "With [param at_least] or more [param kind] counters on it."
static func has_counters(kind: MmCounter.Kind, at_least: int) -> HasCountersFilter:
	var filter: HasCountersFilter = HasCountersFilter.new()
	filter.kind = kind
	filter.at_least = at_least
	return filter


## "Originally named [param card_name]."
static func named(card_name: String) -> HasOriginalNameFilter:
	var filter: HasOriginalNameFilter = HasOriginalNameFilter.new()
	filter.original_name = card_name
	return filter


# --- Exile and linked abilities --------------------------------------------------------


## An enchantment costing {0} with [param abilities].
static func enchantment(card_name: String, abilities: Array[MmAbility]) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla(card_name)
	definition.card_types = [MmCardTypes.CardType.ENCHANTMENT]
	definition.mana_cost = mana_cost(0)
	definition.abilities = abilities
	return definition


static func exile(selection: MmSelection) -> ExileEffect:
	var effect: ExileEffect = ExileEffect.new()
	effect.selection = selection
	return effect


static func return_to_battlefield(selection: MmSelection) -> ReturnToBattlefieldEffect:
	var effect: ReturnToBattlefieldEffect = ReturnToBattlefieldEffect.new()
	effect.selection = selection
	return effect


## "Whenever a [filter] leaves the battlefield": from the battlefield to anywhere.
static func leaves(filter: MmFilter) -> ZoneChangeTrigger:
	var trigger: ZoneChangeTrigger = ZoneChangeTrigger.new()
	trigger.any_from_zone = false
	trigger.from_zone = MmZone.Kind.BATTLEFIELD
	trigger.any_to_zone = true
	trigger.filter = filter
	return trigger


## "Another target nonland permanent": not a player, not the source, not a land.
static func another_nonland_permanent() -> TargetRequirement:
	return target(all_of([is_not(IsPlayerFilter.new()), is_not(IsSourceFilter.new()),
		is_not(of_type(MmCardTypes.CardType.LAND))]))


## An enchantment costing {0} with Oblivion Ring's two linked abilities: "When this
## enchantment enters, exile another target nonland permanent. When this enchantment leaves
## the battlefield, return the exiled card to the battlefield under its owner's control."
static func free_prison(card_name: String) -> MmCardDefinition:
	return enchantment(card_name, [
		triggered(enters(IsSourceFilter.new()), [exile(targeted(0))], [another_nonland_permanent()]),
		triggered(leaves(IsSourceFilter.new()), [return_to_battlefield(ExiledWithSourceSelection.new())]),
	])


## "Exile [param selection] until this permanent leaves the battlefield" (CR 610.3).
static func exile_until(selection: MmSelection) -> ExileEffect:
	var effect: ExileEffect = exile(selection)
	effect.until_source_leaves = true
	return effect


## An enchantment costing {0} with Leyline Binding's trigger: "When this enchantment enters,
## exile target nonland permanent an opponent controls until this enchantment leaves the
## battlefield." With [param aimed] the target is that instead.
static func free_binding(card_name: String, aimed: TargetRequirement = null) -> MmCardDefinition:
	var theirs: ControlledByFilter = ControlledByFilter.new()
	theirs.whose = MmTrigger.Whose.OPPONENT
	var requirement: TargetRequirement = aimed if aimed != null else \
		target(all_of([is_not(IsPlayerFilter.new()), is_not(of_type(MmCardTypes.CardType.LAND)), theirs]))
	return enchantment(card_name, [triggered(enters(IsSourceFilter.new()), [exile_until(targeted(0))], [requirement])])


## An instant costing {0}: "Destroy target enchantment."
static func free_disenchant(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.ENCHANTMENT))],
		[destroy(targeted(0))])


## The IDs of the cards [param player] owns in exile, in the zone's order.
static func exiled_by_owner(engine: MmEngine, player: MmPlayer) -> Array[int]:
	var ids: Array[int] = []
	for card: MmGameObject in engine.game_state().exile.objects():
		if card.owner_id == player.id:
			ids.append(card.id)
	return ids


# --- Card track: Equipment -------------------------------------------------------------


## "Equipped creature": what the ability's source is attached to.
static func attached() -> AttachedToSelection:
	return AttachedToSelection.new()


## "Equip [cost]".
static func equip(cost: MmManaCost) -> EquipAbility:
	var ability: EquipAbility = EquipAbility.new()
	ability.mana_cost = cost
	return ability


## "You may activate equip abilities any time you could cast an instant."
static func instant_speed_equip() -> InstantSpeedEquipAbility:
	return InstantSpeedEquipAbility.new()


## An Equipment costing {0}: "Equipped creature gets +[bonus]/+[bonus]. Equip [equip_cost]",
## with equip costing {0} unless [param equip_cost] is given.
static func sword(card_name: String, bonus: int = 1, equip_cost: MmManaCost = null) -> MmCardDefinition:
	var definition: MmCardDefinition = artifact(card_name, [
		continuous_static([modify_pt(bonus, bonus, attached())]),
		equip(mana_cost(0) if equip_cost == null else equip_cost)])
	definition.subtypes = ["Equipment"]
	return definition


## "Reconfigure [cost]": its two abilities, attaching and then unattaching (CR 702.151a).
static func reconfigure(cost: MmManaCost) -> Array[MmAbility]:
	var attach: ReconfigureAbility = ReconfigureAbility.new()
	attach.mana_cost = cost
	var unattach: ReconfigureAbility = ReconfigureAbility.new()
	unattach.mana_cost = cost.duplicate()
	unattach.unattaches = true
	return [attach, unattach]


## A 1/1 artifact creature Equipment Cat costing {0}, after Lion Sash: "Equipped creature
## gets +[bonus]/+[bonus]. Reconfigure {0}". Its abilities are the bonus, then
## reconfigure's two.
static func sash(card_name: String = "Sash", bonus: int = 1) -> MmCardDefinition:
	var abilities: Array[MmAbility] = [continuous_static([modify_pt(bonus, bonus, attached())])]
	abilities.append_array(reconfigure(mana_cost(0)))
	var definition: MmCardDefinition = creature(card_name, 1, 1, abilities)
	definition.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	definition.subtypes = ["Equipment", "Cat"]
	return definition


## Lion Sash's static ability and reconfigure at {0}, on a 1/1 artifact creature Equipment
## Cat costing {0}: "Equipped creature gets +X/+X, where X is the number of +1/+1 counters
## on this permanent. Reconfigure {0}".
static func lion_sash(card_name: String = "Lion Sash") -> MmCardDefinition:
	var bonus: ModifyPowerToughnessContinuousEffect = ModifyPowerToughnessContinuousEffect.new()
	bonus.power = counters_of(MmCounter.Kind.PLUS_ONE_PLUS_ONE, SourceSelection.new())
	bonus.toughness = counters_of(MmCounter.Kind.PLUS_ONE_PLUS_ONE, SourceSelection.new())
	bonus.affected = attached()
	var definition: MmCardDefinition = sash(card_name)
	definition.abilities[0] = continuous_static([bonus])
	return definition


## The ID of what [param object_id] is attached to, or 0.
static func attached_to(engine: MmEngine, object_id: int) -> int:
	return engine.game_state().object(object_id).attached_to_object_id


## Activates equip on [param equipment_id] for [param creature_id] and lets it resolve.
static func equip_and_resolve(engine: MmEngine, equipment_id: int, creature_id: int) -> String:
	var error: String = activate(engine, equipment_id, [MmReference.to_object(creature_id)])
	return error if error != "" else resolve_stack(engine)


## "Equipped": a permanent with an Equipment attached to it.
static func equipped() -> IsEquippedFilter:
	return IsEquippedFilter.new()


## "Equipped creatures you control".
static func equipped_creature_you_control() -> AllOfFilter:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	return all_of([of_type(MmCardTypes.CardType.CREATURE), equipped(), yours])


## A 2/2 creature costing {0}, after Kemba, Kha Enduring's static ability alone: "Equipped
## creatures you control get +1/+1."
static func kemba(card_name: String = "Kemba") -> MmCardDefinition:
	return creature(card_name, 2, 2, [continuous_static([modify_pt(1, 1, each(equipped_creature_you_control()))])])


## A 2/2 creature costing {0}, after Sunspear Shikari: "As long as this creature is equipped,
## it has first strike and lifelink."
static func shikari(card_name: String = "Shikari") -> MmCardDefinition:
	return creature(card_name, 2, 2, [continuous_static(
		[gain_abilities([FirstStrikeAbility.new(), LifelinkAbility.new()], SourceSelection.new())],
		condition(SourceSelection.new(), equipped()))])


## An instant costing {0}, after Resistance Reunited's second sentence: "Equipped creatures
## you control gain indestructible until end of turn."
static func free_reunite(card_name: String = "Reunite") -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [],
		[until_end_of_turn(gain_abilities([IndestructibleAbility.new()], each(equipped_creature_you_control())))])


# --- Tokens ---------------------------------------------------------------------------


## A Token Definition: a [param power]/[param toughness] creature token of [param colors]
## and [param subtypes], with [param abilities]. CR 111.4: named for its subtypes plus the
## word "Token".
static func token(power: int, toughness: int, colors: Array[MmCardTypes.CardColor], subtypes: Array[String],
		abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var definition: MmCardDefinition = MmCardDefinition.new()
	definition.name = " ".join(subtypes) + " Token"
	definition.card_types = [MmCardTypes.CardType.CREATURE]
	definition.subtypes = subtypes
	definition.color_indicator = colors
	definition.power = power
	definition.toughness = toughness
	definition.abilities = abilities
	return definition


## A 1/1 white Cat creature token.
static func cat() -> MmCardDefinition:
	return token(1, 1, [MmCardTypes.CardColor.WHITE], ["Cat"])


## "Create [param amount] [param made]".
static func create_tokens(made: MmCardDefinition, amount: int = 1) -> CreateTokenEffect:
	var effect: CreateTokenEffect = CreateTokenEffect.new()
	effect.token = made
	effect.amount = amount
	return effect


## An instant costing {0}: "Create [param amount] [param made]".
static func free_tokens(card_name: String, made: MmCardDefinition, amount: int = 1) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [], [create_tokens(made, amount)])


## The IDs of the tokens on the battlefield, in ID order.
static func tokens_on_battlefield(engine: MmEngine) -> Array[int]:
	var ids: Array[int] = []
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.is_token:
			ids.append(permanent.id)
	ids.sort()
	return ids


# --- Card track: modal spells ----------------------------------------------------------


## One mode of a modal spell or triggered ability: "[effects]", with its own [param targets].
static func ability_mode(targets: Array[TargetRequirement], effects: Array[MmEffect]) -> AbilityMode:
	var mode: AbilityMode = AbilityMode.new()
	mode.targets = targets
	mode.effects = effects
	return mode


## An instant costing {0}: "Choose one — [modes]".
static func free_modal(card_name: String, modes: Array[AbilityMode]) -> MmCardDefinition:
	var definition: MmCardDefinition = instant(card_name, mana_cost(0), [], [])
	(definition.abilities[0] as SpellAbility).modes = modes
	return definition


## An instant costing {0}: "Choose one — • [param amount] damage to target creature.
## • Destroy target enchantment."
static func free_charm(card_name: String, amount: int = 2) -> MmCardDefinition:
	return free_modal(card_name, [
		ability_mode([target(of_type(MmCardTypes.CardType.CREATURE))], [deal_damage(amount, targeted(0))]),
		ability_mode([target(of_type(MmCardTypes.CardType.ENCHANTMENT))], [destroy(targeted(0))]),
	])


## "[trigger], choose one — [modes]" (CR 603.3c, 700.2b).
static func modal_triggered(trigger: MmTrigger, modes: Array[AbilityMode]) -> TriggeredAbility:
	var ability: TriggeredAbility = TriggeredAbility.new()
	ability.trigger = trigger
	ability.modes = modes
	return ability


## An enchantment costing {0}, after Felidar Retreat: "[trigger], choose one — • Create a
## 2/2 white Cat Beast creature token. • Put a +1/+1 counter on each creature you control.
## Each creature you control gains vigilance until end of turn."
static func free_retreat(card_name: String, trigger: MmTrigger) -> MmCardDefinition:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	return enchantment(card_name, [modal_triggered(trigger, [
		ability_mode([], [create_tokens(token(2, 2, [MmCardTypes.CardColor.WHITE], ["Cat", "Beast"]))]),
		ability_mode([], [put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, each_creature(yours)),
			until_end_of_turn(gain_abilities([VigilanceAbility.new()], each_creature(yours)))]),
	])])


## Chooses mode [param mode_index] of the spell or triggered ability in the pending mode
## decision.
static func choose_mode(engine: MmEngine, mode_index: int) -> String:
	var decision: ChooseModeDecision = engine.pending_decision() as ChooseModeDecision
	if decision == null:
		return "Not a mode decision."
	var index: int = decision.modes.find(mode_index)
	return "Mode %d is not offered." % mode_index if index == -1 else engine.submit(index)


## Casts [param object_id] choosing mode [param mode_index] (when asked), then
## [param targets] in order, and pays automatically.
static func cast_mode(engine: MmEngine, object_id: int, mode_index: int, targets: Array[MmReference] = []) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = cast_index(decision, object_id)
	if index == -1:
		return "Object %d cannot be cast." % object_id
	var error: String = engine.submit(index)
	if error == "" and engine.pending_decision() is ChooseModeDecision:
		error = choose_mode(engine, mode_index)
	for chosen: MmReference in targets:
		if error != "":
			return error
		error = choose_target(engine, chosen)
	return error if error != "" else auto_pay(engine)


# --- Card track: flashback and costs that are not mana ------------------------------


## "Flashback [mana] [, costs]" (CR 702.34a). Null mana means its cost has no mana in it.
static func flashback(mana: MmManaCost, costs: Array[MmCost] = []) -> FlashbackAbility:
	var ability: FlashbackAbility = FlashbackAbility.new()
	ability.mana_cost = mana
	ability.costs = costs
	return ability


## A sorcery costing {0}: "[effects]" and [param keyword].
static func flashback_sorcery(card_name: String, targets: Array[TargetRequirement], effects: Array[MmEffect],
		keyword: FlashbackAbility) -> MmCardDefinition:
	var definition: MmCardDefinition = sorcery(card_name, mana_cost(0), targets, effects)
	definition.abilities.append(keyword)
	return definition


## "Pay [param amount] life" (CR 119.4).
static func pay_life(amount: int) -> PayLifeCost:
	var cost: PayLifeCost = PayLifeCost.new()
	cost.amount = amount
	return cost


## "Tap [param count] untapped creatures you control".
static func tap_creatures(count: int) -> TapCreaturesCost:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var cost: TapCreaturesCost = TapCreaturesCost.new()
	cost.count = count
	cost.filter = all_of([of_type(MmCardTypes.CardType.CREATURE), untapped(), mine])
	return cost


## A 1/1 creature costing {0}: "{T}: Add {W}."
static func elf(card_name: String = "Elf") -> MmCardDefinition:
	return creature(card_name, 1, 1, [tap_for_mana(MmMana.Type.WHITE, 1)])


## The object ID of the first card named [param card_name] in [param player]'s exile, or -1.
static func card_in_exile(engine: MmEngine, player: MmPlayer, card_name: String) -> int:
	for card: MmGameObject in engine.game_state().exile.objects():
		if card.owner_id == player.id and engine.game_state().characteristics_of(card).name == card_name:
			return card.id
	return -1


# --- Cost reductions ------------------------------------------------------------------


## "Affinity for [param filter]" (CR 702.41a).
static func affinity(filter: MmFilter) -> AffinityAbility:
	var ability: AffinityAbility = AffinityAbility.new()
	ability.filter = filter
	return ability


## "This spell costs {1} less to cast for each [param amount]" (CR 601.2f).
static func cost_reduction(amount: MmValue) -> CostReductionAbility:
	var ability: CostReductionAbility = CostReductionAbility.new()
	ability.amount = amount
	return ability


## An instant costing [param cost]: "This spell costs {1} less to cast for each basic land
## type among lands you control. You gain 1 life.", as Leyline Binding's reduction reads.
static func domain_reduced_instant(card_name: String, cost: MmManaCost) -> MmCardDefinition:
	var definition: MmCardDefinition = instant(card_name, cost, [], [gain_life(1, you())])
	definition.abilities.push_front(cost_reduction(domain()))
	return definition


## A 1/1 Cat creature costing {0}: "{T}: Add {W}", so it can pay for what it makes cheaper.
static func mouser(card_name: String = "Mouser") -> MmCardDefinition:
	var definition: MmCardDefinition = creature(card_name, 1, 1, [tap_for_mana(MmMana.Type.WHITE, 1)])
	definition.subtypes = ["Cat"]
	return definition


## An instant costing [param cost]: "Affinity for Cats. You gain 1 life."
static func cat_affinity_instant(card_name: String, cost: MmManaCost) -> MmCardDefinition:
	var definition: MmCardDefinition = instant(card_name, cost, [], [gain_life(1, you())])
	definition.abilities.push_front(affinity(has_subtype("Cat")))
	return definition


# --- The legend rule ------------------------------------------------------------------


## A legendary creature costing {0} ({2}{W} with [param costs_mana]), with [param abilities].
static func legend(card_name: String = "Legend", power: int = 2, toughness: int = 2, abilities: Array[MmAbility] = [],
		costs_mana: bool = false) -> MmCardDefinition:
	var definition: MmCardDefinition = creature(card_name, power, toughness, abilities,
		mana_cost(2, [MmMana.Type.WHITE]) if costs_mana else null)
	definition.supertypes = [MmCardTypes.Supertype.LEGENDARY]
	return definition


## Keeps [param object_id] in the pending legend rule choice (CR 704.5j).
static func keep_legend(engine: MmEngine, object_id: int) -> String:
	var decision: ChooseLegendToKeepDecision = engine.pending_decision() as ChooseLegendToKeepDecision
	if decision == null:
		return "Not a legend rule choice."
	var index: int = decision.candidate_ids.find(object_id)
	return "Object %d is not a candidate." % object_id if index == -1 else engine.submit(index)


# --- Choosing a creature type ---------------------------------------------------------


## "Creatures you control of the chosen type": the chosen type of the ability's source.
static func of_chosen_type_you_control() -> AllOfFilter:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	return all_of([of_type(MmCardTypes.CardType.CREATURE), yours, IsOfChosenTypeFilter.new()])


## An enchantment costing {0}, Rally the Ranks's two abilities: "As this enchantment enters,
## choose a creature type. Creatures you control of the chosen type get +1/+1."
static func rally(card_name: String = "Rally") -> MmCardDefinition:
	return enchantment(card_name, [AsEntersChooseCreatureTypeAbility.new(),
		continuous_static([modify_pt(1, 1, each(of_chosen_type_you_control()))])])


## Answers the pending creature type choice with [param creature_type].
static func choose_creature_type(engine: MmEngine, creature_type: String) -> String:
	var decision: ChooseCreatureTypeDecision = engine.pending_decision() as ChooseCreatureTypeDecision
	if decision == null:
		return "Not a creature type choice."
	var index: int = decision.creature_types.find(creature_type)
	return "%s is not a creature type." % creature_type if index == -1 else engine.submit(index)


## A creature costing {0} of [param subtypes].
static func typed_creature(card_name: String, power: int, toughness: int, subtypes: Array[String]) -> MmCardDefinition:
	var definition: MmCardDefinition = creature(card_name, power, toughness)
	definition.subtypes = subtypes
	return definition


# --- Casting from the top of the library ----------------------------------------------


## "With power [param amount] or less" (or greater).
static func power(amount: int, comparison: PowerFilter.Comparison = PowerFilter.Comparison.OR_LESS) -> PowerFilter:
	var filter: PowerFilter = PowerFilter.new()
	filter.amount = amount
	filter.comparison = comparison
	return filter


## "With toughness [param amount] or less" (or greater).
static func toughness(amount: int, comparison: ToughnessFilter.Comparison = ToughnessFilter.Comparison.OR_LESS) -> ToughnessFilter:
	var filter: ToughnessFilter = ToughnessFilter.new()
	filter.amount = amount
	filter.comparison = comparison
	return filter


## "With toughness X or less", or "or greater", X being [param value] as the Filter is
## asked, such as Domain. "Less than X" is not "X or greater": is_not() around it.
static func toughness_from(value: MmValue, comparison: ToughnessFilter.Comparison = ToughnessFilter.Comparison.OR_LESS) -> ToughnessFilter:
	var filter: ToughnessFilter = ToughnessFilter.new()
	filter.amount_value = value
	filter.comparison = comparison
	return filter


## "Once each turn, you may cast a creature spell with power 2 or less from the top of your
## library."
static func cast_from_top() -> CastFromTopOfLibraryAbility:
	var ability: CastFromTopOfLibraryAbility = CastFromTopOfLibraryAbility.new()
	ability.filter = all_of([of_type(MmCardTypes.CardType.CREATURE), power(2)])
	return ability


## An enchantment costing {0} with Assemble the Players's two abilities: "You may look at
## the top card of your library any time. Once each turn, you may cast a creature spell
## with power 2 or less from the top of your library."
static func lookout(card_name: String = "Lookout") -> MmCardDefinition:
	return enchantment(card_name, [LookAtTopOfLibraryAbility.new(), cast_from_top()])


## The name of the top card of [param player]'s library, or "" for an empty one.
static func top_name(engine: MmEngine, player: MmPlayer) -> String:
	var top: MmGameObject = player.library.top()
	return "" if top == null else engine.game_state().characteristics_of(top).name


## Finds a seed for [param setup] where the Hero casts [param hero_permanents] (each costing
## {0}) on Game Turn 1, then plays on to their first main phase of Game Turn 3 holding
## [param hand], with the top of their library holding [param tops] in order. Returns null
## if no seed deals them.
static func top_ready(setup: MmEncounterSetup, hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		tops: Array[String]) -> MmEngine:
	return find_engine(setup, func(running: MmEngine) -> bool:
		if play_until_step(running, 1, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		for definition: MmCardDefinition in hero_permanents:
			if cast_and_resolve(running, definition.name) != "" or resolve_stack(running) != "":
				return false
		if play_until_step(running, 3, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		for definition: MmCardDefinition in hand:
			if card_in_hand(running, running.hero(), definition.name) == -1:
				return false
		var library: Array[MmGameObject] = running.hero().library.objects()
		for index: int in tops.size():
			if running.game_state().characteristics_of(library[index]).name != tops[index]:
				return false
		return true, 3000)


# --- "Instead", doubling counters and counting resolutions ------------------------------


## "[param effect]. If [param condition], [param instead] instead." (CR 608.2c)
static func instead(condition: MmCondition, effect: MmEffect, instead_effect: MmEffect) -> InsteadEffect:
	var chosen: InsteadEffect = InsteadEffect.new()
	chosen.condition = condition
	chosen.effect = effect
	chosen.instead = instead_effect
	return chosen


## "Double the number of [param kind] counters on [param recipients]" (CR 701.10e).
static func double_counters(kind: MmCounter.Kind, recipients: MmSelection) -> DoubleCountersEffect:
	var effect: DoubleCountersEffect = DoubleCountersEffect.new()
	effect.kind = kind
	effect.recipients = recipients
	return effect


## "This is the [param times]th time this ability has resolved this turn."
static func times_resolved(times: int) -> TimesResolvedThisTurnCondition:
	var condition: TimesResolvedThisTurnCondition = TimesResolvedThisTurnCondition.new()
	condition.times = times
	return condition


## "You gain 1 life. If this is the second time this ability has resolved this turn, you
## gain 10 life instead.": what each of Scenario.ticker()'s abilities does.
static func second_time_gains_ten() -> InsteadEffect:
	return instead(times_resolved(2), gain_life(1, you()), gain_life(10, you()))


## A 1/1 creature costing {0} with [param abilities] free activated abilities, each
## "{0}: You gain 1 life. If this is the second time this ability has resolved this turn,
## you gain 10 life instead."
static func ticker(card_name: String = "Ticker", abilities: int = 1) -> MmCardDefinition:
	var activated: Array[MmAbility] = []
	for _index: int in abilities:
		var ability: ActivatedAbility = ActivatedAbility.new()
		ability.effects = [second_time_gains_ten()]
		activated.append(ability)
	return creature(card_name, 1, 1, activated)


## Activates ability [param ability_index] of [param object_id] and pays automatically.
static func activate_ability(engine: MmEngine, object_id: int, ability_index: int) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = action_index(decision, func(action: MmAction) -> bool:
		var activate: ActivateAbilityAction = action as ActivateAbilityAction
		return activate != null and activate.object_id == object_id and activate.ability_index == ability_index)
	if index == -1:
		return "Object %d has no ability %d to activate." % [object_id, ability_index]
	var error: String = engine.submit(index)
	return error if error != "" else auto_pay(engine)


# --- Searching a library (ADR 0057) ----------------------------------------------------


## "Basic land card": HasSupertypeFilter for basic with a land Filter.
static func basic_land_card() -> AllOfFilter:
	var basic: HasSupertypeFilter = HasSupertypeFilter.new()
	basic.supertype = MmCardTypes.Supertype.BASIC
	return all_of([basic, of_type(MmCardTypes.CardType.LAND)])


## "Search your library for up to [param amount] [param filter] cards, reveal them (with
## [param reveal]), put them into [param destination], then shuffle."
static func search(filter: MmFilter, amount: int = 1, destination: MmZone.Kind = MmZone.Kind.HAND,
		reveal: bool = true, tapped: bool = false) -> SearchLibraryEffect:
	var effect: SearchLibraryEffect = SearchLibraryEffect.new()
	effect.filter = filter
	effect.amount = constant(amount)
	effect.destination = destination
	effect.reveal = reveal
	effect.tapped = tapped
	return effect


## A sorcery costing {0} that does [param effect], by default Bushwhack's first mode:
## "Search your library for a basic land card, reveal it, put it into your hand, then
## shuffle."
static func free_seek(card_name: String = "Seek", effect: SearchLibraryEffect = null) -> MmCardDefinition:
	var searching: SearchLibraryEffect = effect if effect != null else search(basic_land_card())
	return sorcery(card_name, mana_cost(0), [], [searching])


## An instant costing {0} that puts the first card of its controller's hand on the bottom
## of their library without revealing it, as Brainstorm puts cards back (a test-only effect).
static func free_put_back(card_name: String = "Put Back") -> MmCardDefinition:
	var effect: MmEffect = load("res://addons/modmox_rules/tests/support/put_back_effect.gd").new()
	return instant(card_name, mana_cost(0), [], [effect])


## Passes priority until a search is asked, answering anything else with autoplay()
## defaults.
static func pass_to_search(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool:
		return running.pending_decision() is ChooseCardsInLibraryDecision)


## Casts [param card_name] from the Hero's hand and passes until its search is asked.
static func cast_to_search(engine: MmEngine, card_name: String = "Seek") -> String:
	var error: String = cast(engine, card_in_hand(engine, engine.hero(), card_name))
	return error if error != "" else pass_to_search(engine)


# --- Card track: Heroic ----------------------------------------------------------------


## "A spell that targets [param filter]", for a SpellCastTrigger's filter.
static func targets(filter: MmFilter) -> TargetsFilter:
	var targeting: TargetsFilter = TargetsFilter.new()
	targeting.filter = filter
	return targeting


## "A spell that targets this creature": Heroic's filter.
static func targets_source() -> TargetsFilter:
	return targets(IsSourceFilter.new())


## A 2/2 creature costing {0} with Heroic: "Whenever you cast a spell that targets this
## creature, [param effects]", by default "you gain 5 life".
static func heroic(card_name: String = "Hero", effects: Array[MmEffect] = []) -> MmCardDefinition:
	var gained: Array[MmEffect] = effects.duplicate()
	if gained.is_empty():
		gained.append(gain_life(5, you()))
	return creature(card_name, 2, 2, [triggered(casts(targets_source(), MmTrigger.Whose.YOU), gained)])


# --- Card track: up to N targets ------------------------------------------------------


## "Up to [param most] target [filter]": one word "target" that chooses any number of
## different objects from none to [param most] (CR 115.1d, 115.3, 601.2c).
static func up_to_targets(filter: MmFilter, most: int) -> TargetRequirement:
	var requirement: TargetRequirement = target(filter)
	requirement.most = most
	requirement.is_up_to = true
	return requirement


## A sorcery costing {0}, after Gird for Battle: "Put a +1/+1 counter on each of up to two
## target creatures."
static func free_gird(card_name: String = "Gird") -> MmCardDefinition:
	return sorcery(card_name, mana_cost(0), [up_to_targets(of_type(MmCardTypes.CardType.CREATURE), 2)],
		[put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, targeted(0))])


## "Other creature you control", Felidar Savior's targets.
static func other_creature_you_control() -> AllOfFilter:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	return all_of([of_type(MmCardTypes.CardType.CREATURE), is_not(IsSourceFilter.new()), yours])


## A 2/3 creature costing {0}, after Felidar Savior: "When this creature enters, put a
## +1/+1 counter on each of up to two other target creatures you control."
static func savior(card_name: String = "Savior") -> MmCardDefinition:
	return creature(card_name, 2, 3, [triggered(enters(IsSourceFilter.new()),
		[put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, targeted(0))],
		[up_to_targets(other_creature_you_control(), 2)])])


## Answers the pending choice of up to some number of targets with [param chosen], in order.
static func choose_targets(engine: MmEngine, chosen: Array[MmReference]) -> String:
	var decision: ChooseTargetsDecision = engine.pending_decision() as ChooseTargetsDecision
	if decision == null:
		return "Not a choice of targets."
	var answer: Array = []
	for wanted: MmReference in chosen:
		var found: int = -1
		for index: int in decision.candidates.size():
			if decision.candidates[index].equals(wanted):
				found = index
		if found == -1:
			return "%s is not a candidate." % wanted.describe()
		answer.append(found)
	return engine.submit(answer)


## Casts [param object_id], choosing [param chosen] for its one "up to" requirement when it
## is asked (it is not when nothing could be chosen), and pays automatically.
static func cast_up_to(engine: MmEngine, object_id: int, chosen: Array[MmReference]) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = cast_index(decision, object_id)
	if index == -1:
		return "Object %d cannot be cast." % object_id
	var error: String = engine.submit(index)
	if error == "" and engine.pending_decision() is ChooseTargetsDecision:
		error = choose_targets(engine, chosen)
	return error if error != "" else auto_pay(engine)


# --- Cycling --------------------------------------------------------------------------

## "Cycling [param mana]" (CR 702.29a): "[mana], Discard this card: Draw a card."
static func cycling(mana: MmManaCost) -> CyclingAbility:
	var ability: CyclingAbility = CyclingAbility.new()
	ability.mana_cost = mana
	return ability


## An instant costing {0}, "You gain 1 life", with cycling for [param mana], {2} unless
## another cost is given.
static func cycler(card_name: String = "Cycler", mana: MmManaCost = null) -> MmCardDefinition:
	var definition: MmCardDefinition = instant(card_name, mana_cost(0), [], [gain_life(1, you())])
	definition.abilities.append(cycling(mana if mana != null else mana_cost(2)))
	return definition


## "Basic landcycling [param mana]" (CR 702.29e): "[mana], Discard this card: Search your
## library for a basic land card, reveal it, put it into your hand, then shuffle."
static func landcycling(mana: MmManaCost) -> CyclingAbility:
	var ability: CyclingAbility = cycling(mana)
	ability.search = basic_land_card()
	return ability


## An instant costing {0}, "You gain 1 life", with basic landcycling for [param mana], {2}
## unless another cost is given.
static func landcycler(card_name: String = "Landcycler", mana: MmManaCost = null) -> MmCardDefinition:
	var definition: MmCardDefinition = instant(card_name, mana_cost(0), [], [gain_life(1, you())])
	definition.abilities.append(landcycling(mana if mana != null else mana_cost(2)))
	return definition


# --- Card track: "you may" ------------------------------------------------------------


## "You may [param effect]." (CR 603.5, 608.2d): asked yes or no as it begins.
static func may(effect: MmEffect) -> MayEffect:
	var optional: MayEffect = MayEffect.new()
	optional.effect = effect
	return optional


## A 2/1 creature costing {0}, Leonin Snarecaster's ability alone: "When this creature
## enters, you may tap target creature", or target [param filter].
static func snarer(card_name: String = "Snarer", filter: MmFilter = null) -> MmCardDefinition:
	var targeted_filter: MmFilter = filter if filter != null else of_type(MmCardTypes.CardType.CREATURE)
	return creature(card_name, 2, 1, [triggered(enters(IsSourceFilter.new()), [may(tap(targeted(0)))],
		[target(targeted_filter)])])


## Passes priority and answers everything else as autoplay() does, until a "you may" is
## asked.
static func pass_to_yes_or_no(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is ChooseYesOrNoDecision)


# --- Card track: "you may pay {X}" ----------------------------------------------------


## "You may pay {X}. If you do, [param effect]." (ADR 0061): X is chosen and paid as it
## begins, and [param effect] and every later effect of the ability read it as paid_x().
static func pay_x(effect: MmEffect) -> MayPayXEffect:
	var paying: MayPayXEffect = MayPayXEffect.new()
	paying.effect = effect
	return paying


## "X", the X paid as the spell or ability resolves.
static func paid_x() -> PaidXValue:
	return PaidXValue.new()


## "You gain X life", X being the X paid.
static func gain_x_life() -> GainLifeEffect:
	var effect: GainLifeEffect = gain_life(0, you())
	effect.amount = paid_x()
	return effect


## A 1/1 creature costing {0}: "When this creature enters, you may pay {X}. If you do,
## [effects]", by default "you gain X life". Any [param after] follow in the same ability.
static func x_payer(card_name: String = "X Payer", effect: MmEffect = null, after: Array[MmEffect] = []) -> MmCardDefinition:
	var effects: Array[MmEffect] = [pay_x(effect if effect != null else gain_x_life())]
	effects.append_array(after)
	return creature(card_name, 1, 1, [triggered(enters(IsSourceFilter.new()), effects)])


## A 0/1 creature costing {0}: "{T}: Add [param amount] {W}", so one source pays several.
static func mana_bird(card_name: String = "Mana Bird", amount: int = 3) -> MmCardDefinition:
	return creature(card_name, 0, 1, [tap_for_mana(MmMana.Type.WHITE, amount)])


## Passes priority and answers everything else as autoplay() does, until how much X to pay
## is asked.
static func pass_to_x_choice(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is ChooseXToPayDecision)


## Answers the pending ChooseXToPayDecision by paying [param x].
static func choose_x(engine: MmEngine, x: int) -> String:
	return engine.submit(ChooseXToPayDecision.answer_for(x))


# --- Card track: ward ------------------------------------------------------------------


## "Ward [param cost]" (CR 702.21a, ADR 0062), {2} unless another cost is given.
static func ward(cost: MmManaCost = null) -> WardAbility:
	var ability: WardAbility = WardAbility.new()
	ability.mana_cost = cost if cost != null else mana_cost(2)
	return ability


## A 2/2 creature costing {0} with ward [param cost], {2} unless another cost is given.
static func warden(card_name: String = "Warden", cost: MmManaCost = null) -> MmCardDefinition:
	return creature(card_name, 2, 2, [ward(cost)])


## Passes priority and answers everything else as autoplay() does, until a cost is asked to
## be paid or not, as ward's is.
static func pass_to_pay_or_not(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool:
		var asked: ChooseYesOrNoDecision = running.pending_decision() as ChooseYesOrNoDecision
		return asked != null and asked.cost != null)


# --- Card track: Domain ----------------------------------------------------------------


## Domain (CR 207.2c): "the number of basic land types among lands you control".
static func domain() -> BasicLandTypeCountValue:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var value: BasicLandTypeCountValue = BasicLandTypeCountValue.new()
	value.selection = each(all_of([of_type(MmCardTypes.CardType.LAND), mine]))
	return value


## A nonbasic land with two basic land types, such as a Plains Island, named after them.
## Its mana abilities come from its subtypes (CR 305.6), and it enters untapped.
static func dual_land(first_type: String, second_type: String) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla("%s %s" % [first_type, second_type])
	definition.card_types = [MmCardTypes.CardType.LAND]
	definition.subtypes = [first_type, second_type]
	return definition


## A sorcery costing {0}: "Search your library for up to [param amount] land cards and put
## them onto the battlefield, then shuffle", to put chosen lands under the Hero's control.
static func free_land_fetch(card_name: String = "Land Fetch", amount: int = 6) -> MmCardDefinition:
	return free_seek(card_name, search(of_type(MmCardTypes.CardType.LAND), amount, MmZone.Kind.BATTLEFIELD))


## Casts [param card_name] (a free_land_fetch()) from the Hero's hand and finds a land card
## named each of [param land_names], in order, then lets the stack resolve. Returns the
## first rejection reason, or "".
static func fetch_lands(engine: MmEngine, land_names: Array[String], card_name: String = "Land Fetch") -> String:
	var error: String = cast_to_search(engine, card_name)
	if error != "":
		return error
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	var found: Array[int] = []
	for land_name: String in land_names:
		for id: int in search.candidate_ids:
			if not found.has(id) and engine.game_state().characteristics_of(engine.game_state().object(id)).name == land_name:
				found.append(id)
				break
	if found.size() != land_names.size():
		return "Not every land is in the library."
	error = engine.submit(found)
	return error if error != "" else resolve_stack(engine)


# --- Card track: entering tapped --------------------------------------------------------


## A nonbasic land with two basic land types and "This land enters tapped." (CR 614.1c),
## such as Haunted Mire, named "Tapped [first] [second]".
static func tapped_dual_land(first_type: String, second_type: String) -> MmCardDefinition:
	var definition: MmCardDefinition = dual_land(first_type, second_type)
	definition.name = "Tapped %s %s" % [first_type, second_type]
	definition.abilities = [EntersTappedAbility.new()]
	return definition


# --- Card track: paying as a land enters ----------------------------------------------


## A nonbasic land with two basic land types and "As this land enters, you may pay 2 life.
## If you don't, it enters tapped." (CR 614.1c, 119.4), as on Temple Garden, named
## "Shock [first] [second]".
static func shock_land(first_type: String, second_type: String) -> MmCardDefinition:
	var definition: MmCardDefinition = dual_land(first_type, second_type)
	definition.name = "Shock %s %s" % [first_type, second_type]
	var ability: AsEntersPayOrEntersTappedAbility = AsEntersPayOrEntersTappedAbility.new()
	ability.cost = pay_life(2)
	definition.abilities = [ability]
	return definition


# --- Card track: activated ability cost reduction ---------------------------------------


## Jodah's Codex as an artifact costing {0}: "[param mana], {T}: Draw a card. This ability
## costs {1} less to activate for each basic land type among lands you control." ({5}
## unless another cost is given). With [param is_reduced] false it has no reduction.
static func codex(mana: MmManaCost = null, is_reduced: bool = true) -> MmCardDefinition:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = mana if mana != null else mana_cost(5)
	ability.costs = [TapCost.new()]
	ability.effects = [draw_cards(1, you())]
	if is_reduced:
		ability.generic_reduction = domain()
	return artifact("Codex", [ability])


# --- Card track: Auras ------------------------------------------------------------------


## "Enchant [param filter]" (CR 303.4a, 702.5): "Enchant land" unless another Filter is given.
static func enchant(filter: MmFilter = null) -> EnchantAbility:
	var ability: EnchantAbility = EnchantAbility.new()
	ability.filter = filter if filter != null else of_type(MmCardTypes.CardType.LAND)
	return ability


## An Aura costing {0}: "Enchant [param filter]" ("Enchant land" unless another Filter is
## given), then [param abilities].
static func aura(card_name: String = "Aura", filter: MmFilter = null, abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [enchant(filter)]
	all.append_array(abilities)
	var definition: MmCardDefinition = enchantment(card_name, all)
	definition.subtypes = ["Aura"]
	return definition


## Layer 4: "[affected] is every basic land type in addition to its other types", as Nylea's
## Presence says of enchanted land: the five basic land types, in the order of
## MmCardTypes.BASIC_LAND_TYPES. A land gains each one's mana ability (CR 305.7).
static func every_basic_land_type(affected: MmSelection) -> AddSubtypesContinuousEffect:
	var subtypes: Array[String] = []
	subtypes.assign(MmCardTypes.BASIC_LAND_TYPES.keys())
	return add_subtypes(subtypes, affected)


## An instant costing {0}: "Return target land to its owner's hand."
static func free_uproot(card_name: String = "Uproot") -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.LAND))], [return_to_hand(targeted(0))])


# --- Card track: becoming tapped --------------------------------------------------------


## "Whenever [filter] [whose] becomes tapped" (CR 603.2): "this permanent" unless another
## Filter is given.
static func becomes_tapped(filter: MmFilter = null, whose: MmTrigger.Whose = MmTrigger.Whose.ANY) -> BecomesTappedTrigger:
	var trigger: BecomesTappedTrigger = BecomesTappedTrigger.new()
	trigger.filter = filter if filter != null else IsSourceFilter.new()
	trigger.whose = whose
	return trigger


## A 2/2 costing {0}: "Whenever this creature becomes tapped, you gain 1 life", then
## [param abilities].
static func tap_watcher(card_name: String = "Watcher", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [triggered(becomes_tapped(), [gain_life(1, you())])]
	all.append_array(abilities)
	return creature(card_name, 2, 2, all)


## Zar Ojanen's ability on a 4/4 costing {0}: "Whenever this creature becomes tapped, put a
## +1/+1 counter on each creature you control with toughness less than the number of basic
## land types among lands you control."
static func scion(card_name: String = "Scion") -> MmCardDefinition:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var less_than_domain: NotFilter = is_not(toughness_from(domain(), ToughnessFilter.Comparison.OR_GREATER))
	var recipients: EachSelection = each(all_of([of_type(MmCardTypes.CardType.CREATURE), mine, less_than_domain]))
	return creature(card_name, 4, 4, [triggered(becomes_tapped(), [put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, recipients)])])


# --- Card track: surveil ---------------------------------------------------------------


## "Surveil [param amount]" (CR 701.25, ADR 0068).
static func surveil(amount: int = 1) -> SurveilEffect:
	var effect: SurveilEffect = SurveilEffect.new()
	effect.amount = constant(amount)
	return effect


## A 3/1 creature costing {0} with Wary Thespian's abilities: "When this creature enters,
## surveil [param amount]." and "When this creature dies, surveil [param amount]."
static func thespian(card_name: String = "Thespian", amount: int = 1) -> MmCardDefinition:
	return creature(card_name, 3, 1, [triggered(enters(IsSourceFilter.new()), [surveil(amount)]),
		triggered(dies(IsSourceFilter.new()), [surveil(amount)])])


## Passes priority and answers everything else as autoplay() does, until a surveil is
## asked.
static func pass_to_surveil(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is SurveilDecision)
