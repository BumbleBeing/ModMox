class_name MmSimulationSource
extends RefCounted
## What an Agent may use to look ahead from one decision (ADR 0020): its AI RNG, a World to
## read, and Simulation Copies to play on. It never hands out the real game state, so an
## Agent cannot see cards its player could not. Made fresh for each decision by
## MmEngine.simulation_source_for().

## The player the Agent answers for.
var player_id: int

var _engine: MmEngine
var _ai_seed: int
## Whether copies re-deal the cards this player cannot see. False inside a Simulation
## Copy, whose hidden cards are already imagined.
var _hides_cards: bool
var _world: MmGameState = null


func _init(engine: MmEngine, deciding_player_id: int, ai_seed: int, hides_cards: bool) -> void:
	_engine = engine
	player_id = deciding_player_id
	_ai_seed = ai_seed
	_hides_cards = hides_cards


## A fresh AI RNG for this decision (ADR 0006, A158). Every call gives the same numbers,
## so take it once and draw everything from it.
func ai_rng() -> MmRng:
	return MmRng.for_ai(_ai_seed, player_id, _engine.decision_count())


## A Simulation Copy of the engine as this player might imagine it, re-dealt from
## [param rng]. Drive it with submit(); the real game never changes.
func simulation_copy(rng: MmRng) -> MmEngine:
	return _engine.simulation_copy(player_id, rng, not _hides_cards)


## The game as this player might imagine it, to read freely: the real game with every
## card they cannot see re-dealt from [param rng], made on the first call and kept after.
## Inside a Simulation Copy it is that copy's own state. Never change it.
func world(rng: MmRng) -> MmGameState:
	if _world == null:
		_world = simulation_copy(rng).game_state() if _hides_cards else _engine.game_state()
	return _world
