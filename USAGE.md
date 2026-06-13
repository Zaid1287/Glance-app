# Using Glance

How to build the Mac agent, get the app on your iPhone, pair them, and watch a
task show up as a Live Activity. This reflects the **current dev state** (free
Apple Developer account, building from source).

---

## 1. Mac agent (works today, no Xcode needed)

Requires the Swift toolchain (Swift 5.9+) and macOS 14+.

```sh
cd ~/Glance
swift build                      # build the agent, menu-bar app, CLI
swift run glance-selftest        # 40/40 checks

# Auto-detect downloads:
.build/debug/glance watch-downloads
# Auto-detect builds/installs/transfers:
.build/debug/glance watch-processes
# Wrap a command with progress parsing:
.build/debug/glance run --progress 'Epoch.*?([0-9]+)%' -- python train.py

# Menu-bar app (live status item, no Dock icon):
swift run glance-bar
```

`--json` on any watcher prints the raw synced wire format.

## 2. Start the sync agent (this is what the phone talks to)

```sh
.build/debug/glance sync-serve
```

- On first run it mints a 256-bit pairing key at `~/.glance/key` (mode `0600`)
  and prints its **fingerprint**.
- It advertises over **MultipeerConnectivity** (what the app browses for) and
  TCP. macOS will ask to **allow Local Network access — allow it**, or the phone
  can't connect.
- It auto-detects downloads + builds/installs and pushes them, encrypted, to any
  paired device on the same Wi-Fi.

## 3. Get the app on your iPhone

The iPhone app is an Xcode project generated from `app/project.yml`.

```sh
cd ~/Glance/app
./bootstrap.sh            # installs xcodegen + platforms, generates Glance.xcodeproj, opens it
```

In Xcode:

1. **GlanceApp** target → **Signing & Capabilities** → set your **Team**
   (a free Apple ID works).
2. Scheme = **GlanceApp** (not `glance`/`glance-bar` — those are the Mac CLI),
   destination = **your iPhone**.
3. **⌘R**.
4. First launch the phone shows "Untrusted Developer" →
   **Settings → General → VPN & Device Management** → trust your Apple ID →
   reopen the app.

### Free-account caveats (until you have a paid Apple Developer account)

- **Bundle IDs must be unique to you.** The project uses `com.zaid.glance*` —
  change the prefix in `app/project.yml` (and re-run `xcodegen generate`) if you
  fork it.
- **No App Groups** → the Home-screen *widget*'s live data is off (the Live
  Activity still works). App Groups need a paid account.
- **Apple Watch is excluded from the build** — a free team can't sign a watchOS
  app without a registered Apple Watch. Re-add it by restoring the
  `GlanceWatch` embed in `app/project.yml` once you have a paid account or a
  paired watch registered to your team.
- **7-day expiry** — free-signed builds stop after 7 days; just Run again to
  renew. A paid account removes this.

## 4. Pair

1. On the Mac, with `glance sync-serve` running, copy the key:
   ```sh
   cat ~/.glance/key
   ```
2. In the app, paste it into **Pairing key** → tap **Pair**. The app's
   fingerprint must match the one `sync-serve` printed.
3. Same Wi-Fi → the pairing screen flips to the task list ("No active tasks").

## 5. Test it

Start any real download in Safari/Chrome (or any recognized build/transfer).
`sync-serve` detects it → the app shows it climbing → **lock the phone** to see
the **Live Activity** on the Lock Screen / Dynamic Island, updating live, then
completing.

To drive a controlled test without a real download:

```sh
# grow a fake in-progress download; sync-serve will detect + push it
f=~/Downloads/Test.dmg.crdownload
for mb in 10 40 90 160 230; do dd if=/dev/zero of="$f" bs=1m count=$mb 2>/dev/null; sleep 3; done
mv "$f" ~/Downloads/Test.dmg && sleep 2 && rm -f ~/Downloads/Test.dmg
```

## Command cheat-sheet

```
glance watch-downloads [--dir PATH] [--json]
glance watch-processes [--json]
glance run [--name N] [--progress REGEX] -- CMD…
glance attach --pid PID
glance watch --file PATH [--size BYTES]
glance sync-serve  [--port N] [--key PATH] [--lan]
glance sync-listen [--host H] [--port N] [--key PATH] [--json]   # CLI peer (debugging)
glance-bar [--install-agent | --uninstall-agent]
```

## Troubleshooting

- **`xcodebuild requires Xcode … CommandLineTools`** — prefix Xcode commands with
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, or run
  `sudo xcode-select -s /Applications/Xcode.app`.
- **"watchOS … must be installed"** — only matters if you re-enable the watch:
  `xcodebuild -downloadPlatform watchOS`.
- **App shows nothing after pairing** — confirm both devices are on the same
  Wi-Fi, the key fingerprints match, and you allowed Local Network access for
  `sync-serve`.
- **Phone install fails on signing** — make sure the scheme is **GlanceApp** and
  the destination is your device; let Xcode auto-provision (it registers the
  device on first Run-to-device).
- **`swift build` builds the wrong thing** — run it from `~/Glance` (or
  `make -C ~/Glance`).
