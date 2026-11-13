class_name CardLook
extends RefCounted
## Everything a card is drawn from: its characteristics as the viewer sees them, whether it
## is tapped, which art it uses and its rules text. Built the same way outside an encounter
## (from printed characteristics) and inside one (from a Player View), so a deck screen and
## the battlefield draw an unaffected card identically (ADR 0009).

## Power or toughness above its printed value prints green, below it red (A221).
const RAISED: Color = Color("#1f7a2a")
const LOWERED: Color = Color("#b3261e")

## What kind of thing this is the look of. An Emblem and a Potion are not cards and have no
## card type (ADR 0036): whoever makes the look says which it is, with of_held().
enum Kind { CARD, EMBLEM, POTION }

var kind: Kind = Kind.CARD
var name: String = ""
## In WUBRG order; empty means colorless.
var colors: Array[MmCardTypes.CardColor] = []
var card_types: Array[MmCardTypes.CardType] = []
var supertypes: Array[MmCardTypes.Supertype] = []
var subtypes: Array[String] = []
## Null for a card with no mana cost, which is not the same as {0}.
var mana_cost: MmManaCost = null
var power: int = 0
var toughness: int = 0
var base_power: int = 0
var base_toughness: int = 0
var is_power_variable: bool = false
var is_toughness_variable: bool = false
## Damage marked on a creature this turn, shown on a Damage Chip. Always 0 as printed.
var damage_marked: int = 0
## Every ability it has right now, including granted ones.
var abilities: Array[MmAbility] = []
var is_tapped: bool = false
## Which art to draw: the file name of the card's Card Definition, without its extension.
## Art belongs to the Card Definition, so a renamed Run Card keeps its art (A229).
var art_key: String = ""
## The rules text to print, generated from the abilities by AbilityText whenever a look
## is made from characteristics or a view (A333). Only a basic land's is in parentheses:
## what a keyword means is a Reminder, listed by the Inspector (ADR 0033).
var rules_text: String = ""

## For an Emblem or a Potion: its abilities' text, one to an entry in the order of
## abilities, and which of them are Spent (ADR 0036), so each can be drawn apart.
var rules_lines: Array[String] = []
var spent_ability_indexes: Array[int] = []


## The look of a card outside any encounter, from its printed characteristics.
static func of_characteristics(characteristics: MmCharacteristics, card_art_key: String = "") -> CardLook:
	var look: CardLook = CardLook.new()
	look.name = characteristics.name
	look.colors = characteristics.colors.duplicate()
	look.card_types = characteristics.card_types.duplicate()
	look.supertypes = characteristics.supertypes.duplicate()
	look.subtypes = characteristics.subtypes.duplicate()
	look.mana_cost = characteristics.mana_cost
	look.power = characteristics.power
	look.toughness = characteristics.toughness
	look.base_power = characteristics.base_power
	look.base_toughness = characteristics.base_toughness
	look.is_power_variable = characteristics.is_power_variable
	look.is_toughness_variable = characteristics.is_toughness_variable
	look.abilities = characteristics.abilities.duplicate()
	look.art_key = card_art_key
	look.rules_text = AbilityText.of_card(look.abilities, look.card_types, look.supertypes, look.name)
	return look


## The look of a Game Object as a Player View shows it.
static func of_view(view: MmObjectView, card_art_key: String = "") -> CardLook:
	var look: CardLook = CardLook.new()
	look.name = view.name
	look.colors = view.colors.duplicate()
	look.card_types = view.card_types.duplicate()
	look.supertypes = view.supertypes.duplicate()
	look.subtypes = view.subtypes.duplicate()
	look.mana_cost = view.mana_cost
	look.power = view.power
	look.toughness = view.toughness
	look.base_power = view.base_power
	look.base_toughness = view.base_toughness
	look.is_power_variable = view.is_power_variable
	look.is_toughness_variable = view.is_toughness_variable
	look.abilities = view.abilities.duplicate()
	look.is_tapped = view.is_tapped
	look.damage_marked = view.damage_marked
	look.art_key = card_art_key
	look.rules_text = AbilityText.of_card(look.abilities, look.card_types, look.supertypes, look.name)
	return look


## The look of an Emblem or a Potion as a Player View shows it: [param held_kind] says
## which, and its text calls it "this emblem" or "this potion". Also the look of a Potion's
## ability on the stack, which keeps the Potion's art once the Potion is gone.
static func of_held(view: MmObjectView, held_art_key: String, held_kind: Kind) -> CardLook:
	var look: CardLook = of_view(view, held_art_key)
	look.kind = held_kind
	look.rules_lines = AbilityText.lines_of(look.abilities, noun_of(held_kind))
	look.rules_text = "\n".join(look.rules_lines)
	look.spent_ability_indexes = view.spent_ability_indexes.duplicate()
	return look


## The look of [param potion]'s ability on the stack, [param view]: the Potion itself is
## gone by then, so its name and what it does come from what it was authored as (ADR 0033).
static func of_potion_ability(view: MmObjectView, potion: MmCardDefinition, held_art_key: String) -> CardLook:
	var look: CardLook = of_held(view, held_art_key, Kind.POTION)
	look.name = potion.name
	look.abilities = potion.abilities.duplicate()
	look.rules_lines = AbilityText.lines_of(look.abilities, noun_of(Kind.POTION))
	look.rules_text = "\n".join(look.rules_lines)
	return look


## What a thing of [param held_kind] calls itself in its own text, or "" for a card, which
## AbilityText.self_noun() names from its types.
static func noun_of(held_kind: Kind) -> String:
	match held_kind:
		Kind.EMBLEM:
			return AbilityText.EMBLEM_NOUN
		Kind.POTION:
			return AbilityText.POTION_NOUN
	return ""


## The type line the GUI writes for an Emblem or a Potion, neither of which is a card type
## (ADR 0033, A536); "" for a card, whose type line comes from its types.
func held_type_line() -> String:
	match kind:
		Kind.EMBLEM:
			return "Emblem"
		Kind.POTION:
			return "Potion"
	return ""


## Whether the ability at [param ability_index] is a once-each-game ability that has been
## activated.
func is_ability_spent(ability_index: int) -> bool:
	return spent_ability_indexes.has(ability_index)


## The look of [param definition] as printed, keyed to its file's art.
static func of_definition(definition: MmCardDefinition) -> CardLook:
	return of_characteristics(MmCharacteristics.printed(definition), definition.resource_path.get_file().get_basename())


func has_card_type(card_type: MmCardTypes.CardType) -> bool:
	return card_types.has(card_type)


func is_creature() -> bool:
	return has_card_type(MmCardTypes.CardType.CREATURE)


func is_permanent() -> bool:
	for card_type: MmCardTypes.CardType in MmCharacteristics.PERMANENT_TYPES:
		if has_card_type(card_type):
			return true
	return false


## The type line: supertypes, card types, then " — " and the subtypes.
func type_line() -> String:
	var words: PackedStringArray = []
	for supertype: MmCardTypes.Supertype in supertypes:
		words.append((MmCardTypes.Supertype.keys()[supertype] as String).capitalize())
	for card_type: MmCardTypes.CardType in card_types:
		words.append((MmCardTypes.CardType.keys()[card_type] as String).capitalize())
	var line: String = " ".join(words)
	if not subtypes.is_empty():
		line += " — " + " ".join(PackedStringArray(subtypes))
	return line


## Rules text as a Card Face prints it: anything in parentheses is left off, except on a
## basic land, whose parenthesized line is all it has.
func printed_rules_text() -> String:
	if supertypes.has(MmCardTypes.Supertype.BASIC):
		return rules_text
	var lines: PackedStringArray = []
	for line: String in rules_text.split("\n"):
		var kept: String = RegEx.create_from_string(" ?\\([^)]*\\)").sub(line, "", true).strip_edges()
		if kept != "":
			lines.append(kept)
	return "\n".join(lines)


## Power, "/" and toughness, with "*" for a number a characteristic-defining ability works
## out (CR 604.3).
func power_toughness_texts() -> Array[String]:
	return [
		"*" if is_power_variable else str(power), "/",
		"*" if is_toughness_variable else str(toughness),
	]


## The color of each of power_toughness_texts().
func power_toughness_colors() -> Array[Color]:
	return [_change_color(power, base_power), Color.BLACK, _change_color(toughness, base_toughness)]


static func _change_color(current: int, printed: int) -> Color:
	if current > printed:
		return RAISED
	if current < printed:
		return LOWERED
	return Color.BLACK
