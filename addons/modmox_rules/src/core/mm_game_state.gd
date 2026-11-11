class_name MmGameState
extends RefCounted
## Everything true about an encounter at one moment: players, zones, Game Objects, the
## Game RNG and the event log. Changes happen only through perform() (ADR 0007).

const NO_PLAYER: int = -1

## Players indexed by ID. Exactly two (ADR 0001).
var players: Array[MmPlayer] = []
var battlefield: MmZone = MmZone.new(MmZone.Kind.BATTLEFIELD)
## The top of the stack is its last object.
var stack: MmZone = MmZone.new(MmZone.Kind.STACK)
var exile: MmZone = MmZone.new(MmZone.Kind.EXILE)
var command: MmZone = MmZone.new(MmZone.Kind.COMMAND)
var game_rng: MmRng
var starting_player_id: int = NO_PLAYER
## The count of all turns begun by either player; 0 during the pregame.
var game_turn: int = 0
var active_player_id: int = NO_PLAYER
var step: MmTurn.Step = MmTurn.Step.NONE
## The current combat; empty outside combat.
var combat: MmCombat = MmCombat.new()
## Whether the encounter has ended (CR 104), and who won: MmGameState.NO_PLAYER for a draw.
var is_over: bool = false
var winner_id: int = NO_PLAYER
## Triggered abilities waiting to be put on the stack, in the order they triggered.
var pending_triggers: Array[PendingTrigger] = []
## Continuous effects created by resolved spells and abilities, until they end (CR 611.2).
var continuous_effects: Array[ActiveContinuousEffect] = []
## Replacement and prevention effects created by resolved spells and abilities, in the
## order they were created, until they end or are used up (ADR 0019).
var replacement_effects: Array[ActiveReplacementEffect] = []
## The batch waiting for a replacement choice, or null (A143). Nothing else can be
## performed until it is answered.
var suspended_batch: SuspendedBatch = null
## Every event performed, in order. Read-only outside perform(). Events never change once
## applied, so copies of the state share them.
var event_log: Array[MmEvent] = []

var _objects: Dictionary[int, MmGameObject] = {}
var _run_cards: Dictionary[int, MmRunCard] = {}
var _next_object_id: int = 1
var _next_card_id: int = 1
var _next_batch: int = 0
## Objects that have left the battlefield, frozen with their last-known information.
var _departed: Dictionary[int, MmGameObject] = {}
## ADR 0018: the layer engine's results for the battlefield and command zone, kept until
## the next event. Not game state: copies start without it.
var _layer_results: Dictionary[int, MmCharacteristics] = {}
var _layer_results_valid: bool = false
var _computing_layers: bool = false


## Builds the starting state of an encounter, or an empty state when [param setup] is null
## (used only by duplicate_state()).
func _init(setup: MmEncounterSetup) -> void:
	if setup == null:
		return
	game_rng = MmRng.for_game(setup.encounter_seed)
	players.append(MmPlayer.new(MmEncounterSetup.HERO_PLAYER_ID, setup.hero))
	players.append(MmPlayer.new(MmEncounterSetup.VILLAIN_PLAYER_ID, setup.villain))
	# CR 103.2: each deck becomes its owner's library, in deck order until shuffled.
	# This is the game's starting state rather than a change, so it is not an event.
	for player: MmPlayer in players:
		var player_setup: MmPlayerSetup = setup.hero if player.id == MmEncounterSetup.HERO_PLAYER_ID else setup.villain
		for run_card: MmRunCard in player_setup.deck:
			var card_id: int = _next_card_id
			_next_card_id += 1
			_run_cards[card_id] = run_card
			player.library.insert(create_object(card_id, player.id, run_card.flatten()), MmZone.BOTTOM)
	# ADR 0011 and CR 114: each player's Emblems start in the command zone. An Emblem is not
	# a card, so it has no Card Identity.
	for player: MmPlayer in players:
		var player_setup: MmPlayerSetup = setup.hero if player.id == MmEncounterSetup.HERO_PLAYER_ID else setup.villain
		for emblem: MmCardDefinition in player_setup.emblems:
			command.insert(create_object(MmGameObject.NO_CARD, player.id, emblem), MmZone.BOTTOM)


## An independent copy of this state: changing one never affects the other. Used for undo
## checkpoints and, later, AI lookahead.
func duplicate_state() -> MmGameState:
	var copy: MmGameState = MmGameState.new(null)
	for player: MmPlayer in players:
		copy.players.append(player.duplicate_without_objects())
	var original_zones: Array[MmZone] = _all_zones()
	var copied_zones: Array[MmZone] = copy._all_zones()
	for index: int in original_zones.size():
		for game_object: MmGameObject in original_zones[index].objects():
			var copied: MmGameObject = game_object.duplicate_object()
			copy._objects[copied.id] = copied
			copied_zones[index].insert(copied, MmZone.BOTTOM)
	copy.game_rng = game_rng.duplicate_stream()
	copy.starting_player_id = starting_player_id
	copy.game_turn = game_turn
	copy.active_player_id = active_player_id
	copy.step = step
	copy.combat = combat.duplicate_combat()
	copy.is_over = is_over
	copy.winner_id = winner_id
	copy.pending_triggers = pending_triggers.duplicate()  # Pending triggers never change.
	copy._departed = _departed.duplicate()  # Departed objects are frozen.
	copy._next_batch = _next_batch
	copy.continuous_effects = continuous_effects.duplicate()  # Active effects never change.
	copy.replacement_effects = replacement_effects.duplicate()  # Nor do these.
	copy.suspended_batch = null if suspended_batch == null else suspended_batch.copy_for(copy)
	copy.event_log = event_log.duplicate()
	copy._run_cards = _run_cards.duplicate()  # Run Cards are read-only during an encounter.
	copy._next_object_id = _next_object_id
	copy._next_card_id = _next_card_id
	return copy


## ADR 0020: re-deals the cards [param viewer_id] cannot see, for a Simulation Copy. The
## other player's hand and library are pooled and dealt back at random into the same
## places, and so is the viewer's own library, so every zone keeps its size and objects keep
## their IDs. The pool is sorted before shuffling, so two states that differ only in how
## those cards are arranged are re-dealt identically. This builds an imagined state rather
## than changing the game, so like the starting state (CR 103.2) it is not an event.
func randomize_hidden_cards(viewer_id: int, rng: MmRng) -> void:
	var other: MmPlayer = opponent_of(viewer_id)
	var unseen: Array[MmGameObject] = other.hand.objects()
	unseen.append_array(other.library.objects())
	_redeal(unseen, rng)
	_redeal(player(viewer_id).library.objects(), rng)


func player(id: int) -> MmPlayer:
	return players[id]


## The other player. Encounters are strictly 1v1 (ADR 0001).
func opponent_of(id: int) -> MmPlayer:
	return players[1 - id]


## Both players, starting player first (CR 101.4 turn order).
func turn_order() -> Array[MmPlayer]:
	assert(starting_player_id != NO_PLAYER, "The starting player has not been determined yet.")
	return [player(starting_player_id), opponent_of(starting_player_id)]


## The zone of [param kind] owned by [param owner_id] (MmZone.NO_OWNER for shared zones).
func zone(kind: MmZone.Kind, owner_id: int) -> MmZone:
	match kind:
		MmZone.Kind.LIBRARY:
			return player(owner_id).library
		MmZone.Kind.HAND:
			return player(owner_id).hand
		MmZone.Kind.GRAVEYARD:
			return player(owner_id).graveyard
		MmZone.Kind.BATTLEFIELD:
			return battlefield
		MmZone.Kind.STACK:
			return stack
		MmZone.Kind.EXILE:
			return exile
	return command


## The Game Object with [param id], or null if it no longer exists.
func object(id: int) -> MmGameObject:
	return _objects.get(id, null) as MmGameObject


## The Run Card a card came from, for presentation and rewards. Null for an object that is
## not a card.
func run_card_of(game_object: MmGameObject) -> MmRunCard:
	return run_card(game_object.card_id)


## The Run Card with Card Identity [param card_id], or null if there is none.
func run_card(card_id: int) -> MmRunCard:
	return _run_cards.get(card_id, null) as MmRunCard


## The current characteristics of [param game_object]. The only place, together with
## MmCharacteristics.printed(), that reads a Card Definition's fields (ADR 0009).
func characteristics_of(game_object: MmGameObject) -> MmCharacteristics:
	if game_object.last_known_characteristics != null:
		return game_object.last_known_characteristics  # CR 608.2h
	if game_object.definition == null:
		# CR 113.7a: an ability on the stack has no characteristics of its own beyond what
		# the GUI needs to name it.
		var ability_view: MmCharacteristics = MmCharacteristics.new()
		ability_view.name = "%s ability" % game_object.source_name
		return ability_view
	var holder: MmZone = game_object.zone()
	if holder != battlefield and holder != command:
		return LayerEngine.outside_the_battlefield(self, game_object)
	# ADR 0018: worked out for everything at once, layer by layer, and kept until the next
	# event. While that is happening, this answers with the layers applied so far.
	if not _computing_layers and not _layer_results_valid:
		_layer_results = LayerEngine.compute(self)
		_layer_results_valid = true
	if _layer_results.has(game_object.id):
		return _layer_results[game_object.id]
	return MmCharacteristics.printed(game_object.definition)


## CR 302.6: whether [param game_object] is a creature whose controller has not controlled
## it continuously since their most recent turn began. Such a creature cannot attack or pay
## {T} in a cost. A creature with haste never is, for these rules.
func is_summoning_sick(game_object: MmGameObject) -> bool:
	var characteristics: MmCharacteristics = characteristics_of(game_object)
	if game_object.zone() != battlefield or not characteristics.has_card_type(MmCardTypes.CardType.CREATURE):
		return false
	if characteristics.has_ability(HasteAbility):
		return false  # CR 702.10b
	return game_object.controlled_since_game_turn >= player(game_object.controller_id).latest_turn_game_turn


## Performs [param event] through the pipeline: replacement, then apply, then log, then
## triggers (ADR 0007). For callers that cannot stop for a decision (A145).
func perform(event: MmEvent) -> void:
	perform_together([event])


## Performs [param events] as one simultaneous batch (ADR 0017), as state-based actions and
## combat damage are (CR 704.3, 510.2). Triggers are looked for once, after all of them.
## For callers that cannot stop for a decision: nothing they perform may need a replacement
## choice (A145).
func perform_together(events: Array[MmEvent]) -> void:
	perform_resumably(events)
	# Later: make each such caller resumable when a card first replaces its events, as
	# Island Sanctuary would the draw step's draw.
	assert(suspended_batch == null, "A replacement choice came up where the engine cannot stop for one.")


## Performs [param events] as one batch, stopping part-way if a replacement choice is
## needed (A143). The caller must then check is_batch_suspended() and stop too; the batch
## carries on when choose_replacement_effect() is answered.
func perform_resumably(events: Array[MmEvent]) -> void:
	assert(suspended_batch == null, "A batch is waiting for a replacement choice.")
	_next_batch += 1
	_continue_batch(SuspendedBatch.new(_next_batch, TriggerDetection.observers(self), events))


## Whether a batch is waiting for a replacement choice.
func is_batch_suspended() -> bool:
	return suspended_batch != null


## The replacement choice the suspended batch is waiting for (CR 616.1).
func replacement_decision() -> ChooseReplacementEffectDecision:
	var event: MmEvent = suspended_batch.next_event()
	return ChooseReplacementEffectDecision.new(ReplacementRules.affected_player_id(self, event), event, suspended_batch.choices)


## Applies option [param index] of the replacement decision, and carries on with the batch.
func choose_replacement_effect(index: int) -> void:
	var batch: SuspendedBatch = suspended_batch
	suspended_batch = null
	_replace_next(batch, batch.choices[index])
	_continue_batch(batch)


## The object with [param id], or its frozen last-known version if it has left the
## battlefield (CR 608.2h), or null.
func object_or_last_known(id: int) -> MmGameObject:
	var live: MmGameObject = object(id)
	return live if live != null else _departed.get(id, null) as MmGameObject


## Cache only, for LayerEngine: answer characteristics queries from [param in_progress]
## while the layers are being applied.
func begin_layer_computation(in_progress: Dictionary[int, MmCharacteristics]) -> void:
	_layer_results = in_progress
	_computing_layers = true


## Cache only, for LayerEngine: the layers are all applied.
func end_layer_computation() -> void:
	_computing_layers = false


## Event-only: the next timestamp (CR 613.7). Object IDs come from the same counter, so an
## object's ID is its timestamp (A117, A127).
func next_timestamp() -> int:
	var timestamp: int = _next_object_id
	_next_object_id += 1
	return timestamp


## Event-only: a continuous effect starts.
func add_continuous_effect(active: ActiveContinuousEffect) -> void:
	continuous_effects.append(active)


## Event-only: a replacement or prevention effect starts.
func add_replacement_effect(active: ActiveReplacementEffect) -> void:
	replacement_effects.append(active)


## Event-only: [param amount] of the shield created at [param timestamp] is used. It ends
## once nothing is left.
func use_replacement_effect(timestamp: int, amount: int) -> void:
	for index: int in replacement_effects.size():
		var active: ActiveReplacementEffect = replacement_effects[index]
		if active.timestamp == timestamp:
			var left: int = active.remaining - amount
			if left > 0:
				replacement_effects[index] = active.with_remaining(left)
			else:
				replacement_effects.remove_at(index)
			return
	assert(false, "No replacement effect has timestamp %d." % timestamp)


## Event-only: every replacement effect with [param duration] ends. Returns how many did.
func end_replacement_effects(duration: CreateContinuousEffect.Duration) -> int:
	var staying: Array[ActiveReplacementEffect] = []
	for active: ActiveReplacementEffect in replacement_effects:
		if active.duration != duration:
			staying.append(active)
	var ending: int = replacement_effects.size() - staying.size()
	replacement_effects = staying
	return ending


## Event-only: every continuous effect with [param duration] ends. Returns how many did.
func end_continuous_effects(duration: CreateContinuousEffect.Duration) -> int:
	var ending: int = 0
	var staying: Array[ActiveContinuousEffect] = []
	for active: ActiveContinuousEffect in continuous_effects:
		if active.duration == duration:
			ending += 1
		else:
			staying.append(active)
	continuous_effects = staying
	return ending


## Event-only: records a triggered ability that has triggered.
func add_pending_trigger(pending: PendingTrigger) -> void:
	pending_triggers.append(pending)


## Event-only: a pending trigger goes on the stack or is removed.
func remove_pending_trigger(pending: PendingTrigger) -> void:
	pending_triggers.erase(pending)


## Event-only: keeps [param leaving], frozen, as it leaves the battlefield.
func record_departure(leaving: MmGameObject) -> void:
	_departed[leaving.id] = leaving


## Draws [param count] cards for a player, one at a time from the top (CR 121.2).
func draw_cards(player_id: int, count: int) -> void:
	for _index: int in count:
		perform(draw_event(player_id))


## The event of [param player_id] drawing their top card now.
func draw_event(player_id: int) -> MmEvent:
	var drawer: MmPlayer = player(player_id)
	if drawer.library.is_empty():
		# CR 121.4: the attempt is recorded, and the player loses at the next check (704.5b).
		return EmptyLibraryDrawEvent.new(player_id)
	return ZoneChangeEvent.new(drawer.library.top(), drawer.hand, MmZone.BOTTOM, ZoneChangeEvent.Reason.DRAW)


## Event-only: the encounter ends with [param winning_player_id] winning, or
## MmGameState.NO_PLAYER for a draw.
func end_encounter(winning_player_id: int) -> void:
	is_over = true
	winner_id = winning_player_id


## Event-only (and initial setup): creates a Game Object with the next free ID.
func create_object(card_id: int, owner_id: int, definition: MmCardDefinition) -> MmGameObject:
	var created: MmGameObject = MmGameObject.new(_next_object_id, card_id, owner_id, definition)
	_next_object_id += 1
	_objects[created.id] = created
	return created


## Event-only: the object has left its zone and stops existing (CR 400.7).
func retire_object(game_object: MmGameObject) -> void:
	_objects.erase(game_object.id)


## A hash of the whole state, equal for two states exactly when they match.
func fingerprint() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("starting player %d" % starting_player_id)
	lines.append("game turn %d active %d step %d" % [game_turn, active_player_id, step])
	lines.append("game rng %s" % game_rng.describe_state())
	lines.append(combat.describe())
	lines.append("over %s winner %d batch %d departed %d" % [is_over, winner_id, _next_batch, _departed.size()])
	for pending: PendingTrigger in pending_triggers:
		lines.append("pending " + pending.describe())
	for active: ActiveContinuousEffect in continuous_effects:
		lines.append("continuous " + active.describe())
	for active: ActiveReplacementEffect in replacement_effects:
		lines.append("replacement " + active.describe())
	if suspended_batch != null:
		lines.append("suspended " + suspended_batch.describe())
	lines.append("next ids %d %d" % [_next_object_id, _next_card_id])
	for each_player: MmPlayer in players:
		var mana: PackedStringArray = PackedStringArray()
		for unit: MmMana in each_player.mana_pool():
			mana.append(unit.describe())
		lines.append("player %d life %d mulligans %d turn %d since %d lands %d empty draw %s lost %s %d mana [%s]" % [
			each_player.id, each_player.life, each_player.mulligans_taken, each_player.turn_number,
			each_player.latest_turn_game_turn, each_player.lands_played_this_turn,
			each_player.has_drawn_from_empty_library, each_player.has_lost, each_player.loss_reason, ", ".join(mana)])
	for each_zone: MmZone in _all_zones():
		var entries: PackedStringArray = PackedStringArray()
		for game_object: MmGameObject in each_zone.objects():
			var target_text: PackedStringArray = PackedStringArray()
			for target: MmReference in game_object.targets:
				target_text.append("none" if target == null else target.describe())
			entries.append("%d:%d:%s:%d:%s:%d:%d:%d:%d:%d:[%s]" % [game_object.id, game_object.card_id, characteristics_of(game_object).name,
				game_object.controller_id, "tapped" if game_object.is_tapped else "untapped", game_object.damage_marked,
				game_object.controlled_since_game_turn, game_object.source_card_id, game_object.triggering_player_id,
				game_object.triggering_object_id, ",".join(target_text)])
			if game_object.was_dealt_deathtouch_damage:
				entries.append("deathtouch damage on %d" % game_object.id)
		lines.append("%s [%s]" % [each_zone.describe(), ", ".join(entries)])
	return "\n".join(lines).sha256_text()


## Gives [param places] the cards they hold, shuffled among them.
func _redeal(places: Array[MmGameObject], rng: MmRng) -> void:
	var cards: Array[MmGameObject] = places.duplicate()
	cards.sort_custom(func(first: MmGameObject, second: MmGameObject) -> bool: return first.card_id < second.card_id)
	var contents: Array = []
	for card: MmGameObject in cards:
		contents.append([card.card_id, card.definition])
	rng.shuffle_in_place(contents)
	for index: int in places.size():
		places[index].card_id = contents[index][0]
		places[index].definition = contents[index][1]


func _all_zones() -> Array[MmZone]:
	var zones: Array[MmZone] = []
	for each_player: MmPlayer in players:
		zones.append_array([each_player.library, each_player.hand, each_player.graveyard])
	zones.append_array([battlefield, stack, exile, command])
	return zones


## Performs the batch's events in order. Before each is applied, it is offered to the
## replacement and prevention effects that apply to it (CR 614, 615); what replaces it
## takes its place and is offered to the rest (CR 616.1, 616.2).
func _continue_batch(batch: SuspendedBatch) -> void:
	while batch.has_next_event():
		var event: MmEvent = batch.next_event()
		var choices: Array[ActiveReplacementEffect] = ReplacementRules.applicable(self, event, batch.next_applied_keys())
		if choices.is_empty():
			batch.take_next_event()
			event.batch = batch.number
			event.apply(self)
			_layer_results_valid = false
			event_log.append(event)
			batch.performed.append(event)
			continue
		var chosen: ActiveReplacementEffect = ReplacementRules.automatic_choice(choices)
		if chosen == null:
			batch.choices = choices
			suspended_batch = batch
			return
		_replace_next(batch, chosen)
	TriggerDetection.detect(self, batch.performed, batch.before)


func _replace_next(batch: SuspendedBatch, chosen: ActiveReplacementEffect) -> void:
	var event: MmEvent = batch.next_event()
	batch.replace_next_event(chosen.effect.replace(self, event, chosen), chosen.key())
