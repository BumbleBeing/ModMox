extends GutTest
## ADR 0004: the Modifications a Run Card can carry, each applied to a private copy as the
## card is flattened. A Mod's Augmentation and Mod Cost are made of these (game ADR 0029).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Type := MmMana.Type


func test_power_and_toughness_are_added_to_the_printed_ones() -> void:
	var run_card: MmRunCard = _run_card(Scenario.creature("Bear", 2, 2))
	run_card.modifications.append(_power_toughness(1, 1))

	var flattened: MmCardDefinition = run_card.flatten()

	assert_eq([flattened.power, flattened.toughness], [3, 3])
	assert_eq([run_card.base.power, run_card.base.toughness], [2, 2], "The base is never changed.")


func test_two_power_and_toughness_modifications_add_up() -> void:
	var run_card: MmRunCard = _run_card(Scenario.creature("Bear", 2, 2))
	var plus_one: AddPowerToughnessModification = _power_toughness(1, 1)
	run_card.modifications.append(plus_one)
	run_card.modifications.append(plus_one)

	var flattened: MmCardDefinition = run_card.flatten()

	assert_eq([flattened.power, flattened.toughness], [4, 4])


func test_power_and_toughness_can_be_taken_away() -> void:
	var run_card: MmRunCard = _run_card(Scenario.creature("Bear", 2, 2))
	run_card.modifications.append(_power_toughness(-1, -1))

	var flattened: MmCardDefinition = run_card.flatten()

	assert_eq([flattened.power, flattened.toughness], [1, 1])


func test_an_ability_is_added_after_the_printed_ones() -> void:
	var run_card: MmRunCard = _run_card(Scenario.creature("Bear", 2, 2, [FlyingAbility.new()]))
	run_card.modifications.append(_ability(TrampleAbility.new()))

	var flattened: MmCardDefinition = run_card.flatten()

	assert_eq(flattened.abilities.size(), 2)
	assert_true(flattened.abilities[0] is FlyingAbility)
	assert_true(flattened.abilities[1] is TrampleAbility)
	assert_eq(run_card.base.abilities.size(), 1, "The base is never changed.")


func test_a_creature_given_trample_has_it_in_an_encounter() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var combat: MmEncounterSetup = Scenario.combat_setup([bear], [])
	for run_card: MmRunCard in combat.hero.deck:
		run_card.modifications.append(_ability(TrampleAbility.new()))

	var engine: MmEngine = Scenario.combat_ready_with(combat, [bear], [])

	assert_not_null(engine, "A seed deals the Bear.")
	var state: MmGameState = engine.game_state()
	var permanent: MmGameObject = state.object(Scenario.permanent_named(engine, engine.hero().id, "Bear"))
	var abilities: Array[MmAbility] = state.characteristics_of(permanent).abilities
	assert_true(abilities.any(func(ability: MmAbility) -> bool: return ability is TrampleAbility))


func test_a_creature_given_an_enters_ability_triggers_it() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var combat: MmEncounterSetup = Scenario.combat_setup([bear], [])
	var gain: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.gain_life(2, Scenario.you())])
	for run_card: MmRunCard in combat.hero.deck:
		run_card.modifications.append(_ability(gain))

	var engine: MmEngine = Scenario.combat_ready_with(combat, [bear], [])

	assert_not_null(engine, "A seed deals the Bear.")
	assert_eq(engine.hero().life, 22, "\"When this creature enters, you gain 2 life\" resolved.")


func test_a_mana_cost_adds_its_generic_mana_to_the_cards() -> void:
	var run_card: MmRunCard = _run_card(Scenario.creature("Bear", 2, 2, [], _cost(1, [Type.GREEN])))
	run_card.modifications.append(_mana_cost(1, []))

	var cost: MmManaCost = run_card.flatten().mana_cost

	assert_eq(cost.generic, 2, "{1}{G} and {1} are {2}{G}, not {1}{1}{G}.")
	assert_eq(cost.symbols, [Type.GREEN] as Array[MmMana.Type])
	assert_eq(run_card.base.mana_cost.generic, 1, "The base is never changed.")


func test_a_mana_cost_adds_its_symbols_to_the_cards() -> void:
	var run_card: MmRunCard = _run_card(Scenario.creature("Elf", 1, 1, [], _cost(0, [Type.GREEN])))
	run_card.modifications.append(_mana_cost(0, [Type.GREEN]))

	var cost: MmManaCost = run_card.flatten().mana_cost

	assert_eq(cost.generic, 0)
	assert_eq(cost.symbols, [Type.GREEN, Type.GREEN] as Array[MmMana.Type])


func test_a_card_with_no_mana_cost_takes_the_whole_cost_as_its_own() -> void:
	var definition: MmCardDefinition = Scenario.creature("Statue", 1, 1)
	definition.mana_cost = null
	var run_card: MmRunCard = _run_card(definition)
	var modification: AddManaCostModification = _mana_cost(1, [Type.RED])
	run_card.modifications.append(modification)

	var cost: MmManaCost = run_card.flatten().mana_cost

	assert_eq([cost.generic, cost.symbols], [1, [Type.RED] as Array[MmMana.Type]])
	assert_ne(cost, modification.cost, "The card's cost is its own copy, never the Modification's.")


func test_flattening_again_starts_from_the_base() -> void:
	var run_card: MmRunCard = _run_card(Scenario.creature("Bear", 2, 2, [], _cost(1, [Type.GREEN])))
	run_card.modifications.append(_mana_cost(1, []))
	run_card.modifications.append(_power_toughness(1, 1))
	run_card.modifications.append(_ability(TrampleAbility.new()))
	run_card.flatten()

	var flattened: MmCardDefinition = run_card.flatten()

	assert_eq(flattened.mana_cost.generic, 2)
	assert_eq([flattened.power, flattened.toughness], [3, 3])
	assert_eq(flattened.abilities.size(), 1)


func test_overloading_moves_the_targets_and_turns_each_target_into_each() -> void:
	var run_card: MmRunCard = _run_card(Scenario.free_shock("Shock", 3))
	run_card.modifications.append(OverloadModification.new())

	var spell: SpellAbility = run_card.flatten().abilities[0] as SpellAbility

	assert_eq(spell.targets.size(), 0, "CR 702.96b: it has no targets.")
	assert_eq(spell.overloaded_targets.size(), 1)
	var damage: DealDamageEffect = spell.effects[0] as DealDamageEffect
	assert_true(damage.recipients is OverloadedSelection)
	assert_eq((damage.recipients as OverloadedSelection).overloaded_index, 0)
	var base_spell: SpellAbility = run_card.base.abilities[0] as SpellAbility
	assert_eq(base_spell.targets.size(), 1, "The base is never changed.")
	assert_true((base_spell.effects[0] as DealDamageEffect).recipients is TargetSelection)


func test_overloading_reaches_a_target_inside_another_selection() -> void:
	var disarm: MmCardDefinition = Scenario.instant("Disarm", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.gain_life(3, Scenario.controller_of(Scenario.targeted(0)))])
	var run_card: MmRunCard = _run_card(disarm)
	run_card.modifications.append(OverloadModification.new())

	var gain: GainLifeEffect = (run_card.flatten().abilities[0] as SpellAbility).effects[0] as GainLifeEffect

	var controller: ControllerOfSelection = gain.players as ControllerOfSelection
	assert_true(controller.selection is OverloadedSelection)
	assert_true(controller.is_once_for_each, "\"Its controller\" is once for each object it was.")


func test_overloading_reaches_each_mode() -> void:
	var run_card: MmRunCard = _run_card(Scenario.free_charm("Charm"))
	run_card.modifications.append(OverloadModification.new())

	var spell: SpellAbility = run_card.flatten().abilities[0] as SpellAbility

	for mode: AbilityMode in spell.modes:
		assert_eq(mode.targets.size(), 0)
		assert_eq(mode.overloaded_targets.size(), 1)
	assert_true((spell.modes[1].effects[0] as DestroyEffect).selection is OverloadedSelection)


func test_overloading_leaves_a_granted_abilitys_own_targets() -> void:
	var ping: ActivatedAbility = Scenario.activated(Scenario.mana_cost(0), [TapCost.new()],
		[Scenario.deal_damage(1, Scenario.targeted(0))], [Scenario.any_target()])
	var gift: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.until_end_of_turn(Scenario.gain_abilities([ping], Scenario.targeted(0)))])
	var run_card: MmRunCard = _run_card(gift)
	run_card.modifications.append(OverloadModification.new())

	var created: CreateContinuousEffect = (run_card.flatten().abilities[0] as SpellAbility).effects[0] as CreateContinuousEffect

	var granted: GainAbilitiesContinuousEffect = created.continuous as GainAbilitiesContinuousEffect
	assert_true(granted.affected is OverloadedSelection)
	var granted_ability: ActivatedAbility = granted.abilities[0] as ActivatedAbility
	assert_eq(granted_ability.targets.size(), 1, "The granted ability's target is its own.")
	assert_true((granted_ability.effects[0] as DealDamageEffect).recipients is TargetSelection)


func test_overloading_leaves_an_adventure_alone() -> void:
	var guide: MmCardDefinition = Scenario.creature("Guide", 1, 1)
	guide.adventure = Scenario.free_shock("Gift", 2)
	var run_card: MmRunCard = _run_card(guide)
	run_card.modifications.append(OverloadModification.new())

	var adventure: MmCardDefinition = run_card.flatten().adventure

	assert_eq((adventure.abilities[0] as SpellAbility).targets.size(), 1)


func _run_card(definition: MmCardDefinition) -> MmRunCard:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = definition
	return run_card


func _cost(generic: int, symbols: Array[MmMana.Type]) -> MmManaCost:
	var cost: MmManaCost = MmManaCost.new()
	cost.generic = generic
	cost.symbols = symbols
	return cost


func _mana_cost(generic: int, symbols: Array[MmMana.Type]) -> AddManaCostModification:
	var modification: AddManaCostModification = AddManaCostModification.new()
	modification.cost = _cost(generic, symbols)
	return modification


func _power_toughness(power: int, toughness: int) -> AddPowerToughnessModification:
	var modification: AddPowerToughnessModification = AddPowerToughnessModification.new()
	modification.power = power
	modification.toughness = toughness
	return modification


func _ability(ability: MmAbility) -> AddAbilityModification:
	var modification: AddAbilityModification = AddAbilityModification.new()
	modification.ability = ability
	return modification
