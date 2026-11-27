extends GutTest
## Milestone 24: the Satchel window (game glossary, signed off as prototypes/satchel/) over the
## Stage Map, driven by real mouse events through the input pipeline: opened from the Run
## Bar, always on the Armor page; closed by Close or a click on the dimmed ground; its tabs,
## its scrolling lists, and Armor put on and taken off from an entry or an Armor Slot. Barred
## Armor Slots (T3, S12) wait for Statuses (milestone 33).

const ArmorSample := preload("res://tests/support/armor_sample.gd")
const Page := SatchelEntries.Page
const BIG_GULP: String = "res://content/potions/big_gulp.tres"
## A point on the dimmed ground, clear of the window and the Run Bar.
const GROUND: Vector2 = Vector2(100, 540)

var _run: Run
var _viewport: SubViewport
var _screen: StageMapScreen
var _went_to: Array[String] = []
var _helm: Armor
var _other_helm: Armor
var _cuirass: Armor


func before_each() -> void:
	_went_to = []
	RunFlow.clear()
	StageMapScreen.opens_satchel = false
	_run = Run.debug(7)
	_run.held_armor = HeldArmor.new()
	_helm = ArmorSample.armor("Lionguard Helm", Armor.Slot.HELM, [ArmorSample.life(3)])
	_other_helm = ArmorSample.armor("Gravewatch Helm", Armor.Slot.HELM, [ArmorSample.mulligans(1)])
	_cuirass = ArmorSample.armor("Sunwarden's Cuirass", Armor.Slot.CUIRASS, [ArmorSample.life(3)])
	for armor: Armor in [_helm, _other_helm, _cuirass]:
		_run.held_armor.add(armor)
	RunFlow.start(_run)
	RunFlow.finish_intro()


func after_each() -> void:
	RunFlow.clear()
	StageMapScreen.opens_satchel = false
	await wait_process_frames(2)


## S1: the Run Bar's Satchel button opens the window, on the Armor page.
func test_the_run_bars_satchel_button_opens_it_on_the_armor_page() -> void:
	await _open_map()
	assert_false(_satchel().is_open())

	await _click(_center(_screen.run_bar().button(RunBar.SATCHEL)))

	assert_true(_satchel().is_open())
	assert_eq(_satchel().page(), Page.ARMOR)
	assert_true(_satchel().window().is_visible_in_tree())


## S1: while it is open the Stage Map takes no clicks: a press on a glowing Node or on the Run
## Bar's Deckbox button lands on the dimmed ground and only closes the Satchel.
func test_the_stage_map_takes_no_clicks_while_it_is_open() -> void:
	await _open_satchel()
	var node: Vector2 = _screen.node_spot(_run.stage_visit.choices()[0])

	await _click(node)
	assert_false(_screen.is_gliding())
	if not _satchel().is_open():
		await _open_satchel_again()
	await _click(_center(_screen.run_bar().button(RunBar.DECKBOX)))

	assert_false(_screen.is_gliding())
	assert_eq(_went_to, [] as Array[String])


## S2: Close closes it.
func test_close_closes_it() -> void:
	await _open_satchel()

	await _click(_center(_satchel().close_button()))

	assert_false(_satchel().is_open())


## S2: a click on the dimmed ground closes it, and a click inside the window does not.
func test_a_click_on_the_dimmed_ground_closes_it_and_one_inside_does_not() -> void:
	await _open_satchel()
	var window: Rect2 = _satchel().window().get_global_rect()

	await _click(window.position + Vector2(window.size.x / 2.0, 30.0))
	assert_true(_satchel().is_open(), "A click on its title leaves it open.")
	await _click(GROUND)

	assert_false(_satchel().is_open())


## S3: reopened, it is on the Armor page whatever page it was closed on, and shows what is
## Worn.
func test_reopened_it_is_on_the_armor_page_and_shows_what_is_worn() -> void:
	await _open_satchel()
	await _click(_center(_satchel().entry_node("Lionguard Helm")))
	await _click(_center(_satchel().tab(Page.POTIONS)))
	assert_eq(_satchel().page(), Page.POTIONS)
	await _click(_center(_satchel().close_button()))

	await _open_satchel_again()

	assert_eq(_satchel().page(), Page.ARMOR)
	assert_eq(_satchel().slot_armor(Armor.Slot.HELM), _helm)
	assert_true(_satchel().star_of("Lionguard Helm").visible)


## S4: each tab opens its page, and each page has one entry for each kind of Item held, with
## its count.
func test_each_tab_opens_its_page_with_an_entry_for_each_kind_held() -> void:
	await _open_satchel()
	assert_eq(_satchel().titles(), ["Gravewatch Helm", "Lionguard Helm", "Sunwarden's Cuirass"] as Array[String])

	await _click(_center(_satchel().tab(Page.MODS)))
	assert_eq(_satchel().page(), Page.MODS)
	var mods: int = 0
	for mod: Mod in ContentMods.all():
		if not mod.is_hex:
			mods += 1
	assert_eq(_satchel().titles().size(), mods, "One of every Mod in Content that is not a Hex.")

	await _click(_center(_satchel().tab(Page.POTIONS)))
	assert_eq(_satchel().page(), Page.POTIONS)
	assert_eq(_satchel().titles(), ["Big Gulp ×2"] as Array[String])

	await _click(_center(_satchel().tab(Page.ARMOR)))
	assert_eq(_satchel().page(), Page.ARMOR)


## S6 and S8: a Mod's picture is the still Mod Icon in its Rarity's color, on no plate; a
## Potion Icon stands on its Rarity's plate; an Armor Icon has no plate.
func test_each_kind_of_picture_is_drawn_on_its_own_ground() -> void:
	await _open_satchel()
	var armor_picture: TextureRect = _satchel().picture_of("Lionguard Helm") as TextureRect
	assert_not_null(armor_picture)
	assert_eq(armor_picture.texture, _helm.icon)
	assert_false(_satchel().has_plate("Lionguard Helm"))

	await _click(_center(_satchel().tab(Page.MODS)))
	var violent: Mod = load("res://content/mods/violent.tres") as Mod
	var cog: ModIcon = _satchel().picture_of(violent.name) as ModIcon
	assert_not_null(cog, "A Mod's picture is its Mod Icon.")
	assert_eq(cog.rarity(), violent.rarity)
	assert_false(cog.is_turning(), "It is still in the Satchel.")
	assert_false(_satchel().has_plate(violent.name))

	await _click(_center(_satchel().tab(Page.POTIONS)))
	var potion: PotionArt = _satchel().picture_of("Big Gulp") as PotionArt
	assert_not_null(potion, "A Potion's picture is its Potion Icon.")
	assert_eq(potion.plate_color(), PotionArt.PLATES[MmCardDefinition.Rarity.COMMON])
	assert_eq(potion.key(), "big_gulp")


## S6: an entry shows its type line and its words.
func test_an_entry_shows_its_type_line_and_its_words() -> void:
	await _open_satchel()

	assert_eq(_satchel().texts_of("Lionguard Helm"), ["Lionguard Helm", "Helm",
		"You start each encounter with 3 more life."] as Array[String])


## S7: an empty page reads "No Armor held.", "No Mods held." or "No Potions held."
func test_an_empty_page_says_nothing_is_held() -> void:
	_run.held_armor = HeldArmor.new()
	_run.held_mods = HeldMods.new()
	_run.held_potions = HeldPotions.new()
	await _open_satchel()

	assert_eq(_satchel().empty_words(), "No Armor held.")
	assert_null(_satchel().scroll())
	await _click(_center(_satchel().tab(Page.MODS)))
	assert_eq(_satchel().empty_words(), "No Mods held.")
	await _click(_center(_satchel().tab(Page.POTIONS)))
	assert_eq(_satchel().empty_words(), "No Potions held.")


## The Worn column: the Hero's Portrait and name, then the Armor Slots head to foot, an empty
## one showing the faint outline of its kind, its Armor Slot's template.
func test_the_worn_column_shows_the_hero_and_empty_slots_as_outlines() -> void:
	await _open_satchel()

	assert_eq(_satchel().hero_name(), "Hero")
	assert_eq(_satchel().hero_portrait(), PlayerPortraits.texture_of(MmEncounterSetup.HERO_PLAYER_ID))
	for slot: Armor.Slot in Armor.Slot.values():
		assert_null(_satchel().slot_armor(slot))
		var outline: Image = _satchel().slot_picture(slot).texture.get_image()
		var template: Image = Image.load_from_file(ProjectSettings.globalize_path(
			"res://tools/sprites/armor_templates/%s.png" % Armor.slot_name(slot).to_lower()))
		assert_true(_same_pixels(outline, template), "%s's outline is its template." % Armor.slot_name(slot))


## S9: a click on an Armor's entry puts it on: its star shows, its Armor Slot shows its
## icon, and the Armor that was Worn there loses its star.
func test_a_click_on_an_armors_entry_puts_it_on() -> void:
	_run.held_armor.put_on(_helm)
	await _open_satchel()
	assert_true(_satchel().star_of("Lionguard Helm").visible)

	await _click(_center(_satchel().entry_node("Gravewatch Helm")))

	assert_true(_run.held_armor.is_worn(_other_helm))
	assert_true(_satchel().star_of("Gravewatch Helm").visible)
	assert_false(_satchel().star_of("Lionguard Helm").visible)
	assert_eq(_satchel().slot_armor(Armor.Slot.HELM), _other_helm)
	assert_eq(_satchel().slot_picture(Armor.Slot.HELM).texture, _other_helm.icon)
	assert_true(_satchel().is_open())


## S9: putting an Armor on leaves the page scrolled where it was.
func test_putting_on_leaves_the_page_scrolled_where_it_was() -> void:
	_hold_many_helms()
	await _open_satchel()
	var bar: VScrollBar = _satchel().scroll().get_v_scroll_bar()
	assert_gt(bar.max_value, bar.page, "The Armor page is long enough to scroll.")
	_satchel().scroll().scroll_vertical = 200
	await wait_process_frames(2)
	var entry: Control = _satchel().entry_node("Helm 3")

	await _click(_center(entry))

	assert_true(_run.held_armor.is_worn(_satchel().entry_of("Helm 3").armor))
	assert_eq(_satchel().scroll().scroll_vertical, 200)


## S10: a click on a Worn Armor's entry takes it off, and so does a click on it in its Armor
## Slot.
func test_a_click_on_a_worn_armors_entry_or_its_slot_takes_it_off() -> void:
	_run.held_armor.put_on(_helm)
	_run.held_armor.put_on(_cuirass)
	await _open_satchel()

	await _click(_center(_satchel().entry_node("Lionguard Helm")))
	assert_null(_run.held_armor.worn_in(Armor.Slot.HELM))
	assert_false(_satchel().star_of("Lionguard Helm").visible)
	assert_null(_satchel().slot_armor(Armor.Slot.HELM))

	await _click(_center(_satchel().slot_node(Armor.Slot.CUIRASS)))
	assert_null(_run.held_armor.worn_in(Armor.Slot.CUIRASS))
	assert_false(_satchel().star_of("Sunwarden's Cuirass").visible)
	assert_eq(_run.held_armor.count_of(_cuirass), 1, "It is still held.")


## T4: with two of one Armor held and one Worn, it is one entry, "×2", with the star.
func test_two_of_one_armor_with_one_worn_is_one_entry_with_the_star() -> void:
	_run.held_armor.add(_helm)
	_run.held_armor.put_on(_helm)
	await _open_satchel()

	assert_eq(_satchel().titles(), ["Gravewatch Helm", "Lionguard Helm ×2", "Sunwarden's Cuirass"] as Array[String])
	assert_true(_satchel().star_of("Lionguard Helm").visible)


## S11: a right-click on a Worn Armor in its Armor Slot opens the Armor page, from any page,
## scrolled to that entry.
func test_a_right_click_on_a_worn_armor_in_its_slot_opens_its_entry() -> void:
	_hold_many_helms()
	var greaves: Armor = ArmorSample.armor("Thornwalker Greaves", Armor.Slot.GREAVES, [ArmorSample.life(1)])
	_run.held_armor.add(greaves)
	_run.held_armor.put_on(greaves)
	await _open_satchel()
	await _click(_center(_satchel().tab(Page.MODS)))

	await _click(_center(_satchel().slot_node(Armor.Slot.GREAVES)), MOUSE_BUTTON_RIGHT)
	await wait_process_frames(3)

	assert_eq(_satchel().page(), Page.ARMOR)
	assert_true(_run.held_armor.is_worn(greaves), "A right-click takes nothing off.")
	var bar: VScrollBar = _satchel().scroll().get_v_scroll_bar()
	var entry: Control = _satchel().entry_node("Thornwalker Greaves")
	assert_gt(_satchel().scroll().scroll_vertical, 0)
	assert_eq(_satchel().scroll().scroll_vertical, int(minf(entry.position.y, bar.max_value - bar.page)),
		"Scrolled as far toward the entry's top as the list goes.")


## S13: entries on the Mods and Potions pages take no clicks.
func test_entries_on_the_mods_and_potions_pages_take_no_clicks() -> void:
	await _open_satchel()
	var before: Array = _held()

	for page: Page in [Page.MODS, Page.POTIONS]:
		await _click(_center(_satchel().tab(page)))
		var entry: Control = _satchel().entry_node(_satchel().entries()[0].name)
		assert_eq(entry.mouse_default_cursor_shape, Control.CURSOR_ARROW)
		await _click(_center(entry))
		assert_true(_satchel().is_open())

	assert_eq(_held(), before, "Nothing held or Worn changed.")


## S14: a page with more entries than fit scrolls, and one with fewer does not.
func test_a_long_page_scrolls_and_a_short_one_does_not() -> void:
	await _open_satchel()

	await _click(_center(_satchel().tab(Page.MODS)))
	var mods: VScrollBar = _satchel().scroll().get_v_scroll_bar()
	assert_gt(mods.max_value, mods.page, "Every Mod in Content is more than fits.")
	await _click(_center(_satchel().tab(Page.POTIONS)))
	var potions: VScrollBar = _satchel().scroll().get_v_scroll_bar()
	assert_true(potions.max_value <= potions.page, "One kind of Potion fits.")


## S15: --satchel opens the Stage Map of a debug run with the Satchel open, on the Armor page.
func test_the_satchel_flag_opens_the_stage_map_with_the_satchel_open() -> void:
	RunFlow.clear()
	var menu: MainMenu = MainMenu.new()
	menu.navigate = func(scene: String) -> void: _went_to.append(scene)
	menu.quit = func() -> void: pass
	menu.arguments = PackedStringArray([SatchelWindow.FLAG, "--run-seed=7"])
	add_child_autofree(menu)
	await wait_process_frames(2)

	assert_eq(_went_to, [Screens.STAGE_MAP] as Array[String])
	assert_eq(RunFlow.run.run_seed, 7)
	assert_true(StageMapScreen.opens_satchel)
	_run = RunFlow.run
	_went_to.clear()
	await _open_map()
	assert_true(_satchel().is_open())
	assert_eq(_satchel().page(), Page.ARMOR)
	assert_false(StageMapScreen.opens_satchel, "Only once: the map reopened later opens it no more.")


## Opening it stalled the game for seconds: an entry's parchment was painted, pixel by pixel,
## for every height it passed through while its words wrapped at a width it never kept, up to
## thousands of pixels. It is painted only for heights an entry ends at.
func test_no_parchment_is_painted_taller_than_an_entry_ends() -> void:
	SatchelLook.forget_painted()
	await _open_satchel()
	await _click(_center(_satchel().tab(Page.MODS)))
	await wait_process_frames(3)

	var tallest: int = 0
	for entry: SatchelEntry in _satchel().entries():
		tallest = maxi(tallest, int(_satchel().entry_node(entry.name).size.y))
	assert_gt(tallest, 0)
	assert_lte(SatchelLook.painted_paper_heights().max(), tallest)


## What never changes is painted once: opening the Satchel again and turning its pages paints
## nothing it painted before.
func test_opening_it_again_paints_nothing_new() -> void:
	SatchelLook.forget_painted()
	await _open_satchel()
	for page: Page in [Page.MODS, Page.POTIONS, Page.ARMOR]:
		await _click(_center(_satchel().tab(page)))
	await _click(_center(_satchel().close_button()))
	var painted: int = SatchelLook.painted_count()
	assert_gt(painted, 0)

	await _open_satchel_again()
	for page: Page in [Page.MODS, Page.POTIONS, Page.ARMOR]:
		await _click(_center(_satchel().tab(page)))

	assert_eq(SatchelLook.painted_count(), painted)


## A debug run's Stage Map in a viewport of its own, so that real events reach it.
func _open_map() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(StageMapLayout.SCREEN)
	_viewport.gui_disable_input = false
	add_child_autofree(_viewport)
	_screen = StageMapScreen.new()
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	_viewport.add_child(_screen)
	_screen.size = StageMapLayout.SCREEN
	_screen.set_process(false)
	_screen.begin(_run)
	await wait_process_frames(3)


func _open_satchel() -> void:
	await _open_map()
	await _open_satchel_again()


func _open_satchel_again() -> void:
	await _click(_center(_screen.run_bar().button(RunBar.SATCHEL)))
	assert_true(_satchel().is_open(), "The Satchel opened.")


## What the run holds and wears, to compare.
func _held() -> Array:
	return [_run.held_armor.worn(), _run.held_armor.kinds(), _run.held_mods.kinds(), _run.held_potions.all()]


func _satchel() -> SatchelWindow:
	return _screen.satchel()


## Eight Helms named in order, so that the Armor page scrolls.
func _hold_many_helms() -> void:
	for index: int in range(1, 9):
		_run.held_armor.add(ArmorSample.armor("Helm %d" % index, Armor.Slot.HELM, [ArmorSample.life(index)]))


## A real press and release of [param button] at [param at], then a frame for what it changed
## to be laid out.
func _click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_viewport.push_input(motion)
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		click.position = at
		click.global_position = at
		_viewport.push_input(click)
	await wait_process_frames(2)


## Whether [param a] and [param b] show the same: each pixel as see-through, and the same
## color where it shows. Importing changes the color of see-through pixels.
func _same_pixels(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	for y: int in a.get_height():
		for x: int in a.get_width():
			var left: Color = a.get_pixel(x, y)
			var right: Color = b.get_pixel(x, y)
			if absf(left.a - right.a) > 0.01:
				return false
			if left.a > 0.0 and not left.is_equal_approx(right):
				return false
	return true


func _center(control: Control) -> Vector2:
	assert_not_null(control)
	return control.get_global_rect().get_center()
