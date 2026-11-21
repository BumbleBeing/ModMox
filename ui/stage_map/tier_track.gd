class_name TierTrack
extends Control
## The Tier Track (game glossary; milestone 19, signed off as step 1 of
## prototypes/run_ends): a row of five medallions on the Stage Intro, one for each Tier.
## Each Stage already played shows its color, the one being entered is lit, drawn half again
## as large and standing in the Stage Map's Glow ring, and those ahead are empty sockets.
## The medallions' centers stand evenly apart, so the middle one is always at the track's
## center, which the Stage Intro puts on the screen's center line, whichever is lit.
##
## Each medallion is a 32 x 32 picture in ui/sprites/tier_track/, drawn by
## tools/sprites/tier_medallions.py, at a whole scale with hard edges.

## Each picture, by the name of its color's Backdrop ("white", "blue" ...) or EMPTY.
const MEDALLIONS: String = "res://ui/sprites/tier_track/tier_%s.png"
const EMPTY: String = "empty"
const PICTURE: float = 32.0
## Each medallion is drawn at SCALE times its picture, the one being entered at LIT_SCALE.
const SCALE: int = 2
const LIT_SCALE: int = 3
## How far apart the medallions' centers are: room for GAP between the lit one and the one
## beside it, kept between every two.
const GAP: float = 24.0
const PITCH: float = PICTURE * (SCALE + LIT_SCALE) / 2.0 + GAP
const GLOW_SPRITE: Texture2D = preload("res://ui/sprites/map_nodes/glow.png")

var _shown: Array[String] = []
var _lit: int = 0
var _textures: Dictionary[String, Texture2D] = {}


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var glow: float = GLOW_SPRITE.get_width() * _glow_scale()
	custom_minimum_size = Vector2(PITCH * (Villain.TIERS - 1) + glow, glow)


## Shows [param run]: the Stages it has played in their colors, the one it is entering lit,
## and the Tiers ahead empty.
func show_run(run: Run) -> void:
	_shown.clear()
	var played: Array[StageVisit] = run.stages_played()
	_lit = played.size()
	for tier: int in range(1, Villain.TIERS + 1):
		_shown.append(played[tier - 1].stage.backdrop() if tier <= played.size() else EMPTY)
	for name: String in _shown:
		if not _textures.has(name):
			_textures[name] = load(MEDALLIONS % name) as Texture2D
	queue_redraw()


## What each medallion shows, Tier 1 first: its Stage's color, or EMPTY.
func medallions() -> Array[String]:
	return _shown.duplicate()


## The Tier being entered, whose medallion is lit.
func lit_tier() -> int:
	return _lit


## How many screen pixels wide and tall the medallion of [param tier] is drawn.
func side_of(tier: int) -> float:
	return PICTURE * (LIT_SCALE if tier == _lit else SCALE)


## Whether the medallion of [param tier] stands in the Glow ring.
func glows(tier: int) -> bool:
	return tier == _lit


## Where the center of the medallion of [param tier] is, in the track's own coordinates.
func center_of(tier: int) -> Vector2:
	return size / 2.0 + Vector2(PITCH * (tier - (Villain.TIERS + 1) / 2), 0.0)


func _draw() -> void:
	for tier: int in range(1, _shown.size() + 1):
		var center: Vector2 = center_of(tier)
		if glows(tier):
			var extent: Vector2 = GLOW_SPRITE.get_size() * _glow_scale()
			draw_texture_rect(GLOW_SPRITE, Rect2((center - extent / 2.0).round(), extent), false,
					Color(StageMapScreen.GLOW, StageMapScreen.GLOW_ALPHA))
		var side: Vector2 = Vector2.ONE * side_of(tier)
		draw_texture_rect(_textures[_shown[tier - 1]], Rect2((center - side / 2.0).round(), side), false)


## The Glow ring's scale round the lit medallion: a Node's halo scale for its radius.
static func _glow_scale() -> int:
	return StageMapLayout.halo_scale(PICTURE * LIT_SCALE / 2.0)
