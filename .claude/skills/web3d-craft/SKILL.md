---
name: web3d-craft
description: Web 3D engineering standards — Three.js / React Three Fiber stack selection, render-loop and performance discipline, shader cost awareness, asset pipeline (glTF/Draco/KTX2), memory disposal, and the 3D pre-delivery checklist. Use when building any WebGL/WebGPU, Three.js, R3F, shader or interactive 3D web experience.
user-invocable: false
---

# Web 3D Craft

## Stack selection (decide before coding)

| Scenario | Stack | Why |
|---|---|---|
| Marketing page with scroll-driven 3D | Three.js + GSAP ScrollTrigger (+ React for UI) | GSAP owns scroll orchestration |
| React app with interactive 3D (product viewer, configurator) | React Three Fiber + Drei | declarative, state-driven |
| Complex timeline sequences in React | R3F + GSAP timelines | best of both |
| Physics-feel interactions (drag, momentum) | R3F + React Spring (+ Rapier for real physics) | natural springs |
| Particle-heavy / maximum control | plain Three.js | imperative control, instancing |

Follow the project's existing choice; never mix two animation libraries on the
same property — one owner per animated value.

## R3F hard rules (violations are audit findings)

- **Never `setState` inside `useFrame`** — that's 60 re-renders/second. Mutate
  refs directly (`meshRef.current.rotation.y += delta`); React state only for
  discrete changes (selection, mode), synced via zustand when global.
- Static scenes: `frameloop="demand"` on Canvas + `invalidate()` on change —
  don't burn GPU on an unchanging frame.
- `dpr={[1, 2]}` adaptive pixel ratio; load assets via Suspense
  (`useGLTF`, `useTexture`) with a designed fallback.
- Reuse geometries/materials across instances; hoist them out of components so
  re-renders don't recreate GPU resources.

## Performance budget (test against real, mid-range hardware)

- Target 60fps desktop / stable 30+ mobile; frame time is the metric, not vibes.
- Draw calls: prefer < ~100 for scenes with UI; merge static meshes; use
  `InstancedMesh` for repeated objects (100 trees = 1 draw call, not 100).
- Use delta time for all motion — never assume frame rate.
- LOD for anything far away; frustum culling stays on; shadows are the first
  thing to cheapen (resolution, distance) when the budget breaks.
- Lights are expensive: bake what doesn't move, limit real-time lights, prefer
  environment maps for ambience.

## Shader discipline (GLSL/WGSL)

- Instruction cost awareness: add/mul = 1×, divide/sqrt ≈ 4×, texture sample ≈
  4–8×, sin/cos/pow ≈ 8×. Move work from fragment to vertex shader when it
  interpolates acceptably; precompute into uniforms/textures what doesn't change
  per-pixel.
- Pink/magenta material = shader compile failure — read the log, don't guess.
- Keep custom shaders in separate `.glsl` files (or tagged template constants),
  named uniforms documented at the top.

## Asset pipeline

- glTF/GLB only for models; Draco or Meshopt compression; KTX2/basis for
  textures where the loader stack supports it. No multi-MB PNGs on 3D surfaces.
- Power-of-two texture sizes; mipmaps on; texel density consistent across
  surfaces the camera sees at the same distance.
- "Apply scale and rotation before export. No exceptions." — imported models
  arrive at scale 1, Y-up, forward-consistent; fix at the source, not with
  wrapper-group hacks.

## Memory & lifecycle (leaks are CRITICAL findings)

- Everything you create, you dispose: `geometry.dispose()`,
  `material.dispose()`, `texture.dispose()`, and `renderer.dispose()` on
  teardown. In R3F, prefer letting the renderer manage it — but anything created
  imperatively is yours to clean.
- Kill animations on unmount (GSAP `tween.kill()`, spring `stop()`); remove
  event/scroll listeners; cancel the RAF loop you own.
- Navigating away from and back to the 3D view repeatedly must not grow memory —
  test it (Performance/Memory panel), don't assume it.

## UX floor for 3D surfaces

- Loading state with progress for anything over ~1MB of assets; the page must
  never freeze white while a scene compiles.
- A non-WebGL/reduced fallback (static render or poster) when the context fails;
  respect `prefers-reduced-motion` by pausing idle animation.
- 3D canvas must not steal page scroll unexpectedly; touch gestures on mobile
  need explicit design (orbit vs page-scroll conflict is the classic fail).

## Pre-delivery checklist

- [ ] Frame rate measured (desktop + mobile emulation) on the heaviest scene — meets budget.
- [ ] Draw call count sane (renderer.info); repeated objects instanced.
- [ ] Assets compressed (Draco/Meshopt, KTX2/resized textures); total 3D payload reported in the ticket.
- [ ] Mount/unmount cycle leak-tested; animations and listeners cleaned up.
- [ ] Loading, fallback and reduced-motion paths exist and were exercised.
- [ ] One animation owner per property — no library fights.
