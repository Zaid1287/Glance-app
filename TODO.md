# Glance — TODO

Planned changes. Ordered by leverage; ✅ quick wins first, ⏳ bigger/gated last.

## Status — implemented 2026-06-13

- ✅ **2 progress wheel**, **4 haptic + completion notification**, **5 persistent
  "Done" state** — in the iOS app/widget (`AppModel.swift`, `Feedback.swift`,
  `GlanceLiveActivity.swift`); iOS build green.
- ✅ **1 menu-bar agent** — `glance-bar` now runs the detectors + MPC advertiser +
  TCP and has a **"Copy pairing key"** menu item (no Terminal); macOS build green.
- ✅ **3 Apple Watch via Smart Stack** — Live Activity layout made watch-friendly
  (`StatusRing` + compact Lock Screen view). Verify on the wrist. The *dedicated*
  watch app is still gated on a paid account / registered watch.

**To see it:** re-Run the app to the iPhone (project regenerated), and launch
`glance-bar` on the Mac instead of `glance sync-serve`.

---

## 1. Mac side = menu-bar only (like Ollama) ⏳

**Goal:** no Terminal. The menu-bar app *is* the agent — runs detectors, advertises
over MultipeerConnectivity, holds the pairing key, auto-starts at login.

**Approach**
- Fold `sync-serve` into `glance-bar` (`Sources/glance-bar/main.swift`):
  - On launch: `GlanceCrypto.loadOrCreateKey` → `SecureCodec` → `MultipeerAdvertiser` + `TCPServer`, wire `TaskStore.onUpdate` → `SyncPublisher`s (reuse the exact code now in the `sync-serve` CLI case).
  - Menu items: pairing **fingerprint**, **"Copy pairing key"** (writes `~/.glance/key` to clipboard), **"Show QR"** (later, item 3 of pairing UX), connection state, active/recent tasks (already there), **Start/Stop**, **Quit**.
- Keep the `glance` CLI as the headless/scriptable option, but the menu-bar app is the default product surface.
- Auto-start: reuse `--install-agent` (LaunchAgent) or add a "Start at login" toggle (`SMAppService`).

**Files:** `Sources/glance-bar/main.swift` (+ reuse `GlanceCore`).
**Note:** menu-bar app needs Local Network permission for MPC — add `NSLocalNetworkUsageDescription` + `NSBonjourServices` once it's a real `.app` bundle (Xcode/notarize), see RELEASE.md.

---

## 2. Progress wheel on the Live Activity ✅

**Goal:** a circular progress ring, not just the linear bar.

**Approach**
- In `app/GlanceWidget/GlanceLiveActivity.swift`: add a circular indicator.
  - Determinate (total known): `Gauge(value: fraction) { } .gaugeStyle(.accessoryCircularCapacity)` or `Circle().trim(from: 0, to: fraction).stroke(style: .init(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))` with a `%` label centered.
  - Indeterminate (no total — most browser downloads): `ProgressView().progressViewStyle(.circular)` spinner, or a pulsing ring.
- Place the ring in: Dynamic Island **compactTrailing** + **minimal** (small ring), and the **expanded** + **Lock Screen** views (larger ring with % or bytes inside).
- `GlanceActivityAttributes.ContentState.fraction` already gives 0…1 or nil — drive the ring off it.

**Files:** `app/GlanceWidget/GlanceLiveActivity.swift`, optionally `app/GlanceApp/ContentView.swift` (match in-app).

---

## 3. Works on Apple Watch ⏳ (free path exists)

**Goal:** see the task on the wrist.

**Approach — free, no watch app, no signing:**
- iPhone Live Activities **auto-appear in the Apple Watch Smart Stack** (watchOS 10+/26). So the *existing* Live Activity already shows on the Watch — make sure its compact layout reads well at watch size (short name, ring + %). **Verify on-device**, then document.
- This sidesteps the watchOS signing blocker entirely.

**Approach — dedicated watch app (later, needs paid account or registered watch):**
- Re-add the `GlanceWatch` embed in `app/project.yml` (removed because a free team
  can't sign watchOS without a registered Apple Watch).
- `GlanceWatch` already has the app + `WatchLink` (WatchConnectivity) code.
- Add a complication (accessory widget) reading the latest summary.

**Files:** `app/GlanceWidget/GlanceLiveActivity.swift` (watch-friendly layout), `app/project.yml` (re-enable target later).

---

## 4. Haptic feedback when a task finishes ✅

**Goal:** a buzz when done/failed.

**Approach**
- In `app/GlanceApp/AppModel.syncActivity`, on transition to terminal:
  - Foreground: `UINotificationFeedbackGenerator().notificationOccurred(task.state == .done ? .success : .error)`.
  - Background (app closed): a local `UNUserNotificationCenter` notification on completion (also satisfies F7 "notify on completion") — its delivery vibrates the phone. Request `UNAuthorizationOptions` at first pair.
- Watch haptic (when the dedicated watch app ships): `WKInterfaceDevice.current().play(.success)`.

**Files:** `app/GlanceApp/AppModel.swift` (+ a small `Notifications` helper).
**Note:** track which task ids already fired so a repeated terminal update doesn't double-buzz.

---

## 5. Live Activity stays on screen as "Done" (Uber-Eats style) ✅

**Goal:** on completion, keep the Live Activity visible showing **Done**, don't
dismiss after 5 s.

**Approach**
- In `AppModel.syncActivity`, on terminal: instead of `end(content, dismissalPolicy: .after(now+5))`, **update to a done content** then
  `await activity.end(finalContent, dismissalPolicy: .default)` — `.default` keeps the final state on the Lock Screen (system removes it after up to ~4 h, or the user swipes it away). For a fixed window use `.after(Date().addingTimeInterval(60*60))`.
- In `GlanceLiveActivity.swift`, style the done/failed state: green check + "Done" (or red ✗ + "Failed"), full ring, final size/duration. Make the terminal state visually distinct.

**Files:** `app/GlanceApp/AppModel.swift`, `app/GlanceWidget/GlanceLiveActivity.swift`.

---

## Order of work

| Item | Effort | Gated? |
|------|--------|--------|
| 5. Done-state persists | small | no |
| 2. Progress wheel | small | no |
| 4. Haptic on done | small | no |
| 3. Watch via Smart Stack | small (mostly verify) | no |
| 1. Menu-bar-only Mac agent | medium | needs `.app` bundle + Local Network entitlement for full polish |
| 3b. Dedicated watch app | medium | needs paid account / registered watch |

**Suggested first pass:** 5 → 2 → 4 → 3 (Smart Stack) in the iOS app/widget (one rebuild to your phone covers all four), then 1 (menu-bar agent) on the Mac.
