class_name EffectCallouts
extends RefCounted
## The Menu Soldier's Effect Callouts: on the frame he first flashes each Effect Animation's
## color, its callout appears about him, and two seconds later it has faded out. His other
## flashes, partway through an effect or on the way out of it, bring none. A callout is
## placed where he stands as he flashes, so none comes before that is known.

var _sequence: SoldierSequence
var _random: RandomNumberGenerator
var _has_ground: bool = false
## His square and the screen, as last told.
var _square: Rect2
var _screen: Rect2
## The effect whose first flash comes next, and when, in seconds into his sequence.
var _coming: String
var _flash_at: float
var _callouts: Array[EffectCallout] = []


## Callouts timed by [param sequence], placed at random with [param random].
func _init(sequence: SoldierSequence, random: RandomNumberGenerator) -> void:
	_sequence = sequence
	_random = random
	_coming = sequence.next_effect()
	_flash_at = sequence.seconds() + sequence.seconds_until_flash()
	sequence.next_effect_changed.connect(_on_flash)


## Tells it where he stands, [param square], and where the screen is. A screen with no size
## yet is ignored.
func set_ground(square: Rect2, screen: Rect2) -> void:
	if screen.size == Vector2.ZERO:
		return
	_square = square
	_screen = screen
	_has_ground = true


## Where he stands, as last told.
func square() -> Rect2:
	return _square


## The callouts showing now, in the order they appeared.
func shown() -> Array[EffectCallout]:
	var showing: Array[EffectCallout] = []
	for callout: EffectCallout in _callouts:
		if not callout.is_over(age_of(callout)):
			showing.append(callout)
	return showing


## How long ago [param callout] appeared, in seconds.
func age_of(callout: EffectCallout) -> float:
	return _sequence.seconds() - callout.born()


func _on_flash(next: String) -> void:
	var flashed: String = _coming
	var flashed_at: float = _flash_at
	_coming = next
	_flash_at = _sequence.seconds() + _sequence.seconds_until_flash()
	_callouts = shown()
	if _has_ground:
		_callouts.append(EffectCallout.placed(flashed, flashed_at, _square, _screen, _random))
