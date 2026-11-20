# A land that may pay to enter untapped is asked in the Info Panel what paying does

Temple Garden, a land of the Villain deck `zar_ojanen_scion_of_efrava` that the Hero can own through Spoils (ADR 0039), says "As this land enters, you may pay 2 life. If you don't, it enters tapped." As the land is played, before it moves, the engine asks its controller a `ChooseYesOrNoDecision` whose `entry_cost` is 2 life and whose `entering_object_id` is the land, still in the hand (engine ADR 0052's addendum). A throwaway prototype on a mock board, built on the Info Panel of ADR 0066 and kept on the branch `prototype/temple-garden` (cbfd458), showed three ways to ask: A, as ward asks, with the cost on the left half of the Answer Row; B, as A with the land waiting above the lands row and the life total previewed as "20 → 18"; and C, "Temple Garden enters:" over "Pay 2 life" | "Tapped". The user chose A, with one change: "I like option A, except the info panel should say what paying the cost would accomplish. In this case, it should say 'Have Temple Garden enter untapped?' with the cost in the bottom left button." They signed it off: "Build it as shown".

**The Info Panel asks what paying does.** It reads "Have Temple Garden enter untapped?", after the land's name. The Answer Row's left half is the cost, "Pay 2 life", in the words `AbilityText` gives it (`cost_words()`, carried to the panel on `InfoPrompt.affirmative`); the right half is "No". No window opens and nothing is marked.

**It starts on nothing, as a ward cost does (ADR 0066).** It costs life, so the Pass Button reads "Choose an answer" until an answer is selected by a click or by Left and Right; then it reads "Pay 2 life" or "No" over "SPACE", and it or Space gives it. Pay lowers the Hero's life by 2 and the land enters untapped; No has it enter tapped.

**The land being played waits in the hand, glowing white**, as the card being played, until the answer is given; then it moves to the lands row. B's land waiting above the row and its life preview were turned down.

**A Hero who cannot pay is not asked.** With less than 2 life the land enters tapped (CR 119.4). At exactly 2 the question is asked, and paying loses the encounter.

**The Encounter Presenter does nothing new.** It hands the Hero's question to the screen as it does any `ChooseYesOrNoDecision`, and the Villain's to its Agent.

**The Villain's answer shows only in its result**: its land enters tapped or untapped, and paying lowers its life with the usual wince of its Pain Portrait.

Left out until a card needs them: the question when such a land enters other than by being played, and an entry cost other than life.
