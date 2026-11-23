# Waiting cards

The real cards `/add-card` triaged and has not added yet (ADR 0040), grouped by what each one waits on. A bare `/add-card` starts here, with the Ready group first.

- **Ready**: nothing; they were over a session's 20.
- **Blocked**: new primitives, under a heading for each.
- **Set Aside**: something new on screen, which starts with a GUI prototype.
- **Unsuited**: can never mean anything here, and is never proposed.

## Set Aside

### Scry

- **Warden of the Inner Sky** ({W}, Creature — Human Soldier, 1/2, Rare): "As long as this creature has three or more counters on it, it has flying and vigilance." and "Tap three untapped artifacts and/or creatures you control: Put a +1/+1 counter on this creature. Scry 1. Activate only as a sorcery." Waits on scry, a new decision on screen (cards to the top or the bottom), which starts with a prototype; and on counting counters of every kind together, where HasCountersFilter counts one kind.

