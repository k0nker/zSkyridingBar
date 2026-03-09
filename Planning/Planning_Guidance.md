You are auditing the refresh and update cascade architecture of this codebase.
Your goal is to produce two .md planning documents in the Planning folder.

## Step 1 — Investigation (do this before writing anything)

Read every file in the project. For each file, identify and record:

1. **Entry points** — what triggers a refresh/update/redraw? (events, user
   actions, timers, settings changes, lifecycle hooks)
2. **Propagation functions** — functions that call other refresh functions as
   part of their body (directly or via a deferred timer/callback)
3. **Terminal actions** — functions that produce visible output (draw, resize,
   reposition, show/hide a UI element, update text)
4. **Deferred calls** — any next-frame defer, setTimeout(0), C_Timer.After(0),
   Promise.resolve().then(), requestAnimationFrame, or equivalent. Note every
   call site.
5. **Event/signal listeners** — every place a listener is registered for a
   shared event/signal/notification bus. Note whether it is registered once
   globally or repeatedly (e.g., inside a constructor or per-instance setup
   function).
6. **Settings/state change handlers** — every callback or observer that fires
   when a user-configurable value changes.

Search the entire codebase for every call site of every function you identify.
Follow call chains in both directions: who calls this function, and what does
this function call?

Do not begin writing the documents until you have read all files and traced
all chains.

---

## Step 2 — Document 1: Cascade & Refresh Architecture Analysis

Save as: `Planning/CascadeAnalysis_Plan.md`

Sections to include:

### Terminology
Define the project-specific terms you discovered: what a "refresh" means here,
what "dirty" means, what the equivalent of SETTING_CHANGED is, etc.

### Call-Graph Summary
Show the full call graph as ASCII diagrams. One diagram for each major entry
point. Show who calls what, with file references.

### Cascade Path Inventory
A table. Each row is one entry-point → terminal-action chain. Columns:
- Entry point
- Full chain (condensed)
- Worst-case operation count (e.g. "5 layout rebuilds + 3 timer passes")

### Problem Areas by Priority (P1 / P2 / P3)
For each problem:
- **Name** — short label
- **Location** — file and function name(s)
- **What happens** — factual description of the unintended behaviour
- **Evidence from code** — quote or reference the specific lines
- **Severity** — concrete impact (performance, correctness, or both)
- **Risk if left unfixed** — how does it scale with growth?

Mandatory problem categories to look for (these appear in almost every
event-driven UI codebase):

- **Listener fan-out** — a listener registered inside a constructor/factory
  that is called once per instance, so N instances = N simultaneous firings
  for one event
- **Over-scheduling of a shared update function** — a function called from
  many paths, including redundant paths, with no guard or coalescing
- **Deferred-call stacking** — multiple independent next-frame defers
  queued by the same logical operation, racing or duplicating each other
- **Overly broad refresh scope** — a refresh that rebuilds more than what
  changed (e.g., refreshing all 5 panels when only 1 changed)
- **Implicit phase ordering violated by deferrals** — phases that have a
  strict data dependency (A must finish before B reads its output) but are
  separated by async gaps, causing B to read stale data
- **Sequential atomic writes that each fire an event** — two or three
  settings written back-to-back, each firing a change event, when logically
  it is one user action
- **Lifecycle over-refresh** — startup/init sequences that trigger more
  full rebuilds than necessary
- **Unbounded event firing during continuous input** — scroll, drag, resize,
  or typing handlers that fire a full rebuild on every raw input event

### Cross-Cutting Patterns
Patterns that appear in multiple places and make the above problems worse:
double-dispatch (a function called both directly and via its event), implicit
cache invalidation, fragile ordering by convention.

### Known Re-entrancy Guards
List every guard that prevents infinite loops (flags, visited sets, skip-ID
params). These must not be removed during refactoring.

---

## Step 3 — Document 2: Proposed Refactor Functions

Save as: `Planning/RefactorFunctions_Plan.md`

Open this document by identifying the **immutable phase order** — the correct
sequence in which operations must run based on their data dependencies. This
is the architectural insight that drives all the function proposals. Draw it
as a numbered list or table with phase name, responsible function, and "reads
from / writes to" columns.

Then, for each proposed new or replacement function, include:

### [N]. `functionName(signature)` — Short Title

- **Status:** New / Replacement / Rename
- **Replaces:** List of existing functions/patterns this eliminates (mark each
  for deletion or keep)
- **Signature:** Full typed signature with parameter table if options-based
- **Parameters table:** Field, type, default, meaning — for every parameter
- **Behaviour:** Step-by-step numbered description of what the function does
  internally. Use pseudocode where helpful. Do not omit ordering.
- **Key guarantees:** What invariants this function upholds that the old code
  did not (e.g., "phases always run in order", "fires exactly once per frame")
- **What this eliminates:** Which specific problem(s) from Document 1 this
  solves, named by their P1/P2/P3 label
- **Migration — call site replacements:** A table mapping every old call
  pattern to its new equivalent
- **Files:** Which files need to change

After all individual proposals, include:

### Interaction Map
An ASCII diagram showing how all the proposed functions compose together for
the two most common flows: (a) a data-driven event refresh, and (b) a
settings-change refresh.

### Phased Implementation Order
A table with columns: Step, Function, Prerequisite, Risk level, and a short
note on how to verify it works (what to test or observe in-game/in-app).

### What the Old Functions Become
A table: Old function → Fate (Delete / Keep / Internalize). Every function
named in Document 1 must appear here.

---

## Constraints

- Do not create any files other than the two planning documents.
- Do not make any code changes.
- Do not suggest changes outside the scope of what the investigation found.
- Every claim in both documents must be traceable to a specific file and
  function you read. No speculation.
- If a re-entrancy guard or debounce already exists and works correctly, say
  so and do not propose replacing it.