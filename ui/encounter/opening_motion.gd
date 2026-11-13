class_name OpeningMotion
extends RefCounted
## How the cards of the opening-hand overlay move (game glossary: Opening-Hand Overlay). The
## overlay rebuilds its cards on every redraw, so this is kept outside them, as Face Motion
## is for the board (ADR 0027): it remembers where each card was, and after a redraw each
## one eases to where it now belongs. A card that is new comes from the library, face down,
## and turns face up on the way; a new hand is dealt a card at a time. A card that has left
## the row goes back to the library and turns face down.
##
## It holds no nodes. A pose's center here is the middle of the card's bottom edge, which
## is what a card of a hand turns about, and its turn is in radians.

## A frame never counts for more than this, as in Face Motion.
const LONGEST_FRAME: float = 1.0 / 30.0
## How much of the inverse sine curve a flight follows: all of it at 1, a straight line near
## 0. Higher is faster at the two ends and slower in the middle.
const SINE_REACH: float = 0.95
## The least share of the whole time a flight takes, however short its trip.
const SHORTEST_SHARE: float = 0.4

## How long one card takes to go the full distance. Zero means every card is simply at
## its place.
var seconds: float = 0.0
## How far a card goes in that time. A shorter trip is a quicker flight, in proportion,
## down to the shortest share; a longer one takes no longer. Zero means every flight takes
## the whole time.
var full_distance: float = 0.0
## How long after one card of a new hand leaves the library the next one does.
var gap_seconds: float = 0.0

var _clock: float = 0.0
var _cards: Dictionary[int, Track] = {}
var _leaving: Dictionary[int, Track] = {}


## Lets a frame of [param delta] seconds go by.
func advance(delta: float) -> void:
	_clock += minf(delta, LONGEST_FRAME)
	for object_id: int in _leaving.keys():
		if _along(_leaving[object_id]) >= 1.0:
			_leaving.erase(object_id)


## The row was redrawn: each card in [param targets] belongs at its pose, in that order, and
## every other card has left for [param library]. A card not seen before comes from there.
## With [param is_new_hand] the new cards are dealt one after another, and only once the
## cards of the hand before have gone back. With no [param library] nothing comes or goes.
func show_cards(targets: Dictionary[int, FacePose], library: FacePose, is_new_hand: bool) -> void:
	var is_still: bool = seconds <= 0.0 or library == null
	var wait: float = 0.0
	for object_id: int in _cards.keys():
		if targets.has(object_id):
			continue
		if not is_still:
			_leaving[object_id] = _track(pose_of(object_id), library, _clock, face_of(object_id), 0.0)
			if is_new_hand:
				wait = maxf(wait, seconds * _leaving[object_id].share)
		_cards.erase(object_id)
	if is_still:
		_leaving.clear()
	var dealt: int = 0
	for object_id: int in targets:
		var target: FacePose = targets[object_id]
		if is_still:
			_cards[object_id] = _track(target, target, _clock - seconds, 1.0, 1.0)
		elif _leaving.has(object_id):
			# Taken back while it was on its way: it turns round where it has got to.
			var leaving: Track = _leaving[object_id]
			_cards[object_id] = _track(_pose(leaving), target, _clock, _face(leaving), 1.0)
			_leaving.erase(object_id)
		elif not _cards.has(object_id):
			var starts: float = _clock + wait + (dealt * gap_seconds if is_new_hand else 0.0)
			_cards[object_id] = _track(library, target, starts, 0.0, 1.0)
			dealt += 1
		elif not _cards[object_id].to.is_at(target):
			_cards[object_id] = _track(pose_of(object_id), target, _clock, face_of(object_id), 1.0)
		else:
			_cards[object_id].to = target


## Sends each card of the row that [param targets] names to its pose there, from wherever
## it is: the hand going to its strip when the pregame ends.
func move_to(targets: Dictionary[int, FacePose]) -> void:
	for object_id: int in targets:
		if _cards.has(object_id):
			_cards[object_id] = _track(pose_of(object_id), targets[object_id], _clock, face_of(object_id), 1.0)


## Forgets every card.
func clear() -> void:
	_cards.clear()
	_leaving.clear()


## How to draw the card of the row that is Game Object [param object_id] right now, or
## null if the row has no such card.
func pose_of(object_id: int) -> FacePose:
	return _pose(_cards[object_id]) if _cards.has(object_id) else null


## Where that card belongs once it stops, or null.
func rest_of(object_id: int) -> FacePose:
	return _cards[object_id].to if _cards.has(object_id) else null


## How far that card is turned face up: 0 is its back, 1 its face.
func face_of(object_id: int) -> float:
	return _face(_cards[object_id]) if _cards.has(object_id) else 1.0


## The cards that have left the row and are still on their way to the library.
func leaving_ids() -> Array[int]:
	var ids: Array[int] = _leaving.keys()
	ids.sort()
	return ids


func leaving_pose(object_id: int) -> FacePose:
	return _pose(_leaving[object_id]) if _leaving.has(object_id) else null


func leaving_face(object_id: int) -> float:
	return _face(_leaving[object_id]) if _leaving.has(object_id) else 0.0


## Whether the card of the row that is Game Object [param object_id] is still on its way,
## or waiting to be dealt.
func is_flying(object_id: int) -> bool:
	return _cards.has(object_id) and _along(_cards[object_id]) < 1.0


## Whether any card is still on its way.
func is_moving() -> bool:
	if not _leaving.is_empty():
		return true
	for object_id: int in _cards:
		if _along(_cards[object_id]) < 1.0:
			return true
	return false


func _pose(track: Track) -> FacePose:
	return track.from.blend(track.to, ease_of(_along(track)))


## How far along a flight is, from how far along its time is: fast, slow, fast, the other
## way round from a face on the board. It is an inverse sine curve with its two ends cut
## off, since the whole curve leaves and arrives at a speed without limit and the card is
## seen to jump.
static func ease_of(along: float) -> float:
	var across: float = 2.0 * clampf(along, 0.0, 1.0) - 1.0
	return 0.5 + asin(SINE_REACH * across) / (2.0 * asin(SINE_REACH))


func _face(track: Track) -> float:
	return lerpf(track.face_from, track.face_to, _along(track))


## How far along its time a move is; nothing before it starts.
func _along(track: Track) -> float:
	if seconds <= 0.0:
		return 1.0
	return clampf((_clock - track.started) / (seconds * track.share), 0.0, 1.0)


## A move from [param from] to [param to], taking the share of the whole time that its
## trip is of the full distance.
func _track(from: FacePose, to: FacePose, started: float, face_from: float, face_to: float) -> Track:
	var track: Track = Track.new(from, to, started, face_from, face_to)
	if full_distance > 0.0:
		track.share = clampf(from.center.distance_to(to.center) / full_distance, SHORTEST_SHARE, 1.0)
	return track


## One card's move: from a pose to a pose, starting at a time on the clock, turning from
## one side toward the other.
class Track:
	extends RefCounted

	var from: FacePose
	var to: FacePose
	var started: float
	var face_from: float
	var face_to: float
	## The share of the whole time this move takes.
	var share: float = 1.0

	func _init(from_pose: FacePose, to_pose: FacePose, started_at: float, from_face: float, to_face: float) -> void:
		from = from_pose
		to = to_pose
		started = started_at
		face_from = from_face
		face_to = to_face
