extends GutTest
## Rules text is generated from abilities (A333), in current Oracle wording (A343): a
## permanent calls itself "this creature" or "this artifact", and a spell goes by its name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const CONTENT_ROOT: String = "res://content/cards/alpha"
## Every set's folder is under here.
const SETS_ROOT: String = "res://content/cards"
const CardType := MmCardTypes.CardType
const Whose := MmTrigger.Whose

## What each authored card with abilities prints.
const PRINTED: Dictionary[String, String] = {
	"ancestral_recall": "Target player draws three cards.",
	"ankh_of_mishra": "Whenever a land enters, this artifact deals 2 damage to that land's controller.",
	"battlegrowth": "Put a +1/+1 counter on target creature.",
	"black_knight": "First strike\nProtection from white",
	"charmed_stray": "Lifelink\nWhen this creature enters, put a +1/+1 counter on each other creature you control originally named Charmed Stray.",
	"coordinated_maneuver": "Choose one —\n"
		+ "• Coordinated Maneuver deals X damage to target creature, where X is the number of creatures you control.\n"
		+ "• Destroy target enchantment.",
	"counterspell": "Counter target spell.",
	"dark_ritual": "Add {B}{B}{B}.",
	"drudge_skeletons": "{B}: Regenerate this creature.",
	"elvish_archers": "First strike",
	"fog": "Prevent all combat damage that would be dealt this turn.",
	"forest": "({T}: Add {G}.)",
	"frozen_shade": "{B}: This creature gets +1/+1 until end of turn.",
	"giant_growth": "Target creature gets +3/+3 until end of turn.",
	"giant_spider": "Reach",
	"goblin_balloon_brigade": "{R}: This creature gains flying until end of turn.",
	"helpful_hunter": "When this creature enters, draw a card.",
	"howling_mine": "At the beginning of each player's draw step, if this artifact is untapped, that player draws a card.",
	"instill_infection": "Put a -1/-1 counter on target creature. Draw a card.",
	"island": "({T}: Add {U}.)",
	"ivory_tower": "At the beginning of your upkeep, you gain X life, where X is the number of cards in your hand minus 4.",
	"keldon_warlord": "This creature's power and toughness are each equal to the number of non-Wall creatures you control.",
	"lightning_bolt": "Lightning Bolt deals 3 damage to any target.",
	"llanowar_elves": "{T}: Add {G}.",
	"malamet_war_scribe": "When this creature enters, each creature you control gets +2/+1 until end of turn.",
	"mountain": "({T}: Add {R}.)",
	"oblivion_ring": "When this enchantment enters, exile another target nonland permanent.\n"
		+ "When this enchantment leaves the battlefield, return the exiled card to the battlefield under its owner's control.",
	"ornery_kudu": "When this creature enters, put a -1/-1 counter on target creature you control.",
	"path_of_bravery": "As long as your life total is greater than or equal to your starting life total, each creature you control gets +1/+1.\n"
		+ "Whenever one or more creatures you control attack, you gain X life, where X is the number of attacking creatures.",
	"plains": "({T}: Add {W}.)",
	"raise_dead": "Return target creature card from your graveyard to your hand.",
	"prideful_parent": "Vigilance\nWhen this creature enters, create a 1/1 white Cat creature token.",
	"prodigal_sorcerer": "{T}: This creature deals 1 damage to any target.",
	"samite_healer": "{T}: Prevent the next 1 damage that would be dealt to any target this turn.",
	"serra_angel": "Flying, vigilance",
	"shatter": "Destroy target artifact.",
	"shivan_dragon": "Flying\n{R}: This creature gets +1/+0 until end of turn.",
	"short_sword": "Equipped creature gets +1/+1.\nEquip {1}",
	"skyknight_squire": "Whenever another creature you control enters, put a +1/+1 counter on this creature.\n"
		+ "As long as this creature has three or more +1/+1 counters on it, it has flying and is a Knight in addition to its other types.",
	"stifle": "Counter target activated or triggered ability.",
	"swamp": "({T}: Add {B}.)",
	"terror": "Destroy target nonartifact, nonblack creature. It can't be regenerated.",
	"uthden_troll": "{R}: Regenerate this creature.",
	"wall_of_stone": "Defender",
	"white_knight": "First strike\nProtection from black",
	"whitemane_lion": "Flash\nWhen this creature enters, return a creature you control to its owner's hand.",
}


func test_each_authored_card_prints_its_oracle_wording() -> void:
	for file_name: String in PRINTED:
		assert_eq(_look(file_name).rules_text, PRINTED[file_name], file_name)


func test_no_ability_of_any_authored_card_falls_back_to_a_class_name() -> void:
	var files: PackedStringArray = PackedStringArray()
	for set_name: String in DirAccess.get_directories_at(SETS_ROOT):
		files.append_array(DirAccess.get_files_at("%s/%s" % [SETS_ROOT, set_name]))
	var checked: int = 0
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		var look: CardLook = _look(file.get_basename())
		checked += 1
		assert_false(AbilityText.has_fallback(look.rules_text), "%s: %s" % [file, look.rules_text])
		if look.abilities.is_empty():
			assert_eq(look.rules_text, "", file)
		else:
			assert_ne(look.rules_text, "", file)
	assert_gt(checked, 40)


func test_something_it_has_no_words_for_is_marked_as_a_fallback() -> void:
	var odd: SpellAbility = SpellAbility.new()
	odd.effects = [MmEffect.new()]

	var text: String = AbilityText.of_ability(odd, "Oddity")

	assert_true(AbilityText.has_fallback(text))
	assert_false(AbilityText.has_fallback("Destroy target artifact."))


func test_a_view_of_a_card_in_an_encounter_prints_the_same_text_as_the_printed_card() -> void:
	var definition: MmCardDefinition = load(CONTENT_ROOT + "/prodigal_sorcerer.tres") as MmCardDefinition
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.copies(definition, 40), Scenario.copies(definition, 40)))
	Scenario.keep_all(engine)

	var held: MmObjectView = engine.view_for(engine.hero()).hand[0]

	assert_eq(CardLook.of_view(held).rules_text, PRINTED["prodigal_sorcerer"])


func test_a_permanent_names_itself_by_its_kind_and_anything_else_by_its_name() -> void:
	assert_eq(AbilityText.self_noun([CardType.CREATURE], "Prodigal Sorcerer"), "this creature")
	assert_eq(AbilityText.self_noun([CardType.ARTIFACT, CardType.CREATURE], "Golem"), "this creature")
	assert_eq(AbilityText.self_noun([CardType.ARTIFACT], "Ankh of Mishra"), "this artifact")
	assert_eq(AbilityText.self_noun([CardType.ENCHANTMENT], "Crusade"), "this enchantment")
	assert_eq(AbilityText.self_noun([CardType.LAND], "Life Land"), "this land")
	assert_eq(AbilityText.self_noun([CardType.INSTANT], "Lightning Bolt"), "Lightning Bolt")
	assert_eq(AbilityText.self_noun([], "Diviner's Boon"), "Diviner's Boon")


func test_what_an_ability_does_leaves_out_its_cost() -> void:
	var sorcerer: MmAbility = (load(CONTENT_ROOT + "/prodigal_sorcerer.tres") as MmCardDefinition).abilities[0]

	assert_eq(AbilityText.of_ability(sorcerer, "this creature"), "{T}: This creature deals 1 damage to any target.")
	assert_eq(AbilityText.effect_of(sorcerer, "this creature"), "This creature deals 1 damage to any target.")


func test_what_a_triggered_ability_does_leaves_out_its_trigger_and_condition() -> void:
	var mine: MmAbility = (load(CONTENT_ROOT + "/howling_mine.tres") as MmCardDefinition).abilities[0]

	assert_eq(AbilityText.effect_of(mine, "this artifact"), "That player draws a card.")


func test_what_a_spell_does_is_its_whole_text() -> void:
	var bolt: MmAbility = (load(CONTENT_ROOT + "/lightning_bolt.tres") as MmCardDefinition).abilities[0]

	assert_eq(AbilityText.effect_of(bolt, "Lightning Bolt"), "Lightning Bolt deals 3 damage to any target.")


func test_a_modal_spell_prints_choose_one_and_a_bullet_for_each_mode() -> void:
	var charm: MmCardDefinition = Scenario.free_charm("Charm")

	var text: String = AbilityText.of_card(charm.abilities, charm.card_types, charm.supertypes, "Charm")

	assert_eq(text, "Choose one —\n• Charm deals 2 damage to target creature.\n• Destroy target enchantment.")


func test_a_mode_is_worded_alone_and_is_what_a_modal_spell_does_once_it_is_chosen() -> void:
	var spell: SpellAbility = Scenario.free_charm("Charm").abilities[0] as SpellAbility

	assert_eq(AbilityText.mode_text(spell, 1, "Charm"), "Destroy target enchantment.")
	assert_eq(AbilityText.effect_of(spell, "Charm", 0), "Charm deals 2 damage to target creature.")
	assert_true(AbilityText.effect_of(spell, "Charm").begins_with("Choose one —"), "Before a mode is chosen, every mode.")


func test_a_mode_with_a_counted_amount_says_what_x_is() -> void:
	var count: CountValue = CountValue.new()
	count.selection = Scenario.each(Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE), _yours()]))
	var damage: DealDamageEffect = Scenario.deal_damage(0, Scenario.targeted(0))
	damage.amount = count
	var spell: SpellAbility = Scenario.free_modal("Maneuver", [
		Scenario.spell_mode([Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))], [damage]),
		Scenario.spell_mode([Scenario.target(Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT))],
			[Scenario.destroy(Scenario.targeted(0))]),
	]).abilities[0] as SpellAbility

	assert_eq(AbilityText.mode_text(spell, 0, "Maneuver"),
		"Maneuver deals X damage to target creature, where X is the number of creatures you control.")


func test_a_free_ability_costs_zero() -> void:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.effects = [Scenario.gain_life(1, Scenario.you())]

	assert_eq(AbilityText.of_ability(ability, "this creature"), "{0}: You gain 1 life.")


func test_mana_and_tapping_are_both_listed_as_costs() -> void:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = Scenario.mana_cost(1, [MmMana.Type.RED])
	ability.costs = [TapCost.new()]
	ability.targets = [Scenario.target_player()]
	ability.effects = [Scenario.lose_life(2, Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(ability, "this creature"), "{1}{R}, {T}: Target player loses 2 life.")


func test_the_trigger_kinds_are_worded() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var expected: Dictionary[String, MmTrigger] = {
		"At the beginning of each opponent's upkeep, you gain 1 life.": Scenario.at_step(MmTurn.Step.UPKEEP, Whose.OPPONENT),
		"At the beginning of your end step, you gain 1 life.": Scenario.at_step(MmTurn.Step.END, Whose.YOU),
		"When this creature enters, you gain 1 life.": Scenario.enters(IsSourceFilter.new()),
		"Whenever a creature you control enters, you gain 1 life.": Scenario.enters(creature, Whose.YOU),
		"Whenever another creature you control enters, you gain 1 life.":
			Scenario.enters(Scenario.all_of([creature, Scenario.is_not(IsSourceFilter.new())]), Whose.YOU),
		"Whenever a creature dies, you gain 1 life.": Scenario.dies(creature),
		"When this creature dies, you gain 1 life.": Scenario.dies(IsSourceFilter.new()),
		"When this creature leaves the battlefield, you gain 1 life.": Scenario.leaves(IsSourceFilter.new()),
		"Whenever a creature leaves the battlefield, you gain 1 life.": Scenario.leaves(creature),
		"Whenever you cast a creature spell, you gain 1 life.": Scenario.casts(creature, Whose.YOU),
		"Whenever an opponent casts a spell, you gain 1 life.": Scenario.casts(null, Whose.OPPONENT),
		"Whenever a player casts an artifact spell, you gain 1 life.": Scenario.casts(Scenario.of_type(CardType.ARTIFACT), Whose.ANY),
		"Whenever one or more creatures you control attack, you gain 1 life.": _attack(Whose.YOU),
		"Whenever one or more creatures an opponent controls attack, you gain 1 life.": _attack(Whose.OPPONENT),
		"Whenever one or more creatures a player controls attack, you gain 1 life.": _attack(Whose.ANY),
	}
	for text: String in expected:
		assert_eq(AbilityText.of_ability(Scenario.triggered(expected[text], gain), "this creature"), text)


func test_the_effects_no_authored_card_uses_yet_are_worded() -> void:
	var white_creatures: EachSelection = Scenario.each_creature(Scenario.of_color(MmCardTypes.CardColor.WHITE))
	var you_control: ControlledByFilter = ControlledByFilter.new()
	var other_strays: EachSelection = Scenario.each_creature(Scenario.all_of(
		[Scenario.of_color(MmCardTypes.CardColor.WHITE), you_control, Scenario.is_not(IsSourceFilter.new()), Scenario.named("Charmed Stray")]))
	var expected: Dictionary[String, MmEffect] = {
		"Each player loses 2 life.": Scenario.lose_life(2, Scenario.each(IsPlayerFilter.new())),
		"Each player draws two cards.": Scenario.draw_cards(2, Scenario.each(IsPlayerFilter.new())),
		"Sample deals 1 damage to each white creature.": Scenario.deal_damage(1, white_creatures),
		"Destroy each white creature.": Scenario.destroy(white_creatures),
		"Each white creature loses all abilities until end of turn.": Scenario.until_end_of_turn(Scenario.lose_all_abilities(white_creatures)),
		"Target creature has base power and toughness 0/1 until end of turn.": Scenario.until_end_of_turn(Scenario.set_pt(0, 1, Scenario.targeted(0))),
		"Target creature gets -2/-0 until end of turn.": Scenario.until_end_of_turn(Scenario.modify_pt(-2, 0, Scenario.targeted(0))),
		"Prevent the next 3 damage that would be dealt to you this turn.": Scenario.prevent_next(3, Scenario.you()),
		"Regenerate target creature.": Scenario.regenerate(Scenario.targeted(0)),
		"Put a +1/+1 counter on target creature.": Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, Scenario.targeted(0)),
		"Put two -1/-1 counters on each white creature.": Scenario.put_counters(MmCounter.Kind.MINUS_ONE_MINUS_ONE, 2, white_creatures),
		"Destroy each other white creature you control originally named Charmed Stray.": Scenario.destroy(other_strays),
		"Destroy each creature not originally named Bear.": Scenario.destroy(Scenario.each_creature(Scenario.is_not(Scenario.named("Bear")))),
		"Return a creature you control to its owner's hand.": Scenario.return_to_hand(Scenario.chosen(Scenario.all_of([Scenario.of_type(CardType.CREATURE), you_control]))),
		"Return each creature to its owner's hand.": Scenario.return_to_hand(Scenario.each_creature()),
		"Destroy an artifact.": Scenario.destroy(Scenario.chosen(Scenario.of_type(CardType.ARTIFACT))),
		"Create a 1/1 white Cat creature token.": Scenario.create_tokens(Scenario.cat()),
		"Create two 2/2 black and green Zombie Warrior creature tokens.": Scenario.create_tokens(
			Scenario.token(2, 2, [MmCardTypes.CardColor.BLACK, MmCardTypes.CardColor.GREEN], ["Zombie", "Warrior"]), 2),
	}
	for text: String in expected:
		var spell: SpellAbility = SpellAbility.new()
		spell.targets = [Scenario.target(Scenario.of_type(CardType.CREATURE))]
		spell.effects = [expected[text]]
		assert_eq(AbilityText.of_ability(spell, "Sample"), text)


func test_a_spell_with_two_effects_prints_two_sentences_and_calls_its_target_it_the_second_time() -> void:
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target(Scenario.of_type(CardType.CREATURE))]
	spell.effects = [Scenario.deal_damage(3, Scenario.targeted(0)), Scenario.deal_damage(1, Scenario.controller_of(Scenario.targeted(0)))]

	assert_eq(AbilityText.of_ability(spell, "Sample"), "Sample deals 3 damage to target creature. Sample deals 1 damage to its controller.")


func test_a_player_targeted_once_is_that_player_the_second_time() -> void:
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target_player()]
	spell.effects = [Scenario.draw_cards(1, Scenario.targeted(0)), Scenario.lose_life(2, Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(spell, "Sample"), "Target player draws a card. That player loses 2 life.")


func test_of_two_card_types_the_last_is_the_noun() -> void:
	var both: MmFilter = Scenario.all_of([Scenario.of_type(CardType.ARTIFACT), Scenario.of_type(CardType.CREATURE)])
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target(both)]
	spell.effects = [Scenario.destroy(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(spell, "Sample"), "Destroy target artifact creature.")
	assert_eq(AbilityText.things(both), "artifact creatures")


func test_lifelink_is_a_keyword() -> void:
	assert_eq(AbilityText.of_ability(LifelinkAbility.new(), "Sample"), "Lifelink")
	assert_true(AbilityText.is_keyword(LifelinkAbility.new()))


func test_target_spell_is_worded_with_and_without_a_filter() -> void:
	var any: SpellAbility = SpellAbility.new()
	any.targets = [Scenario.target_spell()]
	any.effects = [Scenario.counter(Scenario.targeted(0))]
	var creatures: SpellAbility = SpellAbility.new()
	creatures.targets = [Scenario.target_spell(Scenario.of_type(CardType.CREATURE))]
	creatures.effects = [Scenario.counter(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(any, "Sample"), "Counter target spell.")
	assert_eq(AbilityText.of_ability(creatures, "Sample"), "Counter target creature spell.")


func test_a_card_in_a_graveyard_is_worded_with_whose_graveyard_it_is_in() -> void:
	var yours: SpellAbility = SpellAbility.new()
	yours.targets = [Scenario.your_dead_creature()]
	yours.effects = [Scenario.return_to_hand(Scenario.targeted(0))]
	var any: SpellAbility = SpellAbility.new()
	any.targets = [Scenario.target_graveyard_card()]
	any.effects = [Scenario.return_to_hand(Scenario.targeted(0))]
	var theirs: SpellAbility = SpellAbility.new()
	theirs.targets = [Scenario.target_graveyard_card(Scenario.owned_by(Whose.OPPONENT))]
	theirs.effects = [Scenario.return_to_hand(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(yours, "Sample"), "Return target creature card from your graveyard to your hand.")
	assert_eq(AbilityText.of_ability(any, "Sample"), "Return target card from a graveyard to its owner's hand.")
	assert_eq(AbilityText.of_ability(theirs, "Sample"), "Return target card from an opponent's graveyard to its owner's hand.")
	assert_eq(AbilityText.things(Scenario.owned_by(Whose.YOU)), "permanents you own")


func test_exiling_another_target_and_returning_the_exiled_card_are_worded() -> void:
	var exiling: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.exile(Scenario.targeted(0))], [Scenario.another_nonland_permanent()])
	var returning: TriggeredAbility = Scenario.triggered(Scenario.leaves(IsSourceFilter.new()),
		[Scenario.return_to_battlefield(ExiledWithSourceSelection.new())])
	var another_creature: ActivatedAbility = ActivatedAbility.new()
	another_creature.targets = [Scenario.target(Scenario.all_of([Scenario.is_not(IsSourceFilter.new()), Scenario.of_type(CardType.CREATURE)]))]
	another_creature.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(exiling, "this enchantment"), "When this enchantment enters, exile another target nonland permanent.")
	assert_eq(AbilityText.of_ability(returning, "this enchantment"),
		"When this enchantment leaves the battlefield, return the exiled card to the battlefield under its owner's control.")
	assert_eq(AbilityText.of_ability(Scenario.exile_spell("Banish").abilities[0], "Banish"), "Exile target creature.")
	assert_eq(AbilityText.of_ability(another_creature, "this creature"), "{0}: This creature deals 1 damage to another target creature.")
	assert_eq(AbilityText.things(Scenario.is_not(IsPlayerFilter.new())), "permanents", "Anything but a player is a permanent.")


func test_target_ability_is_worded_as_activated_or_triggered() -> void:
	var stifle: SpellAbility = SpellAbility.new()
	stifle.targets = [Scenario.target_ability()]
	stifle.effects = [Scenario.counter(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(stifle, "Sample"), "Counter target activated or triggered ability.")


func test_the_static_abilities_no_authored_card_uses_yet_are_worded() -> void:
	var extra_land: AdditionalLandPlaysAbility = AdditionalLandPlaysAbility.new()
	var extra_blocks: BlockAdditionalAbility = BlockAdditionalAbility.new()
	extra_blocks.count = 2
	var anthem: ContinuousStaticAbility = Scenario.continuous_static([
		Scenario.modify_pt(1, 1, Scenario.each_creature(Scenario.of_color(MmCardTypes.CardColor.WHITE)))])

	assert_eq(AbilityText.of_ability(extra_land, "this artifact"), "You may play an additional land on each of your turns.")
	assert_eq(AbilityText.of_ability(extra_blocks, "this creature"), "This creature can block two additional creatures each combat.")
	assert_eq(AbilityText.of_ability(DamageStaysAbility.new(), "this creature"), "Damage isn't removed from this creature during cleanup steps.")
	assert_eq(AbilityText.of_ability(anthem, "this enchantment"), "Each white creature gets +1/+1.")
	assert_eq(AbilityText.of_ability(Scenario.protection_from(Scenario.of_type(CardType.ARTIFACT)), "this creature"), "Protection from artifacts")
	assert_eq(AbilityText.of_ability(HasteAbility.new(), "this creature"), "Haste")


func test_a_static_ability_says_has_and_is_where_an_effect_says_gains_and_becomes() -> void:
	var knights: EachSelection = Scenario.each_creature(Scenario.has_subtype("Knight"))
	var lord: ContinuousStaticAbility = Scenario.continuous_static([Scenario.gain_abilities([FlyingAbility.new()], knights)])
	var knighted: ContinuousStaticAbility = Scenario.continuous_static([Scenario.add_subtypes(["Knight"], SourceSelection.new())])
	var elves: ContinuousStaticAbility = Scenario.continuous_static([Scenario.add_subtypes(["Elf", "Warrior"], knights)])
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target(Scenario.of_type(CardType.CREATURE))]
	spell.effects = [Scenario.until_end_of_turn(Scenario.add_subtypes(["Knight"], Scenario.targeted(0)))]

	assert_eq(AbilityText.of_ability(lord, "this creature"), "Each Knight creature has flying.")
	assert_eq(AbilityText.of_ability(knighted, "this creature"), "This creature is a Knight in addition to its other types.")
	assert_eq(AbilityText.of_ability(elves, "this creature"), "Each Knight creature is an Elf Warrior in addition to its other types.")
	assert_eq(AbilityText.of_ability(spell, "Sample"), "Target creature becomes a Knight in addition to its other types until end of turn.")


func test_a_conditional_static_ability_is_one_sentence_that_calls_its_source_it_after_the_condition() -> void:
	var plus: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
	var squire: ContinuousStaticAbility = Scenario.continuous_static(
		[Scenario.gain_abilities([FlyingAbility.new()], SourceSelection.new()), Scenario.add_subtypes(["Knight"], SourceSelection.new())],
		Scenario.condition(SourceSelection.new(), Scenario.has_counters(plus, 3)))
	var one_counter: ContinuousStaticAbility = Scenario.continuous_static(
		[Scenario.modify_pt(1, 0, SourceSelection.new())], Scenario.condition(SourceSelection.new(), Scenario.has_counters(plus, 1)))

	assert_eq(AbilityText.of_ability(squire, "this creature"),
		"As long as this creature has three or more +1/+1 counters on it, it has flying and is a Knight in addition to its other types.")
	assert_eq(AbilityText.of_ability(one_counter, "this creature"), "As long as this creature has a +1/+1 counter on it, it gets +1/+0.")
	var brave: ContinuousStaticAbility = Scenario.continuous_static(
		[Scenario.modify_pt(1, 1, SourceSelection.new())], LifeAtLeastStartingCondition.new())
	assert_eq(AbilityText.of_ability(brave, "this creature"),
		"As long as your life total is greater than or equal to your starting life total, it gets +1/+1.")
	assert_eq(AbilityText.things(Scenario.all_of([Scenario.of_type(CardType.CREATURE), IsAttackingFilter.new()])), "attacking creatures")
	assert_eq(AbilityText.things(Scenario.all_of([Scenario.of_type(CardType.CREATURE), Scenario.is_not(IsAttackingFilter.new())])),
		"nonattacking creatures")


func test_a_counter_filter_is_worded_after_its_noun() -> void:
	var plus: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
	var minus: MmCounter.Kind = MmCounter.Kind.MINUS_ONE_MINUS_ONE
	var expected: Dictionary[String, MmFilter] = {
		"Destroy each creature with a +1/+1 counter on it.": Scenario.has_counters(plus, 1),
		"Destroy each creature with three or more -1/-1 counters on it.": Scenario.has_counters(minus, 3),
		"Destroy each creature without a +1/+1 counter on it.": Scenario.is_not(Scenario.has_counters(plus, 1)),
		"Destroy each creature with fewer than two -1/-1 counters on it.": Scenario.is_not(Scenario.has_counters(minus, 2)),
	}
	for text: String in expected:
		var spell: SpellAbility = SpellAbility.new()
		spell.effects = [Scenario.destroy(Scenario.each_creature(expected[text]))]
		assert_eq(AbilityText.of_ability(spell, "Sample"), text)


func test_keywords_share_a_line_and_other_abilities_get_their_own() -> void:
	var abilities: Array[MmAbility] = [FlyingAbility.new(), FirstStrikeAbility.new(), TrampleAbility.new(),
		Scenario.regenerate_ability(Scenario.mana_cost(0, [MmMana.Type.GREEN]))]

	assert_eq(AbilityText.of_card(abilities, [CardType.CREATURE], [], "Sample"), "Flying, first strike, trample\n{G}: Regenerate this creature.")


## The look of the authored card in [param file_name], whichever set's folder it is in.
func _look(file_name: String) -> CardLook:
	for set_name: String in DirAccess.get_directories_at(SETS_ROOT):
		var path: String = "%s/%s/%s.tres" % [SETS_ROOT, set_name, file_name]
		if ResourceLoader.exists(path):
			return CardLook.of_definition(load(path) as MmCardDefinition)
	return null


func test_a_keyword_is_told_from_any_other_ability() -> void:
	assert_true(AbilityText.is_keyword(FlyingAbility.new()))
	assert_true(AbilityText.is_keyword(ProtectionAbility.new()))
	assert_false(AbilityText.is_keyword(ActivatedAbility.new()))


# --- Emblems and Potions (ADR 0036) ----------------------------------------------------

func test_the_authored_boons_and_potion_print_as_they_were_agreed() -> void:
	var electromancers: MmCardDefinition = load("res://content/emblems/electromancers_boon.tres")
	var diviners: MmCardDefinition = load("res://content/emblems/diviners_boon.tres")
	var big_gulp: MmCardDefinition = load("res://content/potions/big_gulp.tres")

	assert_eq(AbilityText.lines_of(electromancers.abilities, AbilityText.EMBLEM_NOUN),
		["{R}: This emblem deals 3 damage to any target. Activate only once each game."] as Array[String])
	assert_eq(AbilityText.lines_of(diviners.abilities, AbilityText.EMBLEM_NOUN),
		["{2}{U}: Draw two cards. Activate only as a sorcery and only once each game."] as Array[String])
	assert_eq(AbilityText.lines_of(big_gulp.abilities, AbilityText.POTION_NOUN),
		["Target creature gets +2/+2 until end of turn."] as Array[String], "A Potion prints no cost.")


func test_an_ability_restricted_only_to_sorcery_timing_says_so() -> void:
	var ability: ActivatedAbility = Scenario.regenerate_ability(Scenario.mana_cost(1))
	ability.is_sorcery_speed = true

	assert_eq(AbilityText.of_ability(ability, "this creature"), "{1}: Regenerate this creature. Activate only as a sorcery.")


func test_equip_prints_as_a_keyword_with_its_cost_and_on_the_stack_as_what_it_does() -> void:
	var equip: EquipAbility = EquipAbility.new()
	equip.mana_cost = Scenario.mana_cost(1)

	assert_eq(AbilityText.of_ability(equip, "this artifact"), "Equip {1}")
	assert_true(AbilityText.is_keyword(equip))
	assert_eq(AbilityText.effect_of(equip, "this artifact"), "Attach this artifact to target creature you control.")


func test_what_an_equipment_is_attached_to_is_the_equipped_creature() -> void:
	var bonus: ModifyPowerToughnessContinuousEffect = Scenario.modify_pt(1, 1, AttachedToSelection.new())

	assert_eq(AbilityText.of_ability(Scenario.continuous_static([bonus]), "this artifact"), "Equipped creature gets +1/+1.")


func test_on_the_stack_an_emblems_ability_reads_without_its_cost_or_restrictions() -> void:
	var electromancers: MmCardDefinition = load("res://content/emblems/electromancers_boon.tres")

	assert_eq(AbilityText.effect_of(electromancers.abilities[0], AbilityText.EMBLEM_NOUN), "This emblem deals 3 damage to any target.")


func _yours() -> ControlledByFilter:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = Whose.YOU
	return yours


func _attack(whose: Whose) -> AttackersDeclaredTrigger:
	var trigger: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	trigger.whose = whose
	return trigger
