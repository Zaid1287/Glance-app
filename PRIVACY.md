# Privacy

Glance is built so that the least possible data leaves your Mac, and what does
leave is readable only by your own paired device.

## What Glance reads (locally, on your Mac)

- In-progress download files in `~/Downloads` (names and sizes).
- The running process list, to recognize long tasks (e.g. `npm install`).
- For `glance run`, the standard output of the command **you** wrap — scanned
  line-by-line for a progress number, then discarded.

## What leaves your Mac

Only **task metadata**, and only to your paired device:

- task name (e.g. `Xcode.dmg`, `npm install`), kind, and state
- progress: bytes done, throughput, ETA
- timestamps and exit codes

## What never leaves your Mac

- File **contents**.
- Command **output** (it is parsed in memory for a progress number, never stored
  or transmitted).
- Keystrokes, screen contents, browsing history, or any data outside the tasks
  you track.

## How it is protected

Everything transmitted is end-to-end encrypted with a key established at pairing
(see [SECURITY.md](SECURITY.md)). The transport binds to localhost by default.
When a sync relay is introduced, it will carry only opaque ciphertext and store
only routing metadata — never your task data.

## Telemetry

The agent core ships with **no analytics or telemetry**. Any future opt-in
diagnostics will be exactly that — opt-in, and documented here.
