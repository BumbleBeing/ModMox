extends GutTest
## The ring round the Pinned card (13h, ADR 0033) is a child of what it rings.


func after_each() -> void:
	await wait_process_frames(2)


func test_the_ring_is_part_of_its_host_and_comes_off_again() -> void:
	var host: Control = Control.new()
	add_child_autofree(host)

	BorderEffects.add_pin(host, Vector2(100, 140))
	assert_true(BorderEffects.has_pin(host))
	var ring: Control = host.get_node(BorderEffects.PIN).get_child(0) as Control
	assert_eq(ring.position, Vector2(-4, -4))
	assert_eq(ring.size, Vector2(108, 148))
	assert_eq((host.get_node(BorderEffects.PIN) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)

	BorderEffects.remove_pin(host)
	assert_false(BorderEffects.has_pin(host))


func test_pinning_twice_leaves_one_ring() -> void:
	var host: Control = Control.new()
	add_child_autofree(host)

	BorderEffects.add_pin(host, Vector2(100, 140))
	BorderEffects.add_pin(host, Vector2(100, 140))
	await wait_process_frames(2)

	assert_eq(host.get_child_count(), 1)


func test_in_a_container_the_ring_reaches_back_out_to_the_hosts_edge() -> void:
	var entry: StackEntry = StackEntry.new("", "Shock", "Hero", Color.RED)
	add_child_autofree(entry)
	await wait_process_frames(2)
	var margin: float = entry.get_theme_stylebox("panel").get_margin(SIDE_LEFT)

	BorderEffects.add_pin(entry, entry.size)

	var ring: Control = entry.get_node(BorderEffects.PIN).get_child(0) as Control
	assert_gt(margin, 0.0)
	assert_eq(ring.position.x, -4.0 - margin)
