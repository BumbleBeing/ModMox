extends RefCounted
## PROTOTYPE (milestones 24 and 25, step 2): what the Store's and the Workshop's prototypes
## are both drawn from: the panes, parchment, a price, the gold panel and its count, the
## buttons, a good's Spot with its lift and its Buy, the Sold space and the prototype's own
## switch bar. Throwaway: deleted with the two prototypes once the real screens are ported
## test-first. Nothing here changes a run.
##
## Step 1 chose the arrangements: A, Bench, for the Store and C, Counter, for the Workshop.
## The three each was chosen from are kept, as they were, in step_1_variants/ (which Godot
## ignores) and in each prototype's pictures/.

enum Kind { CARD, POTION, ARMOR, MOD }

const SCREEN: Vector2 = Vector2(1920, 1080)
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
const INK: Color = Color8(46, 40, 36)
const INK_MUTED: Color = Color8(108, 96, 84)
## A price that cannot be afforded, on a pane and on parchment.
const RED_ON_DARK: Color = Color("#ff6b61")
const RED_ON_PAPER: Color = Color("#b3261e")
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
## The meta a price button is told to stay at least this wide in, while what it reads is
## shorter than what it read.
const HELD_WIDTH: StringName = &"held_width"
const _LIFT: StringName = &"lift"
const _RESERVED: StringName = &"is_reserved"
const _TWEEN: StringName = &"shop_tween"


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


## Where a good stands on the screen, and the parts of it that change when it is selected
## or bought.
class Spot extends RefCounted:
	var good: Good = null
	## What stands in the layout.
	var root: Control = null
	## What rises when the good is selected.
	var lifter: PanelContainer = null
	## What the good is drawn in; a Sold space takes the good's place in it.
	var holder: Control = null
	## What takes the good's clicks.
	var target: Control = null
	var price_row: HBoxContainer = null
	## Whether the price is written on the good's parchment, not under the good on a pane.
	var is_price_on_paper: bool = false
	## The slot its own Buy button stands in, or null when Buy is somewhere else.
	var buy_slot: Control = null
	var radius: int = PAPER_RADIUS
	## How large the good is while it is not selected: what its Sold space is as large as.
	var rest: Vector2 = Vector2.ZERO


## What the Hero holds that a shop's windows change: the Collection and the Decks its
## cards are in, and the Mods a Removal has put back in the Satchel.
class Holdings extends RefCounted:
	var collection: Collection = Collection.new()
	var deckbox: Deckbox = Deckbox.new()
	var returned_mods: Array[Mod] = []

	## The names of the Decks [param card] is in, in the Deckbox's order.
	func decks_of(card: DeckbuilderCard) -> Array[String]:
		var names: Array[String] = []
		for deck: Deck in deckbox.decks():
			if deck.card_ids.has(card.id):
				names.append(deck.name)
		return names


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


## What a Store pays for [param card] as it is: a third of what it asks, rounded down.
static func sale_price(card: DeckbuilderCard) -> int:
	return card_price(card) / 3


## "Currently in Aggro", "Currently in Aggro and Control" or "Currently in Aggro, Control,
## and Midrange": the Decks a card being sold is in, or nothing for none.
static func currently_in(decks: Array[String]) -> String:
	match decks.size():
		0:
			return ""
		1:
			return "Currently in %s" % decks[0]
		2:
			return "Currently in %s and %s" % [decks[0], decks[1]]
	return "Currently in %s, and %s" % [", ".join(decks.slice(0, decks.size() - 1)), decks[decks.size() - 1]]


## A card's tag in the Collection Window: how many Decks it is in.
static func deck_tag(count: int) -> String:
	return "In 1 Deck" if count == 1 else "In %d Decks" % count


## A sample of what the Hero holds, for the Collection Window: some fifty cards of
## Content's, a few of them twice, in three Decks that share some of them; with
## [param has_mods], six more that carry Content's Mods and the deckbuilder sample's Hex;
## and a Power-9 card.
static func sample_holdings(has_mods: bool) -> Holdings:
	var held: Holdings = Holdings.new()
	var pool: Array[MmCardDefinition] = []
	for definition: MmCardDefinition in ContentCards.all():
		if not definition.supertypes.has(MmCardTypes.Supertype.BASIC) \
				and definition.rarity != MmCardDefinition.Rarity.POWER_NINE:
			pool.append(definition)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 24
	var picked: Array[DeckbuilderCard] = []
	for count: int in 40:
		var definition: MmCardDefinition = pool.pop_at(random.randi_range(0, pool.size() - 1))
		picked.append(_hold(held, definition, []))
		if count < 8:
			_hold(held, definition, [])
	var decks: Dictionary[String, Array] = { "Aggro": range(0, 14), "Control": range(10, 25), "Midrange": [12, 13, 14, 15] + range(30, 40) }
	for deck_name: String in decks:
		var deck: Deck = Deck.new()
		deck.name = deck_name
		for index: int in decks[deck_name]:
			deck.card_ids.append(picked[index].id)
		held.deckbox.put(deck)
	_hold(held, load("res://content/cards/alpha/ancestral_recall.tres") as MmCardDefinition, [])
	if not has_mods:
		return held
	var burden: Mod = DeckbuilderSample.burden()
	var modded: Dictionary[String, Array] = {
		"grizzly_bears": ["strong", "tough"], "serra_angel": ["holy"], "lightning_bolt": ["overloaded"],
		"savannah_lions": [burden], "llanowar_elves": [burden, "sharp"],
		"shivan_dragon": ["violent", "unstoppable", "titanic"],
	}
	for file: String in modded:
		var mods: Array[Mod] = []
		for mod: Variant in modded[file]:
			mods.append(mod as Mod if mod is Mod else load("res://content/mods/%s.tres" % mod) as Mod)
		var card: DeckbuilderCard = _hold(held, load("res://content/cards/alpha/%s.tres" % file) as MmCardDefinition, mods)
		if file == "grizzly_bears" or file == "shivan_dragon":
			held.deckbox.decks()[0].card_ids.append(card.id)
	return held


static func _hold(held: Holdings, definition: MmCardDefinition, mods: Array[Mod]) -> DeckbuilderCard:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = definition
	return held.collection.add(run_card, mods)


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
	row.add_child(text(str(amount), font_size, price_color(can_afford, is_on_paper), true))
	return row


static func price_color(can_afford: bool, is_on_paper: bool) -> Color:
	if can_afford:
		return INK if is_on_paper else TEXT
	return RED_ON_PAPER if is_on_paper else RED_ON_DARK


## Writes [param row], a price, in its plain color or in red, as it can be afforded now.
static func mark_price(row: HBoxContainer, can_afford: bool, is_on_paper: bool) -> void:
	(row.get_child(1) as Label).add_theme_color_override("font_color", price_color(can_afford, is_on_paper))


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
static func pane(place: Rect2) -> Panel:
	var made: Panel = Panel.new()
	made.position = place.position
	made.size = place.size
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.add_theme_stylebox_override("panel", DitherShading.plate(PANE.lightened(0.06), PANE.darkened(0.3), PANE_EDGE,
			PANE_RADIUS, 2, 0, int(place.size.y)))
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


## The top bar both shops share: [param title] at the left of [param bar], then the gold
## panel and [param buttons] at its right. Returns the gold panel's count.
static func fill_bar(bar: Panel, title: String, gold: int, buttons: Array[Button]) -> Label:
	# A click on the bar is not a click on the ground.
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var holder: MarginContainer = inside(bar, 0)
	holder.add_theme_constant_override("margin_left", 24)
	holder.add_theme_constant_override("margin_right", 14)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	holder.add_child(row)
	var heading: Label = text(title, 36, TEXT, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(heading)
	var panel: Control = gold_panel(gold)
	row.add_child(panel)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	row.add_child(gap)
	for each: Button in buttons:
		row.add_child(each)
	return panel.find_child("Count", true, false) as Label


## The gold panel: the coin and the gold held on parchment, with no label. Its number is
## named Count.
static func gold_panel(gold: int) -> Control:
	var panel: PanelContainer = paper(Vector2(18, 6))
	panel.custom_minimum_size = Vector2(150, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(picture(load(COIN) as Texture2D, 2.0))
	var count: Label = text(str(gold), 30, INK, true)
	count.name = "Count"
	count.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(count)
	panel.add_child(row)
	var framed: Control = shadowed(panel, PAPER_RADIUS, 3.0)
	framed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return framed


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


## A button as the Run Bar's are: its name in bold in the Steel Frame, with the Run Bar's
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


## A button that confirms a trade: [param word], then the coin and the price once
## set_button_price() gives it one.
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
	var name_label: Label = text(word, 22, Color.WHITE, true)
	name_label.name = "Word"
	row.add_child(name_label)
	var coin: TextureRect = picture(load(COIN) as Texture2D, 2.0)
	coin.name = "Coin"
	row.add_child(coin)
	var amount: Label = text("", 22, Color.WHITE, true)
	amount.name = "Amount"
	row.add_child(amount)
	# As wide as what it reads, whenever that changes, or as wide as it is held to be.
	var fit: Callable = func() -> void:
		made.custom_minimum_size.x = maxf(row.get_combined_minimum_size().x + 2.0 * BUTTON_SIDE + 8.0,
				made.get_meta(HELD_WIDTH, 0.0) as float)
	row.minimum_size_changed.connect(fit)
	made.ready.connect(fit)
	set_button_price(made, -1, true, false)
	return made


## Shows [param amount] on [param made], a price button, in red when it cannot be afforded,
## or no price at all for -1, and lets it be pressed or not.
static func set_button_price(made: Button, amount: int, can_afford: bool, is_live: bool) -> void:
	var row: HBoxContainer = made.get_node("Row") as HBoxContainer
	var price_text: Label = row.get_node("Amount") as Label
	(row.get_node("Coin") as Control).visible = amount >= 0
	price_text.visible = amount >= 0
	price_text.text = str(maxi(amount, 0))
	price_text.add_theme_color_override("font_color", Color.WHITE if can_afford else RED_ON_DARK)
	made.disabled = not is_live
	row.modulate.a = 1.0 if is_live else 0.5


## The deckbuilder's own Inspector on a pane at [param place] of [param on], without Apply
## a Mod and without the deckbuilder's hint, whose words are not a shop's.
static func add_inspector(on: Control, place: Rect2) -> DeckbuilderInspector:
	var back: Panel = pane(place)
	back.theme = DeckbuilderLook.theme()
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.clip_contents = true
	on.add_child(back)
	var inspector: DeckbuilderInspector = DeckbuilderInspector.new()
	inspector.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	(inspector.get_child(0) as Label).text = ""
	back.add_child(inspector)
	# The Inspector keeps room for Apply a Mod at its foot whether or not it is shown, so
	# it is made that much taller than its pane and the pane cuts the room off. Its size
	# is set once it is in the tree: set before, its wrapped hint makes it far too tall.
	var apply: Button = inspector.apply_button()
	apply.visible = false
	inspector.position = Vector2(10, 10)
	inspector.size = place.size - Vector2(20, 20) + Vector2(0, apply.get_combined_minimum_size().y + DeckbuilderInspector.GAP)
	return inspector


# ---------------------------------------------------------------------------------------
# A good's Spot: what lifts when it is selected, where its Buy shows, and the Sold space
# that takes its place.
# ---------------------------------------------------------------------------------------

## [param inner] in a frame that keeps [param lift] pixels above it for it to rise into
## when it is selected, casting a shadow as it does.
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


## The slot a good's own Buy button stands in. A reserved slot keeps its room whether or
## not the button shows; another opens to show it. The button is its only child.
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


## Shows [param spot]'s good as selected, risen with its own Buy showing if it has one, or
## lets it back down, over [param seconds].
static func set_selected(spot: Spot, is_selected: bool, can_afford: bool, seconds: float) -> void:
	if is_selected and spot.rest == Vector2.ZERO:
		spot.rest = spot.holder.size
	set_lifted(spot.lifter, is_selected, seconds)
	if spot.buy_slot != null:
		show_buy(spot.buy_slot, is_selected, can_afford, seconds)


## Puts a Sold space where [param spot]'s good stood, the good easing out and the space in
## over [param seconds], and lets the spot back down. Nothing round it moves.
static func sell_out(spot: Spot, seconds: float) -> void:
	var space: Vector2 = spot.rest if spot.rest != Vector2.ZERO else spot.holder.size
	spot.holder.custom_minimum_size = space
	if spot.buy_slot != null:
		show_buy(spot.buy_slot, false, false, seconds)
	for child: Node in spot.holder.get_children():
		Easing.fade_out_and_free(child as Control, seconds)
	var sold: Panel = sold_space(space, spot.radius)
	spot.holder.add_child(sold)
	Easing.fade_in(sold, seconds)
	if spot.price_row != null and not spot.is_price_on_paper:
		# The price goes; its room stays, so the row keeps its height.
		_stop(spot.price_row)
		if seconds <= 0.0:
			spot.price_row.modulate.a = 0.0
		else:
			var tween: Tween = spot.price_row.create_tween()
			spot.price_row.set_meta(_TWEEN, tween)
			tween.tween_property(spot.price_row, "modulate:a", 0.0, seconds)
	set_lifted(spot.lifter, false, seconds)


## A card for sale: its face with its Mod Slots over a shadow, and its price under it, with
## a reserved slot for its own Buy under that when [param has_buy_slot].
static func card_spot(good: Good, height: float, can_afford: bool, has_buy_slot: bool, on_hover: Callable,
		on_click: Callable) -> Spot:
	var spot: Spot = Spot.new()
	spot.good = good
	var card_size: Vector2 = Vector2(roundf(height * CardGeometry.ASPECT), height)
	spot.radius = int(card_size.x * CardGeometry.CORNER)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spot.root = column
	spot.holder = Control.new()
	spot.holder.custom_minimum_size = card_size
	spot.holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.lifter = lifter(spot.holder, CARD_LIFT, spot.radius)
	column.add_child(spot.lifter)
	var shadow: Panel = Panel.new()
	shadow.size = card_size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cast: StyleBoxFlat = StyleBoxFlat.new()
	cast.bg_color = Color.BLACK
	cast.set_corner_radius_all(spot.radius)
	cast.shadow_color = SHADOW
	cast.shadow_size = 10
	cast.shadow_offset = Vector2(0, 6)
	shadow.add_theme_stylebox_override("panel", cast)
	spot.holder.add_child(shadow)
	spot.holder.add_child(DeckbuilderFace.make(good.card, height))
	# Over the face, so that nothing drawn on the card takes the cursor from it.
	spot.target = Control.new()
	spot.target.size = card_size
	spot.holder.add_child(spot.target)
	watch(spot.target, good, on_hover, on_click)
	spot.price_row = price(good.price, can_afford, false)
	spot.price_row.custom_minimum_size = Vector2(0, 32)
	column.add_child(spot.price_row)
	if has_buy_slot:
		spot.buy_slot = buy_slot(true)
		column.add_child(spot.buy_slot)
	return spot


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
## With [param has_buy_slot] its own Buy opens under its price when it is selected.
static func item_spot(good: Good, can_afford: bool, has_buy_slot: bool, on_hover: Callable, on_click: Callable) -> Spot:
	var spot: Spot = Spot.new()
	spot.good = good
	spot.is_price_on_paper = true
	var panel: PanelContainer = paper()
	var holder: MarginContainer = MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	spot.holder = holder
	spot.target = panel
	spot.lifter = lifter(holder, ENTRY_LIFT, PAPER_RADIUS)
	spot.root = spot.lifter
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(icon_tile(good))
	spot.price_row = price(good.price, can_afford, true)
	left.add_child(spot.price_row)
	if has_buy_slot:
		spot.buy_slot = buy_slot(false)
		left.add_child(spot.buy_slot)
	row.add_child(left)
	row.add_child(_writing(good, 24, 18))
	watch(panel, good, on_hover, on_click)
	return spot


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
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	for line: String in good.words:
		column.add_child(words(line, body_size, INK))
	if good.emblem != null:
		var look: CardLook = CardLook.of_definition(good.emblem)
		column.add_child(words(EMBLEM_WORDS, body_size, INK))
		var inset: MarginContainer = MarginContainer.new()
		inset.add_theme_constant_override("margin_left", 14)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var emblem: VBoxContainer = VBoxContainer.new()
		emblem.add_theme_constant_override("separation", 0)
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem.add_child(wrapped(look.name, body_size, INK, true))
		emblem.add_child(words(look.rules_text, body_size, INK))
		inset.add_child(emblem)
		column.add_child(inset)
	return column


## Makes [param over] the good's own to the mouse: [param on_hover] is told when the cursor
## comes over it (with the good) and when it leaves (with null), and [param on_click] when
## it is clicked.
static func watch(over: Control, good: Good, on_hover: Callable, on_click: Callable) -> void:
	# Pass, not stop: the wheel over a good still scrolls the list it stands in.
	over.mouse_filter = Control.MOUSE_FILTER_PASS
	over.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	over.mouse_entered.connect(func() -> void: on_hover.call(good))
	over.mouse_exited.connect(func() -> void: on_hover.call(null))
	over.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			on_click.call(good))


## The ground under a shop's panes: a click on it, which is a click on nothing, calls
## [param on_click].
static func ground_catcher(on_click: Callable) -> Control:
	var made: Control = Control.new()
	made.set_anchors_preset(Control.PRESET_FULL_RECT)
	made.mouse_filter = Control.MOUSE_FILTER_STOP
	made.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			on_click.call())
	return made


static func _stop(item: Object) -> void:
	if not item.has_meta(_TWEEN):
		return
	var old: Tween = item.get_meta(_TWEEN) as Tween
	if old != null and old.is_valid():
		old.kill()


# ---------------------------------------------------------------------------------------
# PROTOTYPE: its own switches and the real mouse events that drive it for a picture.
# ---------------------------------------------------------------------------------------

## The switch bar, a pill at the foot of the screen that is plainly no part of the design,
## holding [param switches] and then [param note].
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


## One switch of the bar.
static func bar_switch(label: String, on_press: Callable) -> Button:
	var made: Button = Button.new()
	made.text = label
	made.pressed.connect(on_press)
	return made


## A real move of the mouse to the middle of [param over].
static func move_mouse_to(over: Control) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = over.get_global_rect().get_center()
	motion.global_position = motion.position
	over.get_viewport().push_input(motion, true)


## A real left click on the middle of [param over].
static func click_on(over: Control) -> void:
	move_mouse_to(over)
	click_at(over.get_viewport(), over.get_global_rect().get_center())


## A real left click at [param point] of [param viewport].
static func click_at(viewport: Viewport, point: Vector2) -> void:
	for is_pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_pressed
		click.position = point
		click.global_position = point
		viewport.push_input(click, true)
