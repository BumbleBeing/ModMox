extends GutTest
## A Symbol Label: a line of interface text whose {X} symbols are drawn from the mana
## symbol images, as a Card Face's rules text draws them.


func test_a_braced_symbol_is_drawn_as_its_image_and_never_as_text() -> void:
	var label: SymbolLabel = _label("{2}{U}, {T}: Draw a card.")

	assert_eq(label.symbols(), ["2", "u", "t"] as Array[String])
	assert_eq(label.get_parsed_text(), "    ,   : Draw a card.", "An image stands as a space in the parsed text.")
	assert_eq(label.written(), "{2}{U}, {T}: Draw a card.", "What was written is kept as written.")


func test_text_with_no_symbols_is_written_as_it_is() -> void:
	var label: SymbolLabel = _label("Flying")

	assert_eq(label.symbols(), [] as Array[String])
	assert_eq(label.get_parsed_text(), "Flying")


func test_a_symbol_with_no_image_stays_as_text() -> void:
	var label: SymbolLabel = _label("{Q}: Untap.")

	assert_eq(label.symbols(), [] as Array[String])
	assert_eq(label.get_parsed_text(), "{Q}: Untap.")


func test_writing_again_replaces_what_was_written() -> void:
	var label: SymbolLabel = _label("{R}")

	label.write("{G}{G}")

	assert_eq(label.symbols(), ["g", "g"] as Array[String])


func test_text_in_a_color_draws_its_symbols_too() -> void:
	var label: SymbolLabel = SymbolLabel.new()
	add_child_autofree(label)

	label.write_in("Ember   ×2\ncosts {R} more.", Color.GRAY)

	assert_eq(label.get_parsed_text(), "Ember   ×2\ncosts   more.")
	assert_eq(label.symbols(), ["r"] as Array[String])
	assert_eq(label.written(), "Ember   ×2\ncosts {R} more.")


func test_each_symbol_is_shown_with_one_space_before_and_after_it() -> void:
	var label: SymbolLabel = _label("{2}{U}, {T}: Draw a card.")

	assert_eq(label.shown(), "{2} {U} , {T} : Draw a card.")
	assert_eq(label.written(), "{2}{U}, {T}: Draw a card.", "The spaces are only in what is drawn.")


func test_a_space_already_there_is_not_doubled() -> void:
	assert_eq(_label("This card costs {R} more to cast.").shown(), "This card costs {R} more to cast.")
	assert_eq(_label("{T}: Add {G}.").shown(), "{T} : Add {G} .")


func test_a_line_does_not_start_or_end_with_a_space() -> void:
	assert_eq(_label("{R}").shown(), "{R}")
	assert_eq(_label("Add {G}").shown(), "Add {G}")
	var lines: SymbolLabel = SymbolLabel.new()
	add_child_autofree(lines)
	lines.write_lines(["Flying", "{R}: Pump."] as Array[String], [], Color.GRAY, "\n\n")
	assert_eq(lines.shown(), "Flying\n\n{R} : Pump.")


func test_a_symbol_with_no_image_is_left_as_it_is() -> void:
	assert_eq(_label("{Q}: Untap.").shown(), "{Q}: Untap.")


func _label(text: String) -> SymbolLabel:
	var label: SymbolLabel = SymbolLabel.new()
	add_child_autofree(label)
	label.write(text)
	return label
