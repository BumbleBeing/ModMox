class_name PainHold
extends RefCounted
## When a player's panel shows their Pain Portrait (game glossary), and for how long: a
## player is hurt when their life total goes down from one snapshot to the next, counted
## net, whatever took it, and winces for longer the more they lost.

## The hold at Normal speed for each least amount of life lost, largest first.
const NORMAL_SECONDS: Array[Array] = [[11, 1.3], [7, 0.8], [3, 0.5], [1, 0.3]]


## How long a player who lost [param life_lost] life winces at [param speed].
static func seconds(life_lost: int, speed: GameSpeed.Speed) -> float:
	for tier: Array in NORMAL_SECONDS:
		if life_lost >= (tier[0] as int):
			# Normal speed is one of GameSpeed's scales, so the hold is set as one there.
			return GameSpeed.seconds((tier[1] as float) / GameSpeed.scale_of(GameSpeed.Speed.NORMAL), speed)
	return 0.0


## The life each player lost between [param previous] and [param snapshot], net of what they
## gained, for those who lost any. None for a first snapshot or an undo (ADR 0015).
static func losses(previous: EncounterSnapshot, snapshot: EncounterSnapshot) -> Dictionary[int, int]:
	var lost: Dictionary[int, int] = {}
	if previous == null or snapshot.is_rewind:
		return lost
	for player_id: int in snapshot.view.life_totals:
		var before: int = previous.view.life_totals.get(player_id, 0)
		var now: int = snapshot.view.life_totals[player_id]
		if now < before:
			lost[player_id] = before - now
	return lost
