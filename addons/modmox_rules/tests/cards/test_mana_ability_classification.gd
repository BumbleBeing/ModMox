extends GutTest
## CR 605.1a: an activated ability is a mana ability when it could add mana and has no
## target. It is worked out from the ability's content, never set by hand, so a
## Modification that adds a target turns it into an ordinary ability.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const TargetedTestEffect := preload("res://addons/modmox_rules/tests/support/targeted_test_effect.gd")


func test_an_ability_that_adds_mana_without_a_target_is_a_mana_ability() -> void:
	var ability: ActivatedAbility = Scenario.tap_for_mana(MmMana.Type.GREEN, 1)

	assert_true(ability.is_mana_ability())


func test_adding_a_target_makes_it_an_ordinary_activated_ability() -> void:
	var ability: ActivatedAbility = Scenario.tap_for_mana(MmMana.Type.GREEN, 1)

	ability.effects.append(TargetedTestEffect.new())

	assert_false(ability.is_mana_ability())


func test_an_ability_that_adds_no_mana_is_not_a_mana_ability() -> void:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]

	assert_false(ability.is_mana_ability())
