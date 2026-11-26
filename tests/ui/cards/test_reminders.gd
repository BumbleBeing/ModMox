extends GutTest
## A Reminder says what one keyword means (13h). The Inspector lists one for each keyword
## a card has, in the order of its Keyword Chips.

const ALPHA: String = "res://content/cards/alpha/%s.tres"


func test_serra_angel_is_reminded_of_flying_then_vigilance() -> void:
	var reminders: Array[Reminder] = Reminders.of(_abilities("serra_angel"))

	assert_eq(_keywords(reminders), ["Flying", "Vigilance"])
	assert_eq(reminders[0].icon, "flying")
	assert_eq(reminders[0].text, "It can be blocked only by creatures with flying or reach.")
	assert_eq(reminders[1].text, "Attacking doesn't cause it to tap.")


func test_protection_names_what_it_protects_from() -> void:
	var reminders: Array[Reminder] = Reminders.of(_abilities("white_knight"))

	assert_eq(_keywords(reminders), ["First strike", "Protection from black"])
	assert_eq(reminders[1].icon, "protection")


func test_lifelink_is_reminded_of_the_life_it_gains() -> void:
	var reminders: Array[Reminder] = Reminders.of([LifelinkAbility.new()] as Array[MmAbility])

	assert_eq(reminders.size(), 1)
	assert_eq(reminders[0].text, "Damage it deals also causes you to gain that much life.")


func test_equip_is_reminded_of_what_it_does_and_named_without_its_cost() -> void:
	var equip: EquipAbility = EquipAbility.new()
	equip.mana_cost = MmManaCost.new()
	equip.mana_cost.generic = 1

	var reminders: Array[Reminder] = Reminders.of([equip] as Array[MmAbility])

	assert_eq(reminders.size(), 1)
	assert_eq(reminders[0].icon, "equip")
	assert_eq(reminders[0].keyword, "Equip", "A plain label draws it, so it has no mana symbol.")
	assert_eq(reminders[0].text, "Pay its cost to attach it to target creature you control. Equip only as a sorcery.")


func test_ward_is_reminded_of_what_it_does_and_named_without_its_cost() -> void:
	var ward: WardAbility = WardAbility.new()
	ward.mana_cost = MmManaCost.new()
	ward.mana_cost.generic = 2

	var reminders: Array[Reminder] = Reminders.of([ward] as Array[MmAbility])

	assert_eq(reminders.size(), 1)
	assert_eq(reminders[0].icon, "ward")
	assert_eq(reminders[0].keyword, "Ward", "A plain label draws it, so it has no mana symbol.")
	assert_eq(reminders[0].text,
		"Whenever it becomes the target of a spell or ability an opponent controls, counter that unless its controller pays the ward cost.")


func test_bestow_is_reminded_of_what_it_does_with_no_icon_after_the_keywords_with_chips() -> void:
	# Engine ADR 0089: by the user's choice it has a Reminder but no Keyword Chip.
	var bestow: BestowAbility = BestowAbility.new()
	bestow.mana_cost = MmManaCost.new()
	bestow.mana_cost.generic = 4

	var reminders: Array[Reminder] = Reminders.of([bestow, FlyingAbility.new()] as Array[MmAbility])

	assert_eq(_keywords(reminders), ["Flying", "Bestow"])
	assert_eq(reminders[1].icon, "")
	assert_eq(reminders[1].text, "You may cast this card as an Aura for its bestow cost. It becomes a creature again if it's not attached.")
	assert_eq(KeywordChips.chips_for([bestow] as Array[MmAbility], KeywordChips.Place.ANYWHERE).size(), 0)


func test_mentor_is_reminded_of_what_it_does_with_no_icon() -> void:
	# By the user's choice, mentor has a Reminder but no Keyword Chip, as bestow has.
	var reminders: Array[Reminder] = Reminders.of([MentorAbility.new(), FlyingAbility.new()] as Array[MmAbility])

	assert_eq(_keywords(reminders), ["Flying", "Mentor"])
	assert_eq(reminders[1].icon, "")
	assert_eq(reminders[1].text,
		"Whenever this creature attacks, put a +1/+1 counter on target attacking creature with lesser power.")
	assert_eq(KeywordChips.chips_for([MentorAbility.new()] as Array[MmAbility], KeywordChips.Place.ANYWHERE).size(), 0)


func test_a_reminder_with_no_icon_is_drawn_with_an_empty_icon_space() -> void:
	var chipless: Reminder = Reminder.new()
	chipless.keyword = "Bestow"
	chipless.text = "It becomes a creature again if it's not attached."

	var row: HBoxContainer = InspectorParts.reminder_row(chipless, InspectorParts.Palette.new(Color.BLACK, Color.GRAY, Color.WHITE, Color.GRAY), 16)

	var icon: TextureRect = row.get_child(0) as TextureRect
	assert_null(icon.texture)
	assert_eq(icon.custom_minimum_size, Vector2(32, 32), "Its words line up with the others'.")
	row.free()


func test_hexproof_is_reminded_of_what_it_does() -> void:
	var reminders: Array[Reminder] = Reminders.of([HexproofAbility.new()] as Array[MmAbility])

	assert_eq(reminders.size(), 1)
	assert_eq(reminders[0].icon, "hexproof")
	assert_eq(reminders[0].keyword, "Hexproof")
	assert_eq(reminders[0].text, "It can't be the target of spells or abilities your opponents control.")


func test_flashback_is_reminded_of_wherever_the_card_is() -> void:
	# Its chip is drawn only in a graveyard, but the Inspector lists its Reminder anywhere.
	var daydream: MmCardDefinition = load("res://content/cards/secrets_of_strixhaven/daydream.tres") as MmCardDefinition

	var reminders: Array[Reminder] = Reminders.of(daydream.abilities)

	assert_eq(reminders.size(), 1)
	assert_eq(reminders[0].icon, "flashback")
	assert_eq(reminders[0].keyword, "Flashback")


func test_a_card_with_no_keyword_has_no_reminder() -> void:
	assert_eq(Reminders.of(_abilities("prodigal_sorcerer")).size(), 0)
	assert_eq(Reminders.of(_abilities("forest")).size(), 0)


func test_menace_is_reminded_that_it_needs_two_blockers() -> void:
	var reminders: Array[Reminder] = Reminders.of([MenaceAbility.new()] as Array[MmAbility])

	assert_eq(_keywords(reminders), ["Menace"])
	assert_eq(reminders[0].text, "It can't be blocked except by two or more creatures.")


func test_skulk_is_reminded_which_creatures_cant_block_it() -> void:
	var reminders: Array[Reminder] = Reminders.of([SkulkAbility.new()] as Array[MmAbility])

	assert_eq(_keywords(reminders), ["Skulk"])
	assert_eq(reminders[0].text, "It can't be blocked by creatures with greater power.")


func test_a_keyword_it_has_twice_is_reminded_once() -> void:
	var abilities: Array[MmAbility] = [FlyingAbility.new(), FlyingAbility.new()]

	assert_eq(_keywords(Reminders.of(abilities)), ["Flying"])


func test_every_keyword_with_an_icon_has_a_reminder() -> void:
	var count: int = 0
	for file: String in DirAccess.get_files_at(KeywordChips.ICON_FOLDER):
		if not file.ends_with(".png"):
			continue
		count += 1
		var icon: String = file.trim_suffix(".png")
		assert_true(Reminders.TEXTS.has(icon), "%s has no Reminder." % icon)
		assert_true((Reminders.TEXTS.get(icon, "") as String).ends_with("."), icon)
	assert_eq(count, Reminders.TEXTS.size(), "And no Reminder is for a keyword that has no icon.")


func test_no_reminder_uses_a_symbol_a_label_cannot_draw() -> void:
	for icon: String in Reminders.TEXTS:
		assert_false(Reminders.TEXTS[icon].contains("{"), icon)


func _abilities(card: String) -> Array[MmAbility]:
	return CardLook.of_definition(load(ALPHA % card) as MmCardDefinition).abilities


func _keywords(reminders: Array[Reminder]) -> Array[String]:
	var keywords: Array[String] = []
	for reminder: Reminder in reminders:
		keywords.append(reminder.keyword)
	return keywords
