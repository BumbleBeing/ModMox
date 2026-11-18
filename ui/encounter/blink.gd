class_name Blink
extends RefCounted
## When a Portrait's Blink Portrait (game glossary) shows: for SHUT_SECONDS now and then,
## between LEAST_GAP and MOST_GAP apart, and one time in
## DOUBLE_CHANCE twice with DOUBLE_GAP open between. When each player blinks is fixed by
## the encounter's seed, so the two never blink together and a replay looks the same.
## Blinking keeps the same time at every Game Speed, as at Normal (the user's choice).

const SHUT_SECONDS: float = 0.15
const LEAST_GAP: float = 2.5
const MOST_GAP: float = 6.0
const DOUBLE_CHANCE: float = 0.2
const DOUBLE_GAP: float = 0.15

var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_shut: bool = false
## How long until the eyes next shut or open.
var _until_change: float = 0.0
## Whether the eyes shut again straight after they open, for a double blink.
var _blinks_again: bool = false


func _init(encounter_seed: int, player_id: int) -> void:
	_random.seed = hash([encounter_seed, player_id, "blink"])
	_until_change = _random.randf_range(LEAST_GAP, MOST_GAP)


func is_shut() -> bool:
	return _is_shut


## Lets [param seconds] pass.
func advance(seconds: float) -> void:
	var left: float = seconds
	while left >= _until_change:
		left -= _until_change
		_change()
	_until_change -= left


func _change() -> void:
	_is_shut = not _is_shut
	if _is_shut:
		_until_change = SHUT_SECONDS
		return
	if _blinks_again:
		_blinks_again = false
		_until_change = DOUBLE_GAP
		return
	_blinks_again = _random.randf() < DOUBLE_CHANCE
	_until_change = _random.randf_range(LEAST_GAP, MOST_GAP)
