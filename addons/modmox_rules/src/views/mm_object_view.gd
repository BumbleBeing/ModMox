class_name MmObjectView
extends RefCounted
## What a player can see of one Game Object they are allowed to see.

var id: int
var name: String
var owner_id: int
var controller_id: int
var is_tapped: bool
## For a spell or ability on the stack: its chosen targets, in order (null if not chosen).
var targets: Array[MmReference] = []


## The view of [param game_object] as it is now.
static func of(state: MmGameState, game_object: MmGameObject) -> MmObjectView:
	var view: MmObjectView = MmObjectView.new()
	view.id = game_object.id
	view.name = state.characteristics_of(game_object).name
	view.owner_id = game_object.owner_id
	view.controller_id = game_object.controller_id
	view.is_tapped = game_object.is_tapped
	view.targets = game_object.targets.duplicate()
	return view
