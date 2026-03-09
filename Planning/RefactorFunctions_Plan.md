# Refactor Functions Plan

**Goal:** propose a set of refactor functions that impose a clear phased order for refresh cascades and reduce over-scheduling and broad refresh scope. All mappings reference existing functions in `zSkyridingBar.lua`.

## Immutable Phase Order (reads/writes)
1. Read Input State (Event/Timer/OnUpdate) — responsible: event handlers / `speedBarOnUpdate`  
   - Reads: `GetGlidingInfo`, `C_Spell.GetSpellCharges`, `C_UnitAuras.GetPlayerAuraBySpellID`  
   - Files: [zSkyridingBar.lua](zSkyridingBar.lua#L1324-L1339), [zSkyridingBar.lua](zSkyridingBar.lua#L1556-L1568), [zSkyridingBar.lua](zSkyridingBar.lua#L1610-L1620)
2. Update Logical Cache — responsible: cache updater functions  
   - Writes: `previousChargeCount`, `chargesInitialized`, `thrillActive`, `abilityFrameDirty`  
   - Files: `UpdateChargeBars`, `OnUnitAura`, `OnUnitPowerUpdate` ([zSkyridingBar.lua](zSkyridingBar.lua#L1556-L1628), [zSkyridingBar.lua](zSkyridingBar.lua#L1208-L1216))
3. Recompute Derived State — responsible: central `RecomputeVisualState()` (proposed)  
   - Reads caches, computes which frames should be shown/hidden, target values for bars/icons
4. Apply Visual Changes — responsible: `ApplyVisuals()` (proposed)  
   - Calls `SetValue`, `SetStatusBarColor`, `ShowWithFade`/`HideWithFade`, `SetPoint`/`SetSize`
5. Post-flight / timers — responsible: scheduling `C_Timer.After` side effects (e.g., shine fades), leave to existing timer utilities in code.

This ordering must be preserved: reading happens before cache updates, and derived visual recomputation must read caches that are fully updated.

---

## Proposed Functions (one per proposal)

### 1. `CoalesceAndRunRefresh(reason)` — Central refresh entry point
- **Status:** New
- **Replaces:** ad-hoc direct calls to `Update*` from multiple sites (where safe to centralize)
- **Signature:** `CoalesceAndRunRefresh(reason: string)`
- **Parameters:**  
  - `reason` (string) — short label (e.g., "SPELL_UPDATE_CHARGES", "UNIT_AURA", "OnUpdateTick")
- **Behaviour:**
  1. If a refresh is already scheduled this frame, append `reason` to its metadata and return.
  2. Otherwise, schedule a single `C_Timer.After(0, function()` to run the refresh on next tick.
  3. When executed, it runs the phases: `UpdateCaches()`, `RecomputeVisualState()`, `ApplyVisuals()` in-order.
- **Key guarantees:** coalesces multiple near-simultaneous triggers into one refresh; runs phases in immutable order.
- **What this eliminates:** Over-scheduling (P1/P3), deferred-call stacking (P2) when multiple events fire in quick succession.
- **Migration — call site replacements:**
  - Replace direct `UpdateChargeBars()` calls from `SPELL_UPDATE_CHARGES` with `CoalesceAndRunRefresh('SPELL_UPDATE_CHARGES')`.
  - Replace `abilityFrameDirty` immediate calls from `UNIT_AURA` with mark-and-coalesce: set cache then `CoalesceAndRunRefresh('UNIT_AURA')`.
- **Files:** `zSkyridingBar.lua` (replace ad-hoc event handler direct calls listed in [zSkyridingBar.lua](zSkyridingBar.lua#L428-L444)).

### 2. `UpdateCaches()` — canonical cache updater
- **Status:** New (replacement/centralization)
- **Replaces:** piecemeal cache writes in disparate handlers
- **Signature:** `UpdateCaches(trigger)`
- **Parameters:** `trigger` (string) indicates cause for audit/logging
- **Behaviour:**
  1. Re-read authoritative sources needed for UI: `C_Spell.GetSpellCharges` (surge/second wind), `C_UnitAuras.GetPlayerAuraBySpellID` (thrill/static charge), `GetGlidingInfo()`.
  2. Update package-level caches: `previousChargeCount`, `chargesInitialized`, `secondWind` counters, `thrillActive`, `abilityFrameDirty` as appropriate.
- **Key guarantees:** All cache writes centralized, prevents partial updates.
- **What this eliminates:** Implicit cache invalidation and race windows where some code reads stale caches.
- **Files:** `zSkyridingBar.lua` (`UpdateChargeBars`, `UpdateSecondWind`, `OnUnitAura` become callers of this function).

### 3. `RecomputeVisualState()` — compute target UI state but don't apply
- **Status:** New
- **Replaces:** logic currently embedded in `StartTracking`, `Update*`, `UpdateStaticChargeAndWhirlingSurge` (partial)
- **Signature:** `RecomputeVisualState()` -> returns table of desired state for each frame (visibility, sizes, bar values, colors)
- **Behaviour:**
  1. Read caches produced by `UpdateCaches()`.
  2. Decide for each frame whether it should be `shown` or `hidden`, and the target parameters (bar values, icon textures, border visibility).
  3. Return a plain table describing these targets.
- **Key guarantees:** Pure computation—no side effects; allows unit/step-level testing and deterministic diffs.
- **Files:** `zSkyridingBar.lua` (consumer is `ApplyVisuals`).

### 4. `ApplyVisuals(stateTable)` — idempotent DOM mutations
- **Status:** New
- **Replaces:** the current direct SetValue/Show/Hide calls across `Update*` and `StartTracking`/`StopTracking`.
- **Signature:** `ApplyVisuals(stateTable)`
- **Behaviour:**
  1. For each frame entry in `stateTable`, compare current visible state with target; call `ShowWithFade`/`HideWithFade` only if state changes.
  2. Use `SetValue`/`SetStatusBarColor`/`SetTexture` only when the target value differs from the current value (respecting status bar interpolation where used).
  3. Ensure cooldown child frames are zeroed before hiding to avoid visual flash.
- **Key guarantees:** Updates are minimal and guarded, reducing redundant layout churn.
- **Files:** `zSkyridingBar.lua` replacing ad-hoc show/hide paths.

### 5. `ScheduleCooldownPoll(spellId, target, opts)` — coalesced cooldown poller
- **Status:** New
- **Replaces:** repeated polling in `UpdateStaticChargeAndWhirlingSurge` via setting `abilityFrameDirty` and relying on OnUpdate
- **Signature:** `ScheduleCooldownPoll(spellId, callback, minDuration)`
- **Behaviour:** Sets up a lightweight coalesced poll that runs only while a cooldown is in-flight and cancels itself when done; integrates with `CoalesceAndRunRefresh` to avoid per-frame polling when unnecessary.
- **Key guarantees:** Avoids continuous per-frame expensive calls; runs only while needed.
- **Files:** `zSkyridingBar.lua` (used by `RecomputeVisualState`/`ApplyVisuals` to deal with ability cooldowns)

---

## Interaction Map
Two common flows (simplified):

A) Data-driven event refresh (e.g., `SPELL_UPDATE_CHARGES`)

  Event -> event handler -> UpdateCaches() -> RecomputeVisualState() -> ApplyVisuals()
  (All through single `CoalesceAndRunRefresh` scheduling if many events stack)

B) Settings-change refresh (profile changed)

  DB callback `OnProfileChanged` -> call `UpdateFonts()` + `CoalesceAndRunRefresh('PROFILE_CHANGE')` -> UpdateCaches() -> RecomputeVisualState() -> ApplyVisuals()

## Phased Implementation Order
Step | Function | Prerequisite | Risk | Verify
---|---|---:|---:|---
1 | Add `CoalesceAndRunRefresh` + scheduler | none | Low | fire multiple events rapidly and ensure single refresh runs (log/count)
2 | Implement `UpdateCaches` and route `UpdateChargeBars`, `UpdateSecondWind` to call it | Step 1 | Medium | compare cache states before/after triggers
3 | Implement `RecomputeVisualState` (pure) | Step 2 | Medium | unit test by calling with canned caches
4 | Implement `ApplyVisuals` and replace direct Show/Hide calls | Step 3 | Medium-High | visually test transitions
5 | Introduce `ScheduleCooldownPoll` for ability polling | Step 4 | Medium | confirm no per-frame polling when cooldowns idle

## What the Old Functions Become
Old function -> Fate
- `UpdateChargeBars` -> internalized into `UpdateCaches` + small wrapper kept for compatibility and direct calls (Keep as wrapper)
- `UpdateSecondWind` -> internalized into `UpdateCaches` + wrapper (Keep wrapper)
- `UpdateStaticChargeAndWhirlingSurge` -> logic split between `UpdateCaches`, `RecomputeVisualState` and `ScheduleCooldownPoll` (Replace)
- `StartTracking` / `StopTracking` -> keep, but simplify to call `CoalesceAndRunRefresh` as part of StartTracking to ensure consistent initial state (Keep, small edits)

---

**Constraints & Notes**
- No code changes made in this repo as part of this document (per user request). The plan above maps each proposal to the specific functions found in `zSkyridingBar.lua` which should be modified if the team accepts these proposals.
- Every major claim references the files and functions inspected; primary source: `zSkyridingBar.lua`.

