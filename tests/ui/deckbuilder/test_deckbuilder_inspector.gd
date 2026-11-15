extends GutTest
## The deckbuilder's inspector draws every mana and tap symbol as its image: in the Card
## Text, in what a Mod or a Hex says it does, and on the face.

const Fixture: GDScript = preload("res://tests/ui/deckbuilder/support/deckbuilder_fixture.gd")

var _fixture: Fixture
var _inspector: DeckbuilderInspector


func before_each() -> void:
	_fixture = Fixture.new()
	_inspector = DeckbuilderInspector.new()
	add_child_autofree(_inspector)


func after_each() -> void:
	await wait_process_frames(2)


func test_the_card_text_draws_a_cost_as_symbols() -> void:
	_inspector.show_card(_fixture.own("llanowar_elves"), 400.0)

	assert_eq(_inspector.card_text(), "{T}: Add {G}.")
	assert_eq(_inspector.card_text_label().symbols(), ["t", "g"] as Array[String])
	assert_eq(_inspector.card_text_label().get_parsed_text(), "  : Add   .", "One space either side of each symbol.")
	assert_eq(_inspector.face().rules().symbols(), ["{T}", "{G}"] as Array[String], "As the face does.")


func test_a_card_with_no_text_says_none() -> void:
	_inspector.show_card(_fixture.own("grizzly_bears"), 400.0)

	assert_eq(_inspector.card_text(), DeckbuilderInspector.NONE, "Said by a centered None of its own (A577).")
	assert_eq(_inspector.card_text_label().symbols(), [] as Array[String])


func test_what_a_mod_says_it_does_draws_a_cost_as_symbols() -> void:
	var ember: Mod = Fixture.add_symbol_mod(MmMana.Type.RED)
	ember.name = "Ember"
	ember.description = "This card costs {R} more to cast."
	var springs: Mod = Fixture.word_mod("Springs", true)
	springs.description = "This card has \"{2}{U}, {T}: Draw a card.\""
	var plain: Mod = Fixture.word_mod("Plain")
	_inspector.show_card(_fixture.own("grizzly_bears", [ember, springs, plain]), 400.0)

	var labels: Array[SymbolLabel] = _inspector.mod_labels()
	assert_eq(_inspector.mod_names(), ["Ember", "Springs", "Plain"] as Array[String])
	assert_eq(labels.size(), 2, "A Mod that says nothing has only its name.")
	assert_eq(labels[0].symbols(), ["r"] as Array[String])
	assert_eq(labels[0].get_parsed_text(), "This card costs   more to cast.")
	assert_eq(labels[1].symbols(), ["2", "u", "t"] as Array[String])
	assert_false(labels[1].get_parsed_text().contains("{"), "No braces are shown as text.")


func test_no_card_shows_a_brace_as_text_anywhere_in_the_inspector() -> void:
	var ember: Mod = Fixture.add_symbol_mod(MmMana.Type.RED)
	ember.name = "Ember"
	ember.description = "This card costs {R} more to cast."
	for file: String in DirAccess.get_files_at("res://content/cards/alpha/"):
		if not file.ends_with(".tres"):
			continue
		var card: String = file.get_basename()
		_inspector.show_card(_fixture.own(card, [ember]), 400.0)
		_inspector.reminders_button().button_pressed = true
		for label: Label in _inspector.find_children("*", "Label", true, false):
			assert_false(label.text.contains("{"), "%s: \"%s\"" % [card, label.text])
		for label: RichTextLabel in _inspector.find_children("*", "RichTextLabel", true, false):
			assert_false(label.get_parsed_text().contains("{"), "%s: \"%s\"" % [card, label.get_parsed_text()])
		_inspector.reminders_button().button_pressed = false
