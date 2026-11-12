class_name AiDifficulty
extends Resource
## How hard the AI plays (glossary "AI Difficulty", A194): a global, game-side setting that
## only sets how much it searches. It never adds mistakes and never lets the AI cheat
## (ADR 0020). Saved as a .tres file so players can mod it; the shipped levels are in
## content/ai/. A Villain's AI Profile can scale the samples for itself (A195).
##
## Saved files leave out values equal to these defaults, so never change a default once
## difficulties exist; add a new setting instead. The defaults are Normal.

## Whether priority decisions are settled by Flat Monte Carlo. Without it the AI uses
## one-step simulation alone, as in milestone 11.
@export var uses_monte_carlo: bool = true
## How many re-dealt worlds each option is simulated in, one step ahead.
@export var one_step_samples: int = 1
## How many plays Flat Monte Carlo compares (A189).
@export var rollout_candidates: int = 4
## How many re-dealt worlds each candidate is rolled out in (A193).
@export var rollout_samples: int = 4
## Whether a priority decision that offers a combat trick or evasion is scored once the
## Game Turn is over, so what lasts only until end of turn counts for nothing by itself.
## Without it the board is scored as soon as the play has played out, as in milestone 11.
@export var judges_tricks_after_the_turn: bool = true
## The most activations a Repeat Plan may hold (glossary "Repeat Plan"). At 1 an ability is
## only ever weighed one activation at a time.
@export var repeat_plan_length: int = 8


## Milestone 11's AI: one-step simulation only, scored at once, one activation at a time.
static func easy() -> AiDifficulty:
	var difficulty: AiDifficulty = AiDifficulty.new()
	difficulty.uses_monte_carlo = false
	difficulty.judges_tricks_after_the_turn = false
	difficulty.repeat_plan_length = 1
	return difficulty


static func normal() -> AiDifficulty:
	return AiDifficulty.new()


static func hard() -> AiDifficulty:
	var difficulty: AiDifficulty = AiDifficulty.new()
	difficulty.rollout_samples = 12
	return difficulty


## [param samples] scaled by an AI Profile's [param percent], never below one (A195).
static func scaled(samples: int, percent: int) -> int:
	return maxi(samples * percent / 100, 1)
