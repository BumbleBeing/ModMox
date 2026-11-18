class_name CreatureTypes
extends RefCounted
## Every creature type there is (CR 205.3m), for "choose a creature type". Subtypes on cards
## stay free text (MmCardTypes), so this list says only what may be chosen. It is engine
## data, not Content: the rules define it. `card_tool.gd -- creature-types` rewrites it from
## Scryfall's catalog; a changed list changes what a saved answer means, so it is an engine
## version change (ADR 0010).

## In alphabetical order, as CR 205.3m lists them. A ChooseCreatureTypeDecision's answer is an
## index into this list.
const ALL: Array[String] = [
	"Advisor", "Aenar", "Aetherborn", "Alien", "Ally", "Andorian", "Android", "Angel", "Antelope",
	"Ape", "Archer", "Archon", "Armadillo", "Army", "Artificer", "Assassin", "Assembly-Worker",
	"Astartes", "Atog", "Aurochs", "Automaton", "Avatar", "Azra", "Badger", "Bajoran", "Balloon",
	"Barbarian", "Bard", "Basilisk", "Bat", "Bear", "Beast", "Beaver", "Beeble", "Beholder",
	"Berserker", "Betazoid", "Bird", "Bison", "Blinkmoth", "Boar", "Bolian", "Borg", "Brainiac",
	"Brikar", "Bringer", "Brushwagg", "C'tan", "Caitian", "Camarid", "Camel", "Capybara",
	"Cardassian", "Caribou", "Carrier", "Cat", "Centaur", "Chicken", "Child", "Chimera",
	"Citizen", "Cleric", "Clown", "Cockatrice", "Construct", "Coward", "Coyote", "Crab",
	"Crocodile", "Custodes", "Cyberman", "Cyclops", "Dalek", "Dauthi", "Demigod", "Demon",
	"Denobulan", "Deserter", "Detective", "Devil", "Dinosaur", "Djinn", "Doctor", "Dog", "Dragon",
	"Drake", "Dreadnought", "Drix", "Drone", "Druid", "Dryad", "Dwarf", "Echidna", "Edosian",
	"Efreet", "Egg", "El-Aurian", "Elder", "Eldrazi", "Elemental", "Elephant", "Elf", "Elk",
	"Employee", "Eternal", "Excalbian", "Eye", "Faerie", "Ferengi", "Ferret", "Fish",
	"Flagbearer", "Fox", "Fractal", "Frog", "Fungus", "Gamer", "Gamma", "Gargoyle", "Germ",
	"Giant", "Giraffe", "Gith", "Glimmer", "Gnoll", "Gnome", "Goat", "Goblin", "God", "Golem",
	"Gorgon", "Gorn", "Graveborn", "Gremlin", "Griffin", "Guest", "Hag", "Halfling", "Hamster",
	"Harpy", "Head", "Hedgehog", "Hellion", "Hero", "Hippo", "Hippogriff", "Hirogen", "Homarid",
	"Homunculus", "Horror", "Horse", "Human", "Hydra", "Hyena", "Illusion", "Illyrian", "Imp",
	"Incarnation", "Inhuman", "Inkling", "Inquisitor", "Insect", "Jackal", "Jellyfish",
	"Jem'Hadar", "Juggernaut", "Kangaroo", "Kavu", "Kelpien", "Kirin", "Kithkin", "Klingon",
	"Knight", "Kobold", "Kor", "Kraken", "Kree", "Kwejian", "Lamia", "Lammasu", "Lanthanite",
	"Leech", "Lemur", "Leviathan", "Lhurgoyf", "Licid", "Lizard", "Llama", "Lobster", "Manticore",
	"Masticore", "Medusan", "Melkotian", "Mercenary", "Merfolk", "Metathran", "Mindless-One",
	"Minion", "Minotaur", "Mite", "Mole", "Monger", "Mongoose", "Monk", "Monkey", "Moogle",
	"Moonfolk", "Mount", "Mouse", "Mutant", "Myr", "Mystic", "Na'kuhl", "Naga", "Nautilus",
	"Necron", "Nephilim", "Nightmare", "Nightstalker", "Ninja", "Noble", "Noggle", "Nomad",
	"Nymph", "Ocampa", "Octopus", "Officer", "Ogre", "Ooze", "Orb", "Orc", "Orgg", "Orion",
	"Otter", "Ouphe", "Ox", "Oyster", "Pangolin", "Peasant", "Pegasus", "Pentavite", "Performer",
	"Pest", "Phelddagrif", "Phoenix", "Phyrexian", "Pilot", "Pincher", "Pirate", "Plant",
	"Platypus", "Porcupine", "Possum", "Praetor", "Primarch", "Prism", "Processor", "Q", "Qu",
	"Rabbit", "Raccoon", "Ranger", "Rat", "Rebel", "Reflection", "Reveler", "Rhino", "Rigger",
	"Robot", "Rogue", "Romulan", "Rukh", "Sable", "Salamander", "Samurai", "Sand", "Saproling",
	"Satyr", "Scarecrow", "Scientist", "Scion", "Scorpion", "Scout", "Sculpture", "Seal", "Serf",
	"Serpent", "Servo", "Shade", "Shaman", "Shapeshifter", "Shark", "Sheep", "Shi'ar", "Siren",
	"Skeleton", "Skrull", "Skunk", "Slith", "Sliver", "Sloth", "Slug", "Snail", "Snake",
	"Soldier", "Soltari", "Sorcerer", "Spawn", "Specter", "Spellshaper", "Sphinx", "Spider",
	"Spike", "Spirit", "Splinter", "Sponge", "Spy", "Squid", "Squirrel", "Starfish", "Surrakar",
	"Survivor", "Symbiote", "Synth", "Talaxian", "Talosian", "Tamarian", "Teddy", "Tellarite",
	"Tentacle", "Tetravite", "Thalakos", "Tholian", "Thopter", "Thrull", "Tiefling", "Time Lord",
	"Tosk", "Toy", "Treefolk", "Tribble", "Trill", "Trilobite", "Triskelavite", "Troll", "Turtle",
	"Tyranid", "Unicorn", "Urzan", "Utrom", "Vampire", "Varmint", "Vau-N'Akat", "Vedalken",
	"Villain", "Volver", "Vorta", "Vulcan", "Wall", "Walrus", "Warlock", "Warrior", "Weasel",
	"Weird", "Werewolf", "Whale", "Wizard", "Wolf", "Wolverine", "Wombat", "Worm", "Wraith",
	"Wurm", "Xindi", "Yeti", "Zombie", "Zubera",
]


## Whether [param subtype] is a creature type.
static func is_creature_type(subtype: String) -> bool:
	return ALL.has(subtype)
