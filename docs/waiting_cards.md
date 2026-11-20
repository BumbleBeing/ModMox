# Waiting cards

The real cards `/add-card` triaged and has not added yet (ADR 0040), grouped by what each one waits on. A bare `/add-card` starts here, with the Ready group first.

- **Ready**: nothing; they were over a session's 20.
- **Blocked**: new primitives, under a heading for each.
- **Set Aside**: something new on screen, which starts with a GUI prototype.
- **Unsuited**: can never mean anything here, and is never proposed.

## Blocked

### Hybrid mana ({B/R})

- **Cultbrand Cinder** ({4}{B/R}, Creature — Elemental Shaman, 3/3): "When this creature enters, put a -1/-1 counter on target creature." Its ability is Ready since counters; it waits on a mana symbol payable with either of two colors, which the engine's mana costs and the card tool's reading both lack.

### Fight

- **Bushwhack** ({G}, Sorcery): "Choose one — • Search your library for a basic land card, reveal it, put it into your hand, then shuffle. • Target creature you control fights target creature you don't control." Its search is built (ADR 0057); its second mode needs a fight effect (CR 701.14).

### A "sacrifice this permanent" cost

- **Ominous Parcel** ({1}, Artifact): "{2}, {T}, Sacrifice this artifact: Search your library for a basic land card, reveal it, put it into your hand, then shuffle. {5}, {T}, Sacrifice this artifact: It deals 4 damage to target creature." Its search is built; both abilities need a cost that sacrifices the artifact itself.

### A count of the players who control more lands than you

- **Oreskos Explorer** ({1}{W}, Creature — Cat Scout, 2/2): "When this creature enters, search your library for up to X Plains cards, where X is the number of players who control more lands than you. Reveal those cards, put them into your hand, then shuffle." Its search is built; it needs X as a Value (0 or 1 one-on-one).

## Set Aside

### Paying life as a land enters

- **Temple Garden** (Land — Forest Plains): "As this land enters, you may pay 2 life. If you don't, it enters tapped." A yes/no decision now exists, `ChooseYesOrNoDecision`, asked on screen as game ADR 0060 says, but only for a `MayEffect` as it resolves: this one is asked as the land is played, before it enters (ADR 0052's as-enters choice is the closest), and is a cost, not an effect; after it, entering tapped unless the life is paid can reuse `EntersTappedReplacementEffect` (ADR 0019), applied only when the life wasn't paid. Its mana already comes from its Forest and Plains subtypes.

### Surveil

- **Wary Thespian** ({1}{G}, Creature — Cat Druid, 3/1): "When this creature enters or dies, surveil 1." Surveil (CR 701.25) shows its controller the top card of their library and asks whether to put it into their graveyard: a new decision on screen, which the user wants prototyped first. After that it needs a surveil effect; "enters or dies" is two zone-change triggers, which exist.
