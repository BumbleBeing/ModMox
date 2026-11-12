class_name FrameSpec
extends RefCounted
## Which Frame a card is drawn with, worked out from its characteristics alone, so a card
## whose colors or types change gets the right Frame automatically (ADR 0009). It turns
## into a stack of FrameLayers, bottom to top. A colored artifact keeps its colors' Frame
## inside the artifact Frame's border.

## Frame letters, in WUBRG order.
const LETTERS: String = "wubrg"
## Two-color frames draw the left color first. Not always WUBRG order: red-white and
## green-white are reversed, so a pair is looked up here rather than sorted.
const PAIR_ORDER: Array[String] = ["wu", "wb", "ub", "ur", "br", "bg", "rg", "rw", "gw", "gu"]

## The color category's letters in drawing order: none, one, a pair in PAIR_ORDER, or
## three or more in WUBRG order.
var letters: Array[String] = []
var is_land: bool = false
var is_artifact: bool = false
var is_creature: bool = false
var is_legendary: bool = false


## The Frame for [param look]. A land's color category follows the colors of mana it can
## produce; any other card's follows its colors.
static func of(look: CardLook) -> FrameSpec:
	var spec: FrameSpec = FrameSpec.new()
	spec.is_land = look.has_card_type(MmCardTypes.CardType.LAND)
	spec.is_artifact = look.has_card_type(MmCardTypes.CardType.ARTIFACT)
	spec.is_creature = look.is_creature()
	spec.is_legendary = look.supertypes.has(MmCardTypes.Supertype.LEGENDARY)
	var found: Array[String] = []
	if spec.is_land:
		for type: MmMana.Type in _mana_produced(look.abilities):
			found.append(LETTERS[type])
	else:
		for color: MmCardTypes.CardColor in look.colors:
			found.append(LETTERS[color])
	found.sort_custom(func(a: String, b: String) -> bool: return LETTERS.find(a) < LETTERS.find(b))
	if found.size() == 2:
		for pair: String in PAIR_ORDER:
			if pair.contains(found[0]) and pair.contains(found[1]):
				found = [pair[0], pair[1]]
	spec.letters = found
	return spec


## A short key naming this Frame, such as "land2:rw" or "card1:w:pt:crown". Equal specs
## have equal keys, so baked Frames are cached by it.
func key() -> String:
	var text: String = "%s%d:%s" % ["land" if is_land else "card", letters.size(), "".join(letters)]
	if is_artifact and not is_land:
		text += ":artifact"
	if is_creature:
		text += ":pt"
	if is_legendary:
		text += ":crown"
	return text


## This Frame without its P/T box, as a Battlefield Face's border uses it.
func without_power_toughness() -> FrameSpec:
	var copy: FrameSpec = FrameSpec.new()
	copy.letters = letters.duplicate()
	copy.is_land = is_land
	copy.is_artifact = is_artifact
	copy.is_legendary = is_legendary
	return copy


## The layers to draw, bottom to top.
func layers() -> Array[FrameLayer]:
	var result: Array[FrameLayer] = []
	var folder: String = "lands" if is_land else "frames"
	match letters.size():
		0:
			result.append(FrameLayer.full("lands/c" if is_land else ("frames/a" if is_artifact else "frames/c")))
		1:
			result.append(FrameLayer.full(folder + "/" + letters[0]))
		2:
			var left: String = folder + "/" + letters[0]
			var right: String = folder + "/" + letters[1]
			result.append(FrameLayer.full("lands/c" if is_land else "frames/m"))
			result.append(FrameLayer.full(left, ["rules"]))
			result.append(FrameLayer.full(right, ["rules", "right_half"]))
			result.append(FrameLayer.full(left, ["pinline"]))
			result.append(FrameLayer.full(right, ["pinline", "right_half"]))
		_:
			result.append(FrameLayer.full(folder + "/m"))
	if has_artifact_border():
		result.append(FrameLayer.full("frames/a", ["frame"]))
	if is_creature:
		result.append(FrameLayer.placed(power_toughness_image(), CardGeometry.POWER_TOUGHNESS))
	if is_legendary:
		result.append(FrameLayer.cover())
		result.append(FrameLayer.placed("crowns/" + _left_crown(), CardGeometry.CROWN))
		if letters.size() == 2:
			result.append(FrameLayer.placed("crowns/" + letters[1], CardGeometry.CROWN, ["right_half"]))
	return result


## Whether the artifact frame's outer border is laid over a colored frame: a colored
## artifact that is not a land. Its P/T box and crown still follow its colors.
func has_artifact_border() -> bool:
	return is_artifact and not is_land and not letters.is_empty()


## The P/T box image: the color for one color, gold for a two-color or multicolor nonland,
## colorless for a two-color land, and artifact or colorless for no colors.
func power_toughness_image() -> String:
	match letters.size():
		0:
			return "pt/a" if is_artifact else "pt/c"
		1:
			return "pt/" + letters[0]
		2:
			return "pt/c" if is_land else "pt/m"
	return "pt/m"


func _left_crown() -> String:
	match letters.size():
		0:
			return "a" if is_artifact else ("l" if is_land else "c")
		1, 2:
			return letters[0]
	return "m"


## The colors of mana [param abilities] can add, once each, ignoring colorless.
static func _mana_produced(abilities: Array[MmAbility]) -> Array[MmMana.Type]:
	var found: Array[MmMana.Type] = []
	for ability: MmAbility in abilities:
		if not ability is ActivatedAbility:
			continue
		for effect: MmEffect in (ability as ActivatedAbility).effects:
			var add_mana: AddManaEffect = effect as AddManaEffect
			if add_mana != null and add_mana.mana_type != MmMana.Type.COLORLESS and not found.has(add_mana.mana_type):
				found.append(add_mana.mana_type)
	return found
