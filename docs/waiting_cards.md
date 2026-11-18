# Waiting cards

The real cards `/add-card` triaged and has not added yet (ADR 0040), grouped by what each one waits on. A bare `/add-card` starts here, with the Ready group first.

- **Ready**: nothing; they were over a session's 20.
- **Blocked**: new primitives, under a heading for each.
- **Set Aside**: something new on screen, which starts with a GUI prototype.
- **Unsuited**: can never mean anything here, and is never proposed.

## Blocked

### Hybrid mana ({B/R})

- **Cultbrand Cinder** ({4}{B/R}, Creature — Elemental Shaman, 3/3): "When this creature enters, put a -1/-1 counter on target creature." Its ability is Ready since counters; it waits on a mana symbol payable with either of two colors, which the engine's mana costs and the card tool's reading both lack.

## Set Aside

### Searching a library

Choosing cards from a library is a new decision on screen; the encounter's pile window may be where its prototype starts.

- **Bushwhack** ({G}, Sorcery): "Choose one — • Search your library for a basic land card, reveal it, put it into your hand, then shuffle. • Target creature you control fights target creature you don't control." After the search, its second mode still needs a fight effect.
- **Ominous Parcel** ({1}, Artifact): "{2}, {T}, Sacrifice this artifact: Search your library for a basic land card, reveal it, put it into your hand, then shuffle. {5}, {T}, Sacrifice this artifact: It deals 4 damage to target creature." After the search, both abilities still need a sacrifice-this-artifact cost.
- **Oreskos Explorer** ({1}{W}, Creature — Cat Scout, 2/2): "When this creature enters, search your library for up to X Plains cards, where X is the number of players who control more lands than you. Reveal those cards, put them into your hand, then shuffle." After the search, it still needs X as the number of players who control more lands than you (0 or 1 one-on-one).
- **Topiary Panther** ({4}{G}{G}, Creature — Plant Cat, 6/5): "Trample. Basic landcycling {1}{G}." Landcycling is a new action on a card in hand, and it searches the library; after that, it still needs an ability activated from hand with a discard-this-card cost.

### Paying life as a land enters

- **Temple Garden** (Land — Forest Plains): "As this land enters, you may pay 2 life. If you don't, it enters tapped." The yes/no choice is new on screen (ADR 0052's as-enters choice is the closest); after it, it still needs a replacement that makes it enter tapped unless the life is paid. Its mana already comes from its Forest and Plains subtypes.
