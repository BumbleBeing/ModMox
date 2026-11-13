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


func test_a_card_with_no_keyword_has_no_reminder() -> void:
	assert_eq(Reminders.of(_abilities("prodigal_sorcerer")).size(), 0)
	assert_eq(Reminders.of(_abilities("forest")).size(), 0)


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
