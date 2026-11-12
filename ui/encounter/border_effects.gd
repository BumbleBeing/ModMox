class_name BorderEffects
extends RefCounted
## Effects drawn around a thing's border: the Glow, and the outline of whatever a Debug
## Decision Panel option points at. Each one is a child of the Control it marks, so it
## turns, moves and resizes with it. Never draw one beside its host from a remembered
## rectangle: it would hang off a fanned or tapped card.

const GLOW: String = "Glow"
const POINTER: String = "Pointer"
const MARK: String = "StackMark"


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


## Gives [param host] a Glow of [param color] in place of any it has.
static func set_glow(host: Control, host_size: Vector2, color: Color) -> void:
	remove_glow(host)
	add_glow(host, host_size, color)


## Takes away [param host]'s Glow, if it has one.
static func remove_glow(host: Control) -> void:
	var old: Node = host.get_node_or_null(GLOW)
	if old != null:
		host.remove_child(old)
		old.queue_free()


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


## Marks [param host] as something the Stack Window entry under the cursor is about, in
## that entry's [param color]: solid for the source of an ability, dashed for a target
## (A337). The mark takes the place of the host's Glow until it is removed (A346).
static func add_mark(host: Control, host_size: Vector2, color: Color, is_dashed: bool) -> void:
	remove_mark(host)
	var mark: Control = Control.new()
	mark.name = MARK
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_meta("color", color)
	mark.set_meta("is_dashed", is_dashed)
	if is_dashed:
		mark.add_child(DashedBorder.new(host_size, color, 3.0, 4.0))
	else:
		var soft: Panel = CardShapes.outline(host_size + Vector2(14, 14), 12, 4, Color(color, 0.35))
		soft.position = Vector2(-7, -7)
		mark.add_child(soft)
		var hard: Panel = CardShapes.outline(host_size + Vector2(6, 6), 9, 3, color)
		hard.position = Vector2(-3, -3)
		mark.add_child(hard)
	host.add_child(mark)
	var glow: Control = host.get_node_or_null(GLOW) as Control
	if glow != null:
		glow.hide()


## Takes [param host]'s mark away, and shows its Glow again if it has one.
static func remove_mark(host: Control) -> void:
	var mark: Node = host.get_node_or_null(MARK)
	if mark != null:
		host.remove_child(mark)
		mark.queue_free()
	var glow: Control = host.get_node_or_null(GLOW) as Control
	if glow != null:
		glow.show()


## The color of [param host]'s mark, or null if it has none.
static func mark_color(host: Control) -> Variant:
	var mark: Node = host.get_node_or_null(MARK)
	return mark.get_meta("color") if mark != null else null


static func is_mark_dashed(host: Control) -> bool:
	var mark: Node = host.get_node_or_null(MARK)
	return mark != null and (mark.get_meta("is_dashed") as bool)


## Whether [param host]'s Glow is there and showing: a mark hides it.
static func is_glow_showing(host: Control) -> bool:
	var glow: Control = host.get_node_or_null(GLOW) as Control
	return glow != null and glow.visible
