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


func _stream(stream: String) -> RandomNumberGenerator:
	if not _streams.has(stream):
		var made: RandomNumberGenerator = RandomNumberGenerator.new()
		made.seed = hash([_run_seed, stream])
		_streams[stream] = made
	return _streams[stream]
