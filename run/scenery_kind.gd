class_name SceneryKind
extends Resource
## A Scenery Kind (game glossary; ADR 0038): one kind of Scenery a Stage lists, such as
## Kitty Keep's tree or its cat. It is a picture, or frames looped through at a rate of its
## own, drawn at a whole scale of its own, and says how many of it to place on a Stage Map.
## Saved inside its Stage.
##
## Saved files leave out values equal to these defaults, so never change a default once
## Kinds exist; add a new property instead.

@export var name: String = ""
## Its picture, or the frames of its loop, all one size.
@export var frames: Array[Texture2D] = []
## How many frames a second it loops through; 0 for a still piece.
@export var frames_per_second: float = 0.0
## How many screen pixels square each of its pixels is drawn.
@export var scale: int = 4
## How many of it are placed, at fewest and at most; fewer where there is no room.
@export var least: int = 1
@export var most: int = 1


## Why it cannot be placed, or "" if it can.
func validate() -> String:
	if frames.is_empty():
		return "%s has no picture." % name
	for frame: Texture2D in frames:
		if frame == null or frame.get_size() != frames[0].get_size():
			return "%s's frames are not all one size." % name
	if frames.size() > 1 and frames_per_second <= 0.0:
		return "%s has frames but no rate." % name
	if scale < 1:
		return "%s has no scale." % name
	if least < 0 or least > most:
		return "%s places from %d to %d." % [name, least, most]
	return ""
