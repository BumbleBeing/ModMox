class_name PlayerPortraits
extends RefCounted
## Which Portrait (game glossary) each player's panel shows. Until Heroes and Villains
## choose their own, the Hero is the white wizard and the Villain the purple demon (A474).

const PATHS: Dictionary[int, String] = {
	MmEncounterSetup.HERO_PLAYER_ID: "res://ui/sprites/portraits/white_wizard.png",
	MmEncounterSetup.VILLAIN_PLAYER_ID: "res://ui/sprites/portraits/purple_demon.png",
}


## The Portrait of [param player_id], or null for a player who has none.
static func texture_of(player_id: int) -> Texture2D:
	if not PATHS.has(player_id):
		return null
	return load(PATHS[player_id]) as Texture2D
