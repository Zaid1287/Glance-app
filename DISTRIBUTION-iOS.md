# Getting Glance on your iPhone

The Mac side installs with one command (see the [README](README.md)). The iPhone
app is the part Apple gatekeeps — how you install it depends on whether you have
a paid Apple Developer account.

## Free (no paid account)

There's no free way to put an iOS app on the App Store or TestFlight, but you can
still run Glance on your own iPhone:

### A. Build from source (simplest if you have a Mac + Xcode)
1. `git clone https://github.com/Zaid1287/Glance && cd Glance/app`
2. `./bootstrap.sh` (installs XcodeGen + platforms, generates the project, opens it)
3. In Xcode: select the **GlanceApp** scheme + your iPhone, set your **Team**
   (a free Apple ID works) under Signing, and press **Run**.
4. On the phone: **Settings → General → VPN & Device Management** → trust your
   Apple ID. Full steps are in [USAGE.md](USAGE.md).

Free-signed builds expire after **7 days** — just re-Run to renew.

### B. AltStore / SideStore (for non-developers)
[AltStore](https://altstore.io) sideloads the app with a free Apple ID and
re-signs it automatically over Wi-Fi (no weekly cable dance):
1. Install AltServer on a Mac/PC and AltStore on the iPhone (altstore.io).
2. Build a `.ipa` (Xcode → Product → Archive → Distribute → *Ad Hoc/Development*)
   or use a provided `.ipa` if one is published.
3. Open the `.ipa` in AltStore on the phone.

## Paid ($99/yr Apple Developer Program) — real distribution

### TestFlight (fastest way to share — recommended)

The signing team is read from the environment, so a builder with a paid account
signs without editing tracked files. From `app/`:

1. **Generate with the paid team:**
   ```sh
   DEVELOPMENT_TEAM=YOURTEAMID ./bootstrap.sh
   ```
   (`bootstrap.sh` defaults to the original free team when `DEVELOPMENT_TEAM` is
   unset, so local dev builds are unaffected.)
2. **Bundle IDs** are `com.zaid.glance` and `com.zaid.glance.widget`. They must be
   unique on App Store Connect — if they're taken, change the prefix in
   `app/project.yml` (`PRODUCT_BUNDLE_IDENTIFIER` for both targets) and the widget's
   `NSExtension` host.
3. In Xcode: **Product → Archive** → **Distribute App → TestFlight (App Store
   Connect)** → upload.
4. App Store Connect → your app → **TestFlight** → add the build → enable a
   **public link**. Share the link; anyone installs via the TestFlight app.

Notes baked in so uploads don't snag:
- **Export compliance** is pre-declared (`ITSAppUsesNonExemptEncryption: false` in
  `project.yml` — Glance only uses standard ChaCha20-Poly1305 for its own sync), so
  TestFlight won't prompt on every build. Confirm this matches your legal read.
- Usage strings (`NSLocalNetworkUsageDescription`, Bonjour services) are already set.

Up to 10,000 external testers, ~1-day first beta review.

### App Store

Full review + a product page. Build requirements are in [RELEASE.md](RELEASE.md)
(APNs key with the `liveactivity` push type, background-mode justification, etc.).

Going paid also unlocks: the dedicated **Apple Watch** app/complication, the
**Home-screen widget** (App Groups), and **away-from-Mac** updates via APNs push
(so the Live Activity updates while your phone is locked / off your network).
