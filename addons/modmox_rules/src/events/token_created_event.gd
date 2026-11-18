class_name TokenCreatedEvent
extends MmEvent
## A token is created on the battlefield (CR 111.2): a new Game Object that is not a card,
## made from a Token Definition, owned and controlled by the player who created it.

var token: MmCardDefinition
var player_id: int
## The new object's ID, set when the event is applied.
var new_object_id: int = 0


func _init(token_definition: MmCardDefinition, creating_player_id: int) -> void:
	token = token_definition
	player_id = creating_player_id


func apply(state: MmGameState) -> void:
	# CR 111.1: a token is not a card, so it has no Card Identity. Its definition is the
	# loaded Token Definition, which is never changed (ADR 0004).
	var created: MmGameObject = state.create_object(MmGameObject.NO_CARD, player_id, token)
	created.become_token()
	state.battlefield.insert(created, MmZone.BOTTOM)
	new_object_id = created.id
	# CR 302.6: summoning sickness counts from when its controller began controlling it.
	created.record_control_since(state.game_turn)


func describe() -> String:
	return "TOKEN CREATED: %s for player %d as object %d" % [token.name, player_id, new_object_id]
