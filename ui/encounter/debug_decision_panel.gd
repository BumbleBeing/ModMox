class_name DebugDecisionPanel
extends ZoneWindow
## The Debug Decision Panel (game glossary): a temporary window that answers every kind of
## Pending Decision that has no input of its own yet, through DebugDecisionForm's two
## generic forms. Each decision kind leaves it as its own input is built (A243), and it is
## deleted when none is left. It hides whenever it has nothing to offer (A290).

## The form was filled in: [param answer] is what to submit.
signal answered(answer: Variant)
## The cursor is over an option about Game Object [param object_id], or left it (NONE).
signal option_pointed(object_id: int)

const TINT: Color = Color("#b06ad6")

var _form: DebugDecisionForm = null
var _snapshot: EncounterSnapshot = null
var _picked: Array[int] = []
var _options: Array[Button] = []
var _submit: Button = null


func _init() -> void:
	super("Debug Decision Panel", true, TINT)
	show_title("Debug Decision Panel")


## Shows the form for [param snapshot]'s decision, or hides when the Hero is asked nothing
## this panel answers.
func show_snapshot(snapshot: EncounterSnapshot) -> void:
	_form = null if snapshot.is_over() else DebugDecisionForm.of(snapshot.decision, snapshot.view)
	_snapshot = snapshot
	_picked.clear()
	visible = _form != null
	_rebuild()


func heading_text() -> String:
	return (body().get_child(0) as Label).text


## The button for each option of a form.
func option_buttons() -> Array[Button]:
	return _options


## The button that submits a PICK_SOME form, or null.
func submit_button() -> Button:
	return _submit


func _rebuild() -> void:
	clear()
	_options.clear()
	_submit = null
	var heading: Label = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 17)
	body().add_child(heading)
	if _form != null:
		heading.text = _form.title
		_build_form()


func _build_form() -> void:
	match _form.kind:
		DebugDecisionForm.Kind.PICK_ONE:
			for index: int in _form.options.size():
				_add_option(_form.options[index], index, func() -> void: answered.emit(_form.answer_for_pick(index)))
		DebugDecisionForm.Kind.PICK_SOME:
			for index: int in _form.options.size():
				var place: int = _picked.find(index)
				var label: String = _form.options[index] if place == -1 else "[%d]  %s" % [place + 1, _form.options[index]]
				var option: Button = _add_option(label, index, _toggle_pick.bind(index))
				option.toggle_mode = true
				option.set_pressed_no_signal(place != -1)
			var wanted: String = "" if _form.count == DebugDecisionForm.NONE else " of %d" % _form.count
			var text: String = "Submit (%d chosen%s)" % [_picked.size(), wanted]
			_submit = _button(text, func() -> void: answered.emit(_form.answer_for_picks(_picked.duplicate())))
			body().add_child(_submit)


func _toggle_pick(index: int) -> void:
	if _picked.has(index):
		_picked.erase(index)
	else:
		_picked.append(index)
	_rebuild()


func _add_option(label: String, index: int, on_press: Callable) -> Button:
	var option: Button = _button(label, on_press)
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var object_id: int = _form.option_object_ids[index]
	option.mouse_entered.connect(func() -> void: option_pointed.emit(object_id))
	option.mouse_exited.connect(func() -> void: option_pointed.emit(DebugDecisionForm.NONE))
	body().add_child(option)
	_options.append(option)
	return option


func _button(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	return button
