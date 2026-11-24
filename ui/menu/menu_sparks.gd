class_name MenuSparks
extends Control
## The Wisp Sparks on the main menu: leaves them about the Wisp each frame it is flying, in
## its color then, moves them on and draws each where its WispSparks puts it. It covers the
## menu and takes no clicks.

var _wisp: MenuWisp
var _window: Control
var _sparks: WispSparks
## Whether any were drawn last frame, so that the last is wiped once it has faded out.
var _was_showing: bool = false


## The sparks [param wisp] leaves, landing on [param window], placed with [param random],
## or at random if none is given.
func _init(wisp: MenuWisp, window: Control, random: RandomNumberGenerator = null) -> void:
	_wisp = wisp
	_window = window
	# A new generator starts from a random seed of its own.
	_sparks = WispSparks.new(random if random != null else RandomNumberGenerator.new())
	# After the Wisp's, so that they are left where it is this frame.
	process_priority = wisp.process_priority + 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Where they are and how they look.
func sparks() -> WispSparks:
	return _sparks


## Moves the sparks on by [param seconds], then leaves those due about the Wisp.
func advance(seconds: float) -> void:
	_sparks.advance(seconds, _window.get_global_rect())
	var flight: WispFlight = _wisp.flight()
	if flight.is_flying():
		_sparks.trail(seconds, _wisp.drawn_rect().get_center(), flight.color(), flight.opacity())
	var showing: bool = not _sparks.sparks().is_empty()
	if showing or _was_showing:
		queue_redraw()
	_was_showing = showing


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	for spark: WispSparks.Spark in _sparks.sparks():
		var drawn: Rect2 = spark.drawn_rect()
		draw_rect(Rect2(drawn.position - global_position, drawn.size), Color(spark.color, spark.opacity()))
