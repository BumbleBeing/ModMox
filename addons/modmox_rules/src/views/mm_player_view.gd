class_name MmPlayerView
extends RefCounted
## Everything one player may legally see of the game, and nothing more. AI Agents and the
## GUI read only this, never the game state itself.

var viewer_id: int
## The viewer's own hand.
var hand: Array[MmObjectView] = []
var hand_sizes: Dictionary[int, int] = {}
var library_sizes: Dictionary[int, int] = {}
var life_totals: Dictionary[int, int] = {}


## Builds [param viewing_player_id]'s view of [param state].
static func build(state: MmGameState, viewing_player_id: int) -> MmPlayerView:
	# Later: graveyards, battlefield, stack and exile, which are public zones (CR 400.2).
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = viewing_player_id
	for game_object: MmGameObject in state.player(viewing_player_id).hand.objects():
		view.hand.append(MmObjectView.new(game_object.id, state.characteristics_of(game_object).name))
	for player: MmPlayer in state.players:
		view.hand_sizes[player.id] = player.hand.size()
		view.library_sizes[player.id] = player.library.size()
		view.life_totals[player.id] = player.life
	return view
