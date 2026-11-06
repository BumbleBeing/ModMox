class_name CharacteristicDefiningAbility
extends StaticAbility
## "This creature's power and toughness are each equal to [Value]" (CR 604.3). Applied in
## layer 7a, and in every zone, not just the battlefield. Its card prints "*" for these.

@export var power: MmValue
@export var toughness: MmValue


func describe() -> String:
	return "characteristic-defining ability"
