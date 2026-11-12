class_name StackColors
extends RefCounted
## The color of each spell and ability on the stack (A335): one of eight muted hues that
## leave out the Glow's colors and the Block Lines', taken when the object arrives and
## kept until it leaves. Kept by the Encounter Screen, outside the nodes it redraws, since
## a snapshot alone cannot say which hue an object was given.

const HUES: Array[Color] = [
	Color("#9a86c9"), Color("#c987ad"), Color("#6fb3ad"), Color("#c9a15f"),
	Color("#b8676f"), Color("#a9b86a"), Color("#8791c4"), Color("#b39a84"),
]
## The color of anything that is not on the stack, such as a trigger still being ordered.
const PLAIN: Color = Color("#8a93a6")

## Object ID → which of HUES it has.
var _hues: Dictionary[int, int] = {}


## Tells it what is on the stack now, as [param stack_ids] in the order they arrived.
## Objects that left give their hues up; each new one takes the hue at its ID, or the next
## one free. With every hue taken, hues are shared.
func update(stack_ids: Array[int]) -> void:
	for id: int in _hues.keys():
		if not stack_ids.has(id):
			_hues.erase(id)
	for id: int in stack_ids:
		if _hues.has(id):
			continue
		var hue: int = posmod(id, HUES.size())
		for step: int in HUES.size():
			var candidate: int = (hue + step) % HUES.size()
			if not _hues.values().has(candidate):
				hue = candidate
				break
		_hues[id] = hue


## The color of Game Object [param object_id], or PLAIN if it is not on the stack.
func color_of(object_id: int) -> Color:
	return HUES[_hues[object_id]] if _hues.has(object_id) else PLAIN
