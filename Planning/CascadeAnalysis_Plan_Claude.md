# Cascade & Refresh Architecture Analysis (Claude)

> Files read in full: `zSkyridingBar.lua` (1825 lines), `Options.lua` (1312 lines),
> `Locales/enUS.lua`. Relevant lib internals consulted: `AceDB-3.0.lua`,
> `LibEditMode.lua`, `CallbackHandler-1.0.lua`. All claims cite specific line(s).

---

## Terminology

| Term | Meaning in this codebase |
|---|---|
| **Refresh** | Any execution path that calls `RefreshConfig`, `UpdateAllFrameAppearance`, an individual `Update*Appearance`, `UpdateChargeBars`, `UpdateSecondWind`, or `UpdateStaticChargeAndWhirlingSurge`. A refresh touches visible UI. |
| **Appearance update** | The three sub-functions called from `UpdateAllFrameAppearance`: `UpdateSpeedBarAppearance`, `UpdateChargesBarAppearance`, `UpdateSecondWindBarAppearance`. Each one loops over bars and issues `SetStatusBarTexture`, `SetSize`, `SetVertexColor`, etc. |
| **Dirty** | The `abilityFrameDirty` boolean (`zSkyridingBar.lua` line 224). Set to `true` by `UNIT_AURA` and `SPELL_UPDATE_COOLDOWN` handlers at lines 1216 and 1222. Consumed (cleared to `false`) inside `UpdateStaticChargeAndWhirlingSurge` at line 1620. The flag is *also* re-set to `true` by that same function when a cooldown fill animation is still in progress. |
| **Active** | The `active` local boolean at line 181. `true` means the player is currently gliding/flying and the per-frame OnUpdate is (or should be) attached. |
| **Tracking** | The state where `speedBar:SetScript("OnUpdate", speedBarOnUpdate)` is live. Entered by `StartTracking`, exited by `StopTracking`. |
| **SETTING_CHANGED equivalent** | Any AceDB `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` callback (lines 488–490), or any per-control `set = function(...)` in `Options.lua` that writes to `db.profile` and then calls `RefreshConfig`. |

---

## Entry Points (complete inventory)

All events registered on `eventFrame` at lines 428–439 of `zSkyridingBar.lua`.

| Event / Trigger | Handler | File:Line |
|---|---|---|
| `ADDON_LOADED` (self) | `OnAddonLoaded` → `CheckSkyridingAvailability` | `zSkyridingBar.lua:1295–1302` |
| `PLAYER_ENTERING_WORLD` | `OnPlayerEnteringWorld` → set `isSlowSkyriding` → `CheckSkyridingAvailability` | `zSkyridingBar.lua:1299–1303` |
| `PLAYER_LOGIN` | `OnPlayerLogin` → `C_Timer.After(2.5)` → `UpdateFonts` | `zSkyridingBar.lua:614–621` |
| `UNIT_SPELLCAST_SUCCEEDED` (player) | `OnSpellcastSucceeded` → sets `ascentStart` | `zSkyridingBar.lua:1306–1308` |
| `UNIT_AURA` (player) | `OnUnitAura` → sets `abilityFrameDirty = true`, `thrillActive` | `zSkyridingBar.lua:1210–1216` |
| `UNIT_POWER_UPDATE` (player, ALTERNATE) | `OnUnitPowerUpdate` → `UpdateChargeBars` | `zSkyridingBar.lua:1218–1221` |
| `PLAYER_CAN_GLIDE_CHANGED` | `CheckSkyridingAvailability` | `zSkyridingBar.lua:463` |
| `SPELL_UPDATE_COOLDOWN` | Sets `abilityFrameDirty = true` | `zSkyridingBar.lua:469` |
| `ZONE_CHANGED_NEW_AREA` | Sets `isSlowSkyriding` | `zSkyridingBar.lua:471` |
| `SPELL_UPDATE_CHARGES` | `UpdateChargeBars`, `UpdateSecondWind` (while `active`) | `zSkyridingBar.lua:473–476` |
| `UPDATE_UI_WIDGET` (compat only) | `UpdateVigorFromWidget` | `zSkyridingBar.lua:460–462` |
| `speedBar:OnUpdate` (per-frame) | `speedBarOnUpdate` — speed, color, ability frame | `zSkyridingBar.lua:1327–1407` |
| AceDB `OnProfileChanged` | `RefreshConfig` (method-string callback) | `zSkyridingBar.lua:488` |
| AceDB `OnProfileCopied` | `RefreshConfig` (method-string callback) | `zSkyridingBar.lua:489` |
| AceDB `OnProfileReset` | `RefreshConfig` (method-string callback) | `zSkyridingBar.lua:490` |
| LEM `enter` callback | Show all frames unconditionally | `zSkyridingBar.lua:780–787` |
| LEM `exit` callback | `CheckSkyridingAvailability` | `zSkyridingBar.lua:793` |
| LEM `layout` callback | `SetScale` on each frame per saved scale | `zSkyridingBar.lua:797–812` |
| Options.lua root `set` | writes `db.profile[key]` then `RefreshConfig` | `Options.lua:86–89` |
| Options.lua `singleFrameMode` set | writes `db.profile.singleFrameMode` then `CreateAllFrames` | `Options.lua:363–367` |
| Options.lua `enabled` set | calls `Enable` or `Disable` | `Options.lua:105–112` |
| `C_Timer.After(10)` in `OnInitialize` | `CreateAllFrames`, `active = false`, `CheckSkyridingAvailability` | `zSkyridingBar.lua:482–486` |
| `C_Timer.After(2.5)` in `OnPlayerLogin` | `UpdateFonts`, compat print | `zSkyridingBar.lua:618–620` |
| `C_Timer.After(1)` in `ApplyCooldownFill` | resets `speedAbilityFrame._shineActive` | `zSkyridingBar.lua:414–418` |

---

## Propagation Functions

Functions that call one or more other refresh/update functions as part of their body.

```
CheckSkyridingAvailability()
  ├─ StartTracking()
  │    ├─ speedBar:SetScript("OnUpdate", speedBarOnUpdate)    [attach loop]
  │    ├─ ShowWithFade(speedBarFrame / chargesBarFrame / secondWindFrame)
  │    ├─ UpdateChargeBars()         [terminal: sets 6 bars]
  │    ├─ UpdateStaticChargeAndWhirlingSurge()  [terminal: icons / cooldown overlay]
  │    └─ UpdateSecondWind()         [terminal: second wind bar]
  └─ StopTracking()
       ├─ speedBar:SetScript("OnUpdate", nil)  [detach loop]
       └─ HideWithFade(speedBarFrame / chargesBarFrame / speedAbilityFrame / secondWindFrame)

RefreshConfig()
  ├─ UpdateAllFrameAppearance()
  │    ├─ UpdateSpeedBarAppearance()     [terminal]
  │    ├─ UpdateChargesBarAppearance()   [terminal: also reads previousChargeCount]
  │    ├─ UpdateSecondWindBarAppearance()  [terminal]
  │    └─ conditional Show/Hide on all 4 frames
  ├─ UpdateSecondWind()                  [terminal: called again]
  └─ UpdateFonts()                       [terminal]

speedBarOnUpdate()  [per-frame, throttled sections at BAR_TICK_RATE]
  ├─ speedBar:SetValue(...)              [terminal: every frame if gliding]
  ├─ speedText:SetText(...)             [terminal: throttled]
  ├─ speedBar:SetStatusBarColor(...)    [terminal: change-gated]
  ├─ CheckSkyridingAvailability()        [conditional: if not gliding/flying — post-patch]
  └─ UpdateStaticChargeAndWhirlingSurge()  [conditional: if abilityFrameDirty]

ApplyCooldownFill()
  └─ speedAbilityFrame.cooldown:SetCooldown(), Fill overlay, Shine animation
```

---

## Call-Graph Summary

### 1. Mount / Glide State Change

```
PLAYER_CAN_GLIDE_CHANGED
LEM 'exit' event
PLAYER_ENTERING_WORLD
ADDON_LOADED
speedBarOnUpdate (post-ridealong-patch)
                │
                ▼
  CheckSkyridingAvailability()          zSkyridingBar.lua:1410
          /            \
         ▼              ▼
   StartTracking()   StopTracking()     zSkyridingBar.lua:1431 / 1481
         │              │
         ├─ speedBar OnUpdate attached/detached
         ├─ ShowWithFade / HideWithFade (4 frames)
         ├─ UpdateChargeBars()          zSkyridingBar.lua:1562
         ├─ UpdateStaticCharge...()     zSkyridingBar.lua:1616
         └─ UpdateSecondWind()          zSkyridingBar.lua:1743
```

### 2. Per-Frame Update (while active)

```
Frame tick
  │
  ▼
speedBarOnUpdate()                      zSkyridingBar.lua:1327
  │
  ├─ [every frame]  GetGlidingInfo() poll
  ├─ [every frame]  smoothedSpeed easing → speedBar:SetValue()
  │
  └─ [throttled: BAR_TICK_RATE = 1/15s]
       ├─ speedText:SetText()           (change-gated)
       ├─ speedBar:SetStatusBarColor()  (change-gated via lastSpeedBarColorKey)
       └─ [if abilityFrameDirty]
            └─ UpdateStaticChargeAndWhirlingSurge()
                 └─ ApplyCooldownFill() (if cooldown active)
```

### 3. Settings Change

```
User changes any setting in Options.lua
  │
  ├─ [most controls]
  │    db.profile[key] = value
  │    RefreshConfig()                  zSkyridingBar.lua:756
  │         ├─ UpdateAllFrameAppearance()
  │         │    ├─ UpdateSpeedBarAppearance()
  │         │    ├─ UpdateChargesBarAppearance()
  │         │    ├─ UpdateSecondWindBarAppearance()
  │         │    └─ conditional Show/Hide
  │         ├─ UpdateSecondWind()       [called again, second time]
  │         └─ UpdateFonts()
  │
  └─ [singleFrameMode toggle only]
       db.profile.singleFrameMode = value
       CreateAllFrames()                Options.lua:365 / zSkyridingBar.lua:773
            ├─ releaseAllFrames()
            └─ Create{Speed/Charges/SpeedAbility/SecondWind}Frame()
            [NOTE: no ShowWithFade or re-check after — see P1-B below]
```

### 4. Profile Change (AceDB callbacks)

```
User switches / copies / resets profile
  │
  ├─ AceDB fires OnProfileChanged/Copied/Reset callback
  │    └─ RefreshConfig()
  │
  └─ [for CopyProfile / ResetCurrentProfile]
       Method body ALSO calls self:RefreshConfig() explicitly
       ∴ Two RefreshConfig calls per action (see P1-A)
```

---

## Cascade Path Inventory

| Entry Point | Full Chain | Worst-case Op Count |
|---|---|---|
| `PLAYER_CAN_GLIDE_CHANGED` (mount) | → `CheckSkyridingAvailability` → `StartTracking` → `UpdateChargeBars` + `UpdateStaticCharge…` + `UpdateSecondWind` + 3× ShowWithFade | 3 full Update functions + 3 fade-show + OnUpdate attach |
| `SPELL_UPDATE_CHARGES` | → `UpdateChargeBars` → 6 bar SetValue / color / timer | 6 bar ops + 1 timer set |
| `UNIT_POWER_UPDATE(ALTERNATE)` | → `UpdateChargeBars` | same as above (duplicate path for same data) |
| `UNIT_AURA` | → sets `abilityFrameDirty` → polled by OnUpdate → `UpdateStaticCharge…` | 0-2 function calls per frame until dirty flag cleared |
| `SPELL_UPDATE_COOLDOWN` | → sets `abilityFrameDirty` (same poll path as above) | same |
| Settings change (most controls) | → `RefreshConfig` → `UpdateAllFrameAppearance` (all 3 sub-funcs) + `UpdateSecondWind` + `UpdateFonts` | 5 distinct update functions for every single setting change |
| Profile copy / reset | → `RefreshConfig` × 2 (callback + explicit) | 10 distinct function calls (5 × 2) |
| `singleFrameMode` toggle | → `CreateAllFrames` → `releaseAllFrames` + 4× Create (no re-show) | Full frame reconstruction without re-show if currently active |

---

## Problem Areas by Priority

---

### P1-A — Double `RefreshConfig` on Profile Copy and Profile Reset

**Location:** `zSkyridingBar.lua:488–490` (callback registrations) and `zSkyridingBar.lua:552`, `zSkyridingBar.lua:593`.

**What happens:** `CopyProfile` calls `self.db:CopyProfile(sourceName)`. AceDB fires the registered `OnProfileCopied` callback, which immediately calls `RefreshConfig`. After `CopyProfile` returns, the method body then explicitly calls `self:RefreshConfig()` again (line 593). Two complete appearance refreshes — all five sub-functions — run for one user action. `ResetCurrentProfile` has the identical structure: `self.db:ResetProfile()` triggers `OnProfileReset` → `RefreshConfig`, and then `self:RefreshConfig()` follows at line 552.

**Evidence from code:**
```lua
-- zSkyridingBar.lua lines 488–490
self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
self.db.RegisterCallback(self, "OnProfileCopied",  "RefreshConfig")
self.db.RegisterCallback(self, "OnProfileReset",   "RefreshConfig")

-- zSkyridingBar.lua line 593 (CopyProfile)
self:RefreshConfig()   -- explicit call after db:CopyProfile which already fired the callback

-- zSkyridingBar.lua line 552 (ResetCurrentProfile)
self:RefreshConfig()   -- explicit call after db:ResetProfile which already fired the callback
```

**Severity:** Correctness + minor performance. `UpdateSecondWind` and `UpdateChargesBarAppearance` each call `SetStatusBarTexture` which resets status bar fill values to 0, potentially causing a one-frame flicker between the two runs.

**Risk if left unfixed:** Harmless at the current scale, but if more callbacks are registered or RefreshConfig becomes more expensive, the second run becomes a harder-to-trace source of visual flicker.

---

### P1-B — `singleFrameMode` Toggle Calls `CreateAllFrames` Without Restoring Active State

**Location:** `Options.lua:363–367` and `zSkyridingBar.lua:482–486` (the correct reference pattern).

**What happens:** When the user toggles `singleFrameMode`, the `set` handler writes the new value and calls `zSkyridingBar:CreateAllFrames()`. `CreateAllFrames` calls `releaseAllFrames()` which nils every frame reference including `speedBar`. New frames are created but all start hidden. However, `active` is never reset and `CheckSkyridingAvailability` is never called. If the player is currently gliding: `active` remains `true`, but no new OnUpdate is attached to the newly created `speedBar`, and no frames are shown. The UI disappears until the player dismounts and remounts.

The correct pattern is used in `OnInitialize` (lines 482–486):
```lua
C_Timer.After(10, function()
    self:CreateAllFrames()
    active = false                      -- reset so StartTracking re-runs
    self:CheckSkyridingAvailability()   -- re-show frames if needed
end)
```
`Options.lua:365` omits both of those follow-up steps.

**Severity:** Correctness bug. A user toggling this setting while mounted loses their UI.

**Risk if left unfixed:** Will be filed as a bug report. The missing `active = false; CheckSkyridingAvailability()` pattern is already established in `OnInitialize` — the fix is a two-line addition in `Options.lua`.

---

### P2-A — `CheckSkyridingAvailability` Called From 6 Sites With No Coalescing Guard

**Location:** All callers: `OnAddonLoaded` (line 1296), `OnPlayerEnteringWorld` (line 1301), `PLAYER_CAN_GLIDE_CHANGED` handler (line 463), LEM `exit` callback (line 793), `OnEnable` (line 638), and `speedBarOnUpdate` after the ridealong patch (lines 1344–1348).

**What happens:** `PLAYER_ENTERING_WORLD` and `PLAYER_CAN_GLIDE_CHANGED` can fire in the same game tick when zoning into a skyriding-enabled area while already mounted. Both call `CheckSkyridingAvailability` back-to-back. The `active` guard prevents a second call to `StartTracking` if already active, but on first mount-up both fire while `active = false`, causing two `StartTracking` calls, each attaching the OnUpdate and calling `UpdateChargeBars`, `UpdateStaticChargeAndWhirlingSurge`, and `UpdateSecondWind`.

**Evidence from code:**
```lua
-- Lines 457–464: both events call the same function
elseif event == "PLAYER_ENTERING_WORLD" then
    zSkyridingBar:OnPlayerEnteringWorld()    -- includes CheckSkyridingAvailability
...
elseif event == "PLAYER_CAN_GLIDE_CHANGED" then
    zSkyridingBar:CheckSkyridingAvailability()
```

**Severity:** Performance (3 Update functions × 2 = 6 redundant calls on initial mount) and minor correctness (OnUpdate is set twice, the second assignment overwrites the first which is harmless in WoW but is unguarded work).

**Risk if left unfixed:** Scales linearly with each new caller of `CheckSkyridingAvailability`. Currently acceptable; would become a problem if more lifecycle hooks are added.

---

### P2-B — `UpdateChargeBars` Invoked by Two Independent Events for the Same Underlying Data

**Location:** `zSkyridingBar.lua:469–476` (`UNIT_POWER_UPDATE` and `SPELL_UPDATE_CHARGES` handlers).

**What happens:** When vigor recharges, WoW fires both `UNIT_POWER_UPDATE(player, "ALTERNATE")` and `SPELL_UPDATE_CHARGES`. Each independently calls `UpdateChargeBars`. Both function calls execute synchronously within the same event handler dispatch loop (the timer delay between them is zero or near-zero). `UpdateChargeBars` calls `C_Spell.GetSpellCharges`, iterates up to 6 bars, and if the charge sound is enabled, checks whether to play it twice — risking a double sound play.

**Evidence:**
```lua
-- Lines 469–476
elseif event == "UNIT_POWER_UPDATE" then
    local unitTarget, powerType = select(1, ...), select(2, ...)
    zSkyridingBar:OnUnitPowerUpdate(unitTarget, powerType)  -- calls UpdateChargeBars
...
elseif event == "SPELL_UPDATE_CHARGES" then
    if active then
        zSkyridingBar:UpdateChargeBars()   -- calls it again
        zSkyridingBar:UpdateSecondWind()
    end
```

**Severity:** Performance (2× bar loop per charge event) and correctness (the charge-refresh sound at line 1575-1577 could fire twice for a single charge refill if `charges > previousChargeCount` is still true on the second call — `previousChargeCount` is updated on the first call, so the second call sees the already-updated value and does NOT double-play. So correctness is safe, but the 6-bar loop runs twice).

---

### P2-C — `UpdateSecondWind` Called Twice Per `RefreshConfig`

**Location:** `zSkyridingBar.lua:756–771` (`RefreshConfig`): line 759 calls `UpdateAllFrameAppearance`, which calls `UpdateSecondWindBarAppearance`. Then line 761 calls `UpdateSecondWind()` separately (intended to re-apply active values after texture reset). However `UpdateSecondWindBarAppearance` does not call `UpdateSecondWind` — they are distinct. The comment at line 760 says "Re-apply current bar state; `SetStatusBarTexture` resets fill value to 0" — the intent is correct but the actual second call in `UpdateSecondWind` resets `secondWindBar:SetStatusBarColor`, `SetValue`, and timer. This is two full second-wind updates per `RefreshConfig` call. Combined with P1-A, this is four second-wind updates for a single profile copy.

---

### P3-A — `RefreshConfig` Always Refreshes All Three Bar Appearance Sub-functions

**Location:** `zSkyridingBar.lua:758` → `UpdateAllFrameAppearance` → three sub-functions.

**What happens:** Any single settings change — font size, charge bar color, second wind bar height — drives all three bar appearance functions plus `UpdateSecondWind` and `UpdateFonts`. For example, changing only the font triggers `UpdateChargesBarAppearance` which re-iterates all 6 charge bars and calls `SetStatusBarTexture`, `SetSize`, and vertex color updates unnecessarily.

**Severity:** Low performance cost at current scale but a structural problem. As the number of settings and bars grows, the blast radius of any single settings change grows proportionally.

---

### P3-B — `vigorRechargeTimer` and `secondWindRechargeTimer` Not Reset in `StopTracking`

**Location:** Local variables at lines 234–235. Set in `UpdateChargeBars` (line 1601) and `UpdateSecondWind` (lines 1762–1763). Never cleared in `StopTracking` (lines 1481–1534).

**What happens:** The `setBarRechargeTimer` helper accepts an `existing` timer and reuses it (`bar:SetTimerDuration(timer)`). On remount after a dismount mid-recharge, the reused C_DurationUtil objects carry stale start/duration values until `setBarRechargeTimer` is called, which immediately updates them. This is functionally safe today because `UpdateChargeBars` always overwrites the timer before the bar is shown. However, if the nil-check or short-circuit path were ever changed, stale timers could display incorrect values.

---

## Cross-Cutting Patterns

**Double-dispatch:** `UpdateChargeBars` is called both directly from events (`SPELL_UPDATE_CHARGES`, `UNIT_POWER_UPDATE`) and indirectly from `StartTracking`. This is intentional (StartTracking needs current state on mount-up) but the absence of a per-function guard means any event that fires near mount-up causes redundant work. Same pattern applies to `UpdateSecondWind` and `UpdateStaticChargeAndWhirlingSurge` via `abilityFrameDirty`.

**Implicit per-setting refresh scope:** Every Options.lua control's `set = function` calls `RefreshConfig()` directly, bypassing any possibility of knowing which portion of the UI actually needs updating. There is no mechanism for a control to declare its scope (e.g., "this only affects the speed bar texture").

**Startup deferred-call chain (`C_Timer.After` cascade):** `OnInitialize` defers `CreateAllFrames` + `CheckSkyridingAvailability` by 10 seconds. `OnPlayerLogin` independently defers `UpdateFonts` by 2.5 seconds. If player logs in while mounted, these timers fire at different times, potentially creating a window where frames exist but fonts are not yet applied (2.5s–10s window). There is no ordering relationship enforced between these two deferred paths.

---

## Known Re-entrancy Guards (Do Not Remove)

| Guard | Location | Purpose |
|---|---|---|
| `active` boolean | `zSkyridingBar.lua:181` | Prevents `StartTracking` from being called when already tracking. Checked in `CheckSkyridingAvailability` (line 1424). |
| `abilityFrameDirty` | `zSkyridingBar.lua:224` | Prevents `UpdateStaticChargeAndWhirlingSurge` from running every frame; only runs when an aura/cooldown event has occurred since the last check. |
| `lastSpeedBarColorKey` | `zSkyridingBar.lua:229` | Gates color writes to `SetStatusBarColor` — only fires when the color bucket changes. Prevents per-frame `SetStatusBarColor` calls. |
| `zSkyridingBar.lemCallbacksRegistered` | `zSkyridingBar.lua:773` | Prevents LEM callbacks from being re-registered each time `CreateAllFrames` is called. |
| `self._seeding` | `zSkyridingBar.lua:491` | Guards `RefreshConfig` from running during `SeedBuiltinProfiles` which switches profiles mid-init. |
| `chargesInitialized` | `zSkyridingBar.lua:231` | Prevents the charge-refresh sound from playing on the very first `UpdateChargeBars` call (before a baseline is established). |
| `CompatCheck` guards | Throughout | Prevents newer API calls on interface versions ≤ 110205. |
