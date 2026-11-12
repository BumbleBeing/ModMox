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


func test_counterspell_is_a_blue_instant_for_two_blue_mana() -> void:
	var printed: MmCharacteristics = MmCharacteristics.printed(_alpha("counterspell"))

	assert_eq(printed.name, "Counterspell")
	assert_eq(printed.card_types, [MmCardTypes.CardType.INSTANT])
	assert_eq(printed.colors, [MmCardTypes.CardColor.BLUE])
	assert_eq(printed.mana_cost.generic, 0)
	assert_eq(printed.mana_cost.symbols, [MmMana.Type.BLUE, MmMana.Type.BLUE] as Array[MmMana.Type])


func test_counterspell_counters_a_spell_so_it_never_resolves() -> void:
	var cards: Array[MmCardDefinition] = Scenario.cycled([_alpha("island"), _alpha("island"), _alpha("counterspell"), _alpha("ancestral_recall")])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			return Scenario.ready_in_main(running, 5, 3, "Counterspell") and Scenario.card_in_hand(running, running.hero(), "Ancestral Recall") != -1)
	assert_not_null(engine, "No seed gave the needed hand.")
	var hero: MmPlayer = engine.hero()
	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, hero, "Counterspell")), "There is no spell to target yet.")
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Ancestral Recall"), [MmReference.to_player(hero.id)])
	var recall: int = engine.view_for(hero).stack[0].id
	var hand_before: int = hero.hand.size()

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counterspell"), [MmReference.to_object(recall)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(hero.hand.size(), hand_before - 1, "Counterspell left the hand, and nothing was drawn.")
	assert_eq(Scenario.names(engine, hero.graveyard), ["Ancestral Recall", "Counterspell"])


func test_dark_ritual_adds_three_black_mana_when_it_resolves() -> void:
	var engine: MmEngine = _hero_ready_to_cast(_alpha("dark_ritual"), "swamp")

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Dark Ritual"))
	assert_eq(engine.hero().mana_pool().size(), 0, "A spell is not a mana ability.")
	_resolve(engine)

	var pool: Array[MmMana] = engine.hero().mana_pool()
	assert_eq(pool.size(), 3)
	for mana: MmMana in pool:
		assert_eq(mana.type, MmMana.Type.BLACK)


func test_the_alpha_creatures_have_the_right_printed_characteristics() -> void:
	var expected: Dictionary[String, Array] = {
		"grizzly_bears": ["Grizzly Bears", ["Bear"], MmCardTypes.CardColor.GREEN, 2, 2, 2],
		"hill_giant": ["Hill Giant", ["Giant"], MmCardTypes.CardColor.RED, 4, 3, 3],
		"elvish_archers": ["Elvish Archers", ["Elf", "Archer"], MmCardTypes.CardColor.GREEN, 2, 1, 2],
	}
	for file_name: String in expected:
		var printed: MmCharacteristics = MmCharacteristics.printed(_alpha(file_name))
		assert_eq(printed.name, expected[file_name][0])
		assert_eq(printed.card_types, [MmCardTypes.CardType.CREATURE], file_name)
		assert_eq(printed.subtypes, expected[file_name][1], file_name)
		assert_eq(printed.colors, [expected[file_name][2]], file_name)
		assert_eq(printed.mana_value(), expected[file_name][3], file_name)
		assert_eq(printed.power, expected[file_name][4], file_name)
		assert_eq(printed.toughness, expected[file_name][5], file_name)
		assert_eq(printed.has_ability(FirstStrikeAbility), file_name == "elvish_archers", file_name)


func test_grizzly_bears_is_cast_with_forests_and_enters_the_battlefield_as_a_two_two() -> void:
	var bears: MmCardDefinition = _alpha("grizzly_bears")
	var cards: Array[MmCardDefinition] = Scenario.deck_of(_alpha("forest"), 20, bears, 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 3, 2, "Grizzly Bears"))
	assert_not_null(engine, "No seed gave the needed hand.")

	assert_eq(Scenario.cast_and_resolve(engine, "Grizzly Bears"), "")

	var on_battlefield: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	assert_ne(on_battlefield, -1)
	var characteristics: MmCharacteristics = engine.game_state().characteristics_of(engine.game_state().object(on_battlefield))
	assert_eq([characteristics.power, characteristics.toughness], [2, 2])


func test_hill_giant_deals_three_combat_damage() -> void:
	var giant: MmCardDefinition = Scenario.free_copy(_alpha("hill_giant"))
	var engine: MmEngine = Scenario.combat_ready([giant], [])
	assert_not_null(engine, "No seed gave the needed hand.")

	Scenario.declare_attackers(engine, Scenario.permanents_named(engine, engine.hero().id, "Hill Giant"))
	Scenario.pass_until_step(engine, MmTurn.Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 17)


func test_lightning_bolt_destroys_grizzly_bears() -> void:
	var bolt: MmCardDefinition = Scenario.free_copy(_alpha("lightning_bolt"))
	var engine: MmEngine = Scenario.combat_ready([], [Scenario.free_copy(_alpha("grizzly_bears"))], [bolt])
	assert_not_null(engine, "No seed gave the needed hand.")
	var bears: int = Scenario.permanent_named(engine, engine.villain().id, "Grizzly Bears")

	Scenario.cast_and_resolve(engine, "Lightning Bolt", [MmReference.to_object(bears)])

	assert_eq(Scenario.names(engine, engine.villain().graveyard), ["Grizzly Bears"])


func test_elvish_archers_kill_a_one_one_blocker_before_it_strikes_back() -> void:
	var archers: MmCardDefinition = Scenario.free_copy(_alpha("elvish_archers"))
	var engine: MmEngine = Scenario.combat_ready([archers], [Scenario.creature("Goblin", 1, 1)])
	var archers_id: int = Scenario.permanent_named(engine, engine.hero().id, "Elvish Archers")
	var goblin: int = Scenario.permanent_named(engine, engine.villain().id, "Goblin")
	Scenario.declare_attackers(engine, [archers_id])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[goblin, archers_id]])

	Scenario.pass_until_step(engine, MmTurn.Step.END_OF_COMBAT)

	assert_eq(Scenario.names(engine, engine.villain().graveyard), ["Goblin"])
	assert_eq(Scenario.damage_on(engine, archers_id), 0)


func test_three_elvish_archers_kill_a_blocked_hill_giant_before_it_strikes() -> void:
	var archers: MmCardDefinition = Scenario.free_copy(_alpha("elvish_archers"))
	var giant: MmCardDefinition = Scenario.free_copy(_alpha("hill_giant"))
	var engine: MmEngine = Scenario.combat_ready([giant], [archers, archers, archers])
	assert_not_null(engine, "No seed gave the needed hand.")
	var giant_id: int = Scenario.permanent_named(engine, engine.hero().id, "Hill Giant")
	var blocks: Array = []
	for archer_id: int in Scenario.permanents_named(engine, engine.villain().id, "Elvish Archers"):
		blocks.append([archer_id, giant_id])
	Scenario.declare_attackers(engine, [giant_id])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, blocks)

	Scenario.pass_until_step(engine, MmTurn.Step.END_OF_COMBAT)

	assert_eq(Scenario.names(engine, engine.hero().graveyard), ["Hill Giant"])
	assert_eq(Scenario.permanents_named(engine, engine.villain().id, "Elvish Archers").size(), 3, "No Archer was hurt.")
	assert_eq(Scenario.combat_damage_events(engine).size(), 3)


func test_ancestral_recall_from_a_short_library_makes_its_target_lose() -> void:
	var recall: MmCardDefinition = Scenario.free_copy(_alpha("ancestral_recall"))
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.copies(recall, 8), Scenario.copies(Scenario.vanilla("Card"), 40))
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_step(engine, 1, MmTurn.Step.PRECOMBAT_MAIN)

	Scenario.cast_and_resolve(engine, "Ancestral Recall", [MmReference.to_player(engine.hero().id)])

	assert_eq(engine.outcome(), MmEngine.Outcome.VILLAIN_WON)
	assert_eq(engine.hero().loss_reason, MmPlayer.LossReason.EMPTY_LIBRARY)


func test_the_alpha_artifacts_have_the_right_printed_characteristics() -> void:
	var expected: Dictionary[String, Array] = {
		"ankh_of_mishra": ["Ankh of Mishra", 2],
		"howling_mine": ["Howling Mine", 2],
		"ivory_tower": ["Ivory Tower", 1],
	}
	for file_name: String in expected:
		var printed: MmCharacteristics = MmCharacteristics.printed(_alpha(file_name))
		assert_eq(printed.name, expected[file_name][0])
		assert_eq(printed.card_types, [MmCardTypes.CardType.ARTIFACT], file_name)
		assert_eq(printed.colors, [], file_name)
		assert_eq(printed.mana_value(), expected[file_name][1], file_name)
		assert_true(printed.has_ability(TriggeredAbility), file_name)


func test_ankh_of_mishra_damages_the_controller_of_each_land_that_enters() -> void:
	var engine: MmEngine = _artifact_cast_on_turn_three("ankh_of_mishra", "mountain")

	Scenario.play_until_step(engine, 4, MmTurn.Step.PRECOMBAT_MAIN)
	Scenario.play_first_land(engine)
	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().life, 18)
	assert_eq(engine.hero().life, 20)


func test_howling_mine_gives_each_player_an_extra_card_in_their_draw_step() -> void:
	var engine: MmEngine = _artifact_cast_on_turn_three("howling_mine", "island")
	var hand_before: int = engine.villain().hand.size()

	Scenario.play_until_step(engine, 4, MmTurn.Step.DRAW)
	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().hand.size(), hand_before + 2)


func test_ivory_tower_gains_life_for_each_card_in_hand_beyond_four() -> void:
	var tower: MmCardDefinition = _alpha("ivory_tower")
	var cards: Array[MmCardDefinition] = Scenario.deck_of(_alpha("plains"), 20, tower, 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, "Ivory Tower"))
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(Scenario.cast_and_resolve(engine, "Ivory Tower"), "")
	var hand_at_upkeep: int = engine.hero().hand.size()
	assert_eq(hand_at_upkeep, 5, "Seven, minus the Plains and the Tower.")

	Scenario.play_until_step(engine, 3, MmTurn.Step.UPKEEP)
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 21)


## The Hero's second turn (Game Turn 3) after casting the Alpha artifact in
## [param file_name] with two lands from [param land_file].
func _artifact_cast_on_turn_three(file_name: String, land_file: String) -> MmEngine:
	var artifact: MmCardDefinition = _alpha(file_name)
	var cards: Array[MmCardDefinition] = Scenario.deck_of(_alpha(land_file), 20, artifact, 20)
	var lands: Array[MmCardDefinition] = Scenario.copies(_alpha("forest"), 40)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, lands),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 3, 2, artifact.name))
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(Scenario.cast_and_resolve(engine, artifact.name), "")
	return engine


func test_the_milestone_nine_cards_have_the_right_printed_characteristics() -> void:
	var white: MmCardTypes.CardColor = MmCardTypes.CardColor.WHITE
	var red: MmCardTypes.CardColor = MmCardTypes.CardColor.RED
	var green: MmCardTypes.CardColor = MmCardTypes.CardColor.GREEN
	# file: [name, card type, colors, mana value, subtypes, power, toughness, keyword or null]
	var expected: Dictionary[String, Array] = {
		"giant_growth": ["Giant Growth", MmCardTypes.CardType.INSTANT, [green], 1, [], 0, 0, null],
		"serra_angel": ["Serra Angel", MmCardTypes.CardType.CREATURE, [white], 5, ["Angel"], 4, 4, VigilanceAbility],
		"giant_spider": ["Giant Spider", MmCardTypes.CardType.CREATURE, [green], 4, ["Spider"], 2, 4, ReachAbility],
		"wall_of_stone": ["Wall of Stone", MmCardTypes.CardType.CREATURE, [red], 3, ["Wall"], 0, 8, DefenderAbility],
		"keldon_warlord": ["Keldon Warlord", MmCardTypes.CardType.CREATURE, [red], 4, ["Human", "Barbarian"], 0, 0, CharacteristicDefiningAbility],
	}
	for file_name: String in expected:
		var facts: Array = expected[file_name]
		var printed: MmCharacteristics = MmCharacteristics.printed(_alpha(file_name))
		assert_eq(printed.name, facts[0])
		assert_eq(printed.card_types, [facts[1]], file_name)
		assert_eq(printed.colors, facts[2], file_name)
		assert_eq(printed.mana_value(), facts[3], file_name)
		assert_eq(printed.subtypes, facts[4], file_name)
		assert_eq([printed.power, printed.toughness], [facts[5], facts[6]], file_name)
		if facts[7] != null:
			assert_true(printed.has_ability(facts[7]), file_name)
	assert_true(MmCharacteristics.printed(_alpha("serra_angel")).has_ability(FlyingAbility))
	assert_true(MmCharacteristics.printed(_alpha("keldon_warlord")).is_power_variable, "Printed as */*.")


func test_giant_growth_gives_plus_three_plus_three_until_end_of_turn() -> void:
	var growth: MmCardDefinition = Scenario.free_copy(_alpha("giant_growth"))
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("grizzly_bears"))], [], [growth])
	assert_not_null(engine, "No seed gave the needed hand.")
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	Scenario.declare_attackers(engine, [bears])

	Scenario.cast_and_resolve(engine, "Giant Growth", [MmReference.to_object(bears)])
	Scenario.play_until_game_turn(engine, 4)

	assert_eq(engine.villain().life, 15, "A 5/5 attacked.")
	assert_eq(Scenario.pt(engine, bears), [2, 2], "Back to normal after the turn.")


func test_serra_angel_attacks_without_tapping_over_ground_blockers() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("serra_angel"))], [Scenario.free_copy(_alpha("grizzly_bears"))])
	var angel: int = Scenario.permanent_named(engine, engine.hero().id, "Serra Angel")

	Scenario.declare_attackers(engine, [angel])
	Scenario.pass_until_step(engine, MmTurn.Step.DECLARE_BLOCKERS)

	assert_false(engine.game_state().object(angel).is_tapped)
	assert_true(engine.pending_decision() is PriorityDecision, "Grizzly Bears cannot block it.")
	Scenario.pass_until_step(engine, MmTurn.Step.END_OF_COMBAT)
	assert_eq(engine.villain().life, 16)


func test_giant_spider_can_block_serra_angel() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("serra_angel"))], [Scenario.free_copy(_alpha("giant_spider"))])
	var angel: int = Scenario.permanent_named(engine, engine.hero().id, "Serra Angel")
	var spider: int = Scenario.permanent_named(engine, engine.villain().id, "Giant Spider")
	Scenario.declare_attackers(engine, [angel])
	Scenario.pass_to_blockers(engine)

	assert_eq(Scenario.declare_blockers(engine, [[spider, angel]]), "")
	Scenario.pass_until_step(engine, MmTurn.Step.END_OF_COMBAT)

	assert_eq(Scenario.names(engine, engine.villain().graveyard), ["Giant Spider"])
	assert_eq(Scenario.damage_on(engine, angel), 2)


func test_wall_of_stone_cannot_attack() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("wall_of_stone")), Scenario.free_copy(_alpha("grizzly_bears"))], [])

	var decision: DeclareAttackersDecision = engine.pending_decision() as DeclareAttackersDecision

	assert_eq(decision.candidate_ids, [Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")])


func test_keldon_warlord_counts_the_non_wall_creatures_its_controller_controls() -> void:
	var warlord: MmCardDefinition = Scenario.free_copy(_alpha("keldon_warlord"))
	var engine: MmEngine = Scenario.combat_ready(
		[warlord, Scenario.free_copy(_alpha("grizzly_bears")), Scenario.free_copy(_alpha("wall_of_stone"))],
		[Scenario.free_copy(_alpha("grizzly_bears"))])
	assert_not_null(engine, "No seed gave the needed hand.")

	var warlord_id: int = Scenario.permanent_named(engine, engine.hero().id, "Keldon Warlord")

	assert_eq(Scenario.pt(engine, warlord_id), [2, 2])


func test_the_milestone_ten_cards_have_the_right_printed_characteristics() -> void:
	var white: MmCardTypes.CardColor = MmCardTypes.CardColor.WHITE
	var black: MmCardTypes.CardColor = MmCardTypes.CardColor.BLACK
	var expected: Dictionary[String, Array] = {
		"fog": ["Fog", MmCardTypes.CardType.INSTANT, [MmCardTypes.CardColor.GREEN], 1, [], 0, 0],
		"samite_healer": ["Samite Healer", MmCardTypes.CardType.CREATURE, [white], 2, ["Human", "Cleric"], 1, 1],
		"white_knight": ["White Knight", MmCardTypes.CardType.CREATURE, [white], 2, ["Human", "Knight"], 2, 2],
		"black_knight": ["Black Knight", MmCardTypes.CardType.CREATURE, [black], 2, ["Human", "Knight"], 2, 2],
		"drudge_skeletons": ["Drudge Skeletons", MmCardTypes.CardType.CREATURE, [black], 2, ["Skeleton"], 1, 1],
		"terror": ["Terror", MmCardTypes.CardType.INSTANT, [black], 2, [], 0, 0],
	}
	for file_name: String in expected:
		var facts: Array = expected[file_name]
		var printed: MmCharacteristics = MmCharacteristics.printed(_alpha(file_name))
		assert_eq(printed.name, facts[0])
		assert_eq(printed.card_types, [facts[1]], file_name)
		assert_eq(printed.colors, facts[2], file_name)
		assert_eq(printed.mana_value(), facts[3], file_name)
		assert_eq(printed.subtypes, facts[4], file_name)
		if facts[1] == MmCardTypes.CardType.CREATURE:
			assert_eq([printed.power, printed.toughness], [facts[5], facts[6]], file_name)
	for knight: String in ["white_knight", "black_knight"]:
		var printed: MmCharacteristics = MmCharacteristics.printed(_alpha(knight))
		assert_true(printed.has_ability(FirstStrikeAbility), knight)
		assert_true(printed.has_ability(ProtectionAbility), knight)
	var skeleton_ability: ActivatedAbility = _alpha("drudge_skeletons").abilities[0] as ActivatedAbility
	assert_eq(skeleton_ability.mana_cost.symbols, [MmMana.Type.BLACK])
	assert_eq(skeleton_ability.costs, [], "Regenerating does not tap it.")


func test_fog_prevents_all_combat_damage() -> void:
	var fog: MmCardDefinition = Scenario.free_copy(_alpha("fog"))
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("hill_giant"))], [], [fog])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Hill Giant")])

	assert_eq(Scenario.cast_and_resolve(engine, "Fog"), "")
	Scenario.pass_until_step(engine, MmTurn.Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 20)


func test_fog_does_not_prevent_lightning_bolt() -> void:
	var fog: MmCardDefinition = Scenario.free_copy(_alpha("fog"))
	var bolt: MmCardDefinition = Scenario.free_copy(_alpha("lightning_bolt"))
	var engine: MmEngine = Scenario.combat_ready([], [], [fog, bolt])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.pass_until_step(engine, MmTurn.Step.POSTCOMBAT_MAIN)
	Scenario.cast_and_resolve(engine, "Fog")

	Scenario.cast_and_resolve(engine, "Lightning Bolt", [MmReference.to_player(engine.villain().id)])

	assert_eq(engine.villain().life, 17)


func test_samite_healer_prevents_one_damage_to_any_target() -> void:
	var healer: MmCardDefinition = Scenario.free_copy(_alpha("samite_healer"))
	var bolt: MmCardDefinition = Scenario.free_copy(_alpha("lightning_bolt"))
	var engine: MmEngine = Scenario.combat_ready([healer], [], [bolt])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.pass_until_step(engine, MmTurn.Step.POSTCOMBAT_MAIN)
	var villain: MmReference = MmReference.to_player(engine.villain().id)

	Scenario.activate(engine, Scenario.permanent_named(engine, engine.hero().id, "Samite Healer"), [villain])
	Scenario.resolve_stack(engine)
	Scenario.cast_and_resolve(engine, "Lightning Bolt", [villain])

	assert_eq(engine.villain().life, 18)


func test_black_knight_cannot_block_white_knight() -> void:
	# CR 702.16c: each Knight has protection from the other's color, so neither can block
	# the other.
	var cards: Array[MmCardDefinition] = Scenario.deck_of(_alpha("plains"), 20, _alpha("white_knight"), 20)
	var villain_cards: Array[MmCardDefinition] = Scenario.deck_of(_alpha("swamp"), 20, _alpha("black_knight"), 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, villain_cards), func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 3, 2, "White Knight") or Scenario.cast_and_resolve(running, "White Knight") != "":
			return false
		return Scenario.ready_in_main(running, 4, 2, "Black Knight") and Scenario.cast_and_resolve(running, "Black Knight") == "")
	assert_not_null(engine, "No seed gave the needed hands.")
	Scenario.play_until_step(engine, 5, MmTurn.Step.DECLARE_ATTACKERS)
	var white_knight: int = Scenario.permanent_named(engine, engine.hero().id, "White Knight")
	var black_knight: int = Scenario.permanent_named(engine, engine.villain().id, "Black Knight")
	assert_ne(black_knight, -1)
	Scenario.declare_attackers(engine, [white_knight])

	Scenario.pass_until_step(engine, MmTurn.Step.END_OF_COMBAT)

	assert_eq(Scenario.events_of(engine, BlockersDeclaredEvent), [], "No blockers decision was even asked.")
	assert_eq(engine.villain().life, 18)


func test_terror_cannot_target_white_knight_but_destroys_grizzly_bears() -> void:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(_alpha("swamp"), 20, _alpha("terror"), 20)
	var villain_cards: Array[MmCardDefinition] = Scenario.cycled([Scenario.free_copy(_alpha("white_knight")), Scenario.free_copy(_alpha("grizzly_bears"))])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, villain_cards), func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 1, 1, "Terror") or Scenario.play_until_step(running, 2, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.cast_and_resolve(running, "White Knight") != "" or Scenario.cast_and_resolve(running, "Grizzly Bears") != "":
			return false
		return Scenario.ready_in_main(running, 3, 2, "Terror"))
	assert_not_null(engine, "No seed gave the needed hands.")
	var knight: int = Scenario.permanent_named(engine, engine.villain().id, "White Knight")
	var bears: int = Scenario.permanent_named(engine, engine.villain().id, "Grizzly Bears")
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Terror")))

	var candidates: Array[MmReference] = (engine.pending_decision() as ChooseTargetDecision).candidates

	assert_eq(candidates.size(), 1, "Only a creature, and not the Knight with protection from black.")
	assert_true(candidates[0].equals(MmReference.to_object(bears)))
	assert_ne(knight, -1)
	Scenario.choose_target(engine, candidates[0])
	Scenario.auto_pay(engine)
	_resolve(engine)
	assert_eq(Scenario.names(engine, engine.villain().graveyard), ["Grizzly Bears"])


func test_terror_cannot_target_artifact_or_black_creatures() -> void:
	var spec: TargetSpec = (_alpha("terror").abilities[0] as SpellAbility).targets[0]
	var engine: MmEngine = MmEngine.start(_setup_with_deck_of(_alpha("black_knight")))
	var state: MmGameState = engine.game_state()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var black_creature: MmReference = MmReference.to_object(engine.hero().library.objects()[0].id)
	var artifact_creature: MmCardDefinition = Scenario.free_copy(_alpha("grizzly_bears"))
	artifact_creature.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	var artifact_engine: MmEngine = MmEngine.start(_setup_with_deck_of(artifact_creature))
	var bears_engine: MmEngine = MmEngine.start(_setup_with_deck_of(Scenario.free_copy(_alpha("grizzly_bears"))))

	assert_false(spec.filter.matches(state, black_creature, context), "Nonblack.")
	assert_false(spec.filter.matches(artifact_engine.game_state(), MmReference.to_object(artifact_engine.hero().library.objects()[0].id), context), "Nonartifact.")
	assert_true(spec.filter.matches(bears_engine.game_state(), MmReference.to_object(bears_engine.hero().library.objects()[0].id), context))
	assert_false(((_alpha("terror").abilities[0] as SpellAbility).effects[0] as DestroyEffect).can_be_regenerated)


func test_drudge_skeletons_regenerates_for_black_mana() -> void:
	var skeletons: MmCardDefinition = Scenario.free_copy(_alpha("drudge_skeletons"))
	var swamp: MmCardDefinition = _alpha("swamp")
	var bolt: MmCardDefinition = Scenario.free_copy(_alpha("lightning_bolt"))
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup([skeletons], no_cards, [swamp, bolt])
	var engine: MmEngine = Scenario.permanents_ready_with(setup, [skeletons], no_cards, [swamp, bolt], no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Drudge Skeletons")
	Scenario.play_first_land(engine)

	assert_eq(Scenario.activate(engine, skeleton), "")
	Scenario.resolve_stack(engine)
	Scenario.cast_and_resolve(engine, "Lightning Bolt", [MmReference.to_object(skeleton)])

	assert_not_null(engine.game_state().object(skeleton))
	assert_true(engine.game_state().object(skeleton).is_tapped)
	assert_eq(Scenario.damage_on(engine, skeleton), 0)


func test_the_milestone_eleven_cards_have_the_right_printed_characteristics() -> void:
	var white: Array[MmCardTypes.CardColor] = [MmCardTypes.CardColor.WHITE]
	var blue: Array[MmCardTypes.CardColor] = [MmCardTypes.CardColor.BLUE]
	var black: Array[MmCardTypes.CardColor] = [MmCardTypes.CardColor.BLACK]
	var red: Array[MmCardTypes.CardColor] = [MmCardTypes.CardColor.RED]
	var green: Array[MmCardTypes.CardColor] = [MmCardTypes.CardColor.GREEN]
	var creature: MmCardTypes.CardType = MmCardTypes.CardType.CREATURE
	var expected: Dictionary[String, Array] = {
		"shivan_dragon": ["Shivan Dragon", creature, red, 6, ["Dragon"], 5, 5],
		"frozen_shade": ["Frozen Shade", creature, black, 3, ["Shade"], 0, 1],
		"goblin_balloon_brigade": ["Goblin Balloon Brigade", creature, red, 1, ["Goblin", "Warrior"], 1, 1],
		"uthden_troll": ["Uthden Troll", creature, red, 3, ["Troll"], 2, 2],
		"llanowar_elves": ["Llanowar Elves", creature, green, 1, ["Elf", "Druid"], 1, 1],
		"prodigal_sorcerer": ["Prodigal Sorcerer", creature, blue, 3, ["Human", "Wizard"], 1, 1],
		"craw_wurm": ["Craw Wurm", creature, green, 6, ["Wurm"], 6, 4],
		"gray_ogre": ["Gray Ogre", creature, red, 3, ["Ogre"], 2, 2],
		"savannah_lions": ["Savannah Lions", creature, white, 1, ["Cat"], 2, 1],
		"pearled_unicorn": ["Pearled Unicorn", creature, white, 3, ["Unicorn"], 2, 2],
		"water_elemental": ["Water Elemental", creature, blue, 5, ["Elemental"], 5, 4],
		"merfolk_of_the_pearl_trident": ["Merfolk of the Pearl Trident", creature, blue, 1, ["Merfolk"], 1, 1],
		"scathe_zombies": ["Scathe Zombies", creature, black, 3, ["Zombie"], 2, 2],
		"hurloon_minotaur": ["Hurloon Minotaur", creature, red, 3, ["Minotaur"], 2, 3],
		"ironroot_treefolk": ["Ironroot Treefolk", creature, green, 5, ["Treefolk"], 3, 5],
		"shatter": ["Shatter", MmCardTypes.CardType.INSTANT, red, 2, [], 0, 0],
	}
	for file_name: String in expected:
		var facts: Array = expected[file_name]
		var printed: MmCharacteristics = MmCharacteristics.printed(_alpha(file_name))
		assert_eq(printed.name, facts[0])
		assert_eq(printed.card_types, [facts[1]], file_name)
		assert_eq(printed.colors, facts[2], file_name)
		assert_eq(printed.mana_value(), facts[3], file_name)
		assert_eq(printed.subtypes, facts[4], file_name)
		if facts[1] == creature:
			assert_eq([printed.power, printed.toughness], [facts[5], facts[6]], file_name)
	assert_true(MmCharacteristics.printed(_alpha("shivan_dragon")).has_ability(FlyingAbility))
	assert_true((_alpha("llanowar_elves").abilities[0] as ActivatedAbility).is_mana_ability())
	assert_false((_alpha("prodigal_sorcerer").abilities[0] as ActivatedAbility).is_mana_ability())


func test_shivan_dragon_gets_plus_one_plus_zero_for_each_red_paid_until_end_of_turn() -> void:
	var engine: MmEngine = _ready_with_lands(Scenario.free_copy(_alpha("shivan_dragon")), "mountain", 2)
	var dragon: int = Scenario.permanent_named(engine, engine.hero().id, "Shivan Dragon")

	assert_eq(Scenario.activate(engine, dragon), "")
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.activate(engine, dragon), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.pt(engine, dragon), [7, 5])
	Scenario.play_until_game_turn(engine, engine.game_state().game_turn + 1)
	assert_eq(Scenario.pt(engine, dragon), [5, 5], "Until end of turn.")


func test_frozen_shade_pumped_three_times_survives_lightning_bolt() -> void:
	var bolt: MmCardDefinition = Scenario.free_copy(_alpha("lightning_bolt"))
	var engine: MmEngine = _ready_with_lands(Scenario.free_copy(_alpha("frozen_shade")), "swamp", 3, [bolt])
	var shade: int = Scenario.permanent_named(engine, engine.hero().id, "Frozen Shade")

	for _pump: int in 3:
		assert_eq(Scenario.activate(engine, shade), "")
		Scenario.resolve_stack(engine)
	assert_eq(Scenario.pt(engine, shade), [3, 4])
	Scenario.cast_and_resolve(engine, "Lightning Bolt", [MmReference.to_object(shade)])

	assert_not_null(engine.game_state().object(shade), "4 toughness survives 3 damage.")


func test_goblin_balloon_brigade_gains_flying_and_cannot_be_blocked_from_the_ground() -> void:
	var brigade: MmCardDefinition = Scenario.free_copy(_alpha("goblin_balloon_brigade"))
	var bears: MmCardDefinition = Scenario.free_copy(_alpha("grizzly_bears"))
	var mountain: MmCardDefinition = _alpha("mountain")
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup([brigade], [bears], [mountain]),
		[brigade], [bears], [mountain], no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var goblin: int = Scenario.permanent_named(engine, engine.hero().id, "Goblin Balloon Brigade")
	Scenario.play_first_land(engine)

	assert_eq(Scenario.activate(engine, goblin), "")
	Scenario.resolve_stack(engine)
	assert_true(Scenario.now(engine, goblin).has_ability(FlyingAbility))
	Scenario.pass_until_step(engine, MmTurn.Step.DECLARE_ATTACKERS)
	assert_eq(engine.submit([goblin]), "")
	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.pending_decision() is DeclareBlockersDecision or running.game_state().step == MmTurn.Step.END_OF_COMBAT)

	assert_false(engine.pending_decision() is DeclareBlockersDecision, "The Bears cannot block it, so no block is asked.")
	assert_eq(engine.villain().life, 19)


func test_uthden_troll_regenerates_for_red_mana() -> void:
	var bolt: MmCardDefinition = Scenario.free_copy(_alpha("lightning_bolt"))
	var engine: MmEngine = _ready_with_lands(Scenario.free_copy(_alpha("uthden_troll")), "mountain", 1, [bolt])
	var troll: int = Scenario.permanent_named(engine, engine.hero().id, "Uthden Troll")

	assert_eq(Scenario.activate(engine, troll), "")
	Scenario.resolve_stack(engine)
	Scenario.cast_and_resolve(engine, "Lightning Bolt", [MmReference.to_object(troll)])

	assert_not_null(engine.game_state().object(troll))
	assert_true(engine.game_state().object(troll).is_tapped, "Regeneration taps it (CR 701.19a).")


func test_llanowar_elves_taps_for_green_but_not_the_turn_it_enters() -> void:
	var elves: MmCardDefinition = Scenario.free_copy(_alpha("llanowar_elves"))
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup([elves], no_cards, [elves]),
		[elves], no_cards, [elves], no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var old_elf: int = Scenario.permanent_named(engine, engine.hero().id, "Llanowar Elves")

	Scenario.cast_and_resolve(engine, "Llanowar Elves")
	var new_elf: int = Scenario.permanents_named(engine, engine.hero().id, "Llanowar Elves").back()

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, new_elf), -1,
		"CR 302.6: it cannot pay {T} yet.")
	assert_eq(Scenario.activate(engine, old_elf), "")
	assert_eq(engine.hero().mana_pool().size(), 1)
	assert_eq(engine.hero().mana_pool()[0].type, MmMana.Type.GREEN)


func test_prodigal_sorcerer_pings_a_player_and_a_creature() -> void:
	var sorcerer: MmCardDefinition = Scenario.free_copy(_alpha("prodigal_sorcerer"))
	var merfolk: MmCardDefinition = Scenario.free_copy(_alpha("merfolk_of_the_pearl_trident"))
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup([sorcerer], [merfolk]),
		[sorcerer], [merfolk], no_cards, no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var pinger: int = Scenario.permanent_named(engine, engine.hero().id, "Prodigal Sorcerer")
	var target: int = Scenario.permanent_named(engine, engine.villain().id, "Merfolk of the Pearl Trident")

	assert_eq(Scenario.activate(engine, pinger, [MmReference.to_player(engine.villain().id)]), "")
	Scenario.resolve_stack(engine)
	assert_eq(engine.villain().life, 19)
	Scenario.play_until_step(engine, 5, MmTurn.Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.activate(engine, pinger, [MmReference.to_object(target)]), "")
	Scenario.resolve_stack(engine)

	assert_null(engine.game_state().object(target))


func test_shatter_destroys_an_artifact_and_cannot_target_a_creature() -> void:
	var mine: MmCardDefinition = Scenario.free_copy(_alpha("howling_mine"))
	var bears: MmCardDefinition = Scenario.free_copy(_alpha("grizzly_bears"))
	var shatter: MmCardDefinition = Scenario.free_copy(_alpha("shatter"))
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(no_cards, [mine, bears], [shatter]),
		no_cards, [mine, bears], [shatter], no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var artifact: int = Scenario.permanent_named(engine, engine.villain().id, "Howling Mine")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Grizzly Bears")

	assert_ne(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shatter"), [MmReference.to_object(bear)]), "")
	engine.cancel_cast()
	Scenario.cast_and_resolve(engine, "Shatter", [MmReference.to_object(artifact)])

	assert_null(engine.game_state().object(artifact))


func test_each_deck_is_forty_cards_with_seventeen_lands() -> void:
	for deck_name: String in ["red_green", "white_black", "blue_red"]:
		var setup: MmPlayerSetup = load("res://content/decks/%s.tres" % deck_name) as MmPlayerSetup
		assert_not_null(setup, deck_name)
		assert_eq(setup.validate(), "", deck_name)
		assert_eq(setup.deck.size(), 40, deck_name)
		var lands: int = 0
		for run_card: MmRunCard in setup.deck:
			if MmCharacteristics.printed(run_card.base).has_card_type(MmCardTypes.CardType.LAND):
				lands += 1
		assert_eq(lands, 17, deck_name)


## [param creature] on the Hero's battlefield since Game Turn 1, stopped in the Hero's
## main phase once they control [param land_count] of the land [param land_file], holding
## [param extras].
func _ready_with_lands(creature: MmCardDefinition, land_file: String, land_count: int,
		extras: Array[MmCardDefinition] = []) -> MmEngine:
	var land: MmCardDefinition = _alpha(land_file)
	var hero_extras: Array[MmCardDefinition] = [land]
	hero_extras.append_array(extras)
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup([creature], no_cards, hero_extras)
	var game_turn: int = 1 + 2 * land_count
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 1, MmTurn.Step.PRECOMBAT_MAIN) != "" \
				or Scenario.cast_and_resolve(running, creature.name) != "":
			return false
		if Scenario.play_until_step(running, game_turn, MmTurn.Step.PRECOMBAT_MAIN, true) != "":
			return false
		for extra: MmCardDefinition in extras:
			if Scenario.card_in_hand(running, running.hero(), extra.name) == -1:
				return false
		return Scenario.permanents_named(running, running.hero().id, land.name).size() == land_count)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


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
