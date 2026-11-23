extends GutTest
## Changeling (CR 702.73a): "This object is every creature type." It is a characteristic-
## defining ability (CR 604.3), so it works in every zone, and it applies in layer 4 before
## the layer's continuous effects (CR 613.3). Its object keeps its printed subtypes; what it
## has is every creature type besides, asked through MmCharacteristics.has_subtype()
## (ADR 0075).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_it_gets_the_bonus_of_a_cat_lord_and_of_a_warrior_lord() -> void:
	var engine: MmEngine = _main_with([Scenario.changeling(), _banner("Cat"), _banner("Warrior"), _elf()], [])
	var changeling: int = Scenario.permanent_named(engine, engine.hero().id, "Changeling")
	var elf: int = Scenario.permanent_named(engine, engine.hero().id, "Elf")

	assert_eq(Scenario.pt(engine, changeling), [3, 3], "A Cat and a Warrior.")
	assert_eq(Scenario.pt(engine, elf), [1, 1], "Neither.")


func test_it_is_every_creature_type_and_no_other_kind_of_subtype() -> void:
	var engine: MmEngine = _main_with([Scenario.changeling()], [])
	var changeling: MmCharacteristics = Scenario.now(engine, Scenario.permanent_named(engine, engine.hero().id, "Changeling"))

	assert_true(changeling.is_every_creature_type)
	for creature_type: String in ["Cat", "Assembly-Worker", "Shapeshifter", CreatureTypes.ALL[-1]]:
		assert_true(changeling.has_subtype(creature_type), creature_type)
	assert_false(changeling.has_subtype("Equipment"), "An artifact type (CR 205.3g).")
	assert_false(changeling.has_subtype("Forest"), "A land type (CR 205.3i).")
	assert_eq(changeling.subtypes, ["Shapeshifter"] as Array[String], "Its printed subtypes are kept as they are.")


func test_a_creature_without_it_has_only_its_own_types() -> void:
	var engine: MmEngine = _main_with([_elf()], [])
	var elf: MmCharacteristics = Scenario.now(engine, Scenario.permanent_named(engine, engine.hero().id, "Elf"))

	assert_false(elf.is_every_creature_type)
	assert_true(elf.has_subtype("Elf"))
	assert_false(elf.has_subtype("Cat"))


func test_in_the_hand_it_is_every_creature_type_too() -> void:
	# CR 604.3: a characteristic-defining ability works in every zone.
	var engine: MmEngine = _main_with([], [Scenario.changeling("Pocket Changeling")])
	var in_hand: int = Scenario.card_in_hand(engine, engine.hero(), "Pocket Changeling")
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, in_hand)

	assert_true(Scenario.has_subtype("Cat").matches(engine.game_state(), MmReference.to_object(in_hand), context))


func test_as_printed_it_is_every_creature_type() -> void:
	# A deck screen reads printed characteristics (ADR 0009).
	var printed: MmCharacteristics = MmCharacteristics.printed(Scenario.changeling())

	assert_true(printed.is_every_creature_type)
	assert_true(printed.has_subtype("Cat"))


func test_after_losing_all_abilities_it_is_still_every_creature_type() -> void:
	# CR 613.1d, 613.1f: it applied in layer 4, before layer 6 takes the ability away.
	var engine: MmEngine = _main_with([Scenario.changeling(), _banner("Cat")], [_hush()])
	var changeling: int = Scenario.permanent_named(engine, engine.hero().id, "Changeling")

	assert_eq(Scenario.cast_and_resolve(engine, "Hush", [MmReference.to_object(changeling)]), "")

	assert_false(Scenario.now(engine, changeling).has_ability(ChangelingAbility))
	assert_true(Scenario.now(engine, changeling).has_subtype("Cat"))
	assert_eq(Scenario.pt(engine, changeling), [2, 2])


func test_it_is_of_the_type_a_rally_chose() -> void:
	var engine: MmEngine = _main_with([Scenario.changeling(), _elf()], [Scenario.rally()])
	var changeling: int = Scenario.permanent_named(engine, engine.hero().id, "Changeling")
	var elf: int = Scenario.permanent_named(engine, engine.hero().id, "Elf")
	Scenario.cast_and_resolve(engine, "Rally")

	assert_eq(Scenario.choose_creature_type(engine, "Cat"), "")

	assert_eq(Scenario.pt(engine, changeling), [2, 2])
	assert_eq(Scenario.pt(engine, elf), [1, 1])


func test_attached_by_reconfigure_it_has_no_creature_types() -> void:
	# CR 702.151b, CR 205.1b: attached, it isn't a creature, so it has no creature types.
	var sash: MmCardDefinition = Scenario.sash()
	sash.abilities.append(ChangelingAbility.new())
	var engine: MmEngine = _main_with([Scenario.creature("Bear", 2, 2), sash], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sash_id: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")
	assert_true(Scenario.now(engine, sash_id).has_subtype("Goblin"), "Unattached, it is every creature type.")

	assert_eq(Scenario.equip_and_resolve(engine, sash_id, bear), "")

	assert_false(Scenario.now(engine, sash_id).is_every_creature_type)
	assert_false(Scenario.now(engine, sash_id).has_subtype("Goblin"))
	assert_true(Scenario.now(engine, sash_id).has_subtype("Equipment"))


func test_both_players_see_that_it_is_every_creature_type() -> void:
	var engine: MmEngine = _main_with([Scenario.changeling()], [])
	var changeling: int = Scenario.permanent_named(engine, engine.hero().id, "Changeling")

	for player: MmPlayer in [engine.hero(), engine.villain()]:
		for seen: MmObjectView in engine.view_for(player).battlefield:
			if seen.id == changeling:
				assert_true(seen.is_every_creature_type)
				assert_eq(seen.subtypes, ["Shapeshifter"] as Array[String])


func test_changeling_is_saved_with_its_card() -> void:
	var path: String = "user://test_changeling.tres"
	assert_eq(ResourceSaver.save(Scenario.changeling(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	assert_true(loaded.abilities[0] is ChangelingAbility)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## An enchantment costing {0}: "[subtype] creatures you control get +1/+1."
func _banner(subtype: String) -> MmCardDefinition:
	var yours: ControlledByFilter = ControlledByFilter.new()
	return Scenario.enchantment(subtype + " Banner", [Scenario.continuous_static([Scenario.modify_pt(1, 1,
		Scenario.each_creature(Scenario.all_of([Scenario.has_subtype(subtype), yours])))])])


func _elf() -> MmCardDefinition:
	return Scenario.typed_creature("Elf", 1, 1, ["Elf"])


## "Target creature loses all abilities until end of turn."
func _hush() -> MmCardDefinition:
	return Scenario.creature_spell_until_end_of_turn("Hush", Scenario.lose_all_abilities(Scenario.targeted(0)))


## The Hero's [param hero_permanents] on the battlefield, with [param hero_extras] in hand, in
## the Hero's main phase.
func _main_with(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
