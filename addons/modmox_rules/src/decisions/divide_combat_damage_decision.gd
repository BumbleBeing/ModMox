class_name DivideCombatDamageDecision
extends MmPendingDecision
## A creature's controller divides its combat damage as they choose: an attacker's among
## the creatures blocking it (CR 510.1c; there is no damage assignment order), or a
## blocker's among the attackers it blocks (CR 510.1d). With trample, the player
## it attacks is a recipient too, but may be assigned damage only once every blocker has
## been assigned lethal damage (CR 702.19b). Answer: an Array of non-negative amounts, one
## per entry of [member recipients], adding up to [member amount] (ADR 0016).

## The creature whose damage is divided.
var source_id: int
## The combat damage to divide: its power.
var amount: int
## The creatures it is blocked by, or blocking, in ID order, then the player being attacked
## if an attacker has trample.
var recipients: Array[MmReference]
## For each creature, how much more damage is lethal to it, counting damage already marked
## and damage assigned to it earlier in this step, and deathtouch (CR 702.2c).
var lethal_amounts: Array[int]


func _init(deciding_player_id: int, dividing_id: int, damage: int, damage_recipients: Array[MmReference], lethal: Array[int]) -> void:
	super(deciding_player_id)
	source_id = dividing_id
	amount = damage
	recipients = damage_recipients.duplicate()
	lethal_amounts = lethal.duplicate()


## Whether the player being attacked is a recipient, last in the list (trample).
func includes_player() -> bool:
	return not recipients.is_empty() and recipients.back().is_player()


func validate(answer: Variant) -> String:
	if typeof(answer) != TYPE_ARRAY:
		return "Expected a list of amounts, got %s." % type_string(typeof(answer))
	var amounts: Array = answer
	if amounts.size() != recipients.size():
		return "Give one amount for each of the %d recipients." % recipients.size()
	var total: int = 0
	for entry: Variant in amounts:
		if typeof(entry) != TYPE_INT or (entry as int) < 0:
			return "%s is not an amount of damage." % [entry]
		total += entry as int
	if total != amount:
		return "Assign exactly %d damage, not %d." % [amount, total]
	if includes_player() and (amounts.back() as int) > 0:
		for index: int in lethal_amounts.size():
			if (amounts[index] as int) < lethal_amounts[index]:
				return "Each blocker must be assigned lethal damage before the player (CR 702.19b)."
	return ""


func describe() -> String:
	return "player %d: divide %d combat damage of object %d among %d recipients" % [player_id, amount, source_id, recipients.size()]
