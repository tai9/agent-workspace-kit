<!-- ADOPT-ME: stub — a persona skill fills this during adoption for this workspace -->
# Store review surface

What App Review will meet when it opens this product, and what it has
said before. **Stale-by-design**: entries describe the submission
surface as of their date; when an engagement finds it has moved, update
the entry.

Adoption fills:

- **App records** — bundle ID per environment, the App Store Connect
  app name, primary category, age rating, and which builds actually go
  to review (prod only, or also a staging flavor via TestFlight
  external testing).
- **Where the iOS config lives** — the real paths for this stack:
  `Info.plist`, entitlements, `PrivacyInfo.xcprivacy`, and where
  permission strings are generated (native project, Flutter
  `ios/Runner/`, Expo `app.json`/`app.config.*` plugins). An audit that
  reads the wrong file reports a clean bill of health.
- **Reviewer access** — the demo/reviewer account(s) and how they are
  kept alive, or the demo mode; where the App Review notes are kept so
  each submission starts from the last accepted wording. Credentials are
  named by where they live, never pasted here.
- **Monetization seams** — product IDs, which repo validates purchases
  (App Store Server API / receipts, Server Notifications endpoint), and
  where restore lives on the client.
- **Account lifecycle seams** — the in-app deletion entry point and the
  backend handler it calls, what deletion actually removes vs retains
  and why, and Sign in with Apple token revocation if SIWA is offered.
- **SDK inventory** — third-party SDKs that collect data or need a
  privacy manifest, and where the App Privacy ("nutrition label")
  answers are recorded.
- **OTA policy** — the workspace's line between what may ship as an
  over-the-air patch and what needs a store build (bug fixes and copy:
  patch; new features, new screens, changed purpose: store build).
- **Rejection history** — dated: build, guideline cited, Apple's
  wording, the fix, and the build that passed. The next audit checks
  every past rejection has not regressed.
- **Decided positions (don't re-flag)** — review stances the owner has
  taken on purpose, with the reasoning or the Resolution Center thread
  that settled them.
