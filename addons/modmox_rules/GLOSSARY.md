# ModMox Rules Engine

The rules engine that runs a single game of Magic-style cards between the player and one foe, following the structure of the Magic Comprehensive Rules so that unofficial and player-modified cards behave predictably.

## Cards

**Card Definition**:
The base design of a card: its name, costs, types, characteristics, abilities and rarity, as authored by the game designer.
_Avoid_: Card template, prototype, blueprint

**Run Card**:
A specific copy of a card owned by the player during a run, carrying any modifications earned outside of encounters.
_Avoid_: Deck card, upgraded card, card instance

**Modification**:
A single permanent change applied to a Run Card outside of an encounter, such as a new cost, name, or ability parameter.
_Avoid_: Upgrade, buff, patch, mod

**Original**:
The base Card Definition a card in an encounter was made from, before any Modification. A card is "originally named" by its Original's name, whatever its own name has become. A token that is a copy has the Original of what it copied; any other token has none and goes by its current name.
_Avoid_: Base card, printed card, source card

**Game Object**:
An object inside an encounter (a card in a zone, a spell on the stack, a permanent, a token, an ability on the stack), including everything currently affecting it in that game.
_Avoid_: Card (when an in-game object is meant), entity

**Printed Characteristics**:
The characteristics a card has before anything in an encounter affects it, worked out from its Card Definition alone. Deck and reward screens show these, and in-game characteristics start from them.
_Avoid_: Base stats, card data

**Card Identity**:
The identity of a physical card, which survives every zone change even though each move creates a new Game Object. Used only to relate Game Objects back to their Run Card, never by the rules.
_Avoid_: Card ID (when an object is meant), instance ID

**Token**:
A permanent that is not a card, made by an effect from a Token Definition and owned and controlled by the player whose spell or ability made it. It has no Card Identity and is never a Run Card. It enters the battlefield like any permanent and, if it dies, goes to the graveyard long enough to be seen dying; once it is anywhere but the battlefield, it ceases to exist.
_Avoid_: Card (a token never is one), copy (a token that copies something is a later kind), counter (a counter is a marker on a permanent)

**Token Definition**:
The Card Definition a token is made from: its name (its subtypes plus "Token", or the name the effect gives a predefined token, as the Wicked Role), color, types, power, toughness and abilities. Each is its own file in `content/tokens/`, so several cards can make the same token and its art is found by the file's name. A token's color comes from the definition's color indicator, since a token has no mana cost.
_Avoid_: Token card, token template

## Play

**Encounter**:
One complete game of Magic between the Hero and exactly one Villain. Run Cards cannot change during an encounter.
_Avoid_: Match, battle, duel

**Encounter Setup**:
The starting conditions of an encounter: both decks, each player's Emblems and Potions, starting life totals, opening hand sizes, free mulligans, who goes first, and the encounter seed.
_Avoid_: Game config, match settings

**Starting Life**:
The life total a player begins an encounter with, from the Encounter Setup (CR 103.4). It never changes during the encounter, so "your starting life total" means the same at any moment. A Hero's life does not carry from one encounter to the next.
_Avoid_: Max life, base life, initial health

**Free Mulligan**:
A mulligan that puts no cards on the bottom of the library. A player's first mulligans are free, up to the number granted in the Encounter Setup. Free Mulligans never count toward a hand owing every card it holds: a player who has paid a mulligan for each card in their hand is not asked again, keeps it, and puts all of it on the bottom in the order they choose.
_Avoid_: Bonus mulligan, mulligan charge

**Emblem**:
A Game Object in the command zone that has abilities but no other characteristics, used to give an encounter or a player rules that last the whole game. Its abilities are static, triggered or activated, and an activated one may be limited to once each game; an Emblem is never used up and never leaves. "Emblem" is not a card type.
_Avoid_: Encounter rule, modifier, aura (unless an actual Aura is meant)

**Potion**:
A Game Object in the command zone with one activated ability whose cost uses the Potion up, removing it from the game. A player's Potions are listed in the Encounter Setup apart from their Emblems, and the engine can say afterward which were used. It is not a card, cannot be targeted, and "Potion" is not a card type.
_Avoid_: Consumable, single-use Emblem, item (the game's word)

**Activation Restriction**:
A rule on an activated ability about when it may be activated, apart from its costs: only once each game, only once each turn, only as a sorcery, only while its permanent is attached to a creature, or only if a condition holds, as "only if a non-Skeleton creature died under your control this turn" (CR 602.5, ADR 0095). Checked wherever the engine decides which abilities to offer.
_Avoid_: Limit cost, charge, cooldown

**Spent**:
Said of a once-each-game ability that has been activated this game, whether or not it resolved, of a once-each-turn activated ability that has been activated this turn, whether or not it resolved, of a once-each-turn permission to cast from the top of a library that has been used this turn, from the moment the cast began, and of an ability that triggers only once each turn and has triggered this turn, whether or not it resolved. The source's Game Object keeps the mark, and its Object View shows it. A Spent once-each-turn ability, permission or trigger is ready again the next turn, whoever's it is.
_Avoid_: Used up (a Potion is used up; an Emblem never is), exhausted, tapped

**Hero**:
The player in an encounter who represents the human's character.
_Avoid_: Player (when this specific player is meant), user, human

**Villain**:
The player in an encounter who represents the adversary.
_Avoid_: Opponent (when this specific player is meant), enemy, foe, AI

**Agent**:
Whatever answers Pending Decisions on behalf of a player: the human through the GUI, or an AI. Usually the Hero has a Human Agent and the Villain an AI Agent, but either player can be driven by any Agent. A Human Agent is no Agent at all to the Encounter Driver, which stops and waits for the GUI's answer.
_Avoid_: Controller, input, brain

**Target Requirement**:
One instance of the word "target" on a spell or ability, with a Filter saying what may be chosen for it. An "up to" one, as in "up to two target creatures", chooses any number of different objects from none to its most, and can always be chosen, since none is a legal choice.
_Avoid_: Target slot, targeting rule

**Overload**:
A Modification that changes every "target" on an instant or sorcery to "each" (CR 702.96b), so the spell affects everything it could have targeted: overloaded Lightning Bolt deals 3 damage to each creature and each player. Its Target Requirements become Overloaded Requirements, and the spell targets nothing, so ward never triggers, protection keeps nothing out of what it finds, and it always resolves. An Adventure is a card of its own and keeps its targets, and so do an ability the spell grants and a token it creates. An overloaded "its controller" names a player once for each object of theirs, so "its controller gains 3 life" gains 3 for each.
_Avoid_: Mass spell, sweeper, each-mode

**Overloaded Requirement**:
A Target Requirement an Overload changed to "each". As the spell begins to resolve, it finds everything it could have chosen, where it would have looked (players and permanents, spells, abilities, or cards in graveyards), never the spell itself and however many its "up to" allowed, and what it finds then is fixed and shared by every effect, as targets are.
_Avoid_: Each requirement, overloaded target

**Modal Spell**:
An instant or sorcery that says "Choose one —" and lists its Modes (CR 700.2). Its controller chooses the Mode as it is cast, before any target; a Mode whose targets could not all be chosen can't be, and when only one can, it is chosen without asking.
_Avoid_: Charm (a card name, not a rule), choice spell

**Mode**:
One "•" line of a Modal Spell or of a modal triggered ability, with Target Requirements and effects of its own. The chosen Mode is all the spell or ability does. A modal triggered ability's controller chooses its Mode as they put it on the stack, before any target, by the same rules as a Modal Spell's; one with no Mode that can be chosen is removed instead.
_Avoid_: Option (an Option Menu's row), branch, choice

**Selection**:
Who or what an effect applies to: the target chosen for a Target Requirement, what an Overloaded Requirement found, each player or permanent matching a Filter, a permanent the controller chooses as the effect resolves ("a creature you control", not a target), or the controller.
_Avoid_: Target (unless an actual target is meant), recipient list, scope

**Filter**:
A condition a player or Game Object either meets or does not, such as "untapped land". Filters combine with all-of, any-of and not. A number a Filter compares with may be a Value worked out each time it is asked, as in "with toughness less than the number of basic land types among lands you control".
_Avoid_: Predicate, query, condition

**Pending Decision**:
A point where the engine has stopped because a player must make a choice, together with the legal options for that choice.
_Avoid_: Prompt, callback, request

**Action**:
Something a player may do while holding priority, such as passing, playing a land or casting a spell. A priority decision offers the legal Actions as its options.
_Avoid_: Move, play, command

**Mana of Any Color**:
Mana whose color is chosen as it is made, as a Treasure's "Add one mana of any color" (CR 106.1a). A mana ability that adds it is offered as one Action for each color, in WUBRG order, at priority and while paying, and the Action carries the color to the effect (ADR 0072).
_Avoid_: Color choice (nothing is asked: the color is the Action's), rainbow mana

**Adventure**:
An Adventurer card's second half (CR 715): an instant or sorcery with the subtype Adventure, printed on the left page of the card's book, which the card may be cast as from the hand instead of the creature. Cast that way, the spell has only the Adventure's characteristics (ADR 0078). A Mod never changes it.
_Avoid_: Back face, second face, split card

**Mill**:
To put the top cards of a library into its owner's graveyard (CR 701.17a). The spell or ability that mills remembers the cards milled, so a later effect of it can choose "from among them" (ADR 0080).
_Avoid_: Discard from the library, self-mill (as a term)

**Discard**:
To put a card from one's own hand into one's graveyard (CR 701.9a): discarding down to maximum hand size in cleanup (CR 514.1), or an effect's "discard a card". The player chooses which cards, and is asked only when there is a choice: holding that many cards or fewer, they discard them all.
_Avoid_: Mill (which takes from the library), sacrifice (which takes from the battlefield)

**On an Adventure**:
A card exiled as its Adventure resolved (CR 715.3d). Its owner may cast it from exile as the creature, never as the Adventure again, for as long as it stays there.
_Avoid_: Adventuring, exiled with an Adventure

**Exiled to Be Played**:
A card in exile marked with the player who may play it and the last Game Turn they may (engine ADR 0100), as Clockwork Percussionist's "exile the top card of your library. You may play it until the end of your next turn." marks it. That player may cast it with its usual timing, or play it as a land with a land play; the other player may not. The mark permits nothing once its turn is past, and stays with the old object when the card leaves exile.
_Avoid_: Impulse draw (as a term), castable from exile, exile permission

**Hybrid Symbol**:
A mana symbol in a cost that either of two colors pays, such as {B/R} (CR 107.4e). It counts one toward mana value and makes its card both colors. A unit of mana pays a plain symbol of its type before a Hybrid Symbol of its color, and that before generic mana (ADR 0077). Only two-color ones are in the game.
_Avoid_: Split symbol, dual symbol, either-or mana

**Turn Number**:
How many turns a particular player has begun this encounter; shown to people as "<name>'s Turn 3". A player who has not had a turn yet is on Turn Number 0.
_Avoid_: Game Turn (when one player's count is meant), round

**Game Turn**:
How many turns have begun in the encounter across both players. Rules that speak of "the first turn of the game" use it.
_Avoid_: Turn Number (when the overall count is meant), round

**Outcome**:
How an encounter ended: the Hero won, the Villain won, or a draw when both players lost at the same moment. The game around the engine reads it at the end of an encounter.
_Avoid_: Result, score, victory (when a draw is possible)

**Decision Log**:
Every accepted answer to a Pending Decision in an encounter, in order, plus any concession. Together with the Encounter Setup it reproduces the encounter exactly.
_Avoid_: Input history, move list, replay

**Undo Barrier**:
A point in an encounter that decisions cannot be undone past: when hidden information is revealed, randomness is used, something leaves the stack, or the other player gets a decision.
_Avoid_: Commit point, save point

**Event**:
A single change to the game, such as a card moving zones or a library being shuffled. It is proposed, offered to replacement effects, applied, and then recorded.
_Avoid_: Action, change, signal

**Event Log**:
Every Event performed in an encounter, in order. Triggers and the GUI learn what happened from it.
_Avoid_: History, game log

**Player View**:
Everything one player may legally see of the game, and nothing more. The GUI only ever reads a Player View. An AI Agent reads the real encounter only through its Player View and its World, and may read Simulation Copies freely.
_Avoid_: Snapshot, visible state

## Triggered abilities

**Pending Trigger**:
A triggered ability that has triggered but has not been put on the stack yet, together with what triggered it ("that player", "that creature") and the card it came from. One event may make several for one ability, one for each object it is about, as "blocks a creature" does for each attacker blocked.
_Avoid_: Queued trigger, trigger instance

**Reflexive Triggered Ability**:
A triggered ability that a resolving ability creates as its controller takes the action it offers, "When you do, [ability]", as Kishla Trawlers's "you may exile a creature card from your graveyard. When you do, return target instant or sorcery card from your graveyard to your hand." (CR 603.12). It has no trigger of its own: it triggers as the action is taken, waits as a Pending Trigger, and goes on the stack the next time a player would receive priority, its targets chosen then, so the opponent may respond to it. Its source is the ability's source, as it last existed if it has gone (ADR 0088).
_Avoid_: Follow-up ability, "if you do" (an effect of the same ability, which uses no stack), delayed trigger

**Batch**:
Events that happen at the same moment, such as everything state-based actions do at once or all combat damage in a step. Triggers are looked for once, after the whole batch. A trigger that says "one or more", as "Whenever one or more other creatures you control leave the battlefield without dying", triggers once for a batch however many of its events it matches.
_Avoid_: Transaction, group

**Becomes Tapped**:
An untapped permanent changing to tapped, for any reason: attacking, paying a {T} cost, or an effect, as in "Whenever this creature becomes tapped" (CR 603.2). A permanent that enters the battlefield tapped never becomes tapped, and one already tapped can't become tapped again.
_Avoid_: Is tapped (that is a state, not a change), taps (a player taps a permanent; the permanent becomes tapped)

**Counters Put**:
Counters being put on a permanent, by an effect or as it enters with them (CR 122.6), as in "Whenever one or more +1/+1 counters are put on this creature". An effect puts its counters on each permanent at once, so it triggers such an ability once for each permanent it reaches, however many counters go there.
_Avoid_: Gets counters, counters added

**Life Gain**:
One source causing a player to gain life (CR 119.9): a gain life effect, or the damage of one source with lifelink in one Batch, however many recipients it has. "Whenever you gain life" triggers once for each, so two lifelink creatures dealing combat damage together trigger it twice (ADR 0082). Gaining 0 life is no life gain. The life a player gained this turn is kept on the player, effects and lifelink alike, for "if you gained life this turn" (ADR 0082's addendum).
_Avoid_: Life gain event (lifelink's gain is part of its damage, not an Event of its own), lifegain trigger

**Life Loss**:
A player losing life (CR 119.3): from damage (CR 120.3a), from an effect such as "each opponent loses 1 life", or from paying life (CR 119.4). Losing 0 life is no life loss. The life a player lost this turn is kept on the player, every kind alike, for "if an opponent lost life this turn" (engine ADR 0082's second addendum).
_Avoid_: Damage (which is one way to lose life, and which prevention stops), life payment (paying life is a life loss)

**Legend Rule**:
A state-based action: a player who controls two or more legendary permanents with the same name chooses one to keep, and the rest are put into their owners' graveyards with the other state-based actions of that moment (CR 704.5j).
_Avoid_: Legendary uniqueness, legend check

**Known Card**:
A card in a library or a hand that a player knows the identity of, because they saw it put there: one they put on the bottom from their hand, for instance, one they kept on top of their library with a surveil (ADR 0068), or one the other player found with a search and revealed (ADR 0057). A shuffle of that library makes every card in it unknown again. A Known Card in a hand stops being known when it leaves the hand, or when any card leaves a hand of two or more cards for the library without being revealed. A Player View shows Known Cards to the players who know them and nothing of the rest.
_Avoid_: Revealed card, seen card, tracked card

**Last-Known Information**:
What an object was like the last time it was on the battlefield or in a graveyard, kept after it leaves so that "dies" triggers, "its power" and "if it was a permanent card" still have an answer.
_Avoid_: Ghost, snapshot (in rules talk), LKI (in code)

**Flashback**:
A keyword that lets its card be cast from its owner's graveyard by paying its flashback cost instead of its mana cost, with its card type's usual timing; cast that way, it is exiled instead of going anywhere else as it leaves the stack (CR 702.34a). Its cost may have no mana in it, or parts that are not mana, such as "Pay 3 life" or "Tap three untapped creatures you control" (ADR 0048).
_Avoid_: Recast, graveyard cast, rebuy

**Cycling**:
A keyword, "Cycling [cost]": "[Cost], Discard this card: Draw a card", an activated ability that works only while its card is in its owner's hand, whenever they have priority (CR 702.29). Discarding the card is part of the cost, paid once the mana is, so the card is gone even if the ability is countered (ADR 0059). Every other activated ability works anywhere but the hand. Typecycling, such as "Basic landcycling [cost]", is cycling that searches your library for a card of that quality, reveals it and puts it into your hand instead of drawing (CR 702.29e).
_Avoid_: Cycle away, recycle, loot (a different action: draw, then discard)

**Improvise**:
A keyword of a spell: "Your artifacts can help cast this spell. Each artifact you tap after you're done activating mana abilities pays for {1}" (CR 702.126a). While its mana is paid, each untapped artifact its caster controls may be tapped to pay one generic mana, never a colored symbol. It is not the artifact's {T}, so one with summoning sickness may (engine ADR 0099).
_Avoid_: Convoke (creatures, and colored mana too), tap for mana (an artifact need have no mana ability)

**Undying**:
A keyword: "When this creature dies, if it had no +1/+1 counters on it, return it to the battlefield under its owner's control with a +1/+1 counter on it" (CR 702.93a). "It" is the card the creature became in the graveyard, so a card that has left the graveyard since stays where it is, and a token never comes back (engine ADR 0096).
_Avoid_: Comes back, recursion, persist (the same with -1/-1 counters)

**Additional Cost**:
A cost a spell asks for besides its mana cost or alternative cost, "As an additional cost to cast this spell, [cost]" (CR 601.2f, 118.8), as Fear of Isolation's "return a permanent you control to its owner's hand". The spell may be cast only while it can be paid. Its choice is asked once the mana is paid, so a land just tapped for mana may be returned for it (ADR 0086), and it stays paid whatever becomes of the spell.
_Avoid_: Extra cost, kicker (an optional one), cost increase

**Alternative Cost**:
A cost paid instead of a spell's mana cost (CR 118.9). Flashback's and bestow's are alternative costs that come with their keywords; "You may pay {3}{U} and tap an untapped artifact you control rather than pay this spell's mana cost" is one on its own, a static ability of the spell. Its card is then offered a second cast from the hand, for that cost, whose choices are asked before the mana is paid (ADR 0093). Cost reductions take mana off it as they do off a mana cost, and the spell's mana value is still its mana cost's.
_Avoid_: Free cast, replacement cost, optional cost (an additional one, such as kicker)

**Cost Reduction**:
A static ability of a spell that makes it cost less to cast: "This spell costs {1} less to cast for each basic land type among lands you control" takes off as much generic mana as a Value comes to, and affinity ("This spell costs {1} less to cast for each Cat you control", CR 702.41a) one for each matching permanent. What it takes off may be generic or colored mana, and comes off the mana cost or an alternative cost such as a flashback cost, by CR 118.7, as the cast begins (CR 601.2f). The spell's mana value never changes (ADR 0050). An activated ability may carry its own, as part of its text: "This ability costs {1} less to activate for each basic land type among lands you control" (CR 602.2b) takes generic mana off its mana cost as the activation begins. A permanent may make its controller's spells cost less too: "The second spell you cast each turn costs {1} less to cast" takes generic mana off the caster's second spell this turn, counting the spells cast before the permanent arrived (ADR 0050's addendum). A Cost Reduction may hold a condition, "This spell costs {3} less to cast if you've cast another spell this turn", and take its mana off only while that is true as the cast begins (ADR 0050's second addendum).
_Avoid_: Discount, cheaper cost, cost modifier

**Linked Abilities**:
Two abilities of one object where the second refers to what the first did, as Oblivion Ring's "exile another target nonland permanent" and "return the exiled card" are (CR 607). A card the first exiles remembers the object that exiled it, and the second finds only the cards that object exiled. An exile nothing links to, such as Lion Sash's, leaves its cards remembering nothing. An object that changes zones is a new object, so the link does not follow it.
_Avoid_: Paired abilities, remembered card, hostage

**Exile Until**:
An exile that lasts until the object that did it leaves the battlefield, as Leyline Binding's "exile target nonland permanent an opponent controls until this enchantment leaves the battlefield" (CR 610.3). It is one effect, not two Linked Abilities: the card comes back to the battlefield under its owner's control by itself, with nothing on the stack, right after that object leaves, before anything else happens. If the object has already left when the exile would happen, nothing is exiled (CR 610.3c). A token exiled this way ceases to exist and never comes back (ADR 0065).
_Avoid_: Temporary exile, O-Ring effect, banish

**Condition**:
Something true or false about the game right now, such as "this permanent is untapped", used for an intervening "if" clause, for "as long as", for an effect that happens instead of another while it holds ("If this is the second time this ability has resolved this turn, ... instead", CR 608.2c), and for one that happens only while it does not ("discard a card unless you control another creature with power 2 or less").
_Avoid_: Predicate, check (Filter is the word when a player or object either matches or not)

**May Effect**:
An effect its controller may choose not to do, "You may [effect]." (CR 603.5, 608.2d). The spell or ability is put on the stack and its targets chosen whatever its controller means to do (CR 603.3d); as the effect begins they are asked yes or no, and the effect happens only on yes. Saying no is not failing to resolve, so the effects after it still happen. "If you do, [effect]" after it happens only on yes, as in "you may draw a card. If you do, discard a card."; the answer is remembered as the spell or ability resolves, and the effect's own decision, which card to discard, is asked only then.
_Avoid_: Optional trigger (the ability is not optional, only the effect is), may ability

**Pay X Effect**:
An effect that offers a cost to pay as it resolves, "You may pay {X}. If you do, [effect]." (CR 107.3, 608.2d, ADR 0061). As it begins its controller chooses an X, up to the most they could pay, or declines; X is then paid one step at a time as a cast's mana is, mana abilities included (CR 605.3a), and only then does the effect it wraps begin. Paying X = 0 is paying. Declining does nothing, and is not failing to resolve. For now only the Villain pays X: the Hero's screen has no input for choosing X yet, so it declines for them. The Hero does pay costs on resolution, as ward's.
_Avoid_: X cost (an X in a mana cost is chosen as the spell is cast), kicker

**Ward**:
A keyword, "Ward [cost]": whenever the permanent becomes the target of a spell or ability an opponent controls, counter it unless that player pays [cost] (CR 702.21a, ADR 0062). It triggers as the target is chosen and refers to the spell or ability without targeting it. As it resolves, the controller of that spell or ability is asked whether to pay, but only if they could. A yes is paid as a cast's mana is; a no, or a cost they could not pay, counters it.
_Avoid_: Protection, hexproof (different keywords)

**Unless Paid**:
A counter effect's cost that the controller of what it would counter may pay to keep it, "counter [it] unless its controller pays [cost]" (CR 118.12), as ward's is. They are asked yes or no as the effect begins, and only while it is still on the stack and they could pay.

**Paid X**:
The X paid for a Pay X Effect, kept for the rest of that spell or ability's resolution: the effect it wraps and every effect after it read it, as "X" in "mana value X or less" or "you gain X life". It is 0 when none was paid.
_Avoid_: Chosen X, X value

## Continuous effects

**Continuous Effect**:
A change to characteristics that lasts, such as "white creatures get +1/+1" or "+3/+3 until end of turn". It comes from a static ability, applying to whatever matches right now, or from a resolved spell or ability, applying to what it found when it resolved. One from a resolved spell that states no duration, as Bring to Life's "becomes a 0/0 artifact creature", lasts for the rest of the encounter, on the object it found (ADR 0091).
_Avoid_: Buff, modifier, aura (unless an actual Aura is meant)

**Layer**:
One step in the fixed order in which continuous effects apply: copy, control, text, type, color, abilities, then power and toughness (characteristic-defining, setting, modifying).
_Avoid_: Pass, stage

**Timestamp**:
When an object entered its zone or a continuous effect was created. Within a layer, earlier timestamps apply first. An object's ID is its timestamp.
_Avoid_: Creation order, age

**Characteristic-Defining Ability**:
An ability that works out a characteristic, such as "its power and toughness are each equal to the number of non-Wall creatures you control". It may work out power alone, as on a */3 creature, or toughness alone, and the other number is the printed one. It works in every zone, and its card shows "*" for each number it works out.
_Avoid_: Variable stats, star ability

## Replacement effects

**Replacement Effect**:
An effect that waits for a particular event and changes it as it would happen, such as "the next time this creature would be destroyed this turn, instead tap it". When several apply to one event, the affected player chooses the order.
_Avoid_: Override, interceptor, hook

**Prevention Effect**:
A replacement effect that stops damage from being dealt: all of it, or up to an amount. Prevented damage is never dealt, so nothing that reacts to damage sees it.
_Avoid_: Damage reduction, absorb, block (blocking is combat)

**Scry**:
A keyword action: its player looks at the top N cards of their library, puts any number of them on the bottom of it in any order and the rest back on top in any order (CR 701.22a). It is asked and answered as a surveil is, with the cards sent to the bottom, the last sent the deepest, and the order of the rest; no card leaves the library, and every card looked at becomes a Known Card to its owner (ADR 0087).
_Avoid_: Surveil (which puts cards into the graveyard), look at the top cards (which takes one into the hand)

**Explore**:
A keyword action of a permanent: its controller reveals the top card of their library. A land card goes into their hand; otherwise the permanent gets a +1/+1 counter and they may put the revealed card into their graveyard, a choice asked as a surveil of that one card is (CR 701.44a). The card is known to both players. A permanent that has left the battlefield still explores, and gets no counter. A Map, a predefined token, makes a creature explore (ADR 0090).
_Avoid_: Surveil (which looks without revealing), scout, venture

**Surveil**:
A keyword action: its player looks at the top N cards of their library, puts any number of them into their graveyard and the rest back on top in any order (CR 701.25a). One decision, asked as the effect begins and answered once with the cards graveyarded and the order of the rest; the cards kept become Known Cards to their owner (ADR 0068).
_Avoid_: Scry (which puts cards on the bottom), mill (which chooses nothing)

**Shield**:
A replacement or prevention effect that is used up as it applies, such as "prevent the next 1 damage" or a regeneration shield. The GUI shows what each one has left and the card it came from.
_Avoid_: Buffer, barrier, charge

**Protection**:
"Protection from [quality]": a permanent with it can't be dealt damage, blocked, or targeted by anything with that quality, which is a Filter, such as "black" or "creatures".
_Avoid_: Immunity, ward (a different keyword), hexproof (a different keyword)

**Hexproof**:
A keyword: the permanent can't be the target of spells or abilities its controller's opponents control (CR 702.11b). Its controller may still target it, and an effect that does not target, such as an overloaded spell's, still reaches it. It is checked wherever protection is: as targets are chosen and again as the spell or ability resolves.
_Avoid_: Shroud (no player may target it), ward, protection (different keywords)

**Chosen Creature Type**:
The creature type chosen for a permanent with "As this enters, choose a creature type" as it enters (ADR 0052), before it is on the battlefield, and kept on it from the moment it arrives, so its abilities that say "the chosen type" mean it at once. It is chosen from every creature type there is (CR 205.3m), is public, and is forgotten when the permanent leaves, since it becomes a new Game Object.
_Avoid_: Named type, selected type, tribe

**Draw**:
A player taking the top card of their library into their hand, one card at a time (CR 121.2). Replacement effects see each draw before its card is known, so a draw that replaces another takes whatever is on top as it happens, and a draw from an empty library can be replaced too (CR 614.11, engine ADR 0097).
_Avoid_: Draw event (unqualified), pull, card advantage

**Suspended Batch**:
A batch of events that stopped part-way because a player must choose which replacement effect applies first. It is kept in the game state until they answer, and then carries on.
_Avoid_: Paused event, pending event, interrupted batch

## Combat

**Combat**:
Which creatures are attacking and blocking, which player is defending, and which creatures have already struck first. It is part of the game state, and empty outside the combat phase.
_Avoid_: Battle (a card type in Magic), fight (a keyword action: see Fight)

**Attacks**:
A creature being declared as an attacker (CR 508.1), as in "Whenever this creature attacks" (CR 508.3a). A creature put onto the battlefield attacking is attacking but never attacked (CR 508.4). A player attacked this turn once they declared one or more attackers in it, as raid's "if you attacked this turn" asks (engine ADR 0095's addendum).
_Avoid_: Is attacking (that is a state)

**Blocks**:
A creature blocks as it is declared as a blocker (CR 509.1); it blocks a creature once for each attacker it is declared blocking (CR 509.3b). A creature put onto the battlefield blocking is blocking but never blocked (CR 509.7).

**Assigning by Toughness**:
A creature assigning combat damage equal to its toughness rather than its power (CR 510.1a) because a static ability says so, as Bark of Doran's does for the creature it equips while that creature's toughness is greater than its power. Only the amount of combat damage changes: its power is unchanged for everything else, fighting included, and it gains no ability.
_Avoid_: Toughness damage, "deals damage with its toughness"

**Fight**:
A keyword action: two creatures each deal damage equal to their power to the other, at once (CR 701.14a), as Bushwhack's "Target creature you control fights target creature you don't control". The creatures are the sources, so deathtouch and lifelink apply, and it is not combat damage. If either has left the battlefield, is no longer a creature or has become an illegal target, neither deals any (CR 701.14b). Overloaded, "each creature you control fights each creature you don't control", every creature on one side fights every creature on the other, all at once: each deals damage equal to its power to each creature on the other side.
_Avoid_: Duel, brawl, combat (fighting is not combat)

**Summoning Sickness**:
A creature cannot attack or pay {T} until its controller has controlled it continuously since the start of their most recent turn. The engine works this out from when control began; nothing has to clear it.
_Avoid_: Sick (on its own), fresh, exhausted

**Exert**:
To exert a permanent, as part of a cost such as Pride Sovereign's "{W}, {T}, Exert this creature", is to have it not untap during the next untap step of the player who exerted it (CR 701.43). The permanent remembers that player, and that untap step ends its exertion whether it was tapped then or not. Exerting it again before then still skips only that one untap step, and a permanent that changes zones is a new object, not exerted.
_Avoid_: Tired, "doesn't untap" (that is the effect, not the action)

**Skipped Untap**:
What an effect such as Niblis of Frost's "That creature doesn't untap during its controller's next untap step" leaves on a permanent (CR 502.3, ADR 0092): the next untap step of whoever controls it leaves it tapped and ends the Skipped Untap, whether it was tapped then or not. The other player's untap steps leave it alone, and a permanent that changes zones is a new object without it. Unlike exert, it follows the permanent's controller, not a player named as it happened.
_Avoid_: Frozen, stunned (a stun counter is another thing), exerted (which is the cost)

**Sacrifice**:
To sacrifice a permanent is for its controller to move it from the battlefield to its owner's graveyard (CR 701.21a), as Ominous Parcel's cost "Sacrifice this artifact" does, or Selfcraft Mechan's "you may sacrifice an artifact", whose payer chooses which (ADR 0088's addendum), or as an effect, as Agent of the Fates's "each opponent sacrifices a creature", whose player chooses which as it resolves (ADR 0088's second addendum). Only its controller can, and it is not destruction, so indestructible and regeneration never stop it. A sacrificed creature dies, and an ability whose cost sacrificed its source resolves from the source's last-known information. "The sacrificed creature", or "that creature" after a sacrifice, is what the spell or ability itself sacrificed, as a cost or by an earlier effect of its own, seen from its Last-Known Information, so its power and toughness are what they were (engine ADR 0098).
_Avoid_: Destroy (which indestructible stops), discard (which is from a hand)

**Marked Damage**:
Damage dealt to a creature, which stays on it until the cleanup step removes it.
_Avoid_: Wounds, damage counters (counters are something else)

**Counter**:
A marker on a permanent that stays until the permanent leaves the battlefield or the counter is removed. There are two kinds so far, +1/+1 and -1/-1, each changing power and toughness by that much; a permanent with both loses the same number of each. Doubling the number of a kind of counters on a permanent puts on as many more as it has (CR 701.10e). A counter is not a characteristic, and never means countering a spell.
_Avoid_: Token (a token is a permanent that is not a card), marker, buff, stack (for a number of counters)

**Attachment**:
A permanent attached to another, as an Equipment is to the creature it equips or an Aura to what it enchants. An Equipment stays on the battlefield in its own right: when what it is attached to leaves, or may no longer have it, it becomes unattached and stays. An Aura does not: it goes to its owner's graveyard (see Aura). "Equipped creature" is what an Equipment is attached to, and an equipped permanent is one with at least one Equipment attached to it. Equip is the keyword that attaches one, to a creature its controller controls and only as a sorcery. Reconfigure is the keyword of an Equipment that is also a creature: it attaches the Equipment to another creature its controller controls, or unattaches it, only as a sorcery, and while attached the Equipment is not a creature. Only an Equipment with reconfigure may be attached while it is a creature.
_Avoid_: Gear, item (an Item is a Potion or a Boon), child, parent, host; "the equipment's owner" for the creature it is on

**Aura**:
An enchantment that is an Attachment from the moment it enters, made so by its enchant ability, such as "Enchant land", which says what it may be attached to. An Aura spell targets what it will enchant, and if that target is gone as it resolves it goes to its owner's graveyard instead of entering; otherwise it enters attached to it. An Aura attached to something it may not enchant, or to nothing, is put into its owner's graveyard (CR 704.5m). "Enchanted land" is what an Aura is attached to, and "this Aura" what an Aura calls itself.
_Avoid_: Enchantment (an Aura is one kind, and most enchantments are not Auras), buff, modifier; "falls off" (an Aura is put into the graveyard, an Equipment becomes unattached)

**Role**:
An Aura token with the subtype Role, created attached to a creature, as Price of Beauty's "Create a Wicked Role token attached to target creature you control" (CR 111.10, 303.7). A token created attached enters already attached, and one that could not legally be attached is never created. A player keeps one Role on each permanent: when a permanent has two or more Roles of the same player attached, all but the newest go to their owner's graveyard, a state-based action (the Role rule, ADR 0044's addendum). A Role is named by its name, not by its subtypes and "Token".
_Avoid_: Role Token as its name, buff token, costume

**Bestow**:
A keyword, "Bestow [cost]" (CR 702.103): its card, an enchantment creature, may be cast from the hand for that cost instead of its mana cost, as an Aura spell with enchant creature that is no creature. That spell and the Aura it resolves into are bestowed. If its target is gone as it resolves it ceases to be bestowed and enters as an enchantment creature, and once a bestowed Aura becomes unattached it ceases to be bestowed and stays on the battlefield as an enchantment creature, rather than going to its owner's graveyard as an Aura would (ADR 0089).
_Avoid_: Aura mode, bestowed creature (bestowed, it is no creature), "falls off"

**Damage Division**:
An attacker's controller choosing how its combat damage is split among the creatures blocking it, and with trample the player it attacks. There is no damage assignment order. The GUI shows it as a damage-split popup.
_Avoid_: Damage assignment order (removed from the rules), damage ordering

## Randomness

**Encounter Seed**:
The single number from which all randomness in an encounter is derived, making the encounter exactly replayable from its seed and its decisions.
_Avoid_: Random seed, game ID

**Game RNG**:
The randomness used by the rules themselves (shuffles, random discards, coin flips), hidden from both players.
_Avoid_: RNG (unqualified)

**AI RNG**:
The randomness an AI Agent uses to choose among options and to re-deal Simulation Copies, which never affects the Game RNG. Each decision gets a fresh stream from the Encounter Seed, the player and how many decisions came before, so the same decision gets the same numbers after a save and reload.
_Avoid_: RNG (unqualified)

## AI Agents

**Encounter Driver**:
What runs an encounter by asking each player's Agent for answers, stopping where a player has no Agent and a human must decide.
_Avoid_: Game loop, match runner, controller

**Simulation Copy**:
An engine copied from a real one to look ahead on, as one player might imagine the game: the cards they cannot see are re-dealt at random, the Game RNG is reseeded, and nothing can be undone. Playing on it never changes the real encounter.
_Avoid_: Clone, snapshot, sandbox, lookahead state

**Simulation Source**:
What an Agent is handed with each decision: its AI RNG, its World, and Simulation Copies to play on. Never the real game state.
_Avoid_: Engine handle, oracle (unqualified)

**World**:
The game as an Agent's player might imagine it at one decision: the real game with every card they cannot see re-dealt. Inside a Simulation Copy, the copy itself.
_Avoid_: Belief state, guess

**Board Evaluator**:
What turns a game state into one number from a player's point of view: their side's worth minus the other side's, counting life, cards in hand and permanents as they are now. A noncreature token used up by its own abilities, as a Treasure is, counts as a cheap card in hand (ADR 0088's addendum).
_Avoid_: Heuristic (unqualified), fitness, score function

**Combat Oracle**:
What answers "if these attack and these block, what happens?" by running the engine's own combat on a Simulation Copy.
_Avoid_: Combat math, damage predictor

**Timing Tag**:
When a spell or ability is worth considering, worked out from what its effects do: a combat trick only in a fight or a response, evasion (a trick that only grants abilities) from the declare attackers step so it can change who blocks whom, removal (damage, fights, destruction and -1/-1 counters) also in its controller's main phases and the other player's end step, a counter only with the other player's spell or ability on top of the stack. A permanent spell has none, unless it has flash and its own "enters" trigger is removal or a trick: then it has that trigger's; or its own "enters" trigger works only if its controller attacked this turn (raid): then it is considered only in their postcombat main phase. It never decides whether a play is good.
_Avoid_: AI hint, card flag, AILogic

**AI Profile**:
An AI Agent's temperament as a saved, moddable resource: whether it plays first, its mulligan land range, how readily it trades in combat, when its life is in danger, what the Board Evaluator thinks things are worth, and how much more or less than its AI Difficulty it searches.
_Avoid_: Villain Profile, difficulty, personality file

**AI Difficulty**:
A global, game-side setting for how hard the AI plays, as a saved, moddable resource. It only sets how much the AI searches: whether it uses Rollouts, how many candidates and samples, whether a combat trick is judged after it has worn off, and how long a Repeat Plan may be. It never adds mistakes or lets the AI cheat.
_Avoid_: Skill level, AI level, handicap

**Rollout**:
One candidate answer played out on a Simulation Copy, by heuristic Agents for both players, through the rest of the Game Turn and the whole next one, then scored by the Board Evaluator. Flat Monte Carlo compares candidates by their Rollouts on the same re-dealt worlds and keeps the one-step pick unless another clearly beats it.
_Avoid_: Playout, simulation (unqualified), search

**Repeat Plan**:
One activated ability activated several times in a row, each after the last has resolved, compared as a single candidate answer. The Agent submits only the first activation and judges again when it next has priority.
_Avoid_: Multi-activation, pump chain, combo

**AI Log**:
A file written for each real encounter, beside the Run Logs, of every answer the Villain's AI Agent gave and why: the Game Turn and step, the decision, the answer with its cards' names, the reason, how long it took, the options and their scores. It is for reading a bad play back after a playtest; it never changes an answer and nothing replays it. A forced pass and mana payments are left out.
_Avoid_: AI trace, debug log, Run Log (which records the choices themselves)

**Tournament**:
Two AI contenders, each an AI Profile and an AI Difficulty, playing many seeded encounters with the seats swapped on each seed, to measure which plays better. It is how AI settings are tuned.
_Avoid_: Match, ladder, self-play run
