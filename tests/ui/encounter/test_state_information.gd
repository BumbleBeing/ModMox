extends GutTest
## State Information (13h, milestone 16): what is true of a permanent right now that its Card Face does not
## say, each entry a title and a sentence.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const BEARS: int = 7
const HEALER: int = 8
const END_OF_TURN: int = CreateContinuousEffect.Duration.UNTIL_END_OF_TURN


func test_a_permanent_with_nothing_on_it_has_an_empty_list() -> void:
	assert_eq(StateInformation.of(_bears(), _view()).size(), 0)


func test_an_attachment_says_what_it_is_attached_to_and_that_permanent_says_what_is_attached_to_it() -> void:
	var view: MmPlayerView = _view()
	var bears: MmObjectView = _bears()
	var sword: MmObjectView = MmObjectView.new()
	sword.id = 31
	sword.name = "Short Sword"
	sword.attached_to_object_id = BEARS
	var axe: MmObjectView = MmObjectView.new()
	axe.id = 30
	axe.name = "Axe"
	axe.attached_to_object_id = BEARS
	view.battlefield.append_array([sword, axe])

	assert_eq(_texts(StateInformation.of(sword, view)), [["Attached", "Attached to %s." % bears.name]])
	assert_eq(_texts(StateInformation.of(bears, view)), [["Attachment", "Axe."], ["Attachment", "Short Sword."]],
		"In object ID order, as they are drawn.")


func test_a_tucked_card_says_what_exiled_it_and_that_permanent_names_each_card_it_exiled() -> void:
	var view: MmPlayerView = _view()
	var ring: MmObjectView = MmObjectView.new()
	ring.id = 40
	ring.name = "Oblivion Ring"
	view.battlefield.append(ring)
	var ogre: MmObjectView = MmObjectView.new()
	ogre.id = 52
	ogre.name = "Ogre"
	ogre.exiled_with_object_id = 40
	var bear: MmObjectView = MmObjectView.new()
	bear.id = 51
	bear.name = "Bear"
	bear.exiled_with_object_id = 40
	var lost: MmObjectView = MmObjectView.new()
	lost.id = 53
	lost.name = "Lost"
	lost.exiled_with_object_id = 999
	view.exiles[HERO] = [ogre, lost]
	view.exiles[MmEncounterSetup.VILLAIN_PLAYER_ID] = [bear]

	assert_eq(_texts(StateInformation.of(ogre, view)), [["Exiled", "Exiled by Oblivion Ring."]])
	assert_eq(_texts(StateInformation.of(ring, view)), [["Exiled Card", "Bear."], ["Exiled Card", "Ogre."]],
		"In object ID order, as they are drawn.")
	assert_eq(StateInformation.of(lost, view).size(), 0, "What exiled it has gone, and it is exiled for good.")


func test_a_chosen_creature_type_says_what_it_does_with_the_type_named() -> void:
	var rally: MmCardDefinition = Scenario.rally("Rally the Ranks")
	var seen: MmObjectView = MmObjectView.new()
	seen.id = 50
	seen.name = rally.name
	seen.card_types = rally.card_types
	seen.abilities = rally.abilities
	seen.chosen_creature_type = "Cat"

	assert_eq(_texts(StateInformation.of(seen, _view())), [["Chosen type: Cat",
		"Each Cat creature you control gets +1/+1. Chosen as Rally the Ranks entered."]],
		"Game ADR 0053: the type is State Information, not rules text.")


func test_a_permanent_with_no_chosen_type_says_nothing_of_one() -> void:
	var rally: MmCardDefinition = Scenario.rally("Rally the Ranks")
	var seen: MmObjectView = MmObjectView.new()
	seen.id = 50
	seen.name = rally.name
	seen.abilities = rally.abilities

	assert_eq(StateInformation.of(seen, _view()).size(), 0)


func test_a_permission_spent_this_turn_says_what_was_cast_and_by_whom() -> void:
	# Game ADR 0055: only what was done, nothing of next turn.
	var view: MmPlayerView = _view()
	var mine: MmObjectView = _assemble(40, HERO, "Savannah Lions")
	var theirs: MmObjectView = _assemble(41, MmEncounterSetup.VILLAIN_PLAYER_ID, "Pearled Unicorn")
	view.battlefield.append_array([mine, theirs])

	assert_eq(_texts(StateInformation.of(mine, view)),
		[["Cast from the top this turn", "You cast Savannah Lions from the top of your library."]])
	assert_eq(_texts(StateInformation.of(theirs, view)),
		[["Cast from the top this turn", "The Villain cast Pearled Unicorn from the top of their library."]])
	assert_eq(_texts(StateInformation.of(theirs, view, PlayerNames.new("Jackson", "Arahbo"))),
		[["Cast from the top this turn", "Arahbo cast Pearled Unicorn from the top of their library."]])


func test_a_permission_not_spent_this_turn_says_nothing() -> void:
	var view: MmPlayerView = _view()
	var ready: MmObjectView = _assemble(40, HERO, "")
	ready.permissions_used_this_turn.clear()

	assert_eq(StateInformation.of(ready, view).size(), 0)


func test_a_trigger_spent_this_turn_says_it_wont_trigger_again() -> void:
	# Engine ADR 0054's addendum: "This ability triggers only once each turn."
	var welcome: MmObjectView = MmObjectView.new()
	welcome.id = 42
	welcome.name = "Tocasia's Welcome"
	welcome.card_types = [MmCardTypes.CardType.ENCHANTMENT]
	welcome.triggered_this_turn = [0]

	assert_eq(_texts(StateInformation.of(welcome, _view())), [["Triggered this turn", "Won't trigger again this turn."]])
	welcome.triggered_this_turn.clear()
	assert_eq(StateInformation.of(welcome, _view()).size(), 0)


func test_a_summoning_sick_creature_says_so_and_a_land_never_does() -> void:
	var bears: MmObjectView = _bears()
	bears.is_summoning_sick = true
	var land: MmObjectView = MmObjectView.new()
	land.is_summoning_sick = true

	assert_eq(_texts(StateInformation.of(bears, _view())), [["Summoning Sick",
		"Can't attack or tap until its controller's next turn."]])
	assert_eq(StateInformation.of(land, _view()).size(), 0)


func test_an_exerted_permanent_says_it_wont_untap_after_summoning_sickness() -> void:
	var bears: MmObjectView = _bears()
	bears.is_exerted = true
	bears.is_summoning_sick = true

	assert_eq(_texts(StateInformation.of(bears, _view())), [
		["Summoning Sick", "Can't attack or tap until its controller's next turn."],
		["Exerted", "Won't untap during its controller's next untap step."]])


func test_a_permanent_that_doesnt_untap_says_it_wont() -> void:
	# Niblis of Frost's "That creature doesn't untap during its controller's next untap step."
	var bears: MmObjectView = _bears()
	bears.skips_next_untap = true

	assert_eq(_texts(StateInformation.of(bears, _view())), [
		["Won't untap", "Won't untap during its controller's next untap step."]])


func test_a_permanent_that_cant_block_this_turn_says_so() -> void:
	# Arena Athlete's "target creature an opponent controls can't block this turn", the
	# user's words.
	var bears: MmObjectView = _bears()
	bears.cant_block_this_turn = true

	assert_eq(_texts(StateInformation.of(bears, _view())), [["Can't block", "Can't block this turn."]])


func test_a_token_says_it_ceases_to_exist_if_it_leaves_and_comes_first() -> void:
	var cat: MmObjectView = _bears()
	cat.is_token = true
	cat.is_summoning_sick = true

	assert_eq(_texts(StateInformation.of(cat, _view())), [
		["Token", "Ceases to exist if it leaves the battlefield."],
		["Summoning Sick", "Can't attack or tap until its controller's next turn."]])


func test_damage_marked_is_counted() -> void:
	var bears: MmObjectView = _bears()
	bears.damage_marked = 2

	assert_eq(_texts(StateInformation.of(bears, _view())), [["Damaged", "Has 2 damage marked on it."]])


func test_counters_are_counted_in_digits() -> void:
	var grown: MmObjectView = _bears()
	grown.counters = {MmCounter.Kind.PLUS_ONE_PLUS_ONE: 2}
	var shrunk: MmObjectView = _bears()
	shrunk.counters = {MmCounter.Kind.MINUS_ONE_MINUS_ONE: 1}
	var huge: MmObjectView = _bears()
	huge.counters = {MmCounter.Kind.PLUS_ONE_PLUS_ONE: 12}

	assert_eq(_texts(StateInformation.of(grown, _view())), [["+1/+1 Counters", "Currently has 2 +1/+1 counters."]])
	assert_eq(_texts(StateInformation.of(shrunk, _view())), [["-1/-1 Counters", "Currently has 1 -1/-1 counter."]])
	assert_eq(_texts(StateInformation.of(huge, _view()))[0][1], "Currently has 12 +1/+1 counters.")


func test_a_pump_names_the_card_it_came_from() -> void:
	var bears: MmObjectView = _bears()
	bears.continuous_effects = [_locked(Scenario.modify_pt(3, 3, null), [3, 3])]

	assert_eq(_texts(StateInformation.of(bears, _view())), [["Samite Healer's Effect", "+3/+3 until end of turn."]])


func test_a_shrink_is_signed() -> void:
	var bears: MmObjectView = _bears()
	bears.continuous_effects = [_locked(Scenario.modify_pt(-1, 0, null), [-1, 0])]

	assert_eq(_texts(StateInformation.of(bears, _view()))[0][1], "-1/+0 until end of turn.")


func test_set_power_and_toughness_gained_and_lost_abilities_are_worded() -> void:
	var bears: MmObjectView = _bears()
	var flying: Array[MmAbility] = [FlyingAbility.new(), FirstStrikeAbility.new()]
	bears.continuous_effects = [
		_locked(Scenario.set_pt(0, 1, null), [0, 1]),
		_locked(Scenario.gain_abilities(flying, null), []),
		_locked(Scenario.lose_all_abilities(null), []),
	]

	var texts: Array = _texts(StateInformation.of(bears, _view()))
	assert_eq(texts[0][1], "Has base power and toughness 0/1 until end of turn.")
	assert_eq(texts[1][1], "Has flying and first strike until end of turn.")
	assert_eq(texts[2][1], "Loses all abilities until end of turn.")


func test_three_abilities_gained_are_listed_with_a_serial_comma() -> void:
	var bears: MmObjectView = _bears()
	var gained: Array[MmAbility] = [FlyingAbility.new(), FirstStrikeAbility.new(), TrampleAbility.new()]
	bears.continuous_effects = [_locked(Scenario.gain_abilities(gained, null), [])]

	assert_eq(_texts(StateInformation.of(bears, _view()))[0][1], "Has flying, first strike, and trample until end of turn.")


func test_a_source_whose_name_ends_in_s_takes_only_an_apostrophe() -> void:
	var view: MmPlayerView = _view()
	view.battlefield[1].name = "Llanowar Elves"
	var bears: MmObjectView = view.battlefield[0]
	bears.continuous_effects = [_locked(Scenario.modify_pt(1, 1, null), [1, 1])]

	assert_eq(_texts(StateInformation.of(bears, view))[0][0], "Llanowar Elves' Effect")


func test_an_effect_whose_source_is_gone_is_an_effect() -> void:
	var bears: MmObjectView = _bears()
	var active: ActiveContinuousEffect = ActiveContinuousEffect.locked(Scenario.modify_pt(1, 1, null), 5, HERO, 60, 160,
		[BEARS] as Array[int], [1, 1] as Array[int], END_OF_TURN)
	bears.continuous_effects = [active]

	assert_eq(_texts(StateInformation.of(bears, _view()))[0][0], "Effect")


func test_a_shield_is_listed_with_what_it_has_left() -> void:
	var bears: MmObjectView = _bears()
	bears.replacement_effects = [ActiveReplacementEffect.created(PreventDamageReplacementEffect.new(), 5, HERO, HEALER, 108,
		[MmReference.to_object(BEARS)] as Array[MmReference], 1, 0)]

	assert_eq(_texts(StateInformation.of(bears, _view())), [["Samite Healer's Effect",
		"Prevent the next 1 damage that would be dealt to Grizzly Bears this turn."]])


func test_the_entries_come_in_a_fixed_order() -> void:
	var bears: MmObjectView = _bears()
	bears.is_summoning_sick = true
	bears.damage_marked = 1
	bears.counters = {MmCounter.Kind.PLUS_ONE_PLUS_ONE: 1}
	bears.continuous_effects = [_locked(Scenario.modify_pt(3, 3, null), [3, 3])]
	bears.replacement_effects = [ActiveReplacementEffect.created(RegenerationReplacementEffect.new(), 5, HERO, HEALER, 108,
		[MmReference.to_object(BEARS)] as Array[MmReference], 1, 0)]

	var titles: Array[String] = []
	for entry: StateEntry in StateInformation.of(bears, _view()):
		titles.append(entry.title)
	assert_eq(titles, ["Summoning Sick", "+1/+1 Counters", "Damaged", "Samite Healer's Effect", "Samite Healer's Effect"])


func _locked(effect: MmContinuousEffect, amounts: Array) -> ActiveContinuousEffect:
	var numbers: Array[int] = []
	numbers.assign(amounts)
	return ActiveContinuousEffect.locked(effect, 5, HERO, HEALER, 108, [BEARS] as Array[int], numbers, END_OF_TURN)


## Assemble the Players controlled by [param controller], its cast from the top this turn
## Spent on [param cast].
func _assemble(id: int, controller: int, cast: String) -> MmObjectView:
	var assemble: MmObjectView = MmObjectView.new()
	assemble.id = id
	assemble.card_id = 100 + id
	assemble.name = "Assemble the Players"
	assemble.controller_id = controller
	assemble.card_types = [MmCardTypes.CardType.ENCHANTMENT]
	assemble.permissions_used_this_turn = {1: cast}
	return assemble


func _bears() -> MmObjectView:
	return _view().battlefield[0]


func _view() -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var bears: MmObjectView = MmObjectView.new()
	bears.id = BEARS
	bears.card_id = 107
	bears.name = "Grizzly Bears"
	bears.is_creature = true
	var healer: MmObjectView = MmObjectView.new()
	healer.id = HEALER
	healer.card_id = 108
	healer.name = "Samite Healer"
	view.battlefield = [bears, healer]
	return view


func _texts(entries: Array[StateEntry]) -> Array:
	var texts: Array = []
	for entry: StateEntry in entries:
		texts.append([entry.title, entry.text])
	return texts
