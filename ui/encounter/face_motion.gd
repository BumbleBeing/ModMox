class_name FaceMotion
extends RefCounted
## Face Motion (game glossary): how a screen that redraws everything from each snapshot is
## animated (A356). It lives on the Encounter Screen, outside the redrawn nodes, and
## remembers where each permanent's face was last drawn. After a redraw the screen says
## where every face now belongs, and each one eases there from wherever it is: place, size
## and turn alike. A face that is new fades in at its place, and one that has left is kept
## as a ghost that fades out where it was.
##
## It holds no nodes. The screen asks for each face's pose every frame and places the node.

## A frame never counts for more than this, so the slow frame that rebuilt the board does
## not eat the start of the move it began.
const LONGEST_FRAME: float = 1.0 / 30.0

## How long a move takes. Zero means every face is simply at its place.
var seconds: float = 0.0

var _clock: float = 0.0
var _faces: Dictionary[int, Track] = {}
var _ghosts: Dictionary[int, Track] = {}


## Lets a frame of [param delta] seconds go by.
func advance(delta: float) -> void:
	_clock += minf(delta, LONGEST_FRAME)
	for object_id: int in _ghosts.keys():
		if _along(_ghosts[object_id].started) >= 1.0:
			_ghosts.erase(object_id)


## The board was redrawn: each face in [param targets] belongs at its pose, drawn from its
## look in [param looks], and every other face has left. With [param is_snapping] nothing
## moves or fades: a rewind or a resized window is not something that happened in the game.
func show_faces(targets: Dictionary[int, FacePose], looks: Dictionary[int, CardLook], is_snapping: bool) -> void:
	var is_still: bool = is_snapping or seconds <= 0.0
	if is_still:
		_ghosts.clear()
	for object_id: int in _faces.keys():
		if targets.has(object_id):
			continue
		if not is_still:
			var shown: FacePose = pose_of(object_id)
			_ghosts[object_id] = Track.new(shown, FacePose.of(shown.center, shown.height, shown.turn, 0.0), _clock, _faces[object_id].look)
		_faces.erase(object_id)
	for object_id: int in targets:
		var target: FacePose = targets[object_id]
		_ghosts.erase(object_id)
		if is_still:
			_faces[object_id] = Track.new(target, target, _clock - seconds, looks[object_id])
		elif not _faces.has(object_id):
			_faces[object_id] = Track.new(FacePose.of(target.center, target.height, target.turn, 0.0), target, _clock, looks[object_id])
		elif not _faces[object_id].to.is_at(target):
			_faces[object_id] = Track.new(pose_of(object_id), target, _clock, looks[object_id])
		else:
			_faces[object_id] = Track.new(_faces[object_id].from, target, _faces[object_id].started, looks[object_id])


## The face of Game Object [param object_id] was carried to [param center] by something
## that is not a move, such as its line being scrolled: a move it is in the middle of goes
## with it.
func rebase(object_id: int, center: Vector2) -> void:
	if not _faces.has(object_id):
		return
	var track: Track = _faces[object_id]
	var carried: Vector2 = center - track.to.center
	_faces[object_id] = Track.new(FacePose.of(track.from.center + carried, track.from.height, track.from.turn, track.from.alpha),
			FacePose.of(center, track.to.height, track.to.turn, track.to.alpha), track.started, track.look)


## Drops the face of Game Object [param object_id] and its ghost: it was out of sight when
## it left, so there is nothing to fade.
func forget(object_id: int) -> void:
	_ghosts.erase(object_id)
	_faces.erase(object_id)


## How to draw the face of Game Object [param object_id] right now, or null if it has none.
func pose_of(object_id: int) -> FacePose:
	if not _faces.has(object_id):
		return null
	var track: Track = _faces[object_id]
	return track.from.blend(track.to, ease_of(_along(track.started)))


## Where the face of Game Object [param object_id] belongs once it stops, or null.
func rest_of(object_id: int) -> FacePose:
	return _faces[object_id].to if _faces.has(object_id) else null


## The Game Objects that have left and are still fading, in ID order.
func ghost_ids() -> Array[int]:
	var ids: Array[int] = _ghosts.keys()
	ids.sort()
	return ids


## How to draw the ghost of Game Object [param object_id] right now, or null.
func ghost_pose(object_id: int) -> FacePose:
	if not _ghosts.has(object_id):
		return null
	var track: Track = _ghosts[object_id]
	return track.from.blend(track.to, _along(track.started))


## What the ghost of Game Object [param object_id] looked like when it left, or null.
func ghost_look(object_id: int) -> CardLook:
	return _ghosts[object_id].look if _ghosts.has(object_id) else null


## Whether any face is still on its way or any ghost still fading.
func is_moving() -> bool:
	if not _ghosts.is_empty():
		return true
	for object_id: int in _faces:
		if _along(_faces[object_id].started) < 1.0:
			return true
	return false


## How far along a move is, from how far along its time is: slow, fast, slow.
static func ease_of(along: float) -> float:
	return along * along * (3.0 - 2.0 * along)


func _along(started: float) -> float:
	if seconds <= 0.0:
		return 1.0
	return clampf((_clock - started) / seconds, 0.0, 1.0)


## One face's move, or one ghost's fade: from a pose to a pose, since a time on the clock,
## and the look it is drawn from.
class Track:
	extends RefCounted

	var from: FacePose
	var to: FacePose
	var started: float
	var look: CardLook

	func _init(from_pose: FacePose, to_pose: FacePose, started_at: float, drawn_from: CardLook) -> void:
		from = from_pose
		to = to_pose
		started = started_at
		look = drawn_from
