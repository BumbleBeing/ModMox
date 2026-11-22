class_name StageMapScreen
extends Control
## The Stage Map (game glossary; milestone 17, signed off as prototypes/stage_map_screen):
## the map of the Stage being walked, under the Run Bar. The view frames the Hero's row
## near the bottom and the two rows ahead, scrolling only up and down after the Hero. The
## Hero is their Portrait on the Node they stand on, rocking gently; the Nodes a Path
## allows next glow, and a click on one glides the Portrait there along the link at the
## Game Speed, clicks ignored until it arrives. Only the links the Hero can take now are
## lit. The Stage's Map Backdrop lies behind it all, scrolling with the map, its Scenery
## over it, and each Node stands in a halo that sets it off from the picture (ADR 0038). Hovering a Node names it.
## The Boss breathes in its disc. Arriving at an encounter opens the Deckbox against its
## Villain. A beaten Boss's Spoils lead on to the next Tier's Stage Intro, or to Run Won
## (milestone 19), so the map is never shown with its Boss beaten.
##
## Opened on its own (godot --path . res://ui/stage_map/stage_map_screen.tscn, or the main
## menu's --stage-map) it begins a debug run: --run-seed=N picks the run, --stage=red its
## Tier 1 Stage, --tier=N walks it up to Tier N, and --screenshot=/absolute/path.png saves
## a picture and quits.

const FLAG: String = "--stage-map"
const ICONS: String = "res://ui/sprites/map_nodes/%s.png"
const ICON_NAMES: Dictionary[StageMap.Kind, String] = {
	StageMap.Kind.START: "start", StageMap.Kind.STORE: "store",
	StageMap.Kind.WORKSHOP: "workshop", StageMap.Kind.TROVE: "trove",
	StageMap.Kind.LESSER: "lesser_encounter", StageMap.Kind.ELITE: "elite_encounter",
	StageMap.Kind.CHAOS: "chaos_node",
}
const KIND_NAMES: Dictionary[StageMap.Kind, String] = {
	StageMap.Kind.START: "Start Node", StageMap.Kind.STORE: "Store",
	StageMap.Kind.WORKSHOP: "Workshop", StageMap.Kind.TROVE: "Trove",
	StageMap.Kind.LESSER: "Lesser Encounter", StageMap.Kind.ELITE: "Elite Encounter",
	StageMap.Kind.BOSS: "Boss Encounter", StageMap.Kind.CHAOS: "Chaos Node",
}
const GROUND: Color = Color8(42, 44, 56)
## The Glow on a Node the Hero can move to: a white ring 32 pixels across, drawn at the
## Node's halo scale and tinted the color of a playable thing, at this opacity; brighter
## under the cursor. It eases in and out over this long at Blazing.
const GLOW: Color = Color("#7be36a")
const GLOW_SPRITE: Texture2D = preload("res://ui/sprites/map_nodes/glow.png")
const BOSS_GLOW_SPRITE: Texture2D = preload("res://ui/sprites/map_nodes/boss_glow.png")
const GLOW_ALPHA: float = 0.7
const GLOW_FADE_SECONDS: float = 0.25
const HOVER_LIGHTEN: float = 0.35
## A visited Node is drawn this dark.
const VISITED_TINT: Color = Color(0.45, 0.45, 0.5)
## The Hero's Portrait stands on its Node at twice its size, its foot this far below the
## Node's center, and rocks on its foot this far each way, once in this long.
const PORTRAIT_SCALE: int = 2
const PORTRAIT_FOOT: float = 26.0
const ROCK_DEGREES: float = 4.0
const ROCK_SECONDS: float = 3.4
## How quickly the view eases after the Hero (per second), so the Portrait is seen to move
## up the screen and the view settles after it.
const SCROLL_RATE: float = 3.0
## A link is a row of square dots this big, this far apart, kept this far from a Node.
const DOT: float = 6.0
const DOT_STEP: float = 16.0
const DOT_CLEAR: float = 40.0
const DOT_EDGE: Color = Color8(20, 20, 26)
## The hover label: a slate plate like the Deckbox's, this far under its Node, three
## quarters opaque, easing in and out over this long at Blazing.
const LABEL_SLATE: Color = Color("#2a2f37")
const LABEL_BORDER: Color = Color("#14171c")
const LABEL_TEXT: Color = Color8(228, 231, 238)
const LABEL_HEIGHT: int = 44
const LABEL_GAP: float = 12.0
const LABEL_ALPHA: float = 0.75
const LABEL_FADE_SECONDS: float = 0.15
## Keeps the screen's edges clear of the label.
const LABEL_MARGIN: float = 8.0

## Whether the screen reads the run from RunFlow when it is ready. Tests hand it one.
var starts_itself: bool = true
## How the screen opens another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: SceneFade.change_scene(get_tree(), scene)
## Whether labels and links ease in and out. Off in a screen a test makes, which
## shows each at once; glides always take their time, stepped by advance().
var is_paced: bool = false
var game_speed: GameSpeed.Speed = GameSpeed.Speed.FAST

## The Pause Menu over the screen (milestone 21), made by begin().
var run_pause: RunPause = null

## Whether a run has ended at the main menu, so the menu's --stage-map does not open its
## Stage Map again. Run Lost and the Credits set it as they lead there.
static var has_left: bool = false

var _run: Run = null
var _icons: Dictionary[StageMap.Kind, Texture2D] = {}
var _portrait: Texture2D
var _bar: RunBar
var _label: PanelContainer
var _label_text: Label
var _label_tween: Tween
var _links: StageMapLinks = StageMapLinks.new()
## The Stage's Scenery, placed once, the lower last.
var _scenery: Array[SceneryPiece] = []
## How far each Node's Glow has eased in, from 0 to 1.
var _glow_levels: Dictionary[int, float] = {}
## Each size of halo's picture, by the radius of its Node.
var _halos: Dictionary[float, Texture2D] = {}
## Where the view is, in rows: the row framed at the bottom.
var _scroll_row: float = 1.0
## The Node being glided to, how far along (0 to 1) and how long it takes; -1 when the
## Hero stands still.
var _gliding_to: int = -1
var _glide: float = 0.0
var _glide_seconds: float = 0.0
## The Node under the cursor, which the label names, or -1; and the one it was last placed
## under, which it stays under while it fades out.
var _pointed: int = -1
var _labeled: int = -1
## Seconds since the screen opened, which the rocking and breathing follow.
var _time: float = 0.0


func _ready() -> void:
	if not starts_itself:
		return
	is_paced = true
	game_speed = GameSettings.load_from(GameSettings.PATH).game_speed
	if RunFlow.run == null:
		RunFlow.start(debug_run_from(OS.get_cmdline_user_args()))
		RunFlow.finish_intro()
	begin(RunFlow.run)
	var picture: String = EncounterScreen.screenshot_path(OS.get_cmdline_user_args())
	if picture != "":
		set_process(false)
		for frame: int in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## The debug run the command line asks for: --run-seed=N (1 if not given) and, with
## --stage=red or another color, that Tier 1 Stage in place of a rolled one; with --tier=N,
## walked up to Tier N, its earlier Stages counted as won (milestone 19).
static func debug_run_from(arguments: PackedStringArray) -> Run:
	var run_seed: int = 1
	var stage: StageDefinition = null
	var tier: int = Run.FIRST_TIER
	for argument: String in arguments:
		if argument.begins_with("--run-seed="):
			run_seed = int(argument.trim_prefix("--run-seed="))
		elif argument.begins_with("--tier="):
			tier = clampi(int(argument.trim_prefix("--tier=")), Run.FIRST_TIER, Run.LAST_TIER)
		elif argument.begins_with("--stage="):
			var color: String = argument.trim_prefix("--stage=")
			for each: StageDefinition in ContentStages.all():
				if each.backdrop() == color and each.tier == Run.FIRST_TIER:
					stage = each
	return Run.debug(run_seed, stage, tier)


## Shows [param run]'s Stage, the view framing the Hero's row.
func begin(run: Run) -> void:
	_run = run
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	for kind: StageMap.Kind in ICON_NAMES:
		_icons[kind] = load(ICONS % ICON_NAMES[kind]) as Texture2D
	_portrait = PlayerPortraits.texture_of(MmEncounterSetup.HERO_PLAYER_ID)
	_build_label()
	_bar = RunBar.new()
	_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(_bar)
	_bar.show_run(run)
	_bar.deckbox_pressed.connect(func() -> void: navigate.call(Screens.scene(RunFlow.open_deckbox())))
	run_pause = RunPause.over(self, func(scene: String) -> void: navigate.call(scene),
		GameSettings.PATH if starts_itself else "")
	_scroll_row = StageMapLayout.framed_row(_hero_row())
	_links.ease_toward(run.stage_visit, -1, 1.0)
	_ease_glows(1.0)
	_scenery = SceneryLayout.place(run.stage_visit)
	queue_redraw()


## The Stage's Map Backdrop, or null when it shows the plain slate.
func map_backdrop() -> Texture2D:
	return _run.stage_visit.stage.map_backdrop


## Where the Map Backdrop is drawn now.
func map_backdrop_rect() -> Rect2:
	return StageMapLayout.map_backdrop_rect(_scroll_row)


## The Stage's Scenery Pieces, the lower last.
func scenery() -> Array[SceneryPiece]:
	return _scenery


## Where the Scenery Piece [param index] is drawn now.
func scenery_rect(index: int) -> Rect2:
	return SceneryLayout.screen_rect(_scenery[index], _scroll_row)


func run_bar() -> RunBar:
	return _bar


func scroll_row() -> float:
	return _scroll_row


func is_gliding() -> bool:
	return _gliding_to != -1


## Where the Node [param id] is drawn now.
func node_spot(id: int) -> Vector2:
	var node: MapNode = _run.stage_visit.map.nodes[id]
	return StageMapLayout.node_spot(node, _run.stage_visit.offsets.get(id, Vector2.ZERO), _scroll_row)


## Where the Hero's Portrait stands now: on their Node, or part way along the link.
func hero_spot() -> Vector2:
	var spot: Vector2 = node_spot(_run.stage_visit.current)
	if _gliding_to == -1:
		return spot
	return spot.lerp(node_spot(_gliding_to), StageMapLayout.eased(_glide))


## The Nodes that glow now: those the Hero may move to, while they stand still.
func glowing() -> Array[int]:
	if _gliding_to != -1:
		return []
	return _run.stage_visit.choices()


## How opaque the Glow on the Node [param id] is drawn now: GLOW_ALPHA on a Node the Hero
## can move to, none elsewhere, and between while it eases.
func glow_of(id: int) -> float:
	return GLOW_ALPHA * StageMapLayout.eased(_glow_levels.get(id, 0.0))


## The tint the Node [param id] is drawn with: darker once visited.
func node_tint(id: int) -> Color:
	return VISITED_TINT if _run.stage_visit.is_visited(id) else Color.WHITE


## The color of the link between Nodes [param a] and [param b] now.
func link_color(a: int, b: int) -> Color:
	return _links.color_of(_run.stage_visit, a, b, _gliding_to, _glide)


## The picture drawn on the Boss's Node.
func boss_portrait() -> Texture2D:
	return _run.stage_visit.boss.sprite


## What the hover label says, or "" while it is hidden.
func label_text() -> String:
	return _label_text.text if _pointed != -1 else ""


func label_rect() -> Rect2:
	return _label.get_rect()


## A click at [param point]: on a glowing Node, the Hero sets off for it. Says whether it
## did anything.
func click_at(point: Vector2) -> bool:
	var id: int = StageMapLayout.node_at(point, _run.stage_visit, _scroll_row)
	if id == -1 or not glowing().has(id):
		return false
	var from: MapNode = _run.stage_visit.node()
	_gliding_to = id
	_glide = 0.0
	_glide_seconds = StageMapLayout.glide_seconds(from, _run.stage_visit.map.nodes[id], game_speed)
	_point(-1)
	queue_redraw()
	return true


## Names the Node under [param point] in the label, or hides it. Asked each frame from
## where the cursor is; tests call it.
func point_at(point: Vector2) -> void:
	var id: int = -1
	if _gliding_to == -1:
		id = StageMapLayout.node_at(point, _run.stage_visit, _scroll_row)
	_point(id)


## Moves time on by [param delta] seconds: the glide, the view easing after the Hero, the
## links easing, the rocking and breathing.
func advance(delta: float) -> void:
	_time += delta
	if _gliding_to != -1:
		_glide = minf(1.0, _glide + delta / _glide_seconds)
		if _glide >= 1.0:
			_arrive()
	var target: float = StageMapLayout.framed_row(_hero_row())
	_scroll_row = lerpf(_scroll_row, target, 1.0 - exp(-SCROLL_RATE * delta))
	if absf(_scroll_row - target) < 0.002:
		_scroll_row = target
	var step: float = 1.0 if not is_paced else delta / GameSpeed.seconds(StageMapLinks.FADE_SECONDS, game_speed)
	_links.ease_toward(_run.stage_visit, _gliding_to, step)
	_ease_glows(delta / GameSpeed.seconds(GLOW_FADE_SECONDS, game_speed) if is_paced else 1.0)
	_place_label()
	queue_redraw()


func _process(delta: float) -> void:
	if _run == null:
		return
	advance(delta)
	point_at(get_local_mouse_position())


## A press on the map itself; buttons and the Run Bar take their own.
func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT or _run == null:
		return
	if click_at(press.position):
		accept_event()


## The glide is over: the Hero is on the Node, and an encounter there opens the Deckbox.
func _arrive() -> void:
	var id: int = _gliding_to
	_gliding_to = -1
	_glide = 0.0
	var reason: String = _run.move_to(id)
	assert(reason == "", reason)
	queue_redraw()
	var scene: String = Screens.scene(RunFlow.arrive())
	if scene != "":
		navigate.call(scene)


## Where the Hero is, in rows, part way along a glide.
func _hero_row() -> float:
	var row: float = _run.stage_visit.node().row
	if _gliding_to == -1:
		return row
	return lerpf(row, _run.stage_visit.map.nodes[_gliding_to].row, StageMapLayout.eased(_glide))


func _point(id: int) -> void:
	if id == _pointed:
		return
	_pointed = id
	if id != -1:
		_labeled = id
		var node: MapNode = _run.stage_visit.map.nodes[id]
		_label_text.text = _run.stage_visit.boss.name if node.kind == StageMap.Kind.BOSS else KIND_NAMES[node.kind]
		_label.reset_size()
		_place_label()
	_fade_label(LABEL_ALPHA if id != -1 else 0.0)


## Eases the label's alpha to [param alpha] from wherever it is; at once if not paced.
func _fade_label(alpha: float) -> void:
	if _label_tween != null:
		_label_tween.kill()
	if not is_paced:
		_label.modulate.a = alpha
		return
	_label_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_label_tween.tween_property(_label, "modulate:a", alpha, GameSpeed.seconds(LABEL_FADE_SECONDS, game_speed))


## Sets the label centered under its Node, kept on the screen.
func _place_label() -> void:
	if _labeled == -1:
		return
	var node: MapNode = _run.stage_visit.map.nodes[_labeled]
	var center: Vector2 = node_spot(_labeled)
	_label.position = Vector2(
		clampf(center.x - _label.size.x / 2.0, LABEL_MARGIN, StageMapLayout.SCREEN.x - _label.size.x - LABEL_MARGIN),
		center.y + StageMapLayout.radius_of(node.kind) + LABEL_GAP).round()


func _build_label() -> void:
	_label = PanelContainer.new()
	var face: StyleBoxTexture = DitherShading.plate(LABEL_SLATE.lightened(0.06), LABEL_SLATE.darkened(0.3),
			LABEL_BORDER, 6, 2, 0, LABEL_HEIGHT)
	face.content_margin_left = 14
	face.content_margin_right = 14
	face.content_margin_top = 6
	face.content_margin_bottom = 6
	_label.add_theme_stylebox_override("panel", face)
	_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_text = Label.new()
	_label_text.add_theme_font_override("font", UiText.bold())
	_label_text.add_theme_font_size_override("font_size", 22)
	_label_text.add_theme_color_override("font_color", LABEL_TEXT)
	_label.add_child(_label_text)
	_label.modulate.a = 0.0
	add_child(_label)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	if _run == null:
		return
	var visit: StageVisit = _run.stage_visit
	if map_backdrop() != null:
		draw_texture_rect(map_backdrop(), map_backdrop_rect(), false)
	for index: int in _scenery.size():
		_draw_scenery(_scenery[index], scenery_rect(index))
	for node: MapNode in visit.map.nodes:
		for id: int in node.forward:
			_draw_link(node.id, id, visit.map.nodes[id].kind == StageMap.Kind.BOSS)
		if node.side > node.id:
			_draw_link(node.id, node.side, false)
	for node: MapNode in visit.map.nodes:
		_draw_halo(node_spot(node.id), StageMapLayout.radius_of(node.kind))
	for node: MapNode in visit.map.nodes:
		var center: Vector2 = node_spot(node.id)
		if glow_of(node.id) > 0.0:
			_draw_glow(center, node.kind, glow_of(node.id), node.id == _pointed)
		if node.kind == StageMap.Kind.BOSS:
			BossDisc.draw(self, center, StageMapLayout.BOSS_RADIUS, boss_portrait(), _time, node_tint(node.id))
			continue
		var texture: Texture2D = _icons[node.kind]
		var extent: Vector2 = texture.get_size() * StageMapLayout.ICON_SCALE
		draw_texture_rect(texture, Rect2(center - extent / 2.0, extent), false, node_tint(node.id))
	_draw_hero()


## The link between Nodes [param a] and [param b] as a row of square dots, edged dark and
## clear of both Nodes.
func _draw_link(a: int, b: int, is_to_boss: bool) -> void:
	var from: Vector2 = node_spot(a)
	var to: Vector2 = node_spot(b)
	var length: float = from.distance_to(to)
	var direction: Vector2 = (to - from) / length
	var end: float = length - (StageMapLayout.BOSS_RADIUS + 12.0 if is_to_boss else DOT_CLEAR)
	var fill: Color = link_color(a, b)
	var at: float = DOT_CLEAR
	while at <= end:
		var center: Vector2 = (from + direction * at).round()
		draw_rect(Rect2(center - Vector2.ONE * (DOT / 2.0 + 2.0), Vector2.ONE * (DOT + 4.0)), DOT_EDGE)
		draw_rect(Rect2(center - Vector2.ONE * (DOT / 2.0), Vector2.ONE * DOT), fill)
		at += DOT_STEP


## The halo setting a Node of [param radius] off from the Map Backdrop: a 32 x 32 pixel
## circle of the slate, scaled with hard edges.
func _draw_halo(center: Vector2, radius: float) -> void:
	var halo: Texture2D = _halo(radius)
	var extent: Vector2 = halo.get_size() * StageMapLayout.halo_scale(radius)
	draw_texture_rect(halo, Rect2((center - extent / 2.0).round(), extent), false)


## The halo's picture round a Node of [param radius], made once.
func _halo(radius: float) -> Texture2D:
	if _halos.has(radius):
		return _halos[radius]
	var size: int = StageMapLayout.HALO_PIXELS
	var scale: int = StageMapLayout.halo_scale(radius)
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			image.set_pixel(x, y, Color(GROUND, StageMapLayout.halo_alpha(x, y, radius, scale)))
	_halos[radius] = ImageTexture.create_from_image(image)
	return _halos[radius]


## A Scenery Piece in [param rect], showing its frame now and facing its way.
func _draw_scenery(piece: SceneryPiece, rect: Rect2) -> void:
	if rect.end.y < 0.0 or rect.position.y > size.y:
		return
	if piece.is_flipped:
		draw_set_transform(Vector2(rect.end.x, rect.position.y), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(piece.frame_at(_time), Rect2(Vector2.ZERO, rect.size), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		draw_texture_rect(piece.frame_at(_time), rect, false)


## The Glow round a Node of [param kind] the Hero can move to, at [param alpha].
func _draw_glow(center: Vector2, kind: StageMap.Kind, alpha: float, is_hovered: bool) -> void:
	var sprite: Texture2D = BOSS_GLOW_SPRITE if kind == StageMap.Kind.BOSS else GLOW_SPRITE
	var extent: Vector2 = sprite.get_size() * StageMapLayout.halo_scale(StageMapLayout.radius_of(kind))
	var color: Color = GLOW.lightened(HOVER_LIGHTEN) if is_hovered else GLOW
	draw_texture_rect(sprite, Rect2((center - extent / 2.0).round(), extent), false, Color(color, alpha))


## Eases each Node's Glow [param step] of the way in, on a Node the Hero can move to now,
## or out.
func _ease_glows(step: float) -> void:
	var glows: Array[int] = glowing()
	for node: MapNode in _run.stage_visit.map.nodes:
		var target: float = 1.0 if glows.has(node.id) else 0.0
		_glow_levels[node.id] = move_toward(_glow_levels.get(node.id, 0.0), target, step)


## The Hero's Portrait standing on their Node, or part way along the link, rocking on its
## foot. Turning it is the one place the Portrait is drawn other than square (the
## conventions' "Game-side code").
func _draw_hero() -> void:
	if _portrait == null:
		return
	var foot: Vector2 = hero_spot() + Vector2(0.0, PORTRAIT_FOOT)
	var extent: Vector2 = _portrait.get_size() * PORTRAIT_SCALE
	var rock: float = deg_to_rad(ROCK_DEGREES) * sin(TAU * _time / ROCK_SECONDS)
	draw_set_transform(foot, rock, Vector2.ONE)
	draw_texture_rect(_portrait, Rect2(-Vector2(extent.x / 2.0, extent.y), extent), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
