class_name ReferenceArt
extends RefCounted
## The art a Portrait (game glossary) is drawn after: the art crop of a card's first printing
## (FirstPrinting, A227), kept in tools/sprites/reference/, which is never committed, under
## the card's key. The Portrait's grid file credits it in its header. fetch_reference.gd
## fetches it.

const FOLDER: String = "res://tools/sprites/reference/"


## The key a card's reference art, grid file and Portraits are named by: its name in snake
## case, as content/art/ names a card's art. Apostrophes are dropped and any other mark
## that is not a letter or digit splits words: "Mishra's Factory" is mishras_factory.
static func key_of(card_name: String) -> String:
	var key: String = ""
	var split: bool = false
	for character: String in card_name.to_lower():
		if character == "'" or character == "’":
			continue
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			if split and key != "":
				key += "_"
			key += character
			split = false
		else:
			split = true
	return key


## Where the reference art of [param key] is kept.
static func path_of(key: String) -> String:
	return FOLDER + key + ".jpg"


## The comment lines that credit [param printing], a Scryfall card object, at the head of a
## Portrait's grid file.
static func header(printing: Dictionary) -> PackedStringArray:
	var set_code: String = str(printing.get("set", ""))
	var set_name: String = str(printing.get("set_name", ""))
	var edition: String = "%s (%s)" % [set_name, set_code] if set_name != "" else set_code
	return [
		"; Drawn after the art of %s: %s #%s, by %s." % [
			printing.get("name", ""), edition, printing.get("collector_number", ""), printing.get("artist", "an unknown artist")],
		"; Scryfall ID: %s" % printing.get("id", ""),
	]


## Whether [param printings], Scryfall card objects, are of a card whose art is on its
## faces, such as a double-faced card, which FirstPrinting cannot choose from.
static func is_double_faced(printings: Array) -> bool:
	for printing: Variant in printings:
		if printing is Dictionary and (printing as Dictionary).has("card_faces") \
				and not (printing as Dictionary).has("image_uris"):
			return true
	return false
