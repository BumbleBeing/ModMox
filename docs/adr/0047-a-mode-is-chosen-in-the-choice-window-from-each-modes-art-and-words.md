# A mode is chosen in the choice window, from each mode's art and words

The Hero chooses a modal spell's mode (ADR 0046) in the window that asks which replacement effect applies first, its title "Coordinated Maneuver: choose one", with an entry for every mode of the spell. A prototype showed three ways (kept on the branch `prototype/modal-spells`): the Option Menu opened at the card, a mode window, and the card stood up large with each mode in its rules box clicked. The user chose the mode window, with each entry only the card's art and the mode's words, with no "Mode 1" header.

**Every mode is shown, and one that cannot be chosen is dimmed.** A mode the engine does not offer (CR 700.2a) is drawn at less than full strength and takes no click, so the Hero sees why it is not there. A mode that can be chosen is a usable Zone Entry: it glows green, brightens under the cursor and is clicked to answer. A `ZoneEntry` with no name draws its words alone, at full strength and centered by its art.

**Pointing at a mode shows what it could do.** The Info Panel shows the mode in full, and everything the decision says its targets could be is marked in the target color, faces and portraits alike. The Info Panel asks "Choose one for Coordinated Maneuver" and offers Cancel, since the mode is a step of the cast.

**When only one mode can be chosen, no window opens**: the engine chooses it (ADR 0046), and the cast goes straight to that mode's target.

**On the stack a modal spell says only the mode it was cast with.** Its entry leads with its name, as any spell's does, and its full text, shown while the cursor is on it, is the chosen mode's words.
