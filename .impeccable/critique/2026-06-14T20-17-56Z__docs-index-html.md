---
target: docs/index.html
total_score: 32
p0_count: 0
p1_count: 1
timestamp: 2026-06-14T20-17-56Z
slug: docs-index-html
---
# Critique — docs/index.html (Glance landing)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Copy button confirms; mock shows live progress. |
| 2 | Match System / Real World | 4 | Speaks dev fluently — curl, glance run, Live Activity metaphor. |
| 3 | User Control & Freedom | 3 | Mock replays on click; anchor nav. |
| 4 | Consistency & Standards | 3 | Cohesive glass system, but mobile hero breaks the grid. |
| 5 | Error Prevention | 3 | No forms to mis-fill. |
| 6 | Recognition vs Recall | 4 | Everything visible, nav labeled, command shown not described. |
| 7 | Flexibility & Efficiency | 3 | Two copy buttons, smooth-scroll anchors. |
| 8 | Aesthetic & Minimalist | 3 | Glass-on-everything + drifting blob add decorative noise. |
| 9 | Error Recovery | 3 | n/a for static marketing. |
| 10 | Help & Documentation | 3 | Links to USAGE / SECURITY / install guide. |
| Total | | 32/40 | Good — solid foundation, address weak areas |

## Anti-Patterns Verdict

Mostly does NOT look AI-generated. Real POV: dark-grey + single blue accent, animated Live Activity as show-don't-tell hero, varied bento (not identical grid), genuine type pairing (Bricolage Grotesque + Hanken Grotesk). Clears the purple-aurora-SaaS lane. Two tells remain: glass as default on every surface, and a desaturated survivor of the aurora move.

Detector (detect.mjs, 2 warnings):
- em-dash-overuse — 9 in body copy. REAL. Cadence tell vs "calm, precise" voice.
- single-font — FALSE POSITIVE. Detector missed style.css; site pairs two families.

No visual overlay — preview_resize doesn't reflow this static page; mobile findings reasoned from CSS.

## Overall Impression

Good redesign that delivers the brief: no purple, dark-grey liquid-glass, blue accent, pulse-flow kept, motion that earns its place. Biggest opportunity is not aesthetic — the hero's phone-mock centerpiece silently breaks on mobile.

## What's Working

1. Show-don't-tell hero. Filling-then-Done Live Activity IS the pitch. Conic ring frames it.
2. Varied bento. tile-wide / tile-tall / regular breaks the identical-card-grid reflex.
3. Restraint with one accent. Single blue carries glow, pulse, ring, prompt. Matches "calm, precise, invisible."

## Priority Issues

[P1] Hero collapses on mobile. Every section has a stack breakpoint except .hero, which stays grid-template-columns: 1.05fr 0.95fr at every width. On a 375px phone the min(330px,80vw) phone mock overflows and is clipped by body overflow-x:hidden, leaving a ~300-440px dead gap (min-height:440px stage, nothing visible). Best asset vanishes on mobile. Fix: @media (max-width:760px){ .hero{ grid-template-columns:1fr } } + decide mock placement. Command: /impeccable adapt

[P2] Glassmorphism as default. style.css:52 applies blur(22px) glass to .install, .node, .tile, .get-mac, .get-ios — nearly every surface. Brand absolute-ban. Weakens the metaphor: when everything is glass, the mock + install pill stop reading as real Mac/iOS surfaces. Fix: keep glass on product surfaces only; flatten how/tile/get to solid raised + 1px border. Command: /impeccable quieter

[P2] The aurora persists. .aurora::after is a 30s drifting radial blob (@keyframes drift). Desaturated to blue-grey but same moving-gradient-blob move; class still named .aurora. Fix: static grey-blue gradient, drop drift, rename. Command: /impeccable quieter

[P2] Em-dash overuse. 9 in body copy. Stacks against the calm voice. Fix: convert ~half to periods/commas. Command: /impeccable clarify

[P3] Card-stacks all the way down. how (3) + bento + get (2) — eye sees cards, cards, cards. One section breaking the container pattern adds rhythm. Command: /impeccable layout

## Persona Red Flags

Casey (Mobile): Hero shows a blank rectangle where the demo should be (P1). Highest-risk failure.
Jordan (First-Timer): Well served — curl front-and-center, value in 5s, labeled nav. No flags.
Riley (Stress): Mock replays cleanly; prefers-reduced-motion path thorough. Edge cases handled.
Maya (Mac dev, project persona): Trusts the page — ChaCha20-Poly1305, loopback-default, MIT, source links. Will install — if on desktop.

## Minor Observations

- Bricolage + Hanken both grotesques, but roles diverge enough to work.
- Hero ring fills to 318deg, never completes while mock reaches Done — minor narrative mismatch, probably intentional.
- --faint (oklch 0.58) on footer ~4.7:1 — passes, but it's the floor.

## Questions to Consider

- What if the phone mock led on mobile instead of getting clipped — demo first, headline under?
- If only the mock + install pill were glass, would the rest feel more premium, not less?
- Is the drifting blob adding anything a static gradient wouldn't?
