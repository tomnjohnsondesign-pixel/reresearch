# Native design prototype

- Start from visual parity with the existing web app under `src/`. Preserve its current layout and copy until Tom requests a design change.
- Tom's first requested redesign uses light mode, menu top left, centred reresearch logo, search top right, and a floating Liquid Glass tray for Feed, Saved, Queue, and Settings. For you/Latest is a feed-level choice. Both the tray background and selection background must be full capsules, with consistent side/bottom spacing. Do not substitute asymmetrical concentric-corner shapes.
- Inside the tray, use one equal inset around the selected item. Its darker surface should be strongly frosted. All four icons are outlined until selected, then filled. Home is a minimal rounded house without a door cut-out; Settings uses a simple person silhouette, following Tom's Threads reference.
- Realistic mock data should populate existing fields and states. Do not add demo labels, preview banners, explanatory placeholders, debug navigation, or invented interface elements.
- Render the app natively in SwiftUI. Keep design tokens and small reusable components explicit so later visual changes are easy to make.
- Keep backend/API calls and all external side effects out of this prototype. Do not send emails, verify real keys, or access the production database.
- Do not add an Apple signing team, credentials, TestFlight uploads, or GitHub-hosted macOS workflows as part of local design work.
- Build and launch with XcodeBuildMCP on the local Mac. Inspect real simulator screens and verify navigation after changes. The simulator mirror should remain available in Codex while Tom is designing.
- Keep generated builds, screenshots, runtime logs, and machine-local tooling files out of Git. Use the repository's ignored `.data/` directory for local build artifacts.
