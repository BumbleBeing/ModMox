class_name DeathtouchDamageClearedEvent
extends MmEvent
## State-based actions were checked while a permanent that can't be destroyed had been dealt
## deathtouch damage. CR 704.5h asks only about damage since the last check, so it no
## longer counts.

var object_id: int


func _init(permanent_id: int) -> void:
	object_id = permanent_id


func apply(state: MmGameState) -> void:
	state.object(object_id).clear_deathtouch_damage()


func describe() -> String:
	return "DEATHTOUCH DAMAGE CLEARED: object %d" % object_id
