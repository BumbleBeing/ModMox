extends RefCounted
## THROWAWAY (13h prototype): what the Inspector says that no Card Face does. The State
## List's entries, the Reminder for each keyword, and a stand-in table of Rarities, since
## no card has a Rarity yet.

enum Rarity { NONE, COMMON, UNCOMMON, RARE, MYTHIC, POWER_NINE }

const RARITY_COLORS: Dictionary[Rarity, Color] = {
	Rarity.COMMON: Color("#8a8f98"),
	Rarity.UNCOMMON: Color("#d5dbe3"),
	Rarity.RARE: Color("#f2c744"),
	Rarity.MYTHIC: Color("#e89a2b"),
	Rarity.POWER_NINE: Color("#9be88a"),
}
const RARITY_NAMES: Dictionary[Rarity, String] = {
	Rarity.COMMON: "Common", Rarity.UNCOMMON: "Uncommon", Rarity.RARE: "Rare",
	Rarity.MYTHIC: "Mythic", Rarity.POWER_NINE: "Power-9",
}
## By the file name of the Card Definition. From each card's first printing, except Serra
## Angel and Shivan Dragon, made Mythic by hand so that every color can be seen. A card
## not listed is Common.
const RARITIES: Dictionary[String, Rarity] = {
	"ancestral_recall": Rarity.POWER_NINE,
	"serra_angel": Rarity.MYTHIC, "shivan_dragon": Rarity.MYTHIC,
	"ankh_of_mishra": Rarity.RARE, "elvish_archers": Rarity.RARE, "howling_mine": Rarity.RARE,
	"ivory_tower": Rarity.RARE, "savannah_lions": Rarity.RARE, "stifle": Rarity.RARE,
	"black_knight": Rarity.UNCOMMON, "counterspell": Rarity.UNCOMMON,
	"goblin_balloon_brigade": Rarity.UNCOMMON, "keldon_warlord": Rarity.UNCOMMON,
	"uthden_troll": Rarity.UNCOMMON, "wall_of_stone": Rarity.UNCOMMON,
	"water_elemental": Rarity.UNCOMMON, "white_knight": Rarity.UNCOMMON,
}
## By the file name of the Keyword Icon: the keyword's name and what it means.
const REMINDERS: Dictionary[String, Array] = {
	"flying": ["Flying", "It can be blocked only by creatures with flying or reach."],
	"reach": ["Reach", "It can block creatures with flying."],
	"vigilance": ["Vigilance", "Attacking doesn't cause it to tap."],
	"haste": ["Haste", "It can attack and tap for an ability the turn it comes under your control."],
	"deathtouch": ["Deathtouch", "Any amount of damage it deals to a creature is enough to destroy that creature."],
	"defender": ["Defender", "It can't attack."],
	"first_strike": ["First strike", "It deals combat damage before creatures without first strike."],
	"double_strike": ["Double strike", "It deals both first-strike and regular combat damage."],
	"trample": ["Trample", "It can deal excess combat damage to the player it is attacking."],
	"indestructible": ["Indestructible", "Damage and effects that say \"destroy\" don't destroy it."],
	"protection": ["Protection", "It can't be blocked, targeted, dealt damage or enchanted by anything of that kind."],
}


## The Rarity of the card whose art is [param art_key], or NONE for an Emblem or a token.
static func rarity_of(art_key: String) -> Rarity:
	if art_key == "":
		return Rarity.NONE
	return RARITIES.get(art_key, Rarity.COMMON) as Rarity


## One Reminder for each keyword [param look] has: [icon, name, what it means].
static func reminders(look: CardLook) -> Array[Array]:
	var found: Array[Array] = []
	for chip: KeywordChip in KeywordChips.chips_for(look.abilities):
		if not REMINDERS.has(chip.icon):
			continue
		var keyword: String = REMINDERS[chip.icon][0]
		if chip.has_protection_color:
			keyword += " from " + (MmCardTypes.CardColor.keys()[chip.protection_color] as String).to_lower()
		found.append([KeywordChips.icon_texture(chip), keyword, REMINDERS[chip.icon][1]])
	return found


## The State List of the permanent [param seen]: [title, sentence] for each thing true of
## it right now that its Card Face does not say.
static func state_entries(seen: MmObjectView, view: MmPlayerView, names: PlayerNames) -> Array[Array]:
	var entries: Array[Array] = []
	if seen.is_creature and seen.is_summoning_sick:
		entries.append(["Summoning sick", "It can't attack or tap for an ability until its controller's next turn."])
	if seen.damage_marked > 0:
		entries.append(["Damage", "%d damage is marked on it until end of turn." % seen.damage_marked])
	for active: ActiveContinuousEffect in seen.continuous_effects:
		var until: String = " until end of turn" if active.duration == CreateContinuousEffect.Duration.UNTIL_END_OF_TURN else ""
		entries.append([_source_name(active.source_object_id, active.source_card_id, view), _effect_text(active) + until + "."])
	for active: ActiveReplacementEffect in seen.replacement_effects:
		entries.append([ReplacementText.source_name(active, view), ReplacementText.effect_text(active, view, names)])
	return entries


static func _effect_text(active: ActiveContinuousEffect) -> String:
	var amounts: Array[int] = active.amounts
	if active.effect is ModifyPowerToughnessContinuousEffect and amounts.size() == 2:
		return "It gets %+d/%+d" % amounts
	if active.effect is SetPowerToughnessContinuousEffect and amounts.size() == 2:
		return "Its power and toughness are %d/%d" % amounts
	var gained: GainAbilitiesContinuousEffect = active.effect as GainAbilitiesContinuousEffect
	if gained != null:
		var no_types: Array[MmCardTypes.CardType] = []
		var no_supertypes: Array[MmCardTypes.Supertype] = []
		return "It has: " + AbilityText.of_card(gained.abilities, no_types, no_supertypes, "it").replace("\n", " ").trim_suffix(".")
	if active.effect is LoseAllAbilitiesContinuousEffect:
		return "It loses all abilities"
	return "An effect applies to it"


## The name of the card an effect came from: the object itself, or the same card after it
## moved, as a resolved spell is in a graveyard.
static func _source_name(object_id: int, card_id: int, view: MmPlayerView) -> String:
	var everything: Array[MmObjectView] = []
	everything.append_array(view.battlefield)
	everything.append_array(view.stack)
	everything.append_array(view.command)
	for player_id: int in view.graveyards:
		everything.append_array(view.graveyards[player_id])
	for player_id: int in view.exiles:
		everything.append_array(view.exiles[player_id])
	for seen: MmObjectView in everything:
		if seen.id == object_id:
			return seen.name
	for seen: MmObjectView in everything:
		if card_id != MmGameObject.NO_CARD and seen.card_id == card_id:
			return seen.name
	return "An effect"
