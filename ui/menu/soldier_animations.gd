class_name SoldierAnimations
extends RefCounted
## The Menu Soldier's animations, each a timeline of his frames: seven seconds long, starting
## and ending on the neutral frame, where he stands still as long at one end as at the other
## (0.6 seconds), so two in a row leave him still for a moment. Transition Animations are him
## being himself; Effect Animations give him a keyword's look between two flashes of its
## color. The frames are built from tools/sprites/menu_sprites.txt by
## tools/sprites/soldier_frames.py.

const SECONDS: float = 7.0
const NEUTRAL: String = "idle_0"
const SPRITES: String = "res://ui/sprites/menu/soldier_%s.png"
## The color of each flash frame: the palette's (tools/sprites/modmox.gpl) white and five
## brights.
const FLASH_COLORS: Dictionary[String, Color] = {
	"flash_white": Color8(255, 255, 255),
	"flash_red": Color8(217, 72, 59),
	"flash_gold": Color8(238, 196, 74),
	"flash_green": Color8(98, 194, 92),
	"flash_blue": Color8(74, 166, 224),
	"flash_violet": Color8(176, 106, 214),
}

## Each timeline is its frames in order, every one with how long it is held, in seconds. A
## step [code][times, [steps]][/code] plays those steps that many times over.
const TRANSITIONS: Dictionary[String, Array] = {
	"lookout": [
		["idle_0", 0.6],
		["look_left_0", 0.2], ["look_left_1", 1.55], ["look_left_0", 0.2],
		["look_right_0", 0.2], ["look_right_1", 1.55], ["look_right_0", 0.2],
		["idle_0", 0.2], ["blink", 0.15], ["idle_0", 0.15],
		["look_left_0", 0.15], ["look_left_1", 0.55], ["idle_0", 0.15], ["look_right_1", 0.55],
		["idle_0", 0.6],
	],
	"doze": [
		["idle_0", 0.6], ["blink", 0.15], ["sleepy", 0.7], ["yawn", 1.0], ["sleepy", 0.5],
		["blink", 0.25], ["asleep_0", 0.8], ["asleep_1", 0.8], ["asleep_0", 0.7],
		["startled", 0.5], ["look_left_0", 0.2], ["look_right_0", 0.2], ["idle_0", 0.6],
	],
	"cheer": [
		["idle_0", 0.6], ["bob", 0.25],
		["cheer_0", 0.35], ["cheer_1", 0.25], ["cheer_0", 0.35], ["cheer_1", 0.25],
		["cheer_0", 0.6], ["bob", 0.25],
		["idle_0", 0.65], ["blink", 0.15], ["idle_0", 0.3], ["bob", 0.25],
		["cheer_0", 0.35], ["cheer_1", 0.25], ["cheer_0", 0.35], ["cheer_1", 0.25],
		["cheer_0", 0.7], ["bob", 0.25],
		["idle_0", 0.6],
	],
}
## Each stands still a moment and flashes its color, shows the changed soldier for a while,
## and flashes back.
const EFFECTS: Dictionary[String, Array] = {
	"boost": [
		["idle_0", 0.6],
		["flash_white", 0.1], ["boost_0", 0.5], ["flash_white", 0.1],
		["boost_1", 0.6], ["boost_2", 0.5], ["boost_1", 0.5], ["boost_2", 0.5],
		["boost_1", 0.8], ["boost_2", 0.5], ["boost_1", 1.1],
		["flash_white", 0.1], ["boost_0", 0.5], ["idle_0", 0.6],
	],
	"lifelink": [
		["idle_0", 0.6], ["flash_red", 0.12],
		[4, [["lifelink_0", 0.8], ["lifelink_1", 0.5]]], ["lifelink_0", 0.36],
		["flash_red", 0.12], ["idle_0", 0.6],
	],
	"deathtouch": [
		["idle_0", 0.6], ["flash_green", 0.12],
		[3, [["deathtouch_0", 0.9], ["deathtouch_1", 0.7]]], ["deathtouch_0", 0.76],
		["flash_green", 0.12], ["idle_0", 0.6],
	],
	"flying": [
		["idle_0", 0.6], ["flash_white", 0.12],
		[9, [["flying_0", 0.3], ["flying_1", 0.3]]], ["flying_0", 0.16],
		["flash_white", 0.12], ["idle_0", 0.6],
	],
	"reach": [
		["idle_0", 0.6], ["flash_green", 0.12],
		[6, [["reach_0", 0.6], ["reach_1", 0.3]]], ["reach_0", 0.16],
		["flash_green", 0.12], ["idle_0", 0.6],
	],
	"vigilance": [
		["idle_0", 0.6], ["flash_white", 0.12],
		[2, [["vigilance_0", 1.1], ["vigilance_1", 1.1]]], ["vigilance_0", 1.16],
		["flash_white", 0.12], ["idle_0", 0.6],
	],
	"haste": [
		["idle_0", 0.6], ["flash_red", 0.12],
		[27, [["haste_0", 0.1], ["haste_1", 0.1]]], ["haste_0", 0.16],
		["flash_red", 0.12], ["idle_0", 0.6],
	],
	"defender": [
		["idle_0", 0.6], ["flash_white", 0.12],
		[2, [["defender_0", 0.8], ["defender_1", 0.8], ["defender_2", 1.0]]], ["defender_0", 0.36],
		["flash_white", 0.12], ["idle_0", 0.6],
	],
	"first_strike": [
		["idle_0", 0.6], ["flash_white", 0.12],
		[3, [["first_strike_0", 1.3], ["first_strike_1", 0.3]]], ["first_strike_0", 0.76],
		["flash_white", 0.12], ["idle_0", 0.6],
	],
	"double_strike": [
		["idle_0", 0.6], ["flash_red", 0.12],
		[4, [
			["double_strike_0", 0.8], ["double_strike_1", 0.2],
			["double_strike_0", 0.1], ["double_strike_2", 0.2],
		]],
		["double_strike_0", 0.36],
		["flash_red", 0.12], ["idle_0", 0.6],
	],
	"trample": [
		["idle_0", 0.6], ["flash_green", 0.12],
		[3, [["trample_0", 0.5], ["trample_1", 0.3], ["trample_2", 0.5], ["trample_3", 0.3]]],
		["trample_0", 0.46], ["trample_1", 0.3],
		["flash_green", 0.12], ["idle_0", 0.6],
	],
	"indestructible": [
		["idle_0", 0.6], ["flash_gold", 0.12],
		[2, [
			["indestructible_2", 0.8], ["indestructible_0", 0.4],
			["indestructible_2", 0.4], ["indestructible_1", 0.4],
		]],
		["indestructible_2", 0.8], ["indestructible_0", 0.4], ["indestructible_2", 0.36],
		["flash_gold", 0.12], ["idle_0", 0.6],
	],
	"protection": [
		["idle_0", 0.6], ["flash_blue", 0.12],
		[5, [["protection_0", 0.5], ["protection_1", 0.5]]], ["protection_0", 0.56],
		["flash_blue", 0.12], ["idle_0", 0.6],
	],
	"menace": [
		["idle_0", 0.6], ["flash_violet", 0.12],
		[2, [
			["menace_0", 0.8], ["menace_1", 0.2], ["menace_0", 0.2], ["menace_1", 0.2],
			["menace_0", 0.2], ["menace_1", 0.6],
		]],
		["menace_0", 1.16],
		["flash_violet", 0.12], ["idle_0", 0.6],
	],
}


## The timeline of [param animation], a Transition or an Effect Animation.
static func timeline_of(animation: String) -> Array:
	if TRANSITIONS.has(animation):
		return TRANSITIONS[animation]
	return EFFECTS[animation]


## [param timeline] with every repeated step written out, each as [frame, seconds].
static func steps_of(timeline: Array) -> Array[Array]:
	var steps: Array[Array] = []
	for step: Array in timeline:
		if step[0] is int:
			for _time: int in step[0] as int:
				steps.append_array(steps_of(step[1] as Array))
		else:
			steps.append(step)
	return steps


## The frame [param animation] shows [param seconds] in, or the neutral one once it is over.
static func frame_at(animation: String, seconds: float) -> String:
	var end: float = 0.0
	for step: Array in steps_of(timeline_of(animation)):
		end += step[1] as float
		if seconds < end:
			return step[0] as String
	return NEUTRAL


## How long [param animation] lasts, in seconds: always [constant SECONDS].
static func length_of(animation: String) -> float:
	var total: float = 0.0
	for step: Array in steps_of(timeline_of(animation)):
		total += step[1] as float
	return total


## The flash frame [param effect] flashes first, on the way in.
static func flash_of(effect: String) -> String:
	for step: Array in steps_of(EFFECTS[effect]):
		if FLASH_COLORS.has(step[0]):
			return step[0] as String
	return ""


## How far into [param effect] its first flash frame shows, in seconds. Summed as
## [method frame_at] sums, so that the flash shows from exactly this moment.
static func seconds_to_flash(effect: String) -> float:
	var total: float = 0.0
	for step: Array in steps_of(EFFECTS[effect]):
		if FLASH_COLORS.has(step[0]):
			return total
		total += step[1] as float
	return total


## The color [param effect] flashes.
static func color_of(effect: String) -> Color:
	return FLASH_COLORS[flash_of(effect)]


## Every frame any animation shows, each once, in the order they first appear.
static func frames() -> Array[String]:
	var found: Array[String] = [NEUTRAL]
	for animation: String in TRANSITIONS.keys() + EFFECTS.keys():
		for step: Array in steps_of(timeline_of(animation)):
			if not found.has(step[0]):
				found.append(step[0] as String)
	return found
