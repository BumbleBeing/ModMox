extends GutTest
## Game-side checks on the authored Card Definitions in res://content/cards (ADR 0002).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
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


func test_the_alpha_spells_have_the_right_printed_characteristics() -> void:
	var expected: Dictionary[String, Array] = {
		"lightning_bolt": ["Lightning Bolt", MmCardTypes.CardColor.RED],
		"ancestral_recall": ["Ancestral Recall", MmCardTypes.CardColor.BLUE],
		"dark_ritual": ["Dark Ritual", MmCardTypes.CardColor.BLACK],
	}
	for file_name: String in expected:
		var printed: MmCharacteristics = MmCharacteristics.printed(_alpha(file_name))
		assert_eq(printed.name, expected[file_name][0])
		assert_eq(printed.card_types, [MmCardTypes.CardType.INSTANT], file_name)
		assert_eq(printed.colors, [expected[file_name][1]], file_name)
		assert_eq(printed.mana_value(), 1, file_name)


func test_lightning_bolt_deals_three_damage_to_a_player() -> void:
	var engine: MmEngine = _hero_ready_to_cast(_alpha("lightning_bolt"), "mountain")

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Lightning Bolt"), [MmReference.to_player(engine.villain().id)])
	_resolve(engine)

	assert_eq(engine.villain().life, 17)


func test_lightning_bolt_can_target_creatures_and_players_only() -> void:
	# Its filter is saved with default values left out; check it still means "any target".
	var spec: TargetSpec = (_alpha("lightning_bolt").abilities[0] as SpellAbility).targets[0]
	var engine: MmEngine = _hero_ready_to_cast(_alpha("lightning_bolt"), "mountain")
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var land: MmReference = MmReference.to_object(Scenario.first_permanent_of(engine, engine.hero().id))

	assert_true(spec.filter.matches(engine.game_state(), MmReference.to_player(engine.villain().id), context))
	assert_false(spec.filter.matches(engine.game_state(), land, context), "A land is not a creature.")


func test_ancestral_recall_makes_its_target_draw_three() -> void:
	var engine: MmEngine = _hero_ready_to_cast(_alpha("ancestral_recall"), "island")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Ancestral Recall"), [MmReference.to_player(engine.hero().id)])
	var hand_before: int = engine.hero().hand.size()

	_resolve(engine)

	assert_eq(engine.hero().hand.size(), hand_before + 3)


func test_dark_ritual_adds_three_black_mana_when_it_resolves() -> void:
	var engine: MmEngine = _hero_ready_to_cast(_alpha("dark_ritual"), "swamp")

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Dark Ritual"))
	assert_eq(engine.hero().mana_pool().size(), 0, "A spell is not a mana ability.")
	_resolve(engine)

	var pool: Array[MmMana] = engine.hero().mana_pool()
	assert_eq(pool.size(), 3)
	for mana: MmMana in pool:
		assert_eq(mana.type, MmMana.Type.BLACK)


func _alpha(file_name: String) -> MmCardDefinition:
	return load("%s/alpha/%s.tres" % [CONTENT_ROOT, file_name]) as MmCardDefinition


## The Hero in their first main phase with one basic land of [param land_file] in play and
## [param spell] in hand.
func _hero_ready_to_cast(spell: MmCardDefinition, land_file: String) -> MmEngine:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(_alpha(land_file), 20, spell, 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, spell.name))
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


func _resolve(engine: MmEngine) -> void:
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)


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
