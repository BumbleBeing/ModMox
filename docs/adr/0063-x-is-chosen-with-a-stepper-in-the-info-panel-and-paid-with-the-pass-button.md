# X is chosen with a stepper in the Info Panel and paid with the Pass Button

Taj-Nar Swordsmith, a card of the Villain deck `kemba_kha_enduring` that the Hero can own through Spoils (ADR 0039), says "When this creature enters, you may pay {X}. If you do, search your library for an Equipment card with mana value X or less, put it onto the battlefield, then shuffle." As the effect begins, the engine asks its controller a `ChooseXToPayDecision` (engine ADR 0061): decline, or pay an X from 0 to `most`, the most they could pay now. Until now the Encounter Presenter declined it for the Hero without asking. A throwaway prototype on a mock board, kept on the branch `prototype/choose-x`, showed four ways to choose X: a − X + stepper in the Info Panel, a pip button for each X, X counted from the lands the Hero taps, and X set by clicking an Equipment in the Library window. The user chose the stepper, without a line under the question saying what X could find ("unnecessary and clutters the info panel"), with the stepper made larger and "No" narrower, and signed it off: "Build it as shown".

**The Info Panel asks, as for a "you may" (ADR 0060).** No window opens.
- It reads "Pay {X} for Taj-Nar Swordsmith?", the X drawn as its pip, after the name of the ability's source (the stack name's own name when the source is out of sight). The panel draws any prompt with a mana symbol in it with a `SymbolLabel`.
- A − X + stepper, the one combat damage is divided with (`DamageStepper`, 160 × 38), sits at its bottom left; − is grayed out at 0 and + at `most`.
- "No" sits at its bottom right, 104 wide rather than the 130 the Cancel and "Declare All" buttons take, to make room. It declines: nothing "if you do" offers happens.
- The Pass Button reads "Pay {2}", the X the stepper shows drawn as its pip, and pays that X. As with ward, no key presses it, and Space does nothing while X is asked: a Hero pressing Space through priority would spend mana without reading the question.

**The stepper starts at the largest X worth paying.** That is the X the Villain's CHEAP Agent pays: the largest X that offers something no smaller X does, such as a search finding a card of a higher mana value (`AiAgent.xs_worth_paying()`, made static so the presenter can ask it), or 0 when none is. For Taj-Nar with Short Sword and Lion Sash in the library and {2} or more to pay with, that is 2. The presenter asks it of the engine's own game, as the Hero knows what their deck holds.

**While Auto-tap is on, what it would tap for the X shown glows**, as the Tap Preview does at priority (ADR 0031), and changes as the stepper does. The presenter works the plan out on a copy, as it does for a cast, and keeps it until the next snapshot.

**Paying by hand reads "Pay for Taj-Nar Swordsmith:"**, with what is still owed after it on the same line, from the first payment to the last, and has no Cancel: nothing is being cast. The user chose these words. `InfoPrompt` knows a payment on resolution by a triggered ability being on top of the stack, since putting a trigger on the stack costs nothing and a spell being cast is always on top of what it was cast over; ward's payment (ADR 0062) is now one case of this and keeps its own words.

**Nothing is marked.** The prototype drew the trigger's source with a dashed Stack Mark; as with a "you may" (ADR 0060), only a target is marked, and "pay {X}" has none.

Left out until a card needs them: an X chosen as a spell is cast (CR 107.3a, 601.2b), an X with a limit or colored mana, and a cost on resolution other than {X}.

## Addendum: the stepper is the Pay answer (ADR 0066)

ADR 0066 changes where the stepper and "No" sit and how X is paid. They are the two halves of the Info Panel's Answer Row; the stepper is a plate of its own and no longer the `DamageStepper`. Neither is selected at first, and the Pass Button reads "Choose an answer"; clicking or stepping the stepper selects it, Up and Down step X, and the Pass Button or Space then pays, so "no key presses it" above no longer holds. The words, where the stepper starts and the glow of what Auto-tap would tap stand.

## Addendum: X chosen as a spell is cast (engine ADR 0076)

Guiding Hydra's {X}{W} is chosen as it is cast, with the same stepper. The Info Panel reads "Choose {X} for Guiding Hydra"; the stepper starts at the most the Hero could pay and sits on the left of the Answer Row, and the cast's Cancel takes the right, where No would be, since a cast is canceled rather than declined. The Pass Button reads "Cast with {2}". Nothing is selected at first, and what Auto-tap would tap for the X shown glows, as for "Pay {X}".
