class_name MenuCallouts
extends Control
## The Menu Soldier's Effect Callouts on the main menu: draws each callout's words where its
## EffectCallout is, in the menu's bold face, turned as they rock. It covers the menu and
## takes no clicks.

var _soldier: MenuSoldier
var _callouts: EffectCallouts
var _font: Font = UiText.bold()
## Whether any were drawn last frame, so that the last is wiped once it has faded out.
var _was_showing: bool = false


## Callouts about [param soldier], placed with [param random], or at random if none is given.
func _init(soldier: MenuSoldier, random: RandomNumberGenerator = null) -> void:
	_soldier = soldier
	# A new generator starts from a random seed of its own.
	_callouts = EffectCallouts.new(soldier.sequence(), random if random != null else RandomNumberGenerator.new())
	# After the soldier's, so that it reads his sequence as it is this frame.
	process_priority = soldier.process_priority + 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Smooth, not the menu's nearest pixels, so that the words stay clean as they rock.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_anchors_preset(Control.PRESET_FULL_RECT)


## When they appear, where they are and how they look.
func callouts() -> EffectCallouts:
	return _callouts


func _process(_delta: float) -> void:
	_callouts.set_ground(_soldier.get_global_rect(), (get_parent() as Control).get_global_rect())
	var showing: bool = not _callouts.shown().is_empty()
	if showing or _was_showing:
		queue_redraw()
	_was_showing = showing


func _draw() -> void:
	for callout: EffectCallout in _callouts.shown():
		var age: float = _callouts.age_of(callout)
		var drawn: Rect2 = callout.drawn_rect(_callouts.square(), age)
		# Turned about the words' middle, which is on whole pixels with them when level.
		draw_set_transform(drawn.get_center() - global_position, callout.angle(age))
		var baseline: Vector2 = -drawn.size / 2 + Vector2(0, _font.get_ascent(EffectCallout.FONT_SIZE))
		draw_string(_font, baseline, callout.words(), HORIZONTAL_ALIGNMENT_LEFT, -1, EffectCallout.FONT_SIZE,
				Color(callout.color(), callout.opacity(age)))
	draw_set_transform(Vector2.ZERO)
