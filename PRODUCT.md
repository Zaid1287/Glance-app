# Product

## Register

brand

## Users

Mac power users and developers who run long tasks — builds, downloads, model-training runs, renders, large `rsync`/`docker` jobs — and walk away from the machine. They want to know "is it done yet?" from their phone without a remote-desktop session. Technical, Apple-ecosystem, privacy-conscious. The site is their first contact: it must explain the product and earn a one-line `curl | sh` install.

## Product Purpose

Glance is a Mac menu-bar agent that auto-detects long-running tasks and streams encrypted status to the iPhone as a Live Activity (Lock Screen, Dynamic Island, Watch Smart Stack). The landing page exists to make a developer understand the value in five seconds, trust the privacy model, and copy the install command. Success = the visitor runs the install line and builds the iPhone app.

## Brand Personality

Calm, precise, invisible. The voice of a tool that does one job and gets out of the way. Quiet confidence over hype. Apple-adjacent restraint: generous space, exact typography, no shouting. The product's whole pitch is "built to disappear into your workflow" — the site should feel the same way. Lowercase-honest, technically credible, never salesy.

## Anti-references

- **Purple/blue aurora SaaS.** Gradient-mesh backgrounds, aurora blobs, purple→blue hero washes. The saturated AI-landing default. Explicitly rejected.
- Generic glassmorphism for its own sake — blur is used only where it earns the "Mac surface / Live Activity" metaphor, never decoratively everywhere.
- Hero-metric SaaS template (big number / 3-stat row / gradient accent).
- Identical repeated card grids.

## Design Principles

- **Show the product working.** The animated Live Activity mock (fills → finishes → buzzes) carries the pitch better than any adjective. Demonstrate, don't describe.
- **Earn every effect.** Glass, blur, glow, and motion appear only when they reinforce the product metaphor (a real Mac/iOS surface). No decoration without meaning.
- **Privacy is a feature, stated plainly.** ChaCha20-Poly1305, loopback-default, metadata-only — said in calm technical language, not security-theater.
- **Disappear into the workflow.** Restraint over density. The site should feel as quiet and exact as the tool it sells.
- **One clear action.** The `curl | sh` line is the hero CTA; everything routes toward install.

## Accessibility & Inclusion

- Body text ≥4.5:1 contrast against dark-grey base; large/display text ≥3:1.
- Full `prefers-reduced-motion` alternative for the pulse-flow, hero rise, and reveal animations (crossfade or instant).
- Content visible by default; reveals enhance rather than gate (no blank sections on headless/inactive-tab renders).
