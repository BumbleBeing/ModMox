class_name ClickCatcher
extends Control
## Makes a face or a player's panel take clicks. It is a child of the thing it covers, so
## it turns and moves with it. Under the cursor its host brightens and the cursor becomes
## the pointing hand; a left click says so. A thing with no ClickCatcher ignores the mouse.

signal clicked

const NAME: String = "ClickCatcher"
const BRIGHT: Color = Color(1.28, 1.28, 1.28)


## Covers [param host], [param host_size] pixels in size.
static func add(host: Control, host_size: Vector2) -> ClickCatcher:
	var catcher: ClickCatcher = ClickCatcher.new()
	catcher.name = NAME
	catcher.size = host_size
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	catcher.mouse_entered.connect(func() -> void: host.modulate = BRIGHT)
	catcher.mouse_exited.connect(func() -> void: host.modulate = Color.WHITE)
	host.add_child(catcher)
	return catcher


## The catcher on [param host], or null if it does not take clicks.
static func of(host: Control) -> ClickCatcher:
	return host.get_node_or_null(NAME) as ClickCatcher


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()
