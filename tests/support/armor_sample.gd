extends RefCounted
## Armor and Starting Conditions made in code for milestone 23's tests (game ADR 0106), each
## well shaped unless a test spoils it: an Armor Icon of its slot's, drawn already, and a
## price of 200.

const DIVINERS_BOON: String = "res://content/emblems/diviners_boon.tres"
const ELECTROMANCERS_BOON: String = "res://content/emblems/electromancers_boon.tres"
const ICONS: Dictionary[Armor.Slot, String] = {
	Armor.Slot.HELM: "res://ui/sprites/armor/lionguard_helm.png",
	Armor.Slot.CUIRASS: "res://ui/sprites/armor/sunwardens_cuirass.png",
	Armor.Slot.GREAVES: "res://ui/sprites/armor/thornwalker_greaves.png",
}
const PRICE: int = 200


## An Armor named [param armor_name] for [param slot], holding each of [param conditions]
## (Starting Conditions) in order.
static func armor(armor_name: String, slot: Armor.Slot, conditions: Array) -> Armor:
	var made: Armor = Armor.new()
	made.name = armor_name
	made.slot = slot
	for condition: StartingCondition in conditions:
		made.starting_conditions.append(condition)
	made.icon = load(ICONS[slot]) as Texture2D
	made.price = PRICE
	return made


## [param amount] more starting life, or less when it is negative.
static func life(amount: int) -> LifeStartingCondition:
	var condition: LifeStartingCondition = LifeStartingCondition.new()
	condition.amount = amount
	return condition


static func fewer_cards(count: int) -> OpeningHandStartingCondition:
	var condition: OpeningHandStartingCondition = OpeningHandStartingCondition.new()
	condition.fewer_cards = count
	return condition


static func mulligans(count: int) -> FreeMulliganStartingCondition:
	var condition: FreeMulliganStartingCondition = FreeMulliganStartingCondition.new()
	condition.amount = count
	return condition


## The Emblem whose file is [param path].
static func emblem(path: String) -> EmblemStartingCondition:
	var condition: EmblemStartingCondition = EmblemStartingCondition.new()
	condition.emblem = load(path) as MmCardDefinition
	return condition
