class_name StageMapLinks
extends RefCounted
## How each link of the Stage Map is colored: lit while the Hero can take it now, dark
## otherwise, easing between the two; gold once walked, and turning gold while it is being
## walked. Pure: the screen draws what it says.

## The pale dots of a link that can be taken, the dark of one that cannot, the gold of one
## walked.
const LIT: Color = Color8(195, 201, 214)
const DARK: Color = Color8(69, 74, 92)
const WALKED: Color = Color8(238, 196, 74)
## A link eases from dark to lit, or back, over this long at Blazing.
const FADE_SECONDS: float = 0.25

## How lit each link is, from 0 (dark) to 1, by its two Nodes' ids, lower first.
var _light: Dictionary[Vector2i, float] = {}


## Eases every link of [param visit] toward lit if the Hero can take it now, and dark if
## not, by [param step] (1 is the whole way). While the Hero glides toward
## [param gliding_to], only the link being walked stays lit. A link seen for the first
## time starts where it is heading.
func ease_toward(visit: StageVisit, gliding_to: int, step: float) -> bool:
	var takeable: Dictionary[Vector2i, bool] = {}
	if gliding_to == -1:
		for id: int in visit.choices():
			takeable[key(visit.current, id)] = true
	else:
		takeable[key(visit.current, gliding_to)] = true
	var is_changed: bool = false
	for node: MapNode in visit.map.nodes:
		var others: Array[int] = node.forward.duplicate()
		if node.side > node.id:
			others.append(node.side)
		for other: int in others:
			var link: Vector2i = key(node.id, other)
			var target: float = 1.0 if takeable.has(link) else 0.0
			var now: float = _light.get(link, target)
			var next: float = move_toward(now, target, step)
			_light[link] = next
			is_changed = is_changed or next != now
	return is_changed


## How lit the link between [param a] and [param b] is, from 0 to 1.
func light_of(a: int, b: int) -> float:
	return _light.get(key(a, b), 0.0)


## The color of the link between [param a] and [param b] of [param visit]: gold once
## walked; while the Hero glides along it, [param glide] of the way (0 to 1) from lit to
## gold; else between dark and lit as it is lit.
func color_of(visit: StageVisit, a: int, b: int, gliding_to: int, glide: float) -> Color:
	if visit.is_walked(a, b):
		return WALKED
	var color: Color = DARK.lerp(LIT, StageMapLayout.eased(light_of(a, b)))
	if gliding_to != -1 and key(a, b) == key(visit.current, gliding_to):
		color = color.lerp(WALKED, StageMapLayout.eased(glide))
	return color


static func key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))
