extends GutTest
## What a Stack Window entry says about a spell or ability (A338, A341): an ability leads
## with what it does and a spell with its name, then who controls it and what it targets.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SORCERER: int = 6
const BEARS: int = 7


func test_a_spell_leads_with_its_name_then_its_controller_and_target() -> void:
	var view: MmPlayerView = _view()
	var bolt: MmObjectView = _spell(20, "Lightning Bolt", VILLAIN, [MmReference.to_object(SORCERER)])
	view.stack = [bolt]

	var item: StackItem = StackItem.of(bolt, view)

	assert_eq(item.id, 20)
	assert_eq(item.first_line, "Lightning Bolt")
	assert_eq(item.second_line, "Villain → Prodigal Sorcerer")
	assert_eq(item.full_text, "Lightning Bolt — Lightning Bolt deals 3 damage to any target.")
	assert_eq(item.target_object_ids, [SORCERER] as Array[int])
	assert_eq(item.target_player_ids, [] as Array[int])
	assert_eq(item.source_object_id, StackItem.NONE)


func test_an_ability_leads_with_what_it_does_in_its_sources_words() -> void:
	var view: MmPlayerView = _view()
	var ping: MmObjectView = _ability(21, "Prodigal Sorcerer", SORCERER, HERO, [MmReference.to_player(VILLAIN)])
	view.stack = [ping]

	var item: StackItem = StackItem.of(ping, view)

	assert_eq(item.first_line, "This creature deals 1 damage to any target.")
	assert_eq(item.second_line, "Hero → Villain")
	assert_eq(item.full_text, "Prodigal Sorcerer's ability — This creature deals 1 damage to any target.")
	assert_eq(item.target_player_ids, [VILLAIN] as Array[int])
	assert_eq(item.target_object_ids, [] as Array[int])
	assert_eq(item.source_object_id, SORCERER)


func test_an_ability_whose_source_has_left_calls_it_by_name_and_marks_no_source() -> void:
	var view: MmPlayerView = _view()
	view.battlefield.remove_at(0)
	var ping: MmObjectView = _ability(21, "Prodigal Sorcerer", SORCERER, HERO, [MmReference.to_player(HERO)])

	var item: StackItem = StackItem.of(ping, view)

	assert_eq(item.first_line, "Prodigal Sorcerer deals 1 damage to any target.")
	assert_eq(item.second_line, "Hero → Hero")
	assert_eq(item.source_object_id, StackItem.NONE)


func test_an_emblems_ability_finds_its_source_in_the_command_zone() -> void:
	var view: MmPlayerView = _view()
	var emblem: MmObjectView = MmObjectView.new()
	emblem.id = 30
	emblem.name = "Storm Emblem"
	view.command = [emblem]
	var ping: MmObjectView = _ability(21, "Storm Emblem", 30, VILLAIN, [MmReference.to_player(HERO)])

	var item: StackItem = StackItem.of(ping, view)

	assert_eq(item.source_object_id, 30)
	assert_eq(item.first_line, "This emblem deals 1 damage to any target.", "An Emblem calls itself \"this emblem\" (ADR 0036).")


func test_a_potions_ability_is_read_though_its_potion_is_gone() -> void:
	var view: MmPlayerView = _view()
	var gulp: MmObjectView = _ability(21, "Big Gulp", 30, HERO, [MmReference.to_player(HERO)])
	gulp.source_potion_index = 0

	var item: StackItem = StackItem.of(gulp, view)

	assert_eq(item.source_object_id, StackItem.NONE, "Nothing is left to mark on the board.")
	assert_eq(item.first_line, "This potion deals 1 damage to any target.")


func test_with_no_targets_the_second_line_is_just_the_controller() -> void:
	var view: MmPlayerView = _view()
	var bears: MmObjectView = _spell(22, "Grizzly Bears", HERO, [])
	bears.abilities = []
	bears.card_types = [MmCardTypes.CardType.CREATURE]

	var item: StackItem = StackItem.of(bears, view)

	assert_eq(item.second_line, "Hero")
	assert_eq(item.full_text, "Grizzly Bears", "A card with no abilities has nothing more to say.")


func test_several_targets_are_all_named_and_one_that_is_gone_is_left_out() -> void:
	var view: MmPlayerView = _view()
	var bolt: MmObjectView = _spell(20, "Twin Bolt", HERO,
		[MmReference.to_object(BEARS), MmReference.to_object(99), null, MmReference.to_player(VILLAIN)])

	var item: StackItem = StackItem.of(bolt, view)

	assert_eq(item.second_line, "Hero → Grizzly Bears, Villain")
	assert_eq(item.target_object_ids, [BEARS] as Array[int])


func test_a_spell_that_targets_a_spell_names_it_and_says_which_entry_it_points_at() -> void:
	var view: MmPlayerView = _view()
	var bolt: MmObjectView = _spell(20, "Lightning Bolt", VILLAIN, [MmReference.to_player(HERO)])
	var counter: MmObjectView = _spell(23, "Counterspell", HERO, [MmReference.to_object(20)])
	counter.abilities = [(Scenario.free_counter("Counterspell")).abilities[0]]
	view.stack = [bolt, counter]

	var item: StackItem = StackItem.of(counter, view)

	assert_eq(item.second_line, "Hero → Lightning Bolt")
	assert_eq(item.target_stack_ids, [20] as Array[int])
	assert_eq(item.target_object_ids, [] as Array[int], "A spell is not marked on the battlefield.")


func test_a_permanent_spells_full_text_is_its_rules_text_on_one_line() -> void:
	var view: MmPlayerView = _view()
	var angel: MmObjectView = _spell(24, "Serra Angel", HERO, [])
	angel.card_types = [MmCardTypes.CardType.CREATURE]
	angel.abilities = [FlyingAbility.new(), VigilanceAbility.new(), Scenario.regenerate_ability(Scenario.mana_cost(1))]

	var item: StackItem = StackItem.of(angel, view)

	assert_eq(item.full_text, "Serra Angel — Flying, vigilance · {1}: Regenerate this creature.")


func test_players_are_called_by_the_names_they_were_given() -> void:
	var view: MmPlayerView = _view()
	var bolt: MmObjectView = _spell(20, "Lightning Bolt", VILLAIN, [MmReference.to_player(HERO)])
	view.stack = [bolt]

	var item: StackItem = StackItem.of(bolt, view, PlayerNames.new("Jackson", "Mishra"))

	assert_eq(item.second_line, "Mishra → Jackson")
	assert_eq(StackItem.of(bolt, view).second_line, "Villain → Hero", "With no names they go by their parts.")


func test_a_target_in_a_graveyard_is_named_and_marks_nothing() -> void:
	var view: MmPlayerView = _view()
	var dead: MmObjectView = MmObjectView.new()
	dead.id = 40
	dead.name = "Scathe Zombies"
	view.graveyards = {HERO: [dead], VILLAIN: []}
	var raise: MmObjectView = _spell(20, "Raise Dead", HERO, [MmReference.to_object(40)])
	view.stack = [raise]

	var item: StackItem = StackItem.of(raise, view)

	assert_eq(item.second_line, "Hero → Scathe Zombies")
	assert_eq(item.target_object_ids, [] as Array[int], "It is not on the battlefield.")
	assert_eq(item.target_stack_ids, [] as Array[int])


func _view() -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var sorcerer: MmObjectView = MmObjectView.new()
	sorcerer.id = SORCERER
	sorcerer.name = "Prodigal Sorcerer"
	sorcerer.card_types = [MmCardTypes.CardType.CREATURE]
	var bears: MmObjectView = MmObjectView.new()
	bears.id = BEARS
	bears.name = "Grizzly Bears"
	bears.card_types = [MmCardTypes.CardType.CREATURE]
	view.battlefield = [sorcerer, bears]
	return view


func _spell(id: int, spell_name: String, controller: int, targets: Array[MmReference]) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.card_id = id
	seen.name = spell_name
	seen.controller_id = controller
	seen.card_types = [MmCardTypes.CardType.INSTANT]
	seen.abilities = [(Scenario.free_shock(spell_name, 3)).abilities[0]]
	seen.targets = targets
	return seen


func _ability(id: int, source_name: String, source_id: int, controller: int, targets: Array[MmReference]) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.card_id = MmGameObject.NO_CARD
	seen.name = source_name + " ability"
	seen.source_object_id = source_id
	seen.controller_id = controller
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.targets = [Scenario.any_target()]
	ability.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]
	seen.ability = ability
	seen.targets = targets
	return seen
