class_name SceneryPiece
extends RefCounted
## A Scenery Piece (game glossary; ADR 0038): one Scenery Kind placed on a Stage Map, where
## it is drawn with the view at the Start, whether it faces the other way, and how far its
## loop is ahead of the others', so no two creatures move together.

var kind: SceneryKind
## Where it is drawn with the view at the Start, at whole screen pixels.
var rect: Rect2
var is_flipped: bool
## Seconds its loop is ahead.
var phase: float


func _init(placed: SceneryKind, at: Rect2, flipped: bool, ahead: float) -> void:
	kind = placed
	rect = at
	is_flipped = flipped
	phase = ahead


## The frame it shows [param seconds] after the screen opened.
func frame_at(seconds: float) -> Texture2D:
	if kind.frames.size() == 1 or kind.frames_per_second <= 0.0:
		return kind.frames[0]
	return kind.frames[posmod(floori((seconds + phase) * kind.frames_per_second), kind.frames.size())]
