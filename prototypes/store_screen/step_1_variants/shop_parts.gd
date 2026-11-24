extends RefCounted
## PROTOTYPE (milestones 24 and 25, step 1): what the Store's and the Workshop's prototypes
## are both drawn from: the panes and the window, parchment, a price, the gold panel, the
## buttons, a Satchel entry, the Sold space and the prototype's own switch bar. Throwaway:
## deleted with the two prototypes once the real screens are ported test-first. Nothing here
## changes a run.

enum Kind { CARD, POTION, ARMOR, MOD }

const SCREEN: Vector2 = Vector2(1920, 1080)
const GUTTER: float = 12.0
## The deckbuilder's pane, which is the Spoils' window color too.
const PANE: Color = Color("#4b3f3f")
const PANE_EDGE: Color = Color("#575a60")
const PANE_RADIUS: int = 14
const STRIP_EDGE: Color = Color("#14171c")
const TEXT: Color = Color8(228, 231, 238)
const MUTED: Color = Color8(154, 163, 181)
## The Spoils' parchment and its ink.
const PAPER: Color = Color("#e9dcbc")
const PAPER_EDGE: Color = Color("#7a6243")
const PAPER_RADIUS: int = 14
const INK: Color = Color8(46, 40, 36)
const INK_MUTED: Color = Color8(108, 96, 84)
## A price that cannot be afforded, on a pane and on parchment.
const RED_ON_DARK: Color = Color("#ff6b61")
const RED_ON_PAPER: Color = Color("#b3261e")
## The Spoils' "Found Items" bar.
const BAR_COLOR: Color = Color("#656a75")
const BAR_EDGE: Color = Color("#1b1e23")
const BAR_HEIGHT: int = 64
## The Run Bar's buttons.
const BUTTON_FILL: Color = Color("#51555e")
const BUTTON_HEIGHT: int = 48
const BUTTON_SIDE: int = 18
const COIN: String = "res://ui/sprites/run_bar/gold_coin.png"
const SHADOW: Color = Color(0, 0, 0, 0.55)
## What a Sold space is hollowed out in.
const HOLLOW: Color = Color(0, 0, 0, 0.3)
const HOLLOW_EDGE: Color = Color(1, 1, 1, 0.16)
## The Satchel's Armor Slot ground, for an Armor Icon in the Inspector.
const SLOT_GROUND: Color = Color("#2c1d12")
const ARMOR_FOLDER: String = "res://ui/sprites/armor/%s.png"
## A 32 × 32 icon is drawn at three times its size on an entry, as in the Satchel.
const ICON_SIDE: float = 96.0
## Prices from Common to Mythic (ADR 0070; the roadmap's placeholders).
const CARD_PRICES: Array[int] = [25, 50, 100, 150]
const POTION_PRICES: Array[int] = [20, 35, 60, 100]
const MOD_PRICES: Array[int] = [40, 75, 125, 160]
const REMOVAL_PRICE: int = 60
const HEX_DISCOUNT: float = 0.4
const MOD_RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Mythic", "Unique"]
const TYPE_NAMES: Dictionary[MmCardTypes.CardType, String] = {
	MmCardTypes.CardType.ARTIFACT: "Artifact", MmCardTypes.CardType.CREATURE: "Creature",
	MmCardTypes.CardType.ENCHANTMENT: "Enchantment", MmCardTypes.CardType.INSTANT: "Instant",
	MmCardTypes.CardType.LAND: "Land", MmCardTypes.CardType.SORCERY: "Sorcery",
}
const EMBLEM_WORDS: String = "You start each encounter with this Emblem:"


## One thing a shop has for sale.
class Good extends RefCounted:
	var kind: Kind = Kind.CARD
	var name: String = ""
	var price: int = 0
	var is_sold: bool = false
	## A card for sale, with whatever Mods and Hexes it carries.
	var card: DeckbuilderCard = null
	var mod: Mod = null
	var type_line: String = ""
	## What an Item does, a sentence to a line.
	var words: Array[String] = []
	## The Emblem an Armor brings, written under its words, or null.
	var emblem: MmCardDefinition = null
	## A Potion's icon, by its file's name, and its Rarity.
	var potion_key: String = ""
	var rarity: MmCardDefinition.Rarity = MmCardDefinition.Rarity.COMMON
	var armor_icon: Texture2D = null


## What a Store asks for [param card] as it is (ADR 0070): its Rarity's price, 40% off for
## each Hex, then half of each Mod's price, to the nearest 5 and never under 5.
static func card_price(card: DeckbuilderCard) -> int:
	var price: float = CARD_PRICES[mini(card.run_card.base.rarity, CARD_PRICES.size() - 1)]
	for mod: Mod in card.mods:
		if mod.is_hex:
			price *= 1.0 - HEX_DISCOUNT
	for mod: Mod in card.mods:
		if not mod.is_hex:
			price += MOD_PRICES[mini(mod.rarity, MOD_PRICES.size() - 1)] / 2.0
	return maxi(5, roundi(price / 5.0) * 5)


## A Mod's type line (milestone 24's words): its Rarity, the card types it accepts in
## alphabetical order joined by "/", and "Mod". "Omni" for every type, "Nonland" for every
## type but land.
static func mod_type_line(mod: Mod) -> String:
	var accepted: String = ""
	if mod.card_types.size() >= TYPE_NAMES.size():
		accepted = "Omni"
	elif mod.card_types.size() == TYPE_NAMES.size() - 1 and not mod.card_types.has(MmCardTypes.CardType.LAND):
		accepted = "Nonland"
	else:
		var named: Array[String] = []
		for card_type: MmCardTypes.CardType in mod.card_types:
			named.append(TYPE_NAMES[card_type])
		named.sort()
		accepted = "/".join(named)
	return "%s %s Mod" % [MOD_RARITY_NAMES[mod.rarity], accepted]


static func text(written: String, font_size: int, color: Color, is_bold: bool) -> Label:
	var made: Label = Label.new()
	made.text = written
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A line that wraps at its width.
static func wrapped(written: String, font_size: int, color: Color, is_bold: bool) -> Label:
	var made: Label = text(written, font_size, color, is_bold)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


## A line of what something does, its mana symbols drawn as a card's are.
static func words(line: String, font_size: int, color: Color) -> SymbolLabel:
	var made: SymbolLabel = SymbolLabel.new()
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


## A price: the Run Bar's coin and the number, red when it cannot be afforded.
static func price(amount: int, can_afford: bool, is_on_paper: bool, font_size: int = 24) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture(load(COIN) as Texture2D, 2.0))
	var color: Color = INK if is_on_paper else TEXT
	if not can_afford:
		color = RED_ON_PAPER if is_on_paper else RED_ON_DARK
	row.add_child(text(str(amount), font_size, color, true))
	return row


## A parchment panel, shaded with Dither Shading over its own height.
static func paper(padding: Vector2 = Vector2(14, 12)) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade: Callable = func() -> void:
		var made: StyleBoxTexture = DitherShading.plate(PAPER.lightened(0.08), PAPER.darkened(0.15), PAPER_EDGE,
				PAPER_RADIUS - 2, 2, 0, maxi(int(panel.size.y), PAPER_RADIUS * 2 + 1))
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
static func pane(place: Rect2, radius: int = PANE_RADIUS, edge: Color = PANE_EDGE) -> Panel:
	var made: Panel = Panel.new()
	made.position = place.position
	made.size = place.size
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.add_theme_stylebox_override("panel", DitherShading.plate(PANE.lightened(0.06), PANE.darkened(0.3), edge,
			radius, 2, 0, int(place.size.y)))
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


## A window as the Spoils' is, as large as what is put in it.
static func window() -> PanelContainer:
	var made: PanelContainer = PanelContainer.new()
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade: Callable = func() -> void:
		var face: StyleBoxTexture = WindowLook.plate(maxi(int(made.size.y), WindowLook.CORNER * 2))
		face.set_content_margin_all(24)
		made.add_theme_stylebox_override("panel", face)
	shade.call()
	made.resized.connect(shade)
	return made


## A title in bold on the Spoils' dithered gray bar.
static func heading_bar(title: String) -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.add_theme_stylebox_override("panel", DitherShading.plate(BAR_COLOR.lightened(0.1), BAR_COLOR.darkened(0.25),
			BAR_EDGE, 14, 2, 0, BAR_HEIGHT))
	var label: Label = text(title, 32, TEXT, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bar.add_child(label)
	return shadowed(bar, 16, 3.0)


## The gold panel: the coin and the gold held on parchment, with no label.
static func gold_panel(gold: int, is_large: bool) -> Control:
	var panel: PanelContainer = paper(Vector2(24, 12) if is_large else Vector2(18, 6))
	panel.custom_minimum_size = Vector2(200 if is_large else 150, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12 if is_large else 8)
	row.add_child(picture(load(COIN) as Texture2D, 3.0 if is_large else 2.0))
	var count: Label = text(str(gold), 40 if is_large else 30, INK, true)
	count.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(count)
	panel.add_child(row)
	var framed: Control = shadowed(panel, PAPER_RADIUS, 3.0)
	framed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return framed


## A button as the Run Bar's are: its name in bold in the Steel Frame, with the Run Bar's
## icon named [param icon_name] to its right if one is given.
static func button(label: String, icon_name: String = "", height: int = BUTTON_HEIGHT) -> Button:
	var made: Button = Button.new()
	made.text = label
	if icon_name != "":
		made.icon = RunBar._scaled(icon_name)
		made.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		made.add_theme_constant_override("h_separation", 10)
	made.focus_mode = Control.FOCUS_NONE
	made.add_theme_font_override("font", UiText.bold())
	made.add_theme_font_size_override("font_size", 22)
	made.custom_minimum_size = Vector2(0, height)
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state: String in ButtonShading.STATES:
		var plate: StyleBoxTexture = SteelFrame.roomy_plate(BUTTON_FILL, state, height).duplicate() as StyleBoxTexture
		plate.content_margin_left = BUTTON_SIDE
		plate.content_margin_right = BUTTON_SIDE
		made.add_theme_stylebox_override(state, plate)
	return made


## The space a bought good leaves: a hollow of its size that reads "Sold".
static func sold_space(space: Vector2, radius: int) -> Panel:
	var made: Panel = Panel.new()
	made.custom_minimum_size = space
	made.size = space
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HOLLOW
	style.border_color = HOLLOW_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	made.add_theme_stylebox_override("panel", style)
	var label: Label = text("Sold", 26, MUTED, true)
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


## A card for sale: its face with its Mod Slots over a shadow, and its price under it. A
## Sold one is a hollow of its size. [param on_hover] is told when the cursor comes and goes.
static func card_good(good: Good, height: float, can_afford: bool, on_hover: Callable) -> VBoxContainer:
	var card_size: Vector2 = Vector2(roundf(height * CardGeometry.ASPECT), height)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var holder: Control = Control.new()
	holder.custom_minimum_size = card_size
	column.add_child(holder)
	if good.is_sold:
		holder.add_child(sold_space(card_size, int(card_size.x * CardGeometry.CORNER)))
		var gap: Control = Control.new()
		gap.custom_minimum_size = Vector2(0, 32)
		column.add_child(gap)
		return column
	var shadow: Panel = Panel.new()
	shadow.size = card_size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cast: StyleBoxFlat = StyleBoxFlat.new()
	cast.bg_color = Color.BLACK
	cast.set_corner_radius_all(int(card_size.x * CardGeometry.CORNER))
	cast.shadow_color = SHADOW
	cast.shadow_size = 10
	cast.shadow_offset = Vector2(0, 6)
	shadow.add_theme_stylebox_override("panel", cast)
	holder.add_child(shadow)
	holder.add_child(DeckbuilderFace.make(good.card, height))
	# Over the face, so that nothing drawn on the card takes the cursor from it.
	var cover: Control = Control.new()
	cover.size = card_size
	holder.add_child(cover)
	_watch(cover, good, on_hover)
	var cost: HBoxContainer = price(good.price, can_afford, false)
	cost.custom_minimum_size = Vector2(0, 32)
	column.add_child(cost)
	return column


## An Item's picture: a Potion Icon on its Rarity's plate, or an Armor Icon on no ground.
static func icon_tile(good: Good, side: float = ICON_SIDE) -> Control:
	if good.kind == Kind.POTION:
		var art: PotionArt = PotionArt.new(good.potion_key, side, true, good.rarity)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		return art
	var icon: TextureRect = picture(good.armor_icon, side / good.armor_icon.get_width())
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return icon


## An Item for sale as the Satchel writes an entry: its picture with its price under it,
## then its name, its type line and what it does, on parchment as tall as its words need.
## A Sold one is a hollow.
static func item_entry(good: Good, can_afford: bool, on_hover: Callable) -> Control:
	if good.is_sold:
		return sold_space(Vector2(0, 150), PAPER_RADIUS)
	var panel: PanelContainer = paper()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	panel.add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.add_child(icon_tile(good))
	left.add_child(price(good.price, can_afford, true))
	row.add_child(left)
	row.add_child(_writing(good, 24, 18))
	_watch(panel, good, on_hover)
	return panel


## What an entry says of [param good]: its name, its type line and what it does.
static func _writing(good: Good, name_size: int, body_size: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(wrapped(good.name, name_size, INK, true))
	column.add_child(wrapped(good.type_line, body_size, INK_MUTED, false))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	column.add_child(gap)
	for line: String in good.words:
		column.add_child(words(line, body_size, INK))
	if good.emblem != null:
		var look: CardLook = CardLook.of_definition(good.emblem)
		column.add_child(words(EMBLEM_WORDS, body_size, INK))
		var inset: MarginContainer = MarginContainer.new()
		inset.add_theme_constant_override("margin_left", 14)
		var emblem: VBoxContainer = VBoxContainer.new()
		emblem.add_theme_constant_override("separation", 0)
		emblem.add_child(wrapped(look.name, body_size, INK, true))
		emblem.add_child(words(look.rules_text, body_size, INK))
		inset.add_child(emblem)
		column.add_child(inset)
	return column


## Tells [param on_hover] when the cursor comes over [param over] (with the good) and when
## it leaves (with null).
static func _watch(over: Control, good: Good, on_hover: Callable) -> void:
	over.mouse_filter = Control.MOUSE_FILTER_STOP
	over.mouse_entered.connect(func() -> void: on_hover.call(good))
	over.mouse_exited.connect(func() -> void: on_hover.call(null))


## PROTOTYPE: the switch bar, a pill at the foot of the screen that is plainly no part of
## the design, holding [param switches] and then [param note].
static func switch_bar(switches: Array[Button], note: String) -> Control:
	var pill: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.94)
	style.border_color = Color(1, 0.85, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 14
	style.content_margin_right = 18
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 10
	pill.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pill.add_child(row)
	for each: Button in switches:
		each.focus_mode = Control.FOCUS_NONE
		row.add_child(each)
	var label: Label = Label.new()
	label.text = note
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	row.add_child(label)
	var centered: CenterContainer = CenterContainer.new()
	centered.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	centered.offset_top = -52
	centered.offset_bottom = -6
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centered.add_child(pill)
	return centered


## PROTOTYPE: one switch of the bar.
static func bar_switch(label: String, on_press: Callable) -> Button:
	var made: Button = Button.new()
	made.text = label
	made.pressed.connect(on_press)
	return made
