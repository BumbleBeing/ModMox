class_name MmRng
extends RefCounted
## A seeded stream of random numbers (ADR 0006). The Game RNG lives in the game state and
## is used only by the rules; the AI RNG belongs to an AI Agent. Both are derived from the
## Encounter Seed, so an encounter replays exactly.

const _GAME_LABEL: String = "game"
const _AI_LABEL: String = "ai"

var _generator: RandomNumberGenerator = RandomNumberGenerator.new()


## The Game RNG for an encounter.
static func for_game(encounter_seed: int) -> MmRng:
	return MmRng.new(_derive_seed(encounter_seed, _GAME_LABEL))


## The seed every AI RNG of an encounter derives from. Knowing it reveals nothing about
## the Game RNG.
static func ai_seed_for(encounter_seed: int) -> int:
	return _derive_seed(encounter_seed, _AI_LABEL)


## The AI RNG for one decision: [param player_id]'s answer to decision number
## [param decision_index] (ADR 0006, A158). Each decision gets a fresh stream, so the same
## decision gets the same numbers after a save and reload, and two AI players never share
## numbers. Using it never affects the Game RNG.
static func for_ai(ai_seed: int, player_id: int, decision_index: int) -> MmRng:
	return MmRng.new(("%d:%d:%d" % [ai_seed, player_id, decision_index]).hash())


func _init(stream_seed: int) -> void:
	_generator.seed = stream_seed


## A copy of this stream at its current position. Both copies then produce the same numbers.
func duplicate_stream() -> MmRng:
	var copy: MmRng = MmRng.new(_generator.seed)
	copy._generator.state = _generator.state
	return copy


## A seed for another stream, such as a Simulation Copy's Game RNG.
func next_seed() -> int:
	return _generator.randi()


## A random integer from 0 up to but not including [param exclusive_max].
func next_int(exclusive_max: int) -> int:
	assert(exclusive_max > 0, "next_int needs a positive bound.")
	return _generator.randi_range(0, exclusive_max - 1)


## Shuffles [param items] in place with a Fisher-Yates shuffle driven by this stream.
func shuffle_in_place(items: Array) -> void:
	for index: int in range(items.size() - 1, 0, -1):
		var swap_index: int = next_int(index + 1)
		var held: Variant = items[index]
		items[index] = items[swap_index]
		items[swap_index] = held


## The stream's current position, for state fingerprints.
func describe_state() -> String:
	return str(_generator.state)


## Each stream gets its own seed by hashing the Encounter Seed with a fixed label.
static func _derive_seed(encounter_seed: int, label: String) -> int:
	return ("%d:%s" % [encounter_seed, label]).hash()
