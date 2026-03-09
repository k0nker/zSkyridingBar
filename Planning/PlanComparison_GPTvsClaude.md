# Planning Document Comparison: GPT-5 mini vs. Claude

Comparing `CascadeAnalysis_Plan.md` and `RefactorFunctions_Plan.md` (GPT-5 mini)
against `CascadeAnalysis_Plan_Claude.md` and `RefactorFunctions_Plan_Claude.md` (Claude).

---

## Section 1 — Scope of Investigation (what files were read)

| Area | GPT-5 mini | Claude |
|---|---|---|
| `zSkyridingBar.lua` (1825 lines) | Yes | Yes |
| `Options.lua` (1312 lines) | **No** | Yes |
| Locale files | No | Yes (enUS.lua) |
| Relevant lib internals (AceDB-3.0, LibEditMode) | Referenced nominally | Referenced and used to verify callback behaviour |

**Why this matters:** `Options.lua` is a significant entry-point file. It is the only place users
interact with settings, and it contains a critical call to `CreateAllFrames()` without the
required `active = false; CheckSkyridingAvailability()` follow-up (the P1-B `singleFrameMode`
bug). GPT-5 mini never read this file, so that bug category was completely invisible to it.

---

## Section 2 — Terminology

Both analyses define the same three core terms (refresh, dirty, entry point). Claude adds
a more precise definition table covering six terms: **refresh**, **appearance update**,
**dirty**, **active**, **tracking**, and **SETTING_CHANGED equivalent**. The distinction
between a "refresh" (the whole `RefreshConfig` chain) and an "appearance update" (one of three
sub-functions) matters because several problems are specifically about the *appearance update*
being called too broadly, not about `RefreshConfig` itself.

GPT-5 mini's terminology section conflates these, which leads its analysis to describe P3-A
("overly broad refresh scope") as refreshing "all 5 panels" — but there are 4 frames and 3
appearance-update sub-functions, not 5 panels.

---

## Section 3 — Entry Points Inventory

GPT-5 mini identified 4 entry-point chains (PLAYER_CAN_GLIDE_CHANGED, speedBarOnUpdate,
charge events, compat widget). Claude identified 22 distinct entry points across both files.

**Entries discovered by Claude that GPT-5 mini omitted:**

| Missing entry point | Significance |
|---|---|
| `Options.lua` root `set` → `RefreshConfig` | The primary settings-change trigger for most controls |
| `Options.lua` `singleFrameMode` toggle → `CreateAllFrames` | Source of P1-B bug |
| `Options.lua` `enabled` toggle → `Enable`/`Disable` | Calls `StopTracking` |
| AceDB `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` callbacks | Source of P1-A double-fire |
| `ZONE_CHANGED_NEW_AREA` → `isSlowSkyriding` | Affects color thresholds in OnUpdate |
| LEM `layout` callback → `SetScale` | Common user flow when changing EditMode layouts |
| `C_Timer.After(1)` inside `ApplyCooldownFill` | Resets `_shineActive`; creates async state dependency |

---

## Section 4 — Problems Identified

### Problems found by both analyses

| Problem | GPT-5 mini label | Claude label | Assessment |
|---|---|---|---|
| Over-scheduling via `abilityFrameDirty` polling | P1 | P2-C context (noted but not primary concern) | Both identified it. GPT-5 mini rates it P1; Claude considers the dirty-flag polling pattern correct as-is and rates the *double event* path (P2-B) as a more concrete concern. |
| Broad refresh scope (`RefreshConfig` → all 3 sub-functions) | P3 | P3-A | Agreement. |

### Problems found only by Claude

| Problem | Claude label | Why GPT-5 mini missed it |
|---|---|---|
| Double `RefreshConfig` on `CopyProfile`/`ResetCurrentProfile` | P1-A | Requires reading the AceDB callback registration AND the explicit call in each method body together. GPT-5 mini read the callback registrations but not the method bodies at those specific lines. |
| `singleFrameMode` toggle calls `CreateAllFrames` without restoring active state | P1-B | Requires reading `Options.lua`. Not read by GPT-5 mini. |
| Two independent events (`UNIT_POWER_UPDATE` + `SPELL_UPDATE_CHARGES`) calling `UpdateChargeBars` for the same underlying data | P2-B | Requires reading both event handler branches simultaneously and noting they write the same outputs. |
| `UpdateSecondWind` called twice per `RefreshConfig` | P2-C | Requires reading `RefreshConfig` body carefully (line 759 + 761) and understanding that `UpdateAllFrameAppearance` → `UpdateSecondWindBarAppearance` is distinct from the separate `UpdateSecondWind()` call. |
| `vigorRechargeTimer` / `secondWindRechargeTimer` not reset in `StopTracking` | P3-B | Requires trace across `UpdateChargeBars`, `setBarRechargeTimer`, and `StopTracking`. |

### Problem noted by GPT-5 mini that Claude assessed differently

**GPT-5 mini P2 "Listener fan-out":** GPT-5 mini flagged LEM callback registration as a
potential fan-out problem, then immediately admitted the `lemCallbacksRegistered` guard
prevents it. Claude chose not to list a guarded, non-firing problem as a problem area.
Including it as P2 inflates the problem count and could lead a developer to remove a guard that
should stay.

**GPT-5 mini P2 "Deferred-call stacking":** GPT-5 mini described the `C_Timer.After(10)` and 
`C_Timer.After(2.5)` timers as "deferred-call stacking." Claude notes these are two *independent*
timers that serve different purposes and do not call each other; they are not the same as queued
next-frame defers racing for the same operation. Claude documents them accurately as a startup
ordering concern in Cross-Cutting Patterns rather than a problem area.

---

## Section 5 — Cascade Path Inventory

GPT-5 mini's inventory: 3 rows, all sourced from `zSkyridingBar.lua` only.

Claude's inventory: 7 rows, includes settings-change and profile-copy paths sourced from
both files, with explicit worst-case operation counts.

The most important omission is the profile-copy row: GPT-5 mini never modelled the
`OnProfileChanged/Copied/Reset` → `RefreshConfig` chain, so the "2× RefreshConfig on CopyProfile"
problem was invisible to it.

---

## Section 6 — Refactor Proposals Comparison

### Structural approach

| Dimension | GPT-5 mini | Claude |
|---|---|---|
| Number of proposed new functions | 5 (all new) | 2 new + 1 new flag + 2 targeted removals |
| Architectural scope | Large (new dispatch layer + pure computation step + new apply layer) | Surgical (minimal changes, preserve existing patterns) |
| New `C_Timer.After(0)` deferral usage | For ALL refresh types via `CoalesceAndRunRefresh` | Scoped only to `CheckAvailabilityOnce` (one specific over-firing problem) |

### Proposal-by-proposal mapping

**GPT-5 mini Proposal 1: `CoalesceAndRunRefresh(reason)`**

Routes all refresh paths through a single `C_Timer.After(0)` scheduler. Claude's Proposal 3
(`CheckAvailabilityOnce`) addresses the same underlying over-firing but only at the
`CheckSkyridingAvailability` call sites — the one place where back-to-back calls actually
happen. GPT-5 mini's broader coalescing would also defer `RefreshConfig` (settings changes)
by one frame, which introduces an observable lag in the config panel where a slider change
would not apply until the next game frame. This is likely undesirable in a settings panel
context.

Additionally, GPT-5 mini's proposal explicitly defers the `speedBarOnUpdate` ridealong case
via the same coalescer. Claude's analysis identified this as unsafe: the ridealong dismount
fix requires the OnUpdate to be detached *in the same synchronous call* so the callback stops
firing. Routing it through a next-frame `C_Timer.After(0)` would allow one extra OnUpdate
tick with gliding state = false, which is harmless but unnecessary and contradicts the reason
the direct call was added.

**GPT-5 mini Proposal 2: `UpdateCaches()`**

Centralises all phase-2 cache writes into one function. Claude identified this as
architecturally valid but over-engineered given the actual problems found. The existing
`abilityFrameDirty` flag already implements a correct dirty-cache pattern. Claude's Proposal 4
(`chargesFrameDirty` flag) extends the same already-proven pattern to the charge-bar path
rather than introducing a new abstraction layer.

**GPT-5 mini Proposal 3/4: `RecomputeVisualState()` + `ApplyVisuals(stateTable)`**

This is a significant architectural overhaul: split all update functions into a pure
"compute desired state" phase and a separate "apply" phase. Claude did not propose this for
one specific reason: WoW's animation system (`fadeIn:IsPlaying()`, `fadeOut:IsPlaying()`) is
live frame state that must be checked at the moment of application (in `HideWithFade` and
`ShowWithFade`). A pre-computed state table from `RecomputeVisualState()` would not know
whether a fade animation started between the computation and the application. Including
animation state in the table binds the API of both functions to WoW's animation objects,
defeating the goal of separation. The pattern is sound in a web or Qt context where the
"virtual DOM" diff is idiomatic; in WoW's Lua it introduces a new class of subtle ordering
bugs.

**GPT-5 mini Proposal 5: `ScheduleCooldownPoll(spellId, callback, minDuration)`**

Proposes replacing the `abilityFrameDirty` OnUpdate poll with an explicit cooldown-aware
poller. Claude's assessment: the `abilityFrameDirty` mechanism is already correct and
identified as a known re-entrancy guard. GPT-5 mini's analysis describes the dirty-polling
as a P1 problem, but reading the code shows it is throttled to `BAR_TICK_RATE = 1/15s` and
the flag is cleared on first execution — it does not run "many times during short windows"
as described. The real cost is BAR_TICK_RATE-capped, not per-frame. Replacing it with a
separate poller adds complexity without a measurable benefit.

### Problems GPT-5 mini proposals do not address

Because GPT-5 mini's analysis missed P1-A and P1-B entirely, its refactor document has no
proposals for:

- The double `RefreshConfig` on profile copy/reset (Claude Proposal 2).
- The invisible-UI bug when toggling `singleFrameMode` while mounted (Claude Proposal 1).

These are the two highest-confidence, lowest-risk, highest-impact fixes in the codebase.
Both require fewer than 5 lines of changes.

---

## Section 7 — "What Old Functions Become" Table

GPT-5 mini's table has 6 entries. Claude's has 15 entries, enumerated for every function
named in the analysis document. The guidance document requires: *"Every function named in
Document 1 must appear here."* GPT-5 mini's table omits `UpdateSecondWind`,
`UpdateSecondWindBarAppearance`, `UpdateSpeedBarAppearance`, `UpdateChargesBarAppearance`,
`UpdateFonts`, `CreateAllFrames`, and `OnUnitPowerUpdate`.

---

## Section 8 — Correctness of Code Citations

GPT-5 mini referenced line numbers throughout (e.g. `zSkyridingBar.lua:L1431-L1489`). Spot
checks against the actual file confirm these are approximately correct at the time the
analysis was done, though some references point to ranges that span two unrelated functions.

Claude's citations use specific single line references when pointing at a specific statement
(e.g. line 593 for the duplicate `RefreshConfig` call in `CopyProfile`) and ranges only when
describing a function body.

---

## Summary

| Metric | GPT-5 mini | Claude |
|---|---|---|
| Files read | 1 (zSkyridingBar.lua) | 2 primary + locale + lib internals |
| Entry points catalogued | 4 | 22 |
| P1 problems identified | 1 | 2 |
| P2 problems identified | 2 (1 a false positive) | 3 |
| P3 problems identified | 1 | 2 |
| Refactor proposals | 5 (large architectural scope) | 4 targeted fixes + 1 no-op clarification |
| Highest-impact fix proposed | `CoalesceAndRunRefresh` (broad deferred scheduler) | `RestoreActiveState` + duplicate-call removal (2–5 lines each) |
| Novel WoW-specific concerns | None noted | C_Timer.After(0) unsafety for OnUpdate detach; animation state incompatibility with pure state-table pattern |
| "What old functions become" completeness | 6 of ~15 functions accounted for | All 15 functions accounted for |
