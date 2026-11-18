class_name CreatureTypesSource
extends RefCounted
## How the card tool's `creature-types` command rewrites CreatureTypes from Scryfall's
## catalog of creature types (CR 205.3m, engine ADR 0052): the types read from the catalog,
## what changed, and the engine's source file written out with the new list.

## The catalog: every creature type, as Scryfall lists it.
const CATALOG_URL: String = "https://api.scryfall.com/catalog/creature-types"
## The engine's file this rewrites.
const PATH: String = "res://addons/modmox_rules/src/cards/creature_types.gd"
## A line of the list is at most this long, its tab counted as one.
const LINE_LENGTH: int = 96
const HEADER: String = (
	"class_name CreatureTypes\n" +
	"extends RefCounted\n" +
	"## Every creature type there is (CR 205.3m), for \"choose a creature type\". Subtypes on cards\n" +
	"## stay free text (MmCardTypes), so this list says only what may be chosen. It is engine\n" +
	"## data, not Content: the rules define it. `card_tool.gd -- creature-types` rewrites it from\n" +
	"## Scryfall's catalog; a changed list changes what a saved answer means, so it is an engine\n" +
	"## version change (ADR 0010).\n" +
	"\n" +
	"## In alphabetical order, as CR 205.3m lists them. A ChooseCreatureTypeDecision's answer is an\n" +
	"## index into this list.\n" +
	"const ALL: Array[String] = [\n"
)
const FOOTER: String = (
	"\n" +
	"]\n" +
	"\n" +
	"\n" +
	"## Whether [param subtype] is a creature type.\n" +
	"static func is_creature_type(subtype: String) -> bool:\n" +
	"\treturn ALL.has(subtype)\n"
)


## The types in [param catalog], Scryfall's catalog object, sorted; empty when it is not one.
static func types_in(catalog: Variant) -> Array[String]:
	# Variant: parsed JSON is open-ended until checked.
	var types: Array[String] = []
	if not catalog is Dictionary or not (catalog as Dictionary).get("data", null) is Array:
		return types
	for entry: Variant in (catalog as Dictionary)["data"] as Array:
		if entry is String and not types.has(entry as String):
			types.append(entry as String)
	types.sort()
	return types


## The types in [param now] not in [param before].
static func added(before: Array[String], now: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for creature_type: String in now:
		if not before.has(creature_type):
			found.append(creature_type)
	return found


## The engine's creature_types.gd, listing [param types] in order.
static func source_of(types: Array[String]) -> String:
	var lines: PackedStringArray = []
	var line: String = "\t"
	for creature_type: String in types:
		var item: String = "\"%s\", " % creature_type.replace("\\", "\\\\").replace("\"", "\\\"")
		if line.length() + item.length() > LINE_LENGTH:
			lines.append(line.strip_edges(false, true))
			line = "\t"
		line += item
	lines.append(line.strip_edges(false, true))
	return HEADER + "\n".join(lines) + FOOTER
