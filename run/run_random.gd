class_name RunRandom
extends RefCounted
## Every random choice a run makes outside an encounter, all from the Run Seed (ADR 0025).
## Each kind of choice draws from a stream of its own, seeded from the Run Seed and the
## stream's name, so a new kind of choice never changes the results of the old ones.

const VILLAINS: String = "villains"
const ENCOUNTER_SEEDS: String = "encounter_seeds"
const STAGES: String = "stages"
const STAGE_MAPS: String = "stage_maps"
const BOSSES: String = "bosses"
const MAP_LAYOUT: String = "map_layout"
const SPOILS_GOLD: String = "spoils_gold"
const SPOILS_CARDS: String = "spoils_cards"
const SCENERY: String = "scenery"

var _run_seed: int
var _streams: Dictionary[String, RandomNumberGenerator] = {}


func _init(run_seed: int) -> void:
	_run_seed = run_seed


## The next whole number from 0 to [param count] - 1 in [param stream].
func pick(stream: String, count: int) -> int:
	return _stream(stream).randi_range(0, count - 1)


## The next number in [param stream] from 0 up to (not including) 1.
func fraction(stream: String) -> float:
	return _stream(stream).randf()


## The next number in [param stream] that can seed an encounter.
func next_seed(stream: String) -> int:
	return _stream(stream).randi()


## Where each stream drawn from so far has reached, by name, for a saved run (ADR 0074).
## A state is a 64-bit number, kept as text so that no reader rounds it.
func to_data() -> Dictionary:
	var data: Dictionary = {}
	for stream: String in _streams:
		data[stream] = str(_streams[stream].state)
	return data


## Puts each stream in [param data] back where it had reached. A stream it does not name
## starts from the beginning when it is first drawn from, as it would have.
func restore(data: Dictionary) -> void:
	for stream: String in data:
		_stream(stream).state = str(data[stream]).to_int()


func _stream(stream: String) -> RandomNumberGenerator:
	if not _streams.has(stream):
		var made: RandomNumberGenerator = RandomNumberGenerator.new()
		made.seed = hash([_run_seed, stream])
		_streams[stream] = made
	return _streams[stream]
