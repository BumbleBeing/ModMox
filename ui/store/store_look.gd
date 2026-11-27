class_name StoreLook
extends RefCounted
## What the Store's screen and its Collection Window are drawn from (milestone 24, signed off
## as prototypes/store_screen/): the panes in the deckbuilder's warm gray, the parchment the
## Spoils' gold sits on, a price with the Run Bar's coin, the gold panel and its count, the
## buttons in the Steel Frame, the Buy button's slot and the Sold space a bought good leaves.
## Each Dither Shaded plate is painted once for each height it is drawn at and kept
## (conventions, "Paint a Dither Shaded plate only for a height its surface keeps").

## The deckbuilder's pane, which is the Spoils' window color too.
const PANE: Color = Color("#4b3f3f")
const PANE_EDGE: Color = Color("#575a60")
const PANE_RADIUS: int = 14
const TEXT: Color = Color8(228, 231, 238)
const MUTED: Color = Color8(154, 163, 181)
## The Spoils' parchment and its ink.
const PAPER: Color = Color("#e9dcbc")
const PAPER_EDGE: Color = Color("#7a6243")
const PAPER_RADIUS: int = 14
const PAPER_PADDING: Vector2 = Vector2(14, 12)
const INK: Color = Color8(46, 40, 36)
const INK_MUTED: Color = Color8(108, 96, 84)
## A price that cannot be afforded, on a pane and on parchment.
const RED_ON_DARK: Color = Color("#ff6b61")
const RED_ON_PAPER: Color = Color("#b3261e")
## The Run Bar's buttons.
const BUTTON_FILL: Color = RunBar.BUTTON_FILL
const BUTTON_HEIGHT: int = RunBar.BUTTON_HEIGHT
const BUTTON_SIDE: int = RunBar.BUTTON_SIDE
const BUTTON_FONT_SIZE: int = 22
const COIN: String = "res://ui/sprites/run_bar/gold_coin.png"
const SHADOW: Color = Color(0, 0, 0, 0.55)
## What a Sold space is hollowed out in.
const HOLLOW: Color = Color(0, 0, 0, 0.3)
const HOLLOW_EDGE: Color = Color(1, 1, 1, 0.16)
const BUY: String = "Buy"
const SOLD: String = "Sold"
## How far a selected card and a selected entry rise, and the shadow each then casts.
const CARD_LIFT: float = 12.0
const ENTRY_LIFT: float = 6.0
const LIFTED_SHADOW: int = 16
const LIFTED_DROP: float = 8.0
## The slot a Buy button stands in under a good.
const BUY_SLOT: Vector2 = Vector2(96, 50)
const BUY_HEIGHT: int = 44
## The gold counts as the Spoils' does: easing out over this long, at Blazing.
const COUNT_SECONDS: float = SpoilsReveal.COUNT_SECONDS
## The name a price row's number and the gold panel's count are found by.
const AMOUNT: String = "Amount"
const COUNT: String = "Count"
const _LIFT: StringName = &"lift"
const _RESERVED: StringName = &"is_reserved"
const _IS_UP: StringName = &"is_up"
const _TWEEN: StringName = &"store_tween"

## The plates painted so far, by what they are for and their height.
static var _plates: Dictionary[String, StyleBoxTexture] = {}


static func text(written: String, font_size: int, color: Color, is_bold: bool) -> Label:
	var made: Label = Label.new()
	made.text = written
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A line that wraps at [param width], given before it is laid out so that it never passes
## through being a word to a line (conventions).
static func wrapped(written: String, font_size: int, color: Color, is_bold: bool, width: float) -> Label:
	var made: Label = Label.new()
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.custom_minimum_size = Vector2(width, 0)
	made.text = written
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A line of what something does, [param width] wide, its mana symbols drawn as a card's are.
static func words(line: String, font_size: int, color: Color, width: float) -> SymbolLabel:
	var made: SymbolLabel = SymbolLabel.new()
	made.custom_minimum_size = Vector2(width, 0)
	made.set_font_size(font_size)
	made.write_in(line, color)
	return made


## Pixel art at [param scale] times its size, with hard edges.
static func picture(texture: Texture2D, scale: float) -> TextureRect:
	var made: TextureRect = TextureRect.new()
	made.texture = texture
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	made.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	made.custom_minimum_size = texture.get_size() * scale
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	made.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


static func coin() -> TextureRect:
	return picture(load(COIN) as Texture2D, 2.0)


## A price: the Run Bar's coin and [param amount], red when it cannot be afforded. Its number
## is named Amount.
static func price(amount: int, can_afford: bool, is_on_paper: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coin())
	var number: Label = text(str(amount), 24, price_color(can_afford, is_on_paper), true)
	number.name = AMOUNT
	row.add_child(number)
	return row


static func price_color(can_afford: bool, is_on_paper: bool) -> Color:
	if can_afford:
		return INK if is_on_paper else TEXT
	return RED_ON_PAPER if is_on_paper else RED_ON_DARK


## Writes [param row], a price, in its plain color or in red, as it can be afforded now.
static func mark_price(row: HBoxContainer, can_afford: bool, is_on_paper: bool) -> void:
	amount_of(row).add_theme_color_override("font_color", price_color(can_afford, is_on_paper))


## The number of [param row], a price.
static func amount_of(row: HBoxContainer) -> Label:
	return row.get_node(AMOUNT) as Label


## Whether [param row], a price, is written in red.
static func is_red(row: HBoxContainer) -> bool:
	var color: Color = amount_of(row).get_theme_color("font_color")
	return color == RED_ON_DARK or color == RED_ON_PAPER


## A parchment panel in Dither Shading over its own height, painted only when its height
## changes, and kept.
static func paper(padding: Vector2 = PAPER_PADDING) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade: Callable = func() -> void:
		var height: int = maxi(int(panel.size.y), PAPER_RADIUS * 2 + 1)
		if panel.get_meta(&"painted_height", -1) == height:
			return
		panel.set_meta(&"painted_height", height)
		var made: StyleBoxTexture = _paper_plate(height).duplicate() as StyleBoxTexture
		made.content_margin_left = padding.x
		made.content_margin_right = padding.x
		made.content_margin_top = padding.y
		made.content_margin_bottom = padding.y
		panel.add_theme_stylebox_override("panel", made)
	shade.call()
	panel.resized.connect(shade)
	return panel


## A pane at [param place]: the deckbuilder's warm gray in Dither Shading. What is put on it
## is drawn smoothly unless it asks for hard edges itself.
static func pane(place: Rect2) -> Panel:
	var made: Panel = Panel.new()
	made.position = place.position
	made.size = place.size
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var key: String = "pane %d" % int(place.size.y)
	if not _plates.has(key):
		_plates[key] = DitherShading.plate(PANE.lightened(0.06), PANE.darkened(0.3), PANE_EDGE, PANE_RADIUS, 2, 0,
				int(place.size.y))
	made.add_theme_stylebox_override("panel", _plates[key])
	return made


## A holder filling [param on], [param pad] in from its edges, whose contents are drawn
## smoothly.
static func inside(on: Control, pad: float) -> MarginContainer:
	var made: MarginContainer = MarginContainer.new()
	made.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		made.add_theme_constant_override(side, int(pad))
	made.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	on.add_child(made)
	return made


## The gold panel: the coin and [param gold] on parchment, with no label. Its number is named
## Count.
static func gold_panel(gold: int) -> Control:
	var panel: PanelContainer = paper(Vector2(18, 6))
	panel.custom_minimum_size = Vector2(150, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coin())
	var count: Label = text(str(gold), 30, INK, true)
	count.name = COUNT
	count.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(count)
	panel.add_child(row)
	var framed: Control = shadowed(panel, PAPER_RADIUS, 3.0)
	framed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return framed


## The number of [param panel], a gold panel.
static func count_of(panel: Control) -> Label:
	return panel.find_child(COUNT, true, false) as Label


## Counts [param count], the gold panel's number, from what it shows to [param gold] over
## [param seconds], easing out as the Spoils' gold does. At once given no time.
static func count_gold(count: Label, gold: int, seconds: float) -> void:
	_stop(count)
	var from: int = int(count.text)
	if seconds <= 0.0 or from == gold:
		count.text = str(gold)
		return
	var tween: Tween = count.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	count.set_meta(_TWEEN, tween)
	tween.tween_method(func(shown: float) -> void: count.text = str(roundi(shown)), float(from), float(gold), seconds)


## A button as the Run Bar's are: [param label] in bold in the Steel Frame, with the Run Bar's
## icon named [param icon_name] to its right if one is given.
static func button(label: String, icon_name: String = "", height: int = BUTTON_HEIGHT) -> Button:
	var made: Button = Button.new()
	made.text = label
	if icon_name != "":
		made.icon = RunBar.scaled_icon(icon_name)
		made.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		made.add_theme_constant_override("h_separation", 10)
	made.focus_mode = Control.FOCUS_NONE
	made.add_theme_font_override("font", UiText.bold())
	made.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	made.custom_minimum_size = Vector2(0, height)
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state: String in ButtonShading.STATES:
		var plate: StyleBoxTexture = SteelFrame.roomy_plate(BUTTON_FILL, state, height).duplicate() as StyleBoxTexture
		plate.content_margin_left = BUTTON_SIDE
		plate.content_margin_right = BUTTON_SIDE
		made.add_theme_stylebox_override(state, plate)
	return made


## A button that confirms a trade: [param word], then the coin and the price once
## set_button_price() gives it one. Its parts are named Word, Coin and Amount.
static func price_button(word: String) -> Button:
	var made: Button = button("")
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Up off the button's lip, as its own text would stand.
	row.offset_bottom = -4
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	made.add_child(row)
	var name_label: Label = text(word, BUTTON_FONT_SIZE, Color.WHITE, true)
	name_label.name = "Word"
	row.add_child(name_label)
	var coin_picture: TextureRect = coin()
	coin_picture.name = "Coin"
	row.add_child(coin_picture)
	var amount: Label = text("", BUTTON_FONT_SIZE, Color.WHITE, true)
	amount.name = AMOUNT
	row.add_child(amount)
	# As wide as what it reads, whenever that changes.
	var fit: Callable = func() -> void:
		made.custom_minimum_size.x = row.get_combined_minimum_size().x + 2.0 * BUTTON_SIDE + 8.0
	row.minimum_size_changed.connect(fit)
	made.ready.connect(fit)
	set_button_price(made, -1, true, false)
	return made


## Shows [param amount] on [param made], a price button, in red when it cannot be afforded,
## or no price at all for -1, and lets it be pressed or not.
static func set_button_price(made: Button, amount: int, can_afford: bool, is_live: bool) -> void:
	var row: HBoxContainer = made.get_node("Row") as HBoxContainer
	var price_text: Label = row.get_node(AMOUNT) as Label
	(row.get_node("Coin") as Control).visible = amount >= 0
	price_text.visible = amount >= 0
	price_text.text = str(maxi(amount, 0))
	price_text.add_theme_color_override("font_color", Color.WHITE if can_afford else RED_ON_DARK)
	made.disabled = not is_live
	row.modulate.a = 1.0 if is_live else 0.5


## What [param made], a price button, reads: its word, and its price, or "" for none.
static func button_words(made: Button) -> String:
	return ((made.get_node("Row") as Node).get_node("Word") as Label).text


static func button_price(made: Button) -> String:
	var amount: Label = (made.get_node("Row") as Node).get_node(AMOUNT) as Label
	return amount.text if amount.visible else ""


## The space a bought good leaves: a hollow of [param space] that reads "Sold".
static func sold_space(space: Vector2, radius: int) -> Panel:
	var made: Panel = Panel.new()
	made.name = "Sold"
	made.custom_minimum_size = space
	made.size = space
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HOLLOW
	style.border_color = HOLLOW_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	made.add_theme_stylebox_override("panel", style)
	var label: Label = text(SOLD, 26, MUTED, true)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	made.add_child(label)
	return made


## [param item] in a frame that draws only a drop shadow, as the Spoils' parts cast.
static func shadowed(item: Control, radius: int, drop: float) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_horizontal = item.size_flags_horizontal
	frame.size_flags_vertical = item.size_flags_vertical
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(radius)
	style.shadow_color = SHADOW
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, drop)
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(item)
	return frame


## The deckbuilder's own Inspector on a pane at [param place] of [param on], without Apply a
## Mod and saying nothing while it shows nothing.
static func add_inspector(on: Control, place: Rect2) -> DeckbuilderInspector:
	var back: Panel = pane(place)
	back.theme = DeckbuilderLook.theme()
	# A click on the Inspector is not a click on the ground.
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.clip_contents = true
	on.add_child(back)
	var inspector: DeckbuilderInspector = DeckbuilderInspector.new()
	inspector.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	inspector.set_hint("")
	back.add_child(inspector)
	# The Inspector keeps room for Apply a Mod at its foot whether or not it is shown, so it is
	# made that much taller than its pane and the pane cuts the room off. Its size is set once
	# it is in the tree: set before, its wrapped hint makes it far too tall.
	var apply: Button = inspector.apply_button()
	apply.visible = false
	inspector.position = Vector2(10, 10)
	inspector.size = place.size - Vector2(20, 20) + Vector2(0, apply.get_combined_minimum_size().y + DeckbuilderInspector.GAP)
	return inspector


## [param inner] in a frame that keeps [param lift] pixels above it for it to rise into when
## it is selected, casting a shadow as it does.
static func lifter(inner: Control, lift: float, radius: int) -> PanelContainer:
	var made: PanelContainer = PanelContainer.new()
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(radius)
	style.shadow_color = SHADOW
	style.shadow_size = 0
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = lift
	style.content_margin_bottom = 0
	made.add_theme_stylebox_override("panel", style)
	made.set_meta(_LIFT, lift)
	made.add_child(inner)
	return made


## Raises what [param made], a lifter, holds, or lets it back down, over [param seconds].
static func set_lifted(made: PanelContainer, is_up: bool, seconds: float) -> void:
	var style: StyleBoxFlat = made.get_theme_stylebox("panel") as StyleBoxFlat
	var lift: float = made.get_meta(_LIFT) as float
	var top: float = 0.0 if is_up else lift
	var shadow: int = LIFTED_SHADOW if is_up else 0
	var drop: Vector2 = Vector2(0, LIFTED_DROP if is_up else 0.0)
	_stop(made)
	made.set_meta(_IS_UP, is_up)
	if seconds <= 0.0:
		style.content_margin_top = top
		style.content_margin_bottom = lift - top
		style.shadow_size = shadow
		style.shadow_offset = drop
		return
	var tween: Tween = made.create_tween().set_trans(Easing.TRANSITION).set_ease(Tween.EASE_OUT).set_parallel(true)
	made.set_meta(_TWEEN, tween)
	tween.tween_property(style, "content_margin_top", top, seconds)
	tween.tween_property(style, "content_margin_bottom", lift - top, seconds)
	tween.tween_property(style, "shadow_size", shadow, seconds)
	tween.tween_property(style, "shadow_offset", drop, seconds)


## Whether what [param made], a lifter, holds is raised, or rising.
static func is_lifted(made: PanelContainer) -> bool:
	return made.get_meta(_IS_UP, false) as bool


## The slot a good's own Buy button stands in. A reserved slot keeps its room whether or not
## the button shows; another opens to show it. The button is its only child.
static func buy_slot(is_reserved: bool) -> Control:
	var slot: Control = Control.new()
	slot.clip_contents = true
	slot.custom_minimum_size = Vector2(BUY_SLOT.x, BUY_SLOT.y if is_reserved else 0.0)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.set_meta(_RESERVED, is_reserved)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var buy: Button = button(BUY, "", BUY_HEIGHT)
	buy.position = Vector2(0, BUY_SLOT.y - BUY_HEIGHT)
	buy.size = Vector2(BUY_SLOT.x, BUY_HEIGHT)
	buy.visible = false
	slot.add_child(buy)
	return slot


## The Buy button in [param slot].
static func buy_of(slot: Control) -> Button:
	return slot.get_child(0) as Button


## Shows the Buy button in [param slot], off while the good cannot be afforded, or puts it
## away, over [param seconds].
static func show_buy(slot: Control, is_shown: bool, can_afford: bool, seconds: float) -> void:
	var buy: Button = buy_of(slot)
	buy.disabled = not can_afford
	if is_shown:
		Easing.appear(buy, seconds)
	else:
		Easing.disappear(buy, seconds)
	if slot.get_meta(_RESERVED) as bool:
		return
	_stop(slot)
	var height: float = BUY_SLOT.y if is_shown else 0.0
	if seconds <= 0.0:
		slot.custom_minimum_size.y = height
		return
	var tween: Tween = slot.create_tween().set_trans(Easing.TRANSITION).set_ease(Tween.EASE_OUT)
	slot.set_meta(_TWEEN, tween)
	tween.tween_property(slot, "custom_minimum_size:y", height, seconds)


## Makes [param over] take the mouse as a good does: a pointing hand, and [param on_click]
## told of a left press on it. Pass, not stop: the wheel over a good still scrolls the list
## it stands in.
static func take_clicks(over: Control, on_click: Callable) -> void:
	over.mouse_filter = Control.MOUSE_FILTER_PASS
	over.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	over.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			on_click.call())


static func _paper_plate(height: int) -> StyleBoxTexture:
	var key: String = "paper %d" % height
	if not _plates.has(key):
		_plates[key] = DitherShading.plate(PAPER.lightened(0.08), PAPER.darkened(0.15), PAPER_EDGE, PAPER_RADIUS - 2, 2,
				0, height)
	return _plates[key]


static func _stop(item: Object) -> void:
	if not item.has_meta(_TWEEN):
		return
	var old: Tween = item.get_meta(_TWEEN) as Tween
	if old != null and old.is_valid():
		old.kill()
