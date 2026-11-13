class_name MmPlayerView
extends RefCounted
## Everything one player may legally see of the game, and nothing more. AI Agents and the
## GUI read only this, never the game state itself.

var viewer_id: int
## The viewer's own hand.
var hand: Array[MmObjectView] = []
## Every permanent, in battlefield order. The battlefield is public (CR 400.2).
var battlefield: Array[MmObjectView] = []
## Every spell and ability on the stack, bottom first (the last one is on top). Public.
var stack: Array[MmObjectView] = []
## Each player's graveyard, bottom first (the last card is on top), by player ID. Public
## (CR 400.2).
var graveyards: Dictionary[int, Array] = {}
## Each player's exiled cards, in the order they got there, by owner's player ID. Exile is
## one shared zone and public (CR 400.2, 406).
var exiles: Dictionary[int, Array] = {}
## Every Emblem in the command zone, such as the Hero's Statuses. Public.
var command: Array[MmObjectView] = []
## Every Potion not yet used, either player's, in the order of the command zone (ADR 0036).
## Public, and never in command.
var potions: Array[MmObjectView] = []
## Each player's mana pool, as copies of its MmMana units. Mana pools are public.
var mana_pools: Dictionary[int, Array] = {}
var hand_sizes: Dictionary[int, int] = {}
var library_sizes: Dictionary[int, int] = {}
## Each library top first, by player ID, with one entry for each card: an MmObjectView for
## a card this view's player knows, such as one they put on the bottom, and null for any
## other. Libraries are hidden (CR 401.2).
var libraries: Dictionary[int, Array] = {}
var life_totals: Dictionary[int, int] = {}
## The shields and other replacement effects locked to each player, by player ID (A140).
var player_replacement_effects: Dictionary[int, Array] = {}
## Replacement effects locked to no player or object, such as Fog's "prevent all combat
## damage that would be dealt this turn".
var game_replacement_effects: Array[ActiveReplacementEffect] = []
## The count of all turns begun by either player; 0 during the pregame.
var game_turn: int = 0
var active_player_id: int = MmGameState.NO_PLAYER
## The active player's own Turn Number, for "<name>'s Turn N"; 0 during the pregame.
var active_player_turn_number: int = 0
var step: MmTurn.Step = MmTurn.Step.NONE
var priority_player_id: int = MmGameState.NO_PLAYER
## Whether the current combat damage step is the extra one for first and double strikers
## (CR 510.4), so the GUI can label it.
var is_first_strike_damage_step: bool = false
## Whether the encounter has ended, and the winner (MmGameState.NO_PLAYER for a draw).
var is_over: bool = false
var winner_id: int = MmGameState.NO_PLAYER
## Why each player who lost did so, so the GUI can say "Out of life" or "Decked".
var loss_reasons: Dictionary[int, MmPlayer.LossReason] = {}


## Builds [param viewing_player_id]'s view of [param state]. [param priority_holder_id]
## is the player currently holding priority, or MmGameState.NO_PLAYER.
static func build(state: MmGameState, viewing_player_id: int, priority_holder_id: int) -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = viewing_player_id
	for game_object: MmGameObject in state.player(viewing_player_id).hand.objects():
		view.hand.append(MmObjectView.of(state, game_object))
	for permanent: MmGameObject in state.battlefield.objects():
		view.battlefield.append(MmObjectView.of(state, permanent))
	for item: MmGameObject in state.stack.objects():
		view.stack.append(MmObjectView.of(state, item))
	for command_object: MmGameObject in state.command.objects():
		if command_object.is_potion():
			view.potions.append(MmObjectView.of(state, command_object))
		else:
			view.command.append(MmObjectView.of(state, command_object))
	for player: MmPlayer in state.players:
		var graveyard: Array[MmObjectView] = []
		for card: MmGameObject in player.graveyard.objects():
			graveyard.append(MmObjectView.of(state, card))
		view.graveyards[player.id] = graveyard
		var exiled: Array[MmObjectView] = []
		for card: MmGameObject in state.exile.objects():
			if card.owner_id == player.id:
				exiled.append(MmObjectView.of(state, card))
		view.exiles[player.id] = exiled
		view.hand_sizes[player.id] = player.hand.size()
		view.library_sizes[player.id] = player.library.size()
		var library: Array[MmObjectView] = []
		for card: MmGameObject in player.library.objects():
			library.append(MmObjectView.of(state, card) if card.is_known_to(viewing_player_id) else null)
		view.libraries[player.id] = library
		view.life_totals[player.id] = player.life
		view.mana_pools[player.id] = player.mana_pool()
		var on_player: Array[ActiveReplacementEffect] = []
		for active: ActiveReplacementEffect in state.replacement_effects:
			if active.is_locked_to(MmReference.to_player(player.id)):
				on_player.append(active)
		view.player_replacement_effects[player.id] = on_player
		if player.has_lost:
			view.loss_reasons[player.id] = player.loss_reason
	for active: ActiveReplacementEffect in state.replacement_effects:
		if active.affected.is_empty():
			view.game_replacement_effects.append(active)
	view.game_turn = state.game_turn
	view.active_player_id = state.active_player_id
	if state.active_player_id != MmGameState.NO_PLAYER:
		view.active_player_turn_number = state.player(state.active_player_id).turn_number
	view.step = state.step
	view.priority_player_id = priority_holder_id
	view.is_over = state.is_over
	view.winner_id = state.winner_id
	view.is_first_strike_damage_step = state.step == MmTurn.Step.COMBAT_DAMAGE and state.combat.is_first_strike_damage_step
	return view
