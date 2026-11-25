extends GutTest
## Reflexive triggered abilities (CR 603.12): "When you do, [ability]", after a "you may"
## whose cost is to exile a creature card from your graveyard, as Kishla Trawlers has it.
## The reflexive ability triggers as the cost is paid and goes on the stack the next time a
## player would receive priority, its targets chosen then. Husks are 0/0 creatures costing
## {0}, which die as they enter, and Gifts instants costing {0}, so both end in the graveyard.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const YES: int = ChooseYesOrNoDecision.Choice.YES
const NO: int = ChooseYesOrNoDecision.Choice.NO


func test_yes_exiles_the_chosen_creature_card_and_the_reflexive_trigger_returns_its_target() -> void:
	var engine: MmEngine = _graveyard_ready(["Husk", "Gift"])
	assert_eq(_cast_trawler_to_question(engine), "")

	assert_eq(engine.submit(YES), "")
	var choice: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
	assert_not_null(choice, "Yes asks which card to exile.")
	assert_eq(choice.purpose, ChooseObjectDecision.Purpose.EXILE_FROM_GRAVEYARD)
	assert_eq(_names_of(engine, choice.candidates), ["Husk"], "Only creature cards in your graveyard.")
	assert_eq(engine.submit(0), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Husk"), -1)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Gift"), -1)


func test_the_reflexive_trigger_goes_on_the_stack_once_its_ability_has_resolved_and_targets_then() -> void:
	var engine: MmEngine = _graveyard_ready(["Husk", "Gift", "Second Gift"])
	assert_eq(_cast_trawler_to_question(engine), "")
	var trawler: int = Scenario.permanent_named(engine, engine.hero().id, "Trawler")
	assert_eq(engine.submit(YES), "")

	assert_eq(engine.submit(0), "")

	var target: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(target, "CR 603.12: its target is chosen as it is put on the stack.")
	assert_eq(_names_of(engine, target.candidates), ["Gift", "Second Gift"])
	var stack: Array[int] = Scenario.stack_ids(engine)
	assert_eq(stack.size(), 1, "The enters ability has left the stack.")
	assert_eq(engine.game_state().object(stack[0]).source_object_id, trawler)


func test_no_exiles_nothing_and_nothing_triggers() -> void:
	var engine: MmEngine = _graveyard_ready(["Husk", "Gift"])
	assert_eq(_cast_trawler_to_question(engine), "")

	assert_eq(engine.submit(NO), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Husk"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Gift"), -1)
	assert_eq(_triggers_of(engine), 1, "Only the enters ability triggered.")


func test_with_no_creature_card_in_the_graveyard_nothing_is_asked() -> void:
	# CR 118.3: a cost that can't be paid isn't offered, so "When you do" can't happen.
	var engine: MmEngine = _graveyard_ready(["Gift"])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Trawler")), "")

	assert_eq(_play_to_question_or_empty_stack(engine), "")

	assert_false(engine.pending_decision() is ChooseYesOrNoDecision)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Gift"), -1)
	assert_eq(_triggers_of(engine), 1)


func test_with_no_instant_or_sorcery_card_it_still_exiles_and_the_reflexive_trigger_is_removed() -> void:
	var engine: MmEngine = _graveyard_ready(["Husk"])
	assert_eq(_cast_trawler_to_question(engine), "")
	assert_eq(engine.submit(YES), "")

	assert_eq(engine.submit(0), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Husk"), -1)
	assert_eq(_triggers_of(engine), 2, "It triggered as the card was exiled.")
	assert_eq(Scenario.events_of(engine, TriggerRemovedEvent).size(), 1, "CR 603.3d: with no legal target it is removed.")


func test_the_reflexive_trigger_uses_the_stack_so_it_can_be_countered() -> void:
	var engine: MmEngine = _graveyard_ready(["Husk", "Gift"], [Scenario.free_stifle("Stifle")])
	assert_eq(_cast_trawler_to_question(engine), "")
	assert_eq(engine.submit(YES), "")
	assert_eq(engine.submit(0), "")
	assert_eq(Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.pending_decision() is PriorityDecision and not running.game_state().stack.is_empty()), "")
	var reflexive: int = Scenario.stack_ids(engine)[0]

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Stifle"), [MmReference.to_object(reflexive)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Husk"), -1, "The exile was paid as the first ability resolved.")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Gift"), -1, "The countered reflexive ability returned nothing.")


func test_it_still_triggers_after_its_source_has_left_the_battlefield() -> void:
	# CR 603.12, 608.2h: its source is the creature as it last existed.
	var engine: MmEngine = _graveyard_ready(["Husk", "Gift"], [Scenario.free_bounce("Bounce")])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Trawler")), "")
	assert_eq(Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		var stack: Array[MmGameObject] = running.game_state().stack.objects()
		return running.pending_decision() is PriorityDecision and not stack.is_empty() and not stack.back().is_card_or_copy()), "")
	var trawler: int = Scenario.permanent_named(engine, engine.hero().id, "Trawler")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bounce"), [MmReference.to_object(trawler)]), "")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Trawler"), -1)

	assert_eq(engine.submit(YES), "")
	assert_eq(engine.submit(0), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Gift"), -1)


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_reflexive_triggers.tres"
	assert_eq(ResourceSaver.save(Scenario.trawler(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var paying: MayPayEffect = (loaded.abilities[0] as TriggeredAbility).effects[0] as MayPayEffect
	assert_true(paying.cost is ExileFromGraveyardCost)
	var returns: ReflexiveTriggerEffect = paying.effect as ReflexiveTriggerEffect
	assert_eq([returns.ability.targets.size(), returns.ability.effects.size()], [1, 1])
	assert_null(returns.ability.trigger)
	DirAccess.remove_absolute(path)


func test_a_reflexive_trigger_effect_reaches_nothing_of_its_own_ability() -> void:
	# Its targets are its own ability's, chosen apart, so the ability holding it targets nothing.
	var effect: ReflexiveTriggerEffect = Scenario.reflexive([Scenario.return_to_hand(Scenario.targeted(0))],
		[Scenario.your_dead_spell()])

	assert_eq(effect.selections().size(), 0)
	assert_eq(Scenario.may_pay(Scenario.exile_from_graveyard(), effect).selections().size(), 0)


## The Hero in their main phase of Game Turn 3 holding a Trawler and [param extras], with
## each of [param casts], Husks and Gifts by name, cast first, so they are in the graveyard.
func _graveyard_ready(casts: Array[String], extras: Array[MmCardDefinition] = []) -> MmEngine:
	var hand: Array[MmCardDefinition] = [Scenario.trawler()]
	for card_name: String in casts:
		if card_name.contains("Husk"):
			hand.append(Scenario.creature(card_name, 0, 0))
		else:
			hand.append(Scenario.instant(card_name, Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())]))
	hand.append_array(extras)
	var none: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(none, none, hand), none, none, hand, none, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	for card_name: String in casts:
		assert_eq(Scenario.cast_and_resolve(engine, card_name), "")
		assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), card_name), -1)
	return engine


## Casts the Trawler and plays on to its "you may".
func _cast_trawler_to_question(engine: MmEngine) -> String:
	var error: String = Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Trawler"))
	return error if error != "" else Scenario.pass_to_yes_or_no(engine)


## Plays on until a yes or no is asked or the stack is empty.
func _play_to_question_or_empty_stack(engine: MmEngine) -> String:
	return Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.pending_decision() is ChooseYesOrNoDecision or (running.pending_decision() is PriorityDecision
			and running.game_state().stack.is_empty() and running.game_state().pending_triggers.is_empty()))


## How many times an ability of the Trawler has triggered, the reflexive one included.
func _triggers_of(engine: MmEngine) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if (event as AbilityTriggeredEvent).pending.source_name == "Trawler":
			count += 1
	return count


func _names_of(engine: MmEngine, references: Array[MmReference]) -> Array[String]:
	var found: Array[String] = []
	for reference: MmReference in references:
		found.append(engine.game_state().characteristics_of(engine.game_state().object(reference.id)).name)
	return found
