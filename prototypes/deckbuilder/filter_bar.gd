class_name FilterBar
extends HBoxContainer
## The strip above the Collection pane: a search box, then toggles for color, card type and
## mana value, a place kept for rarity, the sort order, Clear and how many cards are showing. It
## shows a CollectionFilter and changes it: every click or keystroke updates the filter and
## then emits changed, and the bar is never rebuilt for it, so the search box keeps its
## cursor.

## The filter was changed by the bar.
signal changed

const TOGGLE: float = 34.0
const ICON: float = 24.0
const ON_FILL: Color = Color("#343b47")
const ON_RING: Color = Color("#e8cf8a")
const OFF_ALPHA: float = 0.38
const HOVER_FILL: Color = Color("#2b313b")
const CHIP_BORDER: Color = Color("#4a515d")
const CHIP_TEXT: Color = Color("#aab2bd")
const CHIP_ON_FILL: Color = Color("#e8cf8a")
const CHIP_ON_TEXT: Color = Color("#1a1d22")
const MUTED: Color = Color("#9aa3af")
const DIVIDER: Color = Color("#3a404a")
const MULTICOLOR_FILL: Color = Color("#d8b24a")
const MULTICOLOR_EDGE: Color = Color("#8a6a1c")
const COLOR_SYMBOLS: Array[String] = ["w", "u", "b", "r", "g"]
const TYPE_NAMES: Dictionary[MmCardTypes.CardType, String] = {
	MmCardTypes.CardType.CREATURE: "Creature", MmCardTypes.CardType.INSTANT: "Instant",
	MmCardTypes.CardType.SORCERY: "Sorcery", MmCardTypes.CardType.ARTIFACT: "Artifact",
	MmCardTypes.CardType.ENCHANTMENT: "Enchantment", MmCardTypes.CardType.LAND: "Land",
}
const SORT_NAMES: Dictionary[CollectionFilter.SortKey, String] = {
	CollectionFilter.SortKey.COLOR: "Color", CollectionFilter.SortKey.MANA_VALUE: "Mana value",
	CollectionFilter.SortKey.NAME: "Name", CollectionFilter.SortKey.TYPE: "Type",
}
## Common, uncommon, rare and mythic, for the place rarity will take.
const RARITY_COLORS: Array[Color] = [Color("#c9ccd1"), Color("#9fb6c9"), Color("#d9b55a"), Color("#e0703a")]

var _filter: CollectionFilter = null
var _toggles: Dictionary[String, Control] = {}
## For each toggle, whether the filter has it on.
var _readers: Dictionary[String, Callable] = {}
var _search: LineEdit = null
var _sort: OptionButton = null
var _count: Label = null
var _owned: int = 0


## Shows and changes [param filter], with [param shown] of [param owned] cards showing.
func setup(filter: CollectionFilter, shown: int, owned: int) -> void:
	_filter = filter
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_search = LineEdit.new()
	_search.text = filter.search
	_search.placeholder_text = "Search cards"
	_search.tooltip_text = "Finds every word in a card's name, type line or Rules Text."
	_search.custom_minimum_size = Vector2(150, 0)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.add_theme_font_size_override("font_size", 15)
	_search.text_changed.connect(_on_search_changed)
	add_child(_search)
	_add_divider()
	for color: MmCardTypes.CardColor in MmCardTypes.CardColor.values():
		_add_toggle("color:" + COLOR_SYMBOLS[color], _symbol(COLOR_SYMBOLS[color]),
				func() -> bool: return _filter.colors.has(color),
				func(is_on: bool) -> void: _set_member(_filter.colors, color, is_on))
	_add_toggle("multicolor", _multicolor_disc(), func() -> bool: return _filter.multicolor,
			func(is_on: bool) -> void: _filter.multicolor = is_on)
	_add_toggle("colorless", _symbol("c"), func() -> bool: return _filter.colorless,
			func(is_on: bool) -> void: _filter.colorless = is_on)
	_add_divider()
	for card_type: MmCardTypes.CardType in TYPE_NAMES:
		_add_chip("type:" + TYPE_NAMES[card_type], TYPE_NAMES[card_type],
				func() -> bool: return _filter.card_types.has(card_type),
				func(is_on: bool) -> void: _set_member(_filter.card_types, card_type, is_on))
	_add_divider()
	for mana_value: int in CollectionFilter.TOP_MANA_VALUE + 1:
		var is_top: bool = mana_value == CollectionFilter.TOP_MANA_VALUE
		_add_toggle("mana:%d" % mana_value, _symbol(str(mana_value), "+" if is_top else ""),
				func() -> bool: return _filter.mana_values.has(mana_value),
				func(is_on: bool) -> void: _set_member(_filter.mana_values, mana_value, is_on))
	_add_divider()
	_add_rarity_placeholder()
	_add_divider()
	_add_sort()
	var clear: Button = _chip_button("Clear", false)
	clear.pressed.connect(_on_clear)
	add_child(clear)
	_toggles["clear"] = clear
	_count = Label.new()
	_count.custom_minimum_size = Vector2(74, 0)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 14)
	_count.add_theme_color_override("font_color", MUTED)
	add_child(_count)
	_sync()
	show_count(shown, owned)


## Says that [param shown] of [param owned] cards are showing.
func show_count(shown: int, owned: int) -> void:
	_owned = owned
	_count.text = "%d of %d" % [shown, owned] if _filter.is_active() else "%d cards" % owned


## The toggle or chip named [param key], such as "color:r", "multicolor", "type:Creature",
## "mana:6" or "clear". Clear is always there, and disabled while nothing is filtered.
func toggle(key: String) -> Control:
	return _toggles.get(key, null) as Control


## Clicks the toggle named [param key], as the mouse would.
func press(key: String) -> void:
	var button: Button = toggle(key) as Button
	if button.disabled:
		return
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	else:
		button.pressed.emit()


func search_box() -> LineEdit:
	return _search


func sort_box() -> OptionButton:
	return _sort


func count_label() -> Label:
	return _count


## Makes every toggle look as the filter says, without anything being emitted.
func _sync() -> void:
	for key: String in _readers:
		var button: Button = _toggles[key] as Button
		var is_on: bool = _readers[key].call()
		button.set_pressed_no_signal(is_on)
		if button.get_child_count() > 0:
			(button.get_child(0) as Control).modulate.a = 1.0 if is_on else OFF_ALPHA
	if _search.text != _filter.search:
		_search.text = _filter.search
	_sort.select(_filter.sort_key)
	(_toggles["clear"] as Button).disabled = not _filter.is_active()


func _on_toggled(is_on: bool, write: Callable) -> void:
	write.call(is_on)
	_sync()
	changed.emit()


func _on_search_changed(text: String) -> void:
	_filter.search = text
	_sync()
	changed.emit()


func _on_sort_chosen(index: int) -> void:
	_filter.sort_key = index as CollectionFilter.SortKey
	changed.emit()


func _on_clear() -> void:
	_filter.clear()
	_sync()
	changed.emit()


## Puts [param value] in [param list] or takes it out.
static func _set_member(list: Array, value: Variant, is_in: bool) -> void:
	list.erase(value)
	if is_in:
		list.append(value)


## A round toggle around [param icon]: lit with a ring when on, faint when off.
func _add_toggle(key: String, icon: Control, read: Callable, write: Callable) -> void:
	var button: Button = Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(TOGGLE, TOGGLE)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var radius: int = roundi(TOGGLE / 2.0)
	button.add_theme_stylebox_override("normal", _flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, radius))
	button.add_theme_stylebox_override("hover", _flat(HOVER_FILL, Color.TRANSPARENT, 0, radius))
	for state: String in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, _flat(ON_FILL, ON_RING, 2, radius))
	icon.position = Vector2.ONE * (TOGGLE - ICON) / 2.0
	button.add_child(icon)
	button.toggled.connect(_on_toggled.bind(write))
	add_child(button)
	_toggles[key] = button
	_readers[key] = read


## A pill with [param text]: filled when on, outlined when off.
func _add_chip(key: String, text: String, read: Callable, write: Callable) -> void:
	var chip: Button = _chip_button(text, true)
	chip.toggled.connect(_on_toggled.bind(write))
	add_child(chip)
	_toggles[key] = chip
	_readers[key] = read


func _chip_button(text: String, toggles: bool) -> Button:
	var chip: Button = Button.new()
	chip.text = text
	chip.toggle_mode = toggles
	chip.focus_mode = Control.FOCUS_NONE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_font_size_override("font_size", 14)
	_style_as_pill(chip)
	return chip


## The pill look, shared by the chips and the sort dropdown.
func _style_as_pill(control: Button) -> void:
	control.add_theme_stylebox_override("normal", _pill(Color.TRANSPARENT, CHIP_BORDER))
	control.add_theme_stylebox_override("hover", _pill(HOVER_FILL, CHIP_BORDER))
	for state: String in ["pressed", "hover_pressed"]:
		var lit: bool = control.toggle_mode and not control is OptionButton
		control.add_theme_stylebox_override(state, _pill(CHIP_ON_FILL if lit else HOVER_FILL, CHIP_ON_FILL if lit else CHIP_BORDER))
		control.add_theme_color_override("font_%s_color" % state, CHIP_ON_TEXT if lit else CHIP_TEXT)
	control.add_theme_stylebox_override("disabled", _pill(Color.TRANSPARENT, DIVIDER))
	control.add_theme_color_override("font_disabled_color", Color(CHIP_TEXT, OFF_ALPHA))
	control.add_theme_color_override("font_color", CHIP_TEXT)
	control.add_theme_color_override("font_hover_color", Color.WHITE)


static func _pill(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = _flat(fill, border, 1, 13)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


static func _flat(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


## The sort order, as a dropdown in the pill look.
func _add_sort() -> void:
	_sort = OptionButton.new()
	_sort.focus_mode = Control.FOCUS_NONE
	_sort.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sort.add_theme_font_size_override("font_size", 14)
	for sort_key: CollectionFilter.SortKey in SORT_NAMES:
		_sort.add_item("Sort: %s" % SORT_NAMES[sort_key], sort_key)
	_style_as_pill(_sort)
	_sort.item_selected.connect(_on_sort_chosen)
	add_child(_sort)
	_toggles["sort"] = _sort


func _add_divider() -> void:
	var line: ColorRect = ColorRect.new()
	line.color = DIVIDER
	line.custom_minimum_size = Vector2(1, 26)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(line)
	add_child(margin)


## Four faint gems where the rarity toggles will go once cards have a rarity.
func _add_rarity_placeholder() -> void:
	var group: HBoxContainer = HBoxContainer.new()
	group.add_theme_constant_override("separation", 9)
	group.modulate.a = 0.4
	group.tooltip_text = "Rarity filters arrive when cards have a rarity."
	for color: Color in RARITY_COLORS:
		var cell: Control = Control.new()
		cell.custom_minimum_size = Vector2(16, 16)
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gem: ColorRect = ColorRect.new()
		gem.color = color
		gem.size = Vector2(11, 11)
		gem.pivot_offset = gem.size / 2.0
		gem.position = Vector2(2.5, 2.5)
		gem.rotation_degrees = 45.0
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(gem)
		group.add_child(cell)
	add_child(group)
	_toggles["rarity"] = group


## A mana symbol at icon size, with [param suffix] written small at its top right.
func _symbol(image_name: String, suffix: String = "") -> Control:
	var picture: TextureRect = TextureRect.new()
	picture.texture = ManaSymbols.texture(image_name)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.size = Vector2(ICON, ICON)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if suffix != "":
		var mark: Label = Label.new()
		mark.text = suffix
		mark.add_theme_font_size_override("font_size", 15)
		mark.add_theme_color_override("font_outline_color", Color.BLACK)
		mark.add_theme_constant_override("outline_size", 4)
		mark.position = Vector2(ICON - 7.0, -9.0)
		picture.add_child(mark)
	return picture


## The gold disc that stands for multicolor.
func _multicolor_disc() -> Control:
	var disc: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = MULTICOLOR_FILL
	style.border_color = MULTICOLOR_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(ICON / 2.0))
	style.anti_aliasing = true
	disc.add_theme_stylebox_override("panel", style)
	disc.size = Vector2(ICON, ICON)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc
