extends GutTest
## The words of the replacement choice (A340): what is about to happen, and what each
## effect that could apply first does and came from.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const BEARS: int = 7
const HEALER: int = 8


func test_damage_to_a_creature_or_a_player_is_named() -> void:
	var view: MmPlayerView = _view()

	assert_eq(ReplacementText.event_text(DamageEvent.new(3, MmReference.to_object(BEARS), 2, true), view), "2 combat damage to Grizzly Bears")
	assert_eq(ReplacementText.event_text(DamageEvent.new(3, MmReference.to_player(HERO), 3), view), "3 damage to Hero")
	assert_eq(ReplacementText.event_text(DamageEvent.new(3, MmReference.to_object(99), 1), view), "1 damage to a permanent")


func test_the_title_asks_which_applies_first() -> void:
	var decision: ChooseReplacementEffectDecision = ChooseReplacementEffectDecision.new(HERO,
		DamageEvent.new(3, MmReference.to_object(BEARS), 2, true), [] as Array[ActiveReplacementEffect])

	assert_eq(ReplacementText.title(decision, _view()), "2 combat damage to Grizzly Bears: which applies first?")


func test_an_event_with_no_words_is_just_this_event() -> void:
	assert_eq(ReplacementText.event_text(TapEvent.new(BEARS), _view()), "This event")


func test_only_a_destruction_is_worded_as_one() -> void:
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(Scenario.cycled([Scenario.life_land()]), Scenario.cycled([])),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, "Life Land"))
	var hero: MmPlayer = engine.hero()
	var land: MmGameObject = engine.game_state().object(Scenario.first_permanent_of(engine, hero.id))
	var view: MmPlayerView = engine.view_for(hero)

	assert_eq(ReplacementText.event_text(ZoneChangeEvent.new(land, hero.graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.DESTROY), view),
		"Life Land would be destroyed")
	assert_eq(ReplacementText.event_text(ZoneChangeEvent.new(land, hero.graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.ZERO_TOUGHNESS), view),
		"This event")


func test_a_shield_says_how_much_it_has_left_and_whom_it_protects() -> void:
	var shield: ActiveReplacementEffect = ActiveReplacementEffect.created(PreventDamageReplacementEffect.new(), 5, HERO, HEALER, 108,
		[MmReference.to_object(BEARS)] as Array[MmReference], 1, 0)
	var for_player: ActiveReplacementEffect = ActiveReplacementEffect.created(PreventDamageReplacementEffect.new(), 5, HERO, HEALER, 108,
		[MmReference.to_player(VILLAIN)] as Array[MmReference], 3, 0)

	assert_eq(ReplacementText.effect_text(shield, _view()), "Prevent the next 1 damage that would be dealt to Grizzly Bears this turn.")
	assert_eq(ReplacementText.effect_text(for_player, _view()), "Prevent the next 3 damage that would be dealt to Villain this turn.")


func test_a_fog_prevents_all_combat_damage() -> void:
	var fog: PreventDamageReplacementEffect = PreventDamageReplacementEffect.new()
	fog.combat_only = true
	var active: ActiveReplacementEffect = ActiveReplacementEffect.created(fog, 5, HERO, 40, 140, [] as Array[MmReference],
		ActiveReplacementEffect.UNLIMITED, 0)

	assert_eq(ReplacementText.effect_text(active, _view()), "Prevent all combat damage that would be dealt this turn.")


func test_prevention_from_some_sources_names_them() -> void:
	var ward: PreventDamageReplacementEffect = PreventDamageReplacementEffect.new()
	ward.sources = Scenario.of_color(MmCardTypes.CardColor.BLACK)
	var active: ActiveReplacementEffect = ActiveReplacementEffect.created(ward, 5, HERO, HEALER, 108,
		[MmReference.to_object(BEARS)] as Array[MmReference], ActiveReplacementEffect.UNLIMITED, 0)

	assert_eq(ReplacementText.effect_text(active, _view()), "Prevent all damage that would be dealt to Grizzly Bears by black permanents this turn.")


func test_a_regeneration_shield_names_what_it_saves() -> void:
	var active: ActiveReplacementEffect = ActiveReplacementEffect.created(RegenerationReplacementEffect.new(), 5, HERO, BEARS, 107,
		[MmReference.to_object(BEARS)] as Array[MmReference], 1, 0)

	assert_eq(ReplacementText.effect_text(active, _view()), "The next time Grizzly Bears would be destroyed this turn, it regenerates instead.")


func test_an_effects_source_is_found_on_the_battlefield_or_by_its_card_once_it_has_moved() -> void:
	var view: MmPlayerView = _view()
	var salve: MmObjectView = MmObjectView.new()
	salve.id = 55
	salve.card_id = 140
	salve.name = "Healing Salve"
	view.graveyards[HERO] = [salve]
	var from_healer: ActiveReplacementEffect = ActiveReplacementEffect.created(PreventDamageReplacementEffect.new(), 5, HERO, HEALER, 108,
		[] as Array[MmReference], 1, 0)
	var from_spell: ActiveReplacementEffect = ActiveReplacementEffect.created(PreventDamageReplacementEffect.new(), 5, HERO, 40, 140,
		[] as Array[MmReference], 1, 0)
	var from_nowhere: ActiveReplacementEffect = ActiveReplacementEffect.created(PreventDamageReplacementEffect.new(), 5, HERO, 41, 141,
		[] as Array[MmReference], 1, 0)

	assert_eq(ReplacementText.source_of(from_healer, view).id, HEALER)
	assert_eq(ReplacementText.source_name(from_healer, view), "Samite Healer")
	assert_eq(ReplacementText.source_of(from_spell, view).id, 55, "The card it came from, now in the graveyard.")
	assert_eq(ReplacementText.source_name(from_spell, view), "Healing Salve")
	assert_null(ReplacementText.source_of(from_nowhere, view))
	var ability: MmObjectView = MmObjectView.new()
	ability.id = 60
	ability.card_id = MmGameObject.NO_CARD
	view.stack = [ability]
	var from_emblem: ActiveReplacementEffect = ActiveReplacementEffect.created(PreventDamageReplacementEffect.new(), 5, HERO, 42,
		MmGameObject.NO_CARD, [] as Array[MmReference], 1, 0)
	assert_null(ReplacementText.source_of(from_emblem, view), "Having no card is not having the same card.")
	assert_null(ReplacementText.source_of(from_nowhere, view))
	assert_eq(ReplacementText.source_name(from_nowhere, view), "An effect")


func test_a_player_is_called_by_the_name_they_were_given() -> void:
	var names: PlayerNames = PlayerNames.new("Jackson", "Mishra")

	assert_eq(ReplacementText.event_text(DamageEvent.new(3, MmReference.to_player(HERO), 3), _view(), names), "3 damage to Jackson")
	var decision: ChooseReplacementEffectDecision = ChooseReplacementEffectDecision.new(HERO,
		DamageEvent.new(3, MmReference.to_player(VILLAIN), 2), [] as Array[ActiveReplacementEffect])
	assert_eq(ReplacementText.title(decision, _view(), names), "2 damage to Mishra: which applies first?")


func _view() -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var bears: MmObjectView = MmObjectView.new()
	bears.id = BEARS
	bears.card_id = 107
	bears.name = "Grizzly Bears"
	var healer: MmObjectView = MmObjectView.new()
	healer.id = HEALER
	healer.card_id = 108
	healer.name = "Samite Healer"
	view.battlefield = [bears, healer]
	return view
