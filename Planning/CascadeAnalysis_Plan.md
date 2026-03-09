# Cascade & Refresh Architecture Analysis

**Scope:** analysis is limited to files inspected in this workspace. Primary implementation is in `zSkyridingBar.lua` with supporting lifecycle/callbacks in bundled libs (ACE, LibEditMode). All claims below reference specific functions/files.

## Terminology
- Refresh — any code path that updates UI state (show/hide, SetValue, SetPoint, SetSize, SetStatusBarTexture). See terminal actions in `StartTracking`, `StopTracking`, `Update*` functions in [zSkyridingBar.lua](zSkyridingBar.lua#L1431-L1489) and [zSkyridingBar.lua](zSkyridingBar.lua#L1737).
- Dirty — local boolean flags used to indicate an update is required without performing it immediately. Example: `abilityFrameDirty` in `zSkyridingBar.lua` (set by `UNIT_AURA` / `SPELL_UPDATE_COOLDOWN`) and read by the `speedBar` OnUpdate handler; see [zSkyridingBar.lua](zSkyridingBar.lua#L1200-L1220) and [zSkyridingBar.lua](zSkyridingBar.lua#L1338-L1348).
- Entry point — an external trigger: a registered game event, a timer callback, or an OnUpdate tick. See events registered on `eventFrame` (ADDON_LOADED, PLAYER_ENTERING_WORLD, PLAYER_LOGIN, UNIT_SPELLCAST_SUCCEEDED, UNIT_AURA, UNIT_POWER_UPDATE, PLAYER_CAN_GLIDE_CHANGED, SPELL_UPDATE_COOLDOWN, ZONE_CHANGED_NEW_AREA, SPELL_UPDATE_CHARGES, UPDATE_UI_WIDGET) in [zSkyridingBar.lua](zSkyridingBar.lua#L428-L439).

## Call-Graph Summary (ASCII diagrams)
Note: diagrams show principal chains anchored at obvious entry points. File references follow each diagram.

1) Event dispatch (central OnEvent)

  PLAYER_CAN_GLIDE_CHANGED
          |
          v
  zSkyridingBar:CheckSkyridingAvailability()
     /                \
    v                  v
 StartTracking()     StopTracking()
    |                  |
    v                  v
 UpdateChargeBars()  HideWithFade(...)  -- terminal actions
 UpdateStaticChargeAndWhirlingSurge()
 UpdateSecondWind()

See registration and handler: [zSkyridingBar.lua](zSkyridingBar.lua#L428-L444) and `CheckSkyridingAvailability`: [zSkyridingBar.lua](zSkyridingBar.lua#L1404-L1428). Start/Stop functions: [zSkyridingBar.lua](zSkyridingBar.lua#L1431-L1489) and [zSkyridingBar.lua](zSkyridingBar.lua#L1475-L1528).

2) Per-frame update (speedBar OnUpdate)

  speedBar:SetScript(OnUpdate) -> speedBarOnUpdate()
          |
          v
  - GetGlidingInfo() (poll)
  - Smooth speed, update speedBar value
  - If abilityFrameDirty -> UpdateStaticChargeAndWhirlingSurge()
  - Update visuals (texts/colors)

See `speedBarOnUpdate` and its usages: [zSkyridingBar.lua](zSkyridingBar.lua#L1324-L1368) and `StartTracking` (where OnUpdate is attached): [zSkyridingBar.lua](zSkyridingBar.lua#L1431-L1443).

3) Charge update events

  SPELL_UPDATE_CHARGES  or  UNIT_POWER_UPDATE(ALTERNATE)
          |
          v
  zSkyridingBar:UpdateChargeBars()
    -> C_Spell.GetSpellCharges(...) -> update bar values, set timers

See registration: [zSkyridingBar.lua](zSkyridingBar.lua#L428-L439) and implementation: [zSkyridingBar.lua](zSkyridingBar.lua#L1556-L1628).

4) Widget/compat path (compat mode)

  UPDATE_UI_WIDGET -> zSkyridingBar:UpdateVigorFromWidget(widgetInfo)
    -> reads C_UIWidgetManager visualization info and updates charge bars directly

See: registration (compat) [zSkyridingBar.lua](zSkyridingBar.lua#L438-L439) and function: [zSkyridingBar.lua](zSkyridingBar.lua#L1560-L1606).

## Cascade Path Inventory (selected major chains)
Each row: Entry point → Full chain → Worst-case operation count

- `PLAYER_CAN_GLIDE_CHANGED` → `CheckSkyridingAvailability()` → `StartTracking()` / `StopTracking()` → `UpdateChargeBars()` + `UpdateStaticChargeAndWhirlingSurge()` + `UpdateSecondWind()` → (show/hide frames)  
  Worst-case: 3 major update functions + up to 4 Show/Hide operations.  
  Evidence: [zSkyridingBar.lua](zSkyridingBar.lua#L428-L444), [zSkyridingBar.lua](zSkyridingBar.lua#L1404-L1489).

- `SPELL_UPDATE_CHARGES` / `UNIT_POWER_UPDATE(ALTERNATE)` → `UpdateChargeBars()` → status bar SetValue/SetMinMaxValues for up to 6 bars  
  Worst-case: 6 bar updates + potential timer set via `setBarRechargeTimer`.  
  Evidence: [zSkyridingBar.lua](zSkyridingBar.lua#L1556-L1628).

- `UNIT_AURA` → sets `abilityFrameDirty` and `thrillActive` → polled by `speedBarOnUpdate` → `UpdateStaticChargeAndWhirlingSurge()`  
  Worst-case: repeated polling on OnUpdate until cooldown resolves.  
  Evidence: [zSkyridingBar.lua](zSkyridingBar.lua#L1208-L1216), [zSkyridingBar.lua](zSkyridingBar.lua#L1338-L1350), [zSkyridingBar.lua](zSkyridingBar.lua#L1610-L1694).

## Problem Areas by Priority
Note: identified patterns and code locations. Each item references code we've read.

P1 - Over-scheduling of shared update (`abilityFrameDirty` + OnUpdate polling)
- Location: `UNIT_AURA` handler sets `abilityFrameDirty` ([zSkyridingBar.lua](zSkyridingBar.lua#L1210-L1216)) while `speedBarOnUpdate` polls every frame and calls `UpdateStaticChargeAndWhirlingSurge()` when dirty ([zSkyridingBar.lua](zSkyridingBar.lua#L1324-L1348), [zSkyridingBar.lua](zSkyridingBar.lua#L1610-L1694)).
- What happens: frequent OnUpdate polling can trigger expensive UI recompute/anim logic many times during short windows (GCD, cooldown registration), especially when many aura events fire.
- Severity: performance in high frame-rate situations; correctness risk if ordering assumptions present.

P2 - Listener fan-out is possible if additional per-instance frames register events
- Location: `LEM:RegisterCallback('enter'/'exit'/'layout', ...)` is registered once in `CreateAllFrames()` (guarded by `lemCallbacksRegistered`) which is correct; however third-party libs may register callbacks (see `LibEditMode` usage) — inspect call sites before changing.  
  Evidence: `LEM:RegisterCallback` calls in [zSkyridingBar.lua](zSkyridingBar.lua#L772-L801) and the guard `zSkyridingBar.lemCallbacksRegistered` in [zSkyridingBar.lua](zSkyridingBar.lua#L792-L798).
- What happens: if unguarded, repeated calls to register the same callback could cause duplicate work per event. In this code the guard prevents repeated registration.

P2 - Deferred-call stacking via `C_Timer.After` usage
- Location: `C_Timer.After` is used for short delays (1s, 2.5s, 10s) in initialization and UI effects ([zSkyridingBar.lua](zSkyridingBar.lua#L414-L419), [zSkyridingBar.lua](zSkyridingBar.lua#L478-L485), [zSkyridingBar.lua](zSkyridingBar.lua#L614-L620)).
- What happens: multiple deferred callbacks interacting with startup lifecycle can cause redundant re-initialization if not coalesced; evidence in the sequence in `OnInitialize` where frames are created after a 10s delay and `OnPlayerLogin` also schedules font updates after 2.5s.

P3 - Overly broad refresh scope
- Location: `RefreshConfig()` calls `UpdateAllFrameAppearance()` which updates all sub-frames even if only one setting changed (e.g., font face vs texture); see [zSkyridingBar.lua](zSkyridingBar.lua#L1176-L1189) and [zSkyridingBar.lua](zSkyridingBar.lua#L1200-L1210).
- What happens: a single settings change may run multiple per-frame layout and appearance updates.

## Cross-Cutting Patterns
- Double-dispatch: update functions are invoked both directly from event handlers and indirectly via `StartTracking`/`OnUpdate` (e.g., `UpdateChargeBars` called from `SPELL_UPDATE_CHARGES` and from `StartTracking`) — see [zSkyridingBar.lua](zSkyridingBar.lua#L1431-L1440) and [zSkyridingBar.lua](zSkyridingBar.lua#L428-L439).
- Implicit cache invalidation: flags like `abilityFrameDirty`, `chargesInitialized` are used broadly; their semantics are embedded in multiple functions rather than via a single cache manager.

## Known Re-entrancy Guards
- `abilityFrameDirty` boolean prevents repeated immediate updates and is explicitly set/cleared in `OnUnitAura`, `SPELL_UPDATE_COOLDOWN`, `speedBarOnUpdate`, and `UpdateStaticChargeAndWhirlingSurge()` ([zSkyridingBar.lua](zSkyridingBar.lua#L1208-L1216), [zSkyridingBar.lua](zSkyridingBar.lua#L430-L438), [zSkyridingBar.lua](zSkyridingBar.lua#L1324-L1348), [zSkyridingBar.lua](zSkyridingBar.lua#L1612-L1620)).
- `zSkyridingBar.lemCallbacksRegistered` guards against registering LEM callbacks multiple times: [zSkyridingBar.lua](zSkyridingBar.lua#L772-L792).

---

End of Cascade & Refresh Architecture Analysis.
