class_name BorderEffects
extends RefCounted
## Effects drawn around a thing's border: the Glow, and the outline of whatever a Debug
## Decision Panel option points at. Each one is a child of the Control it marks, so it
## turns, moves and resizes with it. Never draw one beside its host from a remembered
## rectangle: it would hang off a fanned or tapped card.
##
## A Glow and a mark ease in and out over the seconds they are given, and a Glow changing
## color crossfades. Given none, as in tests and screenshots, they come and go at once. One
## taken away is gone at once to anyone who asks; it is only drawn while it fades.

const GLOW: String = "Glow"
const POINTER: String = "Pointer"
const MARK: String = "StackMark"
## What an effect fading out is renamed to, so a new one can take its name meanwhile.
const LEAVING: String = "Leaving"


## Gives [param host], [param host_size] pixels in size, a Glow of [param color], easing in
## over [param seconds].
static func add_glow(host: Control, host_size: Vector2, color: Color, seconds: float = 0.0) -> void:
	add_glow_of(host, host_size, [color] as Array[Color], seconds)


## Gives [param host] a Glow of [param colors]: one color all round, or two split between
## the top left and the bottom right, for something that offers two kinds of thing.
static func add_glow_of(host: Control, host_size: Vector2, colors: Array[Color], seconds: float = 0.0) -> void:
	var glow: Control = Control.new()
	glow.name = GLOW
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_meta("colors", colors.duplicate())
	glow.set_meta("size", host_size)
	if colors.size() > 1:
		var soft_split: SplitOutline = SplitOutline.new(host_size, colors[0], colors[1], 7, 12, 4)
		soft_split.modulate.a = 0.35
		glow.add_child(soft_split)
		glow.add_child(SplitOutline.new(host_size, colors[0], colors[1], 3, 9, 3))
	else:
		var soft: Panel = CardShapes.outline(host_size + Vector2(14, 14), 12, 4, Color(colors[0], 0.35))
		soft.position = Vector2(-7, -7)
		glow.add_child(soft)
		var hard: Panel = CardShapes.outline(host_size + Vector2(6, 6), 9, 3, colors[0])
		hard.position = Vector2(-3, -3)
		glow.add_child(hard)
	host.add_child(glow)
	Easing.fade_in(glow, seconds)


## Gives [param host] a Glow of [param color] in place of any it has, crossfading over
## [param seconds]. One it has already, of that color and size, is left as it is.
static func set_glow(host: Control, host_size: Vector2, color: Color, seconds: float = 0.0) -> void:
	set_glow_of(host, host_size, [color] as Array[Color], seconds)


## Gives [param host] a Glow of [param colors] in place of any it has, crossfading over
## [param seconds]; with no colors, takes its Glow away. One it has already, of those
## colors and size, is left as it is.
static func set_glow_of(host: Control, host_size: Vector2, colors: Array[Color], seconds: float = 0.0) -> void:
	var old: Node = host.get_node_or_null(GLOW)
	if old != null and glow_colors(host) == colors and old.get_meta("size") == host_size:
		return
	remove_glow(host, seconds)
	if not colors.is_empty():
		add_glow_of(host, host_size, colors, seconds)


## Takes away [param host]'s Glow, if it has one, easing out over [param seconds].
static func remove_glow(host: Control, seconds: float = 0.0) -> void:
	_take_away(host, GLOW, seconds)


## The color of [param host]'s Glow, the first of them if it has two, or null if it has
## none. The result is a Variant because "no Glow" is not a color.
static func glow_color(host: Control) -> Variant:
	var colors: Array[Color] = glow_colors(host)
	return colors[0] if not colors.is_empty() else null


## The colors of [param host]'s Glow: none, one, or two.
static func glow_colors(host: Control) -> Array[Color]:
	var colors: Array[Color] = []
	var glow: Node = host.get_node_or_null(GLOW)
	if glow != null:
		colors.assign(glow.get_meta("colors"))
	return colors


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
static func add_mark(host: Control, host_size: Vector2, color: Color, is_dashed: bool, seconds: float = 0.0) -> void:
	_take_away(host, MARK, seconds)
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
	Easing.fade_in(mark, seconds)
	var glow: Control = host.get_node_or_null(GLOW) as Control
	if glow != null:
		glow.hide()


## Takes [param host]'s mark away, easing out over [param seconds], and shows its Glow again
## if it has one.
static func remove_mark(host: Control, seconds: float = 0.0) -> void:
	_take_away(host, MARK, seconds)
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


## Takes [param host]'s effect named [param effect_name] away: at once given no time, or
## renamed and faded out over [param seconds], then freed. One partly in fades from where
## it is, as quickly.
static func _take_away(host: Control, effect_name: String, seconds: float) -> void:
	var old: Control = host.get_node_or_null(effect_name) as Control
	if old == null:
		return
	if seconds > 0.0:
		old.name = LEAVING
	Easing.fade_out_and_free(old, seconds)
