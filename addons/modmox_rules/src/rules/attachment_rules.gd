class_name AttachmentRules
extends RefCounted
## What a permanent may be attached to (CR 301.5, 303.4, 701.3). Asked as something is
## attached, and again by state-based actions for everything already attached (CR 704.5m,
## 704.5n).

const EQUIPMENT: String = "Equipment"
const AURA: String = "Aura"


## Whether [param attachment] may be, or stay, attached to [param to]. Null for
## [param to] is something that no longer exists.
static func can_be_attached(state: MmGameState, attachment: MmGameObject, to: MmGameObject) -> bool:
	if to == null or to == attachment or to.zone() != state.battlefield or attachment.zone() != state.battlefield:
		return false
	# CR 301.5: an Equipment is attached only to a creature.
	if state.characteristics_of(attachment).subtypes.has(EQUIPMENT) \
			and not state.characteristics_of(to).has_card_type(MmCardTypes.CardType.CREATURE):
		return false
	# CR 301.5c: an Equipment that's also a creature can't equip a creature unless it has
	# reconfigure, and one with reconfigure stops being a creature once attached (LayerEngine).
	if state.characteristics_of(attachment).subtypes.has(EQUIPMENT) \
			and state.characteristics_of(attachment).has_card_type(MmCardTypes.CardType.CREATURE) \
			and not state.characteristics_of(attachment).has_ability(ReconfigureAbility):
		return false
	# CR 303.4a: an Aura is attached only to what its enchant ability allows.
	for ability: MmAbility in state.characteristics_of(attachment).abilities:
		var enchant: EnchantAbility = ability as EnchantAbility
		if enchant != null and not enchant.may_enchant(state, to, attachment):
			return false
	# CR 702.16d: a permanent can't be enchanted or equipped by anything it has protection from.
	return not ProtectionAbility.protects(state, to, attachment.id)
