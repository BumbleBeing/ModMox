extends Control
## PROTOTYPE (stage map, ADR 0026), throwaway: draws one generated map and what it took.
## Right / Space: next seed. Left: previous seed. R: a random seed.

const Generator := preload("res://prototypes/stage_map/stage_map_generator.gd")

const PANEL_WIDTH: float = 360.0
const RADIUS: float = 20.0
const LETTERS: Dictionary = {
	Generator.Kind.START: "", Generator.Kind.STORE: "$", Generator.Kind.WORKSHOP: "W",
	Generator.Kind.TROVE: "T", Generator.Kind.LESSER: "L", Generator.Kind.ELITE: "E",
	Generator.Kind.BOSS: "B", Generator.Kind.CHAOS: "?",
}
const NAMES: Dictionary = {
	Generator.Kind.START: "Start Node", Generator.Kind.STORE: "Store",
	Generator.Kind.WORKSHOP: "Workshop", Generator.Kind.TROVE: "Trove",
	Generator.Kind.LESSER: "Lesser Encounter", Generator.Kind.ELITE: "Elite Encounter",
	Generator.Kind.BOSS: "Boss Encounter", Generator.Kind.CHAOS: "Chaos Node",
}
const COLORS: Dictionary = {
	Generator.Kind.START: Color("8a8a8a"), Generator.Kind.STORE: Color("d9b23c"),
	Generator.Kind.WORKSHOP: Color("4f9fd6"), Generator.Kind.TROVE: Color("f2e27a"),
	Generator.Kind.LESSER: Color("b5553c"), Generator.Kind.ELITE: Color("d0342c"),
	Generator.Kind.BOSS: Color("7a1fa2"), Generator.Kind.CHAOS: Color("5aa469"),
}

var run_seed: int = 1
var _map: Generator.StageMap
var _report: Label


func _ready() -> void:
	_report = Label.new()
	_report.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_report.offset_left = -PANEL_WIDTH
	_report.offset_top = 16.0
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_report)
	show_seed(run_seed)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_RIGHT or key.keycode == KEY_SPACE:
		show_seed(run_seed + 1)
	elif key.keycode == KEY_LEFT:
		show_seed(run_seed - 1)
	elif key.keycode == KEY_R:
		show_seed(randi() % 1000000)


func show_seed(new_seed: int) -> void:
	run_seed = new_seed
	var failures: Array[String] = []
	_map = Generator.generate(run_seed, failures)
	_report.text = _describe(failures)
	queue_redraw()


func _describe(failures: Array[String]) -> String:
	var lines: Array[String] = [
		"PROTOTYPE: Stage map (ADR 0026)", "",
		"Right / Space: next seed", "Left: previous seed", "R: random seed", "",
		"Run Seed: %d" % run_seed,
	]
	if _map == null:
		lines.append("NO VALID MAP in %d attempts" % Generator.MAX_ATTEMPTS)
	else:
		lines.append("Attempts: %d" % _map.attempts)
		lines.append("Encounters on a path: %d to %d" % [_map.fewest_encounters, _map.most_encounters])
		lines.append("")
		var counts: Dictionary = {}
		for node: Generator.MapNode in _map.nodes:
			counts[node.kind] = int(counts.get(node.kind, 0)) + 1
		for kind: Generator.Kind in NAMES:
			lines.append("%s  %s: %d" % [LETTERS[kind], NAMES[kind], int(counts.get(kind, 0))])
		lines.append("")
		lines.append("White line: forward link")
		lines.append("Blue dashes: skip link")
		lines.append("Orange line: horizontal link")
	if not failures.is_empty():
		lines.append("")
		lines.append("Thrown away first:")
		var tally: Dictionary = {}
		for reason: String in failures:
			tally[reason] = int(tally.get(reason, 0)) + 1
		for reason: String in tally:
			lines.append("  %d x %s" % [tally[reason], reason])
	return "\n".join(lines)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1d1f24"))
	var font: Font = ThemeDB.fallback_font
	for row: int in range(1, Generator.ROWS + 1):
		var y: float = _spot(row, 1).y
		draw_string(font, Vector2(8.0, y + 5.0), "row %d" % row, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(1, 1, 1, 0.35))
		draw_line(Vector2(60.0, y), Vector2(size.x - PANEL_WIDTH - 10.0, y), Color(1, 1, 1, 0.05))
	if _map == null:
		return
	for node: Generator.MapNode in _map.nodes:
		var from: Vector2 = _spot(node.row, node.column)
		for id: int in node.forward:
			var ahead: Generator.MapNode = _map.nodes[id]
			var to: Vector2 = _spot(ahead.row, ahead.column)
			if ahead.row - node.row == 2 and ahead.kind != Generator.Kind.BOSS:
				draw_dashed_line(from, to, Color("6ec1ff"), 3.0, 10.0)
			else:
				draw_line(from, to, Color(1, 1, 1, 0.75), 2.0, true)
		if node.side > node.id:
			var beside: Generator.MapNode = _map.nodes[node.side]
			draw_line(from, _spot(beside.row, beside.column), Color("ff9d2e"), 5.0, true)
	for node: Generator.MapNode in _map.nodes:
		var center: Vector2 = _spot(node.row, node.column)
		draw_circle(center, RADIUS, COLORS[node.kind])
		draw_arc(center, RADIUS, 0.0, TAU, 32, Color.BLACK, 2.0, true)
		draw_string(font, center + Vector2(-RADIUS, 7.0), LETTERS[node.kind], HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 20, Color.BLACK)


## Where the Node at [param row] and [param column] is drawn. Row 1 is at the bottom.
func _spot(row: int, column: int) -> Vector2:
	var left: float = 70.0
	var width: float = size.x - PANEL_WIDTH - left - 20.0
	var height: float = size.y - 40.0
	return Vector2(
		left + (column - 0.5) * width / Generator.COLUMNS,
		20.0 + height - (row - 0.5) * height / Generator.ROWS)
