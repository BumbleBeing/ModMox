class_name Easing
extends RefCounted
## How things on the Encounter Screen fade in and out: Glows, Stack Marks and windows all
## use one curve, over the seconds they are given (Pacing.EASE_SECONDS in a real encounter).
## Given none, as in tests and screenshots, they come and go at once.
##
## Something leaving is gone at once to anyone who asks and to the mouse; it is only drawn
## while it fades. Something shown again while it fades out comes back from where it was.

const TRANSITION: Tween.TransitionType = Tween.TRANS_SINE
const _TWEEN: StringName = &"easing_tween"
const _LEAVING: StringName = &"easing_leaving"


## Fades [param item], new, in from nothing over [param seconds].
static func fade_in(item: CanvasItem, seconds: float) -> void:
	if seconds <= 0.0:
		return
	item.modulate.a = 0.0
	_start(item, true).tween_property(item, "modulate:a", 1.0, seconds)


## Fades [param item] out over [param seconds], deaf to the mouse meanwhile, and frees it;
## then calls [param then], if given. At once given no time.
static func fade_out_and_free(item: Control, seconds: float, then: Callable = Callable()) -> void:
	if seconds <= 0.0:
		if item.get_parent() != null:
			item.get_parent().remove_child(item)
		item.queue_free()
		if then.is_valid():
			then.call()
		return
	item.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	var fade: Tween = _start(item, false)
	fade.tween_property(item, "modulate:a", 0.0, seconds * item.modulate.a)
	fade.tween_callback(item.queue_free)
	if then.is_valid():
		fade.tween_callback(then)


## Shows [param item], easing in over [param seconds] from wherever it is.
static func appear(item: Control, seconds: float) -> void:
	if is_shown(item) and item.modulate.a >= 1.0:
		return
	_stop(item)
	item.set_meta(_LEAVING, false)
	item.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if seconds <= 0.0:
		item.modulate.a = 1.0
		item.show()
		return
	if not item.visible:
		item.modulate.a = 0.0
	item.show()
	_start(item, true).tween_property(item, "modulate:a", 1.0, seconds * (1.0 - item.modulate.a))


## Hides [param item], easing out over [param seconds], deaf to the mouse meanwhile.
static func disappear(item: Control, seconds: float) -> void:
	_stop(item)
	if seconds <= 0.0 or not item.visible:
		_hidden(item)
		return
	item.set_meta(_LEAVING, true)
	item.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	var fade: Tween = _start(item, false)
	fade.tween_property(item, "modulate:a", 0.0, seconds * item.modulate.a)
	fade.tween_callback(_hidden.bind(item))


## Whether [param item] is showing and not on its way out.
static func is_shown(item: Control) -> bool:
	return item.visible and not (item.get_meta(_LEAVING, false) as bool)


static func _hidden(item: Control) -> void:
	item.hide()
	item.modulate.a = 1.0
	item.set_meta(_LEAVING, false)
	item.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED


static func _start(item: CanvasItem, is_coming: bool) -> Tween:
	_stop(item)
	var tween: Tween = item.create_tween().set_trans(TRANSITION).set_ease(Tween.EASE_OUT if is_coming else Tween.EASE_IN)
	item.set_meta(_TWEEN, tween)
	return tween


static func _stop(item: CanvasItem) -> void:
	if not item.has_meta(_TWEEN):
		return
	var old: Tween = item.get_meta(_TWEEN) as Tween
	if old != null and old.is_valid():
		old.kill()
