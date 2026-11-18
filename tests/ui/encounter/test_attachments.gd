extends GutTest
## Which permanents are drawn attached to which (game ADR 0042): an attachment is drawn
## with what it is attached to when that stands in the same line, and on its own otherwise.


func test_attachments_are_listed_under_what_they_are_attached_to_in_id_order() -> void:
	var permanents: Array[MmObjectView] = [_permanent(9, 4), _permanent(4, 0), _permanent(7, 4), _permanent(5, 0)]

	var attached: Dictionary[int, Array] = Attachments.by_host(permanents, [4, 5] as Array[int])

	assert_eq(attached.keys(), [4])
	assert_eq(_ids(attached[4]), [7, 9])


func test_an_attachment_whose_permanent_is_not_among_the_hosts_stands_on_its_own() -> void:
	var permanents: Array[MmObjectView] = [_permanent(9, 30), _permanent(4, 0)]

	assert_eq(Attachments.by_host(permanents, [4] as Array[int]).size(), 0)
	assert_false(Attachments.is_drawn_attached(permanents[0], [4] as Array[int]))
	assert_true(Attachments.is_drawn_attached(_permanent(9, 4), [4] as Array[int]))
	assert_false(Attachments.is_drawn_attached(permanents[1], [4] as Array[int]), "Attached to nothing.")


func _permanent(id: int, attached_to: int) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.attached_to_object_id = attached_to
	return seen


func _ids(views: Array) -> Array[int]:
	var ids: Array[int] = []
	for seen: MmObjectView in views:
		ids.append(seen.id)
	return ids
