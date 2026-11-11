class_name DebugDecisionPanel
extends ZoneWindow
## The Debug Decision Panel (game glossary): a temporary window that answers every kind of
## Pending Decision that has no input of its own yet, through DebugDecisionForm's five
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
var _pair_choices: Array[OptionButton] = []
var _shares: Array[SpinBox] = []
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
	visible = _form != null and not (_form.kind == DebugDecisionForm.Kind.PICK_ONE and _form.is_empty())
	_rebuild()


func heading_text() -> String:
	return (body().get_child(0) as Label).text


## The button for each option of a PICK_ONE, PICK_SOME or ORDER form.
func option_buttons() -> Array[Button]:
	return _options


## The button that submits a PICK_SOME, ORDER, PAIR_UP or SPLIT form, or null.
func submit_button() -> Button:
	return _submit


## PAIR_UP: the choice of what option [param index] (a blocker) blocks. Its first item is
## "no block"; the rest are the attackers it may block, in order.
func pair_choice(index: int) -> OptionButton:
	return _pair_choices[index]


## SPLIT: the box holding option [param index]'s share.
func share_box(index: int) -> SpinBox:
	return _shares[index]


func _rebuild() -> void:
	clear()
	_options.clear()
	_pair_choices.clear()
	_shares.clear()
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
		DebugDecisionForm.Kind.PICK_SOME, DebugDecisionForm.Kind.ORDER:
			for index: int in _form.options.size():
				var place: int = _picked.find(index)
				var label: String = _form.options[index] if place == -1 else "[%d]  %s" % [place + 1, _form.options[index]]
				var option: Button = _add_option(label, index, _toggle_pick.bind(index))
				option.toggle_mode = true
				option.set_pressed_no_signal(place != -1)
			var wanted: String = "" if _form.count == DebugDecisionForm.NONE else " of %d" % _form.count
			var text: String = "Submit this order" if _form.kind == DebugDecisionForm.Kind.ORDER \
				else "Submit (%d chosen%s)" % [_picked.size(), wanted]
			_submit = _button(text, func() -> void: answered.emit(_form.answer_for_picks(_picked.duplicate())))
			body().add_child(_submit)
		DebugDecisionForm.Kind.PAIR_UP:
			for index: int in _form.options.size():
				var row: HBoxContainer = _row(_form.options[index], index)
				var choice: OptionButton = OptionButton.new()
				choice.focus_mode = Control.FOCUS_NONE
				choice.add_item("no block")
				var labels: Array = _form.pair_choice_labels[index]
				for label: String in labels:
					choice.add_item("blocks " + label)
				row.add_child(choice)
				_pair_choices.append(choice)
			_submit = _button("Submit blocks", _submit_pairs)
			body().add_child(_submit)
		DebugDecisionForm.Kind.SPLIT:
			for index: int in _form.options.size():
				var lethal: int = _form.lethal_amounts[index]
				var label: String = _form.options[index] if lethal == DebugDecisionForm.NONE \
					else "%s  (lethal: %d)" % [_form.options[index], lethal]
				var row: HBoxContainer = _row(label, index)
				var share: SpinBox = SpinBox.new()
				share.max_value = _form.amount
				row.add_child(share)
				_shares.append(share)
			_submit = _button("Submit division", _submit_shares)
			body().add_child(_submit)


## The first choice for each blocker is "no block"; the rest are its attackers in order.
func _submit_pairs() -> void:
	var attackers_by_option: Array = []
	for index: int in _pair_choices.size():
		var chosen: int = _pair_choices[index].selected
		var ids: Array = _form.pair_choice_ids[index]
		attackers_by_option.append([] if chosen <= 0 else [ids[chosen - 1]])
	answered.emit(_form.answer_for_pairs(attackers_by_option))


func _submit_shares() -> void:
	var shares: Array[int] = []
	for share: SpinBox in _shares:
		shares.append(int(share.value))
	answered.emit(_form.answer_for_split(shares))


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


func _row(label_text: String, index: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	var object_id: int = _form.option_object_ids[index]
	label.mouse_entered.connect(func() -> void: option_pointed.emit(object_id))
	label.mouse_exited.connect(func() -> void: option_pointed.emit(DebugDecisionForm.NONE))
	row.add_child(label)
	body().add_child(row)
	return row


func _button(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	return button
