extends GutTest
## The State List (13h): what is true of a permanent right now that its Card Face does not
## say, each entry a title and a sentence.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const BEARS: int = 7
const HEALER: int = 8
const END_OF_TURN: int = CreateContinuousEffect.Duration.UNTIL_END_OF_TURN


func test_a_permanent_with_nothing_on_it_has_an_empty_list() -> void:
	assert_eq(StateList.of(_bears(), _view()).size(), 0)


func test_a_summoning_sick_creature_says_so_and_a_land_never_does() -> void:
	var bears: MmObjectView = _bears()
	bears.is_summoning_sick = true
	var land: MmObjectView = MmObjectView.new()
	land.is_summoning_sick = true

	assert_eq(_texts(StateList.of(bears, _view())), [["Summoning sick",
		"It came under its controller's control this turn, so it can't attack or tap for a cost."]])
	assert_eq(StateList.of(land, _view()).size(), 0)


func test_damage_marked_is_counted() -> void:
	var bears: MmObjectView = _bears()
	bears.damage_marked = 2

	assert_eq(_texts(StateList.of(bears, _view())), [["Damage", "2 damage is marked on it until end of turn."]])


func test_a_pump_names_the_card_it_came_from() -> void:
	var bears: MmObjectView = _bears()
	bears.continuous_effects = [_locked(Scenario.modify_pt(3, 3, null), [3, 3])]

	assert_eq(_texts(StateList.of(bears, _view())), [["Samite Healer", "It gets +3/+3 until end of turn."]])


func test_a_shrink_is_signed() -> void:
	var bears: MmObjectView = _bears()
	bears.continuous_effects = [_locked(Scenario.modify_pt(-1, 0, null), [-1, 0])]

	assert_eq(_texts(StateList.of(bears, _view()))[0][1], "It gets -1/+0 until end of turn.")


func test_set_power_and_toughness_gained_and_lost_abilities_are_worded() -> void:
	var bears: MmObjectView = _bears()
	var flying: Array[MmAbility] = [FlyingAbility.new(), FirstStrikeAbility.new()]
	bears.continuous_effects = [
		_locked(Scenario.set_pt(0, 1, null), [0, 1]),
		_locked(Scenario.gain_abilities(flying, null), []),
		_locked(Scenario.lose_all_abilities(null), []),
	]

	var texts: Array = _texts(StateList.of(bears, _view()))
	assert_eq(texts[0][1], "Its base power and toughness are 0/1 until end of turn.")
	assert_eq(texts[1][1], "It has flying and first strike until end of turn.")
	assert_eq(texts[2][1], "It loses all abilities until end of turn.")


func test_an_effect_whose_source_is_gone_is_an_effect() -> void:
	var bears: MmObjectView = _bears()
	var active: ActiveContinuousEffect = ActiveContinuousEffect.locked(Scenario.modify_pt(1, 1, null), 5, HERO, 60, 160,
		[BEARS] as Array[int], [1, 1] as Array[int], END_OF_TURN)
	bears.continuous_effects = [active]

	assert_eq(_texts(StateList.of(bears, _view()))[0][0], "An effect")


func test_a_shield_is_listed_with_what_it_has_left() -> void:
	var bears: MmObjectView = _bears()
	bears.replacement_effects = [ActiveReplacementEffect.created(PreventDamageReplacementEffect.new(), 5, HERO, HEALER, 108,
		[MmReference.to_object(BEARS)] as Array[MmReference], 1, 0)]

	assert_eq(_texts(StateList.of(bears, _view())), [["Samite Healer",
		"Prevent the next 1 damage that would be dealt to Grizzly Bears this turn."]])


func test_the_entries_come_in_a_fixed_order() -> void:
	var bears: MmObjectView = _bears()
	bears.is_summoning_sick = true
	bears.damage_marked = 1
	bears.continuous_effects = [_locked(Scenario.modify_pt(3, 3, null), [3, 3])]
	bears.replacement_effects = [ActiveReplacementEffect.created(RegenerationReplacementEffect.new(), 5, HERO, HEALER, 108,
		[MmReference.to_object(BEARS)] as Array[MmReference], 1, 0)]

	var titles: Array[String] = []
	for entry: StateEntry in StateList.of(bears, _view()):
		titles.append(entry.title)
	assert_eq(titles, ["Summoning sick", "Damage", "Samite Healer", "Samite Healer"])


func _locked(effect: MmContinuousEffect, amounts: Array) -> ActiveContinuousEffect:
	var numbers: Array[int] = []
	numbers.assign(amounts)
	return ActiveContinuousEffect.locked(effect, 5, HERO, HEALER, 108, [BEARS] as Array[int], numbers, END_OF_TURN)


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
