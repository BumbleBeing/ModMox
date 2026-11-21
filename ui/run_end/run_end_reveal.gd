class_name RunEndReveal
extends RefCounted
## How Run Won and Run Lost come in (milestone 19, signed off as step 2 of
## prototypes/run_ends), worked out for a moment of it: the title fades in rising into place
## as the Spoils screen's window does; then each part in turn fades in dropping into place
## as a Spoils card does, a card's gap apart; the gold counts up from 0 as its plates come;
## the button fades in last. Every time is in seconds at Blazing; the screen scales them by
## the Game Speed.

const TITLE_IN: float = 0.25
const RISE: float = 24.0
const PART_IN: float = 0.22
const DROP: float = 40.0
const PART_GAP: float = 0.3
const COUNT_SECONDS: float = 0.6
const BUTTON_IN: float = 0.2


## How far below its place the title is at [param time], and how opaque.
static func title(time: float) -> Vector2:
	var done: float = _share(time, 0.0, TITLE_IN)
	return Vector2(RISE * (1.0 - _ease_out_cubic(done)), done)


## When the part [param index] starts to come in: the first once the title is in, each
## after it PART_GAP later.
static func part_at(index: int) -> float:
	return TITLE_IN + PART_GAP * index


## How far below its place the part [param index] is at [param time] (less than 0 above
## it, as it drops in), and how opaque.
static func part(time: float, index: int) -> Vector2:
	var done: float = _share(time, part_at(index), PART_IN)
	return Vector2(-DROP * (1.0 - _ease_out_cubic(done)), done)


## The gold the count shows at [param time] out of [param gold], counting up from 0 over
## COUNT_SECONDS from when the part [param index] that holds it starts, easing out.
static func gold_shown(time: float, index: int, gold: int) -> int:
	var done: float = _share(time, part_at(index), COUNT_SECONDS)
	return roundi(gold * (1.0 - (1.0 - done) * (1.0 - done)))


## When the button starts to fade in, after [param parts] parts, the last holding the gold
## when [param counts_gold].
static func button_at(parts: int, counts_gold: bool) -> float:
	return part_at(parts - 1) + (COUNT_SECONDS if counts_gold else PART_IN)


## How opaque the button is at [param time].
static func button(time: float, parts: int, counts_gold: bool) -> float:
	return _share(time, button_at(parts, counts_gold), BUTTON_IN)


## How long the whole reveal takes.
static func length(parts: int, counts_gold: bool) -> float:
	return button_at(parts, counts_gold) + BUTTON_IN


static func _share(time: float, start: float, seconds: float) -> float:
	return clampf((time - start) / seconds, 0.0, 1.0)


static func _ease_out_cubic(done: float) -> float:
	return 1.0 - pow(1.0 - done, 3.0)
