# Security

## Reporting a vulnerability

Email security reports to **abdulhadi1234knight@gmail.com** (replace with the maintainer's
address before release). Please do not open public issues for security bugs.
We aim to acknowledge within 72 hours.

## Threat model

Glance moves **task metadata** off a Mac toward a paired device. The assets to
protect are (1) the confidentiality of that metadata — file names, command
names, progress — and (2) the integrity of the channel (no spoofed tasks).

Out of scope for the agent itself: a fully compromised Mac (an attacker with
code execution already sees the tasks locally) and physical access to an
unlocked machine.

## Protections in place (agent core + sync layer)

- **End-to-end encryption.** Every wire frame is sealed with ChaCha20-Poly1305
  (AEAD) under a 256-bit pairing key (`SecureCodec`, `GlanceCrypto`). Task
  metadata is never transmitted in clear text (spec N3).
- **Peer authentication.** Only holders of the pairing key can produce a frame
  that decrypts. Anything else — a stranger on the LAN, a scanner, a corrupted
  packet — fails AEAD verification and is dropped. (Verified: a listener with the
  wrong key receives nothing.)
- **Loopback by default.** The TCP transport binds to `127.0.0.1` only; exposing
  it to the LAN is an explicit `--lan` opt-in, and frames stay encrypted either
  way.
- **DoS hardening.** Inbound framing is capped (per-frame and per-connection
  buffer limits); a peer that streams without a delimiter is disconnected rather
  than allowed to exhaust memory.
- **Key at rest.** The pairing key file is written `0600` (user-only).
- **Minimal privilege.** No Full Disk Access; only user-granted folder access.
  Command output and file contents are parsed transiently and never stored or
  transmitted.

## Notes for the production transports

The shipped TCP transport is the local/LAN stand-in. When MultipeerConnectivity
or an APNs relay is added behind the same `OutboundTransport`/`InboundTransport`
seam, the relay must remain **zero-knowledge**: it routes opaque ciphertext and
stores only delivery metadata, never plaintext task payloads.
