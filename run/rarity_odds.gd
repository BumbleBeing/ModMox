class_name RarityOdds
extends RefCounted
## How likely each Rarity is to come up at each Tier, one table that a Store's cards, its
## Potions and the Mods its cards carry all share (ADR 0071), and that the Spoils' Items and
## the Trove draw from later (milestones 24 and 26). The numbers are placeholders (roadmap,
## milestone 24).

## For each Tier from 1 to 5, the chance in a hundred of Common, Uncommon, Rare and Mythic.
const ODDS: Array[Array] = [
	[55, 30, 12, 3],
	[48, 33, 15, 4],
	[40, 35, 20, 5],
	[30, 37, 26, 7],
	[20, 38, 32, 10],
]
## Common to Mythic: the Rarities anything is drawn at. Power-9 and Unique never are.
const RARITIES: int = 4


## A Rarity from 0 (Common) to 3 (Mythic), drawn at [param tier]'s odds from [param stream]
## of [param random].
static func roll(tier: int, random: RunRandom, stream: String) -> int:
	var odds: Array = ODDS[clampi(tier, 1, ODDS.size()) - 1]
	var chance: int = random.pick(stream, 100)
	for rarity: int in odds.size():
		chance -= int(odds[rarity])
		if chance < 0:
			return rarity
	return odds.size() - 1


## Which of [param held], the Rarities something can be drawn at, stands in for [param rolled]:
## itself when held, or else the nearest lower held, or with none lower the nearest higher,
## or -1 when nothing is held.
static func nearest(rolled: int, held: Array[int]) -> int:
	for rarity: int in range(rolled, -1, -1):
		if held.has(rarity):
			return rarity
	for rarity: int in range(rolled + 1, RARITIES):
		if held.has(rarity):
			return rarity
	return -1
