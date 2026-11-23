# Code audit, 2026-11-23

A read-through of the game's code for obvious bugs, duplicated code and convention breaks, made by eight reviewers, one per portion. Tests, `prototypes/`, `content/` and `addons/gut/` were left out.

How to read it:

- Nothing was run in Godot. Every bug is traced by reading the code, not reproduced.
- **[checked]** marks a bug a second reader confirmed against the code. The others rest on one reviewer's trace.
- **CONFIRMED** means the reviewer traced it through the code; **LIKELY** means part of it was not checked, and says which part.
- **Latent** means no authored card or path reaches it today.
- Line numbers are as of commit `94579a1` plus the uncommitted changes then in the working tree.
- Convention rules are quoted from `addons/modmox_rules/docs/conventions.md`.

Contents: [Rules engine: machinery](#1-rules-engine-machinery) · [Rules engine: primitives](#2-rules-engine-primitives) · [AI addon](#3-ai-addon) · [Encounter GUI: logic](#4-encounter-gui-logic) · [Encounter GUI: widgets](#5-encounter-gui-panels-windows-and-widgets) · [Card drawing and shared GUI](#6-card-drawing-and-shared-gui) · [Other screens](#7-screens-outside-an-encounter) · [Run layer and tools](#8-run-layer-and-tools)

---

## 1. Rules engine: machinery

`addons/modmox_rules/src/` — `core/`, `rules/`, `layers/`, `replacements/`, `mana/`, `views/`, `agents/`, `actions/`. All 57 files read in full. Paths below are under `addons/modmox_rules/src/`.

### Bugs

**1.B1 [checked] [fixed 2026-11-23]. A permanent's own mana ability can pay the mana of its own "{N}, {T}: …" ability, and its {T} is then paid while it is already tapped.** CONFIRMED, and reproduced by a test before the fix (Stone tapped twice).

- Fix: `ManaPayment.pays_while_paying()` leaves out a mana ability that taps the permanent whose own {T} the cost being paid still owes, so neither `can_afford()` nor the payment's options count it (ADR 0048). Tests in `tests/rules/test_activation_mana_costs.gd`. Still open: `_pay_remaining_costs` has no `can_pay` recheck, and two abilities of one source that both sacrifice it, or both remove its last counter, collide the same way; no card in Content has either.

- `rules/cast_procedure.gd:223-233`: PAY_COSTS defers every cost with no choice until after the mana. `:298-303` and `:308-317`: `_pay_remaining_costs` in `_finish`, with no `can_pay` recheck.
- `mana/mana_payment_progress.gd:59-78`: `_options` never leaves out the source of the cost being paid.
- `mana/mana_payment.gd:35-61`: `can_afford` counts that source too.
- `rules/turn_procedure.gd:445-451`: `_may_activate` offers the action on that basis.
- `costs/tap_cost.gd:11-12`: `pay` performs a `TapEvent` without checking `is_tapped`.
- Situation: `content/cards/weatherlight/mind_stone.tres` ("{T}: Add {C}." and "{1}, {T}, Sacrifice this artifact: Draw a card."). With Mind Stone as the only untapped mana source, the draw ability is offered. During PAY_MANA the only option is Mind Stone's own mana ability; it taps for {C}, which pays the {1}. `_finish` then taps it again and sacrifices it, so the card is drawn for no outside mana. The same holds for any permanent with a {T} mana ability and a second ability costing mana plus {T}.

**1.B2. State-based actions can put two `ZoneChangeEvent`s for the same permanent into one batch.** CONFIRMED in code; LIKELY as to reachability with today's cards.

- `rules/state_based_actions.gd:47-50` (zero toughness, lethal damage), `:60-61` (Aura attached illegally), `:64-72` (legend rule) all append to one `actions` list with no de-duplication.
- `events/zone_change_event.gd:105` asserts the object is still in its from-zone; in a release build `leaving` is null and line 110 crashes.
- Situation: a player controls two legendary creatures of the same name, and the one not kept also has toughness 0 or lethal damage at that same check. For example a legendary 0/0 "enters with X +1/+1 counters" cast with X = 0 beside a copy already on the battlefield.
- Not checked: whether current Content has a legendary card that can reach this.

**1.B3. `MmGameState.fingerprint()` leaves out `chosen_mode`.** CONFIRMED (field absent); low severity.

- `core/mm_game_state.gd:480-558`, against its doc at `:480` ("A hash of the whole state, equal for two states exactly when they match").
- Situation: a modal triggered ability whose modes have no targets (Felidar Retreat's) on the stack with mode 0, against the same state with mode 1, gives one fingerprint.
- Also absent from the per-object line: `source_object_id` and `source_name`. Two Emblems' abilities at the same index both have `source_card_id` NO_CARD, so they collide too. `ActiveContinuousEffect.describe()` (`layers/active_continuous_effect.gd:60-61`) leaves out `duration` and `controller_id`.
- `fingerprint()` has no caller in `src/`; how tests and game-side tools use it was not traced.

**1.B4. `library_contents` can leak the order of same-named cards.** LIKELY; low severity.

- `views/mm_player_view.gd:144-152`. `_contents_of` walks the library top first and sorts by `name` only. `sort_custom` keeps no promise about ties, and for short lists it keeps input order.
- Situation: two cards with the same name that look different (one carries a Mod) appear in library order, against the field's doc at `:43-45` ("never in what order … nothing in it says where a card is").
- Not checked: whether the GUI or AI shows or reads the relative order.

Traced and found sound: undo and rewind bookkeeping in `MmEngine`, including Simulation Copies made mid-cast; every `duplicate_state` / `duplicate_object` / `copy_for` field list; first-strike and double-strike step handling; the legend-rule choice flow; trigger stacking when a ward trigger arrives mid-stacking; ADR 0065's "exiler already gone" case; `LayerEngine.outside_the_battlefield` writing `chosen_x`.

### Duplicated code

**1.D1. Sort-by-object-ID lambda written out 12 times.** `sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)` at:

- `rules/state_based_actions.gd:174`, `187`, `199`, `218`, `228`
- `mana/mana_payment.gd:98`, `101`, `111`
- `rules/turn_procedure.gd:532` (already a private helper, `_sorted_by_id`, used only in that file)
- `replacements/replacement_rules.gd:77`
- `triggers/trigger_detection.gd:19`, `36`

**1.D2. "Scan the battlefield, keep what matches, sort by ID, return" written five times in one file.** `rules/state_based_actions.gd:168-175`, `181-188`, `193-200`, `207-219`, `223-229`. Only the predicate differs. `ManaPayment.sorted_permanents_of` (`mana/mana_payment.gd:106-112`) is the same shape with a controller predicate.

**1.D3. "Every ability of every observer the player controls" loop written three times.** LIKELY (each is 5 to 8 lines). `rules/turn_procedure.gd:357-362` (`_abilities_controlled_by`, the helper); `rules/cast_procedure.gd:126-135`; `core/mm_game_state.gd:169-172`.

**1.D4. The mana-ability activation sequence written twice.** `rules/turn_procedure.gd:518-525` and `mana/mana_payment_progress.gd:110-117`: `AbilitySpentEvent` if once each game, `pay_costs`, a context from the source's controller, `resolve_effects` with the chosen mana type.

**1.D5. The list of locked references joined into text, twice in one class.** `replacements/active_replacement_effect.gd:91-93` and `:98-100`. Small.

**1.D6. SetPowerToughness and ModifyPowerToughness continuous effects share exports and `numbers()`.** `layers/set_power_toughness_continuous_effect.gd:5-14` and `layers/modify_power_toughness_continuous_effect.gd:5-14`. Only `layer()` and one operator in `apply_to` differ. Small.

### Convention breaks

**1.C1. Public methods without a `##` doc comment: 55.** Rule (Comments): "Every class and every public method has a `##` doc comment."

- 23 are not overrides: `core/mm_reference.gd:17`, `21`, `25`, `29`, `33`, `37`; `core/mm_zone.gd:25`, `29`, `51`; `core/mm_combat.gd:70`, `74`; `core/mm_game_object.gd:353` (`set_chosen_x`, the only event-only setter with no "Event-only" note); `core/mm_game_state.gd:190`, `213`; `core/ability_resolution.gd:21`; `rules/cast_procedure.gd:192`, `196`; `layers/active_continuous_effect.gd:60`; `replacements/active_replacement_effect.gd:97`; `mana/mana_payment_progress.gd:30`, `34`; `mana/mm_mana_cost.gd:87`; `mana/mm_mana.gd:29`.
- 32 are overrides of a documented base method in the five `layers/*_continuous_effect.gd` files, the four `replacements/*_replacement_effect.gd` files and the five `actions/*_action.gd` files.
- `core/mm_game_state.gd:205-213` is a displaced comment: the `zone()` doc line sits on top of `graveyard_from_stack`'s doc, and `zone()` itself has none.

**1.C2. Exported enum without explicit values.** `core/mm_encounter_setup.gd:9` `enum StartingPlayerRule { RANDOM_CHOOSER, HERO_CHOOSES, ... }`, used by `@export var starting_player_rule` at `:16`. Rule (Static typing): "Enums that end up in saved files get explicit values and are append-only. … This applies to every enum used by an `@export` property." No file in `content/` stores the field today.

**1.C3. Subtype membership read from the `subtypes` list.** `rules/attachment_rules.gd:17`, `22`; `rules/state_based_actions.gd:204`. Rule (Tests): "ask whether anything has a subtype with `MmCharacteristics.has_subtype()`, never its `subtypes` list". Behavior is the same today, since Equipment and Aura are not creature types.

**1.C4. Rules code names Hero and Villain.** `rules/pregame_procedure.gd:109`, `111`, `113`, `115`. Rule (Hard rule 3): "Players are relative (ADR 0005). Rules code says controller, owner, active player or opponent of." `MmEncounterSetup`'s own doc says "Hero and Villain appear here, at the boundary, and never in rules code."

**1.C5. Untyped `Array` and `Variant` where a typed collection would work, with no comment saying why.** Rule (Static typing): "Use typed collections" and "`Variant` is allowed only where data is genuinely open-ended … Say why in a comment."

- `layers/layer_engine.gd:97-101` (`var abilities: Array`, `for already: Variant`, `for ability: Variant`; `Array[MmAbility]` fits), `:107`, `:133`
- `mana/mana_payment.gd:45`, `47`, `117`, `120` (`Array[Array]` fits)
- `core/mm_game_state.gd:570` (`var contents: Array`)
- `core/mm_rng.gd:55`, `58` (generic on purpose, but no comment)

**1.C6. Class layout order.** Rule (Class layout): "`@export` properties, then public properties, then private properties. `_init`, then public methods, then private methods."

- Static factories before `_init` in 5 files: `core/mm_engine.gd:54`, `59`; `core/mm_rng.gd:14`, `20`, `28`; `rules/cast_procedure.gd:41-158`; `rules/resolution_procedure.gd:41`; `rules/combat_procedure.gd:28-63`.
- Private methods among public ones: `core/mm_engine.gd:224`, `230`; `core/mm_game_state.gd:181`; `rules/resolution_procedure.gd:156`.
- Private property among public ones: `core/mm_game_state.gd:37` (`_ability_resolutions`, before public `event_log` at `:40`).

**1.C7. Booleans that do not read as questions: 13.** Rule (Naming members): "Booleans read as questions: `is_tapped`, `has_kept`, `can_mulligan`."

- Members: `core/mm_game_object.gd:54` `cast_with_flashback`, `:63` `cast_from_library`; `views/mm_object_view.gd:47`, `50` (same two); `actions/cast_spell_action.gd:7` `as_adventure`; `core/mm_engine.gd:27` `_pregame_over`, `:47` `_checkpoint_pregame_over`, `:50` `_replaying`; `core/mm_game_state.gd:53` `_computing_layers`.
- Parameters: `core/mm_combat.gd:136` `first_strike`; `core/mm_game_object.gd:242` `tapped`, `:380` `until_it_leaves`; `rules/turn_procedure.gd:486` `pays`.

**1.C8. Long lines: 129 lines over 110 columns (tab as 4) in 29 of the 57 files.** Rule (Formatting): "Lines up to about 100 characters." Worst: `core/mm_game_state.gd` (17), `rules/turn_procedure.gd` (15), `rules/resolution_procedure.gd` (11), `rules/cast_procedure.gd` (10).

**1.C9. An invalid Encounter Setup is asserted, not returned.** LIKELY (arguable). `core/mm_engine.gd:72-73`. Rule (Errors): "Bad input from outside (an illegal decision answer, an invalid setup) is expected: return a reason string or result, leave the state unchanged". `MmEncounterSetup.validate()` gives the caller the reason first, but `MmEngine.start()` and `replay()` have no way to return one, and with asserts stripped an invalid setup carries on.

**1.C10. Places that hold a possible replacement choice behind `perform()` with no `# Later` note.** LIKELY. `rules/resolution_procedure.gd:278`, `283`, `287` (`_leave_stack`); `rules/turn_procedure.gd:494` (`_finish_playing_land`, whose doc at `:484-485` says the move "never needs a replacement choice"). A permanent with both `EntersTappedAbility` and `EntersWithCountersAbility` would hit the assert at `core/mm_game_state.gd:296`. No card in `content/` has both today.

Checked with nothing to report: no `.definition.<field>` read in this portion's rules code; no `randi`, clock, `shuffle()` or `pick_random`; no `await`, signals or Nodes; no cross-class access to `_` members; every dictionary iteration is over insertion-ordered or explicitly sorted keys.

---

## 2. Rules engine: primitives

`addons/modmox_rules/src/` — `abilities/`, `effects/`, `events/`, `triggers/`, `decisions/`, `filters/`, `selections/`, `values/`, `costs/`, `conditions/`, `cards/`, `targets/`. All 242 files read in full. Paths below are under `addons/modmox_rules/src/`.

No bug here is reachable from current Content; every one is latent.

### Bugs (all latent, nearest to reachable first)

**2.B1. The wrapping effects do not forward `remembers_moved_cards()`.** LIKELY. `effects/if_effect.gd`, `instead_effect.gd`, `may_effect.gd`, `may_pay_effect.gd` each forward `selections()` and `adds_mana()` (if:32-37, instead:33-40, may:47-52, may_pay:47-52) but not this. `rules/resolution_procedure.gd:148` asks the outer effect, and `MmEffect`'s default (`effects/mm_effect.gd:52`) is false. A `MillEffect` wrapped in any of the four never has its cards remembered, so a later `MovedCardsSelection` ("from among them") finds nothing. Example: "You may mill four cards. Then put a card from among them into your hand."

**2.B2. `MayPayEffect` passes a null source to costs that do not guard it.** LIKELY. `effects/may_pay_effect.gd:18` passes `state.object(context.source_object_id)`, null once the source has left, to `cost.can_pay()`. Only `costs/remove_counters_cost.gd:12` and `costs/sacrifice_this_cost.gd:10` guard `source != null`; `tap_cost.gd:8`, `exert_cost.gd:10`, `discard_this_card_cost.gd:10`, `use_up_cost.gd:9` and `tap_creatures_cost.gd:32` dereference it. A "when this dies, you may [tap or exert cost]. If you do…" trigger would crash on resolution.

**2.B3. `ZoneChangeEvent.describe()` leaves fields out of the fingerprint.** LIKELY. `events/zone_change_event.gd:160-168` leaves out `cast_with_flashback`, `cast_as_adventure`, `exiled_on_adventure`, `counters_on_arrival`, `entry_cost_paid` and `revealed`, all of which `copy()` (84-98) carries. `events/suspended_batch.gd:75` builds its text from `describe()`, and `core/mm_game_state.gd:481-495` puts that into `fingerprint()`.

**2.B4. An activated ability's `generic_reduction` is not clamped.** LIKELY. `abilities/activated_ability.gd:93`. A negative Value reaches `MmManaCost.reduced_by()` and raises the cost. The sibling `abilities/cost_reduction_ability.gd:21` clamps with `maxi(0, …)` and cites CR 107.1b.

**2.B5. `AddManaCostModification` drops {X} when the card already has a cost.** LIKELY. `cards/add_mana_cost_modification.gd:12-17`. With no mana cost on the card, the added cost is duplicated whole, `x_count` included; with one, only `generic`, `symbols` and `hybrid_symbols` are merged. The class comment names only the three merged fields, so this may be intended.

**2.B6. `TapCreaturesCost` passes the wrong ID as `stack_object_id`.** LIKELY. `costs/tap_creatures_cost.gd:18` passes `source.id`; on an activated ability that is the source permanent, not the ability on the stack. No GUI code reads the field today.

**2.B7. Null filters crash.** LIKELY. `abilities/enchant_ability.gd:23` puts `filter` into an `AllOfFilter` unguarded, while `may_enchant()` at `:33` treats a null filter as "anything". `filters/targets_filter.gd:8` defaults `filter` to null and `:19` calls `filter.matches()` unguarded, where every other "null matches any" filter guards.

### Duplicated code

**2.D1. `PowerFilter`, `ToughnessFilter` and `ManaValueFilter` are three copies.** `filters/power_filter.gd`, `toughness_filter.gd`, `mana_value_filter.gd`: the same `enum Comparison { OR_LESS = 0, OR_GREATER = 1 }`, the same exports and the same compare line. They have already drifted: Toughness and ManaValue take `amount_value`, Power does not.

**2.D2. The "reference to a Game Object, or no match" prologue is written out in 16 filters.** `controlled_by:10-13`, `has_ability:10-13`, `has_card_type:9-12`, `has_color:9-12`, `has_counters:12-15`, `has_original_name:12-16`, `has_subtype:9-12`, `has_supertype:10-13`, `is_of_chosen_type:9-15`, `is_permanent:8-11`, `is_tapped:7-10`, `is_token:8-11`, `mana_value:21-25`, `owned_by:11-14`, `power:17-21`, `toughness:23-27`. `MmFilter` has no helper for it.

**2.D3. `state.object(found.id) if found.is_object() else null` followed by an on-the-battlefield test, in 12 effects and 3 values.** `effects/attach_effect.gd:20`, `counter_effect.gd:70`, `create_continuous_effect.gd:20`, `destroy_effect.gd:17`, `double_counters_effect.gd:16`, `exile_effect.gd:28`, `put_counters_effect.gd:21`, `regenerate_effect.gd:16`, `return_to_battlefield_effect.gd:33`, `return_to_hand_effect.gd:15`, `tap_effect.gd:14`, `unattach_effect.gd:14`; `values/power_value.gd:11`, `basic_land_type_count_value.gd:14`, `counter_count_value.gd:15`. Three more as private one-offs: `deal_damage_effect.gd:49-52`, `fight_effect.gd:48-55`, `prevent_damage_effect.gd:68-70`.

**2.D4. The wrapping effects repeat one body.** `next_batch`, `selections()` and `adds_mana()` at `effects/if_effect.gd:26-37`, `may_effect.gd:40-52`, `may_pay_effect.gd:40-52`, with `instead_effect.gd:24-40` and `may_pay_x_effect.gd:53-54` as variants. No shared base, which is how 2.B1 got in.

**2.D5. `SpellAbility` and `TriggeredAbility` share four methods.** `abilities/spell_ability.gd:16-33` and `abilities/triggered_ability.gd:34-52`: `modes_or_none()`, `is_modal()`, `targets_for()`, `effects_for()`.

**2.D6. Equip and Reconfigure build the same attach by hand.** `abilities/equip_ability.gd:10-24` and `abilities/reconfigure_ability.gd:45-61`.

**2.D7. `GainLifeEffect` and `LoseLifeEffect` differ only in the event class.** `effects/additional_land_plays_effect.gd:10-26` is the same shape again. The one-number `numbers()` body is repeated at `add_mana_effect.gd:15-17`, `additional_land_plays_effect.gd:10-12`, `draw_cards_effect.gd:10-12`, `gain_life_effect.gd:9-11`, `lose_life_effect.gd:10-12`, `put_counters_effect.gd:11-13`.

**2.D8. Three near-identical decisions.** `decisions/choose_cards_to_bottom_decision.gd` and `choose_cards_to_discard_decision.gd` are the same class but for `describe()`'s words; `choose_permanents_decision.gd` is the same plus two fields.

**2.D9. "A list of distinct ints from a range" is validated three ways.** `decisions/mm_pending_decision.gd:42-58`, `choose_targets_decision.gd:29-45`, `order_triggers_decision.gd:36-49`.

**2.D10. The "effect this ability made for itself" pattern, three times.** `abilities/cycling_ability.gd:15-23`, `reconfigure_ability.gd:17-25`, `ward_ability.gd:11-19`.

**2.D11. Event pairs differing by one call and one word.** Small. `counters_put_event.gd` / `counters_removed_event.gd`; `life_gained_event.gd` / `life_lost_event.gd`; `tap_event.gd` / `untap_event.gd`. `ability_put_on_stack_event.gd:22-30` and `triggered_ability_put_on_stack_event.gd:16-25` both build an ability object field by field.

**2.D12. Small repeats.** The "source's Card Identity" pair of lines at `effects/create_continuous_effect.gd:25-26`, `prevent_damage_effect.gd:58-59`, `regenerate_effect.gd:13-14`. The Variant-to-`Array[int]` loop at `decisions/surveil_decision.gd:35-39`, `:43-47` and `effects/search_library_effect.gd:42-46`.

### Convention breaks

**2.C1. `MmCardDefinition.Rarity` has no explicit values and is saved in every card file.** `cards/mm_card_definition.gd:12` `enum Rarity { COMMON, UNCOMMON, RARE, MYTHIC, POWER_NINE }`, exported at `:32` (`rarity = 2` in `lion_sash.tres`). Rule (Static typing): "Enums that end up in saved files get explicit values and are append-only." Every other exported enum in the portion has explicit values.

**2.C2. Answer and reason enums without explicit values.** LIKELY. `decisions/choose_yes_or_no_decision.gd:13`, `keep_or_mulligan_decision.gd:5`, `choose_play_or_draw_decision.gd:6`, `events/zone_change_event.gd:17-18`. The Choice values are the answers ADR 0010's decision log saves. LIKELY because the rule's last sentence scopes it to `@export` enums.

**2.C3. 19 booleans not named as questions.** Rule (Naming members): "Booleans read as questions".

- Eleven are exported, so their names are in saved Content: `effects/create_token_effect.gd:23` `attacking`; `effects/search_library_effect.gd:19` `reveal`, `:24` `tapped`; `effects/return_to_battlefield_effect.gd:20` `tapped`; `effects/prevent_damage_effect.gd:28` `combat_only`; `effects/exile_effect.gd:15` `links_to_source`, `:18` `until_source_leaves`; `triggers/zone_change_trigger.gd:11` `any_from_zone`, `:14` `any_to_zone`; `triggers/attackers_declared_trigger.gd:17` `alone`; `abilities/reconfigure_ability.gd:17` `unattaches`.
- Eight on events: `events/zone_change_event.gd:37`, `39`, `41`, `43`, `49`, `55`, `62`; `events/token_created_event.gd:11`.

**2.C4. 350 public methods with no `##` comment.** Nearly all are overrides: `describe` 117, `apply` 48, `matches` 34, `next_batch` 28, `validate` 23, `selections` 22, `select` 12, `evaluate` 11. Not overrides, so plain breaks: `conditions/mm_condition.gd:9` `is_true` (the base method itself); `cards/mm_characteristics.gd:94` `has_card_type`, `:121` `has_supertype`; `events/suspended_batch.gd:42` `has_next_event`, `:46` `next_event`.

**2.C5. Class layout.** `cards/mm_characteristics.gd:133` declares `static var _basic_land_abilities` after eleven methods. `effects/exile_effect.gd:41` puts a private method before public `selections()` at `:46`.

**2.C6. A literal `\n## ` inside three class doc comments.** `abilities/damage_stays_ability.gd:3`, `deathtouch_ability.gd:3`, `haste_ability.gd:3`: a line break written as text, making lines of 110 to 183 columns.

**2.C7. 182 lines over 100 columns in 94 files.** Worst: `events/zone_change_event.gd:17` (147), `events/ability_left_stack_event.gd:27` (147), `effects/return_to_battlefield_effect.gd:38` (141).

**2.C8. Subtypes read from the list.** `filters/is_equipped_filter.gd:17`; `values/basic_land_type_count_value.gd:17`. No wrong result today.

**2.C9. `MmEffect.perform_now()` performs events.** LIKELY (documented exception). `effects/mm_effect.gd:39-47` calls `state.perform_together(batch)`. Rule (Hard rule 1): "Effects never perform anything". The method's comment gives the reason (a mana ability cannot stop for a decision); the convention names no such exception.

**2.C10. `.definition` read in rules code.** LIKELY (commented exception). `filters/has_original_name_filter.gd:18` reads `game_object.definition.original`; `abilities/protection_ability.gd:19` reads `source.definition == null`.

Checked and clean: file name equals class name in all 242 files; no `:=`, no untyped `var` or loop variable, no single-quoted strings, no British spellings, no banned abbreviations, no `await`, signals, Nodes, banned randomness or clock reads, no `hero()`/`villain()`; no mutating call outside an event's `apply()`; `MmEffectContext._copy()`, `ZoneChangeEvent.copy()` and `SuspendedBatch.copy_for()` carry every field.

---

## 3. AI addon

`addons/modmox_ai/src/`, all 13 files read in full. Paths below are under `addons/modmox_ai/src/`.

### Bugs

**3.B1 [checked] [fixed 2026-11-23]. `_is_lethal()` is not the worst case its comment claims, and a "lethal" verdict skips `_together()` and `_hold_back()`.** CONFIRMED. `ai_attack_planner.gd:91-105`, acted on at `:44-47`. The code is a greedy pass over attackers, each taking the first unused blocker. Situation: attackers A (5 power, ground) and B (4 power, flying); blockers b1 (flying or reach, earlier key) and b2 (ground). A takes b1, B then has no unused blocker, `unblocked = 4`. With the other player at 4 life this returns true and nothing is held back. The defender simply blocks B with b1 and A with b2 and takes 0.

- Fix: `_is_lethal()` now finds the most damage the blockers can stop between them (the biggest attacker first, moving earlier ones to other blockers where that frees one, `_can_stop()`). Reproduced first by a test in `test_ai_combat.gd`. Still as before: a blocked trampler counts as stopped, and 3.B4.

**3.B2 [checked] [fixed 2026-11-23]. `_cheap_target()` falls back to candidate 0 whatever side it is on.** CONFIRMED. `ai_agent.gd:684-686`. When every opposing candidate is filtered out (damage would not kill, `:669`; ward cannot be paid, `:667`; already tapped, `:671`) and no player is a candidate, it returns `0`, which is the Agent's own creature whenever that is the oldest.

- Situation A (CHEAP, every simulation and rollout): a "3 damage to target creature" in hand, the other player's only creature a 4/4. `_has_something_to_remove()` (`:457-474`) says yes, the spell is cast, and `_cheap_target()` then skips the 4/4 and returns 0.
- Situation B (FULL, the real game): a tap with every opposing creature already tapped. `:624` makes the CHEAP pick the default, and `:638` keeps it unless another target scores at least 1 better.
- Fix: with nothing fit and no player to aim at, it takes the most valuable candidate on the right side that the effect is wasted on, and candidate 0 only when that side has none. Situation A reproduced first by a test in `test_ai_spells.gd`; Situation B has no test of its own. Still open: with candidates only on the wrong side it takes the oldest, not the least valuable.

**3.B3 [checked] [fixed 2026-11-23]. `_swing_back()` counts tapped creatures as blockers.** CONFIRMED, reproduced by a test in `test_ai_combat.gd`, and fixed with the `is_tapped` check. `ai_attack_planner.gd:191-194`. The comment says "each creature left untapped by this attack"; the code counts every creature that is not attacking or has vigilance, with no `is_tapped` check, so `_hold_back()` (`:167-179`) keeps too few attackers home.

**3.B4. Negative combat damage is summed unclamped.** CONFIRMED in code; LIKELY as to how often power goes negative. `ai_attack_planner.gd:104` and `:188`. `_aggression()` (`:113`), `_their_attack_damage()` (`:205`) and the block planner (`ai_block_planner.gd:154`) clamp with `maxi(..., 0)`; these two do not.

**3.B5. The block planner's second round does not do what its doc says.** LIKELY (which of doc or code is intended is unknown). `ai_block_planner.gd:43-48` against `:4-8`. Doc: "if still in danger, trades and chump blocks lead". Code: `_good_blocks()` leads, then trades, then chumps; and the reset at `:45` throws away the round-one gang blocks.

**3.B6 (latent). `unwrapped()` does not look inside `InsteadEffect`.** LIKELY. `ai_timing.gd:43-55` unwraps May, MayPayX, MayPay and If only. An "X. If [condition], Y instead" around damage or destroy would be tagged `NONE` and `is_harmful()` false. The only authored user today wraps +1/+1 counters.

Found sound: every answer shape against each decision's `validate()`; all simulation goes through `source.simulation_copy()`; CHEAP paths never simulate; randomness comes only from the one `source.ai_rng()` at `ai_agent.gd:133`; the only clock reads are the slow-decision warning.

### Duplicated code

- **3.D1.** `ai_agent.gd:28-31` `BASIC_LAND_COLORS` copies `MmCardTypes.BASIC_LAND_TYPES`. `_basic_colors()` (`:1227-1232`) re-derives what the engine already adds as intrinsic mana abilities.
- **3.D2.** `ai_agent.gd:1418-1431` `_best_option()` and `ai_monte_carlo.gd:69-83` `AiMonteCarlo.choose()` are the same rule written twice.
- **3.D3.** "FULL: simulate every index, take the best" is written out four times: `ai_agent.gd:834-837`, `:903-906`, `:993-996`, `:1239-1243`. The index-list loop inside it four more: `:773-775`, `:816-818`, `:881-883`, `:1139-1142`.
- **3.D4.** `_cheap_target()` (`ai_agent.gd:642-686`) and `_cheap_up_to_targets()` (`:788-806`) repeat the candidate filter and have drifted: the up-to version has no "damage would kill" filter and no counter handling.
- **3.D5.** Building two CHEAP Agents and a capped driver: `ai_simulation.gd:98-108` and `ai_combat_oracle.gd:91-97`. The copy differs in behavior: the oracle gives the other player the deciding player's `_profile`, where `_cheap_driver()` gives the default.
- **3.D6.** The colors a hand needs: `ai_agent.gd:1195-1201` repeats `AiPaymentPlanner.colors_needed_by_hand()` (`ai_payment_planner.gd:37-45`).
- **3.D7.** Sorcery timing: `ai_timing.gd:170-172`, inline at `:265-267` and (negated) `ai_agent.gd:411-412`; the engine has the same test private at `rules/turn_procedure.gd:378-380`.
- **3.D8.** `_creatures_of()` is identical at `ai_agent.gd:1520-1525` and `ai_attack_planner.gd:217-222`. The "permanents this player controls" loop is hand-written at `ai_agent.gd:941-943`, `:1202-1204`, `:1385-1386`, `ai_attack_planner.gd:78-80` and `ai_board_evaluator.gd:28-29`, while `ManaPayment.sorted_permanents_of()` exists.
- **3.D9.** Finding a card's spell ability by looping for `SpellAbility`: `ai_agent.gd:458-461`, `:513-516`, `:1455-1458`; `ai_timing.gd:210-213`, `:227-233`. The engine has `CastProcedure.spell_ability_of()`. LIKELY: whether using it would change an Aura's Timing Tag was not checked.
- **3.D10.** Small twins between the two planners: `_combat_damage()` and `_value()` in both. `AiCombatOracle.duel()` is `duel_among()` with one attacker. The literal `6` at `ai_agent.gd:163` repeats `SURVEIL_LANDS` (`:26`).

### Convention breaks

- **3.C1. Players named by arithmetic and literal ID.** Rule (Hard rule 3). `1 - me` / `1 - player_id` at `ai_agent.gd:474`, `:1319`; `ai_attack_planner.gd:186`, `:203`; `ai_combat_oracle.gd:66`; `ai_simulation.gd:104`. Literal seats at `ai_combat_oracle.gd:93-94`. The same files use `opponent_of()` elsewhere.
- **3.C2. Public methods with no doc comment: 4.** `ai_agent.gd:116` `answer()`; `ai_board_evaluator.gd:42` `permanent_value()`; `ai_difficulty.gd:44` `normal()`, `:48` `hard()`.
- **3.C3. Class layout order.** `ai_agent.gd:34` `enum Reason` after the constants; `:1062` public `xs_worth_paying()` among private methods. `ai_timing.gd` and `ai_simulation.gd` interleave public and private methods.
- **3.C4. Untyped collections and unexplained `Variant`.** About 13 bare `Array`s where `Array[Array]` is used elsewhere in the same file: `ai_monte_carlo.gd:36-37`, `:51`, `:87`; `ai_agent.gd:231`, `:290`, `:879`, `:973`, `:976`, `:811`, `:1533`, `:1536`, `:1324`. `answer: Variant` parameters with no comment: `ai_simulation.gd:20`, `:40`, `:144`; `ai_agent.gd:116`, `:124`.
- **3.C5. About 20 booleans that do not read as questions.** `harmful` (`ai_agent.gd:646`, `:791`, `:1099`); `main_phase`; `through_turn`, a parameter of public API. The reverse case: `ai_agent.gd:78` `holds_lands_through_turn` reads as a boolean and is an `int`.
- **3.C6. Abbreviations.** Lambda parameters `a`, `b` (`ai_agent.gd:803`, `:891`, `:951`, `:1221`); `ms` (`ai_profile.gd:35`, `ai_agent.gd:1547`); `min`/`max` (`ai_agent.gd:23`; `ai_profile.gd:14-15`, which are `@export` and so part of the save format).
- **3.C7. Search budgets outside `AiDifficulty`.** LIKELY. Rule (The AI addon): "Search budgets belong to `AiDifficulty`". `ai_agent.gd:16` `MOST_PICKS_SIMULATED`, `:18` `MOST_TYPES_SIMULATED`, `:811` the literal `count <= 3`; `ai_simulation.gd:12` `ROLLOUT_EXTRA_TURNS`.
- **3.C8. Line length.** 78 lines past 110 columns (49 in `ai_agent.gd`).

Other: `AiFightResult.damage_to_defender` is computed and read nowhere. `AiSimulation.roll_out()` is called only from tests. `_least_useful()` has an unused parameter `_me`. `_combinations()` builds every pick before the size check at `ai_agent.gd:879-880`.

---

## 4. Encounter GUI: logic

29 files in `ui/encounter/`, all read in full (`encounter_screen.gd`, `encounter_presenter.gd`, `encounter_layout.gd`, the snapshot and request, `decision_clicks.gd`, the selections and the pure classes). Paths below are under `ui/encounter/`.

### Bugs

**4.B1 [checked] [fixed 2026-11-23]. Right-arrow while choosing X for a cast makes the Pass Button read "No" and then cast the spell.** CONFIRMED. `encounter_screen.gd:745-748` (`press_key`), `:859-863` (`_select_answer`), `:867-873`, `:877-884`. `_select_answer()` accepts `InfoPanel.NO_ANSWER` for any `_answer_asked`, including a `ChooseXDecision`, which has no "No". `_selected_answer_text()` returns "No"; Pass then runs `_selected_answer_value()`, which returns `_x_to_pay` whatever is selected. `test_screen_choose_x.gd:83` covers Right only for `ChooseXToPayDecision`.

- Fix: `_select_answer()` takes no `NO_ANSWER` while a `ChooseXDecision` is asked. Reproduced first by a test in `test_screen_cast_x.gd`.

**4.B2 [checked] [fixed 2026-11-23]. A pass the Hero clicked, put off for the hangtime, is dropped if a setting is reconsidered meanwhile.** CONFIRMED. `encounter_presenter.gd:368-375`, `:491-496` (`_reconsider`), `:520-527` and `:557-566` (`_advance`). The Villain's spell is young on the stack and the Hero presses Pass; within the hangtime the Hero toggles a step stop, or auto-pass or Auto-tap is set. `_reconsider()` calls `_advance()` without `is_passing_now`, which clears `_is_passing_for_hero`, and the Hero is asked again. Likely related, not traced: Undo in the same window.

- Fix: the presenter remembers that the pass put off is the Hero's own (`_is_own_pass_put_off`), and `_reconsider()` leaves it alone; the new setting is read once the pass is made. A pass made for the Hero and put off is still asked again, as before. Reproduced first by a test in `test_presenter_pacing.gd`. Undo in that window, traced: with something to undo it undoes the Hero's answer before the pass and drops the pass, so the Hero is asked again; with nothing to undo it is refused and the pass stays. Left as it is.

**4.B3. The hangtime is skipped when a pass for the Hero is also put off for the step wait.** CONFIRMED (timing-dependent). `encounter_presenter.gd:557-566`, with `:336-338`. The step-wait branch sets `_is_passing_for_hero` and leaves `_pass_due_at` at 0; `poll()` then calls `_advance(true)`, whose `is_pass_due` branch submits the pass without reaching `_put_off_pass()`. This contradicts the class doc (`:18-22`, "nothing leaves the stack sooner than the hangtime").

**4.B4 [checked] [not reachable in the working tree, 2026-11-23]. With "up to N" targets all picked, the remaining candidates stop glowing but keep their `ClickCatcher`.** CONFIRMED. `encounter_screen.gd:2384-2399`. The glow is dropped when neither `is_picked` nor `can_pick` holds, but the catcher is added for any `is_pickable` (`:2396`). ADR 0022: "a thing that takes a click always glows".

- The uncommitted change to "up to N" targets (the pick that leaves nothing more to pick answers at once, ADR 0022 as edited) means the screen is never drawn with every pick made, for targets or for a cost, unless the engine refuses the answer. The catcher is still added for any candidate; nothing was changed.

**4.B5. Hovering a closed graveyard pile whose top card has a click option shows the Tap Preview for it.** LIKELY. `encounter_screen.gd:3078-3080`, `:2513-2520`, `:2475`. Not checked: whether `payment_plan()` returns a plan for a flashback answer in practice.

**4.B6. A window closed by using an Emblem's or Potion's mana ability never comes back on undo.** LIKELY, not reachable with today's Emblems. `encounter_screen.gd:1848-1857`; `held_windows.gd:49-61`.

### Duplicated code

- **4.D1. "Every object the view shows" is built four times with differing zone lists.** `encounter_snapshot.gd:43-63` and `:123-142`; `state_information.gd:145-160`; `replacement_text.gd:43-51` with `:68-78`.
- **4.D2. Drawing a permanent with its attachments behind it.** `encounter_screen.gd:2165-2184` (`_draw_row`) and `:2287-2318` (`_draw_line`).
- **4.D3. Which nonland permanents stand on their own.** `encounter_screen.gd:1573-1582` and `:2213-2226`.
- **4.D4. The list of the seven Zone Windows.** `encounter_screen.gd:614`, `:937-942`, `:2128`. A new window must be added to all three.
- **4.D5. Undo-button expression repeated five times.** `encounter_screen.gd:2038`, `:2973`, `:2979`, `:2988`, `:3225`.
- **4.D6. `_show_picks()` branches.** `encounter_screen.gd:2972-2977` and `:2978-2983`.
- **4.D7. Marking an item's targets and players.** `encounter_screen.gd:3254-3259` and `:3278-3283` are identical; the portrait lines repeat at `:3533-3536`.
- **4.D8. Finding the scroll arrow a hidden face lies past.** `encounter_screen.gd:2591-2599` and `:2821-2827`.
- **4.D9. Presenter command guards.** `encounter_presenter.gd:358-365`, `:386-391`, `:471-476`; `pass_priority` omits the stopped check.
- **4.D10. Presenter card lookup.** `encounter_presenter.gd:845-848` and `:860-863`; `:864` rewrites `_file_name()` (`:837-838`).
- **4.D11. Fanned hand rests.** `encounter_layout.gd:360-367` and `:447-454`.
- **4.D12. `CardPicks._init`.** `card_picks.gd:33-53`: five parallel branches.
- **4.D13. Identical accessors.** `inspection.gd:42-47`: `shown()` and `pinned()` return the same thing.
- **4.D14. Banner buttons.** `encounter_screen.gd:3643-3649`, `:3651-3655`, `:3656-3660`.

### Convention breaks

- **4.C1. Public methods with no doc comment: 49 across 14 files.** `encounter_screen` 16, `card_picks` 5, `encounter_presenter` 5, `payment_plan` 4, `start_form` 4, `combat_selection` 3, `opening_hand` 3.
- **4.C2. Doc comments on the wrong member.** `encounter_presenter.gd:406-411` (`cancel_cast()`'s comment sits on `stop()`'s); `encounter_screen.gd:3228-3233`; `:106-109` (two stacked comments on `_x_asked`, the first stale); `encounter_layout.gd:56`, `:94-100`; `encounter_screen.gd:1814` names a parameter that does not exist; `encounter_layout.gd:428` says "top to bottom as they are drawn", but the Villain's order differs from `regions()` (`:158-160`).
- **4.C3. Private methods interleaved with public ones.** Systematic in `encounter_screen.gd`, `encounter_presenter.gd:180-200`, `decision_clicks.gd:181`, `encounter_layout.gd:535`, `:606-626`, `:662-672`.
- **4.C4. A constant declared among the methods.** `encounter_layout.gd:737` `const NOT_BLOCKING`.
- **4.C5. Long lines.** 270 over 100, 77 over 120.
- **4.C6. Booleans that do not read as questions.** `encounter_screen.gd:259` `_searched_window`; `:3642` `won`.
- **4.C7. `msec` in names.** 31 occurrences: `encounter_presenter.gd:55-62`, `pacing.gd:15-24`, `game_speed.gd:34`. Whether a unit counts as an abbreviation is the owner's call.
- **4.C8. Untyped collections.** `encounter_screen.gd:3352`, `:3377` take `regions: Dictionary`.
- **4.C9. `Variant` with no reason given.** `encounter_screen.gd:1149`, `:2837-2841`.
- **4.C10. The screen reads more from the presenter than the conventions allow.** LIKELY doc drift. The conventions call the Tap Preview plan "the one thing the screen reads that is not in the snapshot"; `encounter_screen.gd:1482` `starting_x()` and `:2001-2003` `x_payment_plan()` are sanctioned by ADR 0063, so the conventions sentence is what is stale.
- **4.C11. The Pain Portrait's hold does not go through `Pacing`.** LIKELY. `encounter_screen.gd:1527` calls `PainHold.seconds(..., _speed)` directly; an unpaced screen still gets a hold. Not among the listed exceptions.
- **4.C12. A member never read.** `creature_type_choice.gd:17`, `:28`: `_names`.

Boundary checks that came out clean: only `encounter_presenter.gd` mentions the engine classes; the snapshot is made before each worker task starts; click meaning is worked out only in `DecisionClicks` and the selections; no signal is connected twice.

---

## 5. Encounter GUI: panels, windows and widgets

The other 55 files in `ui/encounter/`, all read in full. Paths below are under `ui/encounter/`.

### Bugs

**5.B1 [checked]. The Info Panel leaves hybrid symbols out of what is owed.** CONFIRMED. `info_prompt.gd:238-242` (`_owed`), used at `:57`, `:62`, `:76`. It copies `remaining_generic` and `remaining_symbols` but not `remaining_hybrid_symbols`. Paying {B/R}{B/R}: `ManaSymbols.pip_names()` gets a cost with nothing in it and returns `["0"]`, so the panel reads "Pay for X {0}". With {1}{B/R} it reads {1}, then {0} while the hybrid is still owed.

**5.B2 [checked]. A Pile Window keeps a stale Glow color when the same cards stay clickable under a different kind of decision.** CONFIRMED in code. `pile_window.gd:75-77` (early return) and `:235-245` (`_signature`). The signature records each card's ID and only whether it has options; not `clicks.colors_of()`, which `:202` draws the Glow from. Situation: the graveyard window is open on a flashback card (green), then the Hero starts something that targets a card in a graveyard: the card stays green.

### Duplicated code

- **5.D1. `StackEntry` and `ZoneEntry` are the same widget written twice.** Construction `stack_entry.gd:30-69` vs `zone_entry.gd:31-63`; making it clickable `:129-140` vs `:167-178`; ellipsis cutting `:166-173` vs `:191-194`. `zone_entry.gd:4` still says "Everything on the stack is drawn this way".
- **5.D2. Three motion clocks share one skeleton.** `face_motion.gd:25-29`, `:126-129`, `:134-146`; `opening_motion.gd:37-41`, `:160-163`, `:177-193`; `card_flights.gd:64-65`, `:139-142`, `:167-174`. `opening_motion.gd:14` defines `LONGEST_FRAME` again.
- **5.D3. `SurveilWindow` has its own press/drag state machine beside `DragCard`, and they have drifted.** `surveil_window.gd:39-43`, `:172-210`. `:197` starts a drag at `> DRAG_START`; `drag_card.gd:44` at `>= START_DISTANCE`. `const EASE: float = 0.3` is declared four times (`hand_strip.gd:32`, `trigger_list.gd:18`, `surveil_window.gd:24`, `opening_hand_overlay.gd:52`); `PICKED_GLOW` twice.
- **5.D4. A centered Label helper is written out seven times.** `damage_stepper.gd:61-71`, `potion_readout.gd:75-85`, `info_panel.gd:454-465`, `opening_hand_overlay.gd:623-633`, `player_panel.gd:688-697`, `hold_panel.gd:32-39`, `x_stepper.gd:49-59`.
- **5.D5. Possessives are worded three ways, and one disagrees.** `player_names.gd:53-54` and `stack_item.gd:92-93` are identical; `info_prompt.gd:254` hardcodes `"%s's ability"`. For a name ending in "s", the Info Panel reads "…s's ability" and the Stack Window "…s' ability".
- **5.D6. `InfoPrompt` rewrites its own stack lookup.** `_stack_item()` at `info_prompt.gd:222-226`; inline at `:177-179`, `:190-192`, `:232-235`, `:248-250`; again as `StackItem._find` at `stack_item.gd:85-89`.
- **5.D7. `XStepper` and `DamageStepper` are siblings with no shared part.** Signals, the three accessors and the sign-button builder (`x_stepper.gd:83-107` vs `damage_stepper.gd:74-92`).
- **5.D8. `SteelFrame` builds the same plate scaffold three times.** `steel_frame.gd:76-78` with `:93-97`, `:139-150`, `:162-174`.
- **5.D9. A flat StyleBoxFlat-per-state loop on six small buttons.** `zone_window.gd:70-80`, `option_menu.gd:144-148`, `damage_stepper.gd:83-89`, `player_panel.gd:745-749`, `scroll_row.gd:160-167`, `x_stepper.gd:95-100`.
- **5.D10. `BorderEffects` draws the soft and hard outline pair twice.** `border_effects.gd:53-58` vs `:207-212`, with literal 7, 3 and 0.35 where the constants at `:24-26` hold the same numbers.
- **5.D11. `PauseMenu`'s settings boxes are one block written three times.** `pause_menu.gd:419-425`, `:433-439`, `:443-451`.
- **5.D12. The Rarity color table is copied.** `potion_art.gd:17-23` repeats four of the five literals of `inspector.gd:40-46`.
- **5.D13. Smaller repeats.** Catcher wiring `pile_window.gd:203-206` vs `:221-224`. `player_panel.gd:813-815` duplicates `:683-685`. Panel fill "#2c323c" in six files; muted "#9aa3af" in three; the window dark color in three.

### Convention breaks

- **5.C1. The Surveil window eases by a fixed share per frame.** `surveil_window.gd:167`: `face.position.lerp(slot_at(place), EASE)` in `_process(_delta)`. Rule (Game-side code): "easing takes its weight from the frame's length (`EncounterLayout.ease_weight()`), never a fixed share per frame." Its siblings do it right.
- **5.C2. Hover-leave handlers on rebuilt nodes have no guard.** LIKELY (not proven that Godot prints the error). `stack_entry.gd:70-71`, `:133-134`; `pile_window.gd:205-206`, `:223-224`; `option_menu.gd:156-159`. `creature_type_window.gd:288-293` guards correctly with `_is_clearing`.
- **5.C3. Public methods without a `##` comment: 77 of 507, in 29 files.** Most: `opening_hand_overlay.gd` (7), `player_panel.gd` (7), `border_effects.gd` (5).
- **5.C4. Untyped collections: 16 declarations in 6 files.** `pile_window.gd:65`, `:70`, `:103`, `:105`, `:235`; `stack_arrows.gd:14`, `:29`; `inspector.gd:83`, `:164`, `:263-264`, `:311`, `:316` (`_waiting: Array` used as a five-field tuple).
- **5.C5. Class layout order.** `player_panel.gd:282-319`, `:329-332`; `option_menu.gd:107`; `stack_item.gd:85-93`; `info_prompt.gd:216-242`; static functions before `_init` in `surveil_window.gd`, `potion_art.gd`, `flight_card.gd`; `inspector.gd:35` a `static var` among constants.
- **5.C6. Six inner classes.** Rule: "One class per file." `block_lines.gd:16`, `card_flights.gd:146`, `:167`, `face_motion.gd:134`, `opening_motion.gd:177`, `creature_type_window.gd:387`. `CardFlights.Route` is public API.
- **5.C7. `Variant` with no comment.** `inspector.gd:80`, `player_panel.gd:93`, `:97` (a three-state bool), `opening_hand_overlay.gd:587`.
- **5.C8. Formatting.** 187 lines over 100 columns in 38 files. `player_panel.gd:414` has one blank line between functions; `:659-661` has three.
- **5.C9. Stale doc comments.** `border_effects.gd:3-4`, `:145` describe the pointer as the Debug Decision Panel's, which was deleted; `zone_entry.gd:4`; `damage_stepper.gd:6`; `player_panel.gd:781`.

Checked and clean: no British spellings, banned abbreviations, single-quoted strings, engine class mentions, `.free()`, `await`, or "Hero"/"Villain" literals outside `PlayerNames`.

---

## 6. Card drawing and shared GUI

`ui/cards/` and the ten `.gd` files directly in `ui/`. All 40 files read in full.

No card in Content triggers a bug here today, apart from 6.B1 and 6.C1.

### Bugs

**6.B1 [checked]. Dither block beside the tiled middle is 5 px wide, not 3.** CONFIRMED by arithmetic, not rendered. `ui/dither_shading.gd:161` (`posmod(x / BLOCK, 2)`), called from `:178` with `x - corner`. GDScript integer division truncates toward zero, so `x - corner` in -2..2 all map to block 0, and every block left of it is shifted 2 px. Affects every `DitherShading.plate()`; `SteelFrame` passes x from 0 and is not affected.

**6.B2 (latent). `ModText` names the card from the Mod's accepted types as if one card had them all.** LIKELY. `ui/cards/mod_text.gd:28`. `Mod.card_types` is "must have one of"; `self_noun` returns the first of creature, artifact, enchantment, land. A Mod accepting [ARTIFACT, CREATURE] with an ability that names its source reads "this creature" on a noncreature artifact.

**6.B3 (latent). `FrameSpec.key()` leaves out what picks the crown and P/T box of a colorless artifact land.** LIKELY. `ui/cards/frame_spec.gd:64` adds ":artifact" only when not a land, but `:135` and `:146` choose by `is_artifact` for lands too, so two different frames share a cache key. Content has no artifact land.

**6.B4 (latent). `AbilityText` wording wrong for nameable cards not yet in Content.** CONFIRMED in code. In `ui/cards/ability_text.gd`:

- `:833-835`: "It can't be regenerated." after any `DestroyEffect`. Wrath of God would read "Destroy each creature. It can't be regenerated."
- `:1252-1253`: `_verb()` adds "s" for everything but "you": "up to two target creatures gets +1/+1".
- `:1298-1299`: plural is noun + "s" except Equipment and Plains: "Elfs", "Wolfs", "sorcerys".
- `:1626-1630`: `_with_article()` picks by first letter: "a 8/8", "a 11/11", "an Unicorn".
- `:1271-1276`: the AnyOf branch of `_noun_phrase()` returns before `whose` is added, dropping "you control".
- `:843-844`: "it deals" for a triggering-object source does not set `_says_triggering_object`.
- `ui/cards/mod_text.gd:78-79`: `_signed()` writes "-1/+0" where `AbilityText` writes "-1/-0".

**6.B5 (latent). `ManaSymbols.texture()` dereferences null for a missing image.** LIKELY. `ui/cards/mana_symbols.gd:39-40`. `pip_names()` builds a hybrid name in stored order, and `Vector2i(RED, BLACK)` asks for `rb.svg`, which does not exist. Content is safe; a cost made in code in the other order crashes the face.

### Duplicated code

- **6.D1. The panel plate recipe is written out ten times.** `DitherShading.plate(c.lightened(0.06), c.darkened(0.3), …)` at `ui/window_look.gd:19`; `ui/cards/inspector_parts.gd:345`, `:369`; `ui/deckbox/deckbox_screen.gd:200`; `ui/stage_map/stage_map_screen.gd:378`; `ui/stage_map/run_bar.gd:39`; `ui/spoils/spoils_screen.gd:294`; `ui/menu/main_menu.gd:394`; `ui/encounter/info_panel.gd:114`; `ui/deckbuilder/modify_window.gd:378`. `WindowLook`'s constants are also retyped in several screens.
- **6.D2. "Paint the shading for this height unless it already has it", three times.** `ui/cards/inspector_parts.gd:338-346`, `:364-373`; `ui/deckbuilder/modify_window.gd:372-385`.
- **6.D3. `SteelFrame` re-derives `DitherShading`'s button plate, and the shared helper has no game caller.** `ui/dither_shading.gd:50-51` = `ui/encounter/steel_frame.gd:71-72`. `button_plate()` and `disabled_plate()` are called only from tests, yet the conventions still say a button is made by them.
- **6.D4. The Inspector's button theme and grays are the deckbuilder's, copied.** `ui/cards/inspector_parts.gd:78-91`, `:378-391` against `ui/deckbuilder/deckbuilder_look.gd:80-94`, `:124-133`.
- **6.D5. Linux Libertine is loaded by three helpers.** `ui/ui_text.gd:12-13`; `ui/cards/inspector_parts.gd:31`, `:63-68`; `ui/deckbuilder/deckbuilder_look.gd:54`, `:70-75`.
- **6.D6. The "a, b, and c" joiner exists three times.** `ui/cards/ability_text.gd:795-798`; `ui/cards/mod_text.gd:72-75`; `ui/encounter/state_information.gd:117-120`.
- **6.D7. `CounterChip` repeats `DamageChip`.** `ui/cards/damage_chip.gd:79-86`, `:72-76` = `counter_chip.gd:75-83`, `:68-72`.
- **6.D8. `AbilityText` assembles the same phrase and whose-words several times.** Phrase: `:417-428`, `:978-985`, `:1321-1329`, `:1335-1351`. Whose: `:621-625`, `:632-636`, `:642-646`, `:658-662`, `:1306-1309`, `:1431-1435`.
- **6.D9. `CardFace` draws a row of pips with shadows twice.** `ui/cards/card_face.gd:163-175` and `:201-210`.
- **6.D10. Smaller repeats.** Cut-with-ellipsis in `anchored_text.gd:80-86` and `chosen_type_chip.gd:33-36`; chip plate in `card_shapes.gd:49-51` and `chosen_type_chip.gd:44-47`; `ui/hover_ease.gd:50-58` and `:89-99`.
- **6.D11. One-liners with an obvious home.**
  - A card's art key `resource_path.get_file().get_basename()`: `ui/cards/card_look.gd:200`; `card_warmup.gd:70`; `ui/deckbuilder/deckbuilder_screen.gd:258`; `ui/encounter/encounter_presenter.gd:838`, `:864`; `run/deckbuilder_card.gd:56`; `tools/art/token_art.gd:31`; `tools/card_gallery/card_gallery.gd:153`; `ui/credits/art_attribution.gd:81`.
  - Card size `Vector2(h * CardGeometry.ASPECT, h)`: `card_face.gd:30`; `card_back.gd:14`; `ui/encounter/surveil_window.gd:64`; `pile_window.gd:184`; `encounter_screen.gd:1780`, `:2898`, `:3023`, `:3058`; `villain_hand.gd:119`; `hand_strip.gd:504`; `ui/deckbuilder/modify_window.gd:293`; `deckbuilder_layout.gd:177`.
  - Free-every-child loop that `InspectorParts.clear()` already is: `ui/stage_map/run_bar.gd:87`; `ui/encounter/zone_window.gd:159`; `ui/deckbuilder/modify_window.gd:329`.

### Convention breaks

- **6.C1. The Emblem Face prints mana symbols as braces.** CONFIRMED in code; not looked at on screen. `ui/cards/emblem_face.gd:69-78`: a `RichTextLabel` given `rules_bbcode(look)`. Rule (Game-side code): "Interface text that names a cost is written with a `SymbolLabel`". All three authored Emblems have an activated ability with a mana cost.
- **6.C2. `CardWarmup` does not warm tokens.** LIKELY (not measured). `ui/cards/card_warmup.gd:17-28`, `:39-60`. Pip textures are not warmed either.
- **6.C3. 49 public functions with no `##` doc comment.** `card_face` 7, `rules_text` 7, `card_look` 4, `frame_layer` 4, `inspector_parts` 4. Stranded comment at `ui/cards/card_look.gd:223-225`.
- **6.C4. 223 lines past 100 characters, 56 past 120.** `ui/cards/ability_text.gd` has 94 over 100.
- **6.C5. Class layout order in six files.** Constants before the enum in `card_look.gd:9-17`, `keyword_chips.gd:9-19`; `_init` after public methods in `ability_text.gd:328`, `art_library.gd:34`, `ui/scene_fade.gd:60`.
- **6.C6. Four inner classes.** `ui/cards/rules_text.gd:33`, `:40`; `ability_text.gd:76`; `inspector_parts.gd:35`. `ui/` has 14 in all.
- **6.C7. Both faces pass the mouse, not ignore it.** LIKELY (may be a missing exception in the conventions). `ui/cards/card_face.gd:33`, `battlefield_face.gd:115` set `MOUSE_FILTER_PASS` for the wheel that scrolls rules text.
- **6.C8. A `Variant` parameter with no reason given.** `ui/dither_shading.gd:27` `lip_color: Variant = null`.
- **6.C9. Names.** `rect` (`card_shapes.gd:36`); `dx`, `dy` (`dither_shading.gd:145-146`); `spec` (`ability_text.gd:1165`, `:1191`). Booleans `clips`, `starts_sentence`, `changed`, `or_less`, `reads_it`.
- **6.C10. Four `# Later:` notes name no milestone.** `ui/cards/ability_text.gd:399`, `:578`, `:1016`, `:1054`.
- **6.C11. Untyped collections.** `rules_text.gd:202`; `art_library.gd:22`; `ui/run_log_share.gd:35`.

Seen in passing: `content/mods/viscious.tres` is named "Viscious" (Vicious), file name and Mod name both.

---

## 7. Screens outside an encounter

`ui/deckbuilder/`, `ui/deckbox/`, `ui/menu/`, `ui/stage_map/`, `ui/spoils/`, `ui/run_end/`, `ui/credits/`, `ui/backdrops/`. All 46 files read in full.

### Bugs

**7.B1 [checked]. A glide on the Stage Map keeps running after Quit or Abandon, then reads a run that is gone.** CONFIRMED. `ui/stage_map/stage_map_screen.gd:304-308`, `:289-292`, `:321-330`; `ui/run_pause.gd:52-53`. Click a glowing Node, press Escape, click Quit before the glide ends. `RunFlow.quit()` sets `RunFlow.run = null`; the Scene Fade takes 0.25 s and `_process` is never stopped. `_arrive()` then calls `_run.move_to(id)`, which writes a `node_chosen` line after the `quit` line, and `RunFlow.arrive()` dereferences the null run.

**7.B2. The deckbuilder's hover is worked out only when the mouse moves.** CONFIRMED. `ui/deckbuilder/deckbuilder_screen.gd:723-734`, reached only from `:819-821`. Wheel-scroll with the cursor resting and the inspector and Glow stay on the old card. Also a convention break: "Ask where the cursor is each frame; do not wait for it to move."

**7.B3 [checked]. A click on the open Pause Menu during the Spoils reveal is swallowed.** CONFIRMED. `ui/spoils/spoils_screen.gd:268-272`: `_input` takes every left press while `is_revealing()` without asking `run_pause.is_open()`.

**7.B4. With `--stage-map` or `--spoils`, the Pause Menu's Quit never reaches the main menu.** CONFIRMED (developer flags only). `ui/menu/main_menu.gd:112-122`. RunPause's Quit and Abandon do not set `has_left`, so the menu starts a new debug run and bounces back.

**7.B5. Deckbox changes made before Start are not saved, and deckbuilder saves reach disk only on Exit.** CONFIRMED path; may be accepted under "the run is saved only where `RunFlow` says a Screen opens". `ui/deckbox/deckbox_screen.gd:473-490`; `ui/deckbuilder/deckbuilder_screen.gd:382-390`, `:474-479`. Set Active, Duplicate or Delete, then Start, then Quit from the encounter: Continue reverts them. In the deckbuilder an applied Mod lives only in memory until Exit; ADR 0028 calls an applied Mod final.

**7.B6. A Game Speed chosen in the Pause Menu on the Stage Map or Spoils does not apply until the screen is reopened.** CONFIRMED. `ui/stage_map/stage_map_screen.gd:121`; `ui/spoils/spoils_screen.gd:102`; `ui/run_pause.gd:54-56`.

**7.B7. A freed Deckbox row's hover handlers act on the row that replaced it.** LIKELY. `ui/deckbox/deckbox_screen.gd:145-151`, `:156-162`, `:352-362`, `:381-382`. The handlers are bound by index, and the `is_queued_for_deletion()` guard can never be true. Not checked: Godot's real order of deferred call, container sort and deletion.

**7.B8. A mouse wheel over either zoom slider leaves the faces only scaled.** LIKELY. `ui/deckbuilder/deckbuilder_screen.gd:1248-1249`, `:1254-1255`, `:1297-1310`. Faces are rebuilt sharp only on `drag_ended`. Not checked: that Godot emits no `drag_ended` for a wheel tick.

**7.B9. Exit's tooltip is wrong in a run.** CONFIRMED. `ui/deckbuilder/deckbuilder_screen.gd:1270` says "Go back to the main menu."; `:423-424` goes to the Deckbox when `RunFlow.is_editing`.

**7.B10. Dead condition.** CONFIRMED (harmless). `ui/deckbuilder/deckbuilder_screen.gd:1556`: `not _fan_places.has(card.id)` is always false.

**7.B11. The filter bar tells the player cards have no rarity.** CONFIRMED (stale text). `ui/deckbuilder/filter_bar.gd:301-305`; `collection_filter.gd:5-6`.

### Duplicated code

- **7.D1. The window look is written out again beside `WindowLook`.** `ui/spoils/spoils_screen.gd:21-23`, `:33-35`, `:293-297`; `ui/menu/main_menu.gd:38`, `:391-397`; `ui/stage_map/run_bar.gd:13-14`, `:21`, `:39-40`.
- **7.D2. `ModifyWindow._shade` repeats `InspectorParts.shade_background`.** `ui/deckbuilder/modify_window.gd:371-396`.
- **7.D3. The reveal's arithmetic exists twice.** `ui/spoils/spoils_reveal.gd:79-84`, `:40-42`, `:29-31` and `ui/run_end/run_end_reveal.gd:61-66`, `:40-42`, `:20-22`; the screens' `is_revealing`/`advance`/`finish_reveal` at `spoils_screen.gd:242-256` and `run_end_screen.gd:241-255`.
- **7.D4. "Wait some frames, save a PNG, quit" is written seven times.** `deckbuilder_screen.gd:209-216`; `deckbox_screen.gd:72-77`; `stage_map_screen.gd:126-132`; `stage_intro.gd:49-55`; `spoils_screen.gd:100-111`; `run_end_screen.gd:104-114`; `credits_screen.gd:63-69`. An eighth at `ui/encounter/encounter_screen.gd:454-466`.
- **7.D5. The frame that draws only a drop shadow, four times.** `spoils_screen.gd:418-429`; `main_menu.gd:401-411`; `run_end_screen.gd:457-468`; `credits_screen.gd:279-288`.
- **7.D6. The bold, steel-framed 56 px button, five times.** `spoils_screen.gd:402-409`; `stage_intro.gd:94-101`; `run_end_screen.gd:442-450`; `credits_screen.gd:270-278`; `main_menu.gd:283-292`.
- **7.D7. A dim veil with a centered window, four times.** `modify_window.gd:70-78`; `choice_prompt.gd:25-44`; `menu_dialog.gd:48-56`; `deckbox_screen.gd:499-514`.
- **7.D8. Framing a button again when it resizes, hand-written beside `SteelFrame.frame_as_sized`.** `deckbuilder_screen.gd:1648-1660`; `modify_window.gd:404-411`; `run_bar.gd:154-166`.
- **7.D9. `StageIntro.begin` builds its ground inline though its own `ground_panel()` builds the same.** `ui/stage_map/stage_intro.gd:64-70` against `:139-151`.
- **7.D10. `DeckbuilderSample` lists Content's cards itself.** `ui/deckbuilder/deckbuilder_sample.gd:11`, `:130-143`, against `ContentCards.all()`.
- **7.D11. Small builders repeated across screens.** Pixel icon `TextureRect` (`run_bar.gd:119-128`, `run_end_screen.gd:471-480`, `spoils_screen.gd:316-322`); rounded Portrait frame (`deckbox_screen.gd:250-264`, `run_end_screen.gd:421-439`); the centered label helper in eight screens; `_gap` in three.
- **7.D12. The deckbuilder draws its own hover Glow and selection ring beside `BorderEffects`.** LIKELY. `deckbuilder_screen.gd:899-917`, `:836-841`, `:1003-1028`. Not checked: whether `BorderEffects`' Glow looks as the deckbuilder wants.
- **7.D13. Constants retyped.** Brass #e8cf8a in four places beside `DeckbuilderLook.BRASS`; red #e5484d in three; the screen size in four; the main menu scene path beside `Screens.MENU`.

### Convention breaks

- **7.C1. Public methods without a doc comment: 81 of 400, in 22 files.** Most: `deckbuilder_screen.gd` (16), `deckbox_screen.gd` (13).
- **7.C2. Class layout.** Public methods after private ones in 9 files (`deckbuilder_screen.gd` has 63 after the first private one at `:221`). `ui/menu/main_menu.gd:66-80`: `@export` properties after public ones. Enums after constants in `wisp_light.gd:20`, `deckbuilder_screen.gd:63`.
- **7.C3. Two throwaway prototypes live in `ui/`.** `ui/deckbuilder/prototype_color_sliders.gd` ("delete once the colors are chosen"); `ui/menu/soldier_idle_prototype.gd` and `.tscn`. Rule: prototypes live in `prototypes/` and "are deleted when the real build lands."
- **7.C4. The deckbuilder waits for the cursor to move.** See 7.B2.
- **7.C5. `autowrap_mode` set after the text, three times.** `deckbuilder_inspector.gd:85-86`; `modify_window.gd:416-417`; `choice_prompt.gd:55-56`.
- **7.C6. Cursor-leaving handlers on rebuilt things.** `deckbox_screen.gd:381-382` (see 7.B7); `modify_window.gd:280`.
- **7.C7. Booleans that do not read as questions: 9.** `collection_filter.gd:21-22` `multicolor`, `colorless`; `filter_bar.gd:229` `lit`, `:213` `toggles`; `wisp_flight.gd:303` `anyway`; `flipped`, `won`, `showing`.
- **7.C8. Abbreviations.** `scenery_layout.gd:81-82` `dx`, `dy`; `wisp_flight.gd:269-271` `t`, `t2`, `t3`.
- **7.C9. A `Variant` with no reason given.** `filter_bar.gd:178`.
- **7.C10. A doc comment on the wrong method.** `deckbuilder_screen.gd:568-569`.
- **7.C11. Long lines: 22 over 120 characters, in 12 files.**

Other: `BossDisc.fit_scale` (`ui/stage_map/boss_disc.gd:84`, `:110-122`) calls `portrait.get_image()` and walks every pixel on every draw, and the Stage Map redraws every frame. ADRs 0070 and 0071 (prices, stores) and ADR 0037's amended Begin Run button are not built yet.

---

## 8. Run layer and tools

`run/`, `tools/` (GDScript, shell, Python) and `.claude/skills/add-enemy-deck/scripts/`. 56 files read in full. Not read: `tools/sprites/build_sprites.lua` and the scenes and sprite grids under `tools/`.

### Bugs

**8.B1 [checked]. A fresh `.godot/` makes the parallel and `--quick` test runs deal out zero test files, and it never recovers.** CONFIRMED (the awk behavior was run on scratch data; the rest traced). `tools/test.sh:145-149`. Line 145 touches an empty `.godot/test_times.tsv`. The dealing awk uses `FNR == NR` to mean "first file", which stays true for every line of the second file when the first is empty. No shard list is written, so the glob at `:160` stays literal and the script errors under `set -e`. Times are only written from a successful run, so the file stays empty. Reachable on any fresh clone or new worktree. Fix shape: test `FILENAME == ARGV[1]`.

**8.B2. A Run Log with a `continued` line not preceded by `quit` does not replay.** CONFIRMED by trace. `tools/run_log/run_replay.gd:106-109`. The game saves at points that write no log line (`run/run_flow.gd:106`, `:112`, `:118`, `:169`, `:232`); the replay only calls those lazily.

- Case 1: win an encounter, close Spoils, close the window, Continue. The replay's last save is SPOILS, so it stops with "The run was taken up on SPOILS, not STAGE_MAP".
- Case 2: edit and save a Deck from the Stage Map's Deckbox, close the window, Continue, play an encounter. The replay plays the encounter with the old Deck.
- Nothing handles a window close, so a closed window or a crash is exactly this path.

**8.B3. An unreadable list file overwrites the deck with an empty one and reports success.** CONFIRMED. `.claude/skills/add-enemy-deck/scripts/write_deck.gd:46`, `:73-83`. `FileAccess.get_file_as_string()` returns "" for a missing path, so an empty `MmPlayerSetup` is saved over the deck and "Wrote …: 0 cards" is printed.

**8.B4 [checked]. `Mod.problems()` still enforces a rule ADR 0029 withdrew.** CONFIRMED. `run/mod.gd:67-68`: "A Mod that accepts lands accepts nothing else." ADR 0029: "Amended in the Store's design round: a Mod that accepted Land once accepted no other type. An Omni Mod accepts every card type, lands included". An Omni Mod therefore fails `problems()` and the content test. The stale rule is also pinned by `tests/run/test_mod.gd:124` and repeated in `.claude/skills/add-mod/SKILL.md:35`.

**8.B5. A run that leaks exactly one object passes the leak check.** CONFIRMED from the binary's strings; not executed. `tools/leak_check.sh:9` requires "ObjectDB instances were leaked"; Godot prints "1 ObjectDB instance was leaked at exit" for one.

**8.B6 [checked]. `guarded.sh` refuses to guard a direct GUT command, by matching itself.** CONFIRMED by reading; not executed. `tools/guarded.sh:19`: `pgrep -f 'addons/gut/gut_cmdln\.gd'` matches the guard's own bash process whenever the guarded command names `gut_cmdln.gd`, which is the leak-hunting command in "The run ends clean" step 3.

**8.B7. A missing build folder exits `push.sh` silently.** CONFIRMED. `tools/export/push.sh:42-46`: the `find` fails under `set -euo pipefail` before the intended message at `:44`. Reachable after `export.sh --linux-only`, which removes `build/windows`.

**8.B8 (latent). `tokens_made_by()` misses tokens inside a wrapping effect or an Adventure half.** LIKELY. `tools/art/token_art.gd:12-25` walks only top-level `effects` and modes. The first "you may create a token" card will get no token art, with no message.

**8.B9. `write --anyway` on a two-faced card saves a name-only definition into the root of `content/cards/`.** LIKELY. `tools/cards/card_tool.gd:140-147`. `ContentCards.all()` never lists that folder.

### Duplicated code

- **8.D1. Listing `.tres` files with the `.remap` suffix trimmed, five times.** `run/content_cards.gd:15-21`; `content_decks.gd:13-19`; `content_mods.gd:13-19`; `content_stages.gd:29-37` (the only one made a helper); `ui/deckbuilder/deckbuilder_sample.gd:132-142`.
- **8.D2. Recursive "every card file under content/cards/".** Identical at `tools/art/fetch_art.gd:128-137`, `tools/cards/card_tool.gd:345-354`, `tools/card_gallery/card_gallery.gd:162-171`; a variant at `write_deck.gd:87-97`. `ContentCards.all()` already exists.
- **8.D3. Card name to file map.** `tools/cards/card_tool.gd:336-342` and `write_deck.gd:87-97`; one lower-cases the name, the other does not.
- **8.D4. Scryfall "card, then printings, then `FirstPrinting.choose`".** `tools/art/fetch_art.gd:93-105`; `fetch_reference.gd:35-45`; `tools/cards/card_tool.gd:225-245`. The art-crop download is also twice.
- **8.D5. Card name to snake-case key, written twice with different results.** `tools/art/reference_art.gd:14-27` and `tools/cards/oracle_reading.gd:183-191`. "Lim-Dûl's Vault" becomes `lim_d_ls_vault` in one and `lim_duls_vault` in the other.
- **8.D6. A Deck's plain data is written in three places and read in two.** Written at `run/deckbox.gd:36-38`, `:115`, `run/run.gd:205-207`; read at `run/deckbox.gd:123-129`, `tools/run_log/run_replay.gd:144-149`. `Deck` has no `to_data()` / `from_data()`.
- **8.D7. Weighted-pick loop, three times.** `run/stage_map_generator.gd:227-233`, `:276-284`; `run/spoils_roll.gd:46-53`.
- **8.D8. Shell option parsing and version reading repeated.** `tools/export/export.sh:15-21`, `:74` and `push.sh:14-20`, `:26`. Minor.
- **8.D9. Screenshot-and-quit plus Escape-to-main-menu boilerplate.** `tools/card_gallery/card_gallery.gd:26-37` and `tools/breath_lab/breath_lab.gd:42-54`. Minor.

### Convention breaks

- **8.C1. Public methods with no doc comment: 21.** `run/collection.gd:31`, `:43`; `deckbox.gd:20`, `:46`, `:57`; `deckbuilder_card.gd:64`, `:68`, `:72`, `:76`, `:83`, `:87`, `:119`; `deck.gd:12`; `held_mods.gd:12`, `:39`; `run_flow.gd:232`; `run.gd:307`; `saved_run.gd:85`, `:89`; `stage_visit.gd:134`; `tools/cards/oracle_data.gd:30`.
- **8.C2. Private methods placed before public ones.** `run/run.gd:295`; `run/deckbox.gd:88`, `:96`.
- **8.C3. File name does not match the class.** `tools/export/licenses.gd:1` declares `class_name ExportLicenses`.
- **8.C4. A saved-state field that is not saved.** `run/run.gd:45` `beginning` is absent from `to_data()` and `from_data()`. Harmless today: only `RunFlow.start()` reads it.
- **8.C5. Inferred type outside the one allowed case.** `run/stage_map_generator.gd:7` `const Kind := StageMap.Kind`, the only `:=` in the portion.
- **8.C6. Untyped collections in signatures and constants.** `run/stage_map_generator.gd:12`, `:14`, `:98`, `:166-168`, `:195`, `:237`; `run/spoils_roll.gd:17`, `:48`; `run/run.gd:89`. Low: GDScript cannot nest typed collections, so the constants are forced.
- **8.C7. `run/` names a file of `tools/`, in a comment.** `run/run_log.gd:7`. Low.
- **8.C8. Long lines: 37 over 110 columns across 21 files.**

Found sound: the Stage Map generator against ADR 0026 (row sizes, links, skips, Elite and Trove cuts, shop legality, every validity rule); every saved field of the run's classes written and read back with `int()`, except `beginning`; each Run Log line kind written and replayed in the same shape, apart from 8.B2.
