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
One stop on a Stage's map: an encounter, a trove or a special event.
_Avoid_: Event (an engine term for a change to the game), room, space

## Presentation

**Encounter Screen**:
What shows an encounter to the human and takes their answers.
_Avoid_: Battle screen, game view, board

**Card Face**:
A card drawn in full: its Frame, name, mana cost, type line, rules text and power/toughness. Used wherever a card is read rather than played on.
_Avoid_: Full card, card image

**Battlefield Face**:
How a permanent is drawn on the battlefield: the top of its Frame (name box or crown) and a border around its art, a large power/toughness box, and a chip for each keyword it has. It shows no other text, and turns sideways and darkens when tapped.
_Avoid_: Mini card, tile, token (a token is a rules term)
