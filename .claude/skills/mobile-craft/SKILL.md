---
name: mobile-craft
description: Mobile engineering standards — React Native/Expo/Flutter/native patterns, list and image performance, offline behavior, platform conventions, secure storage, and the device checklist. Use when building any mobile screen, navigation, or device-facing feature.
user-invocable: false
---

# Mobile Craft

Detect the stack from the codebase (React Native/Expo, Flutter, Swift/Kotlin) and
follow that ecosystem's idioms; these standards apply across all of them.

## Performance

- Lists are virtualized (FlatList/FlashList, ListView.builder) with stable keys and
  memoized row components; never map an unbounded array into a scroll view.
- Images: explicit dimensions, cached loading, appropriately sized sources; no
  full-resolution assets in thumbnails.
- Keep the UI thread at 60fps: heavy computation off-thread or deferred; animations
  on the native driver where the framework offers it.
- Measure cold start impact when adding libraries — mobile bundles pay for every dependency.

## Resilience & offline

- Every network surface has loading / empty / error / **offline** states; retry
  affordances where actions can fail.
- Assume the network drops mid-request: writes should be safe to retry (or queued);
  never leave the UI in a lying state.
- Persist appropriate state so a killed/restored app resumes sensibly.

## Platform conventions

- Safe-area insets respected everywhere (notches, home indicator, status bar).
- Touch targets ≥ 44pt with adequate spacing; gestures follow platform norms.
- Android: hardware back button does the right thing on every screen; Predictive back where supported.
- Keyboard: forms scroll into view, inputs use correct keyboard types, return-key flow works.
- Permissions requested in context with rationale, and every denial path handled.

## Security

- Tokens/secrets in secure storage (Keychain/Keystore or the framework's secure
  wrapper) — never AsyncStorage/SharedPreferences/plaintext files.
- No sensitive data in logs, crash reports, or screenshots of secure screens.
- Certificate/ATS defaults respected; no cleartext HTTP.

## Pre-delivery checklist (run before reporting done)

- [ ] Typecheck/lint and unit tests green; new logic covered.
- [ ] Flow driven on simulator/emulator/Expo (or explicitly listed as needing manual
      verification if no device runtime is available in this environment).
- [ ] Loading/empty/error/offline states exist on every async surface.
- [ ] Safe areas, touch targets, keyboard behavior verified on the changed screens.
- [ ] Both platforms considered — platform-specific code paths noted in the ticket.
