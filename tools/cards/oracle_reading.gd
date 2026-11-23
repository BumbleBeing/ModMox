class_name OracleReading
extends RefCounted
## What the card tool reads from a card's Oracle Data (ADR 0040): a Card Definition holding
## its printed characteristics and no abilities, the folder and file it goes in, and
## everything it could not read. It never guesses. Whatever it cannot read is named in
## refusals, for the session adding the card to settle or for the engine to gain first.

## Their Rarity is Power-9, whatever their printing says (ADR 0033).
const POWER_NINE: Array[String] = [
	"Ancestral Recall", "Black Lotus", "Mox Emerald", "Mox Jet", "Mox Pearl", "Mox Ruby",
	"Mox Sapphire", "Time Walk", "Timetwister",
]
## The early sets are better known by a short name, and Alpha's folder already has one.
const SET_NICKNAMES: Dictionary[String, String] = {
	"Limited Edition Alpha": "alpha",
	"Limited Edition Beta": "beta",
	"Unlimited Edition": "unlimited",
	"Revised Edition": "revised",
}
## Scryfall's rarities and the game's. Scryfall's "special" and "bonus" have none.
const RARITIES: Dictionary[String, MmCardDefinition.Rarity] = {
	"common": MmCardDefinition.Rarity.COMMON,
	"uncommon": MmCardDefinition.Rarity.UNCOMMON,
	"rare": MmCardDefinition.Rarity.RARE,
	"mythic": MmCardDefinition.Rarity.MYTHIC,
}
const CARD_TYPES: Dictionary[String, MmCardTypes.CardType] = {
	"Artifact": MmCardTypes.CardType.ARTIFACT,
	"Creature": MmCardTypes.CardType.CREATURE,
	"Enchantment": MmCardTypes.CardType.ENCHANTMENT,
	"Instant": MmCardTypes.CardType.INSTANT,
	"Land": MmCardTypes.CardType.LAND,
	"Sorcery": MmCardTypes.CardType.SORCERY,
}
const SUPERTYPES: Dictionary[String, MmCardTypes.Supertype] = {
	"Basic": MmCardTypes.Supertype.BASIC,
	"Legendary": MmCardTypes.Supertype.LEGENDARY,
}
## The mana symbols the engine has besides a generic amount, by the letter in the braces.
const MANA_SYMBOLS: Dictionary[String, MmMana.Type] = {
	"W": MmMana.Type.WHITE,
	"U": MmMana.Type.BLUE,
	"B": MmMana.Type.BLACK,
	"R": MmMana.Type.RED,
	"G": MmMana.Type.GREEN,
	"C": MmMana.Type.COLORLESS,
}
## Letters with marks, as they are written in a file name.
const PLAIN_LETTERS: Dictionary[String, String] = {
	"á": "a", "à": "a", "â": "a", "ä": "a", "æ": "ae", "é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "î": "i", "ï": "i", "ó": "o", "ô": "o", "ö": "o", "ú": "u", "û": "u", "ü": "u",
}

var definition: MmCardDefinition = MmCardDefinition.new()
## The folder under content/cards/ named for the card's first set.
var folder: String = ""
var file_name: String = ""
## Each thing that could not be read, and why.
var refusals: PackedStringArray = []


## What can be read of [param card], a Scryfall card object or an Oracle Data entry.
static func of(card: Dictionary) -> OracleReading:
	# Dictionary of Variants: Oracle Data is parsed JSON, open-ended until checked.
	var reading: OracleReading = OracleReading.new()
	var card_name: String = str(card.get("name", ""))
	reading.definition.name = card_name
	reading.file_name = file_name_of(card_name)
	reading.folder = folder_of(str(card.get("set_name", "")))
	if card.has("card_faces") and card.get("layout", "") != "adventure":
		reading.refusals.append("two faces (%s): Set Aside" % card.get("layout", ""))
		return reading
	var front: Dictionary = card
	if card.has("card_faces"):
		# An Adventurer card (CR 715, engine ADR 0078): the creature is the card, named and
		# filed for it, and its Adventure is read from the second face.
		var faces: Array = card.get("card_faces", []) as Array  # Array of Variants: parsed JSON.
		front = faces[0] as Dictionary
		reading.definition.name = str(front.get("name", ""))
		reading.file_name = file_name_of(reading.definition.name)
		var back: OracleReading = OracleReading.new()
		back._read_face(faces[1] as Dictionary, {})
		back.definition.name = str((faces[1] as Dictionary).get("name", ""))
		reading.definition.adventure = back.definition
		for refusal: String in back.refusals:
			reading.refusals.append("adventure: " + refusal)
	reading._read_face(front, card)
	reading._read_rarity(str(card.get("rarity", "")), card_name)
	return reading


## The folder under content/cards/ for cards first printed in [param set_name].
static func folder_of(set_name: String) -> String:
	return SET_NICKNAMES[set_name] if SET_NICKNAMES.has(set_name) else _snake_case(set_name)


## The name, without ".tres", of the file the card [param card_name] is written to.
static func file_name_of(card_name: String) -> String:
	return _snake_case(card_name)


## Reads [param face]'s mana cost and type line, and the power and toughness [param numbers]
## gives, a whole card's or an Adventurer card's, which keeps them outside its faces.
func _read_face(face: Dictionary, numbers: Dictionary) -> void:
	_read_mana_cost(str(face.get("mana_cost", "")))
	_read_type_line(str(face.get("type_line", "")))
	definition.power = _read_number(numbers, "power")
	definition.toughness = _read_number(numbers, "toughness")


func _read_mana_cost(text: String) -> void:
	if text == "":
		# CR 202.1b: a card with no mana cost, such as a land, which is not a cost of {0}.
		return
	var cost: MmManaCost = MmManaCost.new()
	var read_length: int = 0
	for found: RegExMatch in RegEx.create_from_string("\\{([^}]*)\\}").search_all(text):
		read_length += found.get_string().length()
		var symbol: String = found.get_string(1)
		if symbol.is_valid_int():
			cost.generic += symbol.to_int()
		elif symbol == "X":
			cost.x_count += 1  # CR 107.3, engine ADR 0076.
		elif MANA_SYMBOLS.has(symbol):
			cost.symbols.append(MANA_SYMBOLS[symbol])
		elif _is_two_color_hybrid(symbol):
			# CR 107.4e, engine ADR 0077: either half pays it.
			var halves: PackedStringArray = symbol.split("/")
			cost.hybrid_symbols.append(Vector2i(MANA_SYMBOLS[halves[0]], MANA_SYMBOLS[halves[1]]))
		else:
			refusals.append("mana cost: {%s} is not a symbol the engine has" % symbol)
	if read_length != text.length():
		refusals.append("mana cost: %s is not only symbols" % text)
	definition.mana_cost = cost


## Whether [param symbol], read between braces, is a hybrid symbol of two different colors,
## such as B/R. A monocolored hybrid symbol ({2/W}) and Phyrexian ones ({B/P}) are not in the
## game (ADR 0001).
static func _is_two_color_hybrid(symbol: String) -> bool:
	var halves: PackedStringArray = symbol.split("/")
	return halves.size() == 2 and halves[0] != halves[1] and MmMana.COLORS.has(MANA_SYMBOLS.get(halves[0], -1)) \
		and MmMana.COLORS.has(MANA_SYMBOLS.get(halves[1], -1))


func _read_type_line(text: String) -> void:
	var halves: PackedStringArray = text.split(" — ", true, 1)
	for word: String in halves[0].split(" ", false):
		if SUPERTYPES.has(word):
			definition.supertypes.append(SUPERTYPES[word])
		elif CARD_TYPES.has(word):
			definition.card_types.append(CARD_TYPES[word])
		else:
			refusals.append("type line: %s is not a type the engine has" % word)
	if halves.size() > 1:
		for subtype: String in halves[1].split(" ", false):
			definition.subtypes.append(subtype)


## The printed number in [param card]'s [param field], or 0 when it has none.
func _read_number(card: Dictionary, field: String) -> int:
	if not card.has(field):
		return 0
	var text: String = str(card[field])
	if text.is_valid_int():
		return text.to_int()
	# CR 604.3: a "*" is defined by a characteristic-defining ability, composed in the session.
	refusals.append("%s is %s: needs a characteristic-defining ability" % [field, text])
	return 0


func _read_rarity(rarity: String, card_name: String) -> void:
	if POWER_NINE.has(card_name):
		definition.rarity = MmCardDefinition.Rarity.POWER_NINE
	elif RARITIES.has(rarity):
		definition.rarity = RARITIES[rarity]
	else:
		refusals.append("rarity is %s: the designer chooses one" % rarity)


## [param text] in lower case, its marks taken off its letters and its apostrophes left out,
## with every other run of characters that are not letters or digits made one underscore.
static func _snake_case(text: String) -> String:
	var plain: String = ""
	for character: String in text.to_lower():
		plain += str(PLAIN_LETTERS.get(character, character))
	plain = plain.replace("'", "").replace("’", "")
	var words: PackedStringArray = []
	for found: RegExMatch in RegEx.create_from_string("[a-z0-9]+").search_all(plain):
		words.append(found.get_string())
	return "_".join(words)
