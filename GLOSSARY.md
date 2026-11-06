# ModMox Game

The roguelike RPG around the rules engine: runs, characters, and everything that happens between encounters.

## Language

**Content**:
The Card Definitions authored for the game and shipped with it, such as the Alpha cards. The rules engine never contains or depends on Content.
_Avoid_: Card database, card pool, assets

**Frame**:
The template image a card is drawn on, chosen from its characteristics: one of 17 color categories (colorless, five colors, ten color pairs, gold) for creature, noncreature or land, in a normal or legendary version. A land's color category follows the colors of mana it can produce.
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
