extends GutTest
## Assemble the Players (ADR 0054): "You may look at the top card of your library any
## time. Once each turn, you may cast a creature spell with power 2 or less from the top of
## your library." Lookout is an enchantment costing {0} with both abilities. Cub is a 2/2
## costing {0}, Brute a 3/3 costing {0}, and Kit a 1/1 costing {W} that an Elf pays for.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_with_a_lookout_you_see_your_top_card_and_nobody_else_does() -> void:
	var engine: MmEngine = _hero_main([Scenario.lookout(), _cub()], ["Cub"])
	var hero: MmPlayer = engine.hero()

	var mine: MmPlayerView = engine.view_for(hero)
	var theirs: MmPlayerView = engine.view_for(engine.villain())

	assert_true(mine.looks_at_library_top)
	var top: MmObjectView = mine.libraries[hero.id][0] as MmObjectView
	assert_not_null(top)
	assert_eq(top.id, hero.library.top().id)
	assert_eq(top.name, "Cub")
	assert_eq(mine.libraries[hero.id].count(null), hero.library.size() - 1, "Only the top card.")
	assert_false(theirs.looks_at_library_top)
	assert_null(theirs.libraries[hero.id][0], "The other player never sees it.")
	assert_eq(theirs.libraries[engine.villain().id].count(null), engine.villain().library.size(),
		"The Hero's Lookout shows nothing of the Villain's library.")


func test_without_a_lookout_the_top_card_is_hidden() -> void:
	var engine: MmEngine = _hero_main([Scenario.lookout(), _cub()], ["Cub"], [])

	var mine: MmPlayerView = engine.view_for(engine.hero())

	assert_false(mine.looks_at_library_top)
	assert_null(mine.libraries[engine.hero().id][0])
	assert_false(Scenario.offers_cast(engine, engine.hero().library.top().id))


func test_a_creature_with_power_2_or_less_on_top_is_cast_from_the_library() -> void:
	var engine: MmEngine = _hero_main([Scenario.lookout(), _cub()], ["Cub"])
	var top: int = engine.hero().library.top().id
	var size: int = engine.hero().library.size()

	assert_true(Scenario.offers_cast(engine, top))
	assert_eq(Scenario.cast(engine, top), "")

	var spell: MmGameObject = engine.game_state().object(Scenario.stack_ids(engine)[0])
	assert_eq(engine.game_state().characteristics_of(spell).name, "Cub")
	assert_true(spell.cast_from_library)
	assert_eq(engine.hero().library.size(), size - 1)
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Cub").size(), 1)
	var used: Dictionary[int, String] = _lookout_view(engine).permissions_used_this_turn
	assert_eq(used, {1: "Cub"} as Dictionary[int, String], "Its second ability is Spent this turn.")


func test_only_a_creature_with_power_2_or_less_is_offered() -> void:
	for top_name: String in ["Brute", "Plains", "Spark"]:
		var engine: MmEngine = _hero_main([Scenario.lookout(), _brute(), Scenario.basic_land("Plains"), _spark()], [top_name])
		var top: int = engine.hero().library.top().id

		var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

		assert_false(Scenario.offers_cast(engine, top), top_name)
		assert_eq(Scenario.play_land_index(decision, top), -1, "CR 305.9: a land on top is never played this way either.")


func test_it_is_not_offered_without_the_mana_to_pay_for_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.lookout(), _kit()], ["Kit"])

	assert_false(Scenario.offers_cast(engine, engine.hero().library.top().id), "No Elf to pay {W}.")


func test_it_keeps_its_card_types_timing() -> void:
	var engine: MmEngine = _hero_main([Scenario.lookout(), _cub(), _flash_cub()], ["Cub"])
	var flashing: MmEngine = _hero_main([Scenario.lookout(), _cub(), _flash_cub()], ["Flash Cub"])

	Scenario.pass_until_step(engine, Step.BEGINNING_OF_COMBAT)
	Scenario.pass_until_step(flashing, Step.BEGINNING_OF_COMBAT)

	assert_false(Scenario.offers_cast(engine, engine.hero().library.top().id), "CR 307.1: a creature at sorcery speed.")
	assert_true(Scenario.offers_cast(flashing, flashing.hero().library.top().id), "CR 702.8a")


func test_it_is_used_once_each_turn_and_again_in_the_next_even_the_other_players() -> void:
	var engine: MmEngine = _hero_main([Scenario.lookout(), _flash_cub()], ["Flash Cub", "Flash Cub", "Flash Cub"])
	Scenario.cast(engine, engine.hero().library.top().id)
	Scenario.resolve_stack(engine)

	assert_false(Scenario.offers_cast(engine, engine.hero().library.top().id), "Once each turn.")
	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)
	assert_eq((engine.pending_decision() as PriorityDecision).player_id, engine.hero().id)

	assert_true(Scenario.offers_cast(engine, engine.hero().library.top().id), "A new turn, the Villain's.")
	assert_eq(_lookout_view(engine).permissions_used_this_turn.size(), 0, "Not Spent in this turn.")


func test_two_lookouts_give_two_casts_the_lower_id_first() -> void:
	var lookouts: Array[MmCardDefinition] = [Scenario.lookout("Lookout"), Scenario.lookout("Second Lookout")]
	var engine: MmEngine = _hero_main([lookouts[0], lookouts[1], _cub()], ["Cub", "Cub", "Cub"], lookouts)
	var first: int = Scenario.permanent_named(engine, engine.hero().id, "Lookout")
	var second: int = Scenario.permanent_named(engine, engine.hero().id, "Second Lookout")
	var lower: int = mini(first, second)

	Scenario.cast(engine, engine.hero().library.top().id)
	Scenario.resolve_stack(engine)

	assert_true(engine.game_state().object(lower).is_permission_used_in(1, engine.game_state().game_turn))
	assert_eq(Scenario.cast(engine, engine.hero().library.top().id), "", "The other one's permission.")
	Scenario.resolve_stack(engine)
	assert_false(Scenario.offers_cast(engine, engine.hero().library.top().id))
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Cub").size(), 2)


func test_a_lookout_that_leaves_and_returns_is_a_new_object_that_may_cast_again() -> void:
	# ADR 0008: the permission was Spent on the object that left.
	var bounce: MmCardDefinition = Scenario.instant("Bounce", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT))], [Scenario.return_to_hand(Scenario.targeted(0))])
	var engine: MmEngine = _hero_main([Scenario.lookout(), _cub(), bounce], ["Cub", "Cub"], [Scenario.lookout()], [bounce])
	Scenario.cast(engine, engine.hero().library.top().id)
	Scenario.resolve_stack(engine)
	var lookout: int = Scenario.permanent_named(engine, engine.hero().id, "Lookout")

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bounce"), [MmReference.to_object(lookout)])
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.cast_and_resolve(engine, "Lookout"), "")

	assert_true(Scenario.offers_cast(engine, engine.hero().library.top().id))


func test_while_it_is_being_cast_the_new_top_card_is_hidden_and_the_cast_can_be_canceled() -> void:
	var engine: MmEngine = _hero_main([Scenario.lookout(), Scenario.elf(), _kit()], ["Kit", "Kit"],
		[Scenario.lookout(), Scenario.elf()])
	var hero: MmPlayer = engine.hero()
	var top: int = hero.library.top().id
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_eq(engine.submit(Scenario.cast_index(decision, top)), "")

	assert_true(engine.pending_decision() is PayManaDecision)
	var paying: MmPlayerView = engine.view_for(hero)
	assert_false(paying.looks_at_library_top, "ADR 0054: the new top card is not seen until it is cast.")
	assert_null(paying.libraries[hero.id][0])
	assert_eq(engine.cancel_cast(), "", "No undo barrier while it is paid for (ADR 0015).")
	assert_eq(engine.hero().library.top().id, top, "Back on top, as it was.")
	assert_eq(_lookout_view(engine).permissions_used_this_turn.size(), 0, "Not Spent.")
	assert_true(engine.view_for(engine.hero()).looks_at_library_top)


func test_once_it_is_cast_the_new_top_is_seen_and_it_cannot_be_undone() -> void:
	var engine: MmEngine = _hero_main([Scenario.lookout(), Scenario.elf(), _kit()], ["Kit", "Kit"],
		[Scenario.lookout(), Scenario.elf()])
	var hero: MmPlayer = engine.hero()

	assert_eq(Scenario.cast(engine, hero.library.top().id), "")

	var view: MmPlayerView = engine.view_for(hero)
	assert_true(view.looks_at_library_top)
	assert_eq((view.libraries[hero.id][0] as MmObjectView).id, hero.library.top().id)
	assert_false(engine.can_undo(), "ADR 0015: a barrier once it is cast, since the new top card was seen.")


func test_whenever_you_cast_sees_a_spell_cast_from_the_library() -> void:
	var watcher: MmCardDefinition = Scenario.enchantment("Watcher", [Scenario.triggered(
		Scenario.casts(null, MmTrigger.Whose.YOU), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([Scenario.lookout(), watcher, _cub()], ["Cub"], [Scenario.lookout(), watcher])
	var life: int = engine.hero().life

	Scenario.cast(engine, engine.hero().library.top().id)
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 1, "CR 601.2i")


func test_views_copies_and_replays_know_where_it_was_cast_from_and_what_is_spent() -> void:
	var engine: MmEngine = _hero_main([Scenario.lookout(), _cub()], ["Cub"])
	Scenario.cast(engine, engine.hero().library.top().id)
	var spell: int = Scenario.stack_ids(engine)[0]

	var theirs: MmPlayerView = engine.view_for(engine.villain())
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	assert_true(_stack_view(theirs, spell).cast_from_library, "Both players see it.")
	assert_eq(_lookout_view(engine, theirs).permissions_used_this_turn, {1: "Cub"} as Dictionary[int, String])
	assert_true(copy.game_state().object(spell).cast_from_library)
	var lookout: int = Scenario.permanent_named(engine, engine.hero().id, "Lookout")
	assert_true(copy.game_state().object(lookout).is_permission_used_in(1, copy.game_state().game_turn))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())
	assert_eq(replayed.fingerprint(), engine.fingerprint())


## A 2/2 creature costing {0}.
func _cub() -> MmCardDefinition:
	return Scenario.creature("Cub", 2, 2)


## A 2/2 creature costing {0} with flash.
func _flash_cub() -> MmCardDefinition:
	return Scenario.creature("Flash Cub", 2, 2, [FlashAbility.new()])


## A 3/3 creature costing {0}.
func _brute() -> MmCardDefinition:
	return Scenario.creature("Brute", 3, 3)


## A 1/1 creature costing {W}.
func _kit() -> MmCardDefinition:
	return Scenario.creature("Kit", 1, 1, [], Scenario.mana_cost(0, [MmMana.Type.WHITE]))


## A sorcery costing {0}: "You gain 1 life."
func _spark() -> MmCardDefinition:
	return Scenario.sorcery("Spark", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])


## The Hero's first main phase of Game Turn 3, with [param hero_permanents] cast on Game
## Turn 1, [param hand] in hand, and the top of the Hero's library holding [param tops] in
## order. The Hero's deck cycles through [param deck].
func _hero_main(deck: Array[MmCardDefinition], tops: Array[String], hero_permanents: Variant = null,
		hand: Array[MmCardDefinition] = []) -> MmEngine:
	var permanents: Array[MmCardDefinition] = [deck[0]]
	if hero_permanents != null:
		permanents.assign(hero_permanents)
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(deck), Scenario.cycled([]))
	_setup = setup
	var engine: MmEngine = Scenario.top_ready(setup, permanents, hand, tops)
	assert_not_null(engine, "No seed gave the needed cards.")
	return engine


## The Hero's Lookout as [param view] (the Hero's own by default) shows it.
func _lookout_view(engine: MmEngine, view: MmPlayerView = null) -> MmObjectView:
	var seen: MmPlayerView = engine.view_for(engine.hero()) if view == null else view
	var lookout: int = Scenario.permanent_named(engine, engine.hero().id, "Lookout")
	for permanent: MmObjectView in seen.battlefield:
		if permanent.id == lookout:
			return permanent
	return null


func _stack_view(view: MmPlayerView, object_id: int) -> MmObjectView:
	for item: MmObjectView in view.stack:
		if item.id == object_id:
			return item
	return null
