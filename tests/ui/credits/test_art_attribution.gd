extends GutTest
## Art Attribution (milestone 19, signed off as step 3 of prototypes/run_ends): the artist of
## every picture the game borrows, grouped as card art (tokens among it), Emblem art and
## Portraits, each group sorted by name.


func _lines_of(groups: Array[ArtAttribution.Group], heading: String) -> Array[String]:
	for group: ArtAttribution.Group in groups:
		if group.heading == heading:
			return group.lines
	return []


## S9: Content's art is listed in the agreed forms, under "Card Art" and "Portraits".
func test_contents_art_is_listed_in_the_agreed_forms() -> void:
	var groups: Array[ArtAttribution.Group] = ArtAttribution.groups()
	var cards: Array[String] = _lines_of(groups, "Card Art")
	var portraits: Array[String] = _lines_of(groups, "Portraits")

	assert_has(cards, "Lightning Bolt — Christopher Rush, LEA #161")
	assert_has(cards, "Cat token — April Prime, TONE #1")
	assert_has(portraits, "Portrait of Adorned Pouncer, after art by Slawomir Maniak, HOU #2")
	assert_has(portraits, "Portrait of Frondland Felidar, after art by Steve Prescott, IKO #186",
			"The card's name ends at the first colon, though its set's name holds one.")


## S9: no "Emblem Art" while no Emblem has art.
func test_emblem_art_is_left_out_while_empty() -> void:
	var headings: Array[String] = []
	for group: ArtAttribution.Group in ArtAttribution.groups():
		headings.append(group.heading)

	assert_eq(headings, ["Card Art", "Portraits"] as Array[String])


## Every card and token with art is credited, once.
func test_every_picture_in_the_card_manifest_is_credited_once() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArtLibrary.MANIFEST))
	var cards: Array[String] = _lines_of(ArtAttribution.groups(), "Card Art")
	var seen: Dictionary[String, bool] = {}
	for line: String in cards:
		assert_false(seen.has(line), line)
		seen[line] = true

	assert_eq(cards.size(), manifest.size())


func test_each_group_is_sorted_by_name() -> void:
	for group: ArtAttribution.Group in ArtAttribution.groups():
		var sorted: Array[String] = group.lines.duplicate()
		sorted.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		assert_eq(group.lines, sorted, group.heading)


## An Emblem with art is credited under "Emblem Art", by its name.
func test_an_emblem_with_art_is_listed_under_emblem_art() -> void:
	var emblems: Dictionary = {"diviners_boon": {"artist": "Rebecca Guay", "set": "sok", "collector_number": "41"}}

	var groups: Array[ArtAttribution.Group] = ArtAttribution.groups_from({}, emblems, {})

	assert_eq(groups.size(), 1)
	assert_eq(groups[0].heading, "Emblem Art")
	var name: String = (load("res://content/emblems/diviners_boon.tres") as MmCardDefinition).name
	assert_eq(groups[0].lines, ["%s — Rebecca Guay, SOK #41" % name] as Array[String])


## The Portraits' credits are gathered from their grids, and the file is not stale.
func test_the_portrait_credits_match_the_grids() -> void:
	var credits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArtAttribution.PORTRAIT_MANIFEST))
	var grids: int = 0
	for file: String in DirAccess.get_files_at("res://tools/sprites/portraits/"):
		if file.ends_with(".txt") and FileAccess.get_file_as_string("res://tools/sprites/portraits/" + file).contains(
				"Drawn after the art of"):
			grids += 1
			assert_true(credits.has(file.get_basename()), file + ": run tools/sprites/gather_portrait_credits.sh")

	assert_eq(credits.size(), grids)
