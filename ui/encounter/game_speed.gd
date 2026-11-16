class_name GameSpeed
extends RefCounted
## Game Speed (game glossary): one setting that scales every wait, move, flight and fade of
## an encounter together (13d-2). Pacing has the game's numbers, which are what Blazing,
## the fastest, plays at; a speed is how many times as long everything takes. Only a
## screen that is not paced waits for nothing.

enum Speed { SLOW, NORMAL, FAST, BLAZING }

## Every speed, slowest first.
const ALL: Array[Speed] = [Speed.SLOW, Speed.NORMAL, Speed.FAST, Speed.BLAZING]
const SCALES: Dictionary[Speed, float] = {Speed.SLOW: 3.0, Speed.NORMAL: 2.0, Speed.FAST: 1.5, Speed.BLAZING: 1.0}
const NAMES: Dictionary[Speed, String] = {Speed.SLOW: "Slow", Speed.NORMAL: "Normal", Speed.FAST: "Fast", Speed.BLAZING: "Blazing"}


## How much of Pacing's time [param speed] uses.
static func scale_of(speed: Speed) -> float:
	return SCALES[speed]


static func name_of(speed: Speed) -> String:
	return NAMES[speed]


## The speed called [param text], whatever its capitals, or Normal if there is none.
static func named(text: String) -> Speed:
	for speed: Speed in ALL:
		if NAMES[speed].to_lower() == text.to_lower():
			return speed
	return Speed.NORMAL


## A wait of [param base_msec] milliseconds at [param speed].
static func msec(base_msec: int, speed: Speed) -> int:
	return roundi(base_msec * SCALES[speed])


## A move of [param base_seconds] seconds at [param speed].
static func seconds(base_seconds: float, speed: Speed) -> float:
	return base_seconds * SCALES[speed]
