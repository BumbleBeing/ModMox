extends GutTest
## ADR 0029: a Mod has a name, a Rarity, an Augmentation and a Mod Cost, and accepts a card
## that has one of its card types as the card reads now. A Mod that accepts lands accepts
## nothing else and has no Mod Cost; a Unique Mod is once per card.

const Fixture: GDScript = preload("res://tests/ui/deckbuilder/support/deckbuilder_fixture.gd")
const BecomeCreature: GDScript = preload("res://tests/ui/deckbuilder/support/become_creature_modification.gd")
const CardType := MmCardTypes.CardType

var _fixture: Fixture


func before_each() -> void:
	_fixture = Fixture.new()


func test_violent_adds_its_augmentation_then_its_mod_cost() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")
	var violent: Mod = Fixture.violent()

	bears.attach(violent)

	assert_eq(bears.run_card.modifications, violent.modifications())
	assert_eq(bears.run_card.modifications.back(), violent.mod_cost, "The Mod Cost comes last.")
	var flattened: MmCardDefinition = bears.run_card.flatten()
	assert_eq([flattened.power, flattened.toughness], [3, 3])
	assert_true(flattened.abilities.any(func(ability: MmAbility) -> bool: return ability is TrampleAbility))
	assert_eq(DeckbuilderLooks.look_of(bears).mana_cost.describe(), "{2}{G}", "{1} adds to the {1} it had.")


func test_a_colored_mod_cost_adds_a_symbol() -> void:
	var elves: DeckbuilderCard = _fixture.own("llanowar_elves")

	elves.attach(Fixture.add_symbol_mod(MmMana.Type.GREEN))

	assert_eq(DeckbuilderLooks.look_of(elves).mana_cost.describe(), "{G}{G}")


func test_a_mod_accepts_a_card_with_any_of_its_card_types() -> void:
	var creature_mod: Mod = Fixture.violent()

	assert_true(creature_mod.is_applicable_to(_card("Clockwork Beast", [CardType.ARTIFACT, CardType.CREATURE])))
	assert_false(creature_mod.is_applicable_to(_card("Ankh", [CardType.ARTIFACT])))
	assert_false(creature_mod.is_applicable_to(_fixture.own("lightning_bolt")))


func test_a_mod_reads_the_card_as_its_earlier_mods_have_made_it() -> void:
	var forest: DeckbuilderCard = _fixture.working_deck().add_basic_land("Forest")
	var awaken: Mod = Fixture.any_card_mod()
	awaken.augmentation = [BecomeCreature.new() as MmModification] as Array[MmModification]
	var land_creature_mod: Mod = Fixture.violent()
	assert_false(land_creature_mod.is_applicable_to(forest))

	forest.attach(awaken)

	assert_true(land_creature_mod.is_applicable_to(forest), "The Forest is a creature now.")


func test_a_once_per_card_mod_is_not_applicable_to_a_card_that_holds_it() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")
	var once: Mod = Fixture.violent()
	once.is_once_per_card = true
	bears.attach(once)

	assert_false(once.is_applicable_to(bears))


func test_any_other_mod_goes_on_a_second_and_third_time() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")
	var violent: Mod = Fixture.violent()

	bears.attach(violent)
	assert_true(violent.is_applicable_to(bears))
	bears.attach(violent)
	assert_true(violent.is_applicable_to(bears))
	bears.attach(violent)

	assert_false(violent.is_applicable_to(bears), "Its three Mod Slots are full.")
	var flattened: MmCardDefinition = bears.run_card.flatten()
	assert_eq([flattened.power, flattened.toughness], [5, 5], "Each copy adds its whole Augmentation.")
	assert_eq(DeckbuilderLooks.look_of(bears).mana_cost.describe(), "{4}{G}", "And its whole Mod Cost.")
	assert_eq(bears.card_name(), "Extremely Violent Grizzly Bears")


func test_a_mods_own_rule_can_refuse_a_card_whose_type_fits() -> void:
	var needs_cost: Mod = Fixture.violent()
	needs_cost.needs_mana_cost = true
	var statue: DeckbuilderCard = _card("Statue", [CardType.CREATURE])

	assert_false(needs_cost.is_applicable_to(statue), "It has no mana cost.")
	assert_true(needs_cost.is_applicable_to(_fixture.own("grizzly_bears")))


func test_a_well_shaped_mod_has_no_problems() -> void:
	assert_eq(Fixture.violent().problems(), [] as Array[String])
	assert_eq(_land_mod().problems(), [] as Array[String])


func test_a_mod_needs_a_name() -> void:
	var mod: Mod = Fixture.violent()
	mod.name = ""

	assert_eq(mod.problems(), ["A Mod needs a name."] as Array[String])


func test_a_mod_needs_an_augmentation() -> void:
	var mod: Mod = Fixture.violent()
	mod.augmentation = []

	assert_eq(mod.problems(), ["A Mod needs an Augmentation."] as Array[String])


func test_a_mod_needs_a_card_type() -> void:
	var mod: Mod = Fixture.violent()
	mod.card_types = []

	assert_eq(mod.problems(), ["A Mod needs at least one card type."] as Array[String])


func test_a_mod_that_accepts_lands_accepts_nothing_else() -> void:
	var mod: Mod = _land_mod()
	mod.card_types.append(CardType.CREATURE)

	assert_eq(mod.problems(), ["A Mod that accepts lands accepts nothing else."] as Array[String])


func test_a_mod_that_accepts_lands_has_no_mod_cost() -> void:
	var mod: Mod = _land_mod()
	mod.mod_cost = Fixture.mana_cost(1)

	assert_eq(mod.problems(), ["A Mod that accepts lands has no Mod Cost."] as Array[String])


func test_any_other_mod_needs_a_mod_cost() -> void:
	var mod: Mod = Fixture.violent()
	mod.mod_cost = null

	assert_eq(mod.problems(), ["A Mod that does not accept lands needs a Mod Cost."] as Array[String])


func test_a_unique_mod_is_once_per_card() -> void:
	var mod: Mod = Fixture.violent()
	mod.rarity = Mod.Rarity.UNIQUE

	assert_eq(mod.problems(), ["A Unique Mod is once per card."] as Array[String])
	mod.is_once_per_card = true
	assert_eq(mod.problems(), [] as Array[String])


func test_no_hex_is_unique() -> void:
	var mod: Mod = Fixture.violent()
	mod.rarity = Mod.Rarity.UNIQUE
	mod.is_once_per_card = true
	mod.is_hex = true

	assert_eq(mod.problems(), ["No Hex is Unique."] as Array[String])


func test_a_violent_charmed_stray_is_still_originally_named_charmed_stray() -> void:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = load("res://content/cards/war_of_the_spark/charmed_stray.tres") as MmCardDefinition
	var stray: DeckbuilderCard = _fixture.collection.add(run_card)

	stray.attach(Fixture.violent())

	assert_eq(stray.card_name(), "Violent Charmed Stray")
	var flattened: MmCardDefinition = run_card.flatten()
	assert_eq(flattened.name, "Charmed Stray", "No Modification renames the card for its Mods.")
	assert_eq(flattened.original.name, "Charmed Stray")


## A card of [param card_types] with no mana cost, owned by the Collection.
func _card(card_name: String, card_types: Array[MmCardTypes.CardType]) -> DeckbuilderCard:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = MmCardDefinition.new()
	run_card.base.name = card_name
	run_card.base.card_types = card_types
	return _fixture.collection.add(run_card)


func _land_mod() -> Mod:
	var mod: Mod = Mod.new()
	mod.name = "Ancient"
	mod.augmentation = [Fixture.NoChange.new() as MmModification] as Array[MmModification]
	mod.card_types = [CardType.LAND] as Array[MmCardTypes.CardType]
	return mod
