extends GutTest
## What the Emblems and Potions buttons say (ADR 0032, A526): glowing while something
## could be used now, their own color while anything is left, and gray otherwise.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const Look := HeldState.Look


func test_no_emblems_is_gray() -> void:
	assert_eq(HeldState.emblems_look([], DecisionClicks.new()), Look.GRAY)


func test_an_emblem_with_a_static_ability_is_never_used_up() -> void:
	var winds: MmObjectView = _held(1, [FlyingAbility.new()])

	assert_false(HeldState.is_used_up(winds))
	assert_eq(HeldState.emblems_look([winds], DecisionClicks.new()), Look.PLAIN)


func test_an_emblem_with_no_abilities_is_not_used_up() -> void:
	assert_false(HeldState.is_used_up(_held(1, [])))


func test_an_emblem_whose_only_ability_is_spent_is_used_up_and_the_button_goes_gray() -> void:
	var boon: MmObjectView = _held(1, [_once()])
	assert_false(HeldState.is_used_up(boon))
	assert_eq(HeldState.emblems_look([boon], DecisionClicks.new()), Look.PLAIN)

	boon.spent_ability_indexes = [0]

	assert_true(HeldState.is_used_up(boon))
	assert_eq(HeldState.emblems_look([boon], DecisionClicks.new()), Look.GRAY, "Every Emblem is used up (A520).")


func test_one_emblem_left_keeps_the_button_its_color() -> void:
	var spent: MmObjectView = _held(1, [_once()])
	spent.spent_ability_indexes = [0]

	assert_eq(HeldState.emblems_look([spent, _held(2, [_once()])], DecisionClicks.new()), Look.PLAIN)
	assert_eq(HeldState.emblems_look([spent, _held(3, [FlyingAbility.new()])], DecisionClicks.new()), Look.PLAIN)


func test_an_ability_that_can_be_activated_again_is_never_used_up() -> void:
	var font: MmObjectView = _held(1, [Scenario.regenerate_ability(Scenario.mana_cost(0))])
	font.spent_ability_indexes = [0]

	assert_false(HeldState.is_used_up(font))


func test_an_emblem_with_a_spent_ability_and_another_is_not_used_up() -> void:
	var both: MmObjectView = _held(1, [_once(), _once()])
	both.spent_ability_indexes = [1]

	assert_false(HeldState.is_used_up(both))


func test_the_button_glows_while_an_emblem_answers_a_click() -> void:
	var boon: MmObjectView = _held(7, [_once()])
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	view.command = [boon]
	var clicks: DecisionClicks = DecisionClicks.of(PriorityDecision.new(HERO,
		[PassAction.new(), ActivateAbilityAction.new(7, 0)] as Array[MmAction]), view)

	assert_true(HeldState.is_usable(boon, clicks))
	assert_eq(HeldState.emblems_look([boon], clicks), Look.GLOWING)
	assert_false(HeldState.is_usable(boon, DecisionClicks.new()))


func test_the_potions_button_is_gray_with_none_plain_with_any_and_glows_with_one_to_use() -> void:
	var potion: MmObjectView = _held(9, [_once()])
	potion.potion_index = 0
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	view.potions = [potion]
	var clicks: DecisionClicks = DecisionClicks.of(PriorityDecision.new(HERO,
		[PassAction.new(), ActivateAbilityAction.new(9, 0)] as Array[MmAction]), view)

	assert_eq(HeldState.potions_look([], DecisionClicks.new()), Look.GRAY)
	assert_eq(HeldState.potions_look([potion], DecisionClicks.new()), Look.PLAIN)
	assert_eq(HeldState.potions_look([potion], clicks), Look.GLOWING)


func _held(id: int, abilities: Array[MmAbility]) -> MmObjectView:
	var held: MmObjectView = MmObjectView.new()
	held.id = id
	held.controller_id = HERO
	held.abilities = abilities
	return held


func _once() -> ActivatedAbility:
	var ability: ActivatedAbility = Scenario.regenerate_ability(Scenario.mana_cost(0))
	ability.is_once_each_game = true
	return ability
