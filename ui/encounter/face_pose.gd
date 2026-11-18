class_name FacePose
extends RefCounted
## How one permanent's face is drawn at one moment (Face Motion): where its middle is on
## the screen, how tall it is before any turn, how far it has turned toward tapped (0
## upright, 1 sideways), how solid it is (0 unseen, 1 solid), and how far it lies sideways
## for being attached to another permanent (0 standing on its own, 1 lying behind it).

var center: Vector2 = Vector2.ZERO
var height: float = 0.0
var turn: float = 0.0
var alpha: float = 1.0
var lean: float = 0.0


static func of(face_center: Vector2, face_height: float, face_turn: float, face_alpha: float = 1.0,
		face_lean: float = 0.0) -> FacePose:
	var pose: FacePose = FacePose.new()
	pose.center = face_center
	pose.height = face_height
	pose.turn = face_turn
	pose.alpha = face_alpha
	pose.lean = face_lean
	return pose


## The pose [param weight] of the way from this one to [param to].
func blend(to: FacePose, weight: float) -> FacePose:
	return FacePose.of(center.lerp(to.center, weight), lerpf(height, to.height, weight),
			lerpf(turn, to.turn, weight), lerpf(alpha, to.alpha, weight), lerpf(lean, to.lean, weight))


## Whether [param other] is in the same place, the same size, turned as far and lying as
## far over. How solid
## each is does not count: a face that is fading in is not going anywhere.
func is_at(other: FacePose) -> bool:
	return (absf(center.x - other.center.x) < 0.5 and absf(center.y - other.center.y) < 0.5
			and is_equal_approx(height, other.height) and is_equal_approx(turn, other.turn)
			and is_equal_approx(lean, other.lean))
