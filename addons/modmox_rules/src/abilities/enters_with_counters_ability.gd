class_name EntersWithCountersAbility
extends StaticAbility
## "This permanent enters with [amount] [kind] counters on it." (CR 614.1c, 122.6, ADR 0076),
## as on Guiding Hydra: "This creature enters with X +1/+1 counters on it." Its replacement
## effect modifies how its own permanent enters, so it is generated from the entering
## object's own characteristics, wherever that object is coming from, as EntersTappedAbility's
## is (CR 614.12, ADR 0019). [member amount] is worked out as it enters, with the entering
## object as its source, so ChosenXValue reads the X its spell was cast with (CR 107.3m).

@export var kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
@export var amount: MmValue


## The replacement effect this ability generates for its permanent as it enters.
func replacement() -> EntersWithCountersReplacementEffect:
	var effect: EntersWithCountersReplacementEffect = EntersWithCountersReplacementEffect.new()
	effect.kind = kind
	effect.amount = amount
	return effect


func describe() -> String:
	return "enters with counters"
