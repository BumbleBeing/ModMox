class_name CreateTokenEffect
extends MmEffect
## "Create [amount] [token]" (CR 111.2): puts that many tokens made from the Token
## Definition [member token] onto the battlefield, all at once, under the control of the
## player whose spell or ability created them. Each is a new object (ADR 0008), so it enters
## untapped, with summoning sickness, and its own "enters" abilities trigger.

## The Token Definition: the token's name, color, types, power and toughness and abilities
## (CR 111.3), kept in its own file under content/tokens/.
@export var token: MmCardDefinition
@export var amount: int = 1


func next_batch(_state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for index: int in amount:
		events.append(TokenCreatedEvent.new(token, context.controller_id))
	return events
