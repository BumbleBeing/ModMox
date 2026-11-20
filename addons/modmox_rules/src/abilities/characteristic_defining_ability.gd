class_name CharacteristicDefiningAbility
extends StaticAbility
## "This creature's power and toughness are each equal to [Value]" (CR 604.3). Applied in
## layer 7a, and in every zone, not just the battlefield. Its card prints "*" for these.

## Null when it defines toughness alone, so the printed power stands, as on a 1/* creature.
@export var power: MmValue = null
## Null when it defines power alone, so the printed toughness stands, as on a */3 creature.
@export var toughness: MmValue = null


func describe() -> String:
	return "characteristic-defining ability"
