class_name InspectorParts
extends RefCounted
## What the encounter's Inspector and the deckbuilder's are both built from (milestone 16,
## ADR 0033): a bordered panel with its title centered at the top, an entry of a title over
## a sentence, a Reminder's row, Card Text, the centered italic None a panel says when it
## has nothing to say, and the shaded gray buttons. Each screen hands over a Palette of its
## own colors, so a change to how an Inspector is laid out is made here and both get it.

## What a panel with nothing to say says.
const NONE: String = "None"
## What stands between two abilities in Card Text: an empty line, so each reads on its own.
const PARAGRAPH_BREAK: String = "\n\n"
## How far a title stands above what is under it, of the height a card's panel has when two
## share the room (A577, A585).
const TITLE_GAP_SHARE: float = 1.0 / 20.0
## The panel showing around its backing's sides and bottom: one unit.
const EDGE: float = 4.0
## How far what stands on a backing or an entry's plate is kept from its edges: three units.
const INSET: float = 12.0
## How tall an Inspector's buttons are, so their Dither Shading is painted for it: ten units.
const BUTTON_HEIGHT: int = 40
## The meta a titled panel keeps the room over its title in, for when it is shaded again.
const TITLE_ROOM: StringName = &"title_room"
## Set on a shaded background whose painting is held off, and the painting itself.
const SHADING_HELD: StringName = &"shading_held"
const REPAINT: StringName = &"repaint"
## How much lighter a button is under the mouse, as the Deckbox's are.
const HOVER_LIGHTEN: float = 0.10
const FONT_FOLDER: String = "res://assets/fonts/linux_libertine/linlibertine-%s.ttf"


## The colors an Inspector is drawn in.
class Palette:
	extends RefCounted
	var panel: Color
	var edge: Color
	var text: Color
	var muted: Color
	var button: Color = Color("#4b4e55")
	var button_hover: Color = Color("#5b5f67")
	var button_pressed: Color = Color("#393c42")
	var button_disabled: Color = Color("#303238")
	var disabled_text: Color = Color("#797979")
	var edge_width: int = 2
	## An entry's plate: darker than the panel it stands in.
	var plate: Color

	func _init(panel_color: Color, edge_color: Color, text_color: Color, muted_color: Color) -> void:
		panel = panel_color
		plate = panel_color.darkened(0.3)
		edge = edge_color
		text = text_color
		muted = muted_color


static func italic() -> Font:
	return load(FONT_FOLDER % "italic") as Font


static func bold() -> Font:
	return load(FONT_FOLDER % "bold") as Font


## The gap under every title, for a card's panel [param card_panel_height] tall.
static func title_gap(card_panel_height: float) -> int:
	return floori(maxf(card_panel_height, 0.0) * TITLE_GAP_SHARE)


## A theme for everything under an Inspector: its buttons shaded gray, lit from above with a
## dark lip, and its text in [param palette]'s colors.
static func theme(palette: Palette, font_size: int) -> Theme:
	var made: Theme = Theme.new()
	made.default_font_size = font_size
	made.set_stylebox("normal", "Button", _button_face(palette.button, false))
	made.set_stylebox("hover", "Button", _button_face(palette.button_hover, false))
	made.set_stylebox("pressed", "Button", _button_face(palette.button_pressed, true))
	made.set_stylebox("hover_pressed", "Button", _button_face(palette.button_pressed, true))
	made.set_stylebox("disabled", "Button", _button_face(palette.button_disabled, false))
	made.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		made.set_color(state, "Button", palette.text)
	made.set_color("font_disabled_color", "Button", palette.disabled_text)
	made.set_color("font_color", "Label", palette.text)
	return made


## A toggle button reading [param text] that takes no focus, so Space still does what it
## does, Dither Shaded in [param palette]'s colors.
static func toggle(text: String, font_size: int, palette: Palette) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", font_size)
	shade_button(button, palette)
	return button


## Gives [param button] Dither Shading in every state, as the Deckbox's buttons have
## (A596), and makes it BUTTON_HEIGHT tall so the shading is painted for it.
static func shade_button(button: Button, palette: Palette) -> void:
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fill: Color = palette.button
	button.add_theme_stylebox_override("normal", DitherShading.button_plate(fill, false, BUTTON_HEIGHT))
	button.add_theme_stylebox_override("hover", DitherShading.button_plate(fill.lightened(HOVER_LIGHTEN), false, BUTTON_HEIGHT))
	button.add_theme_stylebox_override("pressed", DitherShading.button_plate(fill, true, BUTTON_HEIGHT))
	button.add_theme_stylebox_override("hover_pressed", DitherShading.button_plate(fill, true, BUTTON_HEIGHT))
	button.add_theme_stylebox_override("disabled", DitherShading.disabled_plate(palette.button_disabled, BUTTON_HEIGHT))


## A bordered panel with [param title] centered at its top in bold and a body under it, filled
## through body_of(). It clips what is in it. A backed one holds its body on a backing as
## dark as an entry's plate, from under its title to its bottom, so that only a thin edge
## of the panel shows around its sides and bottom (A593); one whose entries have plates of
## their own, such as State Information, has none.
static func panel(title: String, palette: Palette, title_size: int, is_backed: bool = true) -> PanelContainer:
	var made: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = palette.panel
	style.border_color = palette.edge
	style.set_border_width_all(palette.edge_width)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(EDGE)
	style.content_margin_top = 4
	made.add_theme_stylebox_override("panel", style)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.clip_contents = true
	# Dither Shaded for its own height, painted again whenever that changes (A596).
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.resized.connect(func() -> void: _shade_panel(made, palette))
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# What is in the panel is drawn as it would be anywhere else.
	column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	made.add_child(column)
	var heading: Label = label(title, title_size, palette.muted)
	heading.name = "Title"
	heading.add_theme_font_override("font", bold())
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_backed:
		var backing: PanelContainer = PanelContainer.new()
		backing.name = "Backing"
		backing.add_theme_stylebox_override("panel", plate_style(palette))
		backing.size_flags_vertical = Control.SIZE_EXPAND_FILL
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backing.add_child(body)
		column.add_child(backing)
	else:
		column.add_child(body)
	return made


## Where what a panel holds goes, under its title.
static func body_of(made: PanelContainer) -> VBoxContainer:
	return made.find_child("Body", true, false) as VBoxContainer


static func title_of(made: PanelContainer) -> Label:
	return made.get_node("Column/Title") as Label


## The look of an entry's plate and of a panel's backing: darker than the panel, edged in
## its gray, with what is on it kept INSET from its sides and bottom and [param top] from
## its top (A594).
static func plate_style(palette: Palette, top: float = INSET) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = palette.plate
	style.border_color = palette.edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(INSET)
	style.content_margin_top = top
	return style


## Sets the room between [param made]'s title and its body to [param gap] pixels, and the
## room over the title to the same, so that the title is centered between the panel's top
## and its body whether or not there is anything in it.
static func set_title_gap(made: PanelContainer, gap: int) -> void:
	var column: VBoxContainer = made.get_node("Column") as VBoxContainer
	if column.get_theme_constant("separation") != gap:
		column.add_theme_constant_override("separation", gap)
	made.set_meta(TITLE_ROOM, gap)
	var face: StyleBox = made.get_theme_stylebox("panel")
	if face.content_margin_top != gap:
		face.content_margin_top = gap


## A scroll that fills what is left of [param parent], scrolling only up and down.
static func scroll(parent: Control) -> ScrollContainer:
	var made: ScrollContainer = ScrollContainer.new()
	made.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	made.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(made)
	return made


## A list of entries inside [param in_scroll].
static func list(in_scroll: ScrollContainer) -> VBoxContainer:
	var made: VBoxContainer = VBoxContainer.new()
	made.add_theme_constant_override("separation", 6)
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	in_scroll.add_child(made)
	return made


## The None a panel says when it has nothing to say: dim, in italics, centered in all the
## room it is given.
static func none_label(palette: Palette, font_size: int) -> Label:
	var made: Label = label(NONE, font_size, palette.muted)
	made.name = "None"
	made.add_theme_font_override("font", italic())
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	made.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return made


## Body text that draws its {X} symbols as images.
static func symbol_label(palette: Palette, font_size: int) -> SymbolLabel:
	var made: SymbolLabel = SymbolLabel.new()
	made.set_font_size(font_size)
	made.add_theme_color_override("default_color", palette.text)
	return made


## A title in bold over a sentence that wraps, its {X} symbols drawn as images. With no
## sentence it is the title alone.
static func words(title: String, sentence: String, palette: Palette, font_size: int) -> VBoxContainer:
	var made: VBoxContainer = VBoxContainer.new()
	made.add_theme_constant_override("separation", 0)
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading: Label = label(title, font_size, palette.text)
	heading.add_theme_font_override("font", bold())
	made.add_child(heading)
	if sentence != "":
		var body: SymbolLabel = symbol_label(palette, font_size)
		body.write(sentence)
		made.add_child(body)
	return made


## An entry on a plate of its own, darker than its panel and edged in its gray: its title
## at the top, centered, bold and underlined, and its sentence under it, its {X} symbols
## drawn as images. The title is named EntryTitle and the sentence Sentence.
static func entry_plate(title: String, sentence: String, palette: Palette, font_size: int) -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	# The title sits near the top; the sentence under it is kept INSET from the other edges.
	plate.add_theme_stylebox_override("panel", plate_style(palette, 6.0))
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(column)
	var heading: RichTextLabel = RichTextLabel.new()
	heading.name = "EntryTitle"
	heading.bbcode_enabled = true
	heading.fit_content = true
	heading.scroll_active = false
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_font_override("bold_font", bold())
	heading.add_theme_font_size_override("bold_font_size", font_size)
	heading.add_theme_color_override("default_color", palette.text)
	heading.text = "[center][b][u]%s[/u][/b][/center]" % title.replace("[", "[lb]")
	column.add_child(heading)
	if sentence != "":
		var body: SymbolLabel = symbol_label(palette, font_size)
		body.name = "Sentence"
		body.write(sentence)
		column.add_child(body)
	return plate


## A Reminder's row: its Keyword Icon at twice its size, beside its keyword over its sentence.
## The icon is the row's first child.
static func reminder_row(reminder: Reminder, palette: Palette, font_size: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("%s%s.png" % [KeywordChips.ICON_FOLDER, reminder.icon]) as Texture2D
	# Pixel art: nearest, at twice its size.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	row.add_child(words(reminder.keyword, reminder.text, palette, font_size))
	return row


static func label(text: String, font_size: int, color: Color) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## Frees everything in [param holder].
static func clear(holder: Node) -> void:
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()


## Gives [param back], an Inspector's outermost background, Dither Shading from [param fill]
## (A598), edged in [param edge] [param edge_width] pixels wide and rounded by [param radius],
## and paints it again whenever its height changes. [param content], on it, is drawn as before;
## null for a back with nothing on it.
static func shade_background(back: Control, content: CanvasItem, fill: Color, edge: Color, edge_width: int,
		radius: int) -> void:
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if content != null:
		content.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var paint: Callable = func() -> void:
		if back.has_meta(SHADING_HELD):
			return
		var height: int = int(back.size.y)
		var current: StyleBoxTexture = back.get_theme_stylebox("panel") as StyleBoxTexture
		if height <= 0 or (current != null and current.texture.get_height() == height):
			return
		back.add_theme_stylebox_override("panel", DitherShading.plate(fill.lightened(0.06), fill.darkened(0.3),
			edge, radius, edge_width, 0, height))
	back.resized.connect(paint)
	back.set_meta(REPAINT, paint)
	paint.call()


## Holds off painting [param back]'s Dither Shading again while [param is_held], so that it
## can be resized every frame and its shading only stretched; let go, it is painted for its
## height. A plate takes about 15 ms to paint, too long to paint several every frame.
static func hold_shading(back: Control, is_held: bool) -> void:
	if is_held:
		back.set_meta(SHADING_HELD, true)
		return
	back.remove_meta(SHADING_HELD)
	(back.get_meta(REPAINT) as Callable).call()


## Paints [param made]'s Dither Shading for its height, unless it already has it.
static func _shade_panel(made: PanelContainer, palette: Palette) -> void:
	var height: int = int(made.size.y)
	var current: StyleBoxTexture = made.get_theme_stylebox("panel") as StyleBoxTexture
	if height <= 0 or (current != null and current.texture.get_height() == height):
		return
	var face: StyleBoxTexture = DitherShading.plate(palette.panel.lightened(0.06), palette.panel.darkened(0.3),
		palette.edge, 6, palette.edge_width, 0, height)
	face.set_content_margin_all(EDGE)
	face.content_margin_top = made.get_meta(TITLE_ROOM, 4)
	made.add_theme_stylebox_override("panel", face)


## A button's face, lit from above: its fill, a dark lip underneath and a soft shadow. A
## pressed one sits down on its lip.
static func _button_face(fill: Color, is_pressed: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = fill.darkened(0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8.0)
	style.border_width_bottom = 1 if is_pressed else 4
	style.content_margin_top = 10.0 if is_pressed else 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style
