# Data & Compliance

**Effective date:** 16 June 2026

This document explains, for reviewers and regulated users, exactly what data
Glance handles and how that maps to common privacy regimes. The short version:
**Glance has no server and collects no personal data**, so most obligations that
apply to data-collecting apps do not arise. See also [PRIVACY.md](PRIVACY.md) and
[SECURITY.md](SECURITY.md).

## 1. Data inventory

| Data | Where it lives | Who can read it | Leaves the device? |
|------|----------------|-----------------|--------------------|
| Task metadata (name, kind, state, progress, timestamps, exit codes) | In memory on your Mac; mirrored to your paired iPhone | You, on your own devices | Only Mac→your phone, E2E-encrypted, over your LAN |
| Download file names/sizes, process names | Read transiently on your Mac | You | No |
| Wrapped command output (`glance run`) | Parsed in memory, then discarded | You | No |
| 256-bit pairing key | `~/.glance/key` (Mac, `0600`); app container w/ file protection (iPhone) | You | No |

We — the maintainers — receive **none** of the above. There is no backend,
database, log pipeline, or analytics endpoint operated by us.

## 2. Roles and responsibilities

Because no data is sent to us, we are **not a data controller or processor** of
your personal data. You are the sole controller of any data Glance produces, all
of which stays on hardware you control.

## 3. GDPR (EU/EEA/UK)

- **Lawful basis / processing by us:** none required — we perform no processing of
  personal data.
- **Data subject rights** (access, rectification, erasure, portability,
  objection): exercisable directly by you, on your devices — unpair to erase the
  key; task data is ephemeral and never centrally stored (see PRIVACY.md §5).
- **International transfers:** none — data never crosses a network we operate.
- **DPO / representative:** not required, as no large-scale or systematic
  processing of personal data is performed by us.

## 4. CCPA / CPRA (California)

We do **not** collect, sell, or "share" personal information as defined by the
CCPA/CPRA. There are no categories of personal information collected, no sale, and
therefore no "Do Not Sell or Share" obligation. Nothing to opt out of.

## 5. Apple App Store privacy

Glance's App Privacy ("nutrition label") declaration is **Data Not Collected**.
The app uses on-device OS features only: Local Network (to reach your Mac), Live
Activities, and local notifications. Relevant Info.plist declarations:

- `NSLocalNetworkUsageDescription` + Bonjour service entries (LAN discovery).
- `NSSupportsLiveActivities = true`.
- `ITSAppUsesNonExemptEncryption = false` — Glance uses only standard
  ChaCha20-Poly1305 for its own sync, which qualifies for the export-compliance
  exemption. *(Confirm this classification for your distribution.)*

## 6. Children's privacy (COPPA / age)

Glance is a general-purpose developer utility, not directed to children, and
collects no data from anyone, including children.

## 7. Data retention

- Task data: ephemeral; not persisted to disk by us.
- Pairing key: retained on each device until you unpair / delete it.
- No backups, no server-side retention, because there is no server.

## 8. Security & breach posture

End-to-end encryption (ChaCha20-Poly1305), loopback-by-default transport, DoS-
hardened framing, and a user-only key file (see SECURITY.md). Because there is no
central store, there is no central breach surface. Vulnerability reports:
[SECURITY.md](SECURITY.md).

## 9. Changes that would affect this

The only roadmap item that could change the above is an **optional**
away-from-home sync relay (APNs). It is **not implemented**. If it ships, it will
be opt-in, documented here first, and designed to route only ciphertext/routing
metadata — never plaintext task data.

## 10. Contact

**[contact email]** · https://github.com/Zaid1287/Glance/issues

---

*Informational, not legal advice. Validate against your specific obligations and
jurisdiction before publishing.*
