class_name AiProfile
extends Resource
## An AI Agent's temperament (glossary "AI Profile"): the settings that make one Villain
## play differently from another. Saved as a .tres file, so players can mod it. Difficulty
## comes from a Villain's deck, the global AI Difficulty and [member search_budget_percent];
## never from cheating (ADR 0020).
##
## Saved files leave out values equal to these defaults, so never change a default once
## profiles exist; add a new setting instead.

## Whether it plays first when it chooses (roadmap milestone 11).
@export var prefers_to_play_first: bool = true
## The fewest and most lands a hand may hold and still be kept.
@export var mulligan_min_lands: int = 2
@export var mulligan_max_lands: int = 5
## It always keeps once keeping would leave this many cards or fewer.
@export var always_keeps_at: int = 5
## The share of a hand that should be lands, in percent, when choosing what to put on the
## bottom or discard.
@export var land_share_percent: int = 42
## The chance, in percent, that it attacks into an even trade it would otherwise avoid.
@export var chance_to_attack_into_trade: int = 0
## Whether it attacks when the race is even or slightly behind.
@export var plays_aggressively: bool = false
## Its life is in danger once it would be at or below this after combat.
@export var life_danger_threshold: int = 4
## The Board Evaluator's worth of a card in hand: this much, plus [member hand_mana_value_bonus]
## for each point of a nonland card's mana value (A179).
@export var hand_card_value: int = 5
@export var hand_mana_value_bonus: int = 10
## A creature that cannot attack yet is worth this share of its value, in percent.
@export var summoning_sick_percent: int = 90
## A decision slower than this, in milliseconds, is reported as a warning. Never changes
## the answer (A159).
@export var slow_decision_warning_ms: int = 1000
## This Villain's search budget, in percent of the global AI Difficulty's samples, so a
## boss can think harder than the rest (A195).
@export var search_budget_percent: int = 100
## Flat Monte Carlo keeps the one-step pick unless another play beats it by this many
## Board Evaluator points per sample (A192).
@export var rollout_switch_margin: int = 10
