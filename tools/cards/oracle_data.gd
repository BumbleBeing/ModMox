class_name OracleData
extends RefCounted
## The Oracle Data of every card in Content (ADR 0040), kept in content/cards/oracle.json and
## keyed by card file name, as the art manifest is. An entry holds what Scryfall says of the
## real card, its first printing's set and rarity, and the fields its Card Definition
## rebalances, under "rebalanced".

const PATH: String = "res://content/cards/oracle.json"
## The fields a Card Definition is held to, and the only ones it may rebalance. Rarity is
## not among them: it is the field rebalanced most (A3).
const CHECKED_FIELDS: PackedStringArray = ["name", "mana_cost", "type_line", "power", "toughness"]
## What an entry keeps of a Scryfall card object. Its set and rarity are its first printing's.
const CARD_FIELDS: PackedStringArray = [
	"oracle_id", "name", "mana_cost", "type_line", "power", "toughness", "oracle_text", "card_faces",
]

## Card file name → its entry. Parsed JSON, so open-ended until read.
var entries: Dictionary = {}


func _init() -> void:
	if not FileAccess.file_exists(PATH):
		return
	# Variant: parsed JSON is open-ended until checked.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		entries = parsed


func save() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries, "\t", true) + "\n")


## The entry for [param card], a Scryfall card object, whose first printing is
## [param first_printing].
static func entry_of(card: Dictionary, first_printing: Dictionary) -> Dictionary:
	var entry: Dictionary = {}
	for field: String in CARD_FIELDS:
		if card.has(field):
			entry[field] = card[field]
	if card.has("card_faces"):
		entry["layout"] = card.get("layout", "")
	entry["set_name"] = str(first_printing.get("set_name", ""))
	entry["rarity"] = str(first_printing.get("rarity", ""))
	return entry


## Each checked field in which [param definition] differs from its Oracle Data
## [param entry] without the entry saying it is rebalanced, and each rebalanced field that
## is not checked at all, as "rebalanced: <field>".
static func mismatches(definition: MmCardDefinition, entry: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = []
	# Array of Variants: parsed JSON.
	var rebalanced: Array = entry.get("rebalanced", []) as Array
	for field: Variant in rebalanced:
		if not CHECKED_FIELDS.has(str(field)):
			found.append("rebalanced: %s" % field)
	var oracle: MmCardDefinition = OracleReading.of(entry).definition
	for field: String in CHECKED_FIELDS:
		if not rebalanced.has(field) and not _agree(field, definition, oracle):
			found.append(field)
	return found


static func _agree(field: String, definition: MmCardDefinition, oracle: MmCardDefinition) -> bool:
	match field:
		"name":
			return definition.name == oracle.name
		"mana_cost":
			if definition.mana_cost == null or oracle.mana_cost == null:
				return definition.mana_cost == oracle.mana_cost
			return definition.mana_cost.generic == oracle.mana_cost.generic \
				and definition.mana_cost.symbols == oracle.mana_cost.symbols
		"type_line":
			return definition.supertypes == oracle.supertypes \
				and definition.card_types == oracle.card_types \
				and definition.subtypes == oracle.subtypes
		"power":
			return definition.power == oracle.power
		"toughness":
			return definition.toughness == oracle.toughness
	return false
