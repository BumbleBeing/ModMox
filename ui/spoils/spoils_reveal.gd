class_name SpoilsReveal
extends RefCounted
## The Spoils screen's reveal (milestone 18, signed off as step 2 of its prototype), worked
## out for a moment of it: the window rises in, the gold fades in and counts up, each card
## drops in face down and flips face up, a card every DEAL_GAP, and Continue comes last.
## Every time is in seconds at Blazing; the screen scales them by the Game Speed.

## The window fades in over WINDOW_IN, rising RISE pixels into place.
const WINDOW_IN: float = 0.25
const RISE: float = 24.0
## The gold panel fades in over PANEL_IN as its number counts up from 0 over COUNT_SECONDS.
const GOLD_AT: float = 0.25
const PANEL_IN: float = 0.15
const COUNT_SECONDS: float = 0.6
## Later (milestone 22): an Item fades in at ITEM_AT, over PANEL_IN.
const ITEM_AT: float = 0.4
## Each card drops DROP pixels into place face down, fading in, over DROP_SECONDS, then
## flips face up over FLIP_SECONDS; the next starts DEAL_GAP after it.
const FIRST_CARD_AT: float = 0.55
const DEAL_GAP: float = 0.3
const DROP: float = 40.0
const DROP_SECONDS: float = 0.22
const FLIP_SECONDS: float = 0.28
## Continue fades in over BUTTON_IN once the last card is face up and the count is done.
const BUTTON_IN: float = 0.2


## How far below its place the window is at [param time], and how opaque it is.
static func window(time: float) -> Vector2:
	var done: float = _share(time, 0.0, WINDOW_IN)
	return Vector2(RISE * (1.0 - _ease_out_cubic(done)), done)


## How opaque the gold panel is at [param time].
static func gold_panel(time: float) -> float:
	return _share(time, GOLD_AT, PANEL_IN)


## The gold the count shows at [param time], out of [param gold], easing out.
static func gold_shown(time: float, gold: int) -> int:
	var done: float = _share(time, GOLD_AT, COUNT_SECONDS)
	return roundi(gold * (1.0 - (1.0 - done) * (1.0 - done)))


## Where the card [param index] is at [param time]: x how far above its place it is, y how
## opaque, z how wide (1 flat, 0 edge on in its flip), and w 1 once it is face up.
static func card(time: float, index: int) -> Vector4:
	var start: float = FIRST_CARD_AT + DEAL_GAP * index
	var dropped: float = _share(time, start, DROP_SECONDS)
	var half: float = FLIP_SECONDS / 2.0
	var flip_at: float = start + DROP_SECONDS
	var width: float = 1.0
	var face_up: float = 0.0
	if time >= flip_at + half:
		face_up = 1.0
		width = sin(_share(time, flip_at + half, half) * PI / 2.0)
	elif time > flip_at:
		width = cos(_share(time, flip_at, half) * PI / 2.0)
	return Vector4(DROP * (1.0 - _ease_out_cubic(dropped)), dropped, width, face_up)


## When Continue starts to fade in, for [param cards] cards.
static func button_at(cards: int) -> float:
	var last_up: float = FIRST_CARD_AT + DEAL_GAP * maxi(cards - 1, 0) + DROP_SECONDS + FLIP_SECONDS
	return maxf(last_up, GOLD_AT + COUNT_SECONDS)


## How opaque Continue is at [param time], for [param cards] cards.
static func button(time: float, cards: int) -> float:
	return _share(time, button_at(cards), BUTTON_IN)


## How long the whole reveal takes, for [param cards] cards.
static func length(cards: int) -> float:
	return button_at(cards) + BUTTON_IN


## How far through a stretch [param seconds] long from [param start] [param time] is, 0 to 1.
static func _share(time: float, start: float, seconds: float) -> float:
	return clampf((time - start) / seconds, 0.0, 1.0)


static func _ease_out_cubic(done: float) -> float:
	return 1.0 - pow(1.0 - done, 3.0)
