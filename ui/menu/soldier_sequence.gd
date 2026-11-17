class_name SoldierSequence
extends RefCounted
## The order the Menu Soldier plays his animations in, and what he is showing at any moment.
## Each starts as the last one ends. The first, from the moment he appears, is a Transition
## Animation chosen at random; then an Effect Animation and a Transition Animation take turns,
## and neither kind plays the same one twice in a row.
##
## The hook for the Wisp, which brings him his effects: the next Effect Animation is
## chosen two animations ahead, so [method next_effect], [method next_color] and
## [method seconds_until_flash] always name the effect whose flash comes next and when, and
## [signal next_effect_changed] tells of the following one on the very frame he flashes.

## Emitted on the frame the Menu Soldier flashes the color of the effect that was next,
## with the effect that is next now.
signal next_effect_changed(effect: String)

var _random: RandomNumberGenerator
var _clock: float = 0.0
## Every animation chosen so far, in the order they play: transitions at even places.
var _chosen: Array[String] = []
## The place in [member _chosen] of the effect whose flash comes next.
var _next: int = 1


## A sequence that makes its random choices with [param random].
func _init(random: RandomNumberGenerator) -> void:
	_random = random
	_choose_two()


## Lets [param seconds] go by. Tells of every flash passed on the way, however many.
func advance(seconds: float) -> void:
	_clock += seconds
	while _clock >= _flash_time(_next):
		_next += 2
		_choose_two()
		next_effect_changed.emit(next_effect())


## The frame he is showing now.
func frame() -> String:
	return SoldierAnimations.frame_at(animation(), _clock - _start_of(_place_now()))


## The animation playing now.
func animation() -> String:
	return _chosen[_place_now()]


## The Effect Animation whose flash comes next.
func next_effect() -> String:
	return _chosen[_next]


## The color he flashes for [method next_effect].
func next_color() -> Color:
	return SoldierAnimations.color_of(next_effect())


## How long until he flashes [method next_effect]'s color, in seconds.
func seconds_until_flash() -> float:
	return _flash_time(_next) - _clock


## Chooses the next transition and the effect after it, neither the same as the last of its kind.
func _choose_two() -> void:
	for kind: Dictionary in [SoldierAnimations.TRANSITIONS, SoldierAnimations.EFFECTS]:
		var last: String = _chosen[_chosen.size() - 2] if _chosen.size() >= 2 else ""
		var choices: Array = kind.keys().filter(func(choice: String) -> bool: return choice != last)
		_chosen.append(choices[_random.randi_range(0, choices.size() - 1)] as String)


func _start_of(place: int) -> float:
	return place * SoldierAnimations.SECONDS


## The place in [member _chosen] of the animation playing now.
func _place_now() -> int:
	return floori(_clock / SoldierAnimations.SECONDS)


func _flash_time(place: int) -> float:
	return _start_of(place) + SoldierAnimations.seconds_to_flash(_chosen[place])
