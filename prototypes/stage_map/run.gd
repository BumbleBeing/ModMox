extends SceneTree
## PROTOTYPE (stage map, ADR 0026), throwaway. Look at maps:
##   godot --path . -s res://prototypes/stage_map/run.gd -- --seed=7
## Add --screenshot=/absolute/path.png to save a picture and quit.
## Count attempts over many Run Seeds, with no window:
##   godot --headless --path . -s res://prototypes/stage_map/run.gd -- --stats=2000

const Generator := preload("res://prototypes/stage_map/stage_map_generator.gd")

var _screenshot: String = ""


func _initialize() -> void:
	var run_seed: int = 1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			run_seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--screenshot="):
			_screenshot = argument.trim_prefix("--screenshot=")
		elif argument.begins_with("--stats="):
			_print_stats(int(argument.trim_prefix("--stats=")))
			quit()
			return
	var view: Control = (load("res://prototypes/stage_map/map_view.gd") as GDScript).new() as Control
	view.set("run_seed", run_seed)
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	if _screenshot != "":
		_shoot.call_deferred()


func _shoot() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_screenshot)
	quit()


func _print_stats(seeds: int) -> void:
	var started: int = Time.get_ticks_msec()
	var attempts: Array[int] = []
	var reasons: Dictionary = {}
	var kinds: Dictionary = {}
	var fewest: Dictionary = {}
	var most: Dictionary = {}
	var nodes: int = 0
	var failed: int = 0
	for run_seed: int in range(1, seeds + 1):
		var failures: Array[String] = []
		var map: Generator.StageMap = Generator.generate(run_seed, failures)
		for reason: String in failures:
			reasons[reason] = int(reasons.get(reason, 0)) + 1
		if map == null:
			failed += 1
			continue
		attempts.append(map.attempts)
		nodes += map.nodes.size()
		fewest[map.fewest_encounters] = int(fewest.get(map.fewest_encounters, 0)) + 1
		most[map.most_encounters] = int(most.get(map.most_encounters, 0)) + 1
		for node: Generator.MapNode in map.nodes:
			if node.row >= 3 and node.row <= 8:
				kinds[node.kind] = int(kinds.get(node.kind, 0)) + 1
	attempts.sort()
	var total: int = 0
	for count: int in attempts:
		total += count
	var made: int = attempts.size()
	print("Run Seeds: %d, no valid map: %d, time: %d ms" % [seeds, failed, Time.get_ticks_msec() - started])
	print("Attempts per map: mean %.1f, median %d, 95th %d, worst %d" % [
		float(total) / made, attempts[made / 2], attempts[int(made * 0.95)], attempts[made - 1]])
	print("Nodes per map: %.1f" % (float(nodes) / made))
	print("Why attempts were thrown away:")
	var thrown: int = total - made
	for reason: String in reasons:
		print("  %5.1f%%  %s" % [100.0 * reasons[reason] / maxi(thrown, 1), reason])
	print("Generated Nodes by kind (rows 3-8):")
	var generated: int = 0
	for kind: int in kinds:
		generated += kinds[kind]
	for kind: int in kinds:
		print("  %5.1f%%  %s (%.1f per map)" % [
			100.0 * kinds[kind] / generated, Generator.Kind.keys()[kind], float(kinds[kind]) / made])
	print("Fewest encounters on a path: %s" % [fewest])
	print("Most encounters on a path: %s" % [most])
