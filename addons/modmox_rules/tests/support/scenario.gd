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
		var asked: ChooseYesOrNoDecision = decision as ChooseYesOrNoDecision
		var paying: bool = asked.cost != null or asked.entry_cost != null or asked.resolution_cost != null
		return ChooseYesOrNoDecision.Choice.NO if paying else ChooseYesOrNoDecision.Choice.YES
	if decision is ChooseXToPayDecision:
		return ChooseXToPayDecision.DECLINE
	if decision is ChooseXDecision:
		return 0  # As an X to pay on resolution is declined: autoplay pays nothing more.
	if decision is SurveilDecision:
		return [[], (decision as SurveilDecision).card_ids.duplicate()]  # Every card kept, in order.
	if decision is ChooseLookedAtCardsDecision:
		var look: ChooseLookedAtCardsDecision = decision as ChooseLookedAtCardsDecision
		return look.answer_taking(look.candidate_ids.slice(0, look.most))
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


## A mana cost of [param generic], [param symbols] and the hybrid symbols [param hybrids],
## each a pair of mana types such as [code][[BLACK, RED]][/code] for {B/R} (CR 107.4e).
static func hybrid_cost(generic: int, hybrids: Array, symbols: Array[MmMana.Type] = []) -> MmManaCost:
	var cost: MmManaCost = mana_cost(generic, symbols)
	for pair: Array in hybrids:
		cost.hybrid_symbols.append(Vector2i(pair[0], pair[1]))
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


## "[param selection] doesn't untap during its controller's next untap step" (CR 502.3).
static func doesnt_untap(selection: MmSelection) -> DoesntUntapEffect:
	var effect: DoesntUntapEffect = DoesntUntapEffect.new()
	effect.selection = selection
	return effect


## An instant costing {0}, after Niblis of Frost's trigger: "Tap target creature. That
## creature doesn't untap during its controller's next untap step."
static func free_frost(card_name: String = "Frost") -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))],
		[tap(targeted(0)), doesnt_untap(targeted(0))])


## "[param selection] can't block this turn" (CR 509.1a), as Arena Athlete's Heroic says.
static func cant_block_this_turn(selection: MmSelection) -> CantBlockThisTurnEffect:
	var effect: CantBlockThisTurnEffect = CantBlockThisTurnEffect.new()
	effect.selection = selection
	return effect


## An instant costing {0}: "Target creature can't block this turn."
static func free_scare(card_name: String = "Scare") -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))],
		[cant_block_this_turn(targeted(0))])


## "Untap [param selection]" (CR 701.26b).
static func untap(selection: MmSelection) -> UntapEffect:
	var effect: UntapEffect = UntapEffect.new()
	effect.selection = selection
	return effect


## An instant costing {0}: "Untap target creature."
static func free_untap(card_name: String) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(of_type(MmCardTypes.CardType.CREATURE))], [untap(targeted(0))])


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


## "This spell costs {[param amount]} less to cast if [param condition]" (CR 601.2f), as
## Gigastorm Titan's "if you've cast another spell this turn" (engine ADR 0050's addendum).
static func cost_reduction_if(amount: int, condition: MmCondition) -> CostReductionAbility:
	var ability: CostReductionAbility = cost_reduction(constant(amount))
	ability.condition = condition
	return ability


## A 4/4 creature costing [param cost] ({4}{W} unless another is given) with Gigastorm
## Titan's "This spell costs {3} less to cast if you've cast another spell this turn."
static func titan(card_name: String = "Titan", cost: MmManaCost = null) -> MmCardDefinition:
	return creature(card_name, 4, 4, [cost_reduction_if(3, CastAnotherSpellThisTurnCondition.new())],
		mana_cost(4, [MmMana.Type.WHITE]) if cost == null else cost)


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


## A 1/1 Shapeshifter costing {0} with changeling, then [param abilities] (CR 702.73a).
static func changeling(card_name: String = "Changeling", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [ChangelingAbility.new()]
	all.append_array(abilities)
	return typed_creature_with(card_name, 1, 1, ["Shapeshifter"], all)


## A creature costing {0} of [param subtypes], with [param abilities].
static func typed_creature_with(card_name: String, power: int, toughness: int, subtypes: Array[String],
		abilities: Array[MmAbility]) -> MmCardDefinition:
	var definition: MmCardDefinition = creature(card_name, power, toughness, abilities)
	definition.subtypes = subtypes
	return definition


# --- Casting from the top of the library ----------------------------------------------


## "With power [param amount] or less" (or greater).
static func power(amount: int, comparison: PowerFilter.Comparison = PowerFilter.Comparison.OR_LESS) -> PowerFilter:
	var filter: PowerFilter = PowerFilter.new()
	filter.amount = amount
	filter.comparison = comparison
	return filter


## "With power X or less", or "or greater", X being [param value] as the Filter is asked.
## "Greater than X" is "X plus 1 or greater".
static func power_from(value: MmValue, comparison: PowerFilter.Comparison = PowerFilter.Comparison.OR_LESS) -> PowerFilter:
	var filter: PowerFilter = PowerFilter.new()
	filter.amount_value = value
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


# --- Abilities that work from the graveyard --------------------------------------------

## Sanitarium Skeleton's ability: "[param mana]: Return this card from your graveyard to
## your hand.", which works only while its card is in its owner's graveyard (CR 113.6k).
static func back_from_the_graveyard(mana: MmManaCost) -> ActivatedAbility:
	var ability: ActivatedAbility = activated(mana, [], [return_to_hand(SourceSelection.new())])
	ability.is_activated_from_graveyard = true
	return ability


## A 1/2 costing {0} with "[param mana]: Return this card from your graveyard to your hand",
## {0} unless another cost is given.
static func skeleton(card_name: String = "Skeleton", mana: MmManaCost = null) -> MmCardDefinition:
	return creature(card_name, 1, 2, [back_from_the_graveyard(mana if mana != null else mana_cost(0))])


## "A [param filter] died [under whose control] this turn" (CR 700.4, ADR 0095): "a
## non-Skeleton creature died under your control this turn" with the defaults.
static func died_this_turn(filter: MmFilter = null, whose: MmTrigger.Whose = MmTrigger.Whose.YOU) -> DiedThisTurnCondition:
	var condition: DiedThisTurnCondition = DiedThisTurnCondition.new()
	condition.filter = filter if filter != null else all_of([of_type(MmCardTypes.CardType.CREATURE), is_not(has_subtype("Skeleton"))])
	condition.whose = whose
	return condition


## Cult Conscript's abilities on a 2/1 Skeleton costing {0}: "This creature enters tapped."
## and "[param mana]: Return this card from your graveyard to the battlefield. Activate only
## if a non-Skeleton creature died under your control this turn.", {0} unless another cost
## is given.
static func conscript(card_name: String = "Conscript", mana: MmManaCost = null) -> MmCardDefinition:
	var back: ActivatedAbility = activated(mana if mana != null else mana_cost(0), [], [return_to_battlefield(SourceSelection.new())])
	back.is_activated_from_graveyard = true
	back.condition = died_this_turn()
	return typed_creature_with(card_name, 2, 1, ["Skeleton"], [EntersTappedAbility.new(), back])


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


# --- Card track: scry -----------------------------------------------------------------


## "Scry [param amount]" (CR 701.22a).
static func scry(amount: int = 1) -> ScryEffect:
	var effect: ScryEffect = ScryEffect.new()
	effect.amount = constant(amount)
	return effect


## A 1/1 creature costing {0}: "When this creature enters, scry [param amount]."
static func seer(card_name: String = "Seer", amount: int = 1) -> MmCardDefinition:
	return creature(card_name, 1, 1, [triggered(enters(IsSourceFilter.new()), [scry(amount)])])


## Passes priority and answers everything else as autoplay() does, until a scry is asked.
static func pass_to_scry(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is ScryDecision)


# --- Card track: fight, sacrifice, players who control more ---------------------------


## "[param creature] fights [param other]" (CR 701.14).
static func fight(creature: MmSelection, other: MmSelection) -> FightEffect:
	var effect: FightEffect = FightEffect.new()
	effect.creature = creature
	effect.other = other
	return effect


## "Creature you don't control": AllOf(creature, Not(you control)).
static func creature_you_dont_control() -> AllOfFilter:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	return all_of([of_type(MmCardTypes.CardType.CREATURE), is_not(mine)])


## "Creature you control".
static func creature_you_control() -> AllOfFilter:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	return all_of([of_type(MmCardTypes.CardType.CREATURE), mine])


## Bushwhack's second mode as an instant costing {0}: "Target creature you control fights
## target creature you don't control."
static func free_fight(card_name: String = "Fight") -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(creature_you_control()), target(creature_you_dont_control())],
		[fight(targeted(0), targeted(1))])


## [param definition] with every "target" in its text changed to "each" (CR 702.96b): the
## card an OverloadModification flattens it into, named [param card_name] when one is given.
static func overloaded(definition: MmCardDefinition, card_name: String = "") -> MmCardDefinition:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = definition
	run_card.modifications = [OverloadModification.new()]
	var flattened: MmCardDefinition = run_card.flatten()
	if card_name != "":
		flattened.name = card_name
	return flattened


## An activated ability: "[param mana], [costs]: [effects]", with [param targets].
static func activated(mana: MmManaCost, costs: Array[MmCost], effects: Array[MmEffect],
		targets: Array[TargetRequirement] = []) -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = mana
	ability.costs = costs
	ability.effects = effects
	ability.targets = targets
	return ability


## Ominous Parcel's second ability on an artifact costing {0}, at {0}: "{0}, {T}, Sacrifice
## this artifact: It deals 4 damage to target creature", then [param abilities].
static func parcel(card_name: String = "Parcel", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [activated(mana_cost(0), [TapCost.new(), SacrificeThisCost.new()],
		[deal_damage(4, targeted(0))], [target(of_type(MmCardTypes.CardType.CREATURE))])]
	all.append_array(abilities)
	return artifact(card_name, all)


## "Players who control more [param filter] than you" (as Oreskos Explorer's X counts them).
static func controls_more(filter: MmFilter) -> ControlsMoreFilter:
	var players: ControlsMoreFilter = ControlsMoreFilter.new()
	players.filter = filter
	return players


## "The number of players who control more [param filter] than you".
static func players_who_control_more(filter: MmFilter) -> CountValue:
	var count: CountValue = CountValue.new()
	count.selection = each(controls_more(filter))
	return count


## An instant costing {0}: "You gain X life, where X is the number of players who control
## more creatures than you."
static func free_envy(card_name: String = "Envy") -> MmCardDefinition:
	var gain: GainLifeEffect = gain_life(0, you())
	gain.amount = players_who_control_more(of_type(MmCardTypes.CardType.CREATURE))
	return instant(card_name, mana_cost(0), [], [gain])


# --- Card track: triggering only once each turn ------------------------------------------


## [param ability] with "This ability triggers only once each turn."
static func once_each_turn(ability: TriggeredAbility) -> TriggeredAbility:
	ability.is_once_each_turn = true
	return ability


## Tocasia's Welcome as an enchantment costing {0}: "Whenever one or more creatures you
## control with mana value 3 or less enter, draw a card. This ability triggers only once
## each turn."
static func welcome(card_name: String = "Welcome") -> MmCardDefinition:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	var small: AllOfFilter = all_of([of_type(MmCardTypes.CardType.CREATURE), yours, mana_value(3)])
	return enchantment(card_name, [once_each_turn(triggered(enters(small), [draw_cards(1, you())]))])


# --- Card track: attacking --------------------------------------------------------------


## "Whenever [filter] attacks" (CR 508.3a): "this creature" unless another Filter is given,
## then "whenever one or more [filter] [whose] control attack".
static func attacks(filter: MmFilter = null, whose: MmTrigger.Whose = MmTrigger.Whose.YOU) -> AttackersDeclaredTrigger:
	var trigger: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	trigger.filter = filter if filter != null else IsSourceFilter.new()
	trigger.whose = whose
	return trigger


## A 1/1 costing {0} with exalted (CR 702.83a), then [param abilities].
static func squire(card_name: String = "Squire", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [ExaltedAbility.new()]
	all.append_array(abilities)
	return creature(card_name, 1, 1, all)


## A 2/2 costing {0}: "Whenever this creature attacks, you gain 1 life", then
## [param abilities].
static func raider(card_name: String = "Raider", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [triggered(attacks(), [gain_life(1, you())])]
	all.append_array(abilities)
	return creature(card_name, 2, 2, all)


## "Create [param amount] [param made] that's attacking" (CR 508.4).
static func attacking_tokens(made: MmCardDefinition, amount: int = 1) -> CreateTokenEffect:
	var effect: CreateTokenEffect = create_tokens(made, amount)
	effect.attacking = true
	return effect


## An instant costing {0}: "Create a 1/1 white Cat creature token that's attacking", or
## [param made] instead of the Cat.
static func free_ambush(card_name: String = "Ambush", made: MmCardDefinition = null) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [], [attacking_tokens(cat() if made == null else made)])


## A 3/4 costing {0} with Brimaz, King of Oreskos's attack trigger: "Whenever this creature
## attacks, create a 1/1 white Cat creature token that's attacking", or [param made] instead
## of the Cat. The Cat has no vigilance, unlike Brimaz's Cat Soldier, so tapping shows.
static func brimaz(made: MmCardDefinition = null) -> MmCardDefinition:
	var effects: Array[MmEffect] = [attacking_tokens(cat() if made == null else made)]
	return creature("Brimaz", 3, 4, [triggered(attacks(), effects)])


# --- Card track: blocking ---------------------------------------------------------------


## "Whenever [filter] blocks a creature" (CR 509.3b): "this creature" unless another Filter
## is given, such as creature_you_control() for "a creature you control".
static func blocks_a_creature(filter: MmFilter = null) -> BlockersDeclaredTrigger:
	var trigger: BlockersDeclaredTrigger = BlockersDeclaredTrigger.new()
	trigger.filter = filter if filter != null else IsSourceFilter.new()
	return trigger


## A 2/2 costing {0}: "Whenever this creature blocks a creature, you gain 1 life", then
## [param abilities].
static func sentry(card_name: String = "Sentry", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [triggered(blocks_a_creature(), [gain_life(1, you())])]
	all.append_array(abilities)
	return creature(card_name, 2, 2, all)


## "Create [param amount] [param made] that's blocking [param blocked]" (CR 509.7): "that
## creature" unless another Selection is given.
static func blocking_tokens(made: MmCardDefinition, amount: int = 1, blocked: MmSelection = null) -> CreateTokenEffect:
	var effect: CreateTokenEffect = create_tokens(made, amount)
	effect.blocking = blocked if blocked != null else TriggeringObjectSelection.new()
	return effect


## A 3/4 costing {0} with Brimaz, King of Oreskos's block trigger: "Whenever this creature
## blocks a creature, create a 1/1 white Cat creature token that's blocking that creature",
## or [param made] instead of the Cat, then [param abilities].
static func blocking_brimaz(made: MmCardDefinition = null, abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var effects: Array[MmEffect] = [blocking_tokens(cat() if made == null else made)]
	var all: Array[MmAbility] = [triggered(blocks_a_creature(), effects)]
	all.append_array(abilities)
	return creature("Brimaz", 3, 4, all)


## An instant costing {0}, after Flash Foliage: "Create a 1/1 white Cat creature token that's
## blocking target attacking creature."
static func free_foliage(card_name: String = "Foliage") -> MmCardDefinition:
	var attacking: AllOfFilter = all_of([of_type(MmCardTypes.CardType.CREATURE), IsAttackingFilter.new()])
	return instant(card_name, mana_cost(0), [target(attacking)], [blocking_tokens(cat(), 1, targeted(0))])


# --- Card track: assigning combat damage by toughness ----------------------------------


## "[affected] assigns combat damage equal to its toughness rather than its power" (CR
## 510.1a): "this creature" unless another Selection is given, and "As long as [condition],
## ..." with [param condition].
static func by_toughness(affected: MmSelection = null, condition: MmCondition = null) -> AssignsCombatDamageByToughnessAbility:
	var ability: AssignsCombatDamageByToughnessAbility = AssignsCombatDamageByToughnessAbility.new()
	ability.affected = affected if affected != null else SourceSelection.new()
	ability.condition = condition
	return ability


## "Equipped creature's toughness is greater than its power": not "toughness [its power] or
## less".
static func toughness_greater_than_power() -> SelectionMatchesCondition:
	var its_power: PowerValue = PowerValue.new()
	its_power.selection = attached()
	return condition(attached(), is_not(toughness_from(its_power)))


## An Equipment costing {0} with Bark of Doran's abilities: "Equipped creature gets +0/+1. As
## long as equipped creature's toughness is greater than its power, it assigns combat damage
## equal to its toughness rather than its power. Equip {0}".
static func bark(card_name: String = "Bark") -> MmCardDefinition:
	var definition: MmCardDefinition = artifact(card_name, [
		continuous_static([modify_pt(0, 1, attached())]),
		by_toughness(attached(), toughness_greater_than_power()),
		equip(mana_cost(0))])
	definition.subtypes = ["Equipment"]
	return definition


# --- Card track: mana of any color (ADR 0072) -------------------------------------------


## "Add one mana of any color" (CR 106.1a), its color chosen as its ability is activated.
static func any_color() -> AddManaEffect:
	var effect: AddManaEffect = AddManaEffect.new()
	effect.is_any_color = true
	effect.amount = constant(1)
	return effect


## "Add {U}, {B}, or {R}": one mana of one of [param colors], its color chosen as its ability
## is activated (ADR 0072).
static func one_of_colors(colors: Array[MmMana.Type]) -> AddManaEffect:
	var effect: AddManaEffect = AddManaEffect.new()
	effect.color_choices = colors.duplicate()
	effect.amount = constant(1)
	return effect


## A nonbasic land named [param card_name] with "{T}: Add [one of param colors]", such as
## Crumbling Necropolis's "{T}: Add {U}, {B}, or {R}." without its entering tapped.
static func choice_land(card_name: String, colors: Array[MmMana.Type]) -> MmCardDefinition:
	var definition: MmCardDefinition = vanilla(card_name)
	definition.card_types = [MmCardTypes.CardType.LAND]
	definition.abilities = [activated(null, [TapCost.new()], [one_of_colors(colors)])]
	return definition


## A Treasure Token Definition made in code (CR 111.10a): a colorless Treasure artifact token
## with "{T}, Sacrifice this token: Add one mana of any color." Load
## content/tokens/treasure.tres when its art matters.
static func treasure() -> MmCardDefinition:
	var definition: MmCardDefinition = MmCardDefinition.new()
	definition.name = "Treasure Token"
	definition.card_types = [MmCardTypes.CardType.ARTIFACT]
	definition.subtypes = ["Treasure"]
	definition.abilities = [activated(null, [TapCost.new(), SacrificeThisCost.new()], [any_color()])]
	return definition


## The color of mana each of [param actions] that activates an ability of [param object_id]
## makes, in order: MmMana.NO_TYPE for an activation that chooses none.
static func colors_offered(actions: Array[MmAction], object_id: int) -> Array[int]:
	var colors: Array[int] = []
	for action: MmAction in actions:
		var activate: ActivateAbilityAction = action as ActivateAbilityAction
		if activate != null and activate.object_id == object_id:
			colors.append(activate.mana_type)
	return colors


## Activates [param object_id]'s ability that adds one mana of any color, for [param type],
## while holding priority.
static func activate_for(engine: MmEngine, object_id: int, type: MmMana.Type) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = _color_index(decision.actions, object_id, type)
	return "Object %d makes no %s." % [object_id, MmMana.Type.find_key(type)] if index == -1 else engine.submit(index)


## Pays one step of the pending payment with [param object_id]'s ability that adds one mana
## of any color, for [param type].
static func pay_for(engine: MmEngine, object_id: int, type: MmMana.Type) -> String:
	var decision: PayManaDecision = engine.pending_decision() as PayManaDecision
	if decision == null:
		return "Not a payment decision."
	var index: int = _color_index(decision.actions, object_id, type)
	return "Object %d makes no %s." % [object_id, MmMana.Type.find_key(type)] if index == -1 else engine.submit(index)


static func _color_index(actions: Array[MmAction], object_id: int, type: MmMana.Type) -> int:
	for index: int in actions.size():
		var activate: ActivateAbilityAction = actions[index] as ActivateAbilityAction
		if activate != null and activate.object_id == object_id and activate.mana_type == type:
			return index
	return -1


# --- Card track: {X} in a mana cost (ADR 0076) -----------------------------------------


## A mana cost with one {X} besides [param generic] and [param symbols] (CR 107.3).
static func x_cost(generic: int = 0, symbols: Array[MmMana.Type] = []) -> MmManaCost:
	var cost: MmManaCost = mana_cost(generic, symbols)
	cost.x_count = 1
	return cost


## "X": the value chosen for {X} as its spell was cast (CR 107.3a, 107.3m).
static func chosen_x() -> ChosenXValue:
	return ChosenXValue.new()


## A sorcery costing {X}: "You gain X life."
static func x_gain(card_name: String = "Bounty") -> MmCardDefinition:
	var gain: GainLifeEffect = gain_life(0, you())
	gain.amount = chosen_x()
	return sorcery(card_name, x_cost(), [], [gain])


## A sorcery costing {X}: "This spell deals X damage to target creature."
static func x_blast(card_name: String = "Blast") -> MmCardDefinition:
	var damage: DealDamageEffect = deal_damage(0, targeted(0))
	damage.amount = chosen_x()
	return sorcery(card_name, x_cost(), [target(of_type(MmCardTypes.CardType.CREATURE))], [damage])


## "This permanent enters with [param amount] [param kind] counters on it" (CR 614.1c).
static func enters_with_counters(amount: MmValue, kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE) -> EntersWithCountersAbility:
	var ability: EntersWithCountersAbility = EntersWithCountersAbility.new()
	ability.kind = kind
	ability.amount = amount
	return ability


## A 0/0 creature costing {X} with "This creature enters with X +1/+1 counters on it.", then
## [param abilities].
static func hydra(card_name: String = "Hydra", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [enters_with_counters(chosen_x())]
	all.append_array(abilities)
	return creature(card_name, 0, 0, all, x_cost())


## Casts [param object_id] from the priority holder's hand, choosing [param x] for its {X},
## then [param targets] in order, and pays automatically.
static func cast_with_x(engine: MmEngine, object_id: int, x: int, targets: Array[MmReference] = []) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = cast_index(decision, object_id)
	if index == -1:
		return "Object %d cannot be cast." % object_id
	var error: String = engine.submit(index)
	if error == "":
		error = choose_cast_x(engine, x)
	for chosen: MmReference in targets:
		if error != "":
			return error
		error = choose_target(engine, chosen)
	return error if error != "" else auto_pay(engine)


## Answers the pending ChooseXDecision with [param x].
static func choose_cast_x(engine: MmEngine, x: int) -> String:
	if not engine.pending_decision() is ChooseXDecision:
		return "Not an X choice."
	return engine.submit(x)


## "You may [param cost]. If you do, [param effect]." (CR 603.5, 608.2d).
static func may_pay(cost: MmCost, effect: MmEffect) -> MayPayEffect:
	var paying: MayPayEffect = MayPayEffect.new()
	paying.cost = cost
	paying.effect = effect
	return paying


## "Discard [param count] cards" as a cost (CR 701.9a, 118), as Irreverent Gremlin's "you may
## discard a card".
static func discard_cards_cost(count: int = 1) -> DiscardCardsCost:
	var cost: DiscardCardsCost = DiscardCardsCost.new()
	cost.count = count
	return cost


## A 2/2 costing {0} with Irreverent Gremlin's second ability: "Whenever another creature you
## control with power 2 or less enters, you may discard a card. If you do, draw a card. Do
## this only once each turn."
static func gremlin(card_name: String = "Gremlin") -> MmCardDefinition:
	var looting: MayPayEffect = may_pay(discard_cards_cost(), draw_cards(1, you()))
	looting.is_once_each_turn = true
	var another: AllOfFilter = all_of([of_type(MmCardTypes.CardType.CREATURE), is_not(IsSourceFilter.new()), power(2)])
	return creature(card_name, 2, 2, [triggered(enters(another, MmTrigger.Whose.YOU), [looting])])


## "You may pay [param mana]. If you do, [param effect]." (ADR 0076's addendum), as
## Myrsmith's "you may pay {1}".
static func may_pay_mana(mana: MmManaCost, effect: MmEffect) -> MayPayEffect:
	var paying: MayPayEffect = MayPayEffect.new()
	paying.mana_cost = mana
	paying.effect = effect
	return paying


## "Remove [param amount] [param kind] counters from this permanent" (CR 118.3).
static func remove_counters(amount: int = 1, kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE) -> RemoveCountersCost:
	var cost: RemoveCountersCost = RemoveCountersCost.new()
	cost.kind = kind
	cost.amount = amount
	return cost


# --- Adventure (CR 715, engine ADR 0078) ---------------------------------------------------


## An Adventurer card after Faerie Guidemother: "Guide", a 1/1 creature with flying costing
## [param creature_cost] ({0} unless given), whose Adventure is "Gift", a sorcery — Adventure
## costing [param adventure_cost] ({0} unless given): "Target creature gets +2/+1 until end
## of turn."
static func adventurer(creature_cost: MmManaCost = null, adventure_cost: MmManaCost = null) -> MmCardDefinition:
	var guide: MmCardDefinition = creature("Guide", 1, 1, [FlyingAbility.new()], creature_cost)
	var gift: MmCardDefinition = sorcery("Gift", mana_cost(0) if adventure_cost == null else adventure_cost,
		[target(of_type(MmCardTypes.CardType.CREATURE))], [until_end_of_turn(modify_pt(2, 1, targeted(0)))])
	gift.subtypes = ["Adventure"]
	guide.adventure = gift
	return guide


## The index of the priority action that casts [param object_id], as its Adventure when
## [param as_adventure], or -1.
static func cast_index_as(decision: PriorityDecision, object_id: int, as_adventure: bool) -> int:
	return action_index(decision, func(action: MmAction) -> bool:
		var cast: CastSpellAction = action as CastSpellAction
		return cast != null and cast.object_id == object_id and cast.as_adventure == as_adventure)


## Casts [param object_id] as its Adventure, aimed at [param chosen], and pays automatically.
static func cast_adventure(engine: MmEngine, object_id: int, chosen: MmReference) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = cast_index_as(decision, object_id, true)
	if index == -1:
		return "Object %d cannot be cast as an Adventure." % object_id
	var error: String = engine.submit(index)
	if error == "" and engine.pending_decision() is ChooseTargetDecision:
		error = choose_target(engine, chosen)
	return error if error != "" else auto_pay(engine)


# --- Mill, "from among them" and threshold (engine ADR 0080) --------------------------------


## "[players] mill [amount] cards" (CR 701.17a), the controller unless others are given.
static func mill(amount: int, players: MmSelection = null) -> MillEffect:
	var effect: MillEffect = MillEffect.new()
	effect.amount = constant(amount)
	effect.players = you() if players == null else players
	return effect


## An instant costing {0}: "Mill [amount] cards", or "Each opponent mills [amount] cards"
## with [param opponents].
static func free_mill(card_name: String, amount: int, opponents: bool = false) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [], [mill(amount, EachOpponentSelection.new() if opponents else null)])


## "Put [a filter] from among them into your hand": a card the controller chooses among the
## cards the spell's earlier effect moved (MovedCardsSelection), not a target.
static func put_one_from_among_them(filter: MmFilter, choice_index: int = 0) -> ReturnToHandEffect:
	var chosen: ChosenSelection = ChosenSelection.new()
	chosen.filter = filter
	chosen.choice_index = choice_index
	chosen.from_among = MovedCardsSelection.new()
	var effect: ReturnToHandEffect = ReturnToHandEffect.new()
	effect.selection = chosen
	return effect


## "Instant or sorcery card".
static func instant_or_sorcery() -> AnyOfFilter:
	return any_of([of_type(MmCardTypes.CardType.INSTANT), of_type(MmCardTypes.CardType.SORCERY)])


## A sorcery costing {0} after Speak Secrets: "Mill four cards, then put an instant or sorcery
## card from among them into your hand."
static func free_secrets(card_name: String = "Secrets") -> MmCardDefinition:
	return sorcery(card_name, mana_cost(0), [], [mill(4), put_one_from_among_them(instant_or_sorcery())])


## "The number of cards in [whose] graveyard".
static func cards_in_graveyard(whose: MmTrigger.Whose = MmTrigger.Whose.YOU, filter: MmFilter = null) -> CardsInZoneValue:
	var value: CardsInZoneValue = CardsInZoneValue.new()
	value.zone = MmZone.Kind.GRAVEYARD
	value.whose = whose
	value.filter = filter
	return value


## "[value] is [amount] or more".
static func at_least(value: MmValue, amount: int) -> ValueAtLeastCondition:
	var condition: ValueAtLeastCondition = ValueAtLeastCondition.new()
	condition.value = value
	condition.amount = amount
	return condition


## A 1/1 creature costing {0} after Most Decrepit Old Bird's threshold: "This creature gets
## +1/+1 as long as there are seven or more cards in your graveyard."
static func threshold_bird(card_name: String = "Old Bird") -> MmCardDefinition:
	var pump: ModifyPowerToughnessContinuousEffect = modify_pt(1, 1, SourceSelection.new())
	return creature(card_name, 1, 1, [continuous_static([pump], at_least(cards_in_graveyard(), 7))])


# --- Card track: counters being put on a permanent ----------------------------------------


## "Whenever one or more [param kind] counters are put on [param filter] [param whose]"
## (CR 122.6): "this creature" unless another Filter is given. With [param by_whose],
## "Whenever [by_whose] put(s) one or more ...": only counters that player puts count.
static func counters_put(filter: MmFilter = null, whose: MmTrigger.Whose = MmTrigger.Whose.ANY,
		kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE,
		by_whose: MmTrigger.Whose = MmTrigger.Whose.ANY) -> CountersPutTrigger:
	var trigger: CountersPutTrigger = CountersPutTrigger.new()
	trigger.filter = filter if filter != null else IsSourceFilter.new()
	trigger.whose = whose
	trigger.kind = kind
	trigger.by_whose = by_whose
	return trigger


## A 2/2 costing {0}: "Whenever one or more +1/+1 counters are put on this creature, you gain
## 1 life", then [param abilities].
static func counter_watcher(card_name: String = "Counter Watcher", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [triggered(counters_put(), [gain_life(1, you())])]
	all.append_array(abilities)
	return creature(card_name, 2, 2, all)


# --- Card track: gaining life (ADR 0082) --------------------------------------------------


## "Whenever [param whose] gain(s) life" (CR 119.9).
static func life_gained(whose: MmTrigger.Whose = MmTrigger.Whose.YOU) -> LifeGainedTrigger:
	var trigger: LifeGainedTrigger = LifeGainedTrigger.new()
	trigger.whose = whose
	return trigger


## A 2/1 costing {0} with Unflinching Hortimancer's second ability: "Whenever you gain life,
## put a +1/+1 counter on this creature", then [param abilities].
static func life_watcher(card_name: String = "Life Watcher", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [triggered(life_gained(), [put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, SourceSelection.new())])]
	all.append_array(abilities)
	return creature(card_name, 2, 1, all)


# --- Card track: a player's Nth spell each turn ----------------------------------------------


## "Whenever [param whose] cast(s) [their] [param nth] spell each turn" (CR 601.2i).
static func nth_spell(nth: int, whose: MmTrigger.Whose = MmTrigger.Whose.YOU) -> SpellCastTrigger:
	var trigger: SpellCastTrigger = casts(null, whose)
	trigger.nth_each_turn = nth
	return trigger


## "The [param nth] spell you cast each turn costs {[param amount]} less to cast", or "Spells
## you cast cost ..." with no [param nth].
static func spells_cost_less(amount: int = 1, nth: int = 2) -> SpellsCostLessAbility:
	var ability: SpellsCostLessAbility = SpellsCostLessAbility.new()
	ability.amount = amount
	ability.nth_each_turn = nth
	return ability


## A 1/4 creature costing {0} with Highspire Bell-Ringer's ability: "The second spell you
## cast each turn costs {1} less to cast."
static func ringer(card_name: String = "Ringer") -> MmCardDefinition:
	return creature(card_name, 1, 4, [spells_cost_less()])


## A 2/2 creature costing {0} with Clarion Spirit's ability, gaining 1 life: "Whenever you
## cast your second spell each turn, you gain 1 life."
static func clarion(card_name: String = "Clarion") -> MmCardDefinition:
	return creature(card_name, 2, 2, [triggered(nth_spell(2), [gain_life(1, you())])])


# --- Card track: casting this spell, and copying spells -----------------------------------


## "When you cast this spell" (CR 601.2i), which works while its card is on the stack
## (CR 113.6k).
static func cast_this_spell() -> SpellCastTrigger:
	return casts(IsSourceFilter.new(), MmTrigger.Whose.YOU)


## "Copy [param selection]" (CR 707.10): "copy this spell" unless another Selection is given.
static func copy_spell(selection: MmSelection = null) -> CopySpellEffect:
	var effect: CopySpellEffect = CopySpellEffect.new()
	effect.selection = selection if selection != null else SourceSelection.new()
	return effect


## A 2/3 costing {0} after Sage of the Skies: "When you cast this spell, if you've cast
## another spell this turn, copy this spell." and flying.
static func sage(card_name: String = "Sage") -> MmCardDefinition:
	return creature(card_name, 2, 3, [triggered(cast_this_spell(), [copy_spell()], [], CastAnotherSpellThisTurnCondition.new()),
		FlyingAbility.new()])


## An instant costing {0}: "Copy target spell." (CR 707.10).
static func free_twin(card_name: String = "Twin") -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target_spell()], [copy_spell(targeted(0))])


# --- Card track: looking at the top cards ------------------------------------------------


## "Look at the top [param amount] cards of your library. You may reveal a [param filter]
## card from among them and put it into your hand. Put the rest on the bottom of your library
## in a random order." (CR 701.20e).
static func look_at_top(amount: int, filter: MmFilter) -> LookAtTopCardsEffect:
	var effect: LookAtTopCardsEffect = LookAtTopCardsEffect.new()
	effect.amount = constant(amount)
	effect.filter = filter
	return effect


## A 2/3 costing {0} after Militia Bugler: "When this creature enters, look at the top four
## cards of your library. You may reveal a creature card with power 2 or less from among them
## and put it into your hand. Put the rest on the bottom of your library in a random order."
static func bugler(card_name: String = "Bugler") -> MmCardDefinition:
	var small: AllOfFilter = all_of([of_type(MmCardTypes.CardType.CREATURE), power(2)])
	return creature(card_name, 2, 3, [triggered(enters(IsSourceFilter.new()), [look_at_top(4, small)])])


## A 2/2 flier costing {0} after Faerie Mechanist: "When this creature enters, look at the
## top three cards of your library. You may reveal an artifact card from among them and put
## it into your hand. Put the rest on the bottom of your library in any order."
static func mechanist(card_name: String = "Mechanist") -> MmCardDefinition:
	var look: LookAtTopCardsEffect = look_at_top(3, of_type(MmCardTypes.CardType.ARTIFACT))
	look.is_rest_in_any_order = true
	return creature(card_name, 2, 2, [FlyingAbility.new(), triggered(enters(IsSourceFilter.new()), [look])])


# --- Card track: discarding, and "unless" ---------------------------------------------------


## "[param players] discard(s) [param amount] cards" (CR 701.9a): "discard a card" for you.
static func discard(amount: int = 1, players: MmSelection = null) -> DiscardEffect:
	var effect: DiscardEffect = DiscardEffect.new()
	effect.amount = constant(amount)
	effect.players = players if players != null else you()
	return effect


## "[param effect] unless [param condition]" (CR 608.2c).
static func unless(condition: MmCondition, effect: MmEffect) -> IfEffect:
	var conditional: IfEffect = if_then(condition, effect)
	conditional.is_unless = true
	return conditional


## A 2/1 creature costing {0} with Splitskin Doll's ability: "When this creature enters, draw
## a card. Then discard a card unless you control another creature with power 2 or less."
static func doll(card_name: String = "Doll") -> MmCardDefinition:
	var small_other: MmFilter = all_of([of_type(MmCardTypes.CardType.CREATURE), is_not(IsSourceFilter.new()), power(2)])
	var effects: Array[MmEffect] = [draw_cards(1, you()), unless(at_least(count_yours(small_other), 1), discard())]
	return creature(card_name, 2, 1, [triggered(enters(IsSourceFilter.new()), effects)])


# --- Card track: putting cards on the bottom of libraries -----------------------------------


## "Put [param selection] on the bottom of its owner's library".
static func put_on_bottom(selection: MmSelection) -> PutOnBottomOfLibraryEffect:
	var effect: PutOnBottomOfLibraryEffect = PutOnBottomOfLibraryEffect.new()
	effect.selection = selection
	return effect


## A 4/6 creature costing {0} with Landscaper Colos's first ability: "When this creature
## enters, put target card from an opponent's graveyard on the bottom of their library."
static func colos(card_name: String = "Colos") -> MmCardDefinition:
	return creature(card_name, 4, 6, [triggered(enters(IsSourceFilter.new()), [put_on_bottom(targeted(0))],
		[target_graveyard_card(owned_by(MmTrigger.Whose.OPPONENT))])])


# --- Card track: evolve and skulk -----------------------------------------------------


## A creature costing {0} with evolve (CR 702.100a), a 0/1 unless other numbers are given,
## then [param abilities].
static func evolver(card_name: String = "Raptor", power: int = 0, toughness: int = 1,
		abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [EvolveAbility.new()]
	all.append_array(abilities)
	return creature(card_name, power, toughness, all)


## A 1/1 creature costing {0} with skulk (CR 702.118b), then [param abilities].
static func skulker(card_name: String = "Sneak", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [SkulkAbility.new()]
	all.append_array(abilities)
	return creature(card_name, 1, 1, all)


# --- Card track: drawing your second card each turn ------------------------------------


## "Whenever [whose] draw(s) [their] [Nth] card each turn" (CR 121.1, 603.2), or "a card"
## when [param nth] is 0.
static func draws(nth: int = 0, whose: MmTrigger.Whose = MmTrigger.Whose.YOU) -> CardDrawnTrigger:
	var trigger: CardDrawnTrigger = CardDrawnTrigger.new()
	trigger.nth_each_turn = nth
	trigger.whose = whose
	return trigger


## A 1/2 creature costing {0} with Faerie Vandal's ability, gaining 1 life: "Whenever you
## draw your second card each turn, you gain 1 life."
static func vandal(card_name: String = "Vandal") -> MmCardDefinition:
	return creature(card_name, 1, 2, [triggered(draws(2), [gain_life(1, you())])])


# --- Card track: prowess ---------------------------------------------------------------


## [param trigger] only during [param whose] turn: "during an opponent's turn".
static func during_turn(trigger: SpellCastTrigger, whose: MmTrigger.Whose) -> SpellCastTrigger:
	trigger.during_whose_turn = whose
	return trigger


## A 2/1 creature costing {0} after Brineborn Cutthroat's ability, gaining 1 life:
## "Whenever you cast a spell during an opponent's turn, you gain 1 life."
static func cutthroat(card_name: String = "Cutthroat") -> MmCardDefinition:
	var trigger: SpellCastTrigger = during_turn(casts(null, MmTrigger.Whose.YOU), MmTrigger.Whose.OPPONENT)
	return creature(card_name, 2, 1, [triggered(trigger, [gain_life(1, you())])])


## "If you do, [param effect]." (CR 608.2c): after a "you may", [param effect] happens only
## if it was answered yes.
static func if_you_do(effect: MmEffect) -> IfEffect:
	return if_then(YouDidCondition.new(), effect)


## A 1/1 creature costing {0} after Riddlesmith's ability: "When this creature enters, you
## may draw a card. If you do, discard a card."
static func looter(card_name: String = "Looter") -> MmCardDefinition:
	return creature(card_name, 1, 1, [triggered(enters(IsSourceFilter.new()), [may(draw_cards(1, you())), if_you_do(discard())])])


## "Return [param count] [param filter] to its owner's hand" as a cost: "return a permanent
## you control to its owner's hand" unless another Filter is given.
static func return_permanents(count: int = 1, filter: MmFilter = null) -> ReturnPermanentsCost:
	var cost: ReturnPermanentsCost = ReturnPermanentsCost.new()
	cost.count = count
	if filter == null:
		var yours: ControlledByFilter = ControlledByFilter.new()
		yours.whose = MmTrigger.Whose.YOU
		filter = yours
	cost.filter = filter
	return cost


## "As an additional cost to cast this spell, [param costs]" (CR 601.2f, 118.8).
static func additional_cost(costs: Array[MmCost]) -> AdditionalCostAbility:
	var ability: AdditionalCostAbility = AdditionalCostAbility.new()
	ability.costs = costs
	return ability


## A 2/3 creature with flying costing {0} unless another cost is given, after Fear of
## Isolation: "As an additional cost to cast this spell, return a permanent you control to
## its owner's hand."
static func isolation(card_name: String = "Isolation", cost: MmManaCost = null) -> MmCardDefinition:
	var costs: Array[MmCost] = [return_permanents()]
	var definition: MmCardDefinition = creature(card_name, 2, 3, [additional_cost(costs), FlyingAbility.new()])
	if cost != null:
		definition.mana_cost = cost
	return definition


## A 4/5 creature costing {0}, after Makeshift Mauler: "As an additional cost to cast this
## spell, exile a creature card from your graveyard."
static func mauler(card_name: String = "Mauler") -> MmCardDefinition:
	var costs: Array[MmCost] = [exile_from_graveyard()]
	return creature(card_name, 4, 5, [additional_cost(costs)])


## "Whenever one or more [param filter] leave the battlefield without dying" (CR 700.4):
## from the battlefield to any zone but the graveyard, once for each batch.
static func leave_without_dying(filter: MmFilter) -> ZoneChangeTrigger:
	var trigger: ZoneChangeTrigger = ZoneChangeTrigger.new()
	trigger.any_from_zone = false
	trigger.from_zone = MmZone.Kind.BATTLEFIELD
	trigger.to_zone = MmZone.Kind.GRAVEYARD
	trigger.is_except_to_zone = true
	trigger.is_one_or_more = true
	trigger.filter = filter
	return trigger


## A 1/3 creature costing {0} after Dour Port-Mage's first ability, gaining 1 life:
## "Whenever one or more other creatures you control leave the battlefield without dying, you
## gain 1 life."
static func port_mage(card_name: String = "Port-Mage") -> MmCardDefinition:
	return creature(card_name, 1, 3, [triggered(leave_without_dying(other_creature_you_control()), [gain_life(1, you())])])


## A 1/1 creature costing {0} with prowess (CR 702.108a), then [param abilities].
static func monk(card_name: String = "Monk", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [ProwessAbility.new()]
	all.append_array(abilities)
	return creature(card_name, 1, 1, all)


# --- Card track: reflexive triggers --------------------------------------------------


## "Exile a [param filter] card from your graveyard", a creature card unless another
## Filter is given; with [param count], "exile [count] [filter] cards".
static func exile_from_graveyard(filter: MmFilter = null, count: int = 1) -> ExileFromGraveyardCost:
	var cost: ExileFromGraveyardCost = ExileFromGraveyardCost.new()
	cost.filter = of_type(MmCardTypes.CardType.CREATURE) if filter == null else filter
	cost.count = count
	return cost


## "When you do, [param effects]" (CR 603.12), with its own [param targets].
static func reflexive(effects: Array[MmEffect], targets: Array[TargetRequirement] = []) -> ReflexiveTriggerEffect:
	var effect: ReflexiveTriggerEffect = ReflexiveTriggerEffect.new()
	effect.ability = triggered(null, effects, targets)
	return effect


## "Target instant or sorcery card from your graveyard."
static func your_dead_spell() -> TargetRequirement:
	return target_graveyard_card(all_of([instant_or_sorcery(), owned_by(MmTrigger.Whose.YOU)]))


## A 3/2 creature costing {0} with Kishla Trawlers's ability: "When this creature enters, you
## may exile a creature card from your graveyard. When you do, return target instant or
## sorcery card from your graveyard to your hand."
static func trawler(card_name: String = "Trawler") -> MmCardDefinition:
	var returns: ReflexiveTriggerEffect = reflexive([return_to_hand(targeted(0))], [your_dead_spell()])
	return creature(card_name, 3, 2, [triggered(enters(IsSourceFilter.new()), [may_pay(exile_from_graveyard(), returns)])])


## "Sacrifice [param count] [param filter]" (CR 701.21a), "an artifact" unless another
## Filter is given.
static func sacrifice_permanents(count: int = 1, filter: MmFilter = null) -> SacrificePermanentsCost:
	var cost: SacrificePermanentsCost = SacrificePermanentsCost.new()
	cost.count = count
	cost.filter = of_type(MmCardTypes.CardType.ARTIFACT) if filter == null else filter
	return cost


## A 3/4 artifact creature costing {0} with Selfcraft Mechan's ability: "When this creature
## enters, you may sacrifice an artifact. When you do, put a +1/+1 counter on target creature
## and draw a card."
static func mechan(card_name: String = "Mechan") -> MmCardDefinition:
	var effects: Array[MmEffect] = [put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, targeted(0)), draw_cards(1, you())]
	var rewards: ReflexiveTriggerEffect = reflexive(effects, [target(of_type(MmCardTypes.CardType.CREATURE))])
	var definition: MmCardDefinition = creature(card_name, 3, 4,
		[triggered(enters(IsSourceFilter.new()), [may_pay(sacrifice_permanents(), rewards)])])
	definition.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	return definition


# --- Card track: bestow ---------------------------------------------------------------


## "Bestow [param cost]" (CR 702.103a), {0} unless another cost is given.
static func bestow(cost: MmManaCost = null) -> BestowAbility:
	var ability: BestowAbility = BestowAbility.new()
	ability.mana_cost = mana_cost(0) if cost == null else cost
	return ability


## A 2/2 Enchantment Creature — Nymph costing {0}, or [param cost], after Nimbus Naiad: "Bestow
## {0}", or [param bestow_cost], "Flying" and "Enchanted creature gets +2/+2 and has flying."
static func naiad(card_name: String = "Naiad", cost: MmManaCost = null, bestow_cost: MmManaCost = null) -> MmCardDefinition:
	var definition: MmCardDefinition = creature(card_name, 2, 2, [bestow(bestow_cost), FlyingAbility.new(),
		continuous_static([modify_pt(2, 2, attached()), gain_abilities([FlyingAbility.new()], attached())])], cost)
	definition.card_types = [MmCardTypes.CardType.ENCHANTMENT, MmCardTypes.CardType.CREATURE]
	definition.subtypes = ["Nymph"]
	return definition


## The index of the priority action that casts [param object_id] bestowed, or plainly when
## [param bestowed] is false, or -1.
static func cast_index_bestowed(decision: PriorityDecision, object_id: int, bestowed: bool = true) -> int:
	return action_index(decision, func(action: MmAction) -> bool:
		var cast: CastSpellAction = action as CastSpellAction
		return cast != null and cast.object_id == object_id and not cast.as_adventure and cast.is_bestowed == bestowed)


## Casts [param object_id] bestowed, aimed at [param chosen], and pays automatically.
static func cast_bestowed(engine: MmEngine, object_id: int, chosen: MmReference) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = cast_index_bestowed(decision, object_id)
	if index == -1:
		return "Object %d cannot be cast bestowed." % object_id
	var error: String = engine.submit(index)
	if error == "" and engine.pending_decision() is ChooseTargetDecision:
		error = choose_target(engine, chosen)
	return error if error != "" else auto_pay(engine)


# --- Card track: alternative costs ----------------------------------------------------


## "You may pay [param cost] and [param costs] rather than pay this spell's mana cost"
## (CR 118.9, engine ADR 0093).
static func alternative_cost(cost: MmManaCost, costs: Array[MmCost] = []) -> AlternativeCostAbility:
	var ability: AlternativeCostAbility = AlternativeCostAbility.new()
	ability.mana_cost = cost
	ability.costs = costs
	return ability


## "Tap [param count] untapped artifacts you control", as Zahid's "tap an untapped artifact
## you control" is.
static func tap_artifacts(count: int = 1) -> TapCreaturesCost:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var cost: TapCreaturesCost = TapCreaturesCost.new()
	cost.count = count
	cost.filter = all_of([of_type(MmCardTypes.CardType.ARTIFACT), untapped(), mine])
	return cost


## A 5/6 flier costing [param cost] ({4}{W}{W} unless another is given), after Zahid, Djinn
## of the Lamp: "You may pay {3}{W} and tap an untapped artifact you control rather than
## pay this spell's mana cost."
static func djinn(card_name: String = "Djinn", cost: MmManaCost = null) -> MmCardDefinition:
	var alternative: AlternativeCostAbility = alternative_cost(mana_cost(3, [MmMana.Type.WHITE]), [tap_artifacts()])
	return creature(card_name, 5, 6, [alternative, FlyingAbility.new()],
		mana_cost(4, [MmMana.Type.WHITE, MmMana.Type.WHITE]) if cost == null else cost)


## The index of the priority action that casts [param object_id] for its alternative cost,
## or for its mana cost when [param alternative] is false, or -1.
static func cast_index_alternative(decision: PriorityDecision, object_id: int, alternative: bool = true) -> int:
	return action_index(decision, func(action: MmAction) -> bool:
		var cast: CastSpellAction = action as CastSpellAction
		return cast != null and cast.object_id == object_id and not cast.as_adventure and not cast.is_bestowed \
			and cast.is_for_alternative_cost == alternative)


# --- Card track: explore --------------------------------------------------------------


## "[param selection] explores" (CR 701.44a), "this creature" unless another is given.
static func explore(selection: MmSelection = null) -> ExploreEffect:
	var effect: ExploreEffect = ExploreEffect.new()
	effect.selection = SourceSelection.new() if selection == null else selection
	return effect


## A 1/1 creature costing {0}: "When this creature enters, it explores."
static func explorer(card_name: String = "Explorer") -> MmCardDefinition:
	return creature(card_name, 1, 1, [triggered(enters(IsSourceFilter.new()), [explore()])])


## A Map made in code (CR 111.10): "{1}, {T}, Sacrifice this token: Target creature you
## control explores. Activate only as a sorcery."
static func map() -> MmCardDefinition:
	var definition: MmCardDefinition = MmCardDefinition.new()
	definition.name = "Map Token"
	definition.card_types = [MmCardTypes.CardType.ARTIFACT]
	definition.subtypes = ["Map"]
	var ability: ActivatedAbility = activated(mana_cost(1), [TapCost.new(), SacrificeThisCost.new()],
		[explore(targeted(0))], [target(all_of([of_type(MmCardTypes.CardType.CREATURE), ControlledByFilter.new()]))])
	ability.is_sorcery_speed = true
	definition.abilities = [ability]
	return definition


## Passes priority and answers everything else as autoplay() does, until an explore asks
## what to do with the card it revealed.
static func pass_to_explore(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is ExploreDecision)


# --- Card track: becoming an artifact creature ------------------------------------------


## Layer 4: "[affected] becomes a [card types]", keeping its other types (CR 205.1b).
static func add_card_types(card_types: Array[MmCardTypes.CardType], affected: MmSelection) -> AddCardTypesContinuousEffect:
	var effect: AddCardTypesContinuousEffect = AddCardTypesContinuousEffect.new()
	effect.card_types = card_types
	effect.affected = affected
	return effect


## [param continuous] from a resolved spell or ability with no duration, which lasts for
## the rest of the encounter (CR 611.2a).
static func indefinitely(continuous: MmContinuousEffect) -> CreateContinuousEffect:
	var effect: CreateContinuousEffect = CreateContinuousEffect.new()
	effect.continuous = continuous
	effect.duration = CreateContinuousEffect.Duration.INDEFINITELY
	return effect


## "Noncreature artifact you control".
static func noncreature_artifact_you_control() -> AllOfFilter:
	return all_of([of_type(MmCardTypes.CardType.ARTIFACT), is_not(of_type(MmCardTypes.CardType.CREATURE)),
		ControlledByFilter.new()])


## A sorcery costing {0} after Bring to Life: "Target noncreature artifact you control
## becomes a 0/0 artifact creature. Put four +1/+1 counters on it."
static func free_animate(card_name: String = "Animate") -> MmCardDefinition:
	var both: Array[MmCardTypes.CardType] = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	return sorcery(card_name, mana_cost(0), [target(noncreature_artifact_you_control())], [
		indefinitely(add_card_types(both, targeted(0))), indefinitely(set_pt(0, 0, targeted(0))),
		put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 4, targeted(0))])


# --- Card track: raid -------------------------------------------------------------------


## "If you attacked this turn" (raid): true while the controller declared an attacker this
## turn.
static func attacked_this_turn() -> AttackedThisTurnCondition:
	return AttackedThisTurnCondition.new()


## A 2/1 costing {0} after Mardu Skullhunter's raid ability, with a gain of life in place of
## the discard: "When this creature enters, if you attacked this turn, you gain 1 life."
static func skullhunter(card_name: String = "Skullhunter") -> MmCardDefinition:
	var effects: Array[MmEffect] = [gain_life(1, you())]
	return creature(card_name, 2, 1, [triggered(enters(IsSourceFilter.new()), effects, [], attacked_this_turn())])



# --- Card track: undying ----------------------------------------------------------------


## A 1/1 costing {0} with undying (CR 702.93a), then [param abilities].
static func ghoul(card_name: String = "Ghoul", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [UndyingAbility.new()]
	all.append_array(abilities)
	return creature(card_name, 1, 1, all)


## An instant costing {0}: "Exile target card from a graveyard."
static func free_bury(card_name: String = "Bury") -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target_graveyard_card()], [exile(targeted(0))])


# --- Card track: replacing a draw -------------------------------------------------------


## "[param value] is [param amount] or less" (engine ADR 0097).
static func at_most(value: MmValue, amount: int) -> ValueAtMostCondition:
	var condition: ValueAtMostCondition = ValueAtMostCondition.new()
	condition.value = value
	condition.amount = amount
	return condition


## "If you would draw a card while [param condition], instead [param instead]" (CR 614.1a,
## 614.11, engine ADR 0097).
static func draw_replacement(condition: MmCondition, instead: Array[MmEffect]) -> DrawReplacementAbility:
	var ability: DrawReplacementAbility = DrawReplacementAbility.new()
	ability.condition = condition
	ability.instead = instead
	return ability


## A 2/1 costing {0} with Blood Scrivener's ability: "If you would draw a card while you
## have no cards in hand, instead you draw two cards and you lose 1 life."
static func scrivener(card_name: String = "Scrivener") -> MmCardDefinition:
	var hand: HandSizeValue = HandSizeValue.new()
	hand.players = you()
	var instead: Array[MmEffect] = [draw_cards(2, you()), lose_life(1, you())]
	return creature(card_name, 2, 1, [draw_replacement(at_most(hand, 0), instead)])


# --- Card track: "if you gained life this turn" ---------------------------------------------

## "You gained life this turn" (engine ADR 0082's addendum).
static func gained_life_this_turn() -> GainedLifeThisTurnCondition:
	return GainedLifeThisTurnCondition.new()


## A 2/2 costing {0} with Poisoner's Apprentice's ability: "When this creature enters, target
## creature an opponent controls gets -4/-4 until end of turn if you gained life this turn."
static func apprentice(card_name: String = "Apprentice") -> MmCardDefinition:
	var shrink: IfEffect = if_then(gained_life_this_turn(), until_end_of_turn(modify_pt(-4, -4, targeted(0))))
	return creature(card_name, 2, 2, [triggered(enters(IsSourceFilter.new()), [shrink], [target(creature_you_dont_control())])])


# --- Card track: "if an opponent lost life this turn" -----------------------------------------

## "[param whose] lost life this turn" ("an opponent" unless another is given), engine ADR
## 0082's second addendum.
static func lost_life_this_turn(whose: MmTrigger.Whose = MmTrigger.Whose.OPPONENT) -> LostLifeThisTurnCondition:
	var condition: LostLifeThisTurnCondition = LostLifeThisTurnCondition.new()
	condition.whose = whose
	return condition


## A 4/2 costing {0} after Bat Whisperer, with a gain of life in place of the Bat: "When this
## creature enters, if an opponent lost life this turn, you gain 1 life."
static func whisperer(card_name: String = "Whisperer") -> MmCardDefinition:
	var effects: Array[MmEffect] = [gain_life(1, you())]
	return creature(card_name, 4, 2, [triggered(enters(IsSourceFilter.new()), effects, [], lost_life_this_turn())])


# --- Card track: a sacrifice effect ----------------------------------------------------------

## "[param players] sacrifice(s) [param count] [param filter]" ("each opponent sacrifices a
## creature" unless others are given), the effect, not the cost (CR 701.21a).
static func sacrifice(players: MmSelection = null, filter: MmFilter = null, count: int = 1) -> SacrificeEffect:
	var effect: SacrificeEffect = SacrificeEffect.new()
	effect.players = players if players != null else EachOpponentSelection.new()
	effect.filter = filter if filter != null else of_type(MmCardTypes.CardType.CREATURE)
	effect.count = count
	return effect


## An instant costing {0}: "Each opponent sacrifices a creature."
static func free_edict(card_name: String = "Edict") -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [], [sacrifice()])


## Passes priority until a player is asked which permanents to pick.
static func pass_to_permanents_choice(engine: MmEngine) -> String:
	return autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is ChoosePermanentsDecision)


# --- Card track: "the sacrificed creature" ----------------------------------------------------

## "The sacrificed creature", or "that creature" after a sacrifice: what the spell or ability
## sacrificed, as a cost or by an earlier effect, as it last existed (engine ADR 0098).
static func sacrificed() -> SacrificedSelection:
	return SacrificedSelection.new()


## "Another creature", as a sacrifice says it.
static func another_creature() -> AllOfFilter:
	return all_of([of_type(MmCardTypes.CardType.CREATURE), is_not(IsSourceFilter.new())])


## A 2/4 costing {0} with Bushmeat Poacher's ability at {0}: "{0}, {T}, Sacrifice another
## creature: You gain life equal to the sacrificed creature's toughness. Draw a card."
static func poacher(card_name: String = "Poacher") -> MmCardDefinition:
	var toughness: ToughnessValue = ToughnessValue.new()
	toughness.selection = sacrificed()
	var gain: GainLifeEffect = GainLifeEffect.new()
	gain.amount = toughness
	gain.players = you()
	var costs: Array[MmCost] = [TapCost.new(), sacrifice_permanents(1, another_creature())]
	return creature(card_name, 2, 4, [activated(mana_cost(0), costs, [gain, draw_cards(1, you())])])


## A 2/2 costing {0} with Heartfire Immolator's second ability at {0}: "{0}, Sacrifice this
## creature: It deals damage equal to its power to target creature." (engine ADR 0098's
## addendum), then [param abilities].
static func immolator(card_name: String = "Immolator", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var power: PowerValue = PowerValue.new()
	power.selection = sacrificed()
	var damage: DealDamageEffect = DealDamageEffect.new()
	damage.amount = power
	damage.recipients = targeted(0)
	var all: Array[MmAbility] = abilities.duplicate()
	all.append(activated(mana_cost(0), [SacrificeThisCost.new()], [damage], [target(of_type(MmCardTypes.CardType.CREATURE))]))
	return creature(card_name, 2, 2, all)


## A 2/1 costing {0} with Disciple of Bolas's ability: "When this creature enters, sacrifice
## another creature. You gain X life and draw X cards, where X is that creature's power."
static func disciple(card_name: String = "Disciple") -> MmCardDefinition:
	var power_for_life: PowerValue = PowerValue.new()
	power_for_life.selection = sacrificed()
	var gain: GainLifeEffect = GainLifeEffect.new()
	gain.amount = power_for_life
	gain.players = you()
	var power_for_cards: PowerValue = PowerValue.new()
	power_for_cards.selection = sacrificed()
	var draw: DrawCardsEffect = DrawCardsEffect.new()
	draw.amount = power_for_cards
	draw.players = you()
	var effects: Array[MmEffect] = [sacrifice(you(), another_creature()), gain, draw]
	return creature(card_name, 2, 1, [triggered(enters(IsSourceFilter.new()), effects)])


# --- Card track: Role tokens ------------------------------------------------------------------

## "When [filter] is put into a graveyard from the battlefield", which a permanent that is no
## creature says rather than "dies" (CR 700.4).
static func put_into_graveyard(filter: MmFilter) -> ZoneChangeTrigger:
	return dies(filter)


## A colorless Enchantment — Aura Role token made in code, after the Wicked Role: "Enchant
## creature", "Enchanted creature gets +1/+1" and "When this Aura is put into a graveyard,
## each opponent loses 1 life." Another Filter it may enchant may be given.
static func role(card_name: String = "Wicked Role", enchanted: MmFilter = null) -> MmCardDefinition:
	var lose: LoseLifeEffect = LoseLifeEffect.new()
	lose.amount = constant(1)
	lose.players = EachOpponentSelection.new()
	var definition: MmCardDefinition = MmCardDefinition.new()
	definition.name = card_name
	definition.card_types = [MmCardTypes.CardType.ENCHANTMENT]
	definition.subtypes = ["Aura", "Role"]
	definition.abilities = [enchant(enchanted if enchanted != null else of_type(MmCardTypes.CardType.CREATURE)),
		continuous_static([modify_pt(1, 1, attached())]),
		triggered(put_into_graveyard(IsSourceFilter.new()), [lose])]
	return definition


## "Create [param made] attached to [param to]" (CR 111.2, 303.4).
static func created_attached(made: MmCardDefinition, to: MmSelection) -> CreateTokenEffect:
	var effect: CreateTokenEffect = create_tokens(made)
	effect.attached_to = to
	return effect


## An instant costing {0} after Price of Beauty: "Create a Wicked Role token attached to
## target creature you control." Another Role may be given.
static func free_role(card_name: String = "Price", made: MmCardDefinition = null) -> MmCardDefinition:
	return instant(card_name, mana_cost(0), [target(creature_you_control())],
		[created_attached(made if made != null else role(), targeted(0))])


# --- Card track: improvise ----------------------------------------------------------------------


## An instant costing [param cost] with improvise (CR 702.126a): "You gain 1 life."
static func improviser(card_name: String, cost: MmManaCost) -> MmCardDefinition:
	var definition: MmCardDefinition = instant(card_name, cost, [], [gain_life(1, you())])
	definition.abilities.push_front(ImproviseAbility.new())
	return definition


## Pays one step of the pending payment by tapping [param object_id] for improvise.
static func improvise_with(engine: MmEngine, object_id: int) -> String:
	var decision: PayManaDecision = engine.pending_decision() as PayManaDecision
	if decision == null:
		return "Not a payment decision."
	var index: int = action_index(decision_as_actions(decision), func(action: MmAction) -> bool:
		return action is ImproviseAction and (action as ImproviseAction).object_id == object_id)
	return "Object %d cannot improvise." % object_id if index == -1 else engine.submit(index)


## The objects the pending payment offers to tap for improvise.
static func improvisers_offered(engine: MmEngine) -> Array[int]:
	var offered: Array[int] = []
	var decision: PayManaDecision = engine.pending_decision() as PayManaDecision
	if decision == null:
		return offered
	for action: MmAction in decision.actions:
		if action is ImproviseAction:
			offered.append((action as ImproviseAction).object_id)
	return offered
