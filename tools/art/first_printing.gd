class_name FirstPrinting
extends RefCounted
## Picks the printing whose art a card uses (A227): the earliest released paper printing
## with art, skipping digital-only, oversized and promo printings. Printings released the
## same day are ordered by collector number, so Alpha's first basic land art wins.


## The chosen printing among Scryfall card objects [param printings], or an empty
## Dictionary when none is usable.
static func choose(printings: Array) -> Dictionary:
	# Array of Variants: parsed Scryfall JSON is open-ended until checked.
	var usable: Array[Dictionary] = []
	for printing: Variant in printings:
		if not printing is Dictionary:
			continue
		var card: Dictionary = printing
		if card.get("digital", false) or card.get("oversized", false) or card.get("promo", false):
			continue
		if not (card.get("image_uris", {}) as Dictionary).has("art_crop"):
			continue
		usable.append(card)
	if usable.is_empty():
		return {}
	usable.sort_custom(_is_earlier)
	return usable[0]


static func _is_earlier(a: Dictionary, b: Dictionary) -> bool:
	var released_a: String = str(a.get("released_at", ""))
	var released_b: String = str(b.get("released_at", ""))
	if released_a != released_b:
		return released_a < released_b
	return _collector_order(a) < _collector_order(b)


## Collector numbers such as "47" or "294a", padded so they sort as numbers.
static func _collector_order(card: Dictionary) -> String:
	var number: String = str(card.get("collector_number", ""))
	var digits: String = ""
	for character: String in number:
		if character.is_valid_int():
			digits += character
		else:
			break
	return digits.lpad(6, "0") + number.substr(digits.length())
