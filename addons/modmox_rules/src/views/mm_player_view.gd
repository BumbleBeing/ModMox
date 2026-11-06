class_name MmPlayerView
extends RefCounted
## Everything one player may legally see of the game, and nothing more. AI Agents and the
## GUI read only this, never the game state itself.

var viewer_id: int
## The viewer's own hand.
var hand: Array[MmObjectView] = []
## Every permanent, in battlefield order. The battlefield is public (CR 400.2).
var battlefield: Array[MmObjectView] = []
## Each player's mana pool, as copies of its MmMana units. Mana pools are public.
var mana_pools: Dictionary[int, Array] = {}
var hand_sizes: Dictionary[int, int] = {}
var library_sizes: Dictionary[int, int] = {}
var life_totals: Dictionary[int, int] = {}
## The count of all turns begun by either player; 0 during the pregame.
var game_turn: int = 0
var active_player_id: int = MmGameState.NO_PLAYER
## The active player's own Turn Number, for "<name>'s Turn N"; 0 during the pregame.
var active_player_turn_number: int = 0
var step: MmTurn.Step = MmTurn.Step.NONE
var priority_player_id: int = MmGameState.NO_PLAYER


## Builds [param viewing_player_id]'s view of [param state]. [param priority_holder_id]
## is the player currently holding priority, or MmGameState.NO_PLAYER.
static func build(state: MmGameState, viewing_player_id: int, priority_holder_id: int) -> MmPlayerView:
	# Later: graveyards, stack and exile, which are public zones too (CR 400.2).
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = viewing_player_id
	for game_object: MmGameObject in state.player(viewing_player_id).hand.objects():
		view.hand.append(MmObjectView.of(state, game_object))
	for permanent: MmGameObject in state.battlefield.objects():
		view.battlefield.append(MmObjectView.of(state, permanent))
	for player: MmPlayer in state.players:
		view.hand_sizes[player.id] = player.hand.size()
		view.library_sizes[player.id] = player.library.size()
		view.life_totals[player.id] = player.life
		view.mana_pools[player.id] = player.mana_pool()
	view.game_turn = state.game_turn
	view.active_player_id = state.active_player_id
	if state.active_player_id != MmGameState.NO_PLAYER:
		view.active_player_turn_number = state.player(state.active_player_id).turn_number
	view.step = state.step
	view.priority_player_id = priority_holder_id
	return view
