class_name Screens
extends RefCounted
## Which scene each of a run's Screens is. RunFlow says which Screen comes next; only the
## GUI knows the scene tree, so the run never names a scene file.

const MENU: String = "res://ui/menu/main_menu.tscn"
const DECKBOX: String = "res://ui/deckbox/deckbox_screen.tscn"
const DECKBUILDER: String = "res://ui/deckbuilder/deckbuilder_screen.tscn"
const STAGE_INTRO: String = "res://ui/stage_map/stage_intro.tscn"
const STAGE_MAP: String = "res://ui/stage_map/stage_map_screen.tscn"
const SPOILS: String = "res://ui/spoils/spoils_screen.tscn"
const RUN_WON: String = "res://ui/run_end/run_won.tscn"
const RUN_LOST: String = "res://ui/run_end/run_lost.tscn"
const CREDITS: String = "res://ui/credits/credits_screen.tscn"
const STORE: String = "res://ui/store/store_screen.tscn"

const _SCENES: Dictionary[RunFlow.Screen, String] = {
	RunFlow.Screen.MENU: MENU,
	RunFlow.Screen.DECKBOX: DECKBOX,
	RunFlow.Screen.DECKBUILDER: DECKBUILDER,
	RunFlow.Screen.STAGE_INTRO: STAGE_INTRO,
	RunFlow.Screen.STAGE_MAP: STAGE_MAP,
	RunFlow.Screen.SPOILS: SPOILS,
	RunFlow.Screen.RUN_WON: RUN_WON,
	RunFlow.Screen.RUN_LOST: RUN_LOST,
	RunFlow.Screen.CREDITS: CREDITS,
	RunFlow.Screen.STORE: STORE,
}


## The scene [param screen] is, or "" for NONE, which opens nothing.
static func scene(screen: RunFlow.Screen) -> String:
	return _SCENES.get(screen, "")
