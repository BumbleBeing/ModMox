extends GutTest
## Every creature card and creature token in Content is of creature types the engine lists
## (CR 205.3m, ADR 0052), so "choose a creature type" can name any of them and a typo in a
## subtype is caught. An artifact creature may also have artifact types.

const FOLDERS: Array[String] = ["res://content/cards/", "res://content/tokens/"]
## The artifact types in Content. An artifact creature's subtypes may be of either kind
## (CR 205.3g), as Lion Sash is an Equipment Cat and Tough Cookie a Food Golem.
const ARTIFACT_TYPES: Array[String] = [AttachmentRules.EQUIPMENT, "Food"]


func test_every_printed_creature_subtype_is_a_creature_type() -> void:
	var checked: int = 0
	for folder: String in FOLDERS:
		for path: String in _files(folder):
			var definition: MmCardDefinition = load(path) as MmCardDefinition
			if definition == null or not definition.card_types.has(MmCardTypes.CardType.CREATURE):
				continue
			checked += 1
			var is_artifact: bool = definition.card_types.has(MmCardTypes.CardType.ARTIFACT)
			for subtype: String in definition.subtypes:
				if is_artifact and ARTIFACT_TYPES.has(subtype):
					continue
				assert_true(CreatureTypes.is_creature_type(subtype), "%s: %s is not a creature type." % [path, subtype])

	assert_gt(checked, 20, "The scan found the creatures.")


## Every .tres file under [param folder].
func _files(folder: String) -> Array[String]:
	var found: Array[String] = []
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_files(folder + sub + "/"))
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tres"):
			found.append(folder + file)
	return found
