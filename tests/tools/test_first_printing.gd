extends GutTest
## The art script uses each card's first printing (A227): the earliest released paper
## printing, skipping digital-only, oversized and promo ones.


func test_the_earliest_paper_printing_is_chosen() -> void:
	var printings: Array = [
		_printing("2ed", "1993-12-01", "200"),
		_printing("lea", "1993-08-05", "190"),
		_printing("leb", "1993-10-04", "191"),
	]

	assert_eq(FirstPrinting.choose(printings).get("set"), "lea")


func test_digital_oversized_and_promo_printings_are_skipped() -> void:
	var digital: Dictionary = _printing("vma", "1990-01-01", "1")
	digital["digital"] = true
	var oversized: Dictionary = _printing("oleb", "1990-01-02", "1")
	oversized["oversized"] = true
	var promo: Dictionary = _printing("p30a", "1990-01-03", "1")
	promo["promo"] = true

	var chosen: Dictionary = FirstPrinting.choose([digital, oversized, promo, _printing("lea", "1993-08-05", "47")])

	assert_eq(chosen.get("set"), "lea")


func test_a_printing_without_art_is_skipped() -> void:
	var no_art: Dictionary = _printing("lea", "1993-08-05", "1")
	no_art.erase("image_uris")

	assert_eq(FirstPrinting.choose([no_art, _printing("leb", "1993-10-04", "2")]).get("set"), "leb")


func test_printings_released_the_same_day_are_ordered_by_collector_number() -> void:
	# Alpha has two arts of each basic land: the lower collector number comes first.
	var chosen: Dictionary = FirstPrinting.choose([
		_printing("lea", "1993-08-05", "10"),
		_printing("lea", "1993-08-05", "9"),
	])

	assert_eq(chosen.get("collector_number"), "9", "Compared as numbers, not as text.")


func test_no_usable_printing_gives_nothing() -> void:
	var promo: Dictionary = _printing("p30a", "1990-01-03", "1")
	promo["promo"] = true

	assert_true(FirstPrinting.choose([promo]).is_empty())


func _printing(set_code: String, released: String, number: String) -> Dictionary:
	return {
		"set": set_code, "released_at": released, "collector_number": number,
		"digital": false, "oversized": false, "promo": false,
		"image_uris": {"art_crop": "https://example.invalid/%s/%s.jpg" % [set_code, number]},
	}
