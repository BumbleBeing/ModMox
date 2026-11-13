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
	"black_knight": "First strike\nProtection from white",
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
	"howling_mine": "At the beginning of each player's draw step, if this artifact is untapped, that player draws a card.",
	"island": "({T}: Add {U}.)",
	"ivory_tower": "At the beginning of your upkeep, you gain X life, where X is the number of cards in your hand minus 4.",
	"keldon_warlord": "This creature's power and toughness are each equal to the number of non-Wall creatures you control.",
	"lightning_bolt": "Lightning Bolt deals 3 damage to any target.",
	"llanowar_elves": "{T}: Add {G}.",
	"mountain": "({T}: Add {R}.)",
	"plains": "({T}: Add {W}.)",
	"raise_dead": "Return target creature card from your graveyard to your hand.",
	"prodigal_sorcerer": "{T}: This creature deals 1 damage to any target.",
	"samite_healer": "{T}: Prevent the next 1 damage that would be dealt to any target this turn.",
	"serra_angel": "Flying, vigilance",
	"shatter": "Destroy target artifact.",
	"shivan_dragon": "Flying\n{R}: This creature gets +1/+0 until end of turn.",
	"stifle": "Counter target activated or triggered ability.",
	"swamp": "({T}: Add {B}.)",
	"terror": "Destroy target nonartifact, nonblack creature. It can't be regenerated.",
	"uthden_troll": "{R}: Regenerate this creature.",
	"wall_of_stone": "Defender",
	"white_knight": "First strike\nProtection from black",
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
		"Whenever a creature dies, you gain 1 life.": Scenario.dies(creature),
		"When this creature dies, you gain 1 life.": Scenario.dies(IsSourceFilter.new()),
		"Whenever you cast a creature spell, you gain 1 life.": Scenario.casts(creature, Whose.YOU),
		"Whenever an opponent casts a spell, you gain 1 life.": Scenario.casts(null, Whose.OPPONENT),
		"Whenever a player casts an artifact spell, you gain 1 life.": Scenario.casts(Scenario.of_type(CardType.ARTIFACT), Whose.ANY),
	}
	for text: String in expected:
		assert_eq(AbilityText.of_ability(Scenario.triggered(expected[text], gain), "this creature"), text)


func test_the_effects_no_authored_card_uses_yet_are_worded() -> void:
	var white_creatures: EachSelection = Scenario.each_creature(Scenario.of_color(MmCardTypes.CardColor.WHITE))
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
