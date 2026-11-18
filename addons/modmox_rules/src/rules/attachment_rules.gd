class_name AttachmentRules
extends RefCounted
## What a permanent may be attached to (CR 301.5, 701.3). Asked as something is attached,
## and again by state-based actions for everything already attached (CR 704.5n).
# Later: Auras, whose enchant ability says what they may be attached to (CR 303.4), and
# Equipment that is also a creature, which can't equip anything (CR 301.5c).

const EQUIPMENT: String = "Equipment"


## Whether [param attachment] may be, or stay, attached to [param to]. Null for
## [param to] is something that no longer exists.
static func can_be_attached(state: MmGameState, attachment: MmGameObject, to: MmGameObject) -> bool:
	if to == null or to == attachment or to.zone() != state.battlefield or attachment.zone() != state.battlefield:
		return false
	# CR 301.5: an Equipment is attached only to a creature.
	if state.characteristics_of(attachment).subtypes.has(EQUIPMENT) \
			and not state.characteristics_of(to).has_card_type(MmCardTypes.CardType.CREATURE):
		return false
	# CR 702.16d: a permanent can't be equipped by an Equipment it has protection from.
	return not ProtectionAbility.protects(state, to, attachment.id)
