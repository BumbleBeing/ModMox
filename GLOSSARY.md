# ModMox Game

The roguelike RPG around the rules engine: runs, characters, and everything that happens between encounters.

## Language

**Content**:
The Card Definitions authored for the game and shipped with it, such as the Alpha cards. The rules engine never contains or depends on Content.
_Avoid_: Card database, card pool, assets

**Frame**:
The layered image a card is drawn on, worked out from its characteristics: a frame for its color category (a land's follows the colors of mana it can produce), a power/toughness box if it is a creature, and a crown if it is legendary.
_Avoid_: Card background, border, template

**Status**:
A lasting condition on the Hero's character that changes the starting conditions of encounters or adds an Emblem to them.
_Avoid_: Trait, perk, buff, condition

**Boon**:
A Status that helps the Hero, such as an extra free mulligan.
_Avoid_: Blessing, perk

**Affliction**:
A Status that hinders the Hero, such as Forgetful (opening hand one card smaller).
_Avoid_: Curse, debuff

## Runs

**Tier**:
One of a run's five steps of difficulty, each offering one Stage of every color. A run plays one Stage per Tier and never the same color twice.
_Avoid_: Level, act, round

**Stage**:
One section of a run, of one color at one Tier and ending in a Boss, which sets the backdrop of its encounters. There are 25 in all.
_Avoid_: Level, act, world, biome

**Node**:
One stop on a Stage's map. Its kind is one of Start Node, Store, Workshop, Trove, Lesser Encounter, Elite Encounter, Boss Encounter or Chaos Node.
_Avoid_: Event (an engine term for a change to the game), room, space

**Start Node**:
The Node a Stage begins on, where nothing happens.
_Avoid_: Blank node, entrance

**Lesser Encounter**, **Elite Encounter**, **Boss Encounter**:
A Node that is an encounter with a Villain of that Rank. Every Stage ends on its one Boss Encounter.
_Avoid_: Fight, battle, boss node

**Store**:
A Node that buys and sells cards and items for gold, buying at a fraction of the price it sells at. Every Stage has one right after its Start Node and one right before its Boss Encounter.
_Avoid_: Shop, merchant, vendor

**Workshop**:
A Node that buys and sells Mods for gold, and removes a Mod from a card for a price, a higher one for a Hex. Every Stage has one right after its Start Node and one right before its Boss Encounter.
_Avoid_: Forge, smith, mod shop

**Trove**:
The Node that follows an Elite Encounter and holds treasure. The Hero reaches it whether the Elite Encounter was won or lost, and it is never found anywhere else.
_Avoid_: Treasure node, chest

**Chaos Node**:
The Node through which a Unique Villain is met. It never counts as an encounter when a Stage's map is laid out.
_Avoid_: Mystery Node, event node

**Rank**:
How dangerous a Villain is where it is met: Lesser, Elite, Boss or Unique. A Stage says which Villains it has at each of the first three Ranks, so Rank belongs to the meeting, not to the Villain. The Rank and the Stage's Tier decide the Spoils.
_Avoid_: Difficulty (AI Difficulty is the one global setting for how hard every Villain thinks), level, class

**Unique Villain**:
A Villain of Unique Rank, met only through a Chaos Node. It can turn up at any Stage, with a stronger deck at each Tier.
_Avoid_: Mystery enemy, mini-boss, special

**Spoils**:
What the Hero wins for beating a Villain: gold, cards, Mods and items. Their quantity and quality follow the Villain's Rank and the Tier; the cards come from the Villain's own deck.
_Avoid_: Loot, rewards, drops

**Mod**:
An item the Hero holds (a Hex aside) and can apply to a card in their Collection to change it for the rest of the run. Applied, it becomes one of that Run Card's Modifications, the rules engine's word for the change itself. Applying one is final the moment it is confirmed, and it fills one of the card's Mod Slots. A Mod is applicable to a card that has an empty Mod Slot and that the Mod's own rule accepts.
_Avoid_: Modification (the engine's term), upgrade, enchantment

**Hex**:
A Mod that harms the card it is on. The Hero never holds or applies one: it arrives already on a card, and takes one of that card's three Mod Slots.
_Avoid_: Curse, bad mod, downgrade

**Mod Slot**:
One of the three places a Run Card has for Mods, Hexes included. Basic lands have none.
_Avoid_: Mod pip, socket, upgrade slot

**Heart**:
One of the losses a run can survive. Losing an encounter costs one, and the run is lost when none are left.
_Avoid_: Life (a rules term), health, HP

**Run Seed**:
The single number from which all randomness in a run is derived: each Stage's map, which Villain a Node gives, the Spoils, and every Encounter Seed. A run is exactly replayable from it and the human's choices.
_Avoid_: Random seed, world seed

## Decks

**Collection**:
Every Run Card the Hero owns in the run. It alone owns them: a Deck only points at cards in it, so one Run Card can be in several Decks and carries its Mods into each. Two copies of a card are two Run Cards. Basic lands are not in it.
_Avoid_: Card pool, inventory, library (a rules term), stash

**Deck**:
A named list of Run Cards from the Collection, each at most once, plus any number of basic lands. Its cards are never stacked or counted as copies: every one is shown and handled as its own card. It is legal at 40 cards or more. An illegal Deck can be saved but cannot be the Active Deck.
_Avoid_: Decklist, loadout, build

**Deckbox**:
The Decks the Hero has saved in the run.
_Avoid_: Deck list, deck slots, saved decks

**Active Deck**:
The one Deck in the Deckbox that the Hero takes into encounters.
_Avoid_: Current deck, equipped deck, main deck

**Basic land**:
A land the Hero never has to own: a Deck may hold any number of each type for free. It cannot take a Mod.
_Avoid_: Free land

**Working Deck**:
The unsaved copy of a Deck being edited in the deckbuilder. Saving writes it to the Deckbox; leaving without saving throws it away. Mods applied meanwhile are not part of it and stay applied.
_Avoid_: Draft (a Magic term), deck in progress, scratch deck

**Hall of Fame**:
The read-only copies of Active Decks, Mods included, kept from runs the Hero won. They are looked at from the main menu and never played.
_Avoid_: Trophy room, deck archive, history

## Presentation

**Encounter Screen**:
What shows an encounter to the human and takes their answers.
_Avoid_: Battle screen, game view, board

**Encounter Presenter**:
The one part of the GUI that owns the rules engine for an encounter. It runs the Villain's Agent, takes the Hero's answers, and after every change hands the Encounter Screen a snapshot of what the Hero may see and is being asked.
_Avoid_: Controller, game manager, view model

**Region**:
One rectangle of the Encounter Screen's layout, such as a player's panel in the sidebar, a row of lands, the Hero's hand, or a library, graveyard or exile pile. No two Regions overlap. The stack is not a Region: see Stack Window.
_Avoid_: Area, zone (a rules term), slot

**Zone Window**:
A window over the Encounter Screen that shows what is in a zone. It can be dragged and resized within the battlefield, scrolls when its contents overflow, is titled with the zone's name and its count, and reopens where it was left. All but the Stack Window can be closed.
_Avoid_: Popup, dialog, zone viewer

**Stack Window**:
The Zone Window for the stack. It is there while something is on the stack or triggers are being put in order, lists what resolves first at the top, and cannot be closed. Each entry has two lines, each cut short with an ellipsis: an ability leads with what it does and a spell with its name, then comes who controls it and what it targets.
_Avoid_: Stack region, stack panel

**Stack Color**:
The color a spell or ability has for as long as it is on the stack: one of eight muted hues that leave out the Glow's colors and the Block Lines'. It is on the entry's border and the stripe down its left side, on the arrow to a spell it targets, and on what the entry marks on the board while the cursor is over it.
_Avoid_: Entry tint, stack hue, highlight color

**Stack Mark**:
What the Stack Window entry under the cursor draws on the board, in its Stack Color: a solid border on the source of an ability, which is settled, and a dashed border on each target, which is still to happen. A mark takes the place of the Glow while it is there.
_Avoid_: Hover highlight, preview, target glow

**Hand Order**:
The order the Hero keeps their hand in, which is theirs alone: cards are dragged along the hand to rearrange it, a new card joins at the right end, and a card that a canceled cast or an undo brings back takes the place it had.
_Avoid_: Hand sort, hand layout, card order

**Drag Card**:
The card of the Hero's hand that is being held with the mouse. It follows the cursor upright above everything; let go above the hand's strip it is played, and let go over the strip it is put down where the other cards made room.
_Avoid_: Hand drag, dragged card, held card, grabbed card

**Face Motion**:
How permanents move on a screen that is rebuilt from every snapshot: it remembers where each one's face was last drawn, and the face eases from there to where it now belongs, in place, size and turn. A permanent that arrives fades in, and one that leaves fades out as a ghost.
_Avoid_: Tween, animation system, transition

**Ghost**:
The fading face of a permanent that has left the battlefield, drawn where it was for a quarter of a second. It takes no clicks and nothing points at it.
_Avoid_: Corpse, death animation, afterimage

**Pacing**:
The wait before the Villain's next answer is shown, so the Hero can read the last one: half a second after an action, about a quarter after tapping for mana, and none after a pass that showed nothing. Thinking counts toward it.
_Avoid_: Delay, Villain speed, animation lock

**Damage Chip**:
A red bead on a creature with the damage marked on it this turn, resting on the top of its power and toughness box over the toughness. The box itself keeps showing the creature's power and toughness.
_Avoid_: Damage counter, wound marker, remaining toughness

**Trigger Order**:
The Hero's half-made answer when several of their triggers happen at once: the triggers in a list above the stack, the top one resolving first, each dragged to its place before the order is confirmed. Triggers that all read the same and have the same cause are ordered without asking.
_Avoid_: Trigger queue, stacking order

**Rules Text**:
The words on a card for what its abilities do. They are generated from the abilities themselves in current Oracle wording, so a Mod that changes an ability changes its text. A permanent calls itself "this creature" or "this artifact", and a spell goes by its name.
_Avoid_: Oracle text (the real card's), description, tooltip

**Glow**:
The colored outline on everything a Pending Decision can choose: orange-red for targets, blue for mana sources, green for anything else. Whatever a click answers something on always glows. It eases in and out rather than popping.
_Avoid_: Highlight, selection, halo

**Info Panel**:
The bordered box at the bottom left of the battlefield, between the Hero's panel and the Hero's hand. It says what the Hero is being asked, what is still owed while paying, why their last answer was refused and whether priority is being held, and holds the Cancel button for a cast in progress.
_Avoid_: Prompt bar, status line, message box

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
The dropdown that opens where a card was clicked when the click could mean more than one thing, with a row for each: a permanent's abilities now, and later choices such as kicker or which half of an adventure card to cast. It shows three rows and scrolls for more.
_Avoid_: Ability menu, context menu, popup

**Pause Menu**:
The fixed window over the battlefield that Escape opens and closes. While it is open nothing in the encounter moves or can be clicked. It offers Resume, Concede, Settings and Quit to main menu.
_Avoid_: Escape menu, options screen, system menu

**Opening-Hand Overlay**:
The scrim over everything right of the sidebar through the pregame, with the Hero's hand drawn large on it, fanned as it is in play; the card under the cursor comes to the front and stands upright to be read. Playing first or drawing, keeping or mulliganing, and putting cards on the bottom are all answered there, and it says who plays first and what the Villain has decided. It goes when the first turn begins.
_Avoid_: Mulligan screen, pregame dialog, hand viewer

**Card Picks**:
The Hero's half-made choice of cards from their hand, before they confirm it: which to put on the bottom after keeping, or which to discard. The cards are given in the order picked. It is thrown away when the decision changes.
_Avoid_: Selection (a Combat Selection is the combat one), checklist, picked cards

**Card Face**:
A card drawn in full: its Frame, name, mana cost, type line, rules text and power/toughness. Used wherever a card is read rather than played on.
_Avoid_: Full card, card image

**Battlefield Face**:
How a permanent is drawn on the battlefield: the top of its Frame (name box or crown) and a border around its art, a large power/toughness box, and a chip for each keyword it has. It shows no other text, and turns sideways and darkens when tapped.
_Avoid_: Mini card, tile, token (a token is a rules term)

**Keyword Chip**:
The small square on a Battlefield Face that stands for one keyword the permanent has.
_Avoid_: Badge, tag

**Keyword Icon**:
The 16 × 16 pixel picture on a Keyword Chip that identifies its keyword.
_Avoid_: Sprite, glyph, symbol (mana symbols are a different thing)
