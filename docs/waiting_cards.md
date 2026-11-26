# Waiting cards

The real cards `/add-card` triaged and has not added yet (ADR 0040), grouped by what each one waits on. A bare `/add-card` starts here, with the Ready group first.

- **Ready**: nothing; they were over a session's 20.
- **Blocked**: new primitives, under a heading for each.
- **Set Aside**: something new on screen, which starts with a GUI prototype.
- **Unsuited**: can never mean anything here, and is never proposed.

## Blocked

### A tapped token, the Powerstone, and mana with a spending restriction

- **Geology Enthusiast** (The Brothers' War, rare): "At the beginning of your end step, create a tapped Powerstone token. (It's an artifact with "{T}: Add {C}. This mana can't be spent to cast a nonartifact spell.")" and "{6}: Draw a card and put a +1/+1 counter on this creature." The end step trigger and the {6} ability are there. It needs three things: `CreateTokenEffect` creating its token tapped; a Powerstone Token Definition in `content/tokens/`; and mana that can't be spent to cast a nonartifact spell (CR 106.6), carried on each `MmMana` unit (ADR 0013) and refused by `ManaPayment` and the Agent's affordability check for a nonartifact spell, though spent freely on abilities. Proposed and not taken up yet: whether a Powerstone's {C} should look different in the Mana Pool is the user's question, and if it should, the card is Set Aside for a GUI prototype instead.

## Set Aside

### Stun counters

- **Galvanic Giant // Storm Reading** (Wilds of Eldraine, uncommon): "Whenever you cast a spell with mana value 5 or greater, tap target creature an opponent controls and put a stun counter on it." Its Adventure, Storm Reading ("Draw four cards, then discard two cards."), and the trigger's tap and mana value Filter are all there (engine ADR 0078). A stun counter is a new counter kind (CR 122.1d: "If a permanent with a stun counter on it would become untapped, instead remove a stun counter from it"), which needs a Counter Chip of its own drawn on the card face, starting with a GUI prototype, then the kind and its untap replacement.
