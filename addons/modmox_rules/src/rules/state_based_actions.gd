class_name StateBasedActions
extends RefCounted
## CR 704: the game checks these whenever a player would receive priority, performs
## everything that applies at once, and repeats until nothing does. Each rule is its own
## function, so a new state-based action is one more function and one more call.


## Performs state-based actions until none apply, then ends the encounter if anyone lost.
## Stops while a batch waits for a replacement choice, such as which regeneration shield to
## use; calling it again afterwards carries on (A143). Returns the legend rule's choice when
## a player must make one before anything is performed (CR 704.5j): [param kept_ids] holds
## the legends kept so far, and is used up as the batch is performed (ADR 0051).
static func check(state: MmGameState, kept_ids: Array[int]) -> ChooseLegendToKeepDecision:
	while not state.is_over and not state.is_batch_suspended():
		for player: MmPlayer in state.players:
			if player.has_lost:
				_end_encounter(state)
				return null
		var choice: ChooseLegendToKeepDecision = _next_legend_choice(state, kept_ids)
		if choice != null:
			return choice
		var actions: Array[MmEvent] = _actions(state, kept_ids)
		kept_ids.clear()
		if actions.is_empty():
			return null
		# CR 704.3: all at once, so "dies" triggers see everything that died together
		# (ADR 0017).
		state.perform_resumably(actions)
	return null


## Whether any state-based action would be performed right now (CR 514.3a asks this).
static func any_apply(state: MmGameState) -> bool:
	var none_kept: Array[int] = []
	return not state.is_over and (not _actions(state, none_kept).is_empty() or not _legend_groups(state).is_empty())


## The events every state-based action that applies right now would perform. A group of
## legends none of [param kept_ids] is in is left for its choice.
static func _actions(state: MmGameState, kept_ids: Array[int]) -> Array[MmEvent]:
	var actions: Array[MmEvent] = []
	var losers: Array[MmPlayer] = []
	var reasons: Array[MmPlayer.LossReason] = []
	_players_who_lose(state, losers, reasons)
	for index: int in losers.size():
		actions.append(PlayerLostEvent.new(losers[index].id, reasons[index]))
	for creature: MmGameObject in _creatures_with_zero_toughness(state):
		actions.append(_to_graveyard(state, creature, ZoneChangeEvent.Reason.ZERO_TOUGHNESS))
	for creature: MmGameObject in _creatures_with_lethal_damage(state):
		actions.append(_to_graveyard(state, creature, ZoneChangeEvent.Reason.DESTROY))
	for creature: MmGameObject in _indestructible_creatures_dealt_deathtouch_damage(state):
		actions.append(DeathtouchDamageClearedEvent.new(creature.id))
	for permanent: MmGameObject in _permanents_with_both_kinds_of_counter(state):
		var canceled: int = mini(permanent.counters_of(MmCounter.Kind.PLUS_ONE_PLUS_ONE),
			permanent.counters_of(MmCounter.Kind.MINUS_ONE_MINUS_ONE))
		actions.append(CountersRemovedEvent.new(permanent.id, MmCounter.Kind.PLUS_ONE_PLUS_ONE, canceled))
		actions.append(CountersRemovedEvent.new(permanent.id, MmCounter.Kind.MINUS_ONE_MINUS_ONE, canceled))
	for permanent: MmGameObject in _permanents_attached_illegally(state):
		actions.append(UnattachedEvent.new(permanent.id))
	for aura: MmGameObject in _auras_attached_illegally(state):
		if aura.is_bestowed:
			# CR 702.103f, engine ADR 0089: it becomes unattached instead, an exception to
			# CR 704.5m, and so ceases to be bestowed.
			actions.append(UnattachedEvent.new(aura.id))
		else:
			actions.append(_to_graveyard(state, aura, ZoneChangeEvent.Reason.UNATTACHED_AURA))
	for token: MmGameObject in _tokens_off_the_battlefield(state):
		actions.append(TokenCeasedEvent.new(token))
	for copy: MmGameObject in _copies_off_the_stack(state):
		actions.append(CopyCeasedEvent.new(copy))
	for group: Array[int] in _legend_groups(state):
		var kept: int = _kept_in(group, kept_ids)
		if kept == -1:
			continue
		for id: int in group:
			if id != kept:
				# Later: an owner's graveyard other than the controller's, once something
				# changes control.
				actions.append(_to_graveyard(state, state.object(id), ZoneChangeEvent.Reason.LEGEND_RULE))
	return actions


## CR 704.5j: the choice for the first group of legends with no kept one among
## [param kept_ids], or null when every group has one.
static func _next_legend_choice(state: MmGameState, kept_ids: Array[int]) -> ChooseLegendToKeepDecision:
	for group: Array[int] in _legend_groups(state):
		if _kept_in(group, kept_ids) == -1:
			var first: MmGameObject = state.object(group[0])
			return ChooseLegendToKeepDecision.new(first.controller_id, state.characteristics_of(first).name, group)
	return null


## CR 704.5j: each set of two or more legendary permanents with the same name that one
## player controls, each in ID order. The active player's come first (CR 101.4), and each
## player's are in the order of their lowest IDs.
static func _legend_groups(state: MmGameState) -> Array[Array]:
	var groups: Array[Array] = []
	for player_id: int in [state.active_player_id, state.opponent_of(state.active_player_id).id]:
		var by_name: Dictionary[String, Array] = {}
		var names: Array[String] = []
		for permanent: MmGameObject in ManaPayment.sorted_permanents_of(state, player_id):
			var characteristics: MmCharacteristics = state.characteristics_of(permanent)
			if not characteristics.has_supertype(MmCardTypes.Supertype.LEGENDARY):
				continue
			if not by_name.has(characteristics.name):
				by_name[characteristics.name] = []
				names.append(characteristics.name)
			by_name[characteristics.name].append(permanent.id)
		for each_name: String in names:
			if by_name[each_name].size() >= 2:
				var group: Array[int] = []
				group.assign(by_name[each_name])
				group.sort()
				groups.append(group)
	return groups


## The one of [param group] that is in [param kept_ids], or -1.
static func _kept_in(group: Array[int], kept_ids: Array[int]) -> int:
	for id: int in group:
		if kept_ids.has(id):
			return id
	return -1


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
## than or equal to its toughness. CR 704.5h: one with toughness greater than 0 dealt damage
## by a source with deathtouch. CR 702.12b: neither destroys an indestructible creature.
static func _creatures_with_lethal_damage(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for creature: MmGameObject in _creatures(state):
		var characteristics: MmCharacteristics = state.characteristics_of(creature)
		if characteristics.toughness > 0 and not characteristics.has_ability(IndestructibleAbility) \
				and (creature.damage_marked >= characteristics.toughness or creature.was_dealt_deathtouch_damage):
			found.append(creature)
	return found


## CR 704.5h asks only about deathtouch damage since the last check, so an indestructible
## creature that survives this check stops counting it.
static func _indestructible_creatures_dealt_deathtouch_damage(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for creature: MmGameObject in _creatures(state):
		var characteristics: MmCharacteristics = state.characteristics_of(creature)
		if creature.was_dealt_deathtouch_damage and characteristics.toughness > 0 \
				and characteristics.has_ability(IndestructibleAbility):
			found.append(creature)
	return found


## CR 704.5q: a permanent with both a +1/+1 counter and a -1/-1 counter on it loses the
## same number of each, as many as it has of the fewer. In ID order.
static func _permanents_with_both_kinds_of_counter(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.counters_of(MmCounter.Kind.PLUS_ONE_PLUS_ONE) > 0 \
				and permanent.counters_of(MmCounter.Kind.MINUS_ONE_MINUS_ONE) > 0:
			found.append(permanent)
	found.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return found


## CR 704.5n: an Equipment attached to an illegal permanent, or to something that is no
## longer on the battlefield, becomes unattached and stays on the battlefield. In ID order.
## An Aura is never unattached this way: _auras_attached_illegally() finds it instead.
static func _permanents_attached_illegally(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.attached_to_object_id != 0 and not _is_aura(state, permanent) \
				and not AttachmentRules.can_be_attached(state, permanent, state.object(permanent.attached_to_object_id)):
			found.append(permanent)
	found.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return found


## CR 704.5m: an Aura attached to an illegal object or player, or not attached to an object
## or player, is put into its owner's graveyard. In ID order.
static func _auras_attached_illegally(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if _is_aura(state, permanent) and (permanent.attached_to_object_id == 0
				or not AttachmentRules.can_be_attached(state, permanent, state.object(permanent.attached_to_object_id))):
			found.append(permanent)
	found.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return found


static func _is_aura(state: MmGameState, permanent: MmGameObject) -> bool:
	return state.characteristics_of(permanent).subtypes.has(AttachmentRules.AURA)


## CR 704.5d: a token in a zone other than the battlefield ceases to exist. In ID order.
static func _tokens_off_the_battlefield(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for player: MmPlayer in state.players:
		for each_zone: MmZone in [player.hand, player.library, player.graveyard]:
			for game_object: MmGameObject in each_zone.objects():
				if game_object.is_token:
					found.append(game_object)
	for game_object: MmGameObject in state.exile.objects() + state.stack.objects():
		if game_object.is_token:
			found.append(game_object)
	found.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return found


## CR 704.5e: a copy of a spell in a zone other than the stack ceases to exist. In ID order.
static func _copies_off_the_stack(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for player: MmPlayer in state.players:
		for each_zone: MmZone in [player.hand, player.library, player.graveyard]:
			for game_object: MmGameObject in each_zone.objects():
				if game_object.is_copy:
					found.append(game_object)
	for game_object: MmGameObject in state.exile.objects() + state.battlefield.objects():
		if game_object.is_copy:
			found.append(game_object)
	found.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return found


## Every creature on the battlefield, in ID order.
static func _creatures(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if state.characteristics_of(permanent).has_card_type(MmCardTypes.CardType.CREATURE):
			found.append(permanent)
	found.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return found


static func _to_graveyard(state: MmGameState, creature: MmGameObject, reason: ZoneChangeEvent.Reason) -> ZoneChangeEvent:
	return ZoneChangeEvent.new(creature, state.player(creature.owner_id).graveyard, MmZone.BOTTOM, reason)


## CR 104.2a: the player still in the game wins. CR 104.4a: a draw when nobody is.
static func _end_encounter(state: MmGameState) -> void:
	var winner_id: int = MmGameState.NO_PLAYER
	for player: MmPlayer in state.players:
		if not player.has_lost:
			winner_id = player.id
	state.perform(EncounterEndedEvent.new(winner_id))
