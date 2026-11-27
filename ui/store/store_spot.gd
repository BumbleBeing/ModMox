class_name StoreSpot
extends RefCounted
## Where one good stands on the Store's screen (milestone 24), and the parts of it that change
## when it is selected or bought: what rises, what takes its clicks, its price, its Buy and the
## Sold space that takes its place. A card stands as its face with its Mod Slots, its price
## under it and room kept for its Buy under that; an Item as a Satchel entry on parchment, its
## picture with its price under it, its own Buy opening under the price when it is selected.

var good: StoreGood = null
## What stands in the layout.
var root: Control = null
## What rises when the good is selected.
var lifter: PanelContainer = null
## What the good is drawn in; a Sold space takes the good's place in it.
var holder: Control = null
## What takes the good's clicks, and the cursor.
var target: Control = null
var price_row: HBoxContainer = null
## Whether the price is written on the good's parchment, not under the good on a pane.
var is_price_on_paper: bool = false
var buy_slot: Control = null
## A card's face, or null for an Item.
var face: CardFace = null
var radius: int = StoreLook.PAPER_RADIUS
## How large the good is while it is not selected: what its Sold space is as large as.
var rest: Vector2 = Vector2.ZERO
## The Sold space, once the good is bought.
var sold: Control = null


## A card for sale, [param height] tall, its price red unless [param can_afford].
static func of_card(for_sale: StoreGood, height: float, can_afford: bool) -> StoreSpot:
	var spot: StoreSpot = StoreSpot.new()
	spot.good = for_sale
	var card_size: Vector2 = Vector2(roundf(height * CardGeometry.ASPECT), height)
	spot.radius = int(card_size.x * CardGeometry.CORNER)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.root = column
	spot.holder = Control.new()
	spot.holder.custom_minimum_size = card_size
	spot.holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.lifter = StoreLook.lifter(spot.holder, StoreLook.CARD_LIFT, spot.radius)
	column.add_child(spot.lifter)
	var shadow: Panel = Panel.new()
	shadow.size = card_size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cast: StyleBoxFlat = StyleBoxFlat.new()
	cast.bg_color = Color.BLACK
	cast.set_corner_radius_all(spot.radius)
	cast.shadow_color = StoreLook.SHADOW
	cast.shadow_size = 10
	cast.shadow_offset = Vector2(0, 6)
	shadow.add_theme_stylebox_override("panel", cast)
	spot.holder.add_child(shadow)
	spot.face = DeckbuilderFace.make(for_sale.card, height)
	spot.holder.add_child(spot.face)
	# Over the face, so that nothing drawn on the card takes the cursor from it.
	spot.target = Control.new()
	spot.target.size = card_size
	spot.holder.add_child(spot.target)
	spot.price_row = StoreLook.price(for_sale.price(), can_afford, false)
	spot.price_row.custom_minimum_size = Vector2(0, 32)
	column.add_child(spot.price_row)
	spot.buy_slot = StoreLook.buy_slot(true)
	column.add_child(spot.buy_slot)
	return spot


## An Item for sale as the Satchel writes an entry: its picture with its price under it, then
## its name, its type line and what it does, on parchment as tall as its words need.
static func of_item(for_sale: StoreGood, can_afford: bool) -> StoreSpot:
	var spot: StoreSpot = StoreSpot.new()
	spot.good = for_sale
	spot.is_price_on_paper = true
	var panel: PanelContainer = StoreLook.paper()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder: MarginContainer = MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	spot.holder = holder
	spot.target = panel
	spot.lifter = StoreLook.lifter(holder, StoreLook.ENTRY_LIFT, StoreLook.PAPER_RADIUS)
	spot.root = spot.lifter
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(picture_of(for_sale, StoreLayout.ICON_SIDE, true))
	spot.price_row = StoreLook.price(for_sale.price(), can_afford, true)
	left.add_child(spot.price_row)
	spot.buy_slot = StoreLook.buy_slot(false)
	left.add_child(spot.buy_slot)
	row.add_child(left)
	row.add_child(_writing(StoreLayout.entry_of(for_sale), 24, 18))
	return spot


## An Item's picture, [param side] pixels across: a Potion Icon on its Rarity's plate, or an
## Armor Icon on no ground. [param is_small] as PotionArt takes it.
static func picture_of(item: StoreGood, side: float, is_small: bool) -> Control:
	if item.kind == StoreGood.Kind.POTION:
		var art: PotionArt = PotionArt.new(item.potion.resource_path.get_file().get_basename(), side, is_small,
				item.potion.rarity)
		art.custom_minimum_size = Vector2(side, side)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		return art
	var icon: TextureRect = StoreLook.picture(item.armor.icon, side / item.armor.icon.get_width())
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return icon


## Shows the good as selected, risen with its Buy showing, or lets it back down, over
## [param seconds].
func set_selected(is_selected: bool, can_afford: bool, seconds: float) -> void:
	if is_selected and rest == Vector2.ZERO:
		rest = holder.size
	StoreLook.set_lifted(lifter, is_selected, seconds)
	StoreLook.show_buy(buy_slot, is_selected, can_afford, seconds)


func buy_button() -> Button:
	return StoreLook.buy_of(buy_slot)


## Writes the price in its plain color, or red when it cannot be afforded, and lets Buy be
## pressed or not.
func show_price(can_afford: bool) -> void:
	StoreLook.mark_price(price_row, can_afford, is_price_on_paper)
	buy_button().disabled = not can_afford


## Puts a Sold space where the good stood, the good easing out and the space in over
## [param seconds], and lets the spot back down. Nothing round it moves.
func sell_out(seconds: float) -> void:
	var space: Vector2 = rest if rest != Vector2.ZERO else holder.size
	holder.custom_minimum_size = space
	StoreLook.show_buy(buy_slot, false, false, seconds)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.mouse_default_cursor_shape = Control.CURSOR_ARROW
	for child: Node in holder.get_children():
		Easing.fade_out_and_free(child as Control, seconds)
	sold = StoreLook.sold_space(space, radius)
	holder.add_child(sold)
	Easing.fade_in(sold, seconds)
	face = null
	if not is_price_on_paper:
		# The price goes; its room stays, so the row keeps its height.
		price_row.modulate.a = 0.0
	StoreLook.set_lifted(lifter, false, seconds)


## What an entry says of [param entry]: its name, its type line and what it does.
static func _writing(entry: SatchelEntry, name_size: int, body_size: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width: float = StoreLayout.WORDS_WIDTH
	column.add_child(StoreLook.wrapped(entry.name, name_size, StoreLook.INK, true, width))
	column.add_child(StoreLook.wrapped(entry.type_line, body_size, StoreLook.INK_MUTED, false, width))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	for line: String in entry.lines:
		column.add_child(StoreLook.words(line, body_size, StoreLook.INK, width))
	return column
