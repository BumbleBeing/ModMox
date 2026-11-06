class_name StateBasedActions
extends RefCounted
## CR 704: the game checks these whenever a player would receive priority, performs
## everything that applies at once, and repeats until nothing does. Each rule is its own
## function, so a new state-based action is one more function and one more call.


## Performs state-based actions until none apply, then ends the encounter if anyone lost.
static func check(state: MmGameState) -> void:
	while not state.is_over:
		var losers: Array[MmPlayer] = []
		var reasons: Array[MmPlayer.LossReason] = []
		_players_who_lose(state, losers, reasons)
		var zero_toughness: Array[MmGameObject] = _creatures_with_zero_toughness(state)
		var lethal: Array[MmGameObject] = _creatures_with_lethal_damage(state)
		if losers.is_empty() and zero_toughness.is_empty() and lethal.is_empty():
			return
		# CR 704.3: all at once. Later (milestone 8): mark these as one simultaneous batch,
		# for "dies" triggers that look back in time (CR 603.10a).
		for index: int in losers.size():
			state.perform(PlayerLostEvent.new(losers[index].id, reasons[index]))
		for creature: MmGameObject in zero_toughness:
			_put_into_graveyard(state, creature, ZoneChangeEvent.Reason.ZERO_TOUGHNESS)
		for creature: MmGameObject in lethal:
			_put_into_graveyard(state, creature, ZoneChangeEvent.Reason.DESTROY)
		if not losers.is_empty():
			_end_encounter(state)


## CR 704.5a: 0 or less life. CR 704.5b: tried to draw from an empty library.
static func _players_who_lose(state: MmGameState, losers: Array[MmPlayer], reasons: Array[MmPlayer.LossReason]) -> void:
	for player: MmPlayer in state.players:
		if player.has_lost:
			continue
		if player.life <= 0:
			losers.append(player)
			reasons.append(MmPlayer.LossReason.ZERO_LIFE)
		elif player.has_drawn_from_empty_library:
			losers.append(player)
			reasons.append(MmPlayer.LossReason.EMPTY_LIBRARY)


## CR 704.5f: a creature with toughness 0 or less.
static func _creatures_with_zero_toughness(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for creature: MmGameObject in _creatures(state):
		if state.characteristics_of(creature).toughness <= 0:
			found.append(creature)
	return found


## CR 704.5g: a creature with toughness greater than 0 and damage marked on it greater
## than or equal to its toughness. Later (milestone 9): deathtouch (704.5h), indestructible.
static func _creatures_with_lethal_damage(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for creature: MmGameObject in _creatures(state):
		var toughness: int = state.characteristics_of(creature).toughness
		if toughness > 0 and creature.damage_marked >= toughness:
			found.append(creature)
	return found


## Every creature on the battlefield, in ID order.
static func _creatures(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if state.characteristics_of(permanent).has_card_type(MmCardTypes.CardType.CREATURE):
			found.append(permanent)
	found.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return found


static func _put_into_graveyard(state: MmGameState, creature: MmGameObject, reason: ZoneChangeEvent.Reason) -> void:
	var graveyard: MmZone = state.player(creature.owner_id).graveyard
	state.perform(ZoneChangeEvent.new(creature, graveyard, MmZone.BOTTOM, reason))


## CR 104.2a: the player still in the game wins. CR 104.4a: a draw when nobody is.
static func _end_encounter(state: MmGameState) -> void:
	var winner_id: int = MmGameState.NO_PLAYER
	for player: MmPlayer in state.players:
		if not player.has_lost:
			winner_id = player.id
	state.perform(EncounterEndedEvent.new(winner_id))
