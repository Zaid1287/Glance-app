# Privacy Policy

**Effective date:** 16 June 2026
**Applies to:** the Glance macOS menu-bar agent, the Glance iPhone app, and the
Glance website (https://zaid1287.github.io/Glance).

> Plain-language summary: **Glance collects nothing about you.** There is no
> account, no analytics, and no server that we operate. Everything Glance touches
> stays on your own devices, and the small amount of data that moves between your
> Mac and your phone is end-to-end encrypted and travels directly over your local
> network.

## 1. Who we are

Glance is a free, open-source project (the "Software"), maintained by the Glance
author ("we", "us"). Source: https://github.com/Zaid1287/Glance.

## 2. Information we collect

**None.** We do not operate servers, accounts, or analytics. We do not collect,
receive, store, sell, or share any personal information or usage data. We have no
ability to see your tasks, files, device identifiers, location, or activity.

## 3. Information processed locally on your devices

Glance reads the following **only on your own Mac**, to do its job, and never
transmits it to us:

- In-progress download files in `~/Downloads` (file **names** and **sizes**).
- The running process list, to recognize long tasks (e.g. `npm install`).
- For `glance run`, the standard output of the command **you** wrap — scanned
  line-by-line in memory for a progress number, then discarded.

When you pair a phone, only **task metadata** is sent **directly to your own
paired device** over your local network (Apple MultipeerConnectivity):

- task name (e.g. `Xcode.dmg`, `npm install`), kind, and state;
- progress (bytes done, throughput, ETA);
- timestamps and exit codes.

**Never transmitted:** file contents, full command output, keystrokes, screen
contents, browsing history, or anything outside the tasks you track.

## 4. How that data is protected

Everything sent between your devices is end-to-end encrypted with
ChaCha20-Poly1305 under a 256-bit key established at pairing. The Mac transport
binds to localhost by default; LAN exposure is an explicit opt-in. Details:
[SECURITY.md](SECURITY.md).

## 5. Data stored on your devices

- **Mac:** a pairing key at `~/.glance/key` (user-only, `0600`).
- **iPhone:** the same pairing key, in the app's private container with file
  protection. Live Activities and local notifications are rendered on-device by
  iOS; Glance does not send push notifications through any server.

You can delete this data at any time: **Unpair** in the iPhone app removes its
key; deleting `~/.glance/key` removes the Mac's. Task data is ephemeral and is
not written to any database by us.

## 6. Third parties

We use **no** third-party analytics, advertising, or tracking SDKs. Glance relies
only on Apple's on-device operating-system features (local networking, Live
Activities, local notifications), governed by
[Apple's Privacy Policy](https://www.apple.com/legal/privacy/). We do not share
data with anyone, because we do not have your data.

## 7. Children

Glance is a general-audience developer utility, not directed to children under 13
(or 16 in the EEA). We do not knowingly collect information from children — in
fact, we collect nothing from anyone.

## 8. Your rights

Because we hold no personal data, there is nothing for us to access, correct,
export, or delete on our side. Any data Glance produces lives solely on your
devices and is fully under your control (see §5). For how this maps to GDPR/CCPA,
see [DATA-COMPLIANCE.md](DATA-COMPLIANCE.md).

## 9. Changes to this policy

If Glance ever adds a feature that changes this (for example an optional
away-from-home sync relay), we will update this policy and the change history in
the repository **before** that feature ships, and keep any such data flow
opt-in.

## 10. Contact

Questions: **[contact email]** · or open an issue at
https://github.com/Zaid1287/Glance/issues.

---

*This document is provided for transparency and is not legal advice. If you
publish Glance commercially or in a regulated context, have it reviewed by a
qualified professional for your jurisdiction.*
