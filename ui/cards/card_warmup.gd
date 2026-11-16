class_name CardWarmup
extends RefCounted
## Loads what an encounter's cards are drawn from before any of them is shown: each card's
## Frame, the Battlefield Face's border and P/T box for a permanent, and its art, with the
## art of each Emblem. The first time a card is drawn all of that took 10 to 35 ms, in the
## frame the card took off in; done here it is paid once, while the screen is still black
## behind the Scene Fade.
##
## A Frame is kept by the FrameBaker for good. Art is kept loaded only while something
## holds it, so the screen keeps its warmup for as long as it shows the encounter.

## Art key → the art, held so that it stays loaded.
var _art: Dictionary[String, Texture2D] = {}


## Loads everything the cards and Emblems of [param setup] are drawn from.
func warm(setup: MmEncounterSetup) -> void:
	for look: CardLook in looks(setup):
		var spec: FrameSpec = FrameSpec.of(look)
		FrameBaker.texture(spec)
		if look.is_permanent():
			FrameBaker.field_border_texture(spec)
		if spec.is_creature:
			BattlefieldFace.power_toughness_texture(spec)
	for key: String in art_keys(setup):
		var art: Texture2D = ArtLibrary.shared().texture(key)
		if art != null:
			_art[key] = art


## How many pictures are held.
func art_count() -> int:
	return _art.size()


## The look of each different card in the decks of [param setup], as printed with its
## Modifications: one for each Card Definition, and one more for each Run Card that has
## any, which may have a Frame of its own.
static func looks(setup: MmEncounterSetup) -> Array[CardLook]:
	var found: Array[CardLook] = []
	var seen: Dictionary[MmCardDefinition, bool] = {}
	for player: MmPlayerSetup in [setup.hero, setup.villain]:
		for run_card: MmRunCard in player.deck:
			if not run_card.modifications.is_empty():
				found.append(CardLook.of_characteristics(MmCharacteristics.printed(run_card.flatten()), _art_key(run_card.base)))
			elif not seen.has(run_card.base):
				seen[run_card.base] = true
				found.append(CardLook.of_definition(run_card.base))
	return found


## The art key of each card and Emblem of [param setup] that has one, each once.
static func art_keys(setup: MmEncounterSetup) -> Array[String]:
	var keys: Array[String] = []
	for player: MmPlayerSetup in [setup.hero, setup.villain]:
		for run_card: MmRunCard in player.deck:
			_add(keys, _art_key(run_card.base))
		for emblem: MmCardDefinition in player.emblems:
			_add(keys, EncounterPresenter.emblem_art_key(emblem))
	return keys


static func _add(keys: Array[String], key: String) -> void:
	if key != "" and not keys.has(key):
		keys.append(key)


## The art of a card is named after its Card Definition's file.
static func _art_key(definition: MmCardDefinition) -> String:
	return definition.resource_path.get_file().get_basename()
