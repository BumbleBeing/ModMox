extends GutTest
## Game-side checks on the authored Card Definitions in res://content/cards (ADR 0002).

const CONTENT_ROOT: String = "res://content/cards"
const BASIC_LANDS: Array[String] = ["Plains", "Island", "Swamp", "Mountain", "Forest"]


func test_every_card_file_is_a_named_card_definition() -> void:
	var paths: PackedStringArray = _find_cards(CONTENT_ROOT)
	assert_gt(paths.size(), 0)
	for path: String in paths:
		var card: MmCardDefinition = load(path) as MmCardDefinition
		assert_not_null(card, "%s is not a Card Definition." % path)
		if card != null:
			assert_ne(card.name, "", "%s has no name." % path)


func test_no_two_cards_share_a_sub_resource() -> void:
	# Copying a sub-resource in the Inspector can leave two cards pointing at the same
	# object, so editing one silently changes the other.
	var cards: Dictionary[String, MmCardDefinition] = {}
	for path: String in _find_cards(CONTENT_ROOT):
		cards[path] = load(path) as MmCardDefinition

	assert_eq(_shared_sub_resources(cards), [])


func test_the_sharing_check_catches_a_shared_ability() -> void:
	var shared: ActivatedAbility = ActivatedAbility.new()
	var first: MmCardDefinition = MmCardDefinition.new()
	first.abilities = [shared]
	var second: MmCardDefinition = MmCardDefinition.new()
	second.abilities = [shared]

	var conflicts: Array[String] = _shared_sub_resources({"first": first, "second": second})

	assert_eq(conflicts, ["second shares a sub-resource with first"])


## Describes every sub-resource that belongs to more than one of [param cards].
func _shared_sub_resources(cards: Dictionary[String, MmCardDefinition]) -> Array[String]:
	var conflicts: Array[String] = []
	var owner_by_resource: Dictionary[int, String] = {}
	for path: String in cards:
		for sub_resource: Resource in _sub_resources(cards[path]):
			var key: int = sub_resource.get_instance_id()
			if owner_by_resource.has(key) and owner_by_resource[key] != path:
				conflicts.append("%s shares a sub-resource with %s" % [path, owner_by_resource[key]])
			owner_by_resource[key] = path
	return conflicts


func test_the_basic_lands_are_basic_lands_of_their_own_type() -> void:
	for land_type: String in BASIC_LANDS:
		var card: MmCardDefinition = load("%s/alpha/%s.tres" % [CONTENT_ROOT, land_type.to_lower()]) as MmCardDefinition
		assert_eq(card.name, land_type)
		assert_eq(card.card_types, [MmCardTypes.CardType.LAND])
		assert_eq(card.supertypes, [MmCardTypes.Supertype.BASIC])
		assert_eq(card.subtypes, [land_type])
		assert_eq(card.abilities.size(), 0, "A basic land's mana ability comes from its type.")


func test_a_basic_land_from_content_taps_for_its_mana_in_a_game() -> void:
	var forest: MmCardDefinition = load(CONTENT_ROOT + "/alpha/forest.tres") as MmCardDefinition
	var engine: MmEngine = MmEngine.start(_setup_with_deck_of(forest))

	var in_library: MmGameObject = engine.hero().library.objects()[0]
	var abilities: Array[MmAbility] = engine.game_state().characteristics_of(in_library).abilities

	assert_eq(abilities.size(), 1)
	var add_mana: AddManaEffect = (abilities[0] as ActivatedAbility).effects[0] as AddManaEffect
	assert_eq(add_mana.mana_type, MmMana.Type.GREEN)


func _setup_with_deck_of(card: MmCardDefinition) -> MmEncounterSetup:
	var deck: Array[MmRunCard] = []
	for _index: int in 20:
		var run_card: MmRunCard = MmRunCard.new()
		run_card.base = card
		deck.append(run_card)
	var setup: MmEncounterSetup = MmEncounterSetup.new()
	setup.hero = MmPlayerSetup.new()
	setup.hero.deck = deck
	setup.villain = MmPlayerSetup.new()
	setup.villain.deck = deck.duplicate()
	setup.starting_player_rule = MmEncounterSetup.StartingPlayerRule.HERO_STARTS
	return setup


## Every Resource reachable from [param root] through its properties, arrays included.
func _sub_resources(root: Resource) -> Array[Resource]:
	var found: Array[Resource] = []
	for property: Dictionary in root.get_property_list():
		if not (property["usage"] & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = root.get(property["name"])
		var candidates: Array = value if value is Array else [value]
		for candidate: Variant in candidates:
			if candidate is Resource and not (candidate is Script):
				found.append(candidate as Resource)
				found.append_array(_sub_resources(candidate as Resource))
	return found


func _find_cards(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		if file_name.ends_with(".tres"):
			found.append(dir_path.path_join(file_name))
	for sub_dir: String in dir.get_directories():
		found.append_array(_find_cards(dir_path.path_join(sub_dir)))
	return found
