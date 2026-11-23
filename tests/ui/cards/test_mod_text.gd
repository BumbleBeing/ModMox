extends GutTest
## ADR 0029: a Mod's text is written from its Augmentation and Mod Cost, never by hand.

const Fixture: GDScript = preload("res://tests/ui/deckbuilder/support/deckbuilder_fixture.gd")
const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const CardType := MmCardTypes.CardType


func test_violent_reads_as_one_sentence_for_its_augmentation_and_one_for_its_cost() -> void:
	assert_eq(ModText.of(Fixture.violent()), "Modified card gets +1/+1 and gains trample. It costs {1} more to cast.")


func test_three_keywords_are_joined_as_oracle_text_joins_them() -> void:
	var mod: Mod = _creature_mod([_ability(FlyingAbility.new()), _ability(TrampleAbility.new()),
		_ability(VigilanceAbility.new())], Fixture.mana_cost(0, [MmMana.Type.WHITE] as Array[MmMana.Type]))

	assert_eq(ModText.of(mod), "Modified card gains flying, trample, and vigilance. It costs {W} more to cast.")


func test_an_ability_that_is_not_a_keyword_is_quoted_after_the_keywords() -> void:
	var ping: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.deal_damage(1, Scenario.targeted(0))], [Scenario.any_target()])
	var mod: Mod = _creature_mod([_power_toughness(2, 0), _ability(ping), _ability(HasteAbility.new())],
		Fixture.mana_cost(1, [MmMana.Type.RED] as Array[MmMana.Type]))

	assert_eq(ModText.of(mod), "Modified card gets +2/+0 and gains haste and "
		+ "\"When this creature enters, this creature deals 1 damage to any target.\" It costs {1}{R} more to cast.")


func test_menace_is_a_keyword_listed_in_the_augmentations_order() -> void:
	var mod: Mod = _creature_mod([_ability(MenaceAbility.new()), _ability(DeathtouchAbility.new()), _power_toughness(1, 0)],
		Fixture.mana_cost(0, [MmMana.Type.BLACK] as Array[MmMana.Type]))

	assert_eq(ModText.of(mod), "Modified card gets +1/+0 and gains menace and deathtouch. It costs {B} more to cast.")


func test_cant_be_blocked_is_quoted_and_a_mod_cost_of_0_has_no_cost_sentence() -> void:
	var mod: Mod = _creature_mod([_ability(CantBeBlockedAbility.new())], Fixture.mana_cost(0))

	assert_eq(ModText.of(mod), "Modified card gains \"This creature can't be blocked.\"")


func test_cant_be_countered_is_quoted_as_said_of_the_spell_on_any_card_type() -> void:
	var mod: Mod = Mod.new()
	mod.augmentation = [_ability(CantBeCounteredAbility.new())] as Array[MmModification]
	mod.mod_cost = Fixture.mana_cost(0)
	mod.card_types = [CardType.CREATURE, CardType.INSTANT] as Array[MmCardTypes.CardType]

	assert_eq(ModText.of(mod), "Modified card gains \"This spell can't be countered.\"")


func test_an_overload_says_what_it_changes_in_the_cards_text() -> void:
	var mod: Mod = Mod.new()
	mod.augmentation = [OverloadModification.new()] as Array[MmModification]
	mod.mod_cost = Fixture.mana_cost(3)
	mod.card_types = [CardType.INSTANT, CardType.SORCERY] as Array[MmCardTypes.CardType]

	assert_eq(ModText.of(mod), "Modified card has every \"target\" in its text changed to \"each.\" It costs {3} more to cast.")


func test_a_hex_takes_power_and_toughness_away() -> void:
	var mod: Mod = _creature_mod([_power_toughness(-1, -1)], Fixture.mana_cost(1))
	mod.is_hex = true

	assert_eq(ModText.of(mod), "Modified card gets -1/-1. It costs {1} more to cast.")


func test_a_land_mod_has_no_cost_sentence() -> void:
	var tap: ActivatedAbility = ActivatedAbility.new()
	tap.costs = [TapCost.new()] as Array[MmCost]
	tap.effects = [Scenario.gain_life(1, Scenario.you())] as Array[MmEffect]
	var mod: Mod = Mod.new()
	mod.augmentation = [_ability(tap)] as Array[MmModification]
	mod.card_types = [CardType.LAND] as Array[MmCardTypes.CardType]

	assert_eq(ModText.of(mod), "Modified card gains \"{T}: You gain 1 life.\"")


func _creature_mod(augmentation: Array[MmModification], mod_cost: AddManaCostModification) -> Mod:
	var mod: Mod = Mod.new()
	mod.augmentation = augmentation
	mod.mod_cost = mod_cost
	mod.card_types = [CardType.CREATURE] as Array[MmCardTypes.CardType]
	return mod


func _power_toughness(power: int, toughness: int) -> AddPowerToughnessModification:
	var modification: AddPowerToughnessModification = AddPowerToughnessModification.new()
	modification.power = power
	modification.toughness = toughness
	return modification


func _ability(ability: MmAbility) -> AddAbilityModification:
	var modification: AddAbilityModification = AddAbilityModification.new()
	modification.ability = ability
	return modification
