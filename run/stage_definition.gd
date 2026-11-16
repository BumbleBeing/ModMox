class_name StageDefinition
extends Resource
## A Stage (game glossary) as Content: one section of a run, of one color at one Tier,
## listing the Villains it gives at each Rank (ADR 0024). Saved in content/stages/.
##
## Saved files leave out values equal to these defaults, so never change a default once
## Stages exist; add a new property instead.

const STAGES: String = "res://content/stages/"
const VILLAINS: String = "res://content/villains/"
## The Backdrop of each color's encounters (ADR 0035).
const BACKDROPS: Dictionary[MmCardTypes.CardColor, String] = {
	MmCardTypes.CardColor.WHITE: "white", MmCardTypes.CardColor.BLUE: "blue",
	MmCardTypes.CardColor.BLACK: "black", MmCardTypes.CardColor.RED: "red",
	MmCardTypes.CardColor.GREEN: "green",
}

## The name shown when the Hero enters it.
@export var name: String = ""
@export var color: MmCardTypes.CardColor = MmCardTypes.CardColor.WHITE
## From 1 to 5.
@export var tier: int = 1
## The Villains it gives at each Rank. A Villain is in at most one of the three lists.
@export var lesser_villains: Array[Villain] = []
@export var elite_villains: Array[Villain] = []
## A list although a Stage has one Boss today, because Stages will have several later.
@export var bosses: Array[Villain] = []
## The one picture behind its Stage Map, 320 x 560, in ui/sprites/backgrounds/stage_maps/;
## null for the plain slate (ADR 0038).
@export var map_backdrop: Texture2D
## The color the Stage Intro's ground is shaded in; clear for the plain slate (ADR 0038).
@export var intro_color: Color = Color(0, 0, 0, 0)
## The Scenery Kinds placed on its Stage Map (ADR 0038).
@export var scenery: Array[SceneryKind] = []
## Where its Scenery may stand: a picture the Map Backdrop's size, opaque there and clear
## elsewhere, such as over a castle or the sky; null for anywhere on the Map Backdrop.
## Imported as an Image, since its pixels are read and it is never drawn.
@export var scenery_ground: Image


## Every Stage in content/stages/, in file order.
static func all() -> Array[StageDefinition]:
	var found: Array[StageDefinition] = []
	for file: String in _files_in(STAGES):
		found.append(load(STAGES + file) as StageDefinition)
	return found


## Every Villain in content/villains/, in file order.
static func all_villains() -> Array[Villain]:
	var found: Array[Villain] = []
	for file: String in _files_in(VILLAINS):
		found.append(load(VILLAINS + file) as Villain)
	return found


## The Villains the Stage gives at the Rank of a Node of [param kind]: its Lesser
## Villains, Elite Villains or Bosses; none for any other kind.
func villains_for(kind: StageMap.Kind) -> Array[Villain]:
	match kind:
		StageMap.Kind.LESSER:
			return lesser_villains
		StageMap.Kind.ELITE:
			return elite_villains
		StageMap.Kind.BOSS:
			return bosses
	return []


## Whether the Stage Intro is drawn in a color of the Stage's own.
func has_intro_color() -> bool:
	return intro_color.a > 0.0


## The name of the Backdrop of its encounters.
func backdrop() -> String:
	return BACKDROPS[color]


## Why this Stage cannot be played, or "" if it can (ADR 0024).
func validate() -> String:
	if tier < 1 or tier > Villain.TIERS:
		return "A Stage's Tier is from 1 to %d." % Villain.TIERS
	for list: Array[Villain] in [lesser_villains, elite_villains, bosses]:
		if list.is_empty():
			return "A Stage lists at least one Villain at each Rank."
	var seen: Dictionary[Villain, bool] = {}
	for list: Array[Villain] in [lesser_villains, elite_villains, bosses]:
		for villain: Villain in list:
			if seen.has(villain):
				return "%s is in two lists of the Stage." % villain.name
			seen[villain] = true
			var reason: String = villain.validate()
			if reason != "":
				return reason
	return ""


## The resource files in [param folder], sorted. An exported game lists a resource as
## "name.tres.remap".
static func _files_in(folder: String) -> Array[String]:
	var found: Array[String] = []
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	files.sort()
	for file: String in files:
		var named: String = file.trim_suffix(".remap")
		if named.ends_with(".tres"):
			found.append(named)
	return found
