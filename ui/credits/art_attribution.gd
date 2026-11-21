class_name ArtAttribution
extends RefCounted
## What the Credits' Art Attribution page lists (game glossary; milestone 19, signed off as
## step 3 of prototypes/run_ends): the artist of every picture the game borrows, read from
## the art manifests, in three groups each sorted by name. "Card Art", every card's and
## token's: "Lightning Bolt — Christopher Rush, LEA #161", a token as "Cat token". "Emblem
## Art", left out while no Emblem has art. "Portraits", the card art each was drawn after,
## gathered from the Portrait grids by tools/sprites/gather_portrait_credits.sh: "Portrait of
## Adorned Pouncer, after art by Slawomir Maniak, HOU #2".

const CARD_ART: String = "Card Art"
const EMBLEM_ART: String = "Emblem Art"
const PORTRAITS: String = "Portraits"
const PORTRAIT_MANIFEST: String = "res://ui/sprites/portraits/art.json"
const TOKENS: String = "res://content/tokens/"
const EMBLEMS: String = "res://content/emblems/"


## One heading and its lines.
class Group:
	extends RefCounted

	var heading: String
	var lines: Array[String] = []

	func _init(group_heading: String) -> void:
		heading = group_heading


## Every group the art manifests in Content give.
static func groups() -> Array[Group]:
	return groups_from(_read(ArtLibrary.MANIFEST), _read(ArtLibrary.EMBLEM_MANIFEST), _read(PORTRAIT_MANIFEST))


## The groups [param card_credits] (the card manifest's entries, by card or token key),
## [param emblem_credits] (by Emblem file name) and [param portrait_credits] (by Portrait)
## give, each left out when it lists nothing.
static func groups_from(card_credits: Dictionary, emblem_credits: Dictionary,
		portrait_credits: Dictionary) -> Array[Group]:
	var made: Array[Group] = []
	var names: Dictionary[String, String] = {}
	if not card_credits.is_empty():
		names = _card_names()
	var cards: Group = Group.new(CARD_ART)
	for key: String in card_credits:
		var named: String = _token_name(key) if key.begins_with(ArtLibrary.TOKENS) else names.get(key, "")
		if named != "":
			_add(cards, "%s — %s" % [named, _source(card_credits[key])])
	var emblems: Group = Group.new(EMBLEM_ART)
	for key: String in emblem_credits:
		var path: String = EMBLEMS + key + ".tres"
		var named: String = (load(path) as MmCardDefinition).name if ResourceLoader.exists(path) else key
		_add(emblems, "%s — %s" % [named, _source(emblem_credits[key])])
	var portraits: Group = Group.new(PORTRAITS)
	for key: String in portrait_credits:
		var credit: Dictionary = portrait_credits[key]
		_add(portraits, "Portrait of %s, after art by %s, %s #%s" % [credit.get("card", ""), credit.get("artist", ""),
			str(credit.get("set", "")).to_upper(), credit.get("collector_number", "")])
	for group: Group in [cards, emblems, portraits]:
		if not group.lines.is_empty():
			group.lines.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
			made.append(group)
	return made


## "Christopher Rush, LEA #161": an entry's artist, set code and collector number.
static func _source(credit: Dictionary) -> String:
	return "%s, %s #%s" % [credit.get("artist", ""), str(credit.get("set", "")).to_upper(),
		credit.get("collector_number", "")]


static func _add(group: Group, line: String) -> void:
	if not group.lines.has(line):
		group.lines.append(line)


## Each card's name, by its file's name.
static func _card_names() -> Dictionary[String, String]:
	var names: Dictionary[String, String] = {}
	for card: MmCardDefinition in ContentCards.all():
		names[card.resource_path.get_file().get_basename()] = card.name
	return names


## A token's name from its key ("tokens/cat_1_1_white"), "token" in lower case: "Cat token".
static func _token_name(key: String) -> String:
	var path: String = TOKENS + key.trim_prefix(ArtLibrary.TOKENS) + ".tres"
	if not ResourceLoader.exists(path):
		return ""
	return (load(path) as MmCardDefinition).name.replace(" Token", " token")


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# Variant: what the file holds is not known until it is parsed.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
