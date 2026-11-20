class_name MmCharacteristics
extends RefCounted
## A Game Object's current characteristics (CR 109.3), after every effect that applies.
## Produced by MmGameState.characteristics_of() during an encounter, and by printed() for a
## card outside any encounter, such as on a deck or reward screen (ADR 0009). Treat it as
## read-only.

const PERMANENT_TYPES: Array[MmCardTypes.CardType] = [
	MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE,
	MmCardTypes.CardType.ENCHANTMENT, MmCardTypes.CardType.LAND,
]

var name: String = ""
var card_types: Array[MmCardTypes.CardType] = []
var supertypes: Array[MmCardTypes.Supertype] = []
var subtypes: Array[String] = []
## Null for a card with no mana cost.
var mana_cost: MmManaCost = null
## CR 105.2: worked out from the mana cost (CR 202.2) and the color indicator (CR 204), in
## WUBRG order. Empty means colorless.
var colors: Array[MmCardTypes.CardColor] = []
## The printed power and toughness (CR 208.1), before any effect.
var base_power: int = 0
var base_toughness: int = 0
## The current power and toughness, after every effect.
var power: int = 0
var toughness: int = 0
## CR 604.3: set by a characteristic-defining ability, so a card prints "*" for it.
var is_power_variable: bool = false
var is_toughness_variable: bool = false
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
	var from_cost: Array[MmCardTypes.CardColor] = []
	if definition.mana_cost != null:
		from_cost = definition.mana_cost.colors()
	for color: MmCardTypes.CardColor in MmCardTypes.CardColor.values():
		if from_cost.has(color) or definition.color_indicator.has(color):
			result.colors.append(color)
	result.base_power = definition.power
	result.base_toughness = definition.toughness
	# The layer engine changes these in an encounter (CR 613.4).
	result.power = result.base_power
	result.toughness = result.base_toughness
	result.abilities = definition.abilities.duplicate()
	for ability: MmAbility in result.abilities:
		var defining: CharacteristicDefiningAbility = ability as CharacteristicDefiningAbility
		if defining != null:
			result.is_power_variable = result.is_power_variable or defining.power != null
			result.is_toughness_variable = result.is_toughness_variable or defining.toughness != null
	result.add_basic_land_abilities()
	return result


## CR 305.6, 305.7: a land has "{T}: Add [its mana]" for each basic land type it has, in
## subtype order, after its other abilities. One it already has is not added again, so the
## layer engine calls this again after layer 4 for the types an effect added.
func add_basic_land_abilities() -> void:
	if not has_card_type(MmCardTypes.CardType.LAND):
		return
	for subtype: String in subtypes:
		if MmCardTypes.BASIC_LAND_TYPES.has(subtype):
			var ability: ActivatedAbility = _basic_land_ability(subtype)
			if not abilities.has(ability):
				abilities.append(ability)


func has_card_type(card_type: MmCardTypes.CardType) -> bool:
	return card_types.has(card_type)


## Whether this has an ability of [param kind] (a script such as FirstStrikeAbility),
## including abilities that kind's subclasses describe.
func has_ability(kind: Script) -> bool:
	for ability: MmAbility in abilities:
		if is_instance_of(ability, kind):
			return true
	return false


## CR 110.4: artifacts, creatures, enchantments and lands are permanent card types.
func is_permanent() -> bool:
	for card_type: MmCardTypes.CardType in PERMANENT_TYPES:
		if has_card_type(card_type):
			return true
	return false


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
