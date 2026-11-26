class_name DrawReplacementAbility
extends StaticAbility
## "If you would draw a card while [condition], instead [instead]" (CR 614.1a, 614.11,
## engine ADR 0097), as Blood Scrivener's "If you would draw a card while you have no cards
## in hand, instead you draw two cards and you lose 1 life." A static ability of a permanent:
## while it is on the battlefield it generates a replacement effect that applies to each of
## its controller's draws, one at a time (DrawCardEvent), while [member condition] holds
## as that draw would happen, even with no card to draw (CR 614.11). What happens instead is
## never replaced by the same ability again (CR 614.5), so its own draws are ordinary
## draws. [member instead] are effects whose events can be worked out together before any of
## them happens, as drawing and losing life can.
# Later: a choice between two different draw replacements, which the draw step cannot stop
# for (MmGameState.perform_together()), once two different ones are in the game.

## Null for every draw.
@export var condition: MmCondition = null
@export var instead: Array[MmEffect] = []


## The replacement effect this ability generates while its permanent is on the battlefield.
func replacement() -> DrawReplacementEffect:
	var effect: DrawReplacementEffect = DrawReplacementEffect.new()
	effect.condition = condition
	effect.instead = instead
	return effect


func describe() -> String:
	return "draw replacement"
