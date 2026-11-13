# ModMox Game

The roguelike RPG around the rules engine: runs, characters, and everything that happens between encounters.

## Language

**Content**:
The Card Definitions authored for the game and shipped with it, such as the Alpha cards. The rules engine never contains or depends on Content.
_Avoid_: Card database, card pool, assets

**Frame**:
The layered image a card is drawn on, worked out from its characteristics: a frame for its color category (a land's follows the colors of mana it can produce), a power/toughness box if it is a creature, and a crown if it is legendary. A colored artifact keeps its colors' frame, box and crown inside the artifact frame's silver border.
_Avoid_: Card background, border, template

**Status**:
A lasting condition on the Hero's character that changes the starting conditions of encounters or adds an Emblem to them. A Status is never used up; what is used up is a Potion.
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
One section of a run, of one color at one Tier and ending in a Boss, which sets the Backdrop of its encounters. There are 25 in all.
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
A Node that buys and sells cards and Items for gold, buying at a fraction of the price it sells at. Every Stage has one right after its Start Node and one right before its Boss Encounter.
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
What the Hero wins for beating a Villain: gold, cards and Items. Their quantity and quality follow the Villain's Rank and the Tier; the cards come from the Villain's own deck.
_Avoid_: Loot, rewards, drops

**Item**:
Anything the Hero holds between encounters and can buy, sell or win other than a card: a Mod or a Potion.
_Avoid_: Gear, equipment (an Equipment is a card), inventory object

**Potion**:
An Item that is used up when it is used. Some can be used in the middle of an encounter, where they do what a spell would, such as "gain 2 life" or "each opponent discards a card". A Potion has no mana cost, and has a Rarity and a Potion Icon. The Hero's panel counts them on its Potions button, which glows while one could be used, is purple with any and gray with none, and opens the Potions window, where a click on a Potion uses it. Whatever is gone for good once used is a Potion and never an Emblem: an Emblem's ability is static or triggered, or can be activated, sometimes only once each game, and the Emblem itself stays (A491 to A493). The only Potion so far is a mock, Big Gulp: "Target creature gets +2/+2 until end of turn."
_Avoid_: Consumable, single-use Emblem, single-use Boon, charge

**Held**:
Said of what a player has in an encounter that is not a card: their Emblems and their Potions. The code that treats the two alike is named for it (`HeldState`, `HeldWindows`, a "held entry"). The engine has no word for the pair: there they are objects in the command zone.
_Avoid_: Command object, non-card, Item (only a Potion is one); and "held card", which is a Drag Card

**Potion Icon**:
A Potion's picture: a 16 × 16 pixel icon on a beige square with a darker circle behind it, shown on its entry in the Potions window, on its ability's entry in the Stack Window, and enlarged in the Inspector. A Potion without one shows a plain bottle.
_Avoid_: Potion art, potion sprite, potion card

**Mod**:
An Item the Hero holds (a Hex aside) and can apply, in the deckbuilder only, to a card to change it for the rest of the run. Applied, it becomes one of that Run Card's Modifications, the rules engine's word for the change itself. Applying one is final the moment it is confirmed, and it fills one of the card's Mod Slots. A Mod is applicable to a card that has an empty Mod Slot and that the Mod's own rule accepts, a basic land included. Its name becomes part of the card's Modded Name.
_Avoid_: Modification (the engine's term), upgrade, enchantment

**Hex**:
A Mod that harms the card it is on. The Hero never holds or applies one: it arrives already on a card, and takes one of that card's three Mod Slots.
_Avoid_: Curse, bad mod, downgrade

**Modded Name**:
What a card with Mods or Hexes is called: the name of each one on it, in slot order, in front of the card's own. A Grizzly Bears with the Mod Violent is Violent Grizzly Bears. A fuller set of naming rules is still to be agreed.
_Avoid_: Prefix, title, nickname

**Mod Slot**:
One of the three places a card has for Mods, Hexes included. A basic land has them too.
_Avoid_: Mod pip, socket, upgrade slot

**Heart**:
One of the losses a run can survive. Losing an encounter costs one, and the run is lost when none are left.
_Avoid_: Life (a rules term), health, HP

**Run Seed**:
The single number from which all randomness in a run is derived: each Stage's map, which Villain a Node gives, the Spoils, and every Encounter Seed. A run is exactly replayable from it and the human's choices.
_Avoid_: Random seed, world seed

## Decks

**Collection**:
Every Run Card the Hero owns in the run. It alone owns them: a Deck only points at cards in it, so one Run Card can be in several Decks and carries its Mods into each. Two copies of a card are two Run Cards. A basic land is not in it until it takes its first Mod. A card that is sold or lost drops out of every Deck.
_Avoid_: Card pool, inventory, library (a rules term), stash

**Deck**:
A named list of Run Cards from the Collection, each at most once, plus any number of basic lands. Its cards are never stacked or counted as copies: every one is shown and handled as its own card. It is legal at 40 cards or more, with no maximum and no limit on copies. An illegal Deck can be saved, but an encounter cannot be started with one.
_Avoid_: Decklist, loadout, build

**Deckbox**:
The Decks the Hero has saved in the run, and the screen that lists them, sets the Active Deck and is the only way into the deckbuilder. It can be opened from Stage Navigation, and it opens by itself before an encounter once the Villain is revealed, with a Start button that is disabled while the Active Deck is illegal.
_Avoid_: Deck list, deck slots, saved decks

**Active Deck**:
The one Deck in the Deckbox that the Hero takes into encounters.
_Avoid_: Current deck, equipped deck, main deck

**Basic land**:
A land the Hero never has to own: a Deck may hold any number of each type for free. One that takes a Mod stops being free: that copy becomes a Run Card in the Collection with a Modded Name, such as Ancient Plains, and no longer counts as a Plains.
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

**Backdrop**:
The one picture behind an Encounter Screen, set by the encounter's Stage: 320 × 180 pixels, drawn six screen pixels to each of its own with hard edges, never tiled, and dimmed by the game so the board reads over it. There is one for each color and a plain one with no picture. Until Stages exist the encounter's request names it, and until each has its own art a placeholder is drawn in its place.
_Avoid_: Background (the plain slate behind a screen), wallpaper, scene, biome

**Zone Plate**:
A rounded, mostly see-through gray rectangle behind a row of the battlefield or a pile, which shows where the zone is and sets it off from the Backdrop. Each player's lands and their other permanents have one each, and so has each library, graveyard and exile. The hands have none.
_Avoid_: Panel (a player's panel is in the sidebar), slot, tray, zone box

**Encounter Presenter**:
The one part of the GUI that owns the rules engine for an encounter. It runs the Villain's Agent, takes the Hero's answers, and after every change hands the Encounter Screen a snapshot of what the Hero may see and is being asked.
_Avoid_: Controller, game manager, view model

**Region**:
One rectangle of the Encounter Screen's layout, such as a player's panel in the sidebar, a row of lands, the Hero's hand, or a library, graveyard or exile pile. No two Regions overlap. The stack is not a Region: see Stack Window.
_Avoid_: Area, zone (a rules term), slot

**Zone Window**:
A window over the Encounter Screen that shows what is in a zone. It can be dragged and resized within the battlefield, scrolls when its contents overflow, is titled with the zone's name and its count, and reopens where it was left. All but the Stack Window can be closed. A player's own zone is titled with their name: "Jackson's Graveyard (5)".
_Avoid_: Popup, dialog, zone viewer

**Pile Window**:
The Zone Window of a pile: a graveyard, an exile or a library. A click on the pile opens it and a second closes it. A graveyard or exile is a grid of Card Faces, the newest card first; a library is one row, its top card on the left, with a card back for each card the Hero does not know. A card in one that a decision can choose glows and is clicked there, and while one can be, its pile glows too. A Pile Window opened to choose a target closes once the target is chosen.
_Avoid_: Zone viewer, graveyard viewer, pile popup

**Player Name**:
What a player of an encounter is called on the screen. A player given no name goes by their part, "Hero" or "Villain", and only then takes "the" in a sentence: "the Villain's turn", but "Mishra's turn".
_Avoid_: Nickname, handle, display name

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
How permanents move on a screen that is rebuilt from every snapshot: it remembers where each one's face was last drawn, and the face eases from there to where it now belongs, in place, size and turn. A permanent that arrives fades in, and one that leaves fades out as a ghost, unless a Card Flight carries it.
_Avoid_: Tween, animation system, transition

**Ghost**:
The fading face of a permanent that has left the battlefield, drawn where it was for a quarter of a second. It takes no clicks and nothing points at it. A permanent that flies to another zone leaves none.

**Card Flight**:
A card drawn in the air on its way from one zone to another, in place of fading out in one place and in at another. It starts where the card was drawn and lands where it now belongs, over every window, and what it lands on shows nothing of it until it arrives. A card that passes through a zone on the way makes one flight. Cards a player draws together fly one after another, and each joins the hand when it lands.

**Flight Card**:
The card drawn for a Card Flight. It is drawn as what the card was where it left and as what it is where it lands, one fading into the other: a Card Face becomes a Battlefield Face, and a card back turns face up. At the Stack Window, which shows an entry and no card, it flies to the entry's art and fades out, or fades in there.
_Avoid_: Corpse, death animation, afterimage

**Pacing**:
The wait before the Villain's next answer is shown, so the Hero can read the last one: at the Fast Game Speed, half a second after an action, about a quarter after tapping for mana, and none after a pass that showed nothing. Thinking counts toward it. A step of the turn is also shown for at least a tenth of a second, again at Fast, before the game leaves it, whoever is passing.

**Game Speed**:
The setting that scales every wait, move, Card Flight and fade of an encounter together: Slow, Normal, Fast or Blazing. Normal takes one and a half times as long as Fast, Slow twice as long, and Blazing half. It is chosen in the Pause Menu's settings and kept between runs.
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

**Trigger Order**:
The Hero's half-made answer when several of their triggers happen at once: the triggers in a list above the stack, the top one resolving first, each dragged to its place before the order is confirmed. Triggers that all read the same and have the same cause are ordered without asking.
_Avoid_: Trigger queue, stacking order

**Rules Text**:
The words on a card for what its abilities do. They are generated from the abilities themselves in current Oracle wording, so a Mod that changes an ability changes its text. A permanent calls itself "this creature" or "this artifact", and a spell goes by its name.
_Avoid_: Oracle text (the real card's), description, tooltip

**Glow**:
The colored outline on everything a Pending Decision can choose: orange-red for targets, blue for mana sources, gold for attackers and blockers to choose, purple for abilities to activate, green for anything else (cards that can be cast or played, among others). Something that offers two kinds of thing glows in both colors, split: the first along the top and left, the second along the bottom and right. A permanent with a mana ability and another ability is purple and blue; a card in hand that can be cast and has an ability used from there is green and purple. Whatever a click answers something on always glows. It eases in and out rather than popping.
_Avoid_: Highlight, selection, halo

**Info Panel**:
The bordered box at the bottom left of the battlefield, between the Hero's panel and the Hero's hand. It says what the Hero is being asked, what is still owed while paying and why their last answer was refused, and holds the Cancel button for a cast in progress, which names the key that cancels. While attackers are declared it holds "Declare All", which reads "Undeclare All" and puts every attacker back for as long as any is declared (A496). The Pass Button is directly above it.
_Avoid_: Prompt bar, status line, message box

**Pass Button**:
The gray, shaded button over the Info Panel and as wide, which is always there. With priority it reads "Pass Priority" with the key that passes, and passes; while attackers, blockers, a division of damage, an order of triggers or cards to discard are being chosen it confirms that choice instead ("Attack with 2"); at any other time it cannot be pressed. Whatever it reads, it ends with the key that presses it: "Attack with 2 [SPACE]" (A495). It was on the Hero's panel until 13g.
_Avoid_: Confirm button, OK button, next button

**Portrait**:
The 32 × 32 pixel picture of a player on their panel, drawn six screen pixels to each of its own with hard edges, with the life total in its corner. It is what glows and is clicked when its player can be chosen. Until Heroes and Villains have their own, the Hero's is a white wizard and the Villain's a purple demon.
_Avoid_: Avatar, icon, face (a Card Face or Battlefield Face is a card's)

**Key Binding**:
The key that does one of the four actions that have a key: passing priority (Space), undo (Z), cancel (X) and holding priority (Control). Any single key can be bound to any of them, a modifier included; never Escape, which is the Pause Menu's, and never a combination or a mouse button. Two actions may share a key: a press of it does only the first of pass, undo and cancel bound to it, and holding priority goes with any of them. Buttons that name a key name the one bound. They are kept in the settings file.
_Avoid_: Hotkey, shortcut, keymap, control (the key)

**Controls Page**:
The page of the Pause Menu that the Controls button on its settings page opens: a row for each Key Binding showing its key, "Reset controls" and Back. A row that is clicked reads "Press a key…" and takes the next key pressed, Escape only stopping it waiting. Rows whose actions share a key are red.
_Avoid_: Keys page, keybind menu, input settings

**Hold Panel**:
The box at the top left of the battlefield, opposite the Info Panel, that says "Holding Priority" in large type. It shows only while the Hold Key is down.
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
The dropdown that opens where a card was clicked when the click could mean more than one thing, with a row for each: a permanent's abilities now, and later choices such as kicker or which half of an adventure card to cast. It shows three rows and scrolls for more.
_Avoid_: Ability menu, context menu, popup

**Pause Menu**:
The fixed window over the battlefield that Escape opens and closes. While it is open nothing in the encounter moves or can be clicked. It offers Resume, Concede, Settings and Quit to main menu. Settings is a page of its own, which holds the Game Speed, Auto-pass and Auto-tap, and the Controls button that opens the Controls Page.
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

**Emblem Face**:
An Emblem drawn in full, in the Inspector: its art in a border of its own, its name, a type line that reads "Emblem", its rules text with any spent ability gray and marked "(used)", and the artist's credit. It is the size of a Card Face and has no Rarity glow.
_Avoid_: Emblem card, Boon card, Status card

**Battlefield Face**:
How a permanent is drawn on the battlefield: the top of its Frame (name box or crown) and a border around its art, a large power/toughness box, and a chip for each keyword it has. It shows no other text, and turns sideways and darkens when tapped.
_Avoid_: Mini card, tile, token (a token is a rules term)

**Keyword Chip**:
The small square on a Battlefield Face that stands for one keyword the permanent has.
_Avoid_: Badge, tag

**Keyword Icon**:
The 16 × 16 pixel picture on a Keyword Chip that identifies its keyword.
_Avoid_: Sprite, glyph, symbol (mana symbols are a different thing)

**Inspector**:
Where a card is read in full during an encounter, the pregame included. It takes the sidebar's place while a card is pinned, and shows that card's Card Face, its State List and its Reminders. An ability on the stack is read as the card it came from. A pinned Emblem is shown on its Emblem Face, and a pinned Potion as its Potion Icon enlarged, with its name, the type line "Potion" and its rules text. Hovering over a card shows nothing.
_Avoid_: Card viewer, tooltip, preview (a Tap Preview is a different thing), zoom

**Pinned card**:
The card a right-click puts in the Inspector, ringed where it is drawn. A right-click on another card pins that one instead. A second right-click on it, a right-click on empty space, a left-click anywhere outside the Inspector or Escape lets it go. Nothing is pinned while a card or a trigger is being dragged.
_Avoid_: Selected card (the deckbuilder's), locked card, focused card

**Original**:
A card as its Card Definition has it: no Mods, no Hexes and nothing an encounter has done to it. The Inspector shows it in place of the card as it is now while View Original is pressed. A token or an Emblem has none.
_Avoid_: Base card, printed card, unmodified card

**State List**:
The Inspector's list of what is true of a permanent right now that its Card Face does not say, such as damage marked on it and each effect on it with where the effect came from. The Inspector draws whatever entries it is given, so a new kind of state adds an entry and changes nothing else.
_Avoid_: Status list (a Status is the Hero's), buffs, modifiers

**Reminder**:
What one keyword means, in a sentence, shown in the Inspector beside its Keyword Icon. Card Faces leave Reminders off.
_Avoid_: Reminder text (the real cards' parenthesized words), tooltip, help text

**Rarity**:
How scarce a card or a Potion is: Common, Uncommon, Rare, Mythic or Power-9. It is part of the card's design, set on its Card Definition, and no rule reads it. The Inspector glows around the card in the Rarity's color: gray, silver, gold, honey and light green.
_Avoid_: Tier (a part of a run), quality, grade
