class_name BorderEffects
extends RefCounted
## Effects drawn around a thing's border: the Glow, and the outline of whatever a Debug
## Decision Panel option points at. Each one is a child of the Control it marks, so it
## turns, moves and resizes with it. Never draw one beside its host from a remembered
## rectangle: it would hang off a fanned or tapped card.
##
## A Battlefield Face's effects are children of its card, the part of it that turns, and
## are made the card's size: the face itself is the footprint the card turns in, which a
## card part-way through a tap does not fill. Ask about them with the face all the same.
##
## A Glow and a mark ease in and out over the seconds they are given, and a Glow changing
## color crossfades. Given none, as in tests and screenshots, they come and go at once. One
## taken away is gone at once to anyone who asks; it is only drawn while it fades.
##
## Round a button drawn with a painted plate, a Glow of one color hugs the plate's own
## shape, corners, lip and all (game ADR 0066); round anything else it is rounded.

const GLOW: String = "Glow"
const POINTER: String = "Pointer"
const MARK: String = "StackMark"
const PIN: String = "Pin"
## The ring round the Pinned card (ADR 0033).
const PIN_COLOR: Color = Color("#e6e9ef")
## What an effect fading out is renamed to, so a new one can take its name meanwhile.
const LEAVING: String = "Leaving"
## How far out a Glow's solid ring reaches, how far its soft one, and how strong that is.
const GLOW_NEAR: int = 3
const GLOW_FAR: int = 7
const GLOW_SOFT: float = 0.35

static var _halos: Dictionary[int, StyleBoxTexture] = {}


## The Control [param host]'s effects are children of: the card of a Battlefield Face, and
## [param host] itself for anything else.
static func bearer_of(host: Control) -> Control:
	var field: BattlefieldFace = host as BattlefieldFace
	return field.card() if field != null else host


## The size [param host]'s effects are drawn round: its card's for a Battlefield Face,
## whatever its footprint is, and [param host_size] for anything else.
static func _size_on(host: Control, host_size: Vector2) -> Vector2:
	return bearer_of(host).size if host is BattlefieldFace else host_size


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
	var around: Vector2 = _size_on(host, host_size)
	if colors.size() > 1:
		var soft_split: SplitOutline = SplitOutline.new(around, colors[0], colors[1], 7, 12, 4)
		soft_split.modulate.a = 0.35
		glow.add_child(soft_split)
		glow.add_child(SplitOutline.new(around, colors[0], colors[1], 3, 9, 3))
	elif plate_of(host) != null:
		glow.add_child(_hugging(plate_of(host), around, colors[0]))
	else:
		var soft: Panel = CardShapes.outline(around + Vector2(14, 14), 12, 4, Color(colors[0], GLOW_SOFT))
		soft.position = Vector2(-7, -7)
		glow.add_child(soft)
		var hard: Panel = CardShapes.outline(around + Vector2(6, 6), 9, 3, colors[0])
		hard.position = Vector2(-3, -3)
		glow.add_child(hard)
	bearer_of(host).add_child(glow)
	Easing.fade_in(glow, seconds)


## The painted plate [param host] is drawn with, if it is a button and has one: what its
## Glow hugs. Null for anything else.
static func plate_of(host: Control) -> StyleBoxTexture:
	var button: Button = host as Button
	if button == null:
		return null
	var plate: StyleBoxTexture = button.get_theme_stylebox("normal") as StyleBoxTexture
	return plate if plate != null and plate.texture != null else null


## Whether [param host]'s Glow hugs the shape of its plate.
static func is_glow_hugging(host: Control) -> bool:
	var glow: Node = bearer_of(host).get_node_or_null(GLOW)
	return glow != null and glow.get_child_count() == 1 and glow.get_child(0).has_meta("plate")


## A Glow of [param color] round the shape of [param plate], on a host [param host_size]
## pixels in size. The halo is painted once for each plate.
static func _hugging(plate: StyleBoxTexture, host_size: Vector2, color: Color) -> Panel:
	var key: int = plate.get_instance_id()
	if not _halos.has(key):
		_halos[key] = DitherShading.halo_round(plate, GLOW_NEAR, GLOW_FAR, GLOW_SOFT)
	var halo: Panel = Panel.new()
	halo.set_meta("plate", key)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	halo.add_theme_stylebox_override("panel", _halos[key])
	halo.self_modulate = color
	halo.position = -Vector2(GLOW_FAR, GLOW_FAR)
	halo.size = host_size + Vector2(GLOW_FAR, GLOW_FAR) * 2.0
	return halo


## Gives [param host] a Glow of [param color] in place of any it has, crossfading over
## [param seconds]. One it has already, of that color and size, is left as it is.
static func set_glow(host: Control, host_size: Vector2, color: Color, seconds: float = 0.0) -> void:
	set_glow_of(host, host_size, [color] as Array[Color], seconds)


## Gives [param host] a Glow of [param colors] in place of any it has, crossfading over
## [param seconds]; with no colors, takes its Glow away. One it has already, of those
## colors and size, is left as it is.
static func set_glow_of(host: Control, host_size: Vector2, colors: Array[Color], seconds: float = 0.0) -> void:
	var old: Node = bearer_of(host).get_node_or_null(GLOW)
	if old != null and glow_colors(host) == colors and old.get_meta("size") == host_size and _hugs_its_plate(host):
		return
	remove_glow(host, seconds)
	if not colors.is_empty():
		add_glow_of(host, host_size, colors, seconds)


## Whether [param host]'s Glow is still the right shape: a button given another plate since
## its Glow was made needs a new one.
static func _hugs_its_plate(host: Control) -> bool:
	var plate: StyleBoxTexture = plate_of(host)
	var glow: Node = bearer_of(host).get_node_or_null(GLOW)
	if plate == null or glow == null or glow_colors(host).size() != 1:
		return true
	return is_glow_hugging(host) and glow.get_child(0).get_meta("plate") == plate.get_instance_id()


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
	var glow: Node = bearer_of(host).get_node_or_null(GLOW)
	if glow != null:
		colors.assign(glow.get_meta("colors"))
	return colors


## Outlines [param host] in white, to say "this is the one that option means".
static func add_pointer(host: Control, host_size: Vector2) -> void:
	remove_pointer(host)
	var pointer: Panel = CardShapes.outline(_size_on(host, host_size) + Vector2(10, 10), 8, 5, Color.WHITE)
	pointer.name = POINTER
	pointer.position = Vector2(-5, -5)
	bearer_of(host).add_child(pointer)


static func remove_pointer(host: Control) -> void:
	var pointer: Node = bearer_of(host).get_node_or_null(POINTER)
	if pointer != null:
		pointer.get_parent().remove_child(pointer)
		pointer.queue_free()


static func has_pointer(host: Control) -> bool:
	return bearer_of(host).get_node_or_null(POINTER) != null


## Rings [param host] as the Pinned card of the Inspector (ADR 0033). The ring is part of
## the card, so whatever lies over the card lies over its ring too. In a container, which
## would shrink the ring to its contents, it reaches back out to the host's own edge.
static func add_pin(host: Control, host_size: Vector2) -> void:
	remove_pin(host)
	var pin: Control = Control.new()
	pin.name = PIN
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset: Vector2 = Vector2.ZERO
	if host is PanelContainer:
		var box: StyleBox = host.get_theme_stylebox("panel")
		inset = Vector2(box.get_margin(SIDE_LEFT), box.get_margin(SIDE_TOP))
	var ring: Panel = CardShapes.outline(_size_on(host, host_size) + Vector2(8, 8), 9, 3, PIN_COLOR)
	ring.position = Vector2(-4, -4) - inset
	pin.add_child(ring)
	bearer_of(host).add_child(pin)


static func remove_pin(host: Control) -> void:
	var pin: Node = bearer_of(host).get_node_or_null(PIN)
	if pin != null:
		pin.get_parent().remove_child(pin)
		pin.queue_free()


static func has_pin(host: Control) -> bool:
	return bearer_of(host).get_node_or_null(PIN) != null


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
	var around: Vector2 = _size_on(host, host_size)
	if is_dashed:
		mark.add_child(DashedBorder.new(around, color, 3.0, 4.0))
	else:
		var soft: Panel = CardShapes.outline(around + Vector2(14, 14), 12, 4, Color(color, 0.35))
		soft.position = Vector2(-7, -7)
		mark.add_child(soft)
		var hard: Panel = CardShapes.outline(around + Vector2(6, 6), 9, 3, color)
		hard.position = Vector2(-3, -3)
		mark.add_child(hard)
	bearer_of(host).add_child(mark)
	Easing.fade_in(mark, seconds)
	var glow: Control = bearer_of(host).get_node_or_null(GLOW) as Control
	if glow != null:
		glow.hide()


## Takes [param host]'s mark away, easing out over [param seconds], and shows its Glow again
## if it has one.
static func remove_mark(host: Control, seconds: float = 0.0) -> void:
	_take_away(host, MARK, seconds)
	var glow: Control = bearer_of(host).get_node_or_null(GLOW) as Control
	if glow != null:
		glow.show()


## The color of [param host]'s mark, or null if it has none.
static func mark_color(host: Control) -> Variant:
	var mark: Node = bearer_of(host).get_node_or_null(MARK)
	return mark.get_meta("color") if mark != null else null


static func is_mark_dashed(host: Control) -> bool:
	var mark: Node = bearer_of(host).get_node_or_null(MARK)
	return mark != null and (mark.get_meta("is_dashed") as bool)


## Whether [param host]'s Glow is there and showing: a mark hides it.
static func is_glow_showing(host: Control) -> bool:
	var glow: Control = bearer_of(host).get_node_or_null(GLOW) as Control
	return glow != null and glow.visible


## Takes [param host]'s effect named [param effect_name] away: at once given no time, or
## renamed and faded out over [param seconds], then freed. One partly in fades from where
## it is, as quickly.
static func _take_away(host: Control, effect_name: String, seconds: float) -> void:
	var old: Control = bearer_of(host).get_node_or_null(effect_name) as Control
	if old == null:
		return
	if seconds > 0.0:
		old.name = LEAVING
	Easing.fade_out_and_free(old, seconds)
