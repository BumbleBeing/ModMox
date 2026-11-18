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


func test_the_sharing_check_lets_cards_share_a_token_definition_file() -> void:
	var cat: MmCardDefinition = load("res://content/tokens/cat_1_1_white.tres") as MmCardDefinition
	var first: MmCardDefinition = MmCardDefinition.new()
	first.abilities = [Scenario.triggered(Scenario.enters(null), [Scenario.create_tokens(cat)])]
	var second: MmCardDefinition = MmCardDefinition.new()
	second.abilities = [Scenario.triggered(Scenario.enters(null), [Scenario.create_tokens(cat)])]

	assert_eq(_shared_sub_resources({"first": first, "second": second}), [])


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


func test_lightning_bolt_deals_three_damage_to_a_player() -> void:
	var engine: MmEngine = _hero_ready_to_cast(_alpha("lightning_bolt"), "mountain")

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Lightning Bolt"), [MmReference.to_player(engine.villain().id)])
	_resolve(engine)

	assert_eq(engine.villain().life, 17)


func test_lightning_bolt_can_target_creatures_and_players_only() -> void:
	# Its filter is saved with default values left out; check it still means "any target".
	var spec: TargetRequirement = (_alpha("lightning_bolt").abilities[0] as SpellAbility).targets[0]
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


func test_raise_dead_returns_a_creature_card_from_its_casters_graveyard() -> void:
	var zombies: MmCardDefinition = Scenario.free_copy(_alpha("scathe_zombies"))
	var cards: Array[MmCardDefinition] = Scenario.cycled([_alpha("swamp"), _alpha("raise_dead"), zombies, Scenario.free_destroy("Doom")])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			if not Scenario.ready_in_main(running, 1, 1, "Raise Dead"):
				return false
			var held: Array[String] = Scenario.names(running, running.hero().hand)
			return held.count("Scathe Zombies") == 1 and held.has("Doom"))
	assert_not_null(engine, "No seed gave the needed hand.")
	var hero: MmPlayer = engine.hero()
	var raise: int = Scenario.card_in_hand(engine, hero, "Raise Dead")
	assert_false(Scenario.offers_cast(engine, raise), "There is no creature card in the graveyard yet.")
	Scenario.cast_and_resolve(engine, "Scathe Zombies")
	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(Scenario.permanent_named(engine, hero.id, "Scathe Zombies"))])
	var dead: int = Scenario.card_in_graveyard(engine, hero, "Scathe Zombies")

	assert_eq(Scenario.cast_and_resolve(engine, "Raise Dead", [MmReference.to_object(dead)]), "")

	assert_eq(Scenario.names(engine, hero.hand).count("Scathe Zombies"), 1)
	assert_eq(Scenario.names(engine, hero.graveyard), ["Doom", "Raise Dead"])


func test_stifle_counters_a_triggered_ability_so_it_never_resolves() -> void:
	var greeter: MmCardDefinition = Scenario.creature("Greeter", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.gain_life(5, Scenario.you())])])
	var cards: Array[MmCardDefinition] = Scenario.cycled([_alpha("island"), _card("scourge", "stifle"), greeter])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			return Scenario.ready_in_main(running, 1, 1, "Stifle") and Scenario.card_in_hand(running, running.hero(), "Greeter") != -1)
	assert_not_null(engine, "No seed gave the needed hand.")
	var hero: MmPlayer = engine.hero()
	var stifle: int = Scenario.card_in_hand(engine, hero, "Stifle")
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Greeter"))
	assert_false(Scenario.offers_cast(engine, stifle), "A creature spell is not an ability.")
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)
	var trigger: int = engine.view_for(hero).stack[0].id

	assert_eq(Scenario.cast(engine, stifle, [MmReference.to_object(trigger)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(hero.life, 20, "The Greeter's trigger never resolved.")
	assert_eq(Scenario.names(engine, hero.graveyard), ["Stifle"])


func test_dark_ritual_adds_three_black_mana_when_it_resolves() -> void:
	var engine: MmEngine = _hero_ready_to_cast(_alpha("dark_ritual"), "swamp")

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Dark Ritual"))
	assert_eq(engine.hero().mana_pool().size(), 0, "A spell is not a mana ability.")
	_resolve(engine)

	var pool: Array[MmMana] = engine.hero().mana_pool()
	assert_eq(pool.size(), 3)
	for mana: MmMana in pool:
		assert_eq(mana.type, MmMana.Type.BLACK)


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


func test_battlegrowth_puts_a_plus_one_plus_one_counter_that_stays() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("grizzly_bears"))], [],
		[Scenario.free_copy(_card("mirrodin", "battlegrowth"))])
	assert_not_null(engine, "No seed gave the needed hand.")
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	Scenario.declare_attackers(engine, [bears])

	Scenario.cast_and_resolve(engine, "Battlegrowth", [MmReference.to_object(bears)])
	Scenario.play_until_game_turn(engine, 4)

	assert_eq(engine.villain().life, 17, "A 3/3 attacked.")
	assert_eq(Scenario.pt(engine, bears), [3, 3], "The counter is still there after the turn.")
	assert_eq(Scenario.counters_on(engine, bears, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 1)


func test_instill_infection_kills_a_one_toughness_creature_and_draws_a_card() -> void:
	var engine: MmEngine = Scenario.combat_ready([], [Scenario.free_copy(_alpha("savannah_lions"))],
		[Scenario.free_copy(_card("scars_of_mirrodin", "instill_infection"))])
	assert_not_null(engine, "No seed gave the needed hand.")
	var lions: int = Scenario.permanent_named(engine, engine.villain().id, "Savannah Lions")
	var hand_before: int = engine.hero().hand.size()

	Scenario.cast_and_resolve(engine, "Instill Infection", [MmReference.to_object(lions)])

	assert_eq(Scenario.permanents_named(engine, engine.villain().id, "Savannah Lions").size(), 0, "A 2/1 with a -1/-1 counter.")
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.ZERO_TOUGHNESS)
	assert_eq(engine.hero().hand.size(), hand_before, "One card cast, one drawn.")


func test_instill_infection_cannot_target_a_player() -> void:
	var engine: MmEngine = Scenario.combat_ready([], [Scenario.free_copy(_alpha("savannah_lions"))],
		[Scenario.free_copy(_card("scars_of_mirrodin", "instill_infection"))])
	assert_not_null(engine, "No seed gave the needed hand.")

	var error: String = Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Instill Infection"),
		[MmReference.to_player(engine.villain().id)])

	assert_ne(error, "")


func test_ornery_kudu_puts_a_minus_one_minus_one_counter_on_a_creature_of_its_controllers_only() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("grizzly_bears"))],
		[Scenario.free_copy(_alpha("savannah_lions"))], [Scenario.free_copy(_card("amonkhet", "ornery_kudu"))])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.declare_attackers(engine, [])
	Scenario.pass_until_step(engine, MmTurn.Step.POSTCOMBAT_MAIN)
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")

	Scenario.cast_and_resolve(engine, "Ornery Kudu")

	var kudu: int = Scenario.permanent_named(engine, engine.hero().id, "Ornery Kudu")
	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision, "CR 603.3d: its target is chosen as the trigger is put on the stack.")
	var candidates: Array[int] = []
	for candidate: MmReference in decision.candidates:
		candidates.append(candidate.id)
	candidates.sort()
	assert_eq(candidates, [bears, kudu], "Its controller's creatures, itself among them, and never the Villain's.")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(kudu)), "")
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.pt(engine, kudu), [2, 3])
	assert_eq(Scenario.pt(engine, bears), [2, 2])


func test_malamet_war_scribe_pumps_each_creature_its_controller_controls_until_end_of_turn() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("grizzly_bears"))],
		[Scenario.free_copy(_alpha("savannah_lions"))],
		[Scenario.free_copy(_card("the_lost_caverns_of_ixalan", "malamet_war_scribe"))])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.declare_attackers(engine, [])
	Scenario.pass_until_step(engine, MmTurn.Step.POSTCOMBAT_MAIN)
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	var lions: int = Scenario.permanent_named(engine, engine.villain().id, "Savannah Lions")

	Scenario.cast_and_resolve(engine, "Malamet War Scribe")
	Scenario.resolve_stack(engine)

	var scribe: int = Scenario.permanent_named(engine, engine.hero().id, "Malamet War Scribe")
	assert_eq(Scenario.pt(engine, scribe), [6, 4], "It gets the bonus itself.")
	assert_eq(Scenario.pt(engine, bears), [4, 3])
	assert_eq(Scenario.pt(engine, lions), [2, 1], "Never the Villain's creatures.")
	Scenario.play_until_game_turn(engine, 4)
	assert_eq(Scenario.pt(engine, bears), [2, 2], "Back to normal after the turn.")


func test_coordinated_maneuver_deals_damage_equal_to_its_casters_creatures_or_destroys_an_enchantment() -> void:
	var maneuver: MmCardDefinition = Scenario.free_copy(_card("tarkir_dragonstorm", "coordinated_maneuver"))
	var engine: MmEngine = Scenario.combat_ready(
		[Scenario.free_copy(_alpha("grizzly_bears")), Scenario.free_copy(_alpha("savannah_lions"))],
		[Scenario.free_copy(_alpha("hill_giant")), Scenario.free_copy(_card("lorwyn", "oblivion_ring"))],
		[maneuver, maneuver])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.declare_attackers(engine, [])
	Scenario.pass_until_step(engine, MmTurn.Step.POSTCOMBAT_MAIN)
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Hill Giant")
	var ring: int = Scenario.permanent_named(engine, engine.villain().id, "Oblivion Ring")
	var creatures: int = Scenario.permanents_named(engine, engine.hero().id, "Grizzly Bears").size() \
		+ Scenario.permanents_named(engine, engine.hero().id, "Savannah Lions").size()
	assert_eq(creatures, 1, "The Oblivion Ring exiled one of the Hero's two creatures as it entered.")

	assert_eq(Scenario.cast_mode(engine, Scenario.card_in_hand(engine, engine.hero(), "Coordinated Maneuver"), 0,
		[MmReference.to_object(giant)]), "")
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.damage_on(engine, giant), 1, "One creature, so 1 damage.")
	assert_eq(Scenario.cast_mode(engine, Scenario.card_in_hand(engine, engine.hero(), "Coordinated Maneuver"), 1,
		[MmReference.to_object(ring)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Oblivion Ring"), -1, "The enchantment is destroyed.")
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Grizzly Bears").size()
		+ Scenario.permanents_named(engine, engine.hero().id, "Savannah Lions").size(), 2, "And the exiled creature came back.")


func test_skyknight_squire_becomes_a_flying_knight_once_three_other_creatures_enter() -> void:
	var others: Array[MmCardDefinition] = [Scenario.free_copy(_alpha("grizzly_bears")),
		Scenario.free_copy(_alpha("savannah_lions")), Scenario.free_copy(_alpha("hill_giant"))]
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_card("foundations", "skyknight_squire"))], [], others)
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.declare_attackers(engine, [])
	Scenario.pass_until_step(engine, MmTurn.Step.POSTCOMBAT_MAIN)
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Skyknight Squire")
	for other: MmCardDefinition in others.slice(0, 2):
		Scenario.cast_and_resolve(engine, other.name)
		Scenario.resolve_stack(engine)
	assert_eq(Scenario.pt(engine, squire), [3, 3])
	assert_false(Scenario.now(engine, squire).has_ability(FlyingAbility), "Two counters are not enough.")

	Scenario.cast_and_resolve(engine, "Hill Giant")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.counters_on(engine, squire, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 3)
	assert_eq(Scenario.pt(engine, squire), [4, 4])
	assert_true(Scenario.now(engine, squire).has_ability(FlyingAbility))
	assert_eq(Scenario.now(engine, squire).subtypes, ["Cat", "Scout", "Knight"] as Array[String])


func test_whitemane_lion_is_cast_in_combat_and_returns_the_creature_its_controller_chooses() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("grizzly_bears"))], [],
		[Scenario.free_copy(_card("salvat_2005", "whitemane_lion"))])
	assert_not_null(engine, "No seed gave the needed hand.")
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	Scenario.declare_attackers(engine, [bears])

	assert_eq(Scenario.cast_and_resolve(engine, "Whitemane Lion"), "", "Flash: cast during combat.")
	assert_eq(Scenario.pass_to_choice(engine), "")

	var decision: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
	var lion: int = Scenario.permanent_named(engine, engine.hero().id, "Whitemane Lion")
	var candidates: Array[int] = []
	for candidate: MmReference in decision.candidates:
		candidates.append(candidate.id)
	assert_eq(candidates, [bears, lion])
	assert_eq(engine.submit(candidates.find(bears)), "")
	Scenario.resolve_stack(engine)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Grizzly Bears"), -1, "Back in hand, out of the attack.")
	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Whitemane Lion"), lion)


func test_arahbo_entering_makes_one_cat_token_that_makes_no_more() -> void:
	var arahbo: MmCardDefinition = Scenario.free_copy(_card("foundations", "arahbo_the_first_fang"))
	var legends: Array[MmCardDefinition] = [arahbo]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(legends, no_cards),
		legends, no_cards, no_cards, no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")

	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 1, "Arahbo's own arrival made one; the token's made none.")
	assert_eq(Scenario.pt(engine, tokens[0]), [2, 2], "Other Cats get +1/+1.")
	assert_eq(Scenario.pt(engine, Scenario.permanent_named(engine, engine.hero().id, arahbo.name)), [2, 2], "Not itself.")


func test_a_second_arahbo_makes_cats_from_both_triggers_and_the_legend_rule_keeps_one() -> void:
	var arahbo: MmCardDefinition = Scenario.free_copy(_card("foundations", "arahbo_the_first_fang"))
	var legends: Array[MmCardDefinition] = [arahbo]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(legends, no_cards, legends),
		legends, no_cards, legends, no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var hero_id: int = engine.hero().id
	var first: int = Scenario.permanent_named(engine, hero_id, arahbo.name)
	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 1)

	assert_eq(Scenario.cast_and_resolve(engine, arahbo.name), "")
	assert_true(engine.pending_decision() is ChooseLegendToKeepDecision, "CR 704.5j: two Arahbos.")
	assert_eq(Scenario.keep_legend(engine, first), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanents_named(engine, hero_id, arahbo.name), [first], "The legend rule kept exactly one.")
	assert_eq(Scenario.names(engine, engine.hero().graveyard), [arahbo.name])
	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 3, "Both Arahbos saw the second enter (CR 603.2): two more Cats, and none from a token.")
	for cat: int in tokens:
		assert_eq(Scenario.pt(engine, cat), [2, 2])


func test_helping_hand_returns_savannah_lions_from_your_graveyard_tapped_and_arahbo_makes_a_cat() -> void:
	var arahbo: MmCardDefinition = Scenario.free_copy(_card("foundations", "arahbo_the_first_fang"))
	var lions: MmCardDefinition = Scenario.free_copy(_alpha("savannah_lions"))
	var helping: MmCardDefinition = Scenario.free_copy(_card("the_lost_caverns_of_ixalan", "helping_hand"))
	var creatures: Array[MmCardDefinition] = [arahbo, lions]
	var extras: Array[MmCardDefinition] = [helping, Scenario.free_destroy("Doom")]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(creatures, no_cards, extras),
		creatures, no_cards, extras, no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var hero: MmPlayer = engine.hero()
	assert_eq(Scenario.cast_and_resolve(engine, "Doom",
		[MmReference.to_object(Scenario.permanent_named(engine, hero.id, "Savannah Lions"))]), "")
	var dead: int = Scenario.card_in_graveyard(engine, hero, "Savannah Lions")
	assert_ne(dead, -1, "The Lions are in the Hero's graveyard.")
	var cats: int = Scenario.tokens_on_battlefield(engine).size()

	assert_eq(Scenario.cast_and_resolve(engine, "Helping Hand", [MmReference.to_object(dead)]), "")
	Scenario.resolve_stack(engine)

	var returned: int = Scenario.permanent_named(engine, hero.id, "Savannah Lions")
	assert_ne(returned, -1, "Back on the battlefield.")
	assert_true(engine.game_state().object(returned).is_tapped, "CR 110.5b: it enters tapped.")
	assert_eq(Scenario.card_in_graveyard(engine, hero, "Savannah Lions"), -1)
	assert_eq(Scenario.tokens_on_battlefield(engine).size(), cats + 1, "Arahbo saw a nontoken Cat enter.")


func test_rally_the_ranks_choosing_cat_pumps_savannah_lions_and_not_llanowar_elves() -> void:
	var creatures: Array[MmCardDefinition] = [Scenario.free_copy(_alpha("savannah_lions")),
		Scenario.free_copy(_alpha("llanowar_elves"))]
	var extras: Array[MmCardDefinition] = [Scenario.free_copy(_card("kaldheim", "rally_the_ranks"))]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(creatures, no_cards, extras),
		creatures, no_cards, extras, no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var lions: int = Scenario.permanent_named(engine, engine.hero().id, "Savannah Lions")
	var elves: int = Scenario.permanent_named(engine, engine.hero().id, "Llanowar Elves")

	Scenario.cast_and_resolve(engine, "Rally the Ranks")
	assert_eq(Scenario.choose_creature_type(engine, "Cat"), "")
	Scenario.resolve_stack(engine)

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Rally the Ranks"), -1)
	assert_eq(Scenario.pt(engine, lions), [3, 2], "A Cat you control gets +1/+1.")
	assert_eq(Scenario.pt(engine, elves), [1, 1], "An Elf is not of the chosen type.")


func test_assemble_the_players_casts_savannah_lions_from_the_top_once_each_turn() -> void:
	var assemble: MmCardDefinition = Scenario.free_copy(_card("murders_at_karlov_manor", "assemble_the_players"))
	var lions: MmCardDefinition = Scenario.free_copy(_alpha("savannah_lions"))
	var elves: MmCardDefinition = Scenario.free_copy(_alpha("llanowar_elves"))
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled([assemble, lions, elves]), Scenario.cycled([]))
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.top_ready(setup, [assemble], no_cards, ["Savannah Lions", "Llanowar Elves"])
	assert_not_null(engine, "No seed gave the needed cards.")
	var hero: MmPlayer = engine.hero()
	var top: int = hero.library.top().id

	assert_true(Scenario.offers_cast(engine, top))
	assert_eq(Scenario.cast(engine, top), "")
	assert_true(engine.game_state().object(Scenario.stack_ids(engine)[0]).cast_from_library)
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanents_named(engine, hero.id, "Savannah Lions").size(), 1)
	assert_eq(Scenario.top_name(engine, hero), "Llanowar Elves")
	assert_false(Scenario.offers_cast(engine, hero.library.top().id), "Once each turn: a 1/1 on top waits for next turn.")


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
	var spec: TargetRequirement = (_alpha("terror").abilities[0] as SpellAbility).targets[0]
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


func test_oblivion_ring_exiles_a_noncreature_permanent_until_it_leaves() -> void:
	var mine: MmCardDefinition = Scenario.free_copy(_alpha("howling_mine"))
	var bears: MmCardDefinition = Scenario.free_copy(_alpha("grizzly_bears"))
	var ring: MmCardDefinition = Scenario.free_copy(_card("lorwyn", "oblivion_ring"))
	var disenchant: MmCardDefinition = Scenario.free_disenchant("Disenchant")
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(no_cards, [mine, bears], [ring, disenchant]),
		no_cards, [mine, bears], [ring, disenchant], no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var artifact: int = Scenario.permanent_named(engine, engine.villain().id, "Howling Mine")

	Scenario.cast_and_resolve(engine, "Oblivion Ring")
	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	var candidates: Array[int] = []
	for candidate: MmReference in decision.candidates:
		candidates.append(candidate.id)
	assert_eq(candidates, [artifact, Scenario.permanent_named(engine, engine.villain().id, "Grizzly Bears")],
		"Any nonland permanent but itself, and never a player.")
	Scenario.choose_target(engine, MmReference.to_object(artifact))
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Howling Mine"), -1)
	assert_eq(Scenario.exiled_by_owner(engine, engine.villain()).size(), 1)

	var ring_id: int = Scenario.permanent_named(engine, engine.hero().id, "Oblivion Ring")
	Scenario.cast_and_resolve(engine, "Disenchant", [MmReference.to_object(ring_id)])
	Scenario.resolve_stack(engine)

	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Howling Mine"), -1, "Back under its owner's control.")
	assert_eq(Scenario.exiled_by_owner(engine, engine.villain()).size(), 0)


func test_short_sword_is_equipped_for_one_mana_and_gives_its_creature_plus_one_plus_one() -> void:
	var bears: MmCardDefinition = Scenario.free_copy(_alpha("grizzly_bears"))
	var sword: MmCardDefinition = Scenario.free_copy(_card("dominaria", "short_sword"))
	var rock: MmCardDefinition = Scenario.artifact("Rock", [Scenario.tap_for_mana(MmMana.Type.COLORLESS, 1)])
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup([bears, sword, rock], no_cards),
		[bears, sword, rock], no_cards, no_cards, no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var creature: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	var equipment: int = Scenario.permanent_named(engine, engine.hero().id, "Short Sword")
	assert_eq(Scenario.pt(engine, creature), [2, 2], "On its own it gives nothing.")

	assert_eq(Scenario.equip_and_resolve(engine, equipment, creature), "")

	assert_eq(Scenario.attached_to(engine, equipment), creature)
	assert_eq(Scenario.pt(engine, creature), [3, 3])
	assert_true(engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Rock")).is_tapped, "Equip {1} was paid.")
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, equipment), -1, "With no mana left it is not offered.")


func test_adventuring_gear_pumps_the_creature_equipped_as_its_landfall_resolves_and_nothing_while_unattached() -> void:
	var bears: MmCardDefinition = Scenario.free_copy(_alpha("grizzly_bears"))
	var lions: MmCardDefinition = Scenario.free_copy(_alpha("savannah_lions"))
	var gear: MmCardDefinition = Scenario.free_copy(_card("zendikar", "adventuring_gear"))
	var rock: MmCardDefinition = Scenario.artifact("Rock", [Scenario.tap_for_mana(MmMana.Type.COLORLESS, 1)])
	var lands: Array[MmCardDefinition] = [_alpha("forest"), _alpha("plains")]
	var permanents: Array[MmCardDefinition] = [bears, lions, gear, rock]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(permanents, no_cards, lands),
		permanents, no_cards, lands, no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	var lion: int = Scenario.permanent_named(engine, engine.hero().id, "Savannah Lions")
	var equipment: int = Scenario.permanent_named(engine, engine.hero().id, "Adventuring Gear")

	var forest: int = Scenario.card_in_hand(engine, engine.hero(), "Forest")
	assert_eq(engine.submit(Scenario.play_land_index(engine.pending_decision() as PriorityDecision, forest)), "")
	assert_eq(Scenario.stacked_abilities(engine).size(), 1, "It triggers while unattached.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.pt(engine, bear), [2, 2], "Unattached, it pumps nothing.")
	assert_eq(Scenario.pt(engine, lion), [2, 1])

	assert_eq(Scenario.play_until_step(engine, 5, MmTurn.Step.PRECOMBAT_MAIN), "")
	assert_eq(Scenario.equip_and_resolve(engine, equipment, bear), "")
	assert_eq(Scenario.pt(engine, bear), [2, 2], "On its own it gives nothing.")
	var plains: int = Scenario.card_in_hand(engine, engine.hero(), "Plains")
	assert_eq(engine.submit(Scenario.play_land_index(engine.pending_decision() as PriorityDecision, plains)), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.pt(engine, bear), [4, 4])

	assert_eq(Scenario.equip_and_resolve(engine, equipment, lion), "")
	assert_eq(Scenario.pt(engine, bear), [4, 4], "The creature equipped as it resolved keeps it (CR 611.2c).")
	assert_eq(Scenario.pt(engine, lion), [2, 1])

	assert_eq(Scenario.play_until_game_turn(engine, 6), "")
	assert_eq(Scenario.pt(engine, bear), [2, 2], "Until end of turn.")


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


func test_the_decks_hold_two_raise_dead_and_two_stifle() -> void:
	assert_eq(_copies_in("white_black", "Raise Dead"), 2)
	assert_eq(_copies_in("blue_red", "Stifle"), 2)


func _copies_in(deck_name: String, card_name: String) -> int:
	var count: int = 0
	for run_card: MmRunCard in (load("res://content/decks/%s.tres" % deck_name) as MmPlayerSetup).deck:
		if run_card.base.name == card_name:
			count += 1
	return count


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
	return _card("alpha", file_name)


## The authored card [param file_name] of the set in folder [param set_name].
func _card(set_name: String, file_name: String) -> MmCardDefinition:
	return load("%s/%s/%s.tres" % [CONTENT_ROOT, set_name, file_name]) as MmCardDefinition


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
			if candidate is Resource and not (candidate is Script) and not _is_own_file(candidate as Resource):
				found.append(candidate as Resource)
				found.append_array(_sub_resources(candidate as Resource))
	return found


## Whether [param resource] is saved as a file of its own, such as a Token Definition in
## content/tokens/, which cards share on purpose (engine ADR 0044).
func _is_own_file(resource: Resource) -> bool:
	return resource.resource_path != "" and not resource.resource_path.contains("::")


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
