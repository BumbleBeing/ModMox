class_name MayPlayExiledEffect
extends MmEffect
## "You may play [selection] until the end of your next turn" (CR 601.2a, 305.1), as Clockwork
## Percussionist's "exile the top card of your library. You may play it until the end of your
## next turn.", or with [member duration] "... this turn": each selected card in exile is
## marked with the player who may play it, the ability's controller, and the last Game Turn
## they may (engine ADR 0100). Its next turn is two Game Turns on if it is their turn now, and
## the next one otherwise. A marked card is played as from the hand: a spell with its usual
## timing and mana cost, a land with one of their land plays (CR 305.2). A card that leaves
## exile is a new object without the mark (ADR 0008).

## How long the card may be played. Saved in Content: append only.
enum Duration { THIS_TURN = 0, YOUR_NEXT_TURN = 1 }

@export var selection: MmSelection
@export var duration: Duration = Duration.YOUR_NEXT_TURN


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	var through: int = last_game_turn(state, context.controller_id, duration)
	for found: MmReference in selection.select(state, context):
		var card: MmGameObject = state.object(found.id) if found.is_object() else null
		if card == null or card.zone() != state.exile:
			continue
		events.append(PlayPermittedEvent.new(card.id, context.controller_id, through))
	return events


## The last Game Turn [param player_id] may play the card for [param how_long], counted
## from now: this one, or the end of their next turn. Two players take turns about, so
## their next turn is two Game Turns on in their own turn and the next one in the other's.
static func last_game_turn(state: MmGameState, player_id: int, how_long: Duration) -> int:
	if how_long == Duration.THIS_TURN:
		return state.game_turn
	return state.game_turn + (2 if state.active_player_id == player_id else 1)


func selections() -> Array[MmSelection]:
	return [selection]
