class_name DrawCardEvent
extends MmEvent
## [member player_id] would draw a card (CR 121.1, engine ADR 0097): the event replacement
## effects on drawing see, as Blood Scrivener's does (CR 614.1a, 614.11). It names no card,
## since which card is drawn is the top one of the library as the draw happens (CR 121.2),
## so a draw that replaces another draws the right card whatever was drawn before it. It is
## never applied itself: once nothing replaces it, the batch puts the draw of that top card
## in its place (MmGameState.draw_event()), an EmptyLibraryDrawEvent when there is none.

var player_id: int


func _init(drawing_player_id: int) -> void:
	player_id = drawing_player_id


## The draw itself, of the card now on top of the library.
func drawn(state: MmGameState) -> MmEvent:
	return state.draw_event(player_id)


func apply(_state: MmGameState) -> void:
	assert(false, "A DrawCardEvent is replaced by the draw it stands for, never applied.")


func describe() -> String:
	return "WOULD DRAW: player %d" % player_id
