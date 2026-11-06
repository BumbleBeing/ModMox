class_name MmCharacteristics
extends RefCounted
## A Game Object's current characteristics (CR 109.3), after every effect that applies.
## Produced by MmGameState.characteristics_of() during an encounter, and by printed() for a
## card outside any encounter, such as on a deck or reward screen (ADR 0009). Treat it as
## read-only.

var name: String = ""
var card_types: Array[MmCardTypes.CardType] = []
var supertypes: Array[MmCardTypes.Supertype] = []
var subtypes: Array[String] = []
## Null for a card with no mana cost.
var mana_cost: MmManaCost = null
## CR 202.2: worked out from the mana cost, in WUBRG order. Empty means colorless.
var colors: Array[MmCardTypes.CardColor] = []
## Written abilities first, then abilities granted by rules, in a fixed order.
var abilities: Array[MmAbility] = []


## The characteristics a Card Definition has before anything in a game affects it: what
## would be printed on the card. The in-game query starts from exactly this, so a deck
## screen and the battlefield agree about any unaffected card.
static func printed(definition: MmCardDefinition) -> MmCharacteristics:
	var result: MmCharacteristics = MmCharacteristics.new()
	result.name = definition.name
	result.card_types = definition.card_types.duplicate()
	result.supertypes = definition.supertypes.duplicate()
	result.subtypes = definition.subtypes.duplicate()
	result.mana_cost = definition.mana_cost
	if definition.mana_cost != null:
		result.colors = definition.mana_cost.colors()
	result.abilities = definition.abilities.duplicate()
	# CR 305.6: each basic land type grants "{T}: Add [its mana]", in subtype order.
	if result.has_card_type(MmCardTypes.CardType.LAND):
		for subtype: String in result.subtypes:
			if MmCardTypes.BASIC_LAND_TYPES.has(subtype):
				result.abilities.append(_basic_land_ability(subtype))
	return result


func has_card_type(card_type: MmCardTypes.CardType) -> bool:
	return card_types.has(card_type)


func has_supertype(supertype: MmCardTypes.Supertype) -> bool:
	return supertypes.has(supertype)


## CR 202.3: 0 for a card with no mana cost.
func mana_value() -> int:
	return 0 if mana_cost == null else mana_cost.mana_value()


## The intrinsic mana ability of each basic land type, built once and shared. It is a
## read-only Resource like any written ability.
static var _basic_land_abilities: Dictionary[String, ActivatedAbility] = {}


static func _basic_land_ability(land_type: String) -> ActivatedAbility:
	if not _basic_land_abilities.has(land_type):
		var one: ConstantValue = ConstantValue.new()
		one.value = 1
		var add_mana: AddManaEffect = AddManaEffect.new()
		add_mana.mana_type = MmCardTypes.BASIC_LAND_TYPES[land_type]
		add_mana.amount = one
		var ability: ActivatedAbility = ActivatedAbility.new()
		ability.costs = [TapCost.new()]
		ability.effects = [add_mana]
		_basic_land_abilities[land_type] = ability
	return _basic_land_abilities[land_type]
