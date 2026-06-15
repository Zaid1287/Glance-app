# Release checklist

What's release-ready today, and what each distribution path still needs.

## Agent core + sync + menu-bar (this repo) — ready

- [x] No plaintext on the wire (E2E ChaCha20-Poly1305).
- [x] Listener loopback-only by default; LAN is explicit opt-in.
- [x] DoS-hardened framing; key file `0600`.
- [x] No telemetry; metadata-only ([PRIVACY.md](PRIVACY.md)).
- [x] LICENSE, SECURITY.md, PRIVACY.md present.
- [x] 40/40 self-test (`make test`); XCTest parity for CI (`make xctest`).
- [ ] Set the real copyright holder in `LICENSE` and the contact in `SECURITY.md`.
- [ ] Trademark check on the name "Glance".

## Distributing the Mac menu-bar app

Dev runs straight from SwiftPM (`make bar`). For public distribution:

- [ ] Wrap `glance-bar` in an `.app` bundle with an `Info.plist`
      (`LSUIElement = true` for the no-Dock accessory app).
- [x] Code-sign + notarize tooling: [`scripts/sign-notarize.sh`](scripts/sign-notarize.sh)
      signs both binaries (Developer ID + hardened runtime) and submits to the notary
      service. Builder sets `GLANCE_SIGN_ID` + a stored `notarytool` profile once.
- [ ] Run it on the release binaries and publish the notarized zip as the
      `glance-macos-arm64.zip` asset.
- [x] `install.sh` honours `GLANCE_NOTARIZED=1` to skip the quarantine strip once
      the published asset is notarized (default still strips for the unsigned build).
- [ ] Optionally ship via the Mac App Store (sandbox + entitlements review) or
      Setapp.

> A bare CLI binary can't be `stapler staple`d (only `.app`/`.dmg`/`.pkg`); Gatekeeper
> verifies the notarization ticket online on first run, which is fine for the zip.

## iOS app (future milestone, M4)

- [ ] Build in Xcode (SwiftUI + ActivityKit + WidgetKit).
- [ ] Apple Developer account; APNs key incl. the `liveactivity` push type.
- [ ] Justify background modes for App Store review.
- [ ] QR pairing performs a real key exchange producing the `GlanceCrypto` key.
