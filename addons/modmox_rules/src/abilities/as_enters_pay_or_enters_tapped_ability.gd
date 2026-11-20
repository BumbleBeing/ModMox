class_name AsEntersPayOrEntersTappedAbility
extends StaticAbility
## "As this land enters, you may pay 2 life. If you don't, it enters tapped." (CR 614.1c,
## 614.12), as on Temple Garden. It does nothing on the battlefield. Played, its controller
## is asked first whether to pay [member cost] (a ChooseYesOrNoDecision with an entry cost),
## while it is still in the hand; the zone change carries the answer (ADR 0052). Unless the
## move says the cost was paid, it generates an EntersTappedReplacementEffect for its own
## entering, as EntersTappedAbility does, so one that enters some other way enters tapped.
# Later: ask it however its permanent enters (a search, a return), once a card can put one
# onto the battlefield.

## What paying lets it enter untapped: a PayLifeCost for Temple Garden. Card data, never
## changed.
@export var cost: MmCost


## The replacement effect this ability generates for its permanent as it enters unpaid.
func replacement() -> EntersTappedReplacementEffect:
	return EntersTappedReplacementEffect.new()


func describe() -> String:
	return "as enters, may pay or enters tapped"
