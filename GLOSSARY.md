# ModMox Game

The roguelike RPG around the rules engine: runs, characters, and everything that happens between encounters.

## Language

**Content**:
The Card Definitions authored for the game and shipped with it, such as the Alpha cards. The rules engine never contains or depends on Content.
_Avoid_: Card database, card pool, assets

**Oracle Data**:
A real Magic card's current official characteristics and rules text, as Scryfall gives them, which that card's Card Definition starts from. It has nothing to do with the AI's Combat Oracle.
_Avoid_: Scryfall data, card data, printed text

**Rebalance**:
A deliberate change to a Card Definition away from its Oracle Data, made for the game's balance, such as a new rarity or cost.
_Avoid_: Deviation, nerf, buff, errata (Wizards' own change to Oracle text)

**Frame**:
The layered image a card is drawn on, worked out from its characteristics: a frame for its color category (a land's follows the colors of mana it can produce), a power/toughness box if it is a creature, and a crown if it is legendary. A colored artifact keeps its colors' frame, box and crown inside the artifact frame's silver border.
_Avoid_: Card background, border, template

**Status**:
A lasting condition on the Hero's character that holds one or more Starting Conditions. A Named Hero comes with its own, which the player cannot change; for the Custom Hero the player picks any number on Choose your Hero, a Boon only once an Achievement has unlocked it. A Status may also bar Armor Slots, and each one may also raise or lower, by a percentage, the gold a won run puts in the Vault: as a rule an Affliction raises it and a Boon lowers it. A Status is never used up; what is used up is a Potion. What does the same to an encounter but is bought, sold, put on and taken off is an Armor.
_Avoid_: Trait, perk, buff, condition

**Starting Condition**:
One change to how the Hero starts an encounter: more or less starting life, a smaller opening hand, an extra free mulligan, or an Emblem that is theirs for that encounter. A Status holds one or more, and so does an Armor, whose Starting Conditions count only while it is Worn.
_Avoid_: Condition (alone), effect (a rules term), bonus, modifier

**Boon**:
A Status that helps the Hero, such as an extra free mulligan.
_Avoid_: Blessing, perk

**Affliction**:
A Status that hinders the Hero, such as Forgetful (opening hand one card smaller).
_Avoid_: Curse, debuff

## Runs

**Run**:
One attempt at the game, from Choose your Hero to Run Won or Run Lost: five Stages, one per Tier, played while Hearts last. Its end screens call it a trial, their titles reading "Trial won" and "Trial lost"; the two words mean the same thing, and every other term keeps "run".
_Avoid_: Game (an encounter is a game of Magic), playthrough, session

**Tier**:
One of a run's five steps of difficulty, each offering one Stage of every color. A run plays one Stage per Tier and never the same color twice. Each Tier's Stage is rolled from the Run Seed among the colors not yet played; the Hero never chooses it.
_Avoid_: Level, act, round

**Stage**:
One section of a run, of one color at one Tier and ending in a Boss, which sets the Backdrop of its encounters. Each has a name, shown with its Tier and its Boss when the Hero enters it. There are 25 in all.
_Avoid_: Level, act, world, biome

**Stage Intro**:
The screen that opens a Stage before its Stage Map: the Stage's name, its Tier and its Boss, who is introduced here, on a ground of the Stage's own color.
_Avoid_: Cutscene, title card, splash

**Tier Track**:
The row of five medallions on the Stage Intro, one for each Tier: each Stage already played shows its color, the one being entered is lit, and those ahead are empty.
_Avoid_: Tier graphic, progress bar, breadcrumbs

**Node**:
One stop on a Stage's map. Its kind is one of Start Node, Store, Workshop, Trove, Lesser Encounter, Elite Encounter, Boss Encounter or Chaos Node.
_Avoid_: Event (an engine term for a change to the game), room, space

**Stage Map**:
The map of a Stage's Nodes and the links between them, and the screen that shows it, where the Hero chooses which Node to go to next. The Hero moves one link at a time and must play an encounter before moving on.
_Avoid_: Stage Navigation, navigation screen, world map, overworld

**Map View**:
The overlay that shows a Stage Map whole: its shape, every Node and the Path walked so far. The Stage Map itself shows only the Hero's row and the two rows ahead.
_Avoid_: Minimap, full map, overview

**Map Backdrop**:
The one picture behind a Stage's Stage Map, belonging to that Stage alone: as wide as the screen and as tall as the whole map, pixel art drawn six screen pixels to each of its own, never tiled and never dimmed. It scrolls with the map, so the Nodes sit on its ground. A Stage without one shows the plain slate.
_Avoid_: Background, map background, Backdrop (the picture behind an encounter, one for each color)

**Scenery**:
The sprites placed at random over a Stage's Map Backdrop, such as mountains, trees and creatures, some still and some animated, of many sizes, their pixels finer or coarser than the Backdrop's so they stand apart from it. Each Stage lists its own Scenery Kinds, rules keep the pieces on its Scenery Ground and clear of the Nodes, the links and each other, and where they fall comes from the Run Seed.
_Avoid_: Decorations, props, doodads

**Scenery Kind**:
One kind of Scenery a Stage can have, such as Kitty Keep's tree or its cat: its picture, or the frames it loops through, the size of its pixels, and how many of it are placed.
_Avoid_: Scenery type, prop definition

**Scenery Ground**:
Where a Stage's Scenery may stand: a mask the size of its Map Backdrop, painted over the meadow and left clear over what Scenery must keep off, such as Kitty Keep's castle and sky.
_Avoid_: Mask, placement area, spawn zone

**Scenery Piece**:
One Scenery Kind placed on one Stage Map, at a spot of its own and perhaps facing the other way.
_Avoid_: Scenery object, instance, decoration

**Path**:
Any walk the Hero could take across a Stage Map from the Node they stand on: forward along links, either way along a link between Nodes of the same row, and never back to a Node already visited.
_Avoid_: Route, lane, branch

**Start Node**:
The Node a Stage begins on, where nothing happens.
_Avoid_: Blank node, entrance

**Lesser Encounter**, **Elite Encounter**, **Boss Encounter**:
A Node that is an encounter with a Villain of that Rank. Every Stage ends on its one Boss Encounter.
_Avoid_: Fight, battle, boss node

**Store**:
A Node that sells nine goods for gold, most of them cards from its Tier's Store Pool and the rest Potions and Armor, and buys those kinds at a third of the price it sells at. What it stocks is set when the Hero arrives and is never restocked. Some of its cards already carry Mods, which raise their price, or Hexes, which lower it. Every Stage has one right after its Start Node and one right before its Boss Encounter.
_Avoid_: Shop, merchant, vendor

**Workshop**:
A Node that sells Mods for gold, buys every Item that is not a card (Mods, Potions and Armor) at a third of the price a shop sells it at, and offers Removal and one Duplication each visit. What it stocks is set when the Hero arrives and is never restocked. Every Stage has one right after its Start Node and one right before its Boss Encounter.
_Avoid_: Forge, smith, mod shop

**Duplication**:
The Workshop's making of an exact second Run Card of a card in the Collection, its Mods and Hexes included, for what a Store would charge for that card as it is. The new Run Card joins the Collection but no Deck. A Power-9 card, a card with a Unique Mod and a plain basic land cannot be duplicated.
_Avoid_: Copy (a rules term), clone, forging

**Removal**:
The Workshop's taking of one Mod or Hex off a card in the Collection, for one flat price, the same for either. A removed Mod goes back into the Satchel; a removed Hex is gone.
_Avoid_: Unmodding, stripping, Mod removal service

**Trove**:
The Node that follows an Elite Encounter and offers three Items, of which the Hero takes one. The Hero reaches it whether the Elite Encounter was won or lost, and it is never found anywhere else.
_Avoid_: Treasure node, chest

**Chaos Node**:
The Node that holds a Twist, drawn when the Hero arrives. It never counts as an encounter when a Stage's map is laid out.
_Avoid_: Mystery Node, event node, Event (an engine term for a change to the game)

**Twist**:
What a Chaos Node holds: a Dilemma or a Gamble, one of those authored for the game. It may give or take almost anything the Hero has, such as gold, Hearts, cards, Items, or a Mod or Hex on a card. No Twist comes up twice in one run.
_Avoid_: Event (an engine term for a change to the game), encounter (an encounter is with a Villain), Phenomenon (a Magic card type)

**Dilemma**:
A Twist that offers two or three choices whose outcomes are stated, with nothing left to chance. It may force a choice, though most let the Hero walk away.
_Avoid_: Choice event, mode (a rules term)

**Gamble**:
A Twist whose outcome is left to chance. Its odds are never shown: its words hint at how risky it is. The Hero can always decline it.
_Avoid_: Bet, wager, roll

**Rank**:
How dangerous a Villain is where it is met: Lesser, Elite or Boss. A Stage says which Villains it has at each Rank, so Rank belongs to the meeting, not to the Villain. The Rank decides how many cards the Spoils pay, and the Rank with the Stage's Tier how much gold.
_Avoid_: Difficulty (AI Difficulty is the one global setting for how hard every Villain thinks), level, class

**Encounter Reveal**:
The screen that opens when the Hero arrives at an encounter, before the Deckbox. A short animation reveals which Villain it is and comes to rest on a still of the Hero against the Villain. From that still the Hero can open the Satchel, or start the encounter, which opens the Deckbox with its Start button.
_Avoid_: Versus screen, matchup screen, Stage Intro (the screen that opens a Stage)

**Spoils**:
What the Hero wins for beating a Villain: gold and cards, and now and then an Item, which a Boss always pays. They are paid the moment the win is counted and the Hero takes all of them; the Spoils screen only shows what was won. How many cards follows the Villain's Rank (a Lesser Villain pays 1 to 3, mostly 1, an Elite 1 to 3 more evenly, a Boss 2 or 3), and how much gold its Rank and the Tier. The cards are drawn evenly from the copies in the Villain's own deck at that Tier, never its basic lands, so their quality is whatever that deck holds. A loss pays nothing.
_Avoid_: Loot, rewards, drops

**Item**:
Anything the Hero holds between encounters and can buy, sell or win other than a card: a Mod, a Potion or an Armor.
_Avoid_: Gear, equipment (an Equipment is a card), inventory object

**Potion**:
An Item that is used up when it is used. It is used only in the middle of an encounter, never between them, and does there what a spell would, such as "gain 2 life" or "each opponent discards a card". A Potion has no mana cost, and has a Rarity and a Potion Icon. The Hero's panel counts them on its Potions button, which glows while one could be used, is purple with any and gray with none, and opens the Potions window, where a click on a Potion uses it. Whatever is gone for good once used is a Potion and never an Emblem: an Emblem's ability is static or triggered, or can be activated, sometimes only once each game, and the Emblem itself stays (A491 to A493). The only Potion so far is a mock, Big Gulp: "Target creature gets +2/+2 until end of turn."
_Avoid_: Consumable, single-use Emblem, single-use Boon, charge

**Held**:
Said of what a player has in an encounter that is not a card: their Emblems and their Potions. The code that treats the two alike is named for it (`HeldState`, `HeldWindows`, a "held entry"). The engine has no word for the pair: there they are objects in the command zone.
_Avoid_: Command object, non-card, Item (only a Potion is one); and "held card", which is a Drag Card

**Potion Icon**:
A Potion's picture: a 32 × 32 pixel icon on a raised plate in its Rarity's color, shown on its entry in the Satchel and in the Potions window, on its ability's entry in the Stack Window, and enlarged in the Inspector. A Potion without one shows a plain bottle.
_Avoid_: Potion art, potion sprite, potion card

**Mod**:
An Item the Hero holds (a Hex aside) and can apply, in the deckbuilder only, to a card to change it for the rest of the run. It has a name, an Augmentation, a Mod Cost, a Rarity and the card types it accepts. Applied, its Augmentation and Mod Cost become that Run Card's Modifications, the rules engine's word for the changes themselves. Applying one is final the moment it is confirmed, and it fills one of the card's Mod Slots. A Mod is applicable to a card that has an empty Mod Slot and has any of the Mod's card types as it reads now, after the Mods already on it, a basic land included; a Mod may add a rule of its own, such as needing a mana cost. The same Mod may go on one card more than once, each copy adding its whole Augmentation and Mod Cost, unless the Mod is once per card, as every Unique one is. What a Mod does is written out from its Augmentation and Mod Cost, never by hand, wherever it is shown off a card. Its name becomes part of the card's Modded Name.
_Avoid_: Modification (the engine's term), upgrade, enchantment

**Hex**:
A Mod that harms the card it is on. It has everything a Mod has, and its Augmentation may be a downside, such as "this enters tapped". The Hero never holds or applies one: it arrives already on a card, and takes one of that card's three Mod Slots.
_Avoid_: Curse, bad mod, downgrade

**Augmentation**:
What a Mod does to the card it is on, such as "+1/+1 and trample": one or more changes to its characteristics or abilities. A Hex's may be a downside.
_Avoid_: Effect (a rules term), bonus, stats

**Mod Cost**:
What a Mod adds to the cost of casting the card it is on: mana symbols, each a fixed color or generic, or an additional cost such as sacrificing a creature, discarding a card or paying life. A Mod that accepts lands has none, and every other Mod has one. A downside that is not paid as the card is cast belongs in the Augmentation.
_Avoid_: Price (what the Workshop charges), tax, upkeep

**Omni Mod**:
A Mod that accepts every card type, lands included, such as one that gives cycling. Like any Mod that accepts lands, it has no Mod Cost.
_Avoid_: Universal Mod, any-card Mod

**Modded Name**:
What a card with Mods or Hexes is called: the name of each one on it, in alphabetical order of the Mods' and Hexes' names together, in front of the card's own, whose capitalization never changes. A Grizzly Bears with the Mod Violent is Violent Grizzly Bears. A Mod on the card twice is named once with Very in front, and three times with Extremely: Very Violent Grizzly Bears, Extremely Violent Grizzly Bears. Very and Extremely stand right in front of their Mod's name and play no part in the order: a Plains with Ancient once and Violent twice is Ancient Very Violent Plains. An effect that asks for cards "originally named" something goes by the Original's name, so a Violent Charmed Stray is still originally named Charmed Stray.
_Avoid_: Prefix, title, nickname

**Mod Slot**:
One of the three places a card has for Mods, Hexes included. A basic land has them too.
_Avoid_: Mod pip, socket, upgrade slot

**Mod Icon**:
A Mod's picture: a 32 × 32 pixel cog, the same for every Mod, in its Rarity's color: gray, silver, gold, orange and light purple. Rare's and Mythic's have a sheen, a bright band across the cog that deepens on either side, gold to bronze and orange to red; the others are flat. It has no ground of its own: it is drawn straight on the parchment, as an Armor Icon is, since the cog is its Rarity's color itself. It is shown wherever a Mod is held or offered as an Item: on its entry in the Satchel, at a Trove and at a Workshop, and on its tile in the Modify Window, where it turns, a quarter turn clockwise every three seconds as the Logo's cogs do, if the Mod can go on the card, and is darkened and still if not. A Mod on a card shows in its Mod Slot instead, never as the cog, and a Hex, which is never held, has no Mod Icon.
_Avoid_: Mod art, mod sprite, cog (the shape, not the term), Mod Slot (the place on a card, not the picture)

**Armor**:
An Item the Hero wears. Each Armor is a Helm, Cuirass or Greaves, and fills the Armor Slot of that name. It holds one or more Starting Conditions, as a Status does, and they count only while it is Worn: the two share one system and differ only in how they are come by. A Status is picked on Choose your Hero and lasts the run; an Armor is won, bought and sold, and put on or taken off between encounters, in the Satchel, as often as the Hero likes. Held but not Worn, it does nothing. It has an Armor Icon and no Rarity, though Armor is the scarcest and most valuable kind of Item.
_Avoid_: Gear, equipment (an Equipment is a card), armor type (a Helm, Cuirass or Greaves is told by its Armor Slot)

**Armor Slot**:
One of the Hero's three places for Armor: Helm, Cuirass and Greaves. Each holds one Armor of its own kind at a time. A Status can bar one or more of them, a Named Hero's own Status included. A **Barred** Armor Slot holds nothing and is drawn under a red X; an Armor for it can still be held and sold, but not put on.
_Avoid_: Armor type, equipment slot, Mod Slot (a card's place for a Mod); for Barred: blocked (a rules term), locked, disabled

**Worn**:
Said of an Armor that is in its Armor Slot. An Armor is put on and taken off, and only a Worn one does anything.
_Avoid_: Attached (a rules term, for an Aura or an Equipment), equipped (equip is a rules keyword), active

**Armor Icon**:
An Armor's picture: a 32 × 32 pixel icon, shown on its entry in the Satchel and in its Armor Slot while it is Worn. It has no ground of its own: on its entry it is drawn straight on the parchment, and in its Armor Slot on the slot's dark square. A Potion Icon, unlike it, stands on its Rarity's plate. An empty Armor Slot shows a faint outline of a helm, cuirass or greaves in its place.
_Avoid_: Armor art, armor sprite, Armor Slot (the place, not the picture)

**Heart**:
One of the losses a run can survive. Losing an encounter costs one, and a Twist may cost one or give one back. The run is lost when none are left.
_Avoid_: Life (a rules term), health, HP

**Starting Pool**:
The cards a run's first Collection is dealt from, authored and divided into the five colors, colorless cards, multicolored cards and lands, never a basic land; a multicolored card is in the multicolored group, whatever its colors. The deal is semi-random: about a third of it is of the Hero Color, and the rest is spread over the other groups. Achievements can add cards to it, some of them new and powerful.
_Avoid_: Starter deck, card pool, starting collection

**Store Pool**:
The cards a Store's stock is drawn from: one for each Tier, authored apart from the Starting Pool and not divided by color, so a Store's cards favor no color, the Hero's included. It never holds a basic land.
_Avoid_: Shop pool, store list, card pool

**Achievement**:
A goal met across runs, kept in the Profile, shown in the Gallery. Some add cards to the Starting Pool or unlock a Boon; nothing an Achievement unlocks is sold in the Bazaar.
_Avoid_: Trophy, unlock, milestone (a roadmap term)

**Choose your Hero**:
The screen a new run starts on, where the player chooses the Hero to play as: a Named Hero or the Custom Hero.
_Avoid_: Hero Selection, character select, Hero screen

**Named Hero**:
A Hero that is a Magic planeswalker, offered on Choose your Hero. Its name, its Hero Color, its Portrait and its Statuses are its own, and the player changes none of them. Some of its Statuses are no one else's, and one may bar Armor Slots.
_Avoid_: Character, class, preset

**Custom Hero**:
The Hero the player makes on Choose your Hero. The player gives its name and, alone among Heroes, chooses its Hero Color, or none, and the Statuses it takes. Its Portrait is one of a set kept for Custom Heroes, some of them drawn after planeswalkers, so a Named Hero may share its Portrait with that set.
_Avoid_: Custom character, blank Hero, player-made Hero

**Hero Color**:
The one color of mage the Hero plays as. A Named Hero's is its own; the Custom Hero's is chosen on Choose your Hero, and may be none. It weights the deal from the Starting Pool toward that color, and with none the deal favors no color; the Hero can still play cards of any color.
_Avoid_: Class, mage type, deck color

**Vault**:
The gold kept between runs: whatever gold the Hero still holds when a run is won goes into it, raised or lowered by the run's Statuses. A lost run puts nothing in it. It is kept in the Profile and spent only in the Bazaar.
_Avoid_: Bank, meta-currency, savings

**Bazaar**:
The store on the main menu where gold from the Vault buys unlocks: new cards and Items for future runs. An unlocked card joins the Store Pool of each Tier it is unlocked for, and never the Starting Pool, which only Achievements add to; an unlocked Item can turn up wherever Items do. Nothing sold here is also an Achievement's reward.
_Avoid_: Meta shop, unlock store, Store (a Node in a run)

**Profile**:
Everything kept between runs: the Vault, the Bazaar's unlocks, the Achievements, the Gallery and the Hints already seen. There is one per installation, kept apart from the saved run, and losing or abandoning a run never touches it.
_Avoid_: Save, account, meta-save

**Tutorial**:
A guided, staged run offered on Choose your Hero: a step-by-step guide to deckbuilding, then a guided visit to a Store and a Workshop, then a staged encounter against a demo Villain with stacked decks and set plays. It uses an authored Collection, keeping only the Hero's name and Portrait from Choose your Hero, ends on a notice that it is complete and returns to the main menu. It leaves nothing behind: no saved run, nothing in the Profile, no Achievements.
_Avoid_: Onboarding, training, first run

**Hint**:
A short note shown once, the first time a screen opens, saying what that screen is for and how it is used. Hints teach the game's screens, never Magic's rules. Those already seen are kept in the Profile, so a later run does not repeat them.
_Avoid_: Tutorial (the guided, staged run), tooltip, coach mark, popup

**Run Won**:
The screen a run ends on when its fifth Boss is beaten, titled "Trial won": the five Stages played, each with its Boss, the gold still held and the Hearts left. It leads to the Credits.
_Avoid_: Victory screen, win screen, Run Won notice (the plain stand-in it replaced)

**Run Lost**:
The screen a run ends on when its last Heart is lost, titled "Trial lost": the Villain that took it, the Stage and Tier where it fell, and the Stages already beaten. It leads to the main menu.
_Avoid_: Game over, defeat screen, death screen

**Run Bar**:
The strip along the Stage Map that shows the Stage, its Tier, the Hearts left and the gold held, with the Satchel button and the Deckbox button.
_Avoid_: HUD, status bar, top bar

**Satchel**:
Where the Hero keeps the Items they hold between encounters, and the window that shows them. The window stands over whatever opened it, which it dims, and cannot be resized. It has three pages, Armor, Mods and Potions, and always opens on Armor. Each page is a scrolling list with one entry for each kind of Item held, saying how many: its picture, its name, what it does and its Rarity (an Armor has none). Beside the pages, whichever is open, stand the Hero's Portrait and their three Armor Slots. A click on an Armor's entry puts it on, in place of any Worn in that Armor Slot, and a click on a filled Armor Slot takes that Armor off; Mods and Potions are only read there. A Worn Armor keeps its entry in the list, marked with a star, and a right-click on it in its Armor Slot opens the Armor page scrolled to that entry, where what it does is read. It has no limit on what it holds. It is opened from a button on the Run Bar, beside the Hearts, the gold and the Deckbox button, from the Encounter Reveal, and from a button at a Store or a Workshop, where Items are sold from it.
_Avoid_: Inventory, bag, Satchel screen (it is a window), Potions window (the encounter's list of Potions)

**Run Seed**:
The single number from which all randomness in a run is derived: each Stage's map, which Villain a Node gives, the Spoils, and every Encounter Seed. A run is exactly replayable from it and the human's choices.
_Avoid_: Random seed, world seed

**Run Log**:
The record a run writes as it goes of every choice the Hero makes, in order, each with the options it was chosen from: the Nodes walked, what is bought and sold, each Removal and Duplication, the Mods applied, the Armor put on and taken off, the Decks saved, every answer given in an encounter, the Villain's as well as the Hero's, and how each encounter ended. With the Run Seed it replays the run exactly, without running the AI. It is kept for the game's makers to study and is never shown in the game.
_Avoid_: History, replay, telemetry, saved run (what Continue resumes)

**Gallery**:
The main menu's record of everything seen across runs, in four pages: Achievements, the Card Encyclopedia (every card collected or seen, with its Modded versions), the Stage Encyclopedia (every Stage and its Villains seen) and the Hall of Fame.
_Avoid_: Hall of Fame (one of its pages), collection (the Collection is a run's cards), Card Gallery (a developer tool)

**Credits**:
The one screen that names who and what made the game: its makers, Godot, and the notice that Magic belongs to Wizards of the Coast. It rolls after a won run, and the main menu opens it too. The artists are named on its Art Attribution page.
_Avoid_: Attributions, about screen, end roll

**Art Attribution**:
The Credits' page that names the artist of every picture the game borrows: each card's art, each Emblem's, and the card art each Portrait was drawn after.
_Avoid_: Art credits, artist list, Credits (the screen it belongs to)

## Decks

**Collection**:
Every Run Card the Hero owns in the run. It alone owns them: a Deck only points at cards in it, so one Run Card can be in several Decks and carries its Mods into each. Two copies of a card are two Run Cards. A basic land is not in it until it takes its first Mod. A card that is sold or lost drops out of every Deck.
_Avoid_: Card pool, inventory, library (a rules term), stash

**Deck**:
A named list of Run Cards from the Collection, each at most once, plus any number of basic lands. Its cards are never stacked or counted as copies: every one is shown and handled as its own card. It is legal at 40 cards or more, with no maximum and no limit on copies. An illegal Deck can be saved, but an encounter cannot be started with one.
_Avoid_: Decklist, loadout, build

**Deckbox**:
The Decks the Hero has saved in the run, and the screen that lists them, sets the Active Deck and is the only way into the deckbuilder. It can be opened from the Stage Map, and it opens from the Encounter Reveal before an encounter, with a Start button that is disabled while the Active Deck is illegal.
_Avoid_: Deck list, deck slots, saved decks

**Active Deck**:
The one Deck in the Deckbox that the Hero takes into encounters.
_Avoid_: Current deck, equipped deck, main deck

**Basic land**:
A land the Hero never has to own: a Deck may hold any number of each type for free. One that takes a Mod stops being free: that copy becomes a Run Card in the Collection with a Modded Name, such as Ancient Plains, and is no longer a free basic land.
_Avoid_: Free land

**Working Deck**:
The unsaved copy of a Deck being edited in the deckbuilder. Saving writes it to the Deckbox; leaving without saving throws it away. Mods applied meanwhile are not part of it and stay applied.
_Avoid_: Draft (a Magic term), deck in progress, scratch deck

**Modify Window**:
The window in the deckbuilder where a held Mod is applied to the selected card, edged in the Steel Rim. It shows every kind of Mod the Hero holds, each with its Mod Icon, the card as it is, and the card as the chosen Mod would make it, and asks once more before applying, because applying is final.
_Avoid_: Mod popup, mod dialog

**Collection Window**:
The window at a Store or a Workshop where a card of the Collection is chosen for a sale, a Removal or a Duplication. It lays the Collection out as the deckbuilder's Collection column does, with an Inspector, marks each card that is in a Deck, grays those it cannot take, and gives the price on the one button that confirms.
_Avoid_: Card picker, sell window, Deckbox (the window of Decks)

**Hall of Fame**:
The read-only copies of Active Decks, Mods included, kept from runs the Hero won. It is a page of the Gallery, and its decks are never played.
_Avoid_: Trophy room, deck archive, history

## Presentation

**Encounter Screen**:
What shows an encounter to the human and takes their answers.
_Avoid_: Battle screen, game view, board

**Backdrop**:
The one picture behind an Encounter Screen, set by the encounter's Stage: 320 × 180 pixels, drawn six screen pixels to each of its own with hard edges, never tiled, and dimmed by the game so the board reads over it. There is one for each color and a plain one with no picture. Until Stages exist the encounter's request names it, and until each has its own art a placeholder is drawn in its place.
_Avoid_: Background (the plain slate behind a screen), wallpaper, scene, biome

**Zone Plate**:
A rounded, mostly see-through gray rectangle behind a row of the battlefield or a pile, which shows where the zone is and sets it off from the Backdrop. Each player's lands and their other permanents have one each, and so has each library, graveyard and exile. The hands have none.
_Avoid_: Panel (see Player Panel), slot, tray, zone box

**Encounter Presenter**:
The one part of the GUI that owns the rules engine for an encounter. It runs the Villain's Agent, takes the Hero's answers, and after every change hands the Encounter Screen a snapshot of what the Hero may see and is being asked.
_Avoid_: Controller, game manager, view model

**Region**:
One rectangle of the Encounter Screen's layout, such as a Player Panel, a row of lands, the Hero's hand, or a library, graveyard or exile pile. No two Regions overlap. The stack is not a Region: see Stack Window.
_Avoid_: Area, zone (a rules term), slot

**Zone Window**:
A window over the Encounter Screen that shows what is in a zone. It can be dragged and resized within the battlefield, scrolls when its contents overflow, is titled with the zone's name and its count, and reopens where it was left. All but the Stack Window can be closed. A player's own zone is titled with their name: "Jackson's Graveyard (5)".
_Avoid_: Popup, dialog, zone viewer

**Pile Window**:
The Zone Window of a pile: a graveyard, an exile or a library. A click on the pile opens it and a second closes it. A graveyard or exile is a grid of Card Faces, the newest card first; a library is one row, its top card on the left, with a card back for each card the Hero does not know. A card in one that a decision can choose glows and is clicked there, and while one can be, its pile glows too. A Pile Window opened to choose a target closes once the target is chosen.
_Avoid_: Zone viewer, graveyard viewer, pile popup

**Player Panel**:
One player's panel in the Encounter Screen's sidebar, the Villain's above the Hero's: their Player Name over their Portrait, with their life total, their mana pool, the Emblems button and a button for each step of the turn. The Hero's also has the Potions button, Undo and Yield Turn; the Villain's says when the Villain is thinking, by name, wrapped to as many lines as it takes. A Player Name too long for its panel glides slowly from one end to the other and back, pausing at each end, for as long as it is shown; one that fits stands still.
_Avoid_: Inspector (that reads a card), player card, sidebar card

**Player Name**:
What a player of an encounter is called on the screen. The Hero's is the name chosen on Choose your Hero. A player given no name goes by their part, "Hero" or "Villain", and only then takes "the" in a sentence: "the Villain's turn", but "Mishra's turn".
_Avoid_: Nickname, handle, display name

**Stack Window**:
The Zone Window for the stack. It is there while something is on the stack or triggers are being put in order, lists what resolves first at the top, and cannot be closed. Each entry has two lines, each cut short with an ellipsis: an ability leads with what it does and a spell with its name, then comes who controls it and what it targets.
_Avoid_: Stack region, stack panel

**Mode Window**:
The window over the battlefield that asks which Mode of a Modal Spell is cast, or of a modal triggered ability the Hero is putting on the stack (game ADR 0047), titled "[spell or source]: choose one". It has an entry for every Mode, each only the card's art and the Mode's words; one that cannot be chosen is dimmed. Pointing at a Mode shows it in full in the Info Panel and marks what it could target. It opens only when two or more Modes can be chosen, and a trigger's offers no Cancel. It is the same window that asks which replacement effect applies first.
_Avoid_: Mode menu, charm picker, choose-one dialog

**Surveil Window**:
The window where the Hero surveils (game ADR 0069), titled "Surveil N" for the number of cards surveilled. It opens by itself left of the piles, three cards wide, with the cards face up in one row, leftmost on top of the library, and "Graveyard" baked into its bottom edge (game ADR 0085); it has no close button. A drag orders the row, a click selects a card (white, the others green), and Graveyard flies the selected card to the Hero's Graveyard pile. Only Done on the Pass Button answers.
_Avoid_: Surveil dialog, scry window, Library window (that shows the whole library)

**Look Window**:
The window where the Hero looks at the top cards of their library and may take one (game ADR 0085), as Militia Bugler has them do, titled "Look at N" for the number of cards looked at. It opens by itself left of the piles, four cards wide, with the cards face up in one row, leftmost on top of the library, and "Hand" baked into its bottom edge; it has no close button. The cards that may be taken glow green; a click selects one (white), and Hand flies it into the hand. There is no dragging. Only Done on the Pass Button answers, and the rest fly face down onto the Library pile.
_Avoid_: Look dialog, dig window, Library window (that shows the whole library)

**Baked Button**:
A window's button set into its bottom edge (game ADR 0085): a strip along the bottom, inside the border, as the title bar runs along the top, exactly as tall as the button, with the button at its middle however the window is resized. The Surveil Window's Graveyard and the Look Window's Hand are Baked Buttons.
_Avoid_: Footer button, window toolbar

**Creature Type Window**:
The window over the battlefield where the Hero chooses a Chosen Creature Type (game ADR 0053), titled "[card]: choose a creature type". A search box at its top has the keyboard as it opens; under it the Hero's own creatures' types are pinned, each just its name, then every other creature type as a compact row. Typing narrows both, names starting with what is typed first, and lights the top match, which Enter chooses; Up and Down move the light. Pointing at a type marks the Hero's creatures of it; the Info Panel only asks "Choose a creature type for [card]". Nothing in it glows, since every type can be chosen.
_Avoid_: Type picker, type dialog, search window

**Stack Color**:
The color a spell or ability has for as long as it is on the stack: one of eight muted hues that leave out the Glow's colors and the Block Lines'. It is on the entry's border and the stripe down its left side, on the arrow to a spell it targets, and on what the entry marks on the board while the cursor is over it.
_Avoid_: Entry tint, stack hue, highlight color

**Stack Mark**:
What the Stack Window entry under the cursor draws on the board, in its Stack Color: a solid border on the source of an ability, which is settled, and a dashed border on each target, which is still to happen. A mark takes the place of the Glow while it is there.
_Avoid_: Hover highlight, preview, target glow

**Hand Strip**:
The Hero's hand as the Encounter Screen draws it: a fanned row of Card Faces along the bottom that parts around the card under the cursor, lights it, and makes room where a Drag Card hovers. It keeps the Hand Order and the Drag Card, carries each card's place across a redraw, and leaves out the cards still flying in until they land. It is told what each card's click would do, and says what the Hero did with a card; it plays nothing itself.
_Avoid_: Hand view, hand row, hand panel

**Villain Hand**:
The Villain's hand as the Encounter Screen draws it: a fan of card backs hanging from the top, one for each card the Villain holds. Like the Hand Strip it keeps its backs across a redraw, so a card that lands in it makes the others ease aside at the same pace, and a drawn card flies to where its back will be at the right end. It takes no clicks.
_Avoid_: Enemy hand, opponent hand, card backs

**Hand Order**:
The order the Hero keeps their hand in, which is theirs alone: cards are dragged along the hand to rearrange it, a new card joins at the right end, and a card that a canceled cast or an undo brings back takes the place it had.
_Avoid_: Hand sort, hand layout, card order

**Drag Card**:
The card of the Hero's hand that is being held with the mouse. It follows the cursor upright above everything; let go above the hand's strip it is played, and let go over the strip it is put down where the other cards made room.
_Avoid_: Hand drag, dragged card, held card, grabbed card

**Face Motion**:
How permanents move on a screen that is rebuilt from every snapshot: it remembers where each one's face was last drawn, and the face eases from there to where it now belongs, in place, size and turn. A permanent that arrives fades in, and one that leaves fades out as a ghost, unless a Card Flight carries it.
_Avoid_: Tween, animation system, transition

**Ghost**:
The fading face of a permanent that has left the battlefield, drawn where it was for a quarter of a second. It takes no clicks and nothing points at it. A permanent that flies to another zone leaves none.

**Card Flight**:
A card drawn in the air on its way from one zone to another, in place of fading out in one place and in at another. It starts where the card was drawn and lands where it now belongs, over every window, and what it lands on shows nothing of it until it arrives. A card that passes through a zone on the way makes one flight. Cards a player draws together fly one after another, and each joins the hand when it lands. A Tucked Card also flies though it changes no zone: to its Pile Window and back, and to its pile once its permanent has gone.

**Flight Card**:
The card drawn for a Card Flight. It is drawn as what the card was where it left and as what it is where it lands, one fading into the other: a Card Face becomes a Battlefield Face, and a card back turns face up. At the Stack Window, which shows an entry and no card, it flies to the entry's art and fades out, or fades in there.
_Avoid_: Corpse, death animation, afterimage

**Flight Layer**:
The layer of the Encounter Screen, over every window, where Card Flights are drawn, and the one place they are worked out: it puts each card that changed zones in the air from where it was drawn, aims it at where it now belongs, draws its Flight Card every frame, and says when it has landed. It asks the screen where a zone is drawn and touches nothing else on it; what a card lands on shows nothing while it is in the air.
_Avoid_: Flight director, flight manager, animation layer

**Pacing**:
The wait before the Villain's next answer is shown, so the Hero can read the last one: at the Blazing Game Speed, half a second after an action, about a quarter after tapping for mana, and none after a pass that showed nothing. Thinking counts toward it. A step of the turn is also shown for at least a tenth of a second, again at Blazing, before the game leaves it, whoever is passing. And nothing leaves the stack sooner than the Hangtime after it was first shown there.

**Hangtime**:
The least time a spell or ability, either player's, cast, activated or triggered, is shown on the stack before it resolves or otherwise leaves: half a second at the Blazing Game Speed, twice the time a land takes to tap. It holds back only what would take something off the stack, so the Villain thinks during it and a pass that resolves nothing is made at once.
_Avoid_: Stack delay, resolve delay

**Game Speed**:
The setting that scales every wait, move, Card Flight and fade of an encounter together: Slow, Normal, Fast or Blazing. Normal takes twice as long as Blazing, Fast one and a half times as long, and Slow three times as long. It is chosen in the Pause Menu's settings and kept between runs.
_Avoid_: Delay, Villain speed, animation lock

**Potions window**:
The Zone Window that lists the Potions the Hero holds, each with its Potion Icon, its Rarity and what it does. The Potions button opens and closes it, and a click on a Potion that glows uses it. Like the Hero's Emblems window, it closes at the click that uses something from it and comes back if that is canceled or undone.
_Avoid_: Inventory, item window, potion menu

**Auto-pass**:
The standing setting that passes priority for the Hero when there is nothing to stop for. With it on, the Hero is asked only on a step that has a stop and where they could cast, play or activate something other than a mana ability, an Emblem's ability and a Potion included, or when the Villain's spell or ability is on top of the stack. It is on unless turned off in the Pause Menu's settings, and kept between runs.
_Avoid_: Auto-skip, smart pass, auto-yield

**Auto-tap**:
The standing setting that pays the Hero's mana costs for them. When a spell or ability reaches payment the game taps the sources and spends the pool mana itself, choosing as the Villain does and showing each tap for a moment, and the Hero is not asked. Mana already in the pool is spent first, so tapping lands by hand before casting chooses them. It is on unless turned off with the Auto-tapping box in the Pause Menu's settings, and a cast that reaches payment with the Hold Key down is paid by hand.
_Avoid_: Auto-pay, smart tap, auto-mana

**Tap Preview**:
What the board shows while the cursor is on something that costs mana and Auto-tap would pay for it: only the sources that would be tapped keep their blue Glow, and the pool mana that would be spent glows on its button. It shows for a card of the hand under the cursor or held, a permanent's ability, and the row of the Option Menu the cursor is on.
_Avoid_: Payment preview, mana highlight, tap suggestion

**Yield**:
The Hero's instruction to pass every priority for the rest of the turn, whatever the stops say and whatever the Villain puts on the stack. Choosing attackers and blockers, and any other choice that is not priority, is still asked, and the Yield carries on afterwards. It is set with the Yield Turn box on the Hero's panel, at any moment, and ends by itself when the next turn begins. Set while the Hero is declaring attackers or blockers, it also confirms them as they stand, so one click says "no attacks, and I am done" (A494).
_Avoid_: Skip turn, pass turn, end turn, auto-pass (the standing setting)

**Hold Key**:
The key bound to holding priority in the Key Bindings: Control unless the player has chosen another. While it is down nothing is passed for the Hero: every priority that Auto-pass or a Yield would have passed, and the one after their own spell or ability goes on the stack, is theirs instead. A priority kept this way stays theirs until they answer, even once the key is let go, and neither Auto-pass nor the Yield is turned off by it. Nothing is paid for them either: a cast that reaches payment while it is down is paid by hand, all of it, whatever Auto-tap says.
_Avoid_: Stop key, full control

**Damage Chip**:
A red bead on a creature with the damage marked on it this turn, resting on the top of its power and toughness box over the toughness. The box itself keeps showing the creature's power and toughness.
_Avoid_: Damage counter, wound marker, remaining toughness

**Attached Mark**:
A white square with a black plus in the corner of an attachment's Battlefield Face, past the end of its name. It says the permanent is attached to the one it lies behind. An attachment, such as an Equipment on a creature, is drawn sideways behind that permanent with only its name strip showing past the right edge, and the mark is at the bottom of that strip.
_Avoid_: Plus icon, attach badge, link icon, equip mark (it is for any attachment)

**Tucked Card**:
A card in exile drawn behind the permanent that exiled it, for as long as that permanent is on the battlefield: the card Oblivion Ring will return when it leaves. It lies sideways as an attachment does, with only its name strip showing past the right edge, but has no Attached Mark, and lies behind every attachment of that permanent. It is still in its owner's exile and that pile counts it, but the pile does not show it. While that exile's Pile Window is open the card is in the window instead, and flies there and back as the window opens and closes. A card whose permanent has gone is exiled for good and is in the pile like any other.
_Avoid_: Exiled under, hostage, captive, attached card (an attachment is on the battlefield)

**Tuck Outline**:
The faint outline left behind a permanent where its Tucked Card lay, while that card is in its Pile Window. It keeps the card's room in the line and is where the card flies back to. It takes no clicks and pins nothing. While the cursor is on the card in the window, or the card is pinned, the outline has a glowing white dashed border.
_Avoid_: Ghost (the fading face of a permanent that has left), placeholder, shadow

**Counter Chip**:
A bead in the top left corner of a permanent's art that says how many counters of one kind are on it, with their sign: green and "+2" for +1/+1 counters, violet and "-2" for -1/-1 counters. It is the Damage Chip's bead in another color and place. The power and toughness box shows what the counters add up to.
_Avoid_: Counter bead, counter badge, gem, buff marker

**Sickness Spiral**:
The white, half see-through spiral turning over the middle of the art of a summoning sick creature's Battlefield Face, over everything else drawn on the face, for as long as the creature cannot attack or pay {T}. It is pixel art drawn at a whole multiple of its size, turns once every three seconds at every Game Speed, and every one on the board turns together. A creature with haste never has one.
_Avoid_: Swirl, dizzy mark, sleep icon, Zzz

**Trigger Order**:
The Hero's half-made answer when several of their triggers happen at once: the triggers in a list above the stack, the top one resolving first, each dragged to its place before the order is confirmed. Triggers that all read the same and have the same cause are ordered without asking.
_Avoid_: Trigger queue, stacking order

**Rules Text**:
The words on a card for what its abilities do. They are generated from the abilities themselves in current Oracle wording, so a Mod that changes an ability changes its text. A permanent calls itself "this creature" or "this artifact", and a spell goes by its name.
_Avoid_: Oracle text (the real card's), description, tooltip

**Glow**:
The colored outline on everything a Pending Decision can choose: orange-red for targets, blue for mana sources, gold for attackers and blockers to choose, purple for abilities to activate, green for anything else (cards that can be cast or played, among others). Something that offers two kinds of thing glows in both colors, split: the first along the top and left, the second along the bottom and right. A permanent with a mana ability and another ability is purple and blue; a card in hand that can be cast and has an ability used from there is green and purple. Whatever a click answers something on always glows. A creature that is attacking or blocking glows gold too, until combat ends, though no decision offers it and it takes no click for it; where a decision offers something on it as well, its Glow is split, that color first and gold second. It eases in and out rather than popping.
_Avoid_: Highlight, selection, halo

**Info Panel**:
The bordered, Dither Shaded box at the left end of the hand's strip, between the Hero's panel and the Hand Strip, 360 wide and as tall as the strip (ADR 0066). Centered in it, it says what the Hero is being asked and what is still owed while paying, and, in red above its Answer Row, why their last answer was refused. Its Answer Row holds the answers of a question or one action. While a "you may" is asked it reads "[ability]: [what yes does]?" (ADR 0060); while a ward cost is asked, and while it is paid, "Pay ward for [the warded permanent]:" with the cost still to pay after it on the same line (ADR 0062); while an X is asked, "Pay {X} for [the source]?" (ADR 0063); while a land being played may be paid for to enter untapped, "Have [the land] enter untapped?", with the cost, "Pay 2 life", as the left answer of its Answer Row (ADR 0067). It is dim while nothing is asked, and its border flashes white once when a question other than priority arrives. While the cursor is on an Option Menu row it shows that row in full in place of everything else.
_Avoid_: Prompt bar, status line, message box

**Pass Button**:
The gray, shaded button at the right end of the hand's strip, opposite the Info Panel and as wide, which is always there (ADR 0066). It reads what it does in large type with the key that presses it under it, smaller: "Pass Priority" over "SPACE". With priority it passes; while attackers, blockers, a division of damage, an order of triggers or cards to discard are being chosen it confirms that choice instead ("Attack with 2"); while a question with a Selected Answer is asked it reads that answer ("Yes", "No", "Pay {2}") and gives it; while such a question has no Selected Answer it reads "Choose an answer", with no key, and cannot be pressed; at any other time it cannot be pressed, and is gray and blank. Its border flashes white once whenever it becomes one that can be pressed. It was over the Info Panel until 13l, and on the Hero's panel until 13g.
_Avoid_: Confirm button, OK button, next button

**Steel Frame**:
How a button is drawn: a ring of light steel three pixels thick with a dark line inside it, its corners stepped and never rounded, over a lip the button sits down on while held, round a face Dither Shaded in the button's own color (game ADR 0066). The ring of a Selected Answer is white. A button that cannot be pressed lies flat, with no lip, its ring faded. Whatever is drawn round a button, a Glow or a ring, follows the frame's shape.
_Avoid_: Border, outline, bevel, button skin

**Steel Rim**:
How a window with no border of its own is edged: three bands three pixels wide, near-black outside and in with dark steel between, its corners stepped four deep as a Steel Frame's are and never rounded, round a face Dither Shaded in the window's warm dark gray. The main menu's window and its dialogs, the Spoils window, the Pause Menu, the encounter's ending banner and the Modify Window have it. A Zone Window keeps its border in its zone's tint, and the deckbuilder's question prompt its thin gray edge.
_Avoid_: Window border, window frame (a Steel Frame is a button's), outline

**Answer Row**:
The bottom row of the Info Panel (ADR 0066). It holds the answers of a question as two halves, the affirmative on the left and "No" on the right, or one action across its whole width: Cancel for a cast in progress, which names the key that cancels, or "Declare All", which reads "Undeclare All" and puts every attacker back for as long as any is declared (A496). A click on an answer gives it at once, and so does an action; while an X is asked a click on an answer only selects it (ADR 0066's addendum). While an X is asked its left half is the stepper: a plate whose ends are − and + and whose number sits in a dark well between them.
_Avoid_: Button row, button bar, footer

**Selected Answer**:
The answer of a "you may", a ward cost or an X that is lit in the Answer Row, with a white border, and that the Pass Button reads and gives (ADR 0066). Left and Right select it; for an X, a click on "No" selects it too, clicking or stepping the stepper selects paying, and Up and Down step X. A click on an answer of any other question gives it at once and needs no Selected Answer (ADR 0066's addendum). A "you may" starts on Yes. A question that spends mana or life starts with none, and the Pass Button cannot give an answer until the Hero selects one.
_Avoid_: Default answer, highlighted answer, focus

**Portrait**:
The 32 × 32 pixel picture of a player on their panel, drawn six screen pixels to each of its own with hard edges, with the life total in its corner. It is what glows and is clicked when its player can be chosen. Every Portrait but a placeholder has a Pain Portrait, and one drawn after a Magic character a Blink Portrait too. A Villain's is drawn after a character in a Magic card's art, turned to face the front, and a Named Hero's after its planeswalker in the same way; the Custom Hero's are a set of their own. Until Heroes have their own, the Hero's is Urza, Academy Headmaster's; for testing, every Villain without a Portrait of its own, and one met outside a run, has Charmed Stray's.
_Avoid_: Avatar, icon, face (a Card Face or Battlefield Face is a card's)

**Pain Portrait**:
The second picture of a Portrait: the same character the moment after being hurt, wincing and knocked a little aside. A player is hurt when their life total goes down, by damage, by paying life or otherwise, counted as what they lost less what they gained at once. The Pain Portrait shows for longer the more life was lost.
_Avoid_: Pain frame (a Frame is a card's), hurt portrait, damage sprite

**Blink Portrait**:
The third picture of a Portrait drawn after a Magic character: the same picture with its eyes closed and nothing else changed, shown for a moment every few seconds, now and then twice, so the character seems alive. Never while the Pain Portrait shows, nor once its player has lost.
_Avoid_: Blink frame, eyes-closed sprite, idle frame

**Breath**:
The slow grow and shrink of a Portrait, so its player seems alive. A player breathes faster as their life gets low, and stops breathing when they lose the encounter.
_Avoid_: Idle animation, bob, pulse

**Breath Rate**:
How fast a character breathes. At 1, a character at rest takes one breath every four seconds; at 2, twice as fast. Each character has their own, and low life raises it.
_Avoid_: Breath speed, tempo

**Breath Intensity**:
How much a Portrait grows at the top of a Breath. At 1, it is one of its own pixels taller and wider; at 2, two. Each character has their own.
_Avoid_: Depth, amplitude, size

**Winded**:
A hurt player is Winded: their Portrait sinks quickly to the bottom of its Breath and stays there while their Pain Portrait shows, then breathes again from the start of a breath.
_Avoid_: Breathless, stunned

**Key Binding**:
The key that does one of the four actions that have a key: passing priority (Space), undo (Z), cancel (X) and holding priority (Control). Any single key can be bound to any of them, a modifier included; never Escape, which is the Pause Menu's, and never a combination or a mouse button. Two actions may share a key: a press of it does only the first of pass, undo and cancel bound to it, and holding priority goes with any of them. Cancel closes an open Option Menu before it cancels a cast. Buttons that name a key name the one bound. They are kept in the settings file.
_Avoid_: Hotkey, shortcut, keymap, control (the key)

**Controls Page**:
The page of the Pause Menu that the Controls button on its settings page opens: a row for each Key Binding showing its key, "Reset controls" and Back. A row that is clicked reads "Press a key…" and takes the next key pressed, Escape only stopping it waiting. Rows whose actions share a key are red.
_Avoid_: Keys page, keybind menu, input settings

**Hold Panel**:
The box at the top left of the battlefield, above the Info Panel and as wide, that says "Holding Priority" in large type. It shows only while the Hold Key is down.
_Avoid_: Hold indicator, priority badge

**Combat Selection**:
The Hero's half-made answer to declaring attackers, declaring blockers or dividing combat damage: what they have clicked so far, before they confirm it. It is thrown away when the decision changes.
_Avoid_: Pending attack, draft, staging

**Block Line**:
The line across the middle of the board from a blocker to the attacker it blocks, with an arrowhead at the attacker. Pale gold while the block is being chosen, white once it is declared.
_Avoid_: Arrow, connector, link

**Damage Stepper**:
The "− 3 +" on a creature, or on a player's portrait, that says how much combat damage it is being given while damage is divided. The number is red once it is lethal.
_Avoid_: Spinner, counter (a rules term), slider

**Option Menu**:
The dropdown that opens where a card was clicked when the click could mean more than one thing, with a row for each: a permanent's abilities now, and later choices such as kicker or which half of an adventure card to cast. It shows three rows and scrolls for more, except that a choice of the color of mana of any color shows all five, a row each, "Add {W}" to "Add {G}" (ADR 0073). A row draws its mana symbols as pips, and while the Hero pays by hand a color that pays something still owed glows green. It closes without choosing at a click anywhere else, or a press of the cancel key, which then cancels nothing more.
_Avoid_: Ability menu, context menu, popup

**Pause Menu**:
The fixed window over the battlefield that Escape opens and closes. While it is open nothing in the encounter moves or can be clicked. It offers Resume, Concede, Settings, Quit to main menu and Abandon Run, and it can be opened on the Stage Map and at any Node too, where it has no Concede. Quitting keeps the run saved, and an encounter quit starts over on Continue; Abandon Run, once confirmed, ends the run as lost and deletes its save. In a run, the Run Seed is shown at its foot. Settings is a page of its own, which holds the Game Speed, Auto-pass and Auto-tap, and the Controls button that opens the Controls Page.
_Avoid_: Escape menu, options screen, system menu

**Opening-Hand Overlay**:
The scrim over everything right of the sidebar through the pregame, with the Hero's hand drawn large on it, fanned as it is in play; the card under the cursor comes to the front and stands upright to be read. Playing first or drawing, keeping or mulliganing, and putting cards on the bottom are all answered there, and it says who plays first and what the Villain has decided. A new hand is dealt onto it from the library a card at a time, and a card put on the bottom, or a hand that is mulliganed, flies back there. When the first turn begins the hand flies down to its strip and the overlay goes.
_Avoid_: Mulligan screen, pregame dialog, hand viewer

**Card Picks**:
The Hero's half-made choice of cards from their hand, before they confirm it: which to put on the bottom after keeping, or which to discard. The cards are given in the order picked. It is thrown away when the decision changes.
_Avoid_: Selection (a Combat Selection is the combat one), checklist, picked cards

**Card Face**:
A card drawn in full: its Frame, name, mana cost, type line, rules text and power/toughness. Used wherever a card is read rather than played on.
_Avoid_: Full card, card image

**Card Back**:
The side of a card the Hero cannot see, drawn for each card in the Villain's hand and for each card in a library that the Hero does not know. It is the size and shape of a Card Face and edged in the same black border, as thick all round as a Card Face's is at its sides and top.
_Avoid_: Back face, face-down card

**Emblem Face**:
An Emblem drawn in full, in the Inspector: its art in a border of its own, its name, a type line that reads "Emblem", its rules text with any spent ability gray and marked "(used)", and the artist's credit. It is the size of a Card Face and has no Rarity glow.
_Avoid_: Emblem card, Boon card, Status card

**Battlefield Face**:
How a permanent is drawn on the battlefield: the top of its Frame (name box or crown) and a border around its art, a large power/toughness box, and a chip for each keyword it has. It shows no other text, and turns sideways and darkens when tapped. A summoning sick creature's is darkened a little, less than a tapped one's, under its Sickness Spiral.
_Avoid_: Mini card, tile, token (a token is a rules term)

**Keyword Chip**:
The small square on a Battlefield Face that stands for one keyword the permanent has.
_Avoid_: Badge, tag

**Chosen Type Chip**:
A chip like a Keyword Chip holding a permanent's Chosen Creature Type by name, first in the chips' row of its Battlefield Face (game ADR 0053). Its words never shrink below a readable size: on a face too small for the whole name it is cut short with an ellipsis, and the Inspector's State Information says it in full.
_Avoid_: Type badge, type tag, type plate

**Keyword Icon**:
The 16 × 16 pixel picture on a Keyword Chip that identifies its keyword.
_Avoid_: Sprite, glyph, symbol (mana symbols are a different thing)

**Inspector**:
Where one card is read in full, down the side of the screen, in an encounter (the pregame included) and in the deckbuilder, laid out alike in both. It shows the card's Card Face and, under it, its Card Text and a second panel: its State Information in an encounter, its Mods in the deckbuilder. While Reminders is pressed, its Reminders stand in place of both. In an encounter it takes the sidebar's place while a card is pinned, and hovering over a card shows nothing; in the deckbuilder it is always there and shows the card selected, or the card under the cursor while none is. An ability on the stack is read as the card it came from. A pinned Emblem is shown on its Emblem Face, and a pinned Potion as its Potion Icon enlarged, with its name and a type line of its Rarity and "Potion", such as "Rare Potion"; either has its Card Text under it and Reminders, but no View Original or State Information.
_Avoid_: Card viewer, tooltip, preview (a Tap Preview is a different thing), zoom

**Pinned card**:
The card a right-click puts in the Inspector, ringed where it is drawn. A right-click on another card pins that one instead. A second right-click on it, a right-click on empty space, a left-click anywhere outside the Inspector or Escape lets it go. Nothing is pinned while a card or a trigger is being dragged.
_Avoid_: Selected card (the deckbuilder's), locked card, focused card

**Original**:
A card as its Card Definition has it: no Mods, no Hexes and nothing an encounter has done to it. The Inspector shows it in place of the card as it is now while View Original is pressed. An Emblem has none. A token that is a copy has the Original of the card it copied, and any other token has none.
_Avoid_: Base card, printed card, unmodified card

**State Information**:
The Inspector's panel of what is true of a permanent right now that its Card Face does not say, such as damage marked on it and each effect on it with where the effect came from. The Inspector draws whatever entries it is given, so a new kind of state adds an entry and changes nothing else.
_Avoid_: State List (its old name), status list (a Status is the Hero's), buffs, modifiers

**Card Text**:
The rules text of a card, an Emblem or a Potion as its face prints it, without reminder text, set out in its own panel in the Inspector. It is always the pinned or selected thing as it is now, even while View Original is pressed.
_Avoid_: Oracle text, description, rules box

**Reminder**:
What one keyword means, in a sentence, shown in the Inspector beside its Keyword Icon. Card Faces leave Reminders off.
_Avoid_: Reminder text (the real cards' parenthesized words), tooltip, help text

**Rarity**:
How scarce a card, a Potion or a Mod is: Common, Uncommon, Rare, Mythic, then Power-9 for a card or Unique for a Mod. A Unique Mod is strong but needs just the right deck; it is won only from a rare Twist, never in Spoils or for sale at a Workshop, though a Workshop buys and removes one like any other. No Hex is Unique. It is part of the card's design, set on its Card Definition, and no rule reads it. The Inspector glows around the card in the Rarity's color: gray, silver, gold, honey and light green, and a Potion's type line there names it. A Potion Icon's plate is the same color, but for a Mythic's, which is sienna so that it is not taken for Rare's gold. A Mod Icon is in its Rarity's color itself: orange for a Mythic, light purple for a Unique. An Emblem has none, and neither has an Armor.
_Avoid_: Tier (a part of a run), quality, grade

**Divider**:
The bar in the deckbuilder between the Collection and the Deck's columns. Dragging it up or down gives one more height and the other less; it changes no card's size, which the two zoom sliders set. Neither side can be made smaller than one whole card, and a double-click puts it back where it started. It stays where it was left until the deckbuilder closes.
_Avoid_: Slider (the zoom sliders), splitter, sash, handle

**Menu Backdrop**:
The one picture behind the main menu: the top of a castle tower at nightfall, the menu's window set into its parapet as its middle merlon with the Menu Soldier standing on it, braziers burning on the corner merlons and open sky on either side for the Wisp. It is 320 × 180 pixels, drawn six screen pixels to each of its own, never tiled and never dimmed, and it plays a ten-second loop of small flickers: the braziers' flames and the light they throw, some of the stars, and the light in an arrow slit.
_Avoid_: Background, wallpaper, Backdrop (the picture behind an encounter)

**Menu Soldier**:
The pixel-art soldier who stands on top of the main menu's window, whose top lies on the parapet of the Menu Backdrop's tower, centered across the screen, and plays one Soldier Animation after another, each starting as the last one ends. The first, from the moment the menu opens, is a Transition Animation chosen at random; then an Effect Animation and a Transition Animation take turns, and he never plays the same Transition Animation, or the same Effect Animation, twice in a row. The next Effect Animation is chosen two animations ahead, so the Wisp, which brings it to him, knows its color and the moment he will flash it.
_Avoid_: Mascot, idle soldier

**Logo**:
The game's name in blocky pixel letters at the head of the main menu's window, under the Menu Soldier: six characters, each drawn on 32 × 32, set evenly and close, and shown at twice their size. Its two o's are the Mod Icon's cog, Rare's then Mythic's, the first turning clockwise and the second against it, a quarter turn every three seconds; "Mod" is white tinged with Rare's gold and "Mox" white tinged with Mythic's bronze.
_Avoid_: Title, wordmark, banner

**Soldier Shadow**:
The shadow the Menu Soldier casts on the window he stands on: half black, in the window's own Dither Shading blocks, two rows solid and two dithered away, under every column where the bottom of his sprite is black. It follows his frames, fading out rapidly under a lifted foot or a raised spear and back in as it comes down, and from under all of him while a flap of his wings lifts him off the window, and on the frame he flashes it takes the flash's color, fading back to black as rapidly after.
_Avoid_: Drop shadow, contact shadow

**Soldier Animation**:
Seven seconds of the Menu Soldier's frames, starting and ending on him standing still, as long at one end as at the other: a Transition Animation or an Effect Animation.
_Avoid_: Section, clip

**Transition Animation**:
A Soldier Animation of the Menu Soldier being himself, played between Effect Animations: keeping lookout, dozing off or cheering.
_Avoid_: Idle (its old name), interlude

**Effect Animation**:
A Soldier Animation that gives the Menu Soldier a keyword's look for a while, such as wings for flying or a goblin's face for menace. He flashes the effect's color on the way in and again on the way out.
_Avoid_: Buff animation, keyword animation

**Wisp**:
The little light that floats about the main menu bringing the Menu Soldier his effects. In the next Effect Animation's color, it reaches his chest at the moment he first flashes that color, drifts on through him to the other side of the window from the one it came from, and wanders lazily back in time for the next; after each touch it turns slowly to the following effect's color. It never crosses the window or goes below it, and it fades in when the menu opens.
_Avoid_: Magic ball, orb, dot

**Wisp Light**:
The light the Wisp casts on the main menu's window when it comes near the window's top or either side: the Soldier Shadow turned to light, in the Wisp's color at half strength, longer the nearer the Wisp is. It lies over the Soldier Shadow where the two meet.
_Avoid_: Anti-shadow, glow (a Pending Decision's), highlight

**Wisp Sparks**:
The trail of sparks the Wisp leaves wherever it goes on the main menu: square sparks, one of its pixels each, in the Wisp's color as each is emitted. Each flies out of the Wisp's middle at a random angle, all the way round, drifting a little off straight and with none of the Wisp's own motion, and falls ever faster as it fades out; one that falls onto the window comes to rest on its top, or on the step of a stepped corner, and fades out there, and one that misses falls on past it.
_Avoid_: Particles, embers, trail (alone)

**Effect Callout**:
The name of the effect the Menu Soldier takes on, floating off from him as he first flashes its color: its keyword as cards print it, such as Flying or First strike, or +1/+1 for his boost, ghostly faint in the flash's color. It appears just outside his picture, beside or above his upper half, and floats straight away from him for two seconds, wiggling and rocking a little as it fades out. His other flashes bring none.
_Avoid_: Text box, popup, floating text, ghost (a leaving permanent's)
