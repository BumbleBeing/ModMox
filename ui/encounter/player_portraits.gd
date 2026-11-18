class_name PlayerPortraits
extends RefCounted
## Which Portrait and Pain Portrait (game glossary) each player's panel shows when it was
## given none of its own. Until Heroes have their own, the Hero is Urza, Academy Headmaster;
## a Villain met outside a run is Charmed Stray, for testing (A474).

const PATHS: Dictionary[int, String] = {
	MmEncounterSetup.HERO_PLAYER_ID: "res://ui/sprites/portraits/urza_academy_headmaster.png",
	MmEncounterSetup.VILLAIN_PLAYER_ID: "res://ui/sprites/portraits/charmed_stray.png",
}
const PAIN_PATHS: Dictionary[int, String] = {
	MmEncounterSetup.HERO_PLAYER_ID: "res://ui/sprites/portraits/urza_academy_headmaster_pain.png",
	MmEncounterSetup.VILLAIN_PLAYER_ID: "res://ui/sprites/portraits/charmed_stray_pain.png",
}


## The Portrait of [param player_id], or null for a player who has none.
static func texture_of(player_id: int) -> Texture2D:
	if not PATHS.has(player_id):
		return null
	return load(PATHS[player_id]) as Texture2D


## The Pain Portrait of [param player_id], or null for a player who has none.
static func pain_of(player_id: int) -> Texture2D:
	if not PAIN_PATHS.has(player_id):
		return null
	return load(PAIN_PATHS[player_id]) as Texture2D
