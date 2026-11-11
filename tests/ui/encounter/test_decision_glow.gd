extends GutTest
## The Glow marks exactly what a Pending Decision can choose: targets orange-red, mana
## sources blue, everything else green.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const LAND_ID: int = 5


func test_no_decision_glows_nothing() -> void:
	var glow: DecisionGlow = DecisionGlow.of(null, _view())

	assert_eq(glow.objects.size(), 0)
	assert_eq(glow.players.size(), 0)


func test_priority_glows_what_can_be_played_green_and_mana_sources_blue() -> void:
	var decision: PriorityDecision = PriorityDecision.new(HERO, [
		PassAction.new(), PlayLandAction.new(7), CastSpellAction.new(8), ActivateAbilityAction.new(LAND_ID, 0),
	] as Array[MmAction])

	var glow: DecisionGlow = DecisionGlow.of(decision, _view())

	assert_eq(glow.objects, {7: DecisionGlow.Kind.OTHER, 8: DecisionGlow.Kind.OTHER, LAND_ID: DecisionGlow.Kind.MANA})
	assert_eq(glow.players.size(), 0)


func test_targets_glow_orange_red_on_objects_and_players_alike() -> void:
	var decision: ChooseTargetDecision = ChooseTargetDecision.new(HERO, 20, 0,
		[MmReference.to_player(VILLAIN), MmReference.to_object(11)] as Array[MmReference])

	var glow: DecisionGlow = DecisionGlow.of(decision, _view())

	assert_eq(glow.objects, {11: DecisionGlow.Kind.TARGET})
	assert_eq(glow.players, {VILLAIN: DecisionGlow.Kind.TARGET})


func test_paying_mana_glows_sources_blue_and_maps_each_pool_color_to_its_first_unit() -> void:
	var view: MmPlayerView = _view()
	view.mana_pools[HERO] = [MmMana.new(MmMana.Type.RED, 1), MmMana.new(MmMana.Type.GREEN, 1), MmMana.new(MmMana.Type.RED, 1)]
	var decision: PayManaDecision = PayManaDecision.new(HERO, [
		PayWithManaAction.new(0), PayWithManaAction.new(1), PayWithManaAction.new(2), ActivateAbilityAction.new(LAND_ID, 0),
	] as Array[MmAction], 1, [] as Array[MmMana.Type])

	var glow: DecisionGlow = DecisionGlow.of(decision, view)

	assert_eq(glow.objects, {LAND_ID: DecisionGlow.Kind.MANA})
	assert_eq(glow.pool_answers, {MmMana.Type.RED: 0, MmMana.Type.GREEN: 1}, "The answer that spends one unit of each color.")


func test_attackers_blockers_and_cards_to_choose_glow_green() -> void:
	var attackers: DecisionGlow = DecisionGlow.of(DeclareAttackersDecision.new(HERO, [3, 4] as Array[int]), _view())
	var blockers: DecisionGlow = DecisionGlow.of(DeclareBlockersDecision.new(HERO, [3] as Array[int], [9] as Array[int],
		{3: [9]} as Dictionary[int, Array], {3: 1} as Dictionary[int, int]), _view())
	var discard: DecisionGlow = DecisionGlow.of(ChooseCardsToDiscardDecision.new(HERO, 1, [1, 2] as Array[int]), _view())
	var bottom: DecisionGlow = DecisionGlow.of(ChooseCardsToBottomDecision.new(HERO, 1, [1, 2] as Array[int]), _view())

	assert_eq(attackers.objects, {3: DecisionGlow.Kind.OTHER, 4: DecisionGlow.Kind.OTHER})
	assert_eq(blockers.objects, {3: DecisionGlow.Kind.OTHER}, "The blockers to choose, not the attackers.")
	assert_eq(discard.objects.keys(), [1, 2])
	assert_eq(bottom.objects.keys(), [1, 2])


func test_dividing_damage_glows_its_recipients_as_targets() -> void:
	var decision: DivideCombatDamageDecision = DivideCombatDamageDecision.new(HERO, 3, 4,
		[MmReference.to_object(9), MmReference.to_player(VILLAIN)] as Array[MmReference], [2] as Array[int])

	var glow: DecisionGlow = DecisionGlow.of(decision, _view())

	assert_eq(glow.objects, {9: DecisionGlow.Kind.TARGET})
	assert_eq(glow.players, {VILLAIN: DecisionGlow.Kind.TARGET})


func test_each_kind_has_its_own_color() -> void:
	assert_eq(DecisionGlow.color_of(DecisionGlow.Kind.TARGET), Color("#ff5a2a"))
	assert_eq(DecisionGlow.color_of(DecisionGlow.Kind.MANA), Color("#3aa0ff"))
	assert_ne(DecisionGlow.color_of(DecisionGlow.Kind.OTHER), DecisionGlow.color_of(DecisionGlow.Kind.MANA))


func _view() -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var land: MmObjectView = MmObjectView.new()
	land.id = LAND_ID
	land.abilities = [Scenario.tap_for_mana(MmMana.Type.GREEN, 1)]
	view.battlefield = [land]
	return view
