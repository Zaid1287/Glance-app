# Glance — iPhone + Apple Watch app

The phone/watch side of Glance: receives encrypted task updates from the Mac
agent over the LAN and shows them as **Live Activities** (Lock Screen + Dynamic
Island), **Home Screen widgets**, and a **Watch** glance + complication.

Shares the model/sync/crypto with the Mac agent via the `GlanceCore` Swift
package at the repo root — no duplicated logic.

## Targets

| Target | What |
|--------|------|
| `GlanceApp` | iPhone app: pairing, task list, drives Live Activities |
| `GlanceWidget` | Live Activity (Lock Screen + Dynamic Island) + Home Screen widget |
| `GlanceWatch` | Apple Watch app showing the active task |

Transport is `MultipeerBrowser` (zero-config LAN, in `GlanceCore`). Frames are
end-to-end encrypted; the app holds the same pairing key as the Mac.

## Build

```sh
./bootstrap.sh          # installs xcodegen + platforms, generates Glance.xcodeproj, opens it
```

Then in Xcode:
1. `GlanceApp` target → **Signing & Capabilities** → set your **Team**
   (a free Apple ID works — the build runs on your iPhone for 7 days before it
   needs re-signing; a paid Apple Developer account removes that and enables
   remote push for the away case).
2. Pick your iPhone as the destination → **Run**.

## Pairing

1. On the Mac: `glance sync-serve` (mints `~/.glance/key`, prints its fingerprint).
2. In the app, paste the contents of `~/.glance/key`. The fingerprints must match.
3. With phone + Mac on the same Wi-Fi, tasks appear automatically — start a
   download or a build to see a Live Activity.

The key is the only secret; it never leaves your devices, and traffic between
them is encrypted with it.

## Things you must set before shipping

- **Bundle IDs / App Group** — placeholders are `app.glance`, `app.glance.widget`,
  `app.glance.watchkitapp`, and App Group `group.app.glance`. Change them in
  `project.yml` (and `SharedStore.appGroup`) to IDs you own, then re-run
  `xcodegen generate`.
- **Team ID** — in `project.yml` `DEVELOPMENT_TEAM`, or via Xcode signing.
- **Key storage** — the app currently stores the pairing key in its container
  with file protection; move it to the Keychain for release (noted in
  `AppModel.swift`).
- **QR pairing** — paste works today; a QR scanner is the intended release UX.

## Away-from-Mac (later)

The near case (same network) needs no server. For updates when away, add a push
relay behind the same `InboundTransport` seam and pass an ActivityKit push token
in `AppModel.syncActivity` — both are isolated changes.
