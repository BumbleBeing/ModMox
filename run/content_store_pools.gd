class_name ContentStorePools
extends RefCounted
## The Store Pools authored in Content (milestone 24, ADR 0071): one list for each Tier, in
## content/store_pools/tier_<N>.txt, each line a card's path under content/cards/ without its
## extension ("alpha/grizzly_bears"). A list is plain text so that it can be pruned by hand:
## a blank line, or one that begins with "#", is skipped. Each Tier's list is its own, and a
## card may be on several. Never a basic land nor a Power-9 card (test_store_pool_content.gd).
## Later (milestone 35): the Bazaar's unlocks join the pools of their Tiers.

const FOLDER: String = "res://content/store_pools/"
const FILE: String = FOLDER + "tier_%d.txt"
## Where a line's card is.
const CARDS: String = "res://content/cards/%s.tres"
const COMMENT: String = "#"


## The cards of [param tier]'s Store Pool, in the order listed.
static func pool(tier: int) -> Array[MmCardDefinition]:
	var cards: Array[MmCardDefinition] = []
	for line: String in lines_of(tier):
		cards.append(load(CARDS % line) as MmCardDefinition)
	return cards


## The lines of [param tier]'s list that name a card, or none if it has no list.
static func lines_of(tier: int) -> Array[String]:
	var path: String = FILE % tier
	if not FileAccess.file_exists(path):
		return []
	return lines_in(FileAccess.get_file_as_string(path))


## The lines of [param text] that name a card, each trimmed, with blank lines and comments
## left out.
static func lines_in(text: String) -> Array[String]:
	var found: Array[String] = []
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed != "" and not trimmed.begins_with(COMMENT):
			found.append(trimmed)
	return found
