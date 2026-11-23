# An Adventurer card is drawn in the Adventure frame, and cast from the Exile window

Faerie Guidemother // Gift of the Fae (engine ADR 0078) needed four new things on screen. A throwaway prototype on a mock board built from the real pieces (`prototypes/adventure/`, deleted when this landed) showed each, and the user chose the following.

**Its face is the printed card, in CardConjurer's Adventure frame.** The rules box is an open book: the Adventure's page on the left, with its name and mana cost in white on a gray bar, its type line on a second bar and its rules under them, and the creature's rules on the right page. `FrameSpec.is_adventure` picks `assets/card_frames/adventure/` (its color, gold for two or more, the artifact frame for none), copied unchanged from CardConjurer's pack and credited with the other frames; `CardFace` writes each piece of text where the pack's `packAdventure.js` puts it (`CardGeometry.ADVENTURE_*`, `CREATURE_PAGE_RULES`). The P/T box is the frame's color's, laid over it as on any creature. Turned down: drawing the creature alone, with the Adventure only in the Inspector. On the battlefield it is a creature like any other, so a Battlefield Face draws nothing new.

**The Inspector's Card Text writes the Adventure under the creature's text**: its name and mana cost, its type line, then its rules, each a paragraph (`CardLook.adventure_text_lines()`).

**Letting it go from the hand opens the Option Menu**: "Cast Faerie Guidemother" and "Cast Gift of the Fae", in that order, as any card with more than one use offers its uses. The row under the cursor is shown in the Info Panel.

**On the stack it is the whole printed card, the creature's page dimmed.** `CardLook.of_view()` makes the look of a spell cast as its Adventure from its card's creature half, with the spell as its `adventure` and `is_adventure_cast`, and `CardFace` shades the right page. Its Stack Window entry reads "Gift of the Fae (Adventure)", and its full text ends "Cast as an Adventure: exiled as it resolves, and Faerie Guidemother may then be cast from exile.", as flashback's does (game ADR 0049). Turned down: drawing the spell as a sorcery face of its own.

**On an adventure it is cast from the Exile window, as flashback is from the Graveyard window** (game ADR 0049). The Hero's exile pile glows green while it can be cast; in the window the card glows and one click casts it, "Cast Faerie Guidemother from exile". Its State Information reads "On an Adventure: May be cast as Faerie Guidemother."; a Villain's card on an adventure says the same in their exile, with no Glow.

The user agreed every word above before it was built.
