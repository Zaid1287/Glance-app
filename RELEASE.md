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
- [ ] Code-sign with a Developer ID Application certificate (needs Xcode /
      `codesign` + an Apple Developer account).
- [ ] Notarize (`notarytool submit … --wait`) and staple.
- [ ] Optionally ship via the Mac App Store (sandbox + entitlements review) or
      Setapp.

## iOS app (future milestone, M4)

- [ ] Build in Xcode (SwiftUI + ActivityKit + WidgetKit).
- [ ] Apple Developer account; APNs key incl. the `liveactivity` push type.
- [ ] Justify background modes for App Store review.
- [ ] QR pairing performs a real key exchange producing the `GlanceCrypto` key.
