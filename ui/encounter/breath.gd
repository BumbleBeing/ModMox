class_name Breath
extends RefCounted
## Breath (game glossary): how far into breathing in a Portrait is, from moment to moment.
## A breath eases in to the top halfway through and eases out again to the bottom, never
## still and never moving at an even pace; at Breath Rate 1 one takes REST_SECONDS, and
## below half of the starting life it climbs to twice as fast at 1 life. A hurt player is Winded: they sink
## to the bottom over WINDED_SECONDS and stay there until they catch their breath, then
## start a new breath. A player who lost sinks and never breathes again.
##
## How large that makes the Portrait is growth(), in its own pixels; BreathDrawing says
## where that puts the picture. Breathing keeps the same time at every Game Speed, as at
## Normal (the user's choice), though a Winded player waits out a Pain Portrait that does not.

## How long a breath at Breath Rate 1 takes.
const REST_SECONDS: float = 4.0
## How long a Winded player takes to sink to the bottom of their breath.
const WINDED_SECONDS: float = 0.15
## Below this share of the starting life a player breathes faster, up to LOW_LIFE_MOST
## times as fast at 1 life.
const LOW_LIFE_SHARE: float = 0.5
const LOW_LIFE_MOST: float = 2.0

var rate: float = 1.0
var intensity: float = 1.0
## How far into this breath, from 0 at its start to 1 at its end.
var phase: float = 0.0
var _is_winded: bool = false
var _is_stopped: bool = false
## How full the breath was when the wind was knocked out, and how long ago that was.
var _winded_from: float = 0.0
var _winded_for: float = 0.0


func _init(breath_rate: float = 1.0, breath_intensity: float = 1.0) -> void:
	rate = breath_rate
	intensity = breath_intensity


## How long one breath takes at [param breath_rate] for a player on [param life] of
## [param starting_life].
static func seconds_per_breath(breath_rate: float, life: int, starting_life: int) -> float:
	return REST_SECONDS / (maxf(breath_rate, 0.01) * life_factor(life, starting_life))


## How many times as fast as their own rate a player on [param life] of
## [param starting_life] breathes: 1 down to half their starting life, then climbing in a
## straight line to LOW_LIFE_MOST at 1 life.
static func life_factor(life: int, starting_life: int) -> float:
	var half: float = starting_life * LOW_LIFE_SHARE
	if life >= half:
		return 1.0
	if life <= 1 or half <= 1.0:
		return LOW_LIFE_MOST
	return lerpf(1.0, LOW_LIFE_MOST, (half - life) / (half - 1.0))


## How full a breath is [param at] into it: 0 at the bottom, 1 at the top halfway, eased
## in and out along a cosine (the user found a held top and rested bottom too linear).
static func fullness_at(at: float) -> float:
	return 0.5 - 0.5 * cos(TAU * at)


## Where in their first breath player [param player_id] starts in the encounter of
## [param encounter_seed], so the two players never breathe in step and a replay of the
## seed looks the same.
static func start_phase(encounter_seed: int, player_id: int) -> float:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([encounter_seed, player_id, "breath"])
	return random.randf()


## Lets [param seconds] pass for a player on [param life] of [param starting_life].
func advance(seconds: float, life: int, starting_life: int) -> void:
	if _is_winded:
		_winded_for += seconds
		return
	phase = fposmod(phase + seconds / seconds_per_breath(rate, life, starting_life), 1.0)


## The player was hurt: they sink to the bottom of their breath and stay there.
func wind() -> void:
	if not _is_winded:
		_winded_from = _fullness()
		_winded_for = 0.0
	_is_winded = true


## The hurt is over: a new breath starts from the bottom. A player who lost never does.
func catch_breath() -> void:
	if _is_stopped or not _is_winded:
		return
	_is_winded = false
	phase = 0.0


## The player lost: they sink to the bottom and never breathe again.
func stop() -> void:
	wind()
	_is_stopped = true


func is_winded() -> bool:
	return _is_winded


func is_stopped() -> bool:
	return _is_stopped


## How many of its own pixels taller and wider the Portrait is now than at rest.
func growth() -> float:
	return _fullness() * intensity


func _fullness() -> float:
	if not _is_winded:
		return fullness_at(phase)
	var sunk: float = clampf(_winded_for / WINDED_SECONDS, 0.0, 1.0)
	return lerpf(_winded_from, 0.0, smoothstep(0.0, 1.0, sunk))
