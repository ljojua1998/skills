---
name: frontend-craft
description: Frontend engineering and design standards — distinctive UI direction, design tokens, component quality, accessibility, responsiveness, and the pre-delivery checklist. Use when building or restyling any UI (web components, pages, dashboards, landing pages).
user-invocable: false
---

# Frontend Craft

## Design process for new visual surfaces

Never start typing JSX/HTML with a default look in mind. Two passes first:

1. **Direction pass.** State the subject, audience, and the page's single purpose.
   Choose a deliberate aesthetic direction grounded in the subject's own world (its
   materials, vocabulary, artifacts) and commit to it. Take one real aesthetic risk
   you can justify — **spend your boldness in one place** (a signature element:
   hero treatment, distinctive type, one striking interaction); keep everything
   else disciplined.
2. **Token plan.** Before coding, write: 4–6 named colors (hex), display + body
   typeface pairing, type scale, spacing unit, radius/shadow language, and the
   signature element. Then critique: *would this look identical on a different
   project?* If yes, revise.

### Banned as AI-slop (do not ship these defaults)

- Inter/Roboto/Arial/system-ui as the display face; purple-gradient-on-white.
- The three clustering clichés: (a) warm cream `#F4F1EA` + serif + terracotta,
  (b) near-black + acid green/vermilion, (c) broadsheet hairlines + zero radius.
- Emojis as icons — use the project's icon set or SVG icons (Lucide/Heroicons).
- Decorative numbering/eyebrows/dividers that encode nothing true about the content.

When the project already has a design system, **its tokens win** — this process
applies to net-new surfaces, not to fighting existing brand rules.

## Engineering standards

- **Small units, always.** One component = one responsibility. When a component
  passes ~150–200 lines, renders several distinct concerns, or needs scrolling to
  understand — split it: extract child components, move logic into hooks
  (`useXxx`), move pure helpers into utils. One component per file; no god-files
  that export half the app. Same for functions: if it does "and", it's two
  functions.
- **Reuse first**: search for existing components, hooks, and utilities before
  creating new ones; extend rather than fork.
- **State placement**: local state for local concerns; server state via the
  project's data-fetching layer (with caching/invalidation); global stores only for
  genuinely global state.
- **Every async surface** ships loading, empty, error states — designed, not
  afterthoughts. Errors are directional ("Couldn't save — retry") not moody.
- **Forms**: validate on the client with readable messages, but treat server
  validation as the source of truth; disable double-submits; preserve input on error.
- **Performance**: lazy-load below-the-fold and route-level code; size images and
  use modern formats; memoize only measured hot paths; avoid layout thrash.
- **UX writing**: active voice ("Save changes", not "Submit"); name controls by
  what users recognize; consistent vocabulary across the app.

## Pre-delivery checklist (run before reporting done)

- [ ] Responsive at 375 / 768 / 1024 / 1440 px — no horizontal scroll, no overlap.
- [ ] Text contrast ≥ 4.5:1; interactive-element states distinguishable without color alone.
- [ ] Keyboard: everything reachable, visible focus states, logical tab order.
- [ ] Semantic HTML (headings hierarchy, buttons vs links, labeled inputs, alt text).
- [ ] `prefers-reduced-motion` respected; transitions 150–300ms, purposeful only.
- [ ] Clickables have cursor-pointer and hover/active feedback.
- [ ] Loading/empty/error states exist for every async surface.
- [ ] No console errors/warnings; no dead code or commented-out blocks left behind.
