class_name ItemReadout
extends RefCounted
## A Potion or an Armor as a shop's Inspector shows it (milestone 24, signed off with the
## Store's prototype at step 3), after the encounter's Potion Readout: its picture large, a
## Potion's glowing its Rarity's color and an Armor's on its Armor Slot's dark ground, its name
## and its type line, and what it does in a Card Text panel.

const PICTURE_SIDE: float = 204.0
## How far an Armor Icon stands in from its ground's edge.
const ARMOR_INSET: float = 6.0
const SLOT_EDGE: Color = Color("#1c120b")
const NAME_SIZE: int = 30
const TYPE_SIZE: int = 18
const TYPE_COLOR: Color = Color("#9aa3af")


## [param good]'s readout, [param width] wide, filling what it is put in.
static func of(good: StoreGood, width: float) -> Control:
	var entry: SatchelEntry = StoreLayout.entry_of(good)
	var palette: InspectorParts.Palette = DeckbuilderLook.inspector_palette()
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_holder: Control = Control.new()
	art_holder.custom_minimum_size = Vector2(width, PICTURE_SIDE + 40.0)
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art_holder)
	var at: Vector2 = Vector2(roundf((width - PICTURE_SIDE) / 2.0), 24)
	if good.kind == StoreGood.Kind.POTION:
		var art: Control = StoreSpot.picture_of(good, PICTURE_SIDE, false)
		art.position = at
		art_holder.add_child(art)
		var ring: Control = Control.new()
		ring.position = at
		ring.size = Vector2(PICTURE_SIDE, PICTURE_SIDE)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(ring)
		BorderEffects.add_glow(ring, ring.size, Inspector.glow_of(good.potion.rarity))
	else:
		var slot: Panel = Panel.new()
		slot.position = at
		slot.size = Vector2(PICTURE_SIDE, PICTURE_SIDE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ground: StyleBoxFlat = StyleBoxFlat.new()
		ground.bg_color = SatchelLook.SLOT_GROUND
		ground.border_color = SLOT_EDGE
		ground.set_border_width_all(2)
		slot.add_theme_stylebox_override("panel", ground)
		var icon: TextureRect = StoreLook.picture(good.armor.icon,
				(PICTURE_SIDE - 2.0 * ARMOR_INSET) / good.armor.icon.get_width())
		icon.position = Vector2(ARMOR_INSET, ARMOR_INSET)
		slot.add_child(icon)
		art_holder.add_child(slot)
	var title: Label = StoreLook.text(entry.name, NAME_SIZE, Color.WHITE, false)
	title.add_theme_font_override("font", CardFonts.title())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var type_line: Label = StoreLook.text(entry.type_line, TYPE_SIZE, TYPE_COLOR, false)
	type_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(type_line)
	var panel: PanelContainer = InspectorParts.panel("Card Text", palette, DeckbuilderInspector.TITLE_SIZE)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = InspectorParts.body_of(panel)
	for line: String in entry.lines:
		var label: SymbolLabel = InspectorParts.symbol_label(palette, DeckbuilderInspector.BODY_SIZE)
		label.write(line)
		body.add_child(label)
	column.add_child(panel)
	return column
