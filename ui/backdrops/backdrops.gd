class_name Backdrops
extends RefCounted
## The Backdrops (game glossary): the one picture behind an Encounter Screen. Each is known
## by name, and until Stages exist the Encounter Request names it (ADR 0035).
##
## A Backdrop is the picture named for it in FOLDER if there is one, SIZE pixels and drawn
## six times over with hard edges, and otherwise a placeholder drawn by a shader on the same
## grid. So a picture put in the folder replaces its placeholder with no change here.

const PLAIN: String = "plain"
## Every Backdrop, in the order they are offered: no picture at all, then the five colors.
const NAMES: Array[String] = ["plain", "white", "blue", "black", "red", "green"]
## A Backdrop's picture, which the 1920 x 1080 screen draws six times over.
const SIZE: Vector2i = Vector2i(320, 180)
## What the screen shows with no Backdrop, and what a Backdrop is dimmed toward.
const SLATE: Color = Color("#1a1d22")
## How far every Backdrop is dimmed toward SLATE, so that faces, Glows and labels read over
## any picture, and a picture is painted at its own brightness (A506).
const DIM: float = 0.55
const FOLDER: String = "res://ui/sprites/backgrounds/Encounters/"
const SHADER: String = "res://ui/backdrops/backdrop.gdshader"


static func has(backdrop: String) -> bool:
	return NAMES.has(backdrop)


## Where the picture of [param backdrop] is, if it has one.
static func picture_path(backdrop: String, folder: String = FOLDER) -> String:
	return folder + backdrop + ".png"


## What draws [param backdrop], to be stretched over the whole screen: its picture from
## [param folder], or its placeholder. Null for the plain one and for a name that is none.
static func make(backdrop: String, folder: String = FOLDER) -> Control:
	if backdrop == PLAIN or not has(backdrop):
		return null
	var made: Control
	if ResourceLoader.exists(picture_path(backdrop, folder)):
		var picture: TextureRect = TextureRect.new()
		picture.texture = load(picture_path(backdrop, folder)) as Texture2D
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		made = picture
	else:
		var placeholder: ColorRect = ColorRect.new()
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = load(SHADER) as Shader
		material.set_shader_parameter("kind", NAMES.find(backdrop) - 1)
		placeholder.material = material
		made = placeholder
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## The layer that dims a Backdrop, to lie just over it.
static func dimmer() -> ColorRect:
	var layer: ColorRect = ColorRect.new()
	layer.color = Color(SLATE, DIM)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer
