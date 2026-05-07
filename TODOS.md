# Bento — TODOs

Deferred items captured during the v0.2 distribution-wave plan (`/autoplan` review, 2026-05-07). Each item names the source finding from the review.

## Hard-deferred (revisit on evidence, not before)

- **CEO F5 — Competitive recon (3-4h time-boxed)** — revisit before starting any non-distribution v0.2 work. Install Raycast (script-commands), BetterTouchTool (macros), Stream Deck Mobile, Hammerspoon-as-launcher patterns. Confirm bento's wedge isn't being eaten by a recent shipment. If a competitor ships "1-click macro launcher with global hotkey," reframe v0.2.
- **Eng F8 — Notarization ($99/yr Apple Developer cert)** — revisit when DMG-path users hit Gatekeeper friction with reproducible evidence (e.g. ≥3 unique users reporting "can't open Bento" via support channels). Going from ad-hoc to Developer ID later breaks Sparkle for every user (team-identifier mismatch in Sparkle's cross-cert path), so this decision compounds.

## Scope expansions for v0.3+

- **DX F2 — `bento doctor --fix` auto-remediation.** Pairs diagnosis with action. `gh auth status` → `gh auth refresh` pattern. v0.3+ scope.
- **DX F5 — Beta channel via custom appcast URL.** Power users want betas; tiny implementation (one Info.plist key + appcast generator branch + `defaults write SUFeedURL` doc). Revisit when there's a power-user cohort wanting beta access.

## Known issues / future hardening

- **Eng F13 — DistributedNotificationCenter is unauthenticated.** Any local process can post `bento.pressTile` and trigger arbitrary tiles. Severity: medium (local-only, requires same-user privilege; but tiles can run shell actions). Mitigation path for v0.3+: switch to `NSXPCConnection` with audit-token validation. Until then, document in `docs/integration.md` that bento's IPC trusts any same-user process.
- **C9 — Discoverability nudge for manual-only updates.** With `SUEnableAutomaticChecks=NO` (per Final Approval Decision 2), users may forget that updates exist. Once we have ≥3 months of v0.2 telemetry-free heuristics (release-asset download counts), assess whether users are missing updates. If yes, add a subtle in-app reminder (e.g. `bento doctor` shows "Last update check: N months ago" with a `[info]` tag). No scheduled prompts.

## Sparkle key custody (operational; revisit quarterly)

- **EdDSA private key rotation calendar.** Quarterly reminder. Steps in plan body §Key-rotation runbook.
- **Move signing from GHA secret to OIDC + cloud KMS** — when a credible KMS path exists (AWS KMS, GCP KMS, GitHub-issued OIDC tokens). Reduces single-compromise blast radius. Tracks Eng F11 future improvement.

## Roadmap items NOT covered by the v0.2 distribution plan

These are README-stated v0.2 roadmap items that ship in separate plans:

- Macro recording (Accessibility-permission-gated; #1 user-demand item)
- Configurable global hotkey (key-recorder UI)
- Play / media-key tile (needs `IOHIDPostEvent` bridge)
- Universal binary (arm64 + x86_64) — build matrix change + Intel hardware testing
- XCTest target (returns alongside library-target refactor that needs full Xcode)
