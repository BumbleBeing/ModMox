class_name TokenCreatedEvent
extends MmEvent
## A token is created on the battlefield (CR 111.2): a new Game Object that is not a card,
## made from a Token Definition, owned and controlled by the player who created it.

var token: MmCardDefinition
var player_id: int
## True when the token is put onto the battlefield attacking (CR 508.4), the player the
## combat's attackers attack: attacking as it arrives, so it is never on the battlefield
## and not attacking. It was never declared as an attacker (ADR 0044).
var attacking_on_arrival: bool = false
## The attacker the token is put onto the battlefield blocking (CR 509.7), or 0: blocking as
## it arrives, so it is never on the battlefield and not blocking. It was never declared as
## a blocker (ADR 0044).
var blocking_on_arrival: int = 0
## The permanent the token is put onto the battlefield attached to (CR 303.4), or 0: attached
## as it arrives, so it is never on the battlefield unattached (engine ADR 0044's addendum).
var attached_to_on_arrival: int = 0
## The new object's ID, set when the event is applied; 0 when no token was created, because
## it could not legally be attached to [member attached_to_on_arrival] (CR 303.4g).
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
	if attached_to_on_arrival != 0:
		if not AttachmentRules.can_be_attached(state, created, state.object(attached_to_on_arrival)):
			# CR 303.4g: an Aura with nothing it may legally enchant stays where it is, and a
			# token being created has nowhere else to be, so it is never made.
			state.battlefield.remove(created)
			state.retire_object(created)
			return
		created.attach_to(attached_to_on_arrival)
	new_object_id = created.id
	# CR 302.6: summoning sickness counts from when its controller began controlling it.
	created.record_control_since(state.game_turn)
	if attacking_on_arrival:
		state.combat.enter_attacking(created.id)
	if blocking_on_arrival != 0:
		state.combat.enter_blocking(created.id, blocking_on_arrival)


func describe() -> String:
	var attacking: String = " attacking" if attacking_on_arrival else ""
	var blocking: String = "" if blocking_on_arrival == 0 else " blocking object %d" % blocking_on_arrival
	var attached: String = "" if attached_to_on_arrival == 0 else " attached to object %d" % attached_to_on_arrival
	return "TOKEN CREATED: %s for player %d as object %d%s%s%s" % [token.name, player_id, new_object_id, attacking, blocking,
		attached]
