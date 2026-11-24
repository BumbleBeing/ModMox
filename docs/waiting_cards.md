# Waiting cards

The real cards `/add-card` triaged and has not added yet (ADR 0040), grouped by what each one waits on. A bare `/add-card` starts here, with the Ready group first.

- **Ready**: nothing; they were over a session's 20.
- **Blocked**: new primitives, under a heading for each.
- **Set Aside**: something new on screen, which starts with a GUI prototype.
- **Unsuited**: can never mean anything here, and is never proposed.

## Blocked

### Copying a spell

- **Sage of the Skies** ({2}{W}, Creature — Human Monk, 2/3, Rare): "When you cast this spell, if you've cast another spell this turn, copy this spell." and "Flying, lifelink". Waits on three primitives: a "when you cast this spell" trigger that works while its card is on the stack, a condition for having cast another spell this turn (from `MmPlayer.spells_cast_this_turn`), and copying a spell, whose copy of a permanent spell becomes a token (CR 707.10, 608.3f). A copy on the stack has never been drawn, so its look may start with a prototype.

## Set Aside

### Looking at the top cards

- **Militia Bugler** ({2}{W}, Creature — Human Soldier, 2/3, Uncommon): "Vigilance" and "When this creature enters, look at the top four cards of your library. You may reveal a creature card with power 2 or less from among them and put it into your hand. Put the rest on the bottom of your library in a random order." `PowerFilter` gives "power 2 or less". Waits on a new decision on screen, the top four cards shown to their owner and one chosen from among them, which starts with a prototype; engine ADR 0080 left "from among them" after a look at the top cards out. Then a look effect that remembers the cards, as `MillEffect` does, and putting the rest on the bottom in a random order.

### Scry

- **Artificer's Assistant** ({U}, Creature — Bird, 1/1, Common): "Flying" and "Whenever you cast a historic spell, scry 1." Historic composes from existing Filters (an artifact, legendary or Saga spell). Waits on scry, a new decision on screen (cards to the top or the bottom), which starts with a prototype.
