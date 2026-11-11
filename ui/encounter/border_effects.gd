class_name BorderEffects
extends RefCounted
## Effects drawn around a thing's border: the Glow, and the outline of whatever a Debug
## Decision Panel option points at. Each one is a child of the Control it marks, so it
## turns, moves and resizes with it. Never draw one beside its host from a remembered
## rectangle: it would hang off a fanned or tapped card.

const GLOW: String = "Glow"
const POINTER: String = "Pointer"


## Gives [param host], [param host_size] pixels in size, a Glow of [param color].
static func add_glow(host: Control, host_size: Vector2, color: Color) -> void:
	var glow: Control = Control.new()
	glow.name = GLOW
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_meta("color", color)
	var soft: Panel = CardShapes.outline(host_size + Vector2(14, 14), 12, 4, Color(color, 0.35))
	soft.position = Vector2(-7, -7)
	glow.add_child(soft)
	var hard: Panel = CardShapes.outline(host_size + Vector2(6, 6), 9, 3, color)
	hard.position = Vector2(-3, -3)
	glow.add_child(hard)
	host.add_child(glow)


## The color of [param host]'s Glow, or null if it has none. The result is a Variant
## because "no Glow" is not a color.
static func glow_color(host: Control) -> Variant:
	var glow: Node = host.get_node_or_null(GLOW)
	return glow.get_meta("color") if glow != null else null


## Outlines [param host] in white, to say "this is the one that option means".
static func add_pointer(host: Control, host_size: Vector2) -> void:
	remove_pointer(host)
	var pointer: Panel = CardShapes.outline(host_size + Vector2(10, 10), 8, 5, Color.WHITE)
	pointer.name = POINTER
	pointer.position = Vector2(-5, -5)
	host.add_child(pointer)


static func remove_pointer(host: Control) -> void:
	var pointer: Node = host.get_node_or_null(POINTER)
	if pointer != null:
		host.remove_child(pointer)
		pointer.queue_free()


static func has_pointer(host: Control) -> bool:
	return host.get_node_or_null(POINTER) != null
