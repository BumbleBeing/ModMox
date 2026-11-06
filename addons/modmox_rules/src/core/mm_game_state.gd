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
## Every event performed, in order. Read-only outside perform(). Events never change once
## applied, so copies of the state share them.
var event_log: Array[MmEvent] = []

var _objects: Dictionary[int, MmGameObject] = {}
var _run_cards: Dictionary[int, MmRunCard] = {}
var _next_object_id: int = 1
var _next_card_id: int = 1


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
	copy.event_log = event_log.duplicate()
	copy._run_cards = _run_cards.duplicate()  # Run Cards are read-only during an encounter.
	copy._next_object_id = _next_object_id
	copy._next_card_id = _next_card_id
	return copy


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
	return _run_cards.get(game_object.card_id, null) as MmRunCard


## The current characteristics of [param game_object]. The only place, together with
## MmCharacteristics.printed(), that reads a Card Definition's fields (ADR 0009).
func characteristics_of(game_object: MmGameObject) -> MmCharacteristics:
	if game_object.definition == null:
		# CR 113.7a: an ability on the stack has no characteristics of its own beyond what
		# the GUI needs to name it.
		var ability_view: MmCharacteristics = MmCharacteristics.new()
		ability_view.name = "%s ability" % game_object.source_name
		return ability_view
	# Later (milestone 9): apply continuous effects in layer order (CR 613).
	return MmCharacteristics.printed(game_object.definition)


## Performs [param event] through the pipeline: replacement, then apply, then log (ADR 0007).
func perform(event: MmEvent) -> void:
	var final_event: MmEvent = _apply_replacement_effects(event)
	final_event.apply(self)
	event_log.append(final_event)


## Draws [param count] cards for a player, one at a time from the top (CR 121.2).
func draw_cards(player_id: int, count: int) -> void:
	var drawer: MmPlayer = player(player_id)
	for _index: int in count:
		if drawer.library.is_empty():
			# Later (milestone 7): record the attempt so the player loses (CR 121.4, 704.5b).
			return
		perform(ZoneChangeEvent.new(drawer.library.top(), drawer.hand, MmZone.BOTTOM, ZoneChangeEvent.Reason.DRAW))


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
	lines.append("next ids %d %d" % [_next_object_id, _next_card_id])
	for each_player: MmPlayer in players:
		var mana: PackedStringArray = PackedStringArray()
		for unit: MmMana in each_player.mana_pool():
			mana.append(unit.describe())
		lines.append("player %d life %d mulligans %d turn %d lands %d mana [%s]" % [
			each_player.id, each_player.life, each_player.mulligans_taken, each_player.turn_number,
			each_player.lands_played_this_turn, ", ".join(mana)])
	for each_zone: MmZone in _all_zones():
		var entries: PackedStringArray = PackedStringArray()
		for game_object: MmGameObject in each_zone.objects():
			var target_text: PackedStringArray = PackedStringArray()
			for target: MmReference in game_object.targets:
				target_text.append("none" if target == null else target.describe())
			entries.append("%d:%d:%s:%d:%s:[%s]" % [game_object.id, game_object.card_id, characteristics_of(game_object).name,
				game_object.controller_id, "tapped" if game_object.is_tapped else "untapped", ",".join(target_text)])
		lines.append("%s [%s]" % [each_zone.describe(), ", ".join(entries)])
	return "\n".join(lines).sha256_text()


func _all_zones() -> Array[MmZone]:
	var zones: Array[MmZone] = []
	for each_player: MmPlayer in players:
		zones.append_array([each_player.library, each_player.hand, each_player.graveyard])
	zones.append_array([battlefield, stack, exile, command])
	return zones


func _apply_replacement_effects(event: MmEvent) -> MmEvent:
	# Later (milestone 10): let replacement and prevention effects modify the event (CR 614).
	return event
