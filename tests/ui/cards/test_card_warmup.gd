extends GutTest
## Before an encounter is shown, the Frames and art its cards are drawn from are loaded, so
## that the first time a card is drawn costs no more than any other time.

const CARDS: String = "res://content/cards/alpha/"
const ART: String = "res://content/art/"


func before_each() -> void:
	FrameBaker.forget_baked()


func test_each_card_of_both_decks_is_listed_once() -> void:
	var setup: MmEncounterSetup = _setup(["grizzly_bears", "grizzly_bears", "forest"], ["lightning_bolt", "forest"])

	var names: Array[String] = []
	for look: CardLook in CardWarmup.looks(setup):
		names.append(look.name)
	names.sort()

	assert_eq(names, ["Forest", "Grizzly Bears", "Lightning Bolt"] as Array[String])


func test_a_card_with_a_modification_is_listed_as_it_is_with_it() -> void:
	var setup: MmEncounterSetup = _setup(["grizzly_bears"], ["grizzly_bears"])
	var red: AddManaCostModification = AddManaCostModification.new()
	red.cost = MmManaCost.new()
	red.cost.symbols = [MmMana.Type.RED] as Array[MmMana.Type]
	setup.hero.deck[0].modifications = [red] as Array[MmModification]

	var keys: Array[String] = []
	for look: CardLook in CardWarmup.looks(setup):
		keys.append(FrameSpec.of(look).key())
	keys.sort()

	assert_eq(keys, ["card1:g:pt", "card2:rg:pt"] as Array[String], "The Villain's is green; the Hero's is red as well.")


func test_art_keys_name_each_card_and_each_emblem_with_art() -> void:
	var setup: MmEncounterSetup = _setup(["grizzly_bears", "forest"], ["grizzly_bears"])
	setup.hero.emblems = [load("res://content/emblems/diviners_boon.tres") as MmCardDefinition] as Array[MmCardDefinition]

	var keys: Array[String] = CardWarmup.art_keys(setup)
	keys.sort()

	assert_eq(keys, ["emblems/diviners_boon", "forest", "grizzly_bears"] as Array[String])


func test_warming_bakes_the_frame_of_every_card() -> void:
	var setup: MmEncounterSetup = _setup(["grizzly_bears"], ["lightning_bolt"])
	var bears: FrameSpec = FrameSpec.of(CardLook.of_definition(_card("grizzly_bears")))
	var bolt: FrameSpec = FrameSpec.of(CardLook.of_definition(_card("lightning_bolt")))
	assert_false(FrameBaker.has_texture(bears), "Nothing is baked before.")

	CardWarmup.new().warm(setup)

	assert_true(FrameBaker.has_texture(bears))
	assert_true(FrameBaker.has_texture(bolt))


func test_warming_makes_the_battlefield_border_of_a_permanent_only() -> void:
	var setup: MmEncounterSetup = _setup(["grizzly_bears"], ["lightning_bolt"])

	CardWarmup.new().warm(setup)

	assert_true(FrameBaker.has_field_border_texture(FrameSpec.of(CardLook.of_definition(_card("grizzly_bears")))))
	assert_false(FrameBaker.has_field_border_texture(FrameSpec.of(CardLook.of_definition(_card("lightning_bolt")))),
			"An instant is never drawn on the battlefield.")


func test_warmed_art_stays_loaded_for_as_long_as_the_warmup_is_kept() -> void:
	var setup: MmEncounterSetup = _setup(["grizzly_bears"], ["grizzly_bears"])
	var warmup: CardWarmup = CardWarmup.new()

	warmup.warm(setup)

	assert_true(ResourceLoader.has_cached(ART + "grizzly_bears.jpg"))
	assert_eq(warmup.art_count(), 1)


func test_a_card_with_no_art_is_passed_over() -> void:
	var setup: MmEncounterSetup = _setup(["grizzly_bears"], ["grizzly_bears"])
	var artless: MmCardDefinition = _card("grizzly_bears").duplicate() as MmCardDefinition
	setup.villain.deck = [_run_card(artless)] as Array[MmRunCard]
	var warmup: CardWarmup = CardWarmup.new()

	warmup.warm(setup)

	assert_eq(warmup.art_count(), 1, "Only the Hero's card has a file to name its art.")


func _setup(hero: Array[String], villain: Array[String]) -> MmEncounterSetup:
	var setup: MmEncounterSetup = MmEncounterSetup.new()
	setup.hero = _player(hero)
	setup.villain = _player(villain)
	return setup


func _player(names: Array[String]) -> MmPlayerSetup:
	var player: MmPlayerSetup = MmPlayerSetup.new()
	for card_name: String in names:
		player.deck.append(_run_card(_card(card_name)))
	return player


func _run_card(definition: MmCardDefinition) -> MmRunCard:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = definition
	return run_card


func _card(card_name: String) -> MmCardDefinition:
	return load(CARDS + card_name + ".tres") as MmCardDefinition

