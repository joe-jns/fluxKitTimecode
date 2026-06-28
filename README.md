# fluxKitTimecode
## Open sourced Flux Kit TimeCoding Tool
- Made by AccelRanger
- Get the compiled file at our [Discord](https://discord.gg/vCr4FrWDKX)

Version 1.4

---

## Unofficial fork — fixes & improvements

Fork of **fluxKitTimecode** (by AccelRanger, MIT license). The original behavior is
**not** removed: this fork fixes bugs and adds quality-of-life features without taking
anything away.

> Only **2 scripts** are modified: `server/root.luau` and `client/root.luau`.
> To deploy: replace the contents of these 2 scripts in your installed kit
> (the server = the one containing `logEvent`, the client = the one containing `processShowfile`).

### 🐞 Fixes

1. **First delay auto-zeroed** — previously the first showfile event inherited the time
   elapsed since the server booted, so you had to edit the JSON by hand (Notepad) on every
   export. Now `lastEventTime` is reset on *Start Recording*, and the export forces the
   first `Delay` to `0` (`buildExport`). No more manual editing.
2. **Guaranteed playback order** — `processShowfile` used `pairs` (no guaranteed order on
   an array) → replaced with `ipairs`.
3. **Drift-free playback timing** — playback waited each `Delay` relatively (`task.wait`),
   which accumulates timing errors over a long show. Each event is now scheduled against an
   **absolute clock** (start time + sum of delays) → stable sync.
4. **Protected JSON decode** — showfile decoding is wrapped in `pcall` → a clear error
   message instead of a crash if a show is corrupted.

### ✨ Additions

5. **STOP button + stop key** — previously you couldn't stop a running show (and 2 clicks =
   2 overlapping shows). Added an anti-double-play guard, a **"STOP SHOW" button** cloned
   into the menu (matching the existing button style), and the **Backspace** key.
6. **Clean blackout on stop** — on stop, effects left on (haze, breath…) are turned off, and
   the **music** (played server-side) is stopped via `soundRemote` (`"__STOP__"`).
7. **Live indicators** — recording: `● REC — N events — Ts`; playback: `Playing X/N — Ts`
   (new server query `clientData("recordingCount")`).

All changes are commented in the code with the `[FORK]` tag.
Original project credit: **AccelRanger**. License: **MIT** (unchanged).
