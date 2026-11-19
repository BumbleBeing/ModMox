# A "you may" is asked in the Info Panel, with No there and Yes on the Pass Button

"You may" on resolution (`MayEffect`, CR 603.5, 608.2d) came with Leonin Snarecaster, "When this creature enters, you may tap target creature.", a card of the Villain deck `king_of_the_pride` that the Hero can own through Spoils (ADR 0039). As the effect begins, the engine asks its controller a `ChooseYesOrNoDecision`; its target was chosen already, as the trigger went on the stack (CR 603.3d). A throwaway prototype of the question on the Encounter Screen, deleted once built, was signed off by the user: "Build it as shown".

**The Info Panel asks, and the Pass Button says yes.** No window opens and nothing new is drawn on the board. The words are the user's, checked before they were built:
- the Info Panel asks "Leonin Snarecaster's ability: tap target creature?": the stack name `InfoPrompt` gives any spell or ability, then what yes does as `AbilityText.offered_words()` words it, without "you may", then a question mark;
- it holds "No" where Cancel and "Declare All" sit, made as they are: a plain button, pressed with the mouse alone, with no key of its own;
- the Pass Button reads "Yes [SPACE]", and it and the pass key answer yes.

**Space says yes.** The prototype showed that the same key passes priority, so a Hero pressing Space through priority, or twice in a row, says yes without reading the question. The user kept it: Space says yes, with no pause before it can. "No" on the Pass Button, so Space always does nothing, was the proposal it replaced.

**The target carries its dashed Stack Mark for as long as the question is asked**, so "target creature" is shown rather than named: the words never name the target. The mark is the one the Stack Window entry's target gets under the cursor (ADR 0022), in that entry's Stack Color, and pointing at the entry and away again leaves it in place. The ability's source is not marked: only its target.

**Nothing glows and no click on the board answers it.** A click on the target to say yes would be a second way to do one thing (A393), and a "you may" with no target would have nothing to click.

Left out until a card needs them: a yes or no that is not an effect's, such as Temple Garden's "As this land enters, you may pay 2 life" (`docs/waiting_cards.md`); the Villain's answer shown in any way beyond what it does.

## Addendum: a ward cost is asked the same way, but no key pays it

Ward (engine ADR 0062) asks the Hero a `ChooseYesOrNoDecision` with a `cost` when the Villain's ward trigger resolves over the Hero's spell or ability: whether to pay the ward cost or have it countered. It is answered with the same input, No in the Info Panel and yes on the Pass Button, with no prototype, and the user approved the words.
- **One line from the question to the last payment.** The Info Panel reads "Pay ward for Leonin Lightbringer:", after the warded permanent's name, with the cost still to pay drawn as pips after it on the same line: {2}, then {1} once one is paid. The line stays the same while the cost is paid by hand or by Auto-tap (ADR 0031). It replaced "Leonin Lightbringer's ability: pay, or Shock is countered?" and "Pay for Leonin Lightbringer's ward".
- **Pay and No.** The Pass Button reads "Pay", with no key after it, and the Info Panel holds "No".
- **No key pays.** Space, and whatever key passes, does nothing while a cost is asked. Only a click on Pay or No answers it. This differs from a plain "you may", where Space says yes: here a Hero pressing Space through priority would spend mana without reading the question.
- **No Cancel while paying.** Nothing is being cast, so there is nothing to cancel: the ward trigger is resolving. `InfoPrompt` knows this payment by the ward trigger being on top of the stack, since a spell being cast always goes on top of whatever it was cast over.
- **The mark.** While the cost is asked, the Stack Window entry of the spell or ability ward would counter carries the ward trigger's dashed Stack Mark, in the ward trigger's Stack Color. Ward refers to that spell or ability rather than targeting it.

Once the Hero has paid and the ward trigger has resolved, the Hero's own spell is on top of the stack again and is passed for them, as any spell of their own is.
