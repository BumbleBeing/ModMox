---
name: milestone
description: Reports where a roadmap milestone stands, what is built and what is left, checked against the repo. Use when the user asks which milestone is next, or what is done or left on one.
argument-hint: "[number or title]"
---

# Milestone status

A status report on one entry of the milestone ladder in `addons/modmox_rules/docs/roadmap.md`: what the entry asks for, held against what the repo holds. A ✅ is the user's record that an entry is closed, and it can trail the code, so the ✅ says where to look and the repo says what is built. The report changes nothing: giving an entry its ✅ stays with the user.

## 1. Find the entry

The roadmap is too long to read whole. Print its **ladder**, every numbered entry with its line number, its ✅ if it has one, and its title:

```bash
grep -noE '^( {4}- )?[0-9]+[a-z]?(-[0-9]+)?\. (✅ )?\*\*[^*]+\*\*' addons/modmox_rules/docs/roadmap.md
```

An entry is its list item with everything nested under it, so a milestone includes its sub-milestones. Read those lines alone, with `Read`'s offset and limit.

- **An argument** names an entry by its number (`17`, `13k`, `13e-2`) or by words of its title. When several entries match, list them and ask which.
- **No argument**: take the entries without a ✅ in ladder order, a sub-milestone under a ticked milestone included, and put each through steps 2 and 3. The report is on the first one with anything left to build, and each one passed on the way gets a line in it.

Done when the entry to report on, or the first entry of the walk, is read in full.

## 2. List its claims

A **claim** is anything in the entry that the repo can confirm or deny:

- **Built things**: each screen, class, file, folder, command-line flag and piece of Content the entry names.
- **Scenarios**: each test scenario, by its label where it has one (`T1`, `S4`, `SC2`).
- **Process**: each step the entry says it follows or has finished, such as a prototype signed off, a port, or a prototype deleted or kept on a branch.

Sizes, colors and timings ride on their scenario's test and the user's sign-off, and are not claims of their own.

What the entry puts under "Left for later" or "Still to come" is a **deferral**: owed by a later milestone, not by this entry. Note which milestone the entry gives it to.

An entry of a sentence or two has no agreed scope yet, since scope and test scenarios are agreed when a milestone starts. Its claims are the things that sentence names.

Done when every sentence of the entry falls under a claim, a deferral, or the sizes-and-colors rule.

## 3. Check each claim

Each ladder entry inside the one being reported is checked by its own ✅.

**With a ✅**, its built things and scenarios stand as built. Check its deferrals alone: a later entry may since have delivered one, so search the ladder and the code for each.

**Without a ✅**, find the evidence for every claim:

- A scenario is covered when a test carries its label and its words. Tests name their scenario in a doc comment (`## T4: a Lesser win pays 1, 2 or 3 cards`). Labels start again in every milestone and milestones share test files, so grep the test files of this entry's folders and read the words after each label: under `tests/` for game-side work, `addons/modmox_rules/tests/` for the engine, `addons/modmox_ai/tests/` for the AI. A scenario whose label no test carries is searched for by its words before it counts as missing, since an earlier milestone's test may already say it.
- A built thing is there when its file, class or flag is in the tree.
- A prototype said to be deleted is gone from `prototypes/`, and one kept on a branch shows in `git branch`.
- `git status --short` on the entry's folders: uncommitted files there are work under way.

The suite takes about seven minutes, so the check is that tests exist. Run them only when the user asks, and say in the report that they were not run.

Each claim ends as **built**, **missing**, or **unverifiable** from the repo, such as a sign-off, which is then taken from the entry's own words.

Done when every claim has one of the three, and every deferral is open or delivered.

## 4. Report

In broad strokes, about a screen long:

- **Heading**: the entry's number and title, and its state: *closed* (has its ✅), *built, not ticked* (nothing missing, no ✅), *under way* (some built, some missing) or *not started*.
- **Done**: three to six lines, each a part of the milestone in the roadmap's words, with folders or files named only where they help find it.
- **Left**: every missing claim by name, a scenario by its label and a few words. This is the one list the report gives in full. For an entry with no agreed scope it opens with the scope and test scenarios still to be agreed. For any entry without a ✅ it ends with what closing takes: the whole suite green, any sign-off the entry still waits on, and the ✅.
- **Deferred**: each deferral still open, with the milestone that owns it, then those since delivered on one line.

With no argument, open with a line on the entries passed on the way, such as "13k is built but not ticked."
