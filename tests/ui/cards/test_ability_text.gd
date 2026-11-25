extends GutTest
## Rules text is generated from abilities (A333), in current Oracle wording (A343): a
## permanent calls itself "this creature" or "this artifact", and a spell goes by its name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const CONTENT_ROOT: String = "res://content/cards/alpha"
## Every set's folder is under here.
const SETS_ROOT: String = "res://content/cards"
const CardType := MmCardTypes.CardType
const Whose := MmTrigger.Whose
## The Treasure Token Definition (CR 111.10a), a predefined token.
const TREASURE: String = "res://content/tokens/treasure.tres"
const CLUE: String = "res://content/tokens/clue.tres"

## What each authored card with abilities prints.
const PRINTED: Dictionary[String, String] = {
	"adaptive_gemguard": "Tap two untapped artifacts and/or creatures you control: Put a +1/+1 counter on this creature. Activate only as a sorcery.",
	"adventuring_gear": "Whenever a land you control enters, equipped creature gets +2/+2 until end of turn.\nEquip {1}",
	"aether_channeler": "When this creature enters, choose one —\n"
		+ "• Create a 1/1 white Bird creature token with flying.\n"
		+ "• Return another target nonland permanent to its owner's hand.\n"
		+ "• Draw a card.",
	"aeronauts_wings": "Equipped creature gets +1/+0. Equipped creature has flying.\nEquip {2}",
	"akrasan_squire": "Exalted",
	"ancestral_recall": "Target player draws three cards.",
	"angelic_quartermaster": "Flying\nWhen this creature enters, put a +1/+1 counter on each of up to two other target creatures.",
	"animating_faerie": "Flying",
	"ankh_of_mishra": "Whenever a land enters, this artifact deals 2 damage to that land's controller.",
	"anointed_chorister": "Lifelink\n{4}{W}: This creature gets +3/+3 until end of turn.",
	"arahbo_the_first_fang": "Each other Cat creature you control gets +1/+1.\nWhenever a nontoken Cat creature you control enters, create a 1/1 white Cat creature token.",
	"arcane_sanctum": "This land enters tapped.\n{T}: Add {W}, {U}, or {B}.",
	"ardenvale_tactician": "Flying",
	"armguard_familiar": "Ward {2}\nEquipped creature gets +2/+1. Equipped creature has ward {2}.\nReconfigure {4}",
	"artificers_assistant": "Flying\nWhenever you cast a historic spell, scry 1.",
	"artillery_blast": "Artillery Blast deals damage to target tapped creature equal to 1 plus the number of basic land types among lands you control.",
	"ash_barrens": "{T}: Add {C}.\nBasic landcycling {1}",
	"assemble_the_players": "You may look at the top card of your library any time.\nOnce each turn, you may cast a creature spell with power 2 or less from the top of your library.",
	"attended_knight": "First strike\nWhen this creature enters, create a 1/1 white Soldier creature token.",
	"auriok_glaivemaster": "As long as this creature is equipped, it gets +1/+1 and has first strike.",
	"bark_of_doran": "Equipped creature gets +0/+1.\n"
		+ "As long as equipped creature's toughness is greater than its power, it assigns combat damage equal to its toughness rather than its power.\n"
		+ "Equip {1}",
	"battlegrowth": "Put a +1/+1 counter on target creature.",
	"benalish_marshal": "Each other creature you control gets +1/+1.",
	"bishop_of_rebirth": "Vigilance\nWhenever this creature attacks, you may return target creature card with mana value 3 or less from your graveyard to the battlefield.",
	"black_knight": "First strike\nProtection from white",
	"brimaz_king_of_oreskos": "Vigilance\n"
		+ "Whenever this creature attacks, create a 1/1 white Cat Soldier creature token with vigilance that's attacking.\n"
		+ "Whenever this creature blocks a creature, create a 1/1 white Cat Soldier creature token with vigilance that's blocking that creature.",
	"brineborn_cutthroat": "Flash\nWhenever you cast a spell during an opponent's turn, put a +1/+1 counter on this creature.",
	"bushwhack":"Choose one —\n"
		+ "• Search your library for a basic land card, reveal it, put it into your hand, then shuffle.\n"
		+ "• Target creature you control fights target creature you don't control.",
	"bygone_bishop": "Flying\nWhenever you cast a creature spell with mana value 3 or less, create a Clue token.",
	"captivating_unicorn": "Whenever an enchantment you control enters, tap target creature an opponent controls.",
	"celebrity_fencer": "Whenever another creature you control enters, put a +1/+1 counter on this creature.",
	"celestial_ancient": "Flying\nWhenever you cast an enchantment spell, put a +1/+1 counter on each creature you control.",
	"celestial_unicorn": "Whenever you gain life, put a +1/+1 counter on this creature.",
	"charmed_stray": "Lifelink\nWhen this creature enters, put a +1/+1 counter on each other creature you control originally named Charmed Stray.",
	"clarion_spirit": "Whenever you cast your second spell each turn, create a 1/1 white Spirit creature token with flying.",
	"claws_out": "Affinity for Cats\nEach creature you control gets +2/+2 until end of turn.",
	"cloudfin_raptor": "Flying, evolve",
	"cogwork_wrestler": "Flash\nWhen this creature enters, target creature an opponent controls gets -2/-0 until end of turn.",
	"contaminated_aquifer": "This land enters tapped.\n{T}: Add {U}.\n{T}: Add {B}.",
	"coordinated_maneuver": "Choose one —\n"
		+ "• Coordinated Maneuver deals damage to target creature equal to the number of creatures you control.\n"
		+ "• Destroy target enchantment.",
	"counterspell": "Counter target spell.",
	"crumbling_necropolis": "This land enters tapped.\n{T}: Add {U}, {B}, or {R}.",
	"cultbrand_cinder": "When this creature enters, put a -1/-1 counter on target creature.",
	"dark_ritual": "Add {B}{B}{B}.",
	"darksteel_axe": "Indestructible\nEquipped creature gets +2/+0.\nEquip {2}",
	"dauntless_veteran": "Whenever this creature attacks, each creature you control gets +1/+1 until end of turn.",
	"daybreak_charger": "When this creature enters, target creature gets +2/+0 until end of turn.",
	"daydream": "Exile target creature you control. Return the exiled card to the battlefield under its owner's control with a +1/+1 counter on it.\nFlashback {2}{W}",
	"dazzling_angel": "Flying\nWhenever another creature you control enters, you gain 1 life.",
	"deep_analysis": "Target player draws two cards.\nFlashback—{1}{U}, Pay 3 life",
	"defiant_strike": "Target creature gets +1/+0 until end of turn. Draw a card.",
	"destroy_evil": "Choose one —\n"
		+ "• Destroy target creature with toughness 4 or greater.\n"
		+ "• Destroy target enchantment.",
	"divining_duelist": "Flash\nWhen this creature enters, choose one —\n"
		+ "• Tap target creature.\n"
		+ "• Untap target creature.\n"
		+ "• Draw a card. Discard a card.",
	"dour_port_mage": "Whenever one or more other creatures you control leave the battlefield without dying, draw a card.\n{1}{U}, {T}: Return another target creature you control to its owner's hand.",
	"drudge_skeletons": "{B}: Regenerate this creature.",
	"dusk_legion_duelist": "Vigilance\nWhenever one or more +1/+1 counters are put on this creature, draw a card. This ability triggers only once each turn.",
	"eidolon_of_philosophy": "{6}{U}, Sacrifice this creature: Draw three cards.",
	"elementalist_adept": "Flash, prowess",
	"elvish_archers": "First strike",
	"emeria_angel": "Flying\nWhenever a land you control enters, you may create a 1/1 white Bird creature token with flying.",
	"etherium_spinner": "Whenever you cast a spell with mana value 4 or greater, create a 1/1 colorless Thopter artifact creature token with flying.",
	"exemplar_of_light": "Flying\nWhenever you gain life, put a +1/+1 counter on this creature.\n"
		+ "Whenever you put one or more +1/+1 counters on this creature, draw a card. This ability triggers only once each turn.",
	"explore": "You may play an additional land this turn. Draw a card.",
	"faerie_guidemother": "Flying",
	"faerie_vandal": "Flash, flying\nWhenever you draw your second card each turn, put a +1/+1 counter on this creature.",
	"fear_of_isolation": "As an additional cost to cast this spell, return a permanent you control to its owner's hand.\nFlying",
	"fearless_fledgling": "Whenever a land you control enters, put a +1/+1 counter on this creature. This creature gains flying until end of turn.",
	"felidar_retreat": "Whenever a land you control enters, choose one —\n"
		+ "• Create a 2/2 white Cat Beast creature token.\n"
		+ "• Put a +1/+1 counter on each creature you control. Each creature you control gains vigilance until end of turn.",
	"felidar_savior": "Lifelink\nWhen this creature enters, put a +1/+1 counter on each of up to two other target creatures you control.",
	"fog": "Prevent all combat damage that would be dealt this turn.",
	"frondland_felidar": "Vigilance\nEach creature you control with vigilance has \"{1}, {T}: Tap target creature.\"",
	"forest": "({T}: Add {G}.)",
	"frontier_bivouac": "This land enters tapped.\n{T}: Add {G}, {U}, or {R}.",
	"frozen_shade": "{B}: This creature gets +1/+1 until end of turn.",
	"gaeas_might": "Target creature gets +X/+X until end of turn, where X is the number of basic land types among lands you control.",
	"garrison_cat": "When this creature dies, create a 1/1 white Human Soldier creature token.",
	"gearsmith_prodigy": "This creature gets +1/+0 as long as you control an artifact.",
	"generous_pup": "Vigilance\nWhenever one or more +1/+1 counters are put on this creature, put a +1/+1 counter on each other creature you control. This ability triggers only once each turn.",
	"geothermal_bog": "This land enters tapped.\n{T}: Add {B}.\n{T}: Add {R}.",
	"giant_growth": "Target creature gets +3/+3 until end of turn.",
	"giant_spider": "Reach",
	"gideons_reproach": "Gideon's Reproach deals 4 damage to target attacking or blocking creature.",
	"gird_for_battle": "Put a +1/+1 counter on each of up to two target creatures.",
	"goblin_balloon_brigade": "{R}: This creature gains flying until end of turn.",
	"group_project": "Create a 2/2 white and red Spirit creature token.\nFlashback—Tap three untapped creatures you control",
	"guarded_heir": "Lifelink\nWhen this creature enters, create two 3/3 white Knight creature tokens.",
	"guiding_hydra": "This creature enters with X +1/+1 counters on it.\nAt the beginning of combat on your turn, you may remove a +1/+1 counter from this creature. If you do, put a +1/+1 counter on each other creature you control.",
	"haazda_vigilante": "When this creature enters, put a +1/+1 counter on target creature you control with power 2 or less.\nWhenever this creature attacks, put a +1/+1 counter on target creature you control with power 2 or less.",
	"haunted_mire": "This land enters tapped.\n{T}: Add {B}.\n{T}: Add {G}.",
	"helpful_hunter": "When this creature enters, draw a card.",
	"helping_hand": "Return target creature card with mana value 3 or less from your graveyard to the battlefield tapped.",
	"hero_of_the_pride": "Whenever you cast a spell that targets this creature, each creature you control gets +1/+0 until end of turn.",
	"highspire_bell_ringer": "Flying\nThe second spell you cast each turn costs {1} less to cast.",
	"honor": "Put a +1/+1 counter on target creature. Draw a card.",
	"howling_mine": "At the beginning of each player's draw step, if this artifact is untapped, that player draws a card.",
	"hypnotic_sprite": "Flying",
	"idyllic_beachfront": "This land enters tapped.\n{T}: Add {W}.\n{T}: Add {U}.",
	"ingenious_prodigy": "Skulk\nThis creature enters with X +1/+1 counters on it.\n"
		+ "At the beginning of your upkeep, if this creature has a +1/+1 counter on it, you may remove a +1/+1 counter from this creature. "
		+ "If you do, draw a card.",
	"instill_infection": "Put a -1/-1 counter on target creature. Draw a card.",
	"ironpaw_aspirant": "When this creature enters, put a +1/+1 counter on target creature.",
	"irregular_cohort": "Changeling\nWhen this creature enters, create a 2/2 colorless Shapeshifter creature token with changeling.",
	"island": "({T}: Add {U}.)",
	"ivory_tower": "At the beginning of your upkeep, you gain X life, where X is the number of cards in your hand minus 4.",
	"jewel_thief": "Vigilance, trample\nWhen this creature enters, create a Treasure token.",
	"jodahs_codex": "{5}, {T}: Draw a card. This ability costs {1} less to activate for each basic land type among lands you control.",
	"jungle_shrine": "This land enters tapped.\n{T}: Add {R}, {G}, or {W}.",
	"keldon_warlord": "This creature's power and toughness are each equal to the number of non-Wall creatures you control.",
	"kemba_kha_enduring": "Whenever a Cat creature you control enters, attach up to one target Equipment you control to that creature.\nEach equipped creature you control gets +1/+1.\n{3}{W}{W}: Create a 2/2 white Cat creature token.",
	"king_of_the_pride": "Each other Cat creature you control gets +2/+1.",
	"kishla_trawlers": "When this creature enters, you may exile a creature card from your graveyard. "
		+ "When you do, return target instant or sorcery card from your graveyard to your hand.",
	"kor_skyfisher": "Flying\nWhen this creature enters, return a permanent you control to its owner's hand.",
	"landscaper_colos": "When this creature enters, put target card from an opponent's graveyard on the bottom of its owner's library.\nBasic landcycling {1}{W}",
	"law_rune_enforcer": "{1}, {T}: Tap target creature with mana value 2 or greater.",
	"lay_down_arms": "Exile target creature with mana value less than or equal to the number of Plains you control. Its controller gains 3 life.",
	"leonin_lightbringer": "Ward {2}\nAs long as this creature is equipped, it gets +1/+1.",
	"leonin_shikari": "You may activate equip abilities any time you could cast an instant.",
	"leonin_skyhunter": "Flying",
	"leonin_snarecaster": "When this creature enters, you may tap target creature.",
	"leyline_binding": "Flash\nThis spell costs {1} less to cast for each basic land type among lands you control.\nWhen this enchantment enters, exile target nonland permanent an opponent controls until this enchantment leaves the battlefield.",
	"lightning_bolt": "Lightning Bolt deals 3 damage to any target.",
	"lion_sash": "{W}: Exile target card from a graveyard. If it is a permanent card, put a +1/+1 counter on this permanent.\nEquipped creature gets +X/+X, where X is the number of +1/+1 counters on this permanent.\nReconfigure {2}",
	"lightshield_parry": "Target creature gets +2/+2 until end of turn.\nCycling {2}",
	"llanowar_elves": "{T}: Add {G}.",
	"malamet_war_scribe": "When this creature enters, each creature you control gets +2/+1 until end of turn.",
	"maned_serval": "Vigilance",
	"martyr_of_dusk": "When this creature dies, create a 1/1 white Vampire creature token with lifelink.",
	"mechan_navigator": "Whenever this creature becomes tapped, draw a card. Discard a card.",
	"militia_bugler": "Vigilance\nWhen this creature enters, look at the top four cards of your library. You may reveal a creature "
		+ "card with power 2 or less from among them and put it into your hand. Put the rest on the bottom of your library in a "
		+ "random order.",
	"mind_stone": "{T}: Add {C}.\n{1}, {T}, Sacrifice this artifact: Draw a card.",
	"mist_cloaked_herald": "This creature can't be blocked.",
	"molten_tributary": "This land enters tapped.\n{T}: Add {U}.\n{T}: Add {R}.",
	"most_decrepit_old_bird": "Flying\nThis creature gets +1/+1 as long as there are seven or more cards in your graveyard.",
	"mountain": "({T}: Add {R}.)",
	"myr_scrapling": "Sacrifice this creature: Put a +1/+1 counter on target creature.",
	"myrsmith": "Whenever you cast an artifact spell, you may pay {1}. If you do, create a 1/1 colorless Myr artifact creature token.",
	"mystic_monastery": "This land enters tapped.\n{T}: Add {U}, {R}, or {W}.",
	"nephalia_smuggler": "{3}{U}, {T}: Exile another target creature you control. Return the exiled card to the battlefield under its owner's control.",
	"network_disruptor": "Flying\nWhen this creature enters, tap target permanent.",
	"nimbus_naiad": "Bestow {4}{U}\nFlying\nEnchanted creature gets +2/+2. Enchanted creature has flying.",
	"nishoba_brawler": "Trample\nThis creature's power is equal to the number of basic land types among lands you control.",
	"nomad_outpost": "This land enters tapped.\n{T}: Add {R}, {W}, or {B}.",
	"nyleas_presence": "Enchant land\nWhen this Aura enters, draw a card.\nEnchanted land is every basic land type in addition to its other types.",
	"oblivion_ring": "When this enchantment enters, exile another target nonland permanent.\n"
		+ "When this enchantment leaves the battlefield, return the exiled card to the battlefield under its owner's control.",
	"odrics_outrider": "Whenever a creature you control dies, put a +1/+1 counter on target creature you control.",
	"oltec_matterweaver": "Whenever you cast a creature spell, choose one —\n"
		+ "• Create a 1/1 colorless Gnome artifact creature token.\n"
		+ "• Create a token that's a copy of target artifact token you control.",
	"ominous_parcel": "{2}, {T}, Sacrifice this artifact: Search your library for a basic land card, reveal it, put it into your hand, then shuffle.\n"
		+ "{5}, {T}, Sacrifice this artifact: This artifact deals 4 damage to target creature.",
	"opulent_palace": "This land enters tapped.\n{T}: Add {B}, {G}, or {U}.",
	"oreskos_explorer": "When this creature enters, search your library for up to X Plains cards, reveal them, put them into your hand, "
		+ "then shuffle, where X is the number of players who control more lands than you.",
	"ornery_kudu": "When this creature enters, put a -1/-1 counter on target creature you control.",
	"ornithopter": "Flying",
	"outflank": "Outflank deals damage to target attacking or blocking creature equal to the number of creatures you control.",
	"path_of_bravery": "As long as your life total is greater than or equal to your starting life total, each creature you control gets +1/+1.\n"
		+ "Whenever one or more creatures you control attack, you gain X life, where X is the number of attacking creatures.",
	"plains": "({T}: Add {W}.)",
	"prophetic_prism": "When this artifact enters, draw a card.\n{1}, {T}: Add one mana of any color.",
	"radiant_grove": "This land enters tapped.\n{T}: Add {G}.\n{T}: Add {W}.",
	"raise_dead": "Return target creature card from your graveyard to your hand.",
	"pride_sovereign": "This creature gets +X/+X, where X is the number of other Cats you control.\n{W}, {T}, Exert this creature: Create two 1/1 white Cat creature tokens with lifelink.",
	"prideful_parent": "Vigilance\nWhen this creature enters, create a 1/1 white Cat creature token.",
	"prodigal_sorcerer": "{T}: This creature deals 1 damage to any target.",
	"prowling_felidar": "Vigilance\nWhenever a land you control enters, put a +1/+1 counter on this creature.",
	"rally_the_ranks": "As this enchantment enters, choose a creature type.\nEach creature you control of the chosen type gets +1/+1.",
	"razzle_dazzler": "Whenever you cast your second spell each turn, put a +1/+1 counter on this creature. This creature gains \"This creature can't be blocked.\" until end of turn.",
	"relief_captain": "When this creature enters, put a +1/+1 counter on each of up to three other target creatures.",
	"resistance_reunited": "Target creature gets +2/+2 until end of turn. "
		+ "Each equipped creature you control gains indestructible until end of turn.",
	"resolute_reinforcements": "Flash\nWhen this creature enters, create a 1/1 white Soldier creature token.",
	"riddlesmith": "Whenever you cast an artifact spell, you may draw a card. If you do, discard a card.",
	"roving_harper": "When this creature enters, draw a card.",
	"sacred_peaks": "This land enters tapped.\n{T}: Add {R}.\n{T}: Add {W}.",
	"sage_of_the_skies": "When you cast this spell, if you've cast another spell this turn, copy this spell.\nFlying, lifelink",
	"salt_road_packbeast": "Affinity for creatures\nWhen this creature enters, draw a card.",
	"samite_healer": "{T}: Prevent the next 1 damage that would be dealt to any target this turn.",
	"sandsteppe_citadel": "This land enters tapped.\n{T}: Add {W}, {B}, or {G}.",
	"sanguine_evangelist": "Battle cry\n"
		+ "When this creature enters, create a 1/1 black Bat creature token with flying.\n"
		+ "When this creature dies, create a 1/1 black Bat creature token with flying.",
	"savage_lands": "This land enters tapped.\n{T}: Add {B}, {R}, or {G}.",
	"scythe_leopard": "Whenever a land you control enters, this creature gets +1/+1 until end of turn.",
	"scythecat_cub": "Trample\nWhenever a land you control enters, put a +1/+1 counter on target creature you control. "
		+ "If this is the second time this ability has resolved this turn, double the number of +1/+1 counters on that creature instead.",
	"seam_rip": "When this enchantment enters, exile target nonland permanent an opponent controls with mana value 2 or less until this enchantment leaves the battlefield.",
	"seaside_citadel": "This land enters tapped.\n{T}: Add {G}, {W}, or {U}.",
	"serra_angel": "Flying, vigilance",
	"serra_redeemer": "Flying\nWhenever another creature with power 2 or less you control enters, put two +1/+1 counters on that creature.",
	"shatter": "Destroy target artifact.",
	"shivan_dragon": "Flying\n{R}: This creature gets +1/+0 until end of turn.",
	"short_sword": "Equipped creature gets +1/+1.\nEquip {1}",
	"skyhunter_prowler": "Flying, vigilance",
	"skyknight_squire": "Whenever another creature you control enters, put a +1/+1 counter on this creature.\n"
		+ "As long as this creature has three or more +1/+1 counters on it, it has flying and is a Knight in addition to its other types.",
	"slash_of_light": "Slash of Light deals damage to target creature equal to the number of creatures you control plus the number of Equipment you control.",
	"sparring_construct": "When this creature dies, put a +1/+1 counter on target creature you control.",
	"spirited_companion": "When this creature enters, draw a card.",
	"splitskin_doll": "When this creature enters, draw a card. Discard a card unless you control another creature with power 2 or less.",
	"steppe_lynx": "Whenever a land you control enters, this creature gets +2/+2 until end of turn.",
	"stifle": "Counter target activated or triggered ability.",
	"sunlit_marsh": "This land enters tapped.\n{T}: Add {W}.\n{T}: Add {B}.",
	"sunspear_shikari": "As long as this creature is equipped, it has first strike and lifelink.",
	"swamp": "({T}: Add {B}.)",
	"taj_nar_swordsmith": "When this creature enters, you may pay {X}. If you do, search your library for an Equipment card with mana value X or less, put it onto the battlefield, then shuffle.",
	"tangled_islet": "This land enters tapped.\n{T}: Add {G}.\n{T}: Add {U}.",
	"temple_garden": "As this land enters, you may pay 2 life. If you don't, it enters tapped.\n{T}: Add {G}.\n{T}: Add {W}.",
	"territorial_scythecat":"Trample\nWhenever a land you control enters, put a +1/+1 counter on this creature.",
	"tethmos_high_priest": "Whenever you cast a spell that targets this creature, return target creature card with mana value 2 or less from your graveyard to the battlefield.",
	"terror": "Destroy target nonartifact, nonblack creature. It can't be regenerated.",
	"thopter_mechanic": "Whenever you draw your second card each turn, put a +1/+1 counter on this creature.\nWhen this creature dies, create a 1/1 colorless Thopter artifact creature token with flying.",
	"thraben_inspector": "When this creature enters, create a Clue token.",
	"tocasias_welcome": "Whenever one or more creatures you control with mana value 3 or less enter, draw a card. "
		+ "This ability triggers only once each turn.",
	"topiary_panther": "Trample\nBasic landcycling {1}{G}",
	"traveling_minister": "{T}: Target creature gets +1/+0 until end of turn. You gain 1 life. Activate only as a sorcery.",
	"tromp_the_domains": "Each creature you control gains trample until end of turn. Each creature you control gets +X/+X until end of turn, where X is the number of basic land types among lands you control.",
	"tunnel_surveyor": "When this creature enters, create a 1/1 white Glimmer enchantment creature token.",
	"undergrowth_leopard": "Vigilance\n{1}, Sacrifice this creature: Destroy target artifact or enchantment.",
	"unflinching_hortimancer": "Ward {1}\nWhenever you gain life, put a +1/+1 counter on this creature.",
	"universal_automaton": "Changeling",
	"uthden_troll": "{R}: Regenerate this creature.",
	"vanguard_of_brimaz": "Vigilance\nWhenever you cast a spell that targets this creature, create a 1/1 white Cat Soldier creature token with vigilance.",
	"viridian_claw": "Equipped creature gets +1/+0. Equipped creature has first strike.\nEquip {1}",
	"wall_of_stone": "Defender",
	"warkite_marauder": "Flying\nWhenever this creature attacks, target creature an opponent controls loses all abilities until end of turn. It has base power and toughness 0/1 until end of turn.",
	"wary_thespian": "When this creature enters, surveil 1.\nWhen this creature dies, surveil 1.",
	"wavebreak_hippocamp": "Whenever you cast your first spell each turn during an opponent's turn, draw a card.",
	"waterwind_scout": "Flying\nWhen this creature enters, create a Map token.",
	"wayspeaker_bodyguard": "When this creature enters, return target nonland permanent card with mana value 2 or less from your graveyard to your hand.\n"
		+ "Whenever you cast your second spell each turn, tap target creature an opponent controls.",
	"white_knight": "First strike\nProtection from black",
	"whitemane_lion": "Flash\nWhen this creature enters, return a creature you control to its owner's hand.",
	"wingblade_disciple": "Flying\nWhenever you cast your second spell each turn, create a 1/1 white Bird creature token with flying.",
	"wooded_ridgeline": "This land enters tapped.\n{T}: Add {R}.\n{T}: Add {G}.",
	"zar_ojanen_scion_of_efrava": "Whenever this creature becomes tapped, put a +1/+1 counter on each creature you control with toughness less than the number of basic land types among lands you control.",
}

## Each authored Adventurer card's Adventure (engine ADR 0078), as its half reads: the same
## review as PRINTED's.
const PRINTED_ADVENTURES: Dictionary[String, String] = {
	"animating_faerie": "Target noncreature artifact you control becomes a 0/0 artifact creature. Put four +1/+1 counters on it.",
	"ardenvale_tactician": "Tap up to two target creatures.",
	"faerie_guidemother": "Target creature gets +2/+1 until end of turn. It gains flying until end of turn.",
	"hypnotic_sprite": "Counter target spell with mana value 3 or less.",
	"most_decrepit_old_bird": "Mill four cards. Put an instant or sorcery card from among them into your hand.",
}

## Each authored instant and sorcery with a target, as it reads with every "target" changed
## to "each" by an OverloadModification (CR 702.96b): the same review as PRINTED's.
const OVERLOADED: Dictionary[String, String] = {
	"ancestral_recall": "Each player draws three cards.",
	"artillery_blast": "Artillery Blast deals damage to each tapped creature equal to 1 plus the number of basic land types among lands you control.",
	"battlegrowth": "Put a +1/+1 counter on each creature.",
	"bushwhack": "Choose one —\n• Search your library for a basic land card, reveal it, put it into your hand, then shuffle.\n• Each creature you control fights each creature you don't control.",
	"coordinated_maneuver": "Choose one —\n• Coordinated Maneuver deals damage to each creature equal to the number of creatures you control.\n• Destroy each enchantment.",
	"counterspell": "Counter each other spell.",
	"daydream": "Exile each creature you control. Return the exiled cards to the battlefield under their owners' control with a +1/+1 counter on each of them.\nFlashback {2}{W}",
	"deep_analysis": "Each player draws two cards.\nFlashback—{1}{U}, Pay 3 life",
	"defiant_strike": "Each creature gets +1/+0 until end of turn. Draw a card.",
	"destroy_evil": "Choose one —\n• Destroy each creature with toughness 4 or greater.\n• Destroy each enchantment.",
	"gaeas_might": "Each creature gets +X/+X until end of turn, where X is the number of basic land types among lands you control.",
	"giant_growth": "Each creature gets +3/+3 until end of turn.",
	"gideons_reproach": "Gideon's Reproach deals 4 damage to each attacking or blocking creature.",
	"gird_for_battle": "Put a +1/+1 counter on each creature.",
	"helping_hand": "Return each creature card with mana value 3 or less from your graveyard to the battlefield tapped.",
	"honor": "Put a +1/+1 counter on each creature. Draw a card.",
	"instill_infection": "Put a -1/-1 counter on each creature. Draw a card.",
	"lay_down_arms": "Exile each creature with mana value less than or equal to the number of Plains you control. For each of those creatures, its controller gains 3 life.",
	"lightning_bolt": "Lightning Bolt deals 3 damage to each creature and each player.",
	"lightshield_parry": "Each creature gets +2/+2 until end of turn.\nCycling {2}",
	"outflank": "Outflank deals damage to each attacking or blocking creature equal to the number of creatures you control.",
	"raise_dead": "Return each creature card from your graveyard to your hand.",
	"resistance_reunited": "Each creature gets +2/+2 until end of turn. Each equipped creature you control gains indestructible until end of turn.",
	"shatter": "Destroy each artifact.",
	"slash_of_light": "Slash of Light deals damage to each creature equal to the number of creatures you control plus the number of Equipment you control.",
	"stifle": "Counter each activated or triggered ability.",
	"terror": "Destroy each nonartifact, nonblack creature. They can't be regenerated.",
}


func test_each_authored_card_prints_its_oracle_wording() -> void:
	for file_name: String in PRINTED:
		assert_eq(_look(file_name).rules_text, PRINTED[file_name], file_name)
	for file_name: String in PRINTED_ADVENTURES:
		assert_eq(_look(file_name).adventure.rules_text, PRINTED_ADVENTURES[file_name], file_name)


func test_each_authored_spell_with_a_target_reads_each_once_overloaded() -> void:
	for file_name: String in OVERLOADED:
		var definition: MmCardDefinition = null
		for set_name: String in DirAccess.get_directories_at(SETS_ROOT):
			var path: String = "%s/%s/%s.tres" % [SETS_ROOT, set_name, file_name]
			if ResourceLoader.exists(path):
				definition = load(path) as MmCardDefinition
		assert_eq(_text(Scenario.overloaded(definition)), OVERLOADED[file_name], file_name)


func test_no_ability_of_any_authored_card_falls_back_to_a_class_name() -> void:
	var files: PackedStringArray = PackedStringArray()
	for set_name: String in DirAccess.get_directories_at(SETS_ROOT):
		files.append_array(DirAccess.get_files_at("%s/%s" % [SETS_ROOT, set_name]))
	var checked: int = 0
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		var look: CardLook = _look(file.get_basename())
		checked += 1
		assert_false(AbilityText.has_fallback(look.rules_text), "%s: %s" % [file, look.rules_text])
		if look.adventure != null:
			assert_false(AbilityText.has_fallback(look.adventure.rules_text), "%s: %s" % [file, look.adventure.rules_text])
		if look.abilities.is_empty():
			assert_eq(look.rules_text, "", file)
		else:
			assert_ne(look.rules_text, "", file)
	assert_gt(checked, 40)


func test_affinity_is_a_keyword_naming_what_it_counts() -> void:
	var cats: AffinityAbility = Scenario.affinity(Scenario.has_subtype("Cat"))
	var artifacts: AffinityAbility = Scenario.affinity(Scenario.of_type(CardType.ARTIFACT))
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws Out", Scenario.mana_cost(3))
	(claws.abilities[1] as SpellAbility).effects = [Scenario.until_end_of_turn(
		Scenario.modify_pt(2, 2, Scenario.each_creature(ControlledByFilter.new())))]

	assert_eq(AbilityText.of_ability(cats, "Claws Out"), "Affinity for Cats", "CR 702.41a, without its reminder text.")
	assert_eq(AbilityText.of_ability(artifacts, "Frogmite"), "Affinity for artifacts")
	assert_true(AbilityText.is_keyword(cats))
	assert_eq(CardLook.of_definition(claws).rules_text,
		"Affinity for Cats\nEach creature you control gets +2/+2 until end of turn.")


func test_choosing_a_creature_type_as_it_enters_and_the_chosen_type_are_worded() -> void:
	var rally: MmCardDefinition = Scenario.rally("Rally the Ranks")

	assert_eq(AbilityText.of_card(rally.abilities, rally.card_types, rally.supertypes, rally.name),
		"As this enchantment enters, choose a creature type.\nEach creature you control of the chosen type gets +1/+1.")


func test_instant_speed_equip_is_worded_as_leonin_shikari_words_it() -> void:
	assert_eq(AbilityText.of_ability(Scenario.instant_speed_equip(), "Leonin Shikari"),
		"You may activate equip abilities any time you could cast an instant.")


func test_reconfigure_prints_its_cost_once_and_its_card_calls_itself_this_permanent() -> void:
	# CR 702.151a: the keyword stands for two abilities, and prints as one.
	var sash: MmCardDefinition = Scenario.sash()
	sash.abilities[1].mana_cost = Scenario.mana_cost(2)
	sash.abilities[2].mana_cost = Scenario.mana_cost(2)

	assert_eq(AbilityText.of_card(sash.abilities, sash.card_types, sash.supertypes, sash.name),
		"Equipped creature gets +1/+1.\nReconfigure {2}")
	assert_eq(AbilityText.self_noun(sash.card_types, sash.name, sash.abilities), "this permanent",
		"A creature only while unattached, so neither \"this creature\" nor \"this artifact\".")
	assert_true(AbilityText.is_keyword(sash.abilities[1]))


func test_each_half_of_reconfigure_has_its_own_option_row() -> void:
	var halves: Array[MmAbility] = Scenario.reconfigure(Scenario.mana_cost(2))

	assert_eq(AbilityText.option_of(halves[0], "this permanent"), "Reconfigure {2}: attach")
	assert_eq(AbilityText.option_of(halves[1], "this permanent"), "Reconfigure {2}: unattach")
	assert_eq(AbilityText.option_of(Scenario.equip(Scenario.mana_cost(1)), "this artifact"), "Equip {1}",
		"Anything else reads as it is printed.")


func test_an_aura_prints_enchant_calls_itself_this_aura_and_names_what_it_enchants() -> void:
	# Nylea's Presence's first two lines, and "enchanted land" (CR 303.4, 702.5).
	var drawing: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.draw_cards(1, Scenario.you())])
	var swamp: ContinuousStaticAbility = Scenario.continuous_static([Scenario.add_subtypes(["Swamp"], Scenario.attached())])
	var aura: MmCardDefinition = Scenario.aura("Presence", null, [drawing, swamp])

	assert_eq(AbilityText.of_card(aura.abilities, aura.card_types, aura.supertypes, aura.name),
		"Enchant land\nWhen this Aura enters, draw a card.\nEnchanted land is a Swamp in addition to its other types.")
	assert_eq(AbilityText.self_noun(aura.card_types, aura.name, aura.abilities), "this Aura")
	assert_true(AbilityText.is_keyword(aura.abilities[0]))
	var on_creature: MmCardDefinition = Scenario.aura("Might", Scenario.of_type(CardType.CREATURE),
		[Scenario.continuous_static([Scenario.modify_pt(2, 2, Scenario.attached())])])
	assert_eq(AbilityText.of_card(on_creature.abilities, on_creature.card_types, on_creature.supertypes, on_creature.name),
		"Enchant creature\nEnchanted creature gets +2/+2.")
	assert_eq(AbilityText.of_ability(Scenario.sword("Sword").abilities[0], "this artifact"), "Equipped creature gets +1/+1.",
		"An Equipment's is still \"equipped creature\".")


func test_what_each_half_of_reconfigure_does() -> void:
	var halves: Array[MmAbility] = Scenario.reconfigure(Scenario.mana_cost(2))

	assert_eq(AbilityText.effect_of(halves[0], "this permanent"), "Attach this permanent to another target creature you control.")
	assert_eq(AbilityText.effect_of(halves[1], "this permanent"), "Unattach this permanent.")


func test_exiling_a_card_from_a_graveyard_and_an_if_are_worded_as_lion_sash_words_them() -> void:
	var scavenger: MmCardDefinition = Scenario.scavenger()
	var ability: ActivatedAbility = scavenger.abilities[0] as ActivatedAbility
	ability.mana_cost = Scenario.mana_cost(0, [MmMana.Type.WHITE])

	assert_eq(AbilityText.of_ability(ability, "this permanent"),
		"{W}: Exile target card from a graveyard. If it is a permanent card, put a +1/+1 counter on this permanent.")


func test_a_permanent_card_is_a_noun() -> void:
	var requirement: TargetRequirement = Scenario.target_graveyard_card(Scenario.permanent_card())
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [requirement]
	spell.effects = [Scenario.exile(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(spell, "Spell"), "Exile target permanent card from a graveyard.")


func test_counting_counters_is_worded_as_the_number_of_them() -> void:
	var sash: MmCardDefinition = Scenario.lion_sash()

	assert_eq(AbilityText.of_card(sash.abilities, sash.card_types, sash.supertypes, sash.name),
		"Equipped creature gets +X/+X, where X is the number of +1/+1 counters on this permanent.\nReconfigure {0}")


func test_something_it_has_no_words_for_is_marked_as_a_fallback() -> void:
	var odd: SpellAbility = SpellAbility.new()
	odd.effects = [MmEffect.new()]

	var text: String = AbilityText.of_ability(odd, "Oddity")

	assert_true(AbilityText.has_fallback(text))
	assert_false(AbilityText.has_fallback("Destroy target artifact."))


func test_a_view_of_a_card_in_an_encounter_prints_the_same_text_as_the_printed_card() -> void:
	var definition: MmCardDefinition = load(CONTENT_ROOT + "/prodigal_sorcerer.tres") as MmCardDefinition
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.copies(definition, 40), Scenario.copies(definition, 40)))
	Scenario.keep_all(engine)

	var held: MmObjectView = engine.view_for(engine.hero()).hand[0]

	assert_eq(CardLook.of_view(held).rules_text, PRINTED["prodigal_sorcerer"])


func test_a_permanent_names_itself_by_its_kind_and_anything_else_by_its_name() -> void:
	assert_eq(AbilityText.self_noun([CardType.CREATURE], "Prodigal Sorcerer"), "this creature")
	assert_eq(AbilityText.self_noun([CardType.ARTIFACT, CardType.CREATURE], "Golem"), "this creature")
	assert_eq(AbilityText.self_noun([CardType.ARTIFACT], "Ankh of Mishra"), "this artifact")
	assert_eq(AbilityText.self_noun([CardType.ENCHANTMENT], "Crusade"), "this enchantment")
	assert_eq(AbilityText.self_noun([CardType.LAND], "Life Land"), "this land")
	assert_eq(AbilityText.self_noun([CardType.INSTANT], "Lightning Bolt"), "Lightning Bolt")
	assert_eq(AbilityText.self_noun([], "Diviner's Boon"), "Diviner's Boon")


func test_what_an_ability_does_leaves_out_its_cost() -> void:
	var sorcerer: MmAbility = (load(CONTENT_ROOT + "/prodigal_sorcerer.tres") as MmCardDefinition).abilities[0]

	assert_eq(AbilityText.of_ability(sorcerer, "this creature"), "{T}: This creature deals 1 damage to any target.")
	assert_eq(AbilityText.effect_of(sorcerer, "this creature"), "This creature deals 1 damage to any target.")


func test_what_a_triggered_ability_does_leaves_out_its_trigger_and_condition() -> void:
	var mine: MmAbility = (load(CONTENT_ROOT + "/howling_mine.tres") as MmCardDefinition).abilities[0]

	assert_eq(AbilityText.effect_of(mine, "this artifact"), "That player draws a card.")


func test_what_a_spell_does_is_its_whole_text() -> void:
	var bolt: MmAbility = (load(CONTENT_ROOT + "/lightning_bolt.tres") as MmCardDefinition).abilities[0]

	assert_eq(AbilityText.effect_of(bolt, "Lightning Bolt"), "Lightning Bolt deals 3 damage to any target.")


func test_a_modal_spell_prints_choose_one_and_a_bullet_for_each_mode() -> void:
	var charm: MmCardDefinition = Scenario.free_charm("Charm")

	var text: String = AbilityText.of_card(charm.abilities, charm.card_types, charm.supertypes, "Charm")

	assert_eq(text, "Choose one —\n• Charm deals 2 damage to target creature.\n• Destroy target enchantment.")


func test_a_mode_is_worded_alone_and_is_what_a_modal_spell_does_once_it_is_chosen() -> void:
	var spell: SpellAbility = Scenario.free_charm("Charm").abilities[0] as SpellAbility

	assert_eq(AbilityText.mode_text(spell, 1, "Charm"), "Destroy target enchantment.")
	assert_eq(AbilityText.effect_of(spell, "Charm", 0), "Charm deals 2 damage to target creature.")
	assert_true(AbilityText.effect_of(spell, "Charm").begins_with("Choose one —"), "Before a mode is chosen, every mode.")


func test_a_modal_triggered_ability_prints_its_trigger_then_choose_one_and_a_bullet_for_each_mode() -> void:
	var retreat: MmCardDefinition = Scenario.free_retreat("Retreat", Scenario.enters(Scenario.of_type(CardType.LAND), Whose.YOU))

	var text: String = AbilityText.of_card(retreat.abilities, retreat.card_types, retreat.supertypes, "Retreat")

	assert_eq(text, "Whenever a land you control enters, choose one —\n"
		+ "• Create a 2/2 white Cat Beast creature token.\n"
		+ "• Put a +1/+1 counter on each creature you control. Each creature you control gains vigilance until end of turn.")


func test_a_modal_triggered_ability_on_the_stack_says_only_its_chosen_mode() -> void:
	var retreat: MmAbility = Scenario.free_retreat("Retreat", Scenario.at_step(MmTurn.Step.UPKEEP, Whose.YOU)).abilities[0]

	assert_eq(AbilityText.mode_text(retreat, 0, "this enchantment"), "Create a 2/2 white Cat Beast creature token.")
	assert_eq(AbilityText.effect_of(retreat, "this enchantment", 1),
		"Put a +1/+1 counter on each creature you control. Each creature you control gains vigilance until end of turn.")
	assert_eq(AbilityText.effect_of(retreat, "this enchantment"), "Choose one —\n"
		+ "• Create a 2/2 white Cat Beast creature token.\n"
		+ "• Put a +1/+1 counter on each creature you control. Each creature you control gains vigilance until end of turn.",
		"Before its mode is chosen, every mode and no trigger.")


func test_the_cat_beast_token_is_worded_as_oracle_words_it() -> void:
	var cat_beast: MmCardDefinition = load("res://content/tokens/cat_beast_2_2_white.tres") as MmCardDefinition
	var maker: MmCardDefinition = Scenario.free_tokens("Maker", cat_beast)

	var text: String = AbilityText.of_card(maker.abilities, maker.card_types, maker.supertypes, "Maker")

	assert_eq(text, "Create a 2/2 white Cat Beast creature token.")


func test_a_tokens_keyword_is_worded_after_with() -> void:
	var cat_soldier: MmCardDefinition = load("res://content/tokens/cat_soldier_1_1_white_vigilance.tres") as MmCardDefinition
	var maker: MmCardDefinition = Scenario.free_tokens("Maker", cat_soldier, 2)

	var text: String = AbilityText.of_card(maker.abilities, maker.card_types, maker.supertypes, "Maker")

	assert_eq(text, "Create two 1/1 white Cat Soldier creature tokens with vigilance.")


func test_a_token_put_onto_the_battlefield_attacking_is_worded_after_its_keywords() -> void:
	# Brimaz, King of Oreskos's first ability, with "this creature" for its name (ADR 0023).
	var cat_soldier: MmCardDefinition = load("res://content/tokens/cat_soldier_1_1_white_vigilance.tres") as MmCardDefinition
	var king: MmCardDefinition = Scenario.brimaz(cat_soldier)
	var litter: MmCardDefinition = Scenario.instant("Litter", Scenario.mana_cost(0), [], [Scenario.attacking_tokens(Scenario.cat(), 2)])

	var one: String = AbilityText.of_card(king.abilities, king.card_types, king.supertypes, "Brimaz")
	var two: String = AbilityText.of_card(litter.abilities, litter.card_types, litter.supertypes, "Litter")

	assert_eq(one, "Whenever this creature attacks, create a 1/1 white Cat Soldier creature token with vigilance that's attacking.")
	assert_eq(two, "Create two 1/1 white Cat creature tokens that are attacking.")


func test_a_token_put_onto_the_battlefield_blocking_is_worded_after_its_keywords() -> void:
	# Brimaz, King of Oreskos's second ability, with "this creature" for its name (ADR 0023).
	var cat_soldier: MmCardDefinition = load("res://content/tokens/cat_soldier_1_1_white_vigilance.tres") as MmCardDefinition
	var king: MmCardDefinition = Scenario.blocking_brimaz(cat_soldier)
	var litter: Array[MmEffect] = [Scenario.blocking_tokens(Scenario.cat(), 2)]
	var foliage: MmCardDefinition = Scenario.free_foliage()

	var one: String = AbilityText.of_card(king.abilities, king.card_types, king.supertypes, "Brimaz")
	var two: String = AbilityText.of_ability(Scenario.triggered(Scenario.blocks_a_creature(), litter), "this creature")
	var targeted: String = AbilityText.of_card(foliage.abilities, foliage.card_types, foliage.supertypes, "Foliage")

	assert_eq(one, "Whenever this creature blocks a creature, create a 1/1 white Cat Soldier creature token with vigilance that's blocking that creature.")
	assert_eq(two, "Whenever this creature blocks a creature, create two 1/1 white Cat creature tokens that are blocking that creature.")
	assert_eq(targeted, "Create a 1/1 white Cat creature token that's blocking target attacking creature.")


func test_a_tokens_keywords_are_listed_as_oracle_lists_them() -> void:
	var angel: MmCardDefinition = MmCardDefinition.new()
	angel.name = "Angel Token"
	angel.card_types = [MmCardTypes.CardType.CREATURE]
	angel.subtypes = ["Angel"]
	angel.color_indicator = [MmCardTypes.CardColor.WHITE]
	angel.power = 4
	angel.toughness = 4
	angel.abilities = [FlyingAbility.new(), VigilanceAbility.new()]
	var two: MmCardDefinition = Scenario.free_tokens("Two", angel)
	var three_angel: MmCardDefinition = angel.duplicate()
	three_angel.abilities = [FlyingAbility.new(), FirstStrikeAbility.new(), LifelinkAbility.new()]
	var three: MmCardDefinition = Scenario.free_tokens("Three", three_angel)

	assert_eq(AbilityText.of_card(two.abilities, two.card_types, two.supertypes, "Two"),
		"Create a 4/4 white Angel creature token with flying and vigilance.")
	assert_eq(AbilityText.of_card(three.abilities, three.card_types, three.supertypes, "Three"),
		"Create a 4/4 white Angel creature token with flying, first strike, and lifelink.")


func test_menace_is_a_keyword() -> void:
	var abilities: Array[MmAbility] = [MenaceAbility.new(), DeathtouchAbility.new()]

	assert_eq(AbilityText.of_card(abilities, [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType],
		[] as Array[MmCardTypes.Supertype], "Brute"),
		"Menace, deathtouch")
	assert_true(AbilityText.is_keyword(MenaceAbility.new()))


func test_skulk_is_a_keyword() -> void:
	var abilities: Array[MmAbility] = [FlyingAbility.new(), SkulkAbility.new()]

	assert_eq(AbilityText.of_card(abilities, [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType],
		[] as Array[MmCardTypes.Supertype], "Sneak"),
		"Flying, skulk")
	assert_true(AbilityText.is_keyword(SkulkAbility.new()))


func test_cant_be_blocked_is_worded_as_phantom_warrior_words_it_and_is_no_keyword() -> void:
	var abilities: Array[MmAbility] = [CantBeBlockedAbility.new()]

	assert_eq(AbilityText.of_card(abilities, [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType],
		[] as Array[MmCardTypes.Supertype], "Phantom"),
		"This creature can't be blocked.")
	assert_false(AbilityText.is_keyword(CantBeBlockedAbility.new()))


func test_cant_be_countered_calls_any_card_this_spell_as_carnage_tyrant_does() -> void:
	var abilities: Array[MmAbility] = [CantBeCounteredAbility.new()]

	assert_eq(AbilityText.of_card(abilities, [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType],
		[] as Array[MmCardTypes.Supertype], "Tyrant"),
		"This spell can't be countered.")
	assert_false(AbilityText.is_keyword(CantBeCounteredAbility.new()))


func test_damage_dealt_by_the_creature_that_entered_is_worded_it_deals_to_each_opponent() -> void:
	var ping: DealDamageEffect = Scenario.deal_damage(1, EachOpponentSelection.new())
	ping.source = TriggeringObjectSelection.new()
	var abilities: Array[MmAbility] = [Scenario.triggered(Scenario.enters(Scenario.creature_you_control()), [ping])]

	assert_eq(AbilityText.of_card(abilities, [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType],
		[] as Array[MmCardTypes.Supertype], "Eruptor"),
		"Whenever a creature you control enters, it deals 1 damage to each opponent.")


func test_a_treasure_prints_as_cr_111_10a_words_it() -> void:
	var treasure: MmCardDefinition = load(TREASURE) as MmCardDefinition

	var text: String = AbilityText.of_card(treasure.abilities, treasure.card_types, treasure.supertypes, treasure.name)

	assert_eq(text, "{T}, Sacrifice this token: Add one mana of any color.")
	assert_eq(CardLook.of_definition(treasure).rules_text, text, "As its face prints it.")


func test_a_predefined_token_is_created_by_its_name_alone() -> void:
	# CR 111.10: its characteristics are the rules', so its abilities are not spelled out.
	var treasure: MmCardDefinition = load(TREASURE) as MmCardDefinition
	var one: MmCardDefinition = Scenario.free_tokens("One", treasure)
	var two: MmCardDefinition = Scenario.free_tokens("Two", treasure, 2)
	var thief: MmCardDefinition = Scenario.creature("Thief", 3, 3,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.create_tokens(treasure)])])

	assert_eq(AbilityText.of_card(one.abilities, one.card_types, one.supertypes, "One"), "Create a Treasure token.")
	assert_eq(AbilityText.of_card(two.abilities, two.card_types, two.supertypes, "Two"), "Create two Treasure tokens.")
	assert_eq(AbilityText.of_card(thief.abilities, thief.card_types, thief.supertypes, "Thief"),
		"When this creature enters, create a Treasure token.", "As Jewel Thief words it.")


func test_a_clue_prints_as_cr_111_10f_words_it_and_is_created_by_its_name() -> void:
	var clue: MmCardDefinition = load(CLUE) as MmCardDefinition
	var inspector: MmCardDefinition = Scenario.creature("Inspector", 1, 2,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.create_tokens(clue)])])

	assert_eq(AbilityText.of_card(clue.abilities, clue.card_types, clue.supertypes, clue.name),
		"{2}, Sacrifice this token: Draw a card.")
	assert_eq(AbilityText.of_card(inspector.abilities, inspector.card_types, inspector.supertypes, "Inspector"),
		"When this creature enters, create a Clue token.", "Investigate's meaning (CR 701.16a).")


func test_mana_of_any_color_is_worded_as_oracle_words_it() -> void:
	var ability: ActivatedAbility = Scenario.activated(null, [TapCost.new()], [Scenario.any_color()])

	assert_eq(AbilityText.of_ability(ability, "this artifact"), "{T}: Add one mana of any color.")


func test_mana_of_one_of_some_colors_is_worded_as_oracle_words_it() -> void:
	var three: ActivatedAbility = Scenario.activated(null, [TapCost.new()],
		[Scenario.one_of_colors([MmMana.Type.GREEN, MmMana.Type.BLUE, MmMana.Type.RED])])
	var two: ActivatedAbility = Scenario.activated(null, [TapCost.new()],
		[Scenario.one_of_colors([MmMana.Type.WHITE, MmMana.Type.BLUE])])

	assert_eq(AbilityText.of_ability(three, "this land"), "{T}: Add {G}, {U}, or {R}.", "In the order printed.")
	assert_eq(AbilityText.of_ability(two, "this land"), "{T}: Add {W} or {U}.")
	assert_eq(AbilityText.option_of(three, "this land", MmMana.Type.BLUE), "{T}: Add {U}.", "ADR 0072.")


func test_an_option_row_says_which_color_its_activation_adds() -> void:
	# ADR 0072: each color is an action of its own, and its Option Menu row says which.
	var treasure: MmCardDefinition = load(TREASURE) as MmCardDefinition
	var ability: MmAbility = treasure.abilities[0]
	var noun: String = AbilityText.self_noun(treasure.card_types, treasure.name, treasure.abilities)

	assert_eq(AbilityText.option_of(ability, noun, MmMana.Type.WHITE), "{T}, Sacrifice this token: Add {W}.")
	assert_eq(AbilityText.option_of(ability, noun, MmMana.Type.GREEN), "{T}, Sacrifice this token: Add {G}.")
	assert_eq(AbilityText.option_of(ability, noun), "{T}, Sacrifice this token: Add one mana of any color.",
		"With no color chosen, as printed.")
	assert_eq(AbilityText.option_of(Scenario.tap_for_mana(MmMana.Type.RED, 1), "this land", MmMana.Type.WHITE),
		"{T}: Add {R}.", "A color chosen changes only mana of any color.")


func test_a_mode_with_a_counted_amount_says_what_x_is() -> void:
	var count: CountValue = CountValue.new()
	count.selection = Scenario.each(Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE), _yours()]))
	var damage: DealDamageEffect = Scenario.deal_damage(0, Scenario.targeted(0))
	damage.amount = count
	var spell: SpellAbility = Scenario.free_modal("Maneuver", [
		Scenario.ability_mode([Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))], [damage]),
		Scenario.ability_mode([Scenario.target(Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT))],
			[Scenario.destroy(Scenario.targeted(0))]),
	]).abilities[0] as SpellAbility

	assert_eq(AbilityText.mode_text(spell, 0, "Maneuver"),
		"Maneuver deals damage to target creature equal to the number of creatures you control.")


func test_a_summed_amount_reads_each_addend_joined_by_plus() -> void:
	var slash: MmCardDefinition = Scenario.free_slash("Slash")

	assert_eq(AbilityText.of_card(slash.abilities, slash.card_types, slash.supertypes, "Slash"),
		"Slash deals damage to target creature equal to the number of creatures you control"
		+ " plus the number of Equipment you control.")


func test_a_sum_of_three_reads_plus_between_each() -> void:
	var damage: DealDamageEffect = Scenario.deal_damage(0, Scenario.targeted(0))
	damage.amount = Scenario.sum([Scenario.count_yours(Scenario.of_type(CardType.CREATURE)),
		Scenario.count_yours(Scenario.of_type(CardType.LAND)), Scenario.constant(1)])
	var spell: MmCardDefinition = Scenario.instant("Sum", Scenario.mana_cost(0), [Scenario.any_target()], [damage])

	assert_eq(AbilityText.of_card(spell.abilities, spell.card_types, spell.supertypes, "Sum"),
		"Sum deals damage to any target equal to the number of creatures you control"
		+ " plus the number of lands you control plus 1.")


func test_domain_reads_as_the_number_of_basic_land_types_among_lands_you_control() -> void:
	var damage: DealDamageEffect = Scenario.deal_damage(0, Scenario.targeted(0))
	damage.amount = Scenario.sum([Scenario.constant(1), Scenario.domain()])
	var spell: MmCardDefinition = Scenario.instant("Artillery Blast", Scenario.mana_cost(0),
		[Scenario.target(Scenario.all_of([Scenario.of_type(CardType.CREATURE), IsTappedFilter.new()]))], [damage])

	assert_eq(AbilityText.of_card(spell.abilities, spell.card_types, spell.supertypes, "Artillery Blast"),
		"Artillery Blast deals damage to target tapped creature equal to 1 plus the number of basic land types"
		+ " among lands you control.")


func test_a_pump_by_domain_says_what_x_is() -> void:
	# Gaea's Might; its "Domain —" ability word is not printed, as Landfall's is not.
	var pump: ModifyPowerToughnessContinuousEffect = Scenario.modify_pt(0, 0, Scenario.targeted(0))
	pump.power = Scenario.domain()
	pump.toughness = Scenario.domain()
	var spell: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Gaea's Might", pump)

	assert_eq(AbilityText.of_card(spell.abilities, spell.card_types, spell.supertypes, "Gaea's Might"),
		"Target creature gets +X/+X until end of turn, where X is the number of basic land types among lands you control.")


func test_a_power_defined_alone_leaves_the_toughness_unsaid() -> void:
	# Nishoba Brawler, a */3; its "Domain —" ability word is not printed.
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.power = Scenario.domain()
	var brawler: MmCardDefinition = Scenario.creature("Nishoba Brawler", 0, 3, [defining])

	assert_eq(AbilityText.of_card(brawler.abilities, brawler.card_types, brawler.supertypes, "Nishoba Brawler"),
		"This creature's power is equal to the number of basic land types among lands you control.")


func test_a_toughness_defined_alone_leaves_the_power_unsaid() -> void:
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.toughness = Scenario.domain()
	var sprawler: MmCardDefinition = Scenario.creature("Sprawler", 1, 0, [defining])

	assert_eq(AbilityText.of_card(sprawler.abilities, sprawler.card_types, sprawler.supertypes, "Sprawler"),
		"This creature's toughness is equal to the number of basic land types among lands you control.")


func test_equipment_is_its_own_plural() -> void:
	var count: CountValue = Scenario.count_yours(Scenario.has_subtype("Equipment"))
	var damage: DealDamageEffect = Scenario.deal_damage(0, Scenario.targeted(0))
	damage.amount = count
	var spell: MmCardDefinition = Scenario.instant("Count", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(CardType.CREATURE))], [damage])

	assert_eq(AbilityText.of_card(spell.abilities, spell.card_types, spell.supertypes, "Count"),
		"Count deals damage to target creature equal to the number of Equipment you control.")


func test_a_free_ability_costs_zero() -> void:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.effects = [Scenario.gain_life(1, Scenario.you())]

	assert_eq(AbilityText.of_ability(ability, "this creature"), "{0}: You gain 1 life.")


func test_mana_and_tapping_are_both_listed_as_costs() -> void:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = Scenario.mana_cost(1, [MmMana.Type.RED])
	ability.costs = [TapCost.new()]
	ability.targets = [Scenario.target_player()]
	ability.effects = [Scenario.lose_life(2, Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(ability, "this creature"), "{1}{R}, {T}: Target player loses 2 life.")


func test_exerting_is_a_cost_worded_as_pride_sovereign_words_it() -> void:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = Scenario.mana_cost(0, [MmMana.Type.WHITE])
	ability.costs = [TapCost.new(), ExertCost.new()]
	ability.effects = [Scenario.gain_life(1, Scenario.you())]

	assert_eq(AbilityText.of_ability(ability, "this creature"), "{W}, {T}, Exert this creature: You gain 1 life.",
		"CR 701.43, without its reminder text.")


func test_the_trigger_kinds_are_worded() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var expected: Dictionary[String, MmTrigger] = {
		"At the beginning of each opponent's upkeep, you gain 1 life.": Scenario.at_step(MmTurn.Step.UPKEEP, Whose.OPPONENT),
		"At the beginning of your end step, you gain 1 life.": Scenario.at_step(MmTurn.Step.END, Whose.YOU),
		"When this creature enters, you gain 1 life.": Scenario.enters(IsSourceFilter.new()),
		"Whenever a creature you control enters, you gain 1 life.": Scenario.enters(creature, Whose.YOU),
		"Whenever another creature you control enters, you gain 1 life.":
			Scenario.enters(Scenario.all_of([creature, Scenario.is_not(IsSourceFilter.new())]), Whose.YOU),
		"Whenever a creature dies, you gain 1 life.": Scenario.dies(creature),
		"When this creature dies, you gain 1 life.": Scenario.dies(IsSourceFilter.new()),
		"When this creature leaves the battlefield, you gain 1 life.": Scenario.leaves(IsSourceFilter.new()),
		"Whenever a creature leaves the battlefield, you gain 1 life.": Scenario.leaves(creature),
		"Whenever you cast a creature spell, you gain 1 life.": Scenario.casts(creature, Whose.YOU),
		"Whenever an opponent casts a spell, you gain 1 life.": Scenario.casts(null, Whose.OPPONENT),
		"Whenever a player casts an artifact spell, you gain 1 life.": Scenario.casts(Scenario.of_type(CardType.ARTIFACT), Whose.ANY),
		"Whenever you cast a spell that targets this creature, you gain 1 life.": Scenario.casts(Scenario.targets_source(), Whose.YOU),
		"Whenever you cast a creature spell that targets a creature you control, you gain 1 life.":
			Scenario.casts(Scenario.all_of([creature, Scenario.targets(Scenario.all_of([creature, ControlledByFilter.new()]))]), Whose.YOU),
		"Whenever one or more creatures you control attack, you gain 1 life.": _attack(Whose.YOU),
		"Whenever one or more creatures an opponent controls attack, you gain 1 life.": _attack(Whose.OPPONENT),
		"Whenever one or more creatures a player controls attack, you gain 1 life.": _attack(Whose.ANY),
		"Whenever this creature attacks, you gain 1 life.": Scenario.attacks(),
		"Whenever one or more Cats you control attack, you gain 1 life.": Scenario.attacks(Scenario.has_subtype("Cat")),
		"Whenever one or more Cats an opponent controls attack, you gain 1 life.":
			Scenario.attacks(Scenario.has_subtype("Cat"), Whose.OPPONENT),
		"Whenever this creature blocks a creature, you gain 1 life.": Scenario.blocks_a_creature(),
		"Whenever a creature you control blocks a creature, you gain 1 life.":
			Scenario.blocks_a_creature(Scenario.creature_you_control()),
	}
	for text: String in expected:
		assert_eq(AbilityText.of_ability(Scenario.triggered(expected[text], gain), "this creature"), text)


func test_a_trigger_limited_to_once_each_turn_says_so_and_its_zone_changes_read_one_or_more() -> void:
	# With the limit, triggering for each object plays as "one or more" does, so it is
	# worded as Oracle words Tocasia's Welcome, Welcoming Vampire and Morbid Opportunist.
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var graveyard: ZoneChangeTrigger = ZoneChangeTrigger.new()
	graveyard.to_zone = MmZone.Kind.GRAVEYARD
	graveyard.filter = creature
	var once: String = " This ability triggers only once each turn."
	var expected: Dictionary[String, MmTrigger] = {
		"Whenever one or more creatures you control with mana value 3 or less enter, you gain 1 life.":
			Scenario.enters(Scenario.all_of([creature, _yours(), Scenario.mana_value(3)])),
		"Whenever one or more lands you control enter, you gain 1 life.": Scenario.enters(Scenario.of_type(CardType.LAND), Whose.YOU),
		"Whenever one or more other creatures die, you gain 1 life.":
			Scenario.dies(Scenario.all_of([creature, Scenario.is_not(IsSourceFilter.new())])),
		"Whenever one or more creatures leave the battlefield, you gain 1 life.": Scenario.leaves(creature),
		"Whenever one or more creatures are put into a graveyard from anywhere, you gain 1 life.": graveyard,
		"When this creature enters, you gain 1 life.": Scenario.enters(IsSourceFilter.new()),
		"Whenever you cast a creature spell, you gain 1 life.": Scenario.casts(creature, Whose.YOU),
	}
	for text: String in expected:
		var limited: TriggeredAbility = Scenario.once_each_turn(Scenario.triggered(expected[text], gain))
		assert_eq(AbilityText.of_ability(limited, "this creature"), text + once)
	var unlimited: TriggeredAbility = Scenario.triggered(Scenario.dies(creature), gain)
	assert_eq(AbilityText.of_ability(unlimited, "this creature"), "Whenever a creature dies, you gain 1 life.")


func test_a_limited_trigger_that_names_that_creature_stays_singular() -> void:
	var counter: PutCountersEffect = Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, TriggeringObjectSelection.new())
	var enters: ZoneChangeTrigger = Scenario.enters(Scenario.of_type(CardType.CREATURE), Whose.YOU)
	var limited: TriggeredAbility = Scenario.once_each_turn(Scenario.triggered(enters, [counter]))

	assert_eq(AbilityText.of_ability(limited, "this creature"),
		"Whenever a creature you control enters, put a +1/+1 counter on that creature. This ability triggers only once each turn.")


func test_what_a_limited_trigger_does_leaves_out_its_limit() -> void:
	var welcome: TriggeredAbility = Scenario.welcome().abilities[0] as TriggeredAbility

	assert_eq(AbilityText.effect_of(welcome, "this enchantment"), "Draw a card.")


func test_the_effects_no_authored_card_uses_yet_are_worded() -> void:
	var white_creatures: EachSelection = Scenario.each_creature(Scenario.of_color(MmCardTypes.CardColor.WHITE))
	var you_control: ControlledByFilter = ControlledByFilter.new()
	var other_strays: EachSelection = Scenario.each_creature(Scenario.all_of(
		[Scenario.of_color(MmCardTypes.CardColor.WHITE), you_control, Scenario.is_not(IsSourceFilter.new()), Scenario.named("Charmed Stray")]))
	var expected: Dictionary[String, MmEffect] = {
		"Each player loses 2 life.": Scenario.lose_life(2, Scenario.each(IsPlayerFilter.new())),
		"Search your library for a basic land card, reveal it, put it into your hand, then shuffle.": Scenario.search(Scenario.basic_land_card()),
		"Search your library for up to two Plains cards, reveal them, put them into your hand, then shuffle.":
			Scenario.search(Scenario.has_subtype("Plains"), 2),
		"Search your library for a basic land card, put it onto the battlefield tapped, then shuffle.":
			Scenario.search(Scenario.basic_land_card(), 1, MmZone.Kind.BATTLEFIELD, false, true),
		"Search your library for an artifact card, put it into your graveyard, then shuffle.":
			Scenario.search(Scenario.of_type(MmCardTypes.CardType.ARTIFACT), 1, MmZone.Kind.GRAVEYARD, false),
		"Search your library for a nonbasic land card, exile it, then shuffle.":
			Scenario.search(Scenario.all_of([Scenario.is_not(Scenario.basic_land_card().filters[0]), Scenario.of_type(MmCardTypes.CardType.LAND)]), 1, MmZone.Kind.EXILE, false),
		"Each player draws two cards.": Scenario.draw_cards(2, Scenario.each(IsPlayerFilter.new())),
		"Sample deals 1 damage to each white creature.": Scenario.deal_damage(1, white_creatures),
		"Destroy each white creature.": Scenario.destroy(white_creatures),
		"Each white creature loses all abilities until end of turn.": Scenario.until_end_of_turn(Scenario.lose_all_abilities(white_creatures)),
		"Target creature has base power and toughness 0/1 until end of turn.": Scenario.until_end_of_turn(Scenario.set_pt(0, 1, Scenario.targeted(0))),
		"Target creature gets -2/-0 until end of turn.": Scenario.until_end_of_turn(Scenario.modify_pt(-2, 0, Scenario.targeted(0))),
		"Prevent the next 3 damage that would be dealt to you this turn.": Scenario.prevent_next(3, Scenario.you()),
		"Regenerate target creature.": Scenario.regenerate(Scenario.targeted(0)),
		"Put a +1/+1 counter on target creature.": Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, Scenario.targeted(0)),
		"Put two -1/-1 counters on each white creature.": Scenario.put_counters(MmCounter.Kind.MINUS_ONE_MINUS_ONE, 2, white_creatures),
		"Double the number of -1/-1 counters on each white creature.": Scenario.double_counters(MmCounter.Kind.MINUS_ONE_MINUS_ONE, white_creatures),
		"Destroy each other white creature you control originally named Charmed Stray.": Scenario.destroy(other_strays),
		"Destroy each creature not originally named Bear.": Scenario.destroy(Scenario.each_creature(Scenario.is_not(Scenario.named("Bear")))),
		"Return a creature you control to its owner's hand.": Scenario.return_to_hand(Scenario.chosen(Scenario.all_of([Scenario.of_type(CardType.CREATURE), you_control]))),
		"Return each creature to its owner's hand.": Scenario.return_to_hand(Scenario.each_creature()),
		"Tap target creature.": Scenario.tap(Scenario.targeted(0)),
		"Tap each white creature.": Scenario.tap(white_creatures),
		"Untap target creature.": Scenario.untap(Scenario.targeted(0)),
		"Untap each white creature.": Scenario.untap(white_creatures),
		"Destroy an artifact.": Scenario.destroy(Scenario.chosen(Scenario.of_type(CardType.ARTIFACT))),
		"Create a 1/1 white Cat creature token.": Scenario.create_tokens(Scenario.cat()),
		"Each player may play two additional lands this turn.": Scenario.additional_land_plays(2, Scenario.each(IsPlayerFilter.new())),
		"Create two 2/2 black and green Zombie Warrior creature tokens.": Scenario.create_tokens(
			Scenario.token(2, 2, [MmCardTypes.CardColor.BLACK, MmCardTypes.CardColor.GREEN], ["Zombie", "Warrior"]), 2),
	}
	for text: String in expected:
		var spell: SpellAbility = SpellAbility.new()
		spell.targets = [Scenario.target(Scenario.of_type(CardType.CREATURE))]
		spell.effects = [expected[text]]
		assert_eq(AbilityText.of_ability(spell, "Sample"), text)


func test_a_spell_with_two_effects_prints_two_sentences_and_calls_its_target_it_the_second_time() -> void:
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target(Scenario.of_type(CardType.CREATURE))]
	spell.effects = [Scenario.deal_damage(3, Scenario.targeted(0)), Scenario.deal_damage(1, Scenario.controller_of(Scenario.targeted(0)))]

	assert_eq(AbilityText.of_ability(spell, "Sample"), "Sample deals 3 damage to target creature. Sample deals 1 damage to its controller.")


func test_an_instead_effect_says_its_usual_effect_then_if_its_condition_what_happens_instead() -> void:
	# Scythecat Cub's landfall ability, the target named again as "that creature".
	var plus: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
	var landfall: TriggeredAbility = Scenario.triggered(Scenario.enters(Scenario.of_type(CardType.LAND), Whose.YOU),
		[Scenario.instead(Scenario.times_resolved(2), Scenario.put_counters(plus, 1, Scenario.targeted(0)),
			Scenario.double_counters(plus, Scenario.targeted(0)))],
		[Scenario.target(Scenario.all_of([Scenario.of_type(CardType.CREATURE), _yours()]))])

	assert_eq(AbilityText.of_ability(landfall, "this creature"), "Whenever a land you control enters, put a +1/+1 counter on "
		+ "target creature you control. If this is the second time this ability has resolved this turn, double the number of "
		+ "+1/+1 counters on that creature instead.")
	assert_eq(AbilityText.effect_of(landfall, "Scythecat Cub"), "Put a +1/+1 counter on target creature you control. If this "
		+ "is the second time this ability has resolved this turn, double the number of +1/+1 counters on that creature instead.")


func test_a_may_effect_says_you_may_then_what_it_does() -> void:
	# Leonin Snarecaster's ability (CR 603.5).
	var snare: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.may(Scenario.tap(Scenario.targeted(0)))], [Scenario.target(Scenario.of_type(CardType.CREATURE))])
	var spell: SpellAbility = SpellAbility.new()
	spell.effects = [Scenario.gain_life(2, Scenario.you()), Scenario.may(Scenario.draw_cards(1, Scenario.you()))]

	assert_eq(AbilityText.of_ability(snare, "this creature"), "When this creature enters, you may tap target creature.")
	assert_eq(AbilityText.effect_of(snare, "Leonin Snarecaster"), "You may tap target creature.")
	assert_eq(AbilityText.of_ability(spell, "Sample"), "You gain 2 life. You may draw a card.")


func test_what_a_may_effect_offers_is_worded_alone_for_the_question() -> void:
	# Game ADR 0060: "Leonin Snarecaster's ability: tap target creature?"
	var may: MayEffect = Scenario.may(Scenario.tap(Scenario.targeted(0)))
	var snare: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [may],
		[Scenario.target(Scenario.of_type(CardType.CREATURE))])

	assert_eq(AbilityText.offered_words(snare, may.effect, "Leonin Snarecaster"), "tap target creature")


# --- {X} costs, entering with counters and "you may [cost]" (engine ADR 0076) ----------


func test_a_cost_with_x_prints_x_first() -> void:
	assert_eq(Scenario.x_cost(0, [MmMana.Type.WHITE]).describe(), "{X}{W}")
	assert_eq(ManaSymbols.pip_names(Scenario.x_cost(0, [MmMana.Type.WHITE])), ["x", "w"] as Array[String])
	assert_eq(ManaSymbols.pip_names(Scenario.x_cost()), ["x"] as Array[String], "{X} alone is not {X}{0}.")


func test_entering_with_x_counters_says_x_with_no_where() -> void:
	var hydra: EntersWithCountersAbility = Scenario.enters_with_counters(Scenario.chosen_x())

	assert_eq(AbilityText.of_ability(hydra, "this creature"), "This creature enters with X +1/+1 counters on it.")
	assert_eq(AbilityText.of_ability(Scenario.enters_with_counters(Scenario.constant(2)), "this creature"),
		"This creature enters with two +1/+1 counters on it.")
	assert_eq(AbilityText.of_ability(Scenario.enters_with_counters(Scenario.constant(1)), "this creature"),
		"This creature enters with a +1/+1 counter on it.")


func test_x_chosen_as_it_was_cast_reads_x_with_no_where() -> void:
	var bounty: MmCardDefinition = Scenario.x_gain()

	assert_eq(AbilityText.of_card(bounty.abilities, bounty.card_types, bounty.supertypes, "Bounty"), "You gain X life.")


func test_you_may_remove_a_counter_if_you_do_is_worded_as_oracle_words_it() -> void:
	var yours: ControlledByFilter = ControlledByFilter.new()
	var others: MmSelection = Scenario.each_creature(Scenario.all_of([yours, Scenario.is_not(IsSourceFilter.new())]))
	var guide: TriggeredAbility = Scenario.triggered(Scenario.at_step(MmTurn.Step.BEGINNING_OF_COMBAT, MmTrigger.Whose.YOU),
		[Scenario.may_pay(Scenario.remove_counters(), Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, others))])

	assert_eq(AbilityText.of_ability(guide, "this creature"), "At the beginning of combat on your turn, you may remove a "
		+ "+1/+1 counter from this creature. If you do, put a +1/+1 counter on each other creature you control.")


func test_a_cost_of_counters_is_worded_by_how_many() -> void:
	assert_eq(AbilityText.cost_words(Scenario.remove_counters(), "this creature"), "Remove a +1/+1 counter from this creature")
	assert_eq(AbilityText.cost_words(Scenario.remove_counters(2, MmCounter.Kind.MINUS_ONE_MINUS_ONE), "this creature"),
		"Remove two -1/-1 counters from this creature")


func test_beginning_of_combat_is_worded_by_whose_turn() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	var words: Dictionary = {
		MmTrigger.Whose.YOU: "At the beginning of combat on your turn, you gain 1 life.",
		MmTrigger.Whose.OPPONENT: "At the beginning of combat on each opponent's turn, you gain 1 life.",
		MmTrigger.Whose.ANY: "At the beginning of each combat, you gain 1 life.",
	}
	for whose: MmTrigger.Whose in words:
		var ability: TriggeredAbility = Scenario.triggered(Scenario.at_step(MmTurn.Step.BEGINNING_OF_COMBAT, whose), gain)
		assert_eq(AbilityText.of_ability(ability, "this creature"), words[whose])


func test_a_pay_x_effect_says_you_may_pay_x_then_if_you_do_what_it_does() -> void:
	# ADR 0061: X is the X paid, so no "where X is" follows.
	var seeking: SearchLibraryEffect = Scenario.search(Scenario.of_type(CardType.CREATURE))
	seeking.amount = Scenario.paid_x()
	var seeker: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.pay_x(seeking)])
	var gainer: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.pay_x(Scenario.gain_x_life()), Scenario.gain_x_life()])

	assert_eq(AbilityText.of_ability(seeker, "this creature"), "When this creature enters, you may pay {X}. If you do, "
		+ "search your library for up to X creature cards, reveal them, put them into your hand, then shuffle.")
	assert_eq(AbilityText.effect_of(gainer, "Sample"), "You may pay {X}. If you do, you gain X life. You gain X life.")


func test_the_times_an_ability_has_resolved_are_worded_as_ordinals() -> void:
	var expected: Dictionary[int, String] = {1: "first", 2: "second", 3: "third", 4: "fourth"}
	for times: int in expected:
		var ability: ActivatedAbility = ActivatedAbility.new()
		ability.effects = [Scenario.instead(Scenario.times_resolved(times), Scenario.gain_life(1, Scenario.you()),
			Scenario.gain_life(10, Scenario.you()))]

		assert_eq(AbilityText.of_ability(ability, "this creature"), "{0}: You gain 1 life. If this is the %s time this " % expected[times]
			+ "ability has resolved this turn, you gain 10 life instead.")


func test_a_player_named_again_in_an_instead_effect_is_that_player() -> void:
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target_player()]
	spell.effects = [Scenario.instead(LifeAtLeastStartingCondition.new(), Scenario.draw_cards(1, Scenario.targeted(0)),
		Scenario.draw_cards(2, Scenario.targeted(0)))]

	assert_eq(AbilityText.of_ability(spell, "Sample"), "Target player draws a card. If your life total is greater than or "
		+ "equal to your starting life total, that player draws two cards instead.")


func test_a_player_targeted_once_is_that_player_the_second_time() -> void:
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target_player()]
	spell.effects = [Scenario.draw_cards(1, Scenario.targeted(0)), Scenario.lose_life(2, Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(spell, "Sample"), "Target player draws a card. That player loses 2 life.")


func test_of_two_card_types_the_last_is_the_noun() -> void:
	var both: MmFilter = Scenario.all_of([Scenario.of_type(CardType.ARTIFACT), Scenario.of_type(CardType.CREATURE)])
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target(both)]
	spell.effects = [Scenario.destroy(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(spell, "Sample"), "Destroy target artifact creature.")
	assert_eq(AbilityText.things(both), "artifact creatures")


func test_a_spells_own_cast_trigger_and_its_copy_are_worded_as_sage_of_the_skies_words_them() -> void:
	# CR 113.6k, 603.4, 707.10.
	var sage: TriggeredAbility = Scenario.triggered(Scenario.cast_this_spell(), [Scenario.copy_spell()], [],
		CastAnotherSpellThisTurnCondition.new())
	var twin: MmCardDefinition = Scenario.free_twin()

	assert_eq(AbilityText.of_ability(sage, "this creature"),
		"When you cast this spell, if you've cast another spell this turn, copy this spell.")
	assert_eq(AbilityText.of_card(twin.abilities, twin.card_types, twin.supertypes, "Twin"), "Copy target spell.")


func test_a_look_at_the_top_cards_is_worded_as_militia_bugler_words_it() -> void:
	# CR 701.20e, 701.20a.
	var bugler: MmCardDefinition = Scenario.bugler()
	var any: LookAtTopCardsEffect = Scenario.look_at_top(3, null)
	any.reveal = false

	assert_eq(AbilityText.of_card(bugler.abilities, bugler.card_types, bugler.supertypes, "Bugler"),
		"When this creature enters, look at the top four cards of your library. You may reveal a creature card "
		+ "with power 2 or less from among them and put it into your hand. Put the rest on the bottom of your "
		+ "library in a random order.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [any]), "this creature"),
		"When this creature enters, look at the top three cards of your library. You may put a card from among "
		+ "them into your hand. Put the rest on the bottom of your library in a random order.")


func test_a_token_copy_is_worded_as_oltec_matterweaver_words_it() -> void:
	# CR 707.2.
	var artifact_token: MmFilter = Scenario.all_of([Scenario.of_type(CardType.ARTIFACT), IsTokenFilter.new(),
		ControlledByFilter.new()])
	var one: CreateTokenCopyEffect = CreateTokenCopyEffect.new()
	one.selection = Scenario.targeted(0)
	var copier: TriggeredAbility = Scenario.triggered(Scenario.casts(Scenario.of_type(CardType.CREATURE), Whose.YOU), [one])
	copier.targets = [Scenario.target(artifact_token)]
	var two: CreateTokenCopyEffect = CreateTokenCopyEffect.new()
	two.selection = SourceSelection.new()
	two.amount = 2

	assert_eq(AbilityText.of_ability(copier, "this creature"),
		"Whenever you cast a creature spell, create a token that's a copy of target artifact token you control.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [two]), "this creature"),
		"When this creature enters, create two tokens that are copies of this creature.")


func test_token_and_nontoken_are_adjectives_and_a_subtype_stands_next_to_its_noun_with_no_comma() -> void:
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var cat: MmFilter = Scenario.has_subtype("Cat")
	var nontoken: MmFilter = Scenario.is_not(IsTokenFilter.new())
	var maker: TriggeredAbility = Scenario.triggered(
		Scenario.enters(Scenario.all_of([creature, cat, nontoken]), MmTrigger.Whose.YOU), [Scenario.create_tokens(Scenario.cat())])

	assert_eq(AbilityText.of_ability(maker, "this creature"),
		"Whenever a nontoken Cat creature you control enters, create a 1/1 white Cat creature token.", "CR 111.1.")
	assert_eq(AbilityText.things(Scenario.all_of([creature, IsTokenFilter.new()])), "creature tokens")
	assert_eq(AbilityText.things(Scenario.all_of([IsTokenFilter.new(), creature])), "creature tokens", "Whatever the order.")
	assert_eq(AbilityText.things(IsTokenFilter.new()), "tokens")
	assert_eq(AbilityText.things(Scenario.all_of([cat, nontoken, Scenario.is_not(IsSourceFilter.new())])), "other nontoken Cats")
	assert_eq(AbilityText.things(Scenario.all_of([creature, cat, Scenario.is_not(IsTappedFilter.new())])), "untapped Cat creatures")


func test_lifelink_is_a_keyword() -> void:
	assert_eq(AbilityText.of_ability(LifelinkAbility.new(), "Sample"), "Lifelink")
	assert_true(AbilityText.is_keyword(LifelinkAbility.new()))


func test_target_spell_is_worded_with_and_without_a_filter() -> void:
	var any: SpellAbility = SpellAbility.new()
	any.targets = [Scenario.target_spell()]
	any.effects = [Scenario.counter(Scenario.targeted(0))]
	var creatures: SpellAbility = SpellAbility.new()
	creatures.targets = [Scenario.target_spell(Scenario.of_type(CardType.CREATURE))]
	creatures.effects = [Scenario.counter(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(any, "Sample"), "Counter target spell.")
	assert_eq(AbilityText.of_ability(creatures, "Sample"), "Counter target creature spell.")


func test_a_card_in_a_graveyard_is_worded_with_whose_graveyard_it_is_in() -> void:
	var yours: SpellAbility = SpellAbility.new()
	yours.targets = [Scenario.your_dead_creature()]
	yours.effects = [Scenario.return_to_hand(Scenario.targeted(0))]
	var any: SpellAbility = SpellAbility.new()
	any.targets = [Scenario.target_graveyard_card()]
	any.effects = [Scenario.return_to_hand(Scenario.targeted(0))]
	var theirs: SpellAbility = SpellAbility.new()
	theirs.targets = [Scenario.target_graveyard_card(Scenario.owned_by(Whose.OPPONENT))]
	theirs.effects = [Scenario.return_to_hand(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(yours, "Sample"), "Return target creature card from your graveyard to your hand.")
	assert_eq(AbilityText.of_ability(any, "Sample"), "Return target card from a graveyard to its owner's hand.")
	assert_eq(AbilityText.of_ability(theirs, "Sample"), "Return target card from an opponent's graveyard to its owner's hand.")
	assert_eq(AbilityText.things(Scenario.owned_by(Whose.YOU)), "permanents you own")


func test_exiling_another_target_and_returning_the_exiled_card_are_worded() -> void:
	var exiling: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.exile(Scenario.targeted(0))], [Scenario.another_nonland_permanent()])
	var returning: TriggeredAbility = Scenario.triggered(Scenario.leaves(IsSourceFilter.new()),
		[Scenario.return_to_battlefield(ExiledWithSourceSelection.new())])
	var another_creature: ActivatedAbility = ActivatedAbility.new()
	another_creature.targets = [Scenario.target(Scenario.all_of([Scenario.is_not(IsSourceFilter.new()), Scenario.of_type(CardType.CREATURE)]))]
	another_creature.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(exiling, "this enchantment"), "When this enchantment enters, exile another target nonland permanent.")
	assert_eq(AbilityText.of_ability(returning, "this enchantment"),
		"When this enchantment leaves the battlefield, return the exiled card to the battlefield under its owner's control.")
	assert_eq(AbilityText.of_ability(Scenario.exile_spell("Banish").abilities[0], "Banish"), "Exile target creature.")
	assert_eq(AbilityText.of_ability(another_creature, "this creature"), "{0}: This creature deals 1 damage to another target creature.")
	assert_eq(AbilityText.things(Scenario.is_not(IsPlayerFilter.new())), "permanents", "Anything but a player is a permanent.")


func test_a_card_put_on_the_bottom_of_a_library_is_worded_with_whose_library_it_is() -> void:
	# Landscaper Colos: "put target card from an opponent's graveyard on the bottom of their
	# library", "their" being its owner.
	var theirs: SpellAbility = SpellAbility.new()
	theirs.targets = [Scenario.target_graveyard_card(Scenario.owned_by(Whose.OPPONENT))]
	theirs.effects = [Scenario.put_on_bottom(Scenario.targeted(0))]
	var yours: SpellAbility = SpellAbility.new()
	yours.targets = [Scenario.your_dead_creature()]
	yours.effects = [Scenario.put_on_bottom(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(theirs, "Sample"),
		"Put target card from an opponent's graveyard on the bottom of its owner's library.")
	assert_eq(AbilityText.of_ability(yours, "Sample"),
		"Put target creature card from your graveyard on the bottom of your library.")


func test_exiling_until_this_leaves_the_battlefield_is_worded() -> void:
	# Leyline Binding's trigger (CR 610.3).
	var binding: MmCardDefinition = Scenario.free_binding("Binding")

	assert_eq(AbilityText.of_ability(binding.abilities[0], "this enchantment"), "When this enchantment enters, exile target "
		+ "nonland permanent an opponent controls until this enchantment leaves the battlefield.")


func test_up_to_targets_are_worded_with_each_of_for_counters() -> void:
	var gird: MmAbility = Scenario.free_gird("Gird").abilities[0]
	var savior: MmAbility = Scenario.savior().abilities[0]
	var one: SpellAbility = SpellAbility.new()
	one.targets = [Scenario.up_to_targets(Scenario.of_type(CardType.CREATURE), 1)]
	one.effects = [Scenario.destroy(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(gird, "Gird"), "Put a +1/+1 counter on each of up to two target creatures.")
	assert_eq(AbilityText.of_ability(savior, "this creature"),
		"When this creature enters, put a +1/+1 counter on each of up to two other target creatures you control.")
	assert_eq(AbilityText.of_ability(one, "Sample"), "Destroy up to one target creature.")


func test_target_ability_is_worded_as_activated_or_triggered() -> void:
	var stifle: SpellAbility = SpellAbility.new()
	stifle.targets = [Scenario.target_ability()]
	stifle.effects = [Scenario.counter(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(stifle, "Sample"), "Counter target activated or triggered ability.")


func test_the_static_abilities_no_authored_card_uses_yet_are_worded() -> void:
	var extra_land: AdditionalLandPlaysAbility = AdditionalLandPlaysAbility.new()
	var extra_blocks: BlockAdditionalAbility = BlockAdditionalAbility.new()
	extra_blocks.count = 2
	var anthem: ContinuousStaticAbility = Scenario.continuous_static([
		Scenario.modify_pt(1, 1, Scenario.each_creature(Scenario.of_color(MmCardTypes.CardColor.WHITE)))])

	assert_eq(AbilityText.of_ability(extra_land, "this artifact"), "You may play an additional land on each of your turns.")
	assert_eq(AbilityText.of_ability(extra_blocks, "this creature"), "This creature can block two additional creatures each combat.")
	assert_eq(AbilityText.of_ability(DamageStaysAbility.new(), "this creature"), "Damage isn't removed from this creature during cleanup steps.")
	assert_eq(AbilityText.of_ability(EntersTappedAbility.new(), "this land"), "This land enters tapped.")
	assert_eq(AbilityText.of_ability(EntersTappedAbility.new(), "this creature"), "This creature enters tapped.")
	var shock: AsEntersPayOrEntersTappedAbility = AsEntersPayOrEntersTappedAbility.new()
	shock.cost = Scenario.pay_life(2)
	assert_eq(AbilityText.of_ability(shock, "this land"), "As this land enters, you may pay 2 life. If you don't, it enters tapped.")
	assert_eq(AbilityText.cost_words(Scenario.pay_life(2), "this land"), "Pay 2 life", "The Info Panel's Pay answer (game ADR 0067).")
	assert_eq(AbilityText.of_ability(anthem, "this enchantment"), "Each white creature gets +1/+1.")
	assert_eq(AbilityText.of_ability(Scenario.protection_from(Scenario.of_type(CardType.ARTIFACT)), "this creature"), "Protection from artifacts")
	assert_eq(AbilityText.of_ability(HasteAbility.new(), "this creature"), "Haste")


func test_a_static_ability_says_has_and_is_where_an_effect_says_gains_and_becomes() -> void:
	var knights: EachSelection = Scenario.each_creature(Scenario.has_subtype("Knight"))
	var lord: ContinuousStaticAbility = Scenario.continuous_static([Scenario.gain_abilities([FlyingAbility.new()], knights)])
	var knighted: ContinuousStaticAbility = Scenario.continuous_static([Scenario.add_subtypes(["Knight"], SourceSelection.new())])
	var elves: ContinuousStaticAbility = Scenario.continuous_static([Scenario.add_subtypes(["Elf", "Warrior"], knights)])
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target(Scenario.of_type(CardType.CREATURE))]
	spell.effects = [Scenario.until_end_of_turn(Scenario.add_subtypes(["Knight"], Scenario.targeted(0)))]

	assert_eq(AbilityText.of_ability(lord, "this creature"), "Each Knight creature has flying.")
	assert_eq(AbilityText.of_ability(knighted, "this creature"), "This creature is a Knight in addition to its other types.")
	assert_eq(AbilityText.of_ability(elves, "this creature"), "Each Knight creature is an Elf Warrior in addition to its other types.")
	assert_eq(AbilityText.of_ability(spell, "Sample"), "Target creature becomes a Knight in addition to its other types until end of turn.")


func test_all_five_basic_land_types_read_as_every_basic_land_type() -> void:
	# Nylea's Presence's last line (CR 305.7).
	var presence: MmCardDefinition = Scenario.aura("Presence", null,
		[Scenario.continuous_static([Scenario.every_basic_land_type(Scenario.attached())])])
	var four: MmCardDefinition = Scenario.aura("Four", null, [Scenario.continuous_static([
		Scenario.add_subtypes(["Plains", "Island", "Swamp", "Mountain"], Scenario.attached())])])
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target(Scenario.of_type(CardType.LAND))]
	spell.effects = [Scenario.until_end_of_turn(Scenario.every_basic_land_type(Scenario.targeted(0)))]

	assert_eq(AbilityText.of_card(presence.abilities, presence.card_types, presence.supertypes, presence.name),
		"Enchant land\nEnchanted land is every basic land type in addition to its other types.")
	assert_eq(AbilityText.of_ability(spell, "Sample"),
		"Target land becomes every basic land type in addition to its other types until end of turn.")
	assert_eq(AbilityText.of_card(four.abilities, four.card_types, four.supertypes, four.name),
		"Enchant land\nEnchanted land is a Plains Island Swamp Mountain in addition to its other types.",
		"Only all five read as every one.")


func test_a_static_ability_that_ends_in_a_quoted_ability_ends_with_the_quotation() -> void:
	# Oracle wording: the granted ability's own period closes the sentence, as Frondland
	# Felidar's does, so no second one follows the quotation mark.
	var tapper: ActivatedAbility = Scenario.activated(Scenario.mana_cost(1), [TapCost.new()],
		[Scenario.tap(Scenario.targeted(0))], [Scenario.target(Scenario.of_type(CardType.CREATURE))])
	var lord: ContinuousStaticAbility = Scenario.continuous_static([Scenario.gain_abilities([tapper], Scenario.each_creature())])
	var squire: ContinuousStaticAbility = Scenario.continuous_static([Scenario.gain_abilities([tapper], SourceSelection.new())],
		Scenario.condition(SourceSelection.new(), Scenario.has_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1)))

	assert_eq(AbilityText.of_ability(lord, "this creature"), "Each creature has \"{1}, {T}: Tap target creature.\"")
	assert_eq(AbilityText.of_ability(squire, "this creature"),
		"As long as this creature has a +1/+1 counter on it, it has \"{1}, {T}: Tap target creature.\"")


func test_a_conditional_static_ability_is_one_sentence_that_calls_its_source_it_after_the_condition() -> void:
	var plus: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
	var squire: ContinuousStaticAbility = Scenario.continuous_static(
		[Scenario.gain_abilities([FlyingAbility.new()], SourceSelection.new()), Scenario.add_subtypes(["Knight"], SourceSelection.new())],
		Scenario.condition(SourceSelection.new(), Scenario.has_counters(plus, 3)))
	var one_counter: ContinuousStaticAbility = Scenario.continuous_static(
		[Scenario.modify_pt(1, 0, SourceSelection.new())], Scenario.condition(SourceSelection.new(), Scenario.has_counters(plus, 1)))

	assert_eq(AbilityText.of_ability(squire, "this creature"),
		"As long as this creature has three or more +1/+1 counters on it, it has flying and is a Knight in addition to its other types.")
	assert_eq(AbilityText.of_ability(one_counter, "this creature"), "As long as this creature has a +1/+1 counter on it, it gets +1/+0.")
	var brave: ContinuousStaticAbility = Scenario.continuous_static(
		[Scenario.modify_pt(1, 1, SourceSelection.new())], LifeAtLeastStartingCondition.new())
	assert_eq(AbilityText.of_ability(brave, "this creature"),
		"As long as your life total is greater than or equal to your starting life total, it gets +1/+1.")
	assert_eq(AbilityText.things(Scenario.all_of([Scenario.of_type(CardType.CREATURE), IsAttackingFilter.new()])), "attacking creatures")
	assert_eq(AbilityText.things(Scenario.all_of([Scenario.of_type(CardType.CREATURE), Scenario.is_not(IsAttackingFilter.new())])),
		"nonattacking creatures")
	assert_eq(AbilityText.things(Scenario.all_of([Scenario.of_type(CardType.CREATURE), IsBlockingFilter.new()])), "blocking creatures")
	assert_eq(AbilityText.things(Scenario.all_of([Scenario.of_type(CardType.CREATURE), Scenario.is_not(IsBlockingFilter.new())])),
		"nonblocking creatures")
	assert_eq(AbilityText.things(Scenario.attacking_or_blocking_creature()), "attacking or blocking creatures")
	assert_eq(AbilityText.of_ability(Scenario.free_outflank("Outflank").abilities[0], "Outflank"),
		"Outflank deals damage to target attacking or blocking creature equal to the number of creatures you control.")


func test_equipped_is_worded_as_an_adjective_and_unequipped_when_negated() -> void:
	var kemba: MmAbility = Scenario.kemba().abilities[0]
	var shikari: MmAbility = Scenario.shikari().abilities[0]
	var reunite: MmAbility = Scenario.free_reunite().abilities[0]

	assert_eq(AbilityText.of_ability(kemba, "Kemba"), "Each equipped creature you control gets +1/+1.")
	assert_eq(AbilityText.of_ability(shikari, "this creature"), "As long as this creature is equipped, it has first strike and lifelink.")
	assert_eq(AbilityText.of_ability(reunite, "Reunite"), "Each equipped creature you control gains indestructible until end of turn.")
	assert_eq(AbilityText.things(Scenario.all_of([Scenario.of_type(CardType.CREATURE), Scenario.is_not(Scenario.equipped())])),
		"unequipped creatures")


func test_assigning_combat_damage_by_toughness_is_worded_as_bark_of_doran_words_it() -> void:
	var bark: MmCardDefinition = Scenario.bark()
	var assigns: String = " assigns combat damage equal to its toughness rather than its power."

	assert_eq(AbilityText.of_card(bark.abilities, bark.card_types, bark.supertypes, bark.name),
		"Equipped creature gets +0/+1.\nAs long as equipped creature's toughness is greater than its power, it" + assigns
		+ "\nEquip {0}")
	assert_eq(AbilityText.of_ability(Scenario.by_toughness(Scenario.attached()), "this artifact"), "Equipped creature" + assigns)
	assert_eq(AbilityText.of_ability(Scenario.by_toughness(), "this creature"), "This creature" + assigns)
	assert_eq(AbilityText.of_ability(Scenario.by_toughness(Scenario.each_creature()), "Doran"), "Each creature" + assigns,
		"As Doran, the Siege Tower words it.")


func test_a_condition_on_toughness_alone_says_whose_toughness_it_is() -> void:
	var sturdy: ContinuousStaticAbility = Scenario.continuous_static([Scenario.gain_abilities([FlyingAbility.new()], SourceSelection.new())],
		Scenario.condition(SourceSelection.new(), Scenario.toughness(4, ToughnessFilter.Comparison.OR_GREATER)))

	assert_eq(AbilityText.of_ability(sturdy, "this creature"), "As long as this creature's toughness is 4 or greater, it has flying.")


func test_a_counter_filter_is_worded_after_its_noun() -> void:
	var plus: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
	var minus: MmCounter.Kind = MmCounter.Kind.MINUS_ONE_MINUS_ONE
	var expected: Dictionary[String, MmFilter] = {
		"Destroy each creature with a +1/+1 counter on it.": Scenario.has_counters(plus, 1),
		"Destroy each creature with three or more -1/-1 counters on it.": Scenario.has_counters(minus, 3),
		"Destroy each creature without a +1/+1 counter on it.": Scenario.is_not(Scenario.has_counters(plus, 1)),
		"Destroy each creature with fewer than two -1/-1 counters on it.": Scenario.is_not(Scenario.has_counters(minus, 2)),
	}
	for text: String in expected:
		var spell: SpellAbility = SpellAbility.new()
		spell.effects = [Scenario.destroy(Scenario.each_creature(expected[text]))]
		assert_eq(AbilityText.of_ability(spell, "Sample"), text)


func test_keywords_share_a_line_and_other_abilities_get_their_own() -> void:
	var abilities: Array[MmAbility] = [FlyingAbility.new(), FirstStrikeAbility.new(), TrampleAbility.new(),
		Scenario.regenerate_ability(Scenario.mana_cost(0, [MmMana.Type.GREEN]))]

	assert_eq(AbilityText.of_card(abilities, [CardType.CREATURE], [], "Sample"), "Flying, first strike, trample\n{G}: Regenerate this creature.")


## The look of the authored card in [param file_name], whichever set's folder it is in.
func _look(file_name: String) -> CardLook:
	for set_name: String in DirAccess.get_directories_at(SETS_ROOT):
		var path: String = "%s/%s/%s.tres" % [SETS_ROOT, set_name, file_name]
		if ResourceLoader.exists(path):
			return CardLook.of_definition(load(path) as MmCardDefinition)
	return null


func test_changeling_is_a_keyword_that_shares_a_line() -> void:
	var abilities: Array[MmAbility] = [ChangelingAbility.new(), FlyingAbility.new()]

	assert_eq(AbilityText.of_ability(ChangelingAbility.new(), "this creature"), "Changeling")
	assert_true(AbilityText.is_keyword(ChangelingAbility.new()))
	assert_eq(AbilityText.of_card(abilities, [CardType.CREATURE], [], "Sample"), "Changeling, flying")


func test_hexproof_is_a_keyword_that_shares_a_line() -> void:
	var abilities: Array[MmAbility] = [FlyingAbility.new(), HexproofAbility.new()]

	assert_eq(AbilityText.of_ability(HexproofAbility.new(), "this creature"), "Hexproof")
	assert_true(AbilityText.is_keyword(HexproofAbility.new()))
	assert_eq(AbilityText.of_card(abilities, [CardType.CREATURE], [], "Sample"), "Flying, hexproof")


func test_exalted_is_a_keyword_that_shares_a_line() -> void:
	var abilities: Array[MmAbility] = [ExaltedAbility.new(), FlyingAbility.new()]

	assert_eq(AbilityText.of_ability(ExaltedAbility.new(), "this creature"), "Exalted")
	assert_true(AbilityText.is_keyword(ExaltedAbility.new()))
	assert_eq(AbilityText.of_card(abilities, [CardType.CREATURE], [], "Sample"), "Exalted, flying")


func test_battle_cry_is_a_keyword_that_shares_a_line() -> void:
	var abilities: Array[MmAbility] = [FlyingAbility.new(), BattleCryAbility.new()]

	assert_eq(AbilityText.of_ability(BattleCryAbility.new(), "this creature"), "Battle cry")
	assert_true(AbilityText.is_keyword(BattleCryAbility.new()))
	assert_eq(AbilityText.of_card(abilities, [CardType.CREATURE], [], "Sample"), "Flying, battle cry")


func test_battle_crys_parts_are_worded_as_its_rule_says() -> void:
	# CR 702.91a, as a Modification that copied its trigger and effect would read.
	var battle_cry: BattleCryAbility = BattleCryAbility.new()
	var parts: TriggeredAbility = Scenario.triggered(battle_cry.trigger, battle_cry.effects)

	assert_eq(AbilityText.of_ability(parts, "this creature"),
		"Whenever this creature attacks, each other attacking creature gets +1/+0 until end of turn.")


func test_prowess_is_a_keyword_that_shares_a_line() -> void:
	var abilities: Array[MmAbility] = [FlashAbility.new(), ProwessAbility.new()]

	assert_eq(AbilityText.of_ability(ProwessAbility.new(), "this creature"), "Prowess")
	assert_true(AbilityText.is_keyword(ProwessAbility.new()))
	assert_eq(AbilityText.of_card(abilities, [CardType.CREATURE], [], "Sample"), "Flash, prowess")


func test_prowesss_parts_are_worded_as_its_rule_says() -> void:
	# CR 702.108a, as a Modification that copied its trigger and effect would read.
	var prowess: ProwessAbility = ProwessAbility.new()
	var parts: TriggeredAbility = Scenario.triggered(prowess.trigger, prowess.effects)

	assert_eq(AbilityText.of_ability(parts, "this creature"),
		"Whenever you cast a noncreature spell, this creature gets +1/+1 until end of turn.")


func test_evolve_is_a_keyword_that_shares_a_line() -> void:
	var abilities: Array[MmAbility] = [FlyingAbility.new(), EvolveAbility.new()]

	assert_eq(AbilityText.of_ability(EvolveAbility.new(), "this creature"), "Evolve")
	assert_true(AbilityText.is_keyword(EvolveAbility.new()))
	assert_eq(AbilityText.of_card(abilities, [CardType.CREATURE], [], "Sample"), "Flying, evolve")


func test_evolves_parts_are_worded_as_its_reminder_says() -> void:
	# CR 702.100a, as a Modification that copied its trigger, condition and effect would read.
	var evolve: EvolveAbility = EvolveAbility.new()
	var parts: TriggeredAbility = Scenario.triggered(evolve.trigger, evolve.effects, [], evolve.condition)

	assert_eq(AbilityText.of_ability(parts, "this creature"), "Whenever a creature you control enters, "
		+ "if that creature has greater power or toughness than this creature, put a +1/+1 counter on this creature.")


func test_a_greater_power_or_toughness_alone_is_worded_too() -> void:
	var evolve: EvolveAbility = EvolveAbility.new()
	var power_and_toughness: Array[MmFilter] = (evolve.condition as SelectionMatchesCondition).filter.filters
	var greater_power: MmCondition = Scenario.condition(TriggeringObjectSelection.new(), power_and_toughness[0])
	var greater_toughness: MmCondition = Scenario.condition(TriggeringObjectSelection.new(), power_and_toughness[1])
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	var enters: ZoneChangeTrigger = Scenario.enters(Scenario.of_type(CardType.CREATURE), MmTrigger.Whose.YOU)

	assert_eq(AbilityText.of_ability(Scenario.triggered(enters, gain, [], greater_power), "this creature"),
		"Whenever a creature you control enters, if that creature has greater power than this creature, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(enters, gain, [], greater_toughness), "this creature"),
		"Whenever a creature you control enters, if that creature has greater toughness than this creature, you gain 1 life.")


func test_a_power_bound_from_a_value_is_worded_inline_and_one_more_as_greater_than() -> void:
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var its_power: PowerValue = PowerValue.new()
	its_power.selection = SourceSelection.new()
	var its_toughness: ToughnessValue = ToughnessValue.new()
	its_toughness.selection = SourceSelection.new()
	var greater: PowerFilter = Scenario.power_from(Scenario.sum([its_power, Scenario.constant(1)]), PowerFilter.Comparison.OR_GREATER)

	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.power_from(Scenario.constant(2))])),
		"creatures with power 2 or less")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.power_from(Scenario.domain())])),
		"creatures with power less than or equal to the number of basic land types among lands you control")
	assert_eq(AbilityText.things(Scenario.all_of([creature, greater])), "creatures with power greater than its power")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.toughness_from(its_toughness, ToughnessFilter.Comparison.OR_GREATER)])),
		"creatures with toughness greater than or equal to its toughness", "\"It\" is the source, with no card to name it.")


func test_a_creature_attacking_alone_is_worded_as_exalted_reminds_it() -> void:
	var alone: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	alone.filter = Scenario.of_type(CardType.CREATURE)
	alone.alone = true
	var pump: CreateContinuousEffect = Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, TriggeringObjectSelection.new()))

	assert_eq(AbilityText.of_ability(Scenario.triggered(alone, [pump]), "this creature"),
		"Whenever a creature you control attacks alone, that creature gets +1/+1 until end of turn.")


func test_a_keyword_is_told_from_any_other_ability() -> void:
	assert_true(AbilityText.is_keyword(FlyingAbility.new()))
	assert_true(AbilityText.is_keyword(ProtectionAbility.new()))
	assert_false(AbilityText.is_keyword(ActivatedAbility.new()))


# --- Emblems and Potions (ADR 0036) ----------------------------------------------------

func test_the_authored_boons_and_potion_print_as_they_were_agreed() -> void:
	var electromancers: MmCardDefinition = load("res://content/emblems/electromancers_boon.tres")
	var diviners: MmCardDefinition = load("res://content/emblems/diviners_boon.tres")
	var big_gulp: MmCardDefinition = load("res://content/potions/big_gulp.tres")

	assert_eq(AbilityText.lines_of(electromancers.abilities, AbilityText.EMBLEM_NOUN),
		["{R}: This emblem deals 3 damage to any target. Activate only once each game."] as Array[String])
	assert_eq(AbilityText.lines_of(diviners.abilities, AbilityText.EMBLEM_NOUN),
		["{2}{U}: Draw two cards. Activate only as a sorcery and only once each game."] as Array[String])
	assert_eq(AbilityText.lines_of(big_gulp.abilities, AbilityText.POTION_NOUN),
		["Target creature gets +2/+2 until end of turn."] as Array[String], "A Potion prints no cost.")


func test_an_ability_restricted_only_to_sorcery_timing_says_so() -> void:
	var ability: ActivatedAbility = Scenario.regenerate_ability(Scenario.mana_cost(1))
	ability.is_sorcery_speed = true

	assert_eq(AbilityText.of_ability(ability, "this creature"), "{1}: Regenerate this creature. Activate only as a sorcery.")


func test_an_ability_that_costs_less_for_each_basic_land_type_says_so_after_what_it_does() -> void:
	# Jodah's Codex; its "Domain —" ability word is not printed, as Gaea's Might's is not.
	var codex: MmCardDefinition = Scenario.codex()

	assert_eq(AbilityText.of_card(codex.abilities, codex.card_types, codex.supertypes, "Codex"),
		"{5}, {T}: Draw a card. This ability costs {1} less to activate for each basic land type among lands you control.")


func test_an_ability_that_costs_less_by_another_value_says_what_x_is() -> void:
	var ability: ActivatedAbility = Scenario.regenerate_ability(Scenario.mana_cost(3))
	ability.generic_reduction = Scenario.count_yours(Scenario.of_type(CardType.ARTIFACT))

	assert_eq(AbilityText.of_ability(ability, "this creature"),
		"{3}: Regenerate this creature. This ability costs {X} less to activate, where X is the number of artifacts you control.")


func test_a_spell_that_costs_less_for_each_basic_land_type_says_so() -> void:
	# Leyline Binding's, without its "Domain —" ability word.
	var binding: MmCardDefinition = Scenario.domain_reduced_instant("Binding", Scenario.mana_cost(5, [MmMana.Type.WHITE]))

	assert_eq(AbilityText.of_card(binding.abilities, binding.card_types, binding.supertypes, "Binding"),
		"This spell costs {1} less to cast for each basic land type among lands you control.\nYou gain 1 life.")


func test_a_spell_that_costs_less_by_another_value_says_what_x_is() -> void:
	var reduction: CostReductionAbility = Scenario.cost_reduction(Scenario.count_yours(Scenario.of_type(CardType.ARTIFACT)))

	assert_eq(AbilityText.of_ability(reduction, "this spell"),
		"This spell costs {X} less to cast, where X is the number of artifacts you control.")


func test_a_reflexive_trigger_after_a_you_may_says_when_you_do_and_names_its_own_target() -> void:
	# Kishla Trawlers's (CR 603.12, engine ADR 0088).
	var trawler: MmCardDefinition = Scenario.trawler()
	var enters: TriggeredAbility = trawler.abilities[0] as TriggeredAbility
	var reflexive: TriggeredAbility = ((enters.effects[0] as MayPayEffect).effect as ReflexiveTriggerEffect).ability

	assert_eq(AbilityText.of_ability(enters, "this creature"), "When this creature enters, you may exile a creature card "
		+ "from your graveyard. When you do, return target instant or sorcery card from your graveyard to your hand.")
	assert_eq(AbilityText.effect_of(reflexive, "this creature"),
		"Return target instant or sorcery card from your graveyard to your hand.", "On the stack it says what it does.")
	assert_eq(AbilityText.of_ability(reflexive, "this creature"),
		"When you do, return target instant or sorcery card from your graveyard to your hand.")
	assert_eq(AbilityText.cost_words(Scenario.exile_from_graveyard(), "this creature"), "Exile a creature card from your graveyard")


func test_a_permanent_that_makes_your_nth_spell_each_turn_cost_less_says_which() -> void:
	# Highspire Bell-Ringer's, and the same with no N.
	assert_eq(AbilityText.of_ability(Scenario.spells_cost_less(1, 2), "this creature"),
		"The second spell you cast each turn costs {1} less to cast.")
	assert_eq(AbilityText.of_ability(Scenario.spells_cost_less(2, 0), "this creature"),
		"Spells you cast cost {2} less to cast.")


func test_equip_prints_as_a_keyword_with_its_cost_and_on_the_stack_as_what_it_does() -> void:
	var equip: EquipAbility = EquipAbility.new()
	equip.mana_cost = Scenario.mana_cost(1)

	assert_eq(AbilityText.of_ability(equip, "this artifact"), "Equip {1}")
	assert_true(AbilityText.is_keyword(equip))
	assert_eq(AbilityText.effect_of(equip, "this artifact"), "Attach this artifact to target creature you control.")


func test_what_an_equipment_is_attached_to_is_the_equipped_creature() -> void:
	var bonus: ModifyPowerToughnessContinuousEffect = Scenario.modify_pt(1, 1, AttachedToSelection.new())

	assert_eq(AbilityText.of_ability(Scenario.continuous_static([bonus]), "this artifact"), "Equipped creature gets +1/+1.")


func test_on_the_stack_an_emblems_ability_reads_without_its_cost_or_restrictions() -> void:
	var electromancers: MmCardDefinition = load("res://content/emblems/electromancers_boon.tres")

	assert_eq(AbilityText.effect_of(electromancers.abilities[0], AbilityText.EMBLEM_NOUN), "This emblem deals 3 damage to any target.")


func _yours() -> ControlledByFilter:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = Whose.YOU
	return yours


func _attack(whose: Whose) -> AttackersDeclaredTrigger:
	var trigger: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	trigger.whose = whose
	return trigger


func test_flashback_prints_its_cost_with_a_dash_when_it_is_more_than_mana() -> void:
	var life: Array[MmCost] = [Scenario.pay_life(3)]
	var creatures: Array[MmCost] = [Scenario.tap_creatures(3)]
	var one_creature: Array[MmCost] = [Scenario.tap_creatures(1)]
	var white: MmManaCost = Scenario.mana_cost(2, [MmMana.Type.WHITE])
	var blue: MmManaCost = Scenario.mana_cost(1, [MmMana.Type.BLUE])

	assert_eq(AbilityText.of_ability(Scenario.flashback(white), "Daydream"), "Flashback {2}{W}")
	assert_eq(AbilityText.of_ability(Scenario.flashback(blue, life), "Deep Analysis"), "Flashback—{1}{U}, Pay 3 life")
	assert_eq(AbilityText.of_ability(Scenario.flashback(null, creatures), "Group Project"),
		"Flashback—Tap three untapped creatures you control")
	assert_eq(AbilityText.of_ability(Scenario.flashback(null, one_creature), "Sample"), "Flashback—Tap an untapped creature you control")
	assert_true(AbilityText.is_keyword(Scenario.flashback(white)))


func test_cycling_prints_its_cost_alone() -> void:
	var cycling: CyclingAbility = Scenario.cycling(Scenario.mana_cost(2))

	var text: String = AbilityText.of_ability(cycling, "Lightshield Parry")

	assert_eq(text, "Cycling {2}", "CR 702.29a: what it does is its Reminder.")
	assert_true(AbilityText.is_keyword(cycling))
	var spelled_out: ActivatedAbility = ActivatedAbility.new()
	spelled_out.mana_cost = Scenario.mana_cost(2)
	spelled_out.costs = cycling.costs
	spelled_out.effects = cycling.effects
	assert_eq(AbilityText.of_ability(spelled_out, "Lightshield Parry"), "{2}, Discard this card: Draw a card.")
	assert_eq(AbilityText.of_card([Scenario.pump_spell("Parry", 2, 2).abilities[0], cycling] as Array[MmAbility],
		[MmCardTypes.CardType.INSTANT] as Array[MmCardTypes.CardType], [] as Array[MmCardTypes.Supertype], "Parry"),
		"Target creature gets +2/+2 until end of turn.\nCycling {2}")


func test_becoming_an_artifact_creature_with_a_base_power_and_toughness_is_one_clause_with_no_duration() -> void:
	# Bring to Life's (CR 205.1b, 611.2a, engine ADR 0091).
	var animate: MmCardDefinition = Scenario.free_animate()
	var both: Array[CardType] = [CardType.ARTIFACT, CardType.CREATURE]

	assert_eq(AbilityText.of_card(animate.abilities, animate.card_types, animate.supertypes, "Animate"),
		"Target noncreature artifact you control becomes a 0/0 artifact creature. Put four +1/+1 counters on it.")
	assert_eq(AbilityText.effect_of(_spell_of([Scenario.indefinitely(Scenario.add_card_types(both, Scenario.targeted(0)))]),
		"this"), "Target creature becomes an artifact creature.", "Alone, with no duration to say.")


## A spell targeting a creature that does [param effects].
func _spell_of(effects: Array[MmEffect]) -> SpellAbility:
	var spell: SpellAbility = SpellAbility.new()
	spell.targets = [Scenario.target(Scenario.of_type(CardType.CREATURE))]
	spell.effects = effects
	return spell


func test_explore_says_who_explores_and_a_map_is_created_by_its_name_alone() -> void:
	# CR 701.44a, 111.10, engine ADR 0090.
	var map: MmCardDefinition = Scenario.map()
	var scout: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.create_tokens(map)])

	assert_eq(AbilityText.of_card(map.abilities, map.card_types, map.supertypes, map.name),
		"{1}, {T}, Sacrifice this token: Target creature you control explores. Activate only as a sorcery.")
	assert_eq(AbilityText.of_ability(scout, "this creature"), "When this creature enters, create a Map token.")
	assert_eq(AbilityText.of_ability(Scenario.explorer().abilities[0], "this creature"),
		"When this creature enters, this creature explores.")


func test_bestow_prints_its_cost_alone_and_calls_what_it_enchants_enchanted_creature() -> void:
	# Nimbus Naiad's (CR 702.103a, engine ADR 0089), without its reminder text.
	var naiad: MmCardDefinition = Scenario.naiad("Naiad", null, Scenario.mana_cost(4, [MmMana.Type.BLUE]))

	assert_eq(AbilityText.of_card(naiad.abilities, naiad.card_types, naiad.supertypes, "Naiad"),
		"Bestow {4}{U}\nFlying\nEnchanted creature gets +2/+2. Enchanted creature has flying.")
	assert_true(AbilityText.is_keyword(naiad.abilities[0]))


func test_ward_prints_its_cost_alone_and_on_the_stack_as_what_it_does() -> void:
	var ward: WardAbility = Scenario.ward(Scenario.mana_cost(2))

	assert_eq(AbilityText.of_ability(ward, "this creature"), "Ward {2}", "CR 702.21a: what it does is its Reminder.")
	assert_true(AbilityText.is_keyword(ward))
	assert_eq(AbilityText.effect_of(ward, "this creature"), "Counter that spell or ability unless its controller pays {2}.")
	var spelled_out: TriggeredAbility = Scenario.triggered(ward.trigger, ward.effects)
	assert_eq(AbilityText.of_ability(spelled_out, "this creature"),
		"Whenever this creature becomes the target of a spell or ability an opponent controls, "
		+ "counter that spell or ability unless its controller pays {2}.")


func test_becoming_a_target_and_counter_unless_paid_are_worded() -> void:
	var trigger: BecomesTargetTrigger = BecomesTargetTrigger.new()
	trigger.filter = Scenario.of_type(CardType.CREATURE)
	trigger.whose = Whose.YOU
	var leak: SpellAbility = SpellAbility.new()
	leak.targets = [Scenario.target_spell()]
	var countering: CounterEffect = Scenario.counter(Scenario.targeted(0))
	countering.unless_paid = Scenario.mana_cost(3)
	leak.effects = [countering]

	assert_eq(AbilityText.of_ability(Scenario.triggered(trigger, [Scenario.gain_life(1, Scenario.you())]), "this creature"),
		"Whenever a creature becomes the target of a spell or ability you control, you gain 1 life.")
	assert_eq(AbilityText.of_ability(leak, "Sample"), "Counter target spell unless its controller pays {3}.")


func test_becoming_tapped_is_worded() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	var counter: Array[MmEffect] = [Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, TriggeringObjectSelection.new())]
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)

	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.becomes_tapped(), gain), "this creature"),
		"Whenever this creature becomes tapped, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.becomes_tapped(creature, Whose.YOU), counter), "Sample"),
		"Whenever a creature you control becomes tapped, put a +1/+1 counter on that creature.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.becomes_tapped(creature, Whose.OPPONENT), gain), "Sample"),
		"Whenever a creature an opponent controls becomes tapped, you gain 1 life.")


func test_counters_being_put_on_a_permanent_are_worded_one_or_more() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var minus: CountersPutTrigger = Scenario.counters_put(creature, Whose.OPPONENT, MmCounter.Kind.MINUS_ONE_MINUS_ONE)

	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.counters_put(), gain), "this creature"),
		"Whenever one or more +1/+1 counters are put on this creature, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.counters_put(creature, Whose.YOU), gain), "Sample"),
		"Whenever one or more +1/+1 counters are put on a creature you control, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(minus, gain), "Sample"),
		"Whenever one or more -1/-1 counters are put on a creature an opponent controls, you gain 1 life.")


func test_a_noun_of_either_kind_is_or_alone_and_and_or_counted_several() -> void:
	# Adaptive Gemguard: "Tap two untapped artifacts and/or creatures you control", where a mix
	# of the two may be tapped, as Oracle's "and/or" says; one of them is "artifact or creature".
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = Whose.YOU
	var either: AnyOfFilter = Scenario.any_of([Scenario.of_type(CardType.ARTIFACT), Scenario.of_type(CardType.CREATURE)])
	var two: TapCreaturesCost = Scenario.tap_creatures(2)
	two.filter = Scenario.all_of([either, Scenario.untapped(), mine])
	var grow: Array[MmEffect] = [Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, SourceSelection.new())]
	var gemguard: ActivatedAbility = Scenario.activated(null, [two], grow)
	gemguard.is_sorcery_speed = true

	assert_eq(AbilityText.of_ability(gemguard, "this creature"),
		"Tap two untapped artifacts and/or creatures you control: Put a +1/+1 counter on this creature. Activate only as a sorcery.")
	assert_eq(AbilityText.how_many_words(1, two.filter), "an untapped artifact or creature you control")


func test_counters_a_player_puts_are_worded_with_who_puts_them() -> void:
	# Exemplar of Light: "Whenever you put one or more +1/+1 counters on this creature" (CR 122.6).
	var draw: Array[MmEffect] = [Scenario.draw_cards(1, Scenario.you())]
	var yours: CountersPutTrigger = Scenario.counters_put(null, Whose.ANY, MmCounter.Kind.PLUS_ONE_PLUS_ONE, Whose.YOU)
	var theirs: CountersPutTrigger = Scenario.counters_put(Scenario.of_type(CardType.CREATURE), Whose.YOU,
		MmCounter.Kind.PLUS_ONE_PLUS_ONE, Whose.OPPONENT)

	assert_eq(AbilityText.of_ability(Scenario.once_each_turn(Scenario.triggered(yours, draw)), "this creature"),
		"Whenever you put one or more +1/+1 counters on this creature, draw a card. This ability triggers only once each turn.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(theirs, draw), "Sample"),
		"Whenever an opponent puts one or more +1/+1 counters on a creature you control, draw a card.")


func test_gaining_life_is_worded_for_whose_life() -> void:
	var draw: Array[MmEffect] = [Scenario.draw_cards(1, Scenario.you())]

	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.life_gained(), draw), "this creature"),
		"Whenever you gain life, draw a card.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.life_gained(Whose.OPPONENT), draw), "Sample"),
		"Whenever an opponent gains life, draw a card.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.life_gained(Whose.ANY), draw), "Sample"),
		"Whenever a player gains life, draw a card.")


func test_an_nth_spell_each_turn_is_worded_with_its_ordinal() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]

	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.nth_spell(2), gain), "this creature"),
		"Whenever you cast your second spell each turn, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.nth_spell(3, Whose.OPPONENT), gain), "Sample"),
		"Whenever an opponent casts their third spell each turn, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.nth_spell(2, Whose.ANY), gain), "Sample"),
		"Whenever a player casts their second spell each turn, you gain 1 life.")


func test_a_card_drawn_is_worded_with_whose_and_any_ordinal() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]

	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.draws(2), gain), "this creature"),
		"Whenever you draw your second card each turn, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.draws(3, Whose.OPPONENT), gain), "Sample"),
		"Whenever an opponent draws their third card each turn, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.draws(), gain), "Sample"),
		"Whenever you draw a card, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.draws(0, Whose.ANY), gain), "Sample"),
		"Whenever a player draws a card, you gain 1 life.")


func test_a_spell_cast_during_whose_turn_says_so() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	var theirs: SpellCastTrigger = Scenario.during_turn(Scenario.casts(null, Whose.OPPONENT), Whose.YOU)

	assert_eq(AbilityText.of_ability(Scenario.cutthroat().abilities[0], "this creature"),
		"Whenever you cast a spell during an opponent's turn, you gain 1 life.")
	assert_eq(AbilityText.of_ability(Scenario.triggered(theirs, gain), "Sample"),
		"Whenever an opponent casts a spell during your turn, you gain 1 life.")


func test_an_additional_cost_is_worded_as_oracle_says_it() -> void:
	var isolation: MmCardDefinition = Scenario.isolation()

	assert_eq(AbilityText.of_ability(isolation.abilities[0], "this creature"),
		"As an additional cost to cast this spell, return a permanent you control to its owner's hand.")
	assert_eq(AbilityText.of_card(isolation.abilities, [CardType.CREATURE], [], "Sample"),
		"As an additional cost to cast this spell, return a permanent you control to its owner's hand.\nFlying")


func test_leaving_without_dying_is_worded_one_or_more() -> void:
	assert_eq(AbilityText.of_ability(Scenario.port_mage().abilities[0], "this creature"),
		"Whenever one or more other creatures you control leave the battlefield without dying, you gain 1 life.")


func test_if_you_do_follows_a_you_may() -> void:
	var looter: MmCardDefinition = Scenario.looter()

	assert_eq(AbilityText.of_ability(looter.abilities[0], "this creature"),
		"When this creature enters, you may draw a card. If you do, discard a card.")


func test_you_may_pay_mana_is_worded_with_its_symbols() -> void:
	var paying: MayPayEffect = Scenario.may_pay_mana(Scenario.mana_cost(1), Scenario.gain_life(3, Scenario.you()))

	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [paying]), "this creature"),
		"When this creature enters, you may pay {1}. If you do, you gain 3 life.")


func test_discarding_is_worded_as_drawing_is() -> void:
	var rummage: SpellAbility = SpellAbility.new()
	rummage.effects = [Scenario.discard(), Scenario.discard(2, EachOpponentSelection.new())]

	assert_eq(AbilityText.of_ability(rummage, "Sample"), "Discard a card. Each opponent discards two cards.")


func test_unless_follows_the_effect_it_keeps_from_happening() -> void:
	assert_eq(AbilityText.of_ability(Scenario.doll().abilities[0], "this creature"),
		"When this creature enters, draw a card. Discard a card unless you control another creature with power 2 or less.")


func test_blocking_a_creature_calls_the_attacker_that_creature() -> void:
	var destroy: Array[MmEffect] = [Scenario.destroy(TriggeringObjectSelection.new())]

	assert_eq(AbilityText.of_ability(Scenario.triggered(Scenario.blocks_a_creature(), destroy), "this creature"),
		"Whenever this creature blocks a creature, destroy that creature.", "CR 509.3b")


func test_typecycling_prints_its_type_attached_to_cycling_and_its_cost() -> void:
	var landcycling: CyclingAbility = Scenario.landcycling(Scenario.mana_cost(1, [MmMana.Type.GREEN]))
	var plains: HasSubtypeFilter = HasSubtypeFilter.new()
	plains.subtype = "Plains"
	var plainscycling: CyclingAbility = Scenario.cycling(Scenario.mana_cost(2))
	plainscycling.search = plains

	var text: String = AbilityText.of_ability(landcycling, "Topiary Panther")

	assert_eq(text, "Basic landcycling {1}{G}", "CR 702.29e: what it does is its Reminder.")
	assert_true(AbilityText.is_keyword(landcycling))
	assert_eq(AbilityText.of_ability(plainscycling, "Sample"), "Plainscycling {2}")
	var spelled_out: ActivatedAbility = ActivatedAbility.new()
	spelled_out.mana_cost = Scenario.mana_cost(1, [MmMana.Type.GREEN])
	spelled_out.costs = landcycling.costs
	spelled_out.effects = landcycling.effects
	assert_eq(AbilityText.of_ability(spelled_out, "Topiary Panther"),
		"{1}{G}, Discard this card: Search your library for a basic land card, reveal it, put it into your hand, then shuffle.")


func test_an_activated_ability_can_cost_life() -> void:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = Scenario.mana_cost(1)
	ability.costs = [TapCost.new(), Scenario.pay_life(1)]
	ability.effects = [Scenario.draw_cards(1, Scenario.you())]

	assert_eq(AbilityText.of_ability(ability, "this artifact"), "{1}, {T}, Pay 1 life: Draw a card.")


func test_returning_with_a_counter_says_so() -> void:
	var back: ReturnToBattlefieldEffect = Scenario.return_to_battlefield(ExiledWithSourceSelection.new())
	back.counters = Scenario.constant(1)
	var spell: SpellAbility = SpellAbility.new()
	spell.effects = [back]

	assert_eq(AbilityText.of_ability(spell, "Daydream"),
		"Return the exiled card to the battlefield under its owner's control with a +1/+1 counter on it.")


func test_returning_your_own_card_tapped_leaves_out_its_owner_and_a_mana_value_comes_before_the_graveyard() -> void:
	var helping: SpellAbility = SpellAbility.new()
	helping.targets = [Scenario.target_graveyard_card(Scenario.all_of([Scenario.of_type(CardType.CREATURE), Scenario.mana_value(3),
		Scenario.owned_by(Whose.YOU)]))]
	var back: ReturnToBattlefieldEffect = Scenario.return_to_battlefield(Scenario.targeted(0))
	back.tapped = true
	helping.effects = [back]
	var anyones: SpellAbility = SpellAbility.new()
	anyones.targets = [Scenario.target_graveyard_card(Scenario.of_type(CardType.CREATURE))]
	var tapped_with_counter: ReturnToBattlefieldEffect = Scenario.return_to_battlefield(Scenario.targeted(0))
	tapped_with_counter.tapped = true
	tapped_with_counter.counters = Scenario.constant(1)
	anyones.effects = [tapped_with_counter]
	var untapped: SpellAbility = SpellAbility.new()
	untapped.targets = [Scenario.your_dead_creature()]
	untapped.effects = [Scenario.return_to_battlefield(Scenario.targeted(0))]

	assert_eq(AbilityText.of_ability(helping, "Helping Hand"),
		"Return target creature card with mana value 3 or less from your graveyard to the battlefield tapped.")
	assert_eq(AbilityText.of_ability(anyones, "Sample"),
		"Return target creature card from a graveyard to the battlefield tapped under its owner's control with a +1/+1 counter on it.")
	assert_eq(AbilityText.of_ability(untapped, "Sample"), "Return target creature card from your graveyard to the battlefield.")


func test_a_power_filter_is_worded_after_its_noun() -> void:
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var greater: PowerFilter = Scenario.power(3, PowerFilter.Comparison.OR_GREATER)

	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.power(2)])), "creatures with power 2 or less")
	assert_eq(AbilityText.things(Scenario.all_of([creature, greater])), "creatures with power 3 or greater")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.is_not(greater)])), "creatures with power 2 or less",
		"Not 3 or greater is 2 or less.")



func test_a_toughness_filter_is_worded_after_its_noun() -> void:
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var greater: ToughnessFilter = Scenario.toughness(4, ToughnessFilter.Comparison.OR_GREATER)

	assert_eq(AbilityText.things(Scenario.all_of([creature, greater])), "creatures with toughness 4 or greater")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.toughness(2)])), "creatures with toughness 2 or less")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.is_not(greater)])), "creatures with toughness 3 or less",
		"Not 4 or greater is 3 or less.")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.is_not(Scenario.toughness(2))])),
		"creatures with toughness 3 or greater")


func test_a_bound_from_a_value_is_worded_inline_and_the_x_paid_as_x() -> void:
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var domain_or_greater: ToughnessFilter = Scenario.toughness_from(Scenario.domain(), ToughnessFilter.Comparison.OR_GREATER)

	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.is_not(domain_or_greater)])),
		"creatures with toughness less than the number of basic land types among lands you control")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.toughness_from(Scenario.domain())])),
		"creatures with toughness less than or equal to the number of basic land types among lands you control",
		"A number in words is not followed by \"or less\".")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.toughness_from(Scenario.constant(2))])),
		"creatures with toughness 2 or less")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.toughness_from(Scenario.paid_x())])),
		"creatures with toughness X or less")
	assert_eq(AbilityText.things(Scenario.all_of([creature,
		Scenario.is_not(Scenario.mana_value_from(Scenario.domain(), ManaValueFilter.Comparison.OR_GREATER))])),
		"creatures with mana value less than the number of basic land types among lands you control")


func test_zar_ojanens_ability_is_worded_as_printed_without_its_ability_word() -> void:
	var scion: MmCardDefinition = Scenario.scion()

	assert_eq(AbilityText.of_ability(scion.abilities[0], "this creature"),
		"Whenever this creature becomes tapped, put a +1/+1 counter on each creature you control with toughness less "
		+ "than the number of basic land types among lands you control.")

func test_looking_at_and_casting_from_the_top_of_the_library_are_worded_as_printed() -> void:
	var look: LookAtTopOfLibraryAbility = LookAtTopOfLibraryAbility.new()
	var any_spell: CastFromTopOfLibraryAbility = CastFromTopOfLibraryAbility.new()

	assert_eq(AbilityText.of_ability(look, "Assemble the Players"), "You may look at the top card of your library any time.")
	assert_eq(AbilityText.of_ability(Scenario.cast_from_top(), "Assemble the Players"),
		"Once each turn, you may cast a creature spell with power 2 or less from the top of your library.")
	assert_eq(AbilityText.of_ability(any_spell, "Sample"), "Once each turn, you may cast a spell from the top of your library.")


func test_a_mana_value_filter_is_worded_after_its_noun() -> void:
	var greater: ManaValueFilter = Scenario.mana_value(4, ManaValueFilter.Comparison.OR_GREATER)
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)

	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.mana_value(2)])), "creatures with mana value 2 or less")
	assert_eq(AbilityText.things(Scenario.all_of([creature, greater])), "creatures with mana value 4 or greater")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.is_not(greater)])), "creatures with mana value 3 or less",
		"Not 4 or greater is 3 or less.")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.is_not(Scenario.mana_value(2))])),
		"creatures with mana value 3 or greater")


func test_a_mana_value_filter_from_a_value_is_worded_with_its_number_or_x() -> void:
	var creature: MmFilter = Scenario.of_type(CardType.CREATURE)
	var x_or_less: ManaValueFilter = Scenario.mana_value_from(Scenario.paid_x())

	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.mana_value_from(Scenario.constant(3))])),
		"creatures with mana value 3 or less")
	assert_eq(AbilityText.things(Scenario.all_of([creature, x_or_less])), "creatures with mana value X or less")
	assert_eq(AbilityText.things(Scenario.all_of([creature,
		Scenario.mana_value_from(Scenario.paid_x(), ManaValueFilter.Comparison.OR_GREATER)])), "creatures with mana value X or greater")
	assert_eq(AbilityText.things(Scenario.all_of([creature, Scenario.is_not(x_or_less)])), "creatures with mana value greater than X",
		"X can't have 1 taken off in words, so not X or less is greater than X.")
	var seeking: SearchLibraryEffect = Scenario.search(Scenario.all_of([Scenario.has_subtype("Equipment"), x_or_less]), 1,
		MmZone.Kind.BATTLEFIELD, false)
	var seeker: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.pay_x(seeking)])
	assert_eq(AbilityText.of_ability(seeker, "this creature"), "When this creature enters, you may pay {X}. If you do, "
		+ "search your library for an Equipment card with mana value X or less, put it onto the battlefield, then shuffle.")


func test_surveil_is_worded_with_its_number_and_no_reminder() -> void:
	var expected: Dictionary[String, MmAbility] = {
		"When this creature enters, surveil 1.": Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.surveil(1)]),
		"When this creature dies, surveil 1.": Scenario.triggered(Scenario.dies(IsSourceFilter.new()), [Scenario.surveil(1)]),
		"Surveil 2.": _spell_doing(Scenario.surveil(2)),
	}
	for text: String in expected:
		assert_eq(AbilityText.of_ability(expected[text], "this creature"), text, "CR 701.25a, without its reminder text.")


func test_scry_is_worded_with_its_number_and_no_reminder() -> void:
	var expected: Dictionary[String, MmAbility] = {
		"When this creature enters, scry 1.": Scenario.seer().abilities[0],
		"Scry 2.": _spell_doing(Scenario.scry(2)),
	}
	for text: String in expected:
		assert_eq(AbilityText.of_ability(expected[text], "this creature"), text, "CR 701.22a, without its reminder text.")


func test_artifact_legendary_or_saga_is_historic() -> void:
	# CR 700.6, as Artificer's Assistant words it.
	var legendary: HasSupertypeFilter = HasSupertypeFilter.new()
	legendary.supertype = MmCardTypes.Supertype.LEGENDARY
	var saga: HasSubtypeFilter = HasSubtypeFilter.new()
	saga.subtype = "Saga"
	var historic: AnyOfFilter = AnyOfFilter.new()
	historic.filters = [saga, Scenario.of_type(CardType.ARTIFACT), legendary]
	var scries: TriggeredAbility = Scenario.triggered(Scenario.casts(historic, Whose.YOU), [Scenario.scry(1)])

	assert_eq(AbilityText.of_ability(scries, "this creature"), "Whenever you cast a historic spell, scry 1.")
	historic.filters = [saga, Scenario.of_type(CardType.ARTIFACT)]
	assert_ne(AbilityText.of_ability(scries, "this creature"), "Whenever you cast a historic spell, scry 1.", "Not without legendary.")


func _spell_doing(effect: MmEffect) -> SpellAbility:
	var spell: SpellAbility = SpellAbility.new()
	spell.effects = [effect]
	return spell


func test_fight_is_worded_without_its_reminder() -> void:
	var spell: MmAbility = Scenario.free_fight().abilities[0]

	assert_eq(AbilityText.of_ability(spell, "this spell"), "Target creature you control fights target creature you don't control.",
		"CR 701.14a, without its reminder text.")


func test_sacrificing_its_source_is_a_cost_named_as_the_source_calls_itself() -> void:
	var ability: MmAbility = Scenario.parcel().abilities[0]

	assert_eq(AbilityText.of_ability(ability, "this artifact"),
		"{0}, {T}, Sacrifice this artifact: This artifact deals 4 damage to target creature.", "CR 701.21a")


func test_players_who_control_more_are_worded_with_the_verb_agreeing() -> void:
	var lands: MmFilter = Scenario.of_type(MmCardTypes.CardType.LAND)
	var plains: SearchLibraryEffect = Scenario.search(Scenario.has_subtype("Plains"))
	plains.amount = Scenario.players_who_control_more(lands)
	var explorer: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [plains])
	var drained: LoseLifeEffect = LoseLifeEffect.new()
	drained.amount = Scenario.constant(1)
	drained.players = Scenario.each(Scenario.controls_more(lands))

	assert_eq(AbilityText.of_ability(explorer, "this creature"), "When this creature enters, search your library for up to X "
		+ "Plains cards, reveal them, put them into your hand, then shuffle, where X is the number of players who control "
		+ "more lands than you.")
	assert_eq(AbilityText.of_ability(_spell_doing(drained), "this spell"),
		"Each player who controls more lands than you loses 1 life.")


func test_mill_from_among_them_and_a_graveyard_count_are_worded_as_oracle_does() -> void:
	# Engine ADR 0080, after Most Decrepit Old Bird // Speak Secrets.
	assert_eq(_text(Scenario.threshold_bird()), "This creature gets +1/+1 as long as there are seven or more cards in your graveyard.")
	assert_eq(_text(Scenario.free_secrets()), "Mill four cards. Put an instant or sorcery card from among them into your hand.")
	assert_eq(_text(Scenario.free_mill("Glimpse", 1)), "Mill a card.")
	assert_eq(_text(Scenario.free_mill("Thought Scour", 2, true)), "Each opponent mills two cards.")


func test_a_count_of_permanents_you_control_as_a_condition_says_you_control_them() -> void:
	# After Gearsmith Prodigy: "This creature gets +1/+0 as long as you control an artifact."
	var artifact: HasCardTypeFilter = Scenario.of_type(MmCardTypes.CardType.ARTIFACT)
	var one: MmCardDefinition = Scenario.creature("Prodigy", 1, 2, [Scenario.continuous_static(
		[Scenario.modify_pt(1, 0, SourceSelection.new())], Scenario.at_least(Scenario.count_yours(artifact), 1))])
	var three: MmCardDefinition = Scenario.creature("Smith", 1, 2, [Scenario.continuous_static(
		[Scenario.modify_pt(2, 2, SourceSelection.new())], Scenario.at_least(Scenario.count_yours(artifact), 3))])

	assert_eq(_text(one), "This creature gets +1/+0 as long as you control an artifact.")
	assert_eq(_text(three), "This creature gets +2/+2 as long as you control three or more artifacts.")


func _text(definition: MmCardDefinition) -> String:
	return CardLook.of_definition(definition).rules_text
