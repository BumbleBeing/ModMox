class_name EntersTappedAbility
extends StaticAbility
## "This permanent enters tapped." (CR 614.1c), as on Haunted Mire. Its replacement effect
## modifies how its own permanent enters, so it is generated from the entering object's own
## characteristics, wherever that object is coming from (CR 614.12, ADR 0019).


## The replacement effect this ability generates for its permanent as it enters.
func replacement() -> EntersTappedReplacementEffect:
	return EntersTappedReplacementEffect.new()


func describe() -> String:
	return "enters tapped"
