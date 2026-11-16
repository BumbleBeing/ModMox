class_name Villain
extends Resource
## A Villain (ADR 0024) as Content: who the Hero meets in an encounter. It holds no Rank of
## its own; its Rank is the list of the Stage it is met through. Saved in content/villains/.
##
## Saved files leave out values equal to these defaults, so never change a default once
## Villains exist; add a new property instead.

## How many setups a Villain whose deck grows with the Tier has: one for each Tier.
const TIERS: int = 5

## What the Villain is called on the screen.
@export var name: String = ""
## Its 32 × 32 Portrait.
@export var sprite: Texture2D
## One setup, played at every Tier, or five, one for each Tier. Each is the same resource a
## deck file is, so starting life and Emblems need no fields here (ADR 0011).
@export var setups: Array[MmPlayerSetup] = []
## How it plays, when it should play unlike the rest; null for the default.
@export var ai_profile: AiProfile
## Later (milestone 22): the Spoils only this Villain gives.
@export var spoils: Array[Resource] = []


## The setup the Villain plays at [param tier], from 1 to 5.
func setup_for_tier(tier: int) -> MmPlayerSetup:
	if setups.size() == 1:
		return setups[0]
	return setups[clampi(tier, 1, TIERS) - 1]


## Why this Villain cannot be played, or "" if it can.
func validate() -> String:
	if setups.size() != 1 and setups.size() != TIERS:
		return "A Villain has one setup or %d, not %d." % [TIERS, setups.size()]
	return ""
