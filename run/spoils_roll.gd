class_name SpoilsRoll
extends RefCounted
## Rolls the Spoils of a win (milestone 18, ADR 0039) from the Villain's Rank where it was
## met, the Stage's Tier and the Villain's deck for that Tier, each part from a stream of
## its own of the Run Seed (ADR 0025). The numbers are placeholders, retuned against the
## Store's prices in milestone 24.

## The gold each Rank pays at Tier 1, from the first number to the second.
const GOLD: Dictionary[StageMap.Kind, Vector2i] = {
	StageMap.Kind.LESSER: Vector2i(15, 30),
	StageMap.Kind.ELITE: Vector2i(35, 55),
	StageMap.Kind.BOSS: Vector2i(85, 130),
}
## Each Tier past the first adds this share of Tier 1's gold to both ends of the range.
const GOLD_PER_TIER: float = 0.5
## How often each Rank pays 1, 2 or 3 cards, in tenths.
const CARD_ODDS: Dictionary[StageMap.Kind, Array] = {
	StageMap.Kind.LESSER: [6, 3, 1],
	StageMap.Kind.ELITE: [4, 4, 2],
	StageMap.Kind.BOSS: [0, 5, 5],
}


## The Spoils of beating [param villain], met at the Rank of a Node of [param rank], in a
## Stage of [param tier], drawn from [param random].
static func roll(rank: StageMap.Kind, tier: int, villain: Villain, random: RunRandom) -> Spoils:
	var made: Spoils = Spoils.new()
	var scale: float = 1.0 + GOLD_PER_TIER * (clampi(tier, 1, Villain.TIERS) - 1)
	var lowest: int = roundi(GOLD[rank].x * scale)
	var highest: int = roundi(GOLD[rank].y * scale)
	made.gold = lowest + random.pick(RunRandom.SPOILS_GOLD, highest - lowest + 1)
	var tickets: Array[MmRunCard] = []
	# One even ticket for each copy in the deck, never a basic land (ADR 0039).
	for run_card: MmRunCard in villain.setup_for_tier(tier).deck:
		if not run_card.base.supertypes.has(MmCardTypes.Supertype.BASIC):
			tickets.append(run_card)
	for index: int in mini(_card_count(rank, random), tickets.size()):
		var drawn: MmRunCard = tickets.pop_at(random.pick(RunRandom.SPOILS_CARDS, tickets.size()))
		var copy: MmRunCard = MmRunCard.new()
		copy.base = drawn.base
		made.cards.append(copy)
	return made


## How many cards a win at [param rank] pays, from 1 to 3, by CARD_ODDS.
static func _card_count(rank: StageMap.Kind, random: RunRandom) -> int:
	var tenth: int = random.pick(RunRandom.SPOILS_CARDS, 10)
	var odds: Array = CARD_ODDS[rank]
	for index: int in odds.size():
		tenth -= odds[index]
		if tenth < 0:
			return index + 1
	return odds.size()
