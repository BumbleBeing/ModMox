extends GutTest
## Equipment (CR 301.5) and attaching (CR 701.3): equip attaches an Equipment to a creature
## its controller controls, only as a sorcery (CR 702.6), and "equipped creature" is
## whatever it is attached to. An Equipment attached to something that is gone, is no longer
## a creature or has protection from it becomes unattached and stays on the battlefield
## (CR 704.5n, 702.16d).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_equip_attaches_the_equipment_and_the_equipped_creature_gets_its_bonus() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword")], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")

	assert_eq(Scenario.equip_and_resolve(engine, sword, bear), "")

	assert_eq(Scenario.attached_to(engine, sword), bear)
	assert_eq(Scenario.pt(engine, bear), [3, 3])
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sword"), [sword], "CR 701.3: it does not change zones.")
	var attached: Array[MmEvent] = Scenario.events_of(engine, AttachedEvent)
	assert_eq(attached.size(), 1)
	assert_eq([(attached[0] as AttachedEvent).object_id, (attached[0] as AttachedEvent).to_object_id], [sword, bear])


func test_an_equipment_attached_to_nothing_gives_nothing() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword")], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")

	assert_eq(Scenario.attached_to(engine, sword), 0)
	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_equip_costs_its_mana() -> void:
	var rock: MmCardDefinition = Scenario.artifact("Rock", [Scenario.tap_for_mana(MmMana.Type.COLORLESS, 1)])
	var engine: MmEngine = _hero_main([_bear(), rock, Scenario.sword("Sword", 1, Scenario.mana_cost(1))], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	var rock_id: int = Scenario.permanent_named(engine, engine.hero().id, "Rock")

	assert_eq(Scenario.equip_and_resolve(engine, sword, bear), "")

	assert_true(engine.game_state().object(rock_id).is_tapped)
	assert_eq(Scenario.attached_to(engine, sword), bear)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1,
		"With no mana left, equip is not offered.")


func test_equip_is_offered_only_as_a_sorcery() -> void:
	# CR 702.6a: "Activate only as a sorcery."
	var engine: MmEngine = Scenario.combat_ready([_bear(), Scenario.sword("Sword")], [])
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")

	Scenario.declare_attackers(engine, [])

	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.pending_decision() is PriorityDecision and running.game_state().step != Step.PRECOMBAT_MAIN)
	assert_ne(engine.game_state().step, Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1)
	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.pending_decision() is PriorityDecision and running.game_state().step == Step.POSTCOMBAT_MAIN)
	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1, "Its controller's main phase.")


func test_with_instant_speed_equip_equip_is_offered_and_resolves_outside_the_main_phase() -> void:
	# Leonin Shikari: "You may activate equip abilities any time you could cast an instant."
	var engine: MmEngine = Scenario.combat_ready([_bear(), _shikari(), Scenario.sword("Sword")], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.declare_attackers(engine, [])

	_pass_to_hero_priority_outside_the_main_phase(engine)

	assert_eq(Scenario.equip_and_resolve(engine, sword, bear), "")
	assert_eq(Scenario.attached_to(engine, sword), bear)


func test_with_instant_speed_equip_equip_is_offered_in_the_other_players_turn() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear(), _shikari(), Scenario.sword("Sword")], [])
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.declare_attackers(engine, [])

	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		var decision: PriorityDecision = running.pending_decision() as PriorityDecision
		return decision != null and decision.player_id == running.hero().id \
			and running.game_state().active_player_id != running.hero().id)

	assert_eq(engine.game_state().step, Step.UPKEEP)
	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1)


func test_with_instant_speed_equip_equip_is_offered_with_a_spell_on_the_stack() -> void:
	var gift: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var engine: MmEngine = _hero_main([_bear(), _shikari(), Scenario.sword("Sword")], [], [gift])
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1)
	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1)


func test_the_other_players_instant_speed_equip_does_not_lift_your_equips_restriction() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear(), Scenario.sword("Sword")], [_shikari()])
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.declare_attackers(engine, [])

	_pass_to_hero_priority_outside_the_main_phase(engine)

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1, "It says \"you\".")


func test_instant_speed_equip_lifts_only_an_equip_abilitys_restriction() -> void:
	var slow: ActivatedAbility = ActivatedAbility.new()
	slow.effects = [Scenario.gain_life(1, Scenario.you())]
	slow.is_sorcery_speed = true
	var engine: MmEngine = Scenario.combat_ready([_bear(), _shikari(), Scenario.artifact("Idol", [slow])], [])
	var idol: int = Scenario.permanent_named(engine, engine.hero().id, "Idol")
	Scenario.declare_attackers(engine, [])

	_pass_to_hero_priority_outside_the_main_phase(engine)

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, idol), -1)


func test_equip_is_a_sorcery_again_once_the_instant_speed_equip_is_gone() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear(), _shikari(), Scenario.sword("Sword")], [], [Scenario.free_destroy("Murder")])
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	var shikari: int = Scenario.permanent_named(engine, engine.hero().id, "Shikari")
	Scenario.declare_attackers(engine, [])
	_pass_to_hero_priority_outside_the_main_phase(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Murder", [_object(shikari)]), "")

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Shikari").size(), 0)
	assert_ne(engine.game_state().step, Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1)


func test_instant_speed_equip_works_from_an_emblem() -> void:
	var hero_permanents: Array[MmCardDefinition] = [_bear(), Scenario.sword("Sword")]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards)
	setup.hero.emblems = [Scenario.emblem("Armory", [Scenario.instant_speed_equip()])]
	var engine: MmEngine = Scenario.combat_ready_with(setup, hero_permanents, no_cards)
	assert_not_null(engine, "No seed gave the needed hands.")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.declare_attackers(engine, [])

	_pass_to_hero_priority_outside_the_main_phase(engine)

	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1)


func test_a_creature_that_loses_instant_speed_equip_no_longer_lifts_the_restriction() -> void:
	# CR 613.1f: the permission is read from its characteristics.
	var hush: MmCardDefinition = Scenario.artifact("Hush", [Scenario.continuous_static(
		[Scenario.lose_all_abilities(Scenario.each_creature())])])
	var engine: MmEngine = Scenario.combat_ready([_bear(), _shikari(), Scenario.sword("Sword")], [hush])
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.declare_attackers(engine, [])

	_pass_to_hero_priority_outside_the_main_phase(engine)

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1)


func test_equip_targets_only_a_creature_its_controller_controls() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword"), Scenario.artifact("Rock", [])], [_ogre()], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_eq(engine.submit(Scenario.activate_index(decision, sword)), "")

	var choice: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(choice)
	var ids: Array[int] = []
	for candidate: MmReference in choice.candidates:
		ids.append(candidate.id if candidate.is_object() else -1)
	assert_eq(ids, [bear], "Not a player, the other player's Ogre, the Rock or the Sword itself.")


func test_equipping_another_creature_moves_the_equipment() -> void:
	var engine: MmEngine = _hero_main([_bear(), _wolf(), Scenario.sword("Sword")], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var wolf: int = Scenario.permanent_named(engine, engine.hero().id, "Wolf")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)

	assert_eq(Scenario.equip_and_resolve(engine, sword, wolf), "")

	assert_eq(Scenario.attached_to(engine, sword), wolf)
	assert_eq(Scenario.pt(engine, bear), [2, 2])
	assert_eq(Scenario.pt(engine, wolf), [4, 4])


func test_two_equipment_on_one_creature_both_count() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword"), Scenario.sword("Axe", 2)], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), bear)
	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Axe"), bear)

	assert_eq(Scenario.pt(engine, bear), [5, 5])


func test_equipping_the_creature_it_is_already_on_changes_nothing() -> void:
	# CR 701.3b: attaching an object to what it is already attached to does nothing.
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword")], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)

	assert_eq(Scenario.equip_and_resolve(engine, sword, bear), "")

	assert_eq(Scenario.attached_to(engine, sword), bear)
	assert_eq(Scenario.events_of(engine, AttachedEvent).size(), 1)
	assert_eq(Scenario.events_of(engine, UnattachedEvent).size(), 0)


func test_when_the_equipped_creature_dies_the_equipment_stays_unattached() -> void:
	# CR 704.5n.
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword")], [], [Scenario.free_destroy("Murder")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)

	Scenario.cast_and_resolve(engine, "Murder", [_object(bear)])

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Bear").size(), 0)
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sword"), [sword])
	assert_eq(Scenario.attached_to(engine, sword), 0)
	var unattached: Array[MmEvent] = Scenario.events_of(engine, UnattachedEvent)
	assert_eq(unattached.size(), 1)
	assert_eq((unattached[0] as UnattachedEvent).object_id, sword)


func test_when_the_equipment_is_destroyed_the_creature_loses_its_bonus() -> void:
	var smash: MmCardDefinition = Scenario.instant("Smash", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(CardType.ARTIFACT))], [Scenario.destroy(Scenario.targeted(0))])
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword")], [], [smash])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)

	Scenario.cast_and_resolve(engine, "Smash", [_object(sword)])

	assert_eq(Scenario.pt(engine, bear), [2, 2])
	var in_graveyard: int = Scenario.card_in_graveyard(engine, engine.hero(), "Sword")
	assert_eq(Scenario.attached_to(engine, in_graveyard), 0, "ADR 0008: a new object, attached to nothing.")


func test_a_creature_that_leaves_and_returns_is_no_longer_equipped() -> void:
	# ADR 0008, CR 400.7: the creature that comes back is a new object.
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword")], [], [Scenario.free_bounce("Bounce")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)

	Scenario.cast_and_resolve(engine, "Bounce", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Bear")

	var returned: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_ne(returned, bear)
	assert_eq(Scenario.pt(engine, returned), [2, 2])
	assert_eq(Scenario.attached_to(engine, sword), 0)


func test_equip_does_nothing_when_its_target_is_gone_and_the_equipment_stays_where_it_was() -> void:
	# CR 608.2b: an ability whose only target is illegal does not resolve.
	var engine: MmEngine = _hero_main([_bear(), _wolf(), Scenario.sword("Sword")], [], [Scenario.free_destroy("Murder")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var wolf: int = Scenario.permanent_named(engine, engine.hero().id, "Wolf")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)
	assert_eq(Scenario.activate(engine, sword, [_object(wolf)]), "")

	var murder: int = Scenario.card_in_hand(engine, engine.hero(), "Murder")
	assert_eq(Scenario.cast(engine, murder, [_object(wolf)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.attached_to(engine, sword), bear)
	assert_eq(Scenario.pt(engine, bear), [3, 3])


func test_a_creature_with_protection_from_artifacts_cannot_be_equipped() -> void:
	# CR 702.16b: equip targets, so the protected creature is not a legal target.
	var warded: MmCardDefinition = Scenario.creature("Warded", 2, 2,
		[Scenario.protection_from(Scenario.of_type(CardType.ARTIFACT))])
	var engine: MmEngine = _hero_main([warded, Scenario.sword("Sword")], [], [])
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1)


func test_an_equipped_creature_that_gains_protection_from_artifacts_drops_the_equipment() -> void:
	# CR 702.16d, 704.5n.
	var ward: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Ward", Scenario.gain_abilities(
		[Scenario.protection_from(Scenario.of_type(CardType.ARTIFACT))], Scenario.targeted(0)))
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword")], [], [ward])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)

	Scenario.cast_and_resolve(engine, "Ward", [_object(bear)])

	assert_eq(Scenario.attached_to(engine, sword), 0)
	assert_eq(Scenario.pt(engine, bear), [2, 2])
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sword"), [sword])


func test_both_players_see_what_an_equipment_is_attached_to() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword")], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")

	Scenario.equip_and_resolve(engine, sword, bear)

	for player: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(player)
		assert_eq(_seen(view, sword).attached_to_object_id, bear)
		assert_eq(_seen(view, bear).attached_to_object_id, 0)
		assert_eq(_seen(view, bear).power, 3)


func test_a_copy_of_the_state_keeps_the_attachment_and_replays_are_exact() -> void:
	var hero_cards: Array[MmCardDefinition] = [_bear(), Scenario.sword("Sword")]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, no_cards)
	var original: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, no_cards, no_cards, no_cards, 3, Step.PRECOMBAT_MAIN)
	var bear: int = Scenario.permanent_named(original, original.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(original, original.hero().id, "Sword")
	var before: String = original.fingerprint()
	Scenario.equip_and_resolve(original, sword, bear)

	var copy: MmGameState = original.game_state().duplicate_state()

	assert_ne(original.fingerprint(), before)
	assert_eq(copy.fingerprint(), original.game_state().fingerprint())
	assert_eq(copy.object(sword).attached_to_object_id, bear)
	assert_eq(copy.characteristics_of(copy.object(bear)).power, 3)
	Scenario.play_until_game_turn(original, 5)
	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())
	assert_eq(replayed.fingerprint(), original.fingerprint())


func test_two_states_that_differ_only_in_an_attachment_have_different_fingerprints() -> void:
	var equipped: MmEngine = _hero_main([_bear(), Scenario.sword("Sword", 0)], [], [])
	var loose: MmEngine = _hero_main([_bear(), Scenario.sword("Sword", 0)], [], [])
	assert_eq(equipped.fingerprint(), loose.fingerprint())

	Scenario.equip_and_resolve(equipped, Scenario.permanent_named(equipped, equipped.hero().id, "Sword"),
		Scenario.permanent_named(equipped, equipped.hero().id, "Bear"))
	Scenario.resolve_stack(loose)

	assert_ne(equipped.fingerprint(), loose.fingerprint())


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _wolf() -> MmCardDefinition:
	return Scenario.creature("Wolf", 3, 3)


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 4, 4)


## Leonin Shikari: a 2/2 with "You may activate equip abilities any time you could cast an
## instant."
func _shikari() -> MmCardDefinition:
	return Scenario.creature("Shikari", 2, 2, [Scenario.instant_speed_equip()])


## Passes on from where the Hero has declared no attackers to their next priority that is
## not in a main phase.
func _pass_to_hero_priority_outside_the_main_phase(engine: MmEngine) -> void:
	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		var decision: PriorityDecision = running.pending_decision() as PriorityDecision
		return decision != null and decision.player_id == running.hero().id \
			and not running.game_state().step in [Step.PRECOMBAT_MAIN, Step.POSTCOMBAT_MAIN])
	assert_ne(engine.game_state().step, Step.PRECOMBAT_MAIN)


func _seen(view: MmPlayerView, object_id: int) -> MmObjectView:
	for seen: MmObjectView in view.battlefield:
		if seen.id == object_id:
			return seen
	return null


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
