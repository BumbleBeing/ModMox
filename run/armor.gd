class_name Armor
extends Resource
## An Item the Hero wears (game glossary, game ADR 0106): a Helm, Cuirass or Greaves, filling
## the Armor Slot of that name. It holds one or more Starting Conditions, which count only
## while it is Worn, an Armor Icon, and a price of its own, since it has no Rarity for ADR
## 0070's formula to work one out from. Its words are written from its Starting Conditions,
## never by hand.

## The Hero's three places for Armor, in the order their Starting Conditions apply.
enum Slot { HELM = 0, CUIRASS = 1, GREAVES = 2 }

const SLOT_NAMES: Dictionary[Slot, String] = { Slot.HELM: "Helm", Slot.CUIRASS: "Cuirass", Slot.GREAVES: "Greaves" }
## An Armor Icon's size in pixels, each way.
const ICON_SIZE: int = 32

@export var name: String = ""
@export var slot: Slot = Slot.HELM
## What it changes about how the Hero starts an encounter while it is Worn, in the order they
## apply.
@export var starting_conditions: Array[StartingCondition] = []
## Its 32 × 32 Armor Icon, in ui/sprites/armor/ named after its file.
@export var icon: Texture2D = null
## What a Store sells it for (milestone 24), usually 150 to 300; a shop buys it at a third.
@export var price: int = 0


## The name of [param armor_slot], as the Satchel's type line writes it: "Helm".
static func slot_name(armor_slot: Slot) -> String:
	return SLOT_NAMES[armor_slot]


## What is wrong with the Armor's shape, one reason to an entry, or nothing when it is an
## Armor the game can hand out.
func problems() -> Array[String]:
	var found: Array[String] = []
	if name == "":
		found.append("An Armor needs a name.")
	if starting_conditions.is_empty():
		found.append("An Armor needs at least one Starting Condition.")
	for index: int in starting_conditions.size():
		if starting_conditions[index] == null:
			found.append("Starting Condition %d is missing." % index)
		else:
			found.append_array(starting_conditions[index].problems())
	if icon == null:
		found.append("An Armor needs an Armor Icon.")
	elif icon.get_size() != Vector2(ICON_SIZE, ICON_SIZE):
		found.append("An Armor Icon is 32 × 32.")
	if price <= 0:
		found.append("An Armor needs a price.")
	return found
