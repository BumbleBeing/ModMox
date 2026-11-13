extends GutTest
## ADR 0036: an Emblem's ability is activated from the command zone like a permanent's
## (CR 113.6, 602.2), an ability may be restricted to once each game (CR 602.5b) or to
## sorcery timing (CR 602.5d), and a Potion is a command-zone object whose one ability
## uses it up as a cost.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_an_emblem_ability_is_offered_only_when_its_mana_can_be_paid() -> void:
	var engine: MmEngine = MmEngine.start(_setup([_electromancers_boon()]))
	Scenario.play_until_step(engine, 1, Step.UPKEEP)
	var emblem: int = _emblem(engine, 0)

	assert_false(_offers(engine, emblem), "No land, so no {R}.")
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.play_first_land(engine)

	assert_true(_offers(engine, emblem))


func test_an_emblem_ability_uses_the_stack_and_deals_its_damage_to_a_player() -> void:
	var engine: MmEngine = _engine_ready([_electromancers_boon()])
	var villain: MmPlayer = engine.villain()

	assert_eq(Scenario.activate(engine, _emblem(engine, 0), [MmReference.to_player(villain.id)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1, "CR 602.2a: it waits on the stack.")
	assert_eq(villain.life, 20)
	assert_eq((engine.pending_decision() as PriorityDecision).player_id, engine.hero().id, "CR 117.3c")
	Scenario.resolve_stack(engine)
	assert_eq(villain.life, 17)


func test_an_emblem_ability_deals_its_damage_to_a_creature() -> void:
	var engine: MmEngine = _engine_ready([_electromancers_boon()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.activate(engine, _emblem(engine, 0), [MmReference.to_object(bear)])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Bear").size(), 0, "3 damage kills a 2/2.")


func test_a_once_each_game_ability_is_never_offered_again() -> void:
	var engine: MmEngine = _engine_ready([_electromancers_boon()])
	var emblem: int = _emblem(engine, 0)
	Scenario.activate(engine, emblem, [MmReference.to_player(engine.villain().id)])
	Scenario.resolve_stack(engine)

	Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN)

	assert_false(_offers(engine, emblem), "CR 602.5b: the land is untapped again, but the ability is spent.")
	assert_eq(engine.game_state().command.size(), 1, "The Emblem itself never leaves.")


func test_a_once_each_game_ability_is_spent_even_when_it_is_countered() -> void:
	var engine: MmEngine = _engine_ready([_electromancers_boon()])
	var hero: MmPlayer = engine.hero()
	var emblem: int = _emblem(engine, 0)
	Scenario.activate(engine, emblem, [MmReference.to_player(engine.villain().id)])

	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Stifle"), [MmReference.to_object(Scenario.stack_ids(engine)[0])])
	Scenario.resolve_stack(engine)
	Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN)

	assert_eq(engine.villain().life, 20, "It never resolved.")
	assert_false(_offers(engine, emblem))


func test_a_sorcery_speed_ability_is_offered_only_in_its_controllers_main_phase_with_an_empty_stack() -> void:
	var engine: MmEngine = MmEngine.start(_setup([_diviners_boon()]))
	var emblem: int = _emblem(engine, 0)
	Scenario.play_until_step(engine, 1, Step.UPKEEP)

	assert_false(_offers(engine, emblem), "Not in the upkeep.")
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	assert_true(_offers(engine, emblem))
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear"))
	assert_false(_offers(engine, emblem), "CR 602.5d: not with a spell on the stack.")
	Scenario.play_until_step(engine, 2, Step.PRECOMBAT_MAIN)
	Scenario.pass_priority(engine)
	assert_false(_offers(engine, emblem), "Not in the other player's turn.")


func test_the_sorcery_speed_ability_draws_its_cards() -> void:
	var engine: MmEngine = MmEngine.start(_setup([_diviners_boon()]))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var hand_size: int = engine.hero().hand.size()

	Scenario.activate(engine, _emblem(engine, 0))
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().hand.size(), hand_size + 2)


func test_two_emblems_with_the_same_ability_each_keep_their_own_use() -> void:
	var engine: MmEngine = MmEngine.start(_setup([_diviners_boon(), _diviners_boon()]))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	Scenario.activate(engine, _emblem(engine, 0))
	Scenario.resolve_stack(engine)

	assert_false(_offers(engine, _emblem(engine, 0)))
	assert_true(_offers(engine, _emblem(engine, 1)))


func test_an_emblem_ability_without_the_restriction_can_be_activated_again() -> void:
	var engine: MmEngine = MmEngine.start(_setup([Scenario.emblem("Font of Life", [_free_ability([Scenario.gain_life(1, Scenario.you())])])]))
	Scenario.play_until_step(engine, 1, Step.UPKEEP)
	var emblem: int = _emblem(engine, 0)

	Scenario.activate(engine, emblem)
	Scenario.resolve_stack(engine)
	Scenario.activate(engine, emblem)
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 22)
	assert_true(_offers(engine, emblem))


func test_the_view_marks_a_spent_ability_for_both_players() -> void:
	var engine: MmEngine = MmEngine.start(_setup([_diviners_boon()]))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	assert_eq(engine.view_for(engine.hero()).command[0].spent_ability_indexes, [] as Array[int])

	Scenario.activate(engine, _emblem(engine, 0))

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		assert_eq(engine.view_for(viewer).command[0].spent_ability_indexes, [0] as Array[int])


func test_a_potion_is_offered_with_a_creature_to_target_and_costs_no_mana() -> void:
	var engine: MmEngine = MmEngine.start(_setup([], [_big_gulp()]))
	Scenario.play_until_step(engine, 1, Step.UPKEEP)
	var potion: int = _potion(engine, 0)

	assert_false(_offers(engine, potion), "CR 602.2b: there is no creature to target.")
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(engine, "Bear")

	assert_true(_offers(engine, potion), "No land was played: it costs no mana.")


func test_a_potion_can_be_used_in_the_other_players_turn() -> void:
	var engine: MmEngine = _engine_ready([], [_big_gulp()])

	Scenario.play_until_step(engine, 2, Step.UPKEEP)
	Scenario.pass_priority(engine)

	assert_eq((engine.pending_decision() as PriorityDecision).player_id, engine.hero().id)
	assert_true(_offers(engine, _potion(engine, 0)))


func test_using_a_potion_removes_it_at_once_and_its_ability_resolves_later() -> void:
	var engine: MmEngine = _engine_ready([], [_big_gulp()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var potion: int = _potion(engine, 0)

	assert_eq(Scenario.activate(engine, potion, [MmReference.to_object(bear)]), "")

	assert_null(engine.game_state().object(potion), "Paying the cost used it up.")
	assert_eq(engine.game_state().command.size(), 0)
	assert_eq(Scenario.pt(engine, bear), [2, 2] as Array[int], "The ability is still on the stack.")
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.pt(engine, bear), [4, 4] as Array[int])
	Scenario.play_until_step(engine, 2, Step.UPKEEP)
	assert_eq(Scenario.pt(engine, bear), [2, 2] as Array[int], "Until end of turn.")


func test_a_potions_ability_on_the_stack_says_which_potion_it_came_from() -> void:
	var engine: MmEngine = _engine_ready([_electromancers_boon()], [_big_gulp(), _big_gulp()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.activate(engine, _potion(engine, 1), [MmReference.to_object(bear)])
	Scenario.activate(engine, _emblem(engine, 0), [MmReference.to_player(engine.villain().id)])

	var stack: Array[MmObjectView] = engine.view_for(engine.villain()).stack
	assert_eq(stack[0].source_potion_index, 1, "The Potion is gone, so its ability remembers.")
	assert_eq(stack[0].name, "Big Gulp ability")
	assert_eq(stack[1].source_potion_index, MmGameObject.NOT_A_POTION, "An Emblem's ability.")


func test_a_potion_whose_ability_is_countered_is_still_gone() -> void:
	var engine: MmEngine = _engine_ready([], [_big_gulp()])
	var hero: MmPlayer = engine.hero()
	var bear: int = Scenario.permanent_named(engine, hero.id, "Bear")
	Scenario.activate(engine, _potion(engine, 0), [MmReference.to_object(bear)])

	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Stifle"), [MmReference.to_object(Scenario.stack_ids(engine)[0])])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.pt(engine, bear), [2, 2] as Array[int])
	assert_eq(engine.view_for(hero).potions.size(), 0)


func test_the_view_lists_potions_apart_from_emblems_for_both_players() -> void:
	var engine: MmEngine = MmEngine.start(_setup([_diviners_boon()], [_big_gulp()]))

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		assert_eq(view.command.size(), 1)
		assert_eq(view.command[0].name, "Diviner's Boon")
		assert_eq(view.potions.size(), 1)
		assert_eq(view.potions[0].name, "Big Gulp")
		assert_eq(view.potions[0].owner_id, engine.hero().id)
		assert_eq(view.potions[0].potion_index, 0)
		assert_eq(view.command[0].potion_index, MmGameObject.NOT_A_POTION)


func test_the_engine_reports_which_potions_were_used() -> void:
	var engine: MmEngine = _engine_ready([], [_big_gulp(), _big_gulp()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(engine.used_potion_indexes(engine.hero()), [] as Array[int])

	Scenario.activate(engine, _potion(engine, 1), [MmReference.to_object(bear)])
	Scenario.resolve_stack(engine)

	assert_eq(engine.used_potion_indexes(engine.hero()), [1] as Array[int], "By its place in the setup's list.")
	assert_eq(engine.used_potion_indexes(engine.villain()), [] as Array[int])
	assert_eq(engine.view_for(engine.hero()).potions.size(), 1)


func test_a_potion_cannot_be_targeted() -> void:
	var engine: MmEngine = MmEngine.start(_setup([], [_big_gulp()]))
	var potion: int = _potion(engine, 0)

	var legal: Array[MmReference] = Scenario.any_target().legal_targets(engine.game_state(), MmEffectContext.new(engine.villain().id, 0))

	for candidate: MmReference in legal:
		assert_false(candidate.is_object() and candidate.id == potion)


func test_undoing_an_activation_restores_the_use_and_the_potion() -> void:
	var engine: MmEngine = _engine_ready([_electromancers_boon()], [_big_gulp()])
	var before: String = engine.fingerprint()
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.activate(engine, _potion(engine, 0), [MmReference.to_object(bear)])
	Scenario.activate(engine, _emblem(engine, 0), [MmReference.to_player(engine.villain().id)])

	while engine.fingerprint() != before and engine.can_undo():
		engine.undo()

	assert_eq(engine.fingerprint(), before)
	assert_eq(engine.view_for(engine.hero()).potions.size(), 1)
	assert_true(_offers(engine, _emblem(engine, 0)))
	assert_eq(engine.used_potion_indexes(engine.hero()), [] as Array[int])


func test_a_replay_reaches_the_same_state_with_the_use_and_the_potion_gone() -> void:
	var setup: MmEncounterSetup = _setup([_electromancers_boon()], [_big_gulp()])
	var engine: MmEngine = _engine_ready_from(setup)
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.activate(engine, _potion(engine, 0), [MmReference.to_object(bear)])
	Scenario.activate(engine, _emblem(engine, 0), [MmReference.to_player(engine.villain().id)])
	Scenario.resolve_stack(engine)

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_eq(replayed.view_for(replayed.hero()).potions.size(), 0)
	assert_eq(replayed.view_for(replayed.hero()).command[0].spent_ability_indexes, [0] as Array[int])


func test_a_spent_ability_changes_the_fingerprint() -> void:
	var engine: MmEngine = MmEngine.start(_setup([Scenario.emblem("Spark", [_once(_free_ability([Scenario.gain_life(1, Scenario.you())]))])]))
	Scenario.play_until_step(engine, 1, Step.UPKEEP)
	var other: MmEngine = MmEngine.start(_setup([Scenario.emblem("Spark", [_free_ability([Scenario.gain_life(1, Scenario.you())])])]))
	Scenario.play_until_step(other, 1, Step.UPKEEP)
	assert_eq(engine.fingerprint(), other.fingerprint(), "The restriction itself is card data, not state.")

	for running: MmEngine in [engine, other]:
		Scenario.activate(running, _emblem(running, 0))
		Scenario.resolve_stack(running)

	assert_ne(engine.fingerprint(), other.fingerprint())


func test_a_setup_with_a_missing_potion_is_refused() -> void:
	var setup: MmEncounterSetup = _setup([], [null])

	assert_eq(setup.hero.validate(), "Potion 0 has no Card Definition.")


# --- helpers ---------------------------------------------------------------------------


## The Hero's deck cycles Mountain, a free 2/2 Bear and a free Stifle; the Villain's is
## vanilla cards.
func _setup(emblems: Array[MmCardDefinition], potions: Array[MmCardDefinition] = []) -> MmEncounterSetup:
	var hero_cards: Array[MmCardDefinition] = Scenario.cycled([
		Scenario.mana_land("Mountain", MmMana.Type.RED, 1), Scenario.creature("Bear", 2, 2), Scenario.free_stifle("Stifle")])
	var setup: MmEncounterSetup = Scenario.setup_with(hero_cards, Scenario.cycled([]))
	setup.hero.emblems = emblems
	setup.hero.potions = potions
	return setup


## In the Hero's first main phase with a Mountain and a Bear on the battlefield and a
## Stifle in hand.
func _engine_ready(emblems: Array[MmCardDefinition], potions: Array[MmCardDefinition] = []) -> MmEngine:
	return _engine_ready_from(_setup(emblems, potions))


func _engine_ready_from(setup: MmEncounterSetup) -> MmEngine:
	return Scenario.find_engine(setup, func(engine: MmEngine) -> bool:
		if Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.play_first_land(engine) == -1 or Scenario.cast_and_resolve(engine, "Bear") != "":
			return false
		return Scenario.card_in_hand(engine, engine.hero(), "Stifle") != -1)


## "{R}: This emblem deals 3 damage to any target. Activate only once each game."
func _electromancers_boon() -> MmCardDefinition:
	var ability: ActivatedAbility = _once(_free_ability([Scenario.deal_damage(3, Scenario.targeted(0))]))
	ability.mana_cost = Scenario.mana_cost(0, [MmMana.Type.RED])
	ability.targets = [Scenario.any_target()]
	return Scenario.emblem("Electromancer's Boon", [ability])


## "{0}: Draw two cards. Activate only as a sorcery and only once each game." The real
## one costs {2}{U}; the cost is tested on Electromancer's Boon.
func _diviners_boon() -> MmCardDefinition:
	var ability: ActivatedAbility = _once(_free_ability([Scenario.draw_cards(2, Scenario.you())]))
	ability.is_sorcery_speed = true
	return Scenario.emblem("Diviner's Boon", [ability])


## A Potion: "Target creature gets +2/+2 until end of turn."
func _big_gulp() -> MmCardDefinition:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [UseUpCost.new()]
	ability.targets = [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))]
	ability.effects = [Scenario.until_end_of_turn(Scenario.modify_pt(2, 2, Scenario.targeted(0)))]
	return Scenario.emblem("Big Gulp", [ability])


func _free_ability(effects: Array[MmEffect]) -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = Scenario.mana_cost(0)
	ability.effects = effects
	return ability


func _once(ability: ActivatedAbility) -> ActivatedAbility:
	ability.is_once_each_game = true
	return ability


## The object ID of the Hero's Emblem number [param index] in the command zone.
func _emblem(engine: MmEngine, index: int) -> int:
	return engine.view_for(engine.hero()).command[index].id


func _potion(engine: MmEngine, index: int) -> int:
	return engine.view_for(engine.hero()).potions[index].id


func _offers(engine: MmEngine, object_id: int) -> bool:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	return decision != null and Scenario.activate_index(decision, object_id) != -1


# --- An Emblem's mana ability (ADR 0036, CR 605) ------------------------------------------


func test_an_emblems_mana_ability_pays_a_cost_and_a_once_each_game_one_is_then_spent() -> void:
	var engine: MmEngine = _font_engine()
	var font: int = _emblem(engine, 0)
	var first: int = Scenario.card_in_hand(engine, engine.hero(), "Zap")
	assert_true(Scenario.offers_cast(engine, first), "CR 605.3a: the Font's mana can pay {R}, with no land.")

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, first))
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))
	assert_eq(Scenario.pay_by_tapping(engine, font, 0), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().life, 19)
	assert_eq(engine.view_for(engine.hero()).command[0].spent_ability_indexes, [0] as Array[int], "CR 602.5b")
	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Zap")), "The Font is spent.")
	assert_false(_offers(engine, font))


func test_an_emblems_mana_ability_resolves_at_once_when_activated_with_priority() -> void:
	var engine: MmEngine = _font_engine()
	var font: int = _emblem(engine, 0)

	assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, font)), "")

	assert_eq(engine.game_state().stack.size(), 0, "CR 605.3b: a mana ability never uses the stack.")
	assert_eq(engine.hero().mana_pool().size(), 1)
	assert_false(_offers(engine, font))


## The Hero in their first main phase with "Add {R}. Activate only once each game." on an
## Emblem, no land, and Zaps ("{R}: 1 damage to any target") in hand.
func _font_engine() -> MmEngine:
	var font: ActivatedAbility = _once(ActivatedAbility.new())
	font.effects = [Scenario.add_mana(MmMana.Type.RED, 1)]
	var zap: MmCardDefinition = Scenario.instant("Zap", Scenario.mana_cost(0, [MmMana.Type.RED]), [Scenario.any_target()],
		[Scenario.deal_damage(1, Scenario.targeted(0))])
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled([zap]), Scenario.cycled([]))
	setup.hero.emblems = [Scenario.emblem("Font", [font])] as Array[MmCardDefinition]
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	return engine
