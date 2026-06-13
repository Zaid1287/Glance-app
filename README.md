# Glance

**Glance answers one question: "is it done yet?"**

Leave your Mac running something long — a big download, a video export, an
`npm install`, an ML training run — walk away, and check its status on your
iPhone in two seconds: a **Live Activity** on the Lock Screen, the **Dynamic
Island**, a **Home Screen widget**, or your **Apple Watch**. No walking back to
the machine, no screen sharing.

> **Status: working end-to-end on real hardware.** Mac agent → encrypted LAN →
> iPhone Live Activity, verified on a physical iPhone. See [Status](#status).

It is **not** remote desktop. It doesn't mirror your screen. It tracks the one
high-frequency moment — progress, and done/failed — and nothing else.

## The wedge: zero-config auto-detection

You don't write a script or wire a webhook. The Mac agent notices the task on
its own:

- **Downloads** — in-progress browser downloads in `~/Downloads`
  (Safari/Chrome/Firefox), with live bytes + throughput.
- **Builds / installs / transfers** — `npm`, `pip`, `cargo`, `xcodebuild`,
  `docker`, `brew`, `make`, `rsync`, `scp`, `wget` (running → done).
- **Anything else** — a CLI wrapper (`glance run -- <cmd>`) as the always-works
  escape hatch, plus PID-attach and file-growth watchers.

A backend-agnostic tool (send-a-webhook services) can't do this — auto-detection
is the moat.

## How it works

```
detectors → TaskStore → encrypt (ChaCha20-Poly1305) → MultipeerConnectivity (LAN)
                                                              │
                              iPhone app ◀── decrypt ◀────────┘
                                   │
                                   └─ ActivityKit → Live Activity on iPhone
                                       (which also mirrors to the Mac menu bar
                                        via Continuity on macOS 26)
```

iOS only lets an installed app author Live Activities, so the iPhone app turns
the synced data into the Live Activity. The Mac sends **metadata only** — never
file contents or command output.

## The pieces

| Component | Where | What |
|-----------|-------|------|
| `glance` | Mac CLI | The agent: detects tasks, wraps commands, publishes encrypted updates. |
| `glance-bar` | Mac menu bar | Live status item (the local view), runs via SwiftPM. |
| `GlanceCore` | shared Swift package | Task model, sync, crypto — used by Mac **and** iPhone. |
| Glance app | iPhone | Pairing, task list, drives Live Activities + widgets. |
| Glance watch | Apple Watch | Glance of the active task. |

## Security & privacy

- **End-to-end encrypted.** Every wire frame is sealed with ChaCha20-Poly1305
  under a 256-bit pairing key. A device without the key gets nothing.
- **Loopback by default.** The agent binds to `127.0.0.1`; LAN exposure is an
  explicit opt-in, still encrypted.
- **Metadata only.** No file contents, no command output, no telemetry.

See [SECURITY.md](SECURITY.md) and [PRIVACY.md](PRIVACY.md).

## Status

| Milestone | State |
|-----------|-------|
| Mac agent core (model, detectors, CLI) | ✅ built + tested (40/40) |
| Encrypted sync (wire, coalescer, MPC + TCP transports) | ✅ verified |
| Menu-bar app | ✅ runs |
| iPhone app + widgets + Live Activity | ✅ **running on a real iPhone** |
| Apple Watch app | ✅ code complete; deferred in the build (needs a registered Apple Watch / paid account to sign) |
| Home-widget live data | ⬜ needs an App Group (paid account) |
| Away-from-Mac (app closed/off-network) | ⬜ needs an APNs push relay (paid account + server) |
| Distribution (notarize Mac, App Store iPhone) | ⬜ packaging step |

Most of the open items are gated on a paid Apple Developer account; the core
"is it done yet?" experience is done and proven.

## Get started

See **[USAGE.md](USAGE.md)** — build the Mac agent, run it, get the app on your
iPhone, pair, and test.

## License

[MIT](LICENSE).
