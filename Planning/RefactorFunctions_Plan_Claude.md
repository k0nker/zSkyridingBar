# Refactor Functions Plan (Claude)

> Proposals derived exclusively from code read in `zSkyridingBar.lua` and `Options.lua`.
> No speculative problems included. Every proposal maps to a named problem in
> `CascadeAnalysis_Plan_Claude.md`.

---

## Immutable Phase Order

The following order is enforced by data dependencies. Any operation that reads
from a later phase, or writes to an earlier phase, is a defect.

| Phase | Name | Responsible code today | Reads from | Writes to |
|---|---|---|---|---|
| 1 | **Read external state** | `GetGlidingInfo()`, `C_Spell.GetSpellCharges()`, `C_UnitAuras.GetPlayerAuraBySpellID()` | WoW API (authoritative) | — |
| 2 | **Update logical cache** | `UpdateChargeBars`, `OnUnitAura`, state assignments in `speedBarOnUpdate` | Phase 1 results | `active`, `thrillActive`, `abilityFrameDirty`, `previousChargeCount`, `chargesInitialized`, `ascentStart` |
| 3 | **Decide visual targets** | logic inside `UpdateStaticChargeAndWhirlingSurge`, `UpdateSecondWind`, `speedBarOnUpdate` color block | Phase 2 cache | Internal decision variables (colors, show/hide) |
| 4 | **Apply visuals** | `SetValue`, `SetStatusBarColor`, `ShowWithFade`, `HideWithFade`, `SetFont`, `SetText` | Phase 3 decisions | WoW frame objects |
| 5 | **Deferred side effects** | `C_Timer.After`, animation callbacks, `PlaySound` | Phase 4 completion | Timer / sound engine |

**Critical constraint:** Phase 1 must always be read fresh — never cached across frames —
because gliding state, charges, and auras can change between any two frames. Phases 2–4
must complete in-order within the same call stack for correct behavior.

---

## Proposals

---

### 1. `RestoreActiveState()` — Re-enter tracking after frame reconstruction

- **Status:** New helper
- **Replaces:** Ad-hoc `active = false; self:CheckSkyridingAvailability()` pattern that exists
  in `OnInitialize` (lines 483–485) but is absent from the `singleFrameMode` toggle in `Options.lua:365`.
- **Fixes:** P1-B

**Signature:**
```lua
local function RestoreActiveState()
```

**Parameters:** None.

**Behaviour:**
1. Set `active = false` — clears the tracking flag so `CheckSkyridingAvailability` will
   enter the `if not active then` branch.
2. Call `zSkyridingBar:CheckSkyridingAvailability()` — re-evaluates gliding state and calls
   `StartTracking` (or `StopTracking`) as appropriate.

**Key guarantees:** After `CreateAllFrames` tears down and rebuilds all frame references,
this function ensures the OnUpdate is re-attached to the new `speedBar` and frames are
shown or hidden to match current gliding state.

**What this eliminates:** The live-skyriding invisible-UI bug (P1-B): toggling
`singleFrameMode` while mounted leaves the UI in a permanently hidden state.

**Migration — call site replacements:**

| Old pattern | New pattern | Location |
|---|---|---|
| `zSkyridingBar:CreateAllFrames()` (singleFrameMode toggle) | `zSkyridingBar:CreateAllFrames(); RestoreActiveState()` | `Options.lua:365` |
| `self:CreateAllFrames(); active = false; self:CheckSkyridingAvailability()` (OnInitialize) | `self:CreateAllFrames(); RestoreActiveState()` | `zSkyridingBar.lua:483–485` |

**Files:** `Options.lua` (primary fix site), `zSkyridingBar.lua` (consolidate existing pattern).

---

### 2. `ApplyProfileRefresh()` — Single authoritative post-profile-change refresh

- **Status:** Rename / replacement
- **Replaces:** The explicit `self:RefreshConfig()` calls at lines 552 and 593 that duplicate
  the AceDB-triggered callback. The callbacks at lines 488–490 remain.
- **Fixes:** P1-A

**Signature:**
```lua
function zSkyridingBar:ApplyProfileRefresh()
```

**Parameters:** None. (Identical body to current `RefreshConfig`; only call sites change.)

**Behaviour:** Identical to `RefreshConfig` today. No functional change to the body.

**Key guarantees:** Fires exactly once per profile operation because the explicit duplicate
calls are removed from `CopyProfile` (line 593) and `ResetCurrentProfile` (lines 551–552).
The AceDB callbacks remain as the single trigger point.

**What this eliminates:**
- Double `RefreshConfig` on `CopyProfile` (P1-A).
- Double `RefreshConfig` on `ResetCurrentProfile` (P1-A).
- By extension: the four-call `UpdateSecondWind` chain (2 × RefreshConfig × 1 UpdateSecondWind
  each) reduces to two calls.

**Migration — call site replacements:**

| Old code | New code | Location |
|---|---|---|
| `self.db:CopyProfile(sourceName)` then `self:RefreshConfig()` | `self.db:CopyProfile(sourceName)` (remove explicit call; callback fires it) | `zSkyridingBar.lua:592–593` |
| `self.db:ResetProfile()` then preset-writes then `self:RefreshConfig()` | `self.db:ResetProfile()` then preset-writes (remove explicit call) | `zSkyridingBar.lua:549–552` |

**Note:** The `OnProfileChanged`, `OnProfileCopied`, and `OnProfileReset` callbacks are all
mapped to `"RefreshConfig"` (string method reference). Rename `RefreshConfig` → `ApplyProfileRefresh`
only if the callbacks are updated to match. Simplest path: **keep the name `RefreshConfig` and
simply remove the explicit duplicate calls.**

**Files:** `zSkyridingBar.lua` only, two call sites.

---

### 3. `CheckAvailabilityOnce()` — Coalesced single-frame availability guard

- **Status:** New (thin wrapper around `CheckSkyridingAvailability`)
- **Replaces:** All 6 direct call sites of `CheckSkyridingAvailability` that can fire simultaneously.
- **Fixes:** P2-A

**Signature:**
```lua
local checkAvailabilityScheduled = false

local function CheckAvailabilityOnce()
    if checkAvailabilityScheduled then return end
    checkAvailabilityScheduled = true
    C_Timer.After(0, function()
        checkAvailabilityScheduled = false
        zSkyridingBar:CheckSkyridingAvailability()
    end)
end
```

**Parameters:** None.

**Behaviour:**
1. If a check is already scheduled for this frame, return immediately (no-op).
2. Otherwise, set the flag and schedule `CheckSkyridingAvailability` to run after the current
   event batch completes (next frame boundary via `C_Timer.After(0, ...)`).
3. When the timer fires, clear the flag then call `CheckSkyridingAvailability`.

**Key guarantees:** Regardless of how many events fire in one frame that would each
independently call `CheckSkyridingAvailability` (e.g. `PLAYER_ENTERING_WORLD` + `PLAYER_CAN_GLIDE_CHANGED`),
exactly one check runs per frame boundary.

**Important constraint on the `speedBarOnUpdate` call site:** After the ridealong patch,
`speedBarOnUpdate` calls `CheckSkyridingAvailability` directly (not through this wrapper) because
it needs the OnUpdate detached in the *same* synchronous call (so it stops firing). Deferring
that to the next frame would cause one extra OnUpdate tick with stale state. The `speedBarOnUpdate`
call site must remain a direct call to `CheckSkyridingAvailability()`.

**Migration — call site replacements:**

| Old call | New call | Location |
|---|---|---|
| `zSkyridingBar:CheckSkyridingAvailability()` (PLAYER_CAN_GLIDE_CHANGED) | `CheckAvailabilityOnce()` | `zSkyridingBar.lua:463` |
| `self:CheckSkyridingAvailability()` (OnAddonLoaded) | `CheckAvailabilityOnce()` | `zSkyridingBar.lua:1296` |
| `self:CheckSkyridingAvailability()` (OnPlayerEnteringWorld) | `CheckAvailabilityOnce()` | `zSkyridingBar.lua:1301` |
| `self:CheckSkyridingAvailability()` (LEM exit callback) | `CheckAvailabilityOnce()` | `zSkyridingBar.lua:793` |
| `self:CheckSkyridingAvailability()` (OnEnable) | `CheckAvailabilityOnce()` | `zSkyridingBar.lua:638` |
| `zSkyridingBar:CheckSkyridingAvailability()` (speedBarOnUpdate) | **keep as direct call** | `zSkyridingBar.lua:1344` |

**Files:** `zSkyridingBar.lua`.

---

### 4. `UpdateChargeState()` — Single entry point for vigor/charge reads

- **Status:** New (consolidation)
- **Replaces:** The two separate direct calls to `UpdateChargeBars` from `UNIT_POWER_UPDATE`
  and `SPELL_UPDATE_CHARGES` handlers. Introduces a single-fire guard analogous to `abilityFrameDirty`.
- **Fixes:** P2-B

**Signature:**
```lua
local chargesFrameDirty = false

local function MarkChargesDirty()
    chargesFrameDirty = true
end
```

Consumed in `speedBarOnUpdate` at the throttled tick section:
```lua
if chargesFrameDirty then
    chargesFrameDirty = false
    zSkyridingBar:UpdateChargeBars()
    zSkyridingBar:UpdateSecondWind()
end
```

**Parameters:** None.

**Behaviour:**
1. Both `UNIT_POWER_UPDATE(ALTERNATE)` and `SPELL_UPDATE_CHARGES` handlers call `MarkChargesDirty()` instead of `UpdateChargeBars` directly.
2. The `speedBarOnUpdate` throttled section checks `chargesFrameDirty` and calls both `UpdateChargeBars` and `UpdateSecondWind` exactly once per dirty cycle.
3. `StartTracking` still calls `UpdateChargeBars()` directly (it needs immediate state, no deferral).

**Key guarantees:** Even if both events fire in the same frame, `UpdateChargeBars` runs at most once per `BAR_TICK_RATE` interval. The charge-refresh sound can never double-play for a single charge event.

**Key constraint:** This deferral applies only while `active = true` (OnUpdate is running).
The existing `SPELL_UPDATE_CHARGES` guard `if active then` (line 473) must be preserved.

**Migration call site replacements:**

| Old | New | Location |
|---|---|---|
| `zSkyridingBar:OnUnitPowerUpdate(...)` which calls `UpdateChargeBars` | `if powerType == "ALTERNATE" then MarkChargesDirty() end` | `zSkyridingBar.lua:467–470` |
| `zSkyridingBar:UpdateChargeBars()` in SPELL_UPDATE_CHARGES | `MarkChargesDirty()` | `zSkyridingBar.lua:474` |
| `zSkyridingBar:UpdateSecondWind()` in SPELL_UPDATE_CHARGES | removed (handled inside MarkChargesDirty consumer) | `zSkyridingBar.lua:475` |

**Files:** `zSkyridingBar.lua`.

---

### 5. `RefreshConfig` — Eliminate double `UpdateSecondWind`

- **Status:** Targeted body fix (not renamed)
- **Replaces:** The current two-path second-wind update inside `RefreshConfig`.
- **Fixes:** P2-C

**Current body of `RefreshConfig` (lines 756–771):**
```lua
function zSkyridingBar:RefreshConfig()
    if self._seeding then return end
    self:UpdateAllFrameAppearance()   -- calls UpdateSecondWindBarAppearance (texture/size only)
    self:UpdateSecondWind()           -- called again: re-applies active fill values
    self:UpdateFonts()
    ...
end
```

The intent of calling `UpdateSecondWind` separately is documented in the comment at line 760:
`SetStatusBarTexture` resets the fill to 0, so `UpdateSecondWind` must re-apply the fill
after `UpdateSecondWindBarAppearance` resets the texture.

**Proposed minimal fix:** The secondary call to `UpdateSecondWind()` should be **removed from
`UpdateAllFrameAppearance`'s sub-call chain** and only happen in `RefreshConfig`. The current
code is already structured this way — the duplication comes from P1-A (double `RefreshConfig`
per profile operation), not from the body of `RefreshConfig` itself. Fixing P1-A via Proposal 2
eliminates the double-call chain. No body change to `RefreshConfig` is needed.

**Revised verdict:** This is not a standalone fix; it resolves itself once Proposal 2 is
implemented. Document here for traceability.

---

## Interaction Map

### (A) Data-driven event refresh — single vigor charge completes

```
UNIT_POWER_UPDATE(ALTERNATE)
SPELL_UPDATE_CHARGES           ──► MarkChargesDirty()   [sets chargesFrameDirty = true]
                                             │
                              (both events handled; flag set once)
                                             │
                              next BAR_TICK_RATE boundary in speedBarOnUpdate
                                             │
                                             ▼
                                  UpdateChargeBars()     [Phase 1+2+4: reads API, updates bars]
                                  UpdateSecondWind()     [Phase 1+2+4: reads API, updates bar]
```

### (B) Settings-change refresh — user changes font size

```
Options.lua set() handler
  db.profile.fontSize = value
  RefreshConfig()
       │
       ├─ UpdateAllFrameAppearance()
       │    ├─ UpdateSpeedBarAppearance()        [Phase 4, appearance only]
       │    ├─ UpdateChargesBarAppearance()      [Phase 4, appearance only]
       │    └─ UpdateSecondWindBarAppearance()   [Phase 4, texture/size only]
       ├─ UpdateSecondWind()                     [Phase 1+4, re-applies active fill]
       └─ UpdateFonts()                          [Phase 4, font strings only]
```

### (C) Profile copy — user copies another profile into current

```
[before Proposal 2]   db:CopyProfile() ─► OnProfileCopied ─► RefreshConfig ─► ...
                      + explicit self:RefreshConfig()  ─► ...  (two full runs)

[after Proposal 2]    db:CopyProfile() ─► OnProfileCopied ─► RefreshConfig ─► ...
                      (single run; explicit call removed)
```

---

## Phased Implementation Order

| Step | Proposal | Prerequisite | Risk | Verify in-game |
|---|---|---|---|---|
| 1 | **Proposal 2**: Remove duplicate `RefreshConfig` from `CopyProfile`/`ResetCurrentProfile` | None | Very low — changes only timing of second call | Copy a profile; confirm no flicker and `UpdateSecondWind` runs once |
| 2 | **Proposal 1**: Add `RestoreActiveState()` and call it after `CreateAllFrames` in Options.lua | None | Low | Toggle `singleFrameMode` while mounted; bars should immediately re-appear |
| 3 | **Proposal 3**: Add `CheckAvailabilityOnce` wrapper for 5 of 6 call sites | None | Low — logic unchanged, only timing shifts by ≤1 frame | Zone into a skyriding area while mounted; confirm bars appear without double StartTracking |
| 4 | **Proposal 4**: Add `chargesFrameDirty` flag; route two event handlers through it | Step 3 should be in place for stability | Medium — changes event-to-update path | Verify charge bars update within one `BAR_TICK_RATE` tick of a vigor recharge |

---

## What the Old Functions Become

| Old function | Fate | Reason |
|---|---|---|
| `CheckSkyridingAvailability` | **Keep** — no body change | Remains the authoritative check; caller sites gain the `CheckAvailabilityOnce` wrapper |
| `StartTracking` | **Keep** — no body change | Correct as-is; called by `CheckSkyridingAvailability` only |
| `StopTracking` | **Keep** — no body change | Correct; also sets OnUpdate to nil for ridealong fix |
| `RefreshConfig` | **Keep** — no body change | Body is correct; only caller-side duplicates removed per Proposal 2 |
| `UpdateAllFrameAppearance` | **Keep** — no body change | Reasonable scope; P3-A is noted but not proposed for refactor at this time |
| `UpdateChargeBars` | **Keep** — called from `StartTracking` and by `chargesFrameDirty` consumer | Direct call from StartTracking remains; event calls replaced by Proposal 4 |
| `UpdateSecondWind` | **Keep** — no change | Redundant double-call resolves via Proposal 2, not body change |
| `UpdateStaticChargeAndWhirlingSurge` | **Keep** — no change | `abilityFrameDirty` pattern is correct; no duplication |
| `UpdateSpeedBarAppearance` | **Keep** | Terminal action, scoped correctly |
| `UpdateChargesBarAppearance` | **Keep** | Terminal action, scoped correctly |
| `UpdateSecondWindBarAppearance` | **Keep** | Terminal action, scoped correctly |
| `UpdateFonts` | **Keep** | Terminal action, scoped correctly |
| `CreateAllFrames` | **Keep — two call sites add `RestoreActiveState()`** | Proposal 1 |
| `OnUnitPowerUpdate` | **Simplify** — body replaced by `MarkChargesDirty()` | Proposal 4 |
