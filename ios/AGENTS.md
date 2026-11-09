# Native design prototype

- Start from visual parity with the existing web app under `src/`. Preserve its current layout and copy until Tom requests a design change.
- Realistic mock data should populate existing fields and states. Do not add demo labels, preview banners, explanatory placeholders, debug navigation, or invented interface elements.
- Render the app natively in SwiftUI. Keep design tokens and small reusable components explicit so later visual changes are easy to make.
- Keep backend/API calls and all external side effects out of this prototype. Do not send emails, verify real keys, or access the production database.
- Do not add an Apple signing team, credentials, TestFlight uploads, or GitHub-hosted macOS workflows as part of local design work.
- Build and launch with XcodeBuildMCP on the local Mac. Inspect real simulator screens and verify navigation after changes. The simulator mirror should remain available in Codex while Tom is designing.
- Keep generated builds, screenshots, runtime logs, and machine-local tooling files out of Git. Use the repository's ignored `.data/` directory for local build artifacts.
