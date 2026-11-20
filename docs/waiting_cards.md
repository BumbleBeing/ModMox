# Waiting cards

The real cards `/add-card` triaged and has not added yet (ADR 0040), grouped by what each one waits on. A bare `/add-card` starts here, with the Ready group first.

- **Ready**: nothing; they were over a session's 20.
- **Blocked**: new primitives, under a heading for each.
- **Set Aside**: something new on screen, which starts with a GUI prototype.
- **Unsuited**: can never mean anything here, and is never proposed.

## Blocked

### Hybrid mana ({B/R})

- **Cultbrand Cinder** ({4}{B/R}, Creature — Elemental Shaman, 3/3): "When this creature enters, put a -1/-1 counter on target creature." Its ability is Ready since counters; it waits on a mana symbol payable with either of two colors, which the engine's mana costs and the card tool's reading both lack.
