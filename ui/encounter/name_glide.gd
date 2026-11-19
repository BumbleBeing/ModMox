class_name NameGlide
extends RefCounted
## How far a Player Name too long for its Player Panel has glided: it rests at its start,
## glides at a steady pace until its end meets the end of its box, rests there, glides back
## and starts over, for as long as it is shown. A name that fits never moves. Like a
## Portrait's Breath it keeps its own time whatever the Game Speed: it is not the game's
## pace.

## How long the name rests at each end.
const REST_SECONDS: float = 1.5
## How fast it glides.
const PIXELS_PER_SECOND: float = 30.0

## How many whole pixels wider the name is than its box, rounded up so its last letter shows.
var _overflow: int = 0
## Where the name is in its round trip, in seconds.
var _time: float = 0.0


## [param overflow] is how much wider the name is than its box, 0 or less for one that fits.
func _init(overflow: float) -> void:
	_overflow = maxi(ceili(overflow - 0.001), 0)


func is_gliding() -> bool:
	return _overflow > 0


func advance(seconds: float) -> void:
	if is_gliding():
		_time = fmod(_time + seconds, _round_trip())


## Where the name is drawn from the start of its box: 0 at its start, down to minus the
## overflow at its end, in whole pixels.
func offset() -> int:
	if not is_gliding():
		return 0
	var glide: float = _glide_seconds()
	var time: float = _time
	var share: float = 0.0
	if time < REST_SECONDS:
		share = 0.0
	elif time < REST_SECONDS + glide:
		share = (time - REST_SECONDS) / glide
	elif time < REST_SECONDS * 2.0 + glide:
		share = 1.0
	else:
		share = 1.0 - (time - REST_SECONDS * 2.0 - glide) / glide
	return -roundi(clampf(share, 0.0, 1.0) * _overflow)


func _glide_seconds() -> float:
	return _overflow / PIXELS_PER_SECOND


func _round_trip() -> float:
	return (REST_SECONDS + _glide_seconds()) * 2.0
